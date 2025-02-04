import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';
import 'package:meta/meta.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import '../models/data_point.dart';
import '../repository/data_acquisition_repository.dart';
import '../../../http/domain/services/http_service.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../models/trigger_data.dart';

// Configurations
const Duration _reconnectionDelay = Duration(seconds: 5);

// Message classes for isolate communication
class SocketIsolateSetup {
  final SendPort sendPort;
  final String ip;
  final int port;

  const SocketIsolateSetup(this.sendPort, this.ip, this.port);
}

class ProcessingIsolateSetup {
  final SendPort sendPort;
  final DataProcessingConfig config;
  final DeviceConfig deviceConfig;

  const ProcessingIsolateSetup(this.sendPort, this.config, this.deviceConfig);
}

class DataProcessingConfig {
  final double scale;
  final double distance;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double mid;
  final bool useHysteresis;
  final bool useLowPassFilter;
  final TriggerMode triggerMode;
  final DeviceConfig deviceConfig;

  const DataProcessingConfig({
    required this.scale,
    required this.distance,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.mid,
    required this.deviceConfig,
    this.useHysteresis = true,
    this.useLowPassFilter = true,
    this.triggerMode = TriggerMode.normal,
  });

  DataProcessingConfig copyWith({
    double? scale,
    double? distance,
    double? triggerLevel,
    TriggerEdge? triggerEdge,
    double? mid,
    DeviceConfig? deviceConfig,
    bool? useHysteresis,
    bool? useLowPassFilter,
    TriggerMode? triggerMode,
  }) {
    return DataProcessingConfig(
      scale: scale ?? this.scale,
      distance: distance ?? this.distance,
      triggerLevel: triggerLevel ?? this.triggerLevel,
      triggerEdge: triggerEdge ?? this.triggerEdge,
      mid: mid ?? this.mid,
      deviceConfig: deviceConfig ?? this.deviceConfig,
      useHysteresis: useHysteresis ?? this.useHysteresis,
      useLowPassFilter: useLowPassFilter ?? this.useLowPassFilter,
      triggerMode: triggerMode ?? this.triggerMode,
    );
  }
}

class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final bool useHysteresis;
  final bool useLowPassFilter;
  final TriggerMode triggerMode;

  const UpdateConfigMessage({
    required this.scale,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.useHysteresis,
    required this.useLowPassFilter,
    required this.triggerMode,
  });
}

class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  late final DeviceConfigProvider deviceConfig;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _frequencyController = StreamController<double>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  late final HttpService httpService;

  bool _disposed = false;
  bool _initialized = false;
  double _scale = 0;
  double _triggerLevel = 1;
  // ignore: unused_field
  double _distance = 0.0;
  double _mid = 0.0;
  TriggerEdge _triggerEdge = TriggerEdge.positive;
  TriggerMode _triggerMode = TriggerMode.normal;
  VoltageScale _currentVoltageScale = VoltageScales.volts_2;
  bool _useHysteresis = false;
  bool _useLowPassFilter = false;

  // Metrics
  double _currentFrequency = 0.0;
  double _currentMaxValue = 0.0;
  double _currentMinValue = 0.0;

  // Isolates and ports
  Isolate? _socketIsolate;
  Isolate? _processingIsolate;
  ReceivePort? _processingReceivePort;
  SendPort? _configSendPort;
  SendPort? _socketToProcessingSendPort;

  DataAcquisitionService(this.httpConfig) {
    try {
      deviceConfig = Get.find<DeviceConfigProvider>();
      if (deviceConfig.config == null) {
        throw StateError('DeviceConfigProvider has no configuration');
      }
      httpService = Get.find<HttpService>();
    } catch (e) {
      throw StateError('Failed to initialize DataAcquisitionService: $e');
    }
  }

  @override
  Future<void> sendSingleTriggerRequest() async {
    try {
      await httpService.get('/single');
    } catch (e) {
      print('Error sending single trigger request: $e');
      rethrow;
    }
  }

  @override
  Future<void> sendNormalTriggerRequest() async {
    try {
      await httpService.get('/normal');
    } catch (e) {
      print('Error sending normal trigger request: $e');
      rethrow;
    }
  }

  void _initializeFromDeviceConfig() {
    postTriggerStatus();
  }

  @override
  bool get useHysteresis => _useHysteresis;
  set useHysteresis(bool value) {
    _useHysteresis = value;
    updateConfig();
  }

  @override
  bool get useLowPassFilter => _useLowPassFilter;
  set useLowPassFilter(bool value) {
    _useLowPassFilter = value;
    updateConfig();
  }

  @override
  double get mid => (1 << deviceConfig.usefulBits) / 2;

  @override
  set mid(double value) {
    _mid = value;
    updateConfig();
  }

  @override
  double get scale => _scale;

  @override
  set scale(double value) {
    _scale = value;
    updateConfig();
  }

  @override
  double get distance => 1 / deviceConfig.samplingFrequency;

  @override
  set distance(double value) {
    _distance = value;
    updateConfig();
  }

  @override
  Future<void> postTriggerStatus() async {
    try {
      // Calculate full range in bits
      final fullRange = 1 << deviceConfig.usefulBits;

      // Convert voltage trigger to raw value
      final rawTrigger = (_triggerLevel / scale) + mid;

      // Calculate percentage (0-100)
      final percentage = (rawTrigger / fullRange) * 100;

      await httpService.post('/trigger', {
        'trigger_percentage': percentage.clamp(0, 100),
        'trigger_edge':
            _triggerEdge == TriggerEdge.positive ? 'positive' : 'negative',
      });
    } catch (e) {
      print('Error posting trigger status: $e');
      rethrow;
    }
  }

  @override
  double get triggerLevel => _triggerLevel;

  @override
  set triggerLevel(double value) {
    _triggerLevel = value;
    postTriggerStatus();
    updateConfig();
  }

  @override
  TriggerEdge get triggerEdge => _triggerEdge;

  @override
  set triggerEdge(TriggerEdge value) {
    _triggerEdge = value;
    postTriggerStatus();
    updateConfig();
  }

  @override
  TriggerMode get triggerMode => _triggerMode;

  @override
  set triggerMode(TriggerMode value) {
    _triggerMode = value;
    postTriggerStatus();
    updateConfig();
  }

  @override
  double get currentMaxValue => _currentMaxValue;

  @override
  double get currentMinValue => _currentMinValue;

  // Stream getters with disposal check
  @override
  Stream<List<DataPoint>> get dataStream {
    _checkDisposed();
    return _dataController.stream;
  }

  @override
  Stream<double> get frequencyStream {
    _checkDisposed();
    return _frequencyController.stream;
  }

  @override
  VoltageScale get currentVoltageScale => _currentVoltageScale;

  @override
  Stream<double> get maxValueStream {
    _checkDisposed();
    return _maxValueController.stream;
  }

  void _checkDisposed() {
    if (_disposed) {
      throw StateError('Service has been disposed');
    }
  }

  @override
  void setVoltageScale(VoltageScale voltageScale) {
    final oldScale = _currentVoltageScale.scale;
    _currentVoltageScale = voltageScale;
    scale = voltageScale.scale;

    // Adjust trigger level proportionally to new scale
    final ratio = voltageScale.scale / oldScale;
    triggerLevel *= ratio;

    // Clamp trigger level to new voltage range
    final voltageRange = voltageScale.scale * 512;
    final halfRange = voltageRange / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);

    updateConfig();
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    setVoltageScale(VoltageScales.volt_1);
    _initializeFromDeviceConfig();
    _initialized = true;
  }

  static Future<void> _socketIsolateFunction(SocketIsolateSetup setup) async {
    final socketService = SocketService();
    final connection = SocketConnection(setup.ip, setup.port);

    // Add exit handler
    final exitPort = ReceivePort();
    Isolate.current.addOnExitListener(exitPort.sendPort);
    exitPort.listen((_) async {
      print('Socket isolate exiting, cleaning up...');
      await socketService.close();
      exitPort.close();
    });

    while (true) {
      try {
        await socketService.connect(connection);
        _setupSocketListener(socketService, setup.sendPort);
        break;
      } catch (e) {
        print('Socket connection error: $e');
        await Future.delayed(_reconnectionDelay);
      }
    }
  }

  static void _setupSocketListener(
      SocketService socketService, SendPort sendPort) {
    socketService.listen();
    socketService.subscribe(sendPort.send);
  }

  static void _processingIsolateFunction(ProcessingIsolateSetup setup) {
    final receivePort = ReceivePort();
    setup.sendPort.send(receivePort.sendPort);

    var config = setup.config;
    final processingChunkSize = setup.deviceConfig.samplesPerPacket;
    final maxQueueSize = processingChunkSize * 6;
    final queue = Queue<int>();
    final singleModeQueue = Queue<int>();

    receivePort.listen((message) {
      if (message == 'stop') {
        queue.clear();
        singleModeQueue.clear();
      } else if (message == 'clear_queue') {
        queue.clear();
        singleModeQueue.clear();
      } else if (message is List<int>) {
        if (config.triggerMode == TriggerMode.single) {
          singleModeQueue.addAll(message);
          _processSingleModeData(
              singleModeQueue, config, setup.sendPort, processingChunkSize);
        } else {
          _processIncomingData(message, queue, config, setup.sendPort,
              maxQueueSize, processingChunkSize);
        }
      } else if (message is UpdateConfigMessage) {
        config = _updateConfig(config, message);
        if (config.triggerMode == TriggerMode.single) {
          queue.clear();
          singleModeQueue.clear();
        }
      }
    });
  }

  static void _processSingleModeData(Queue<int> queue,
      DataProcessingConfig config, SendPort sendPort, int samplesPerPacket) {
    if (queue.isEmpty) return;

    // Solo procesar si tenemos suficientes datos
    if (queue.length >= samplesPerPacket * 2) {
      // * 2 porque son bytes
      final (points, maxValue, minValue) =
          _processData(queue, samplesPerPacket * 2, config, sendPort);

      // Si encontramos puntos y hay un trigger
      if (points.isNotEmpty && points.any((p) => p.isTrigger)) {
        sendPort.send({
          'type': 'data',
          'points': points,
          'maxValue': maxValue,
          'minValue': minValue
        });

        // Solo pausamos si tenemos suficientes datos y encontramos trigger
        sendPort.send({'type': 'pause_graph'});

        print("Size of points: ${points.length}");
        print("Samples per packet: $samplesPerPacket");

        for (int i = 0; i < 5; i++) {
          print("First 5 data points: ${points[i].x}, ${points[i].y}");
        }

        for (int i = points.length - 5; i < points.length; i++) {
          print("Last 5 data points: ${points[i].x}, ${points[i].y}");
        }
      }
    }
  }

  static void _processIncomingData(
    List<int> data,
    Queue<int> queue,
    DataProcessingConfig config,
    SendPort sendPort,
    int maxQueueSize,
    int processingChunkSize,
  ) {
    queue.addAll(data);
    while (queue.length > maxQueueSize) {
      queue.removeFirst();
    }
    while (queue.length >= processingChunkSize) {
      final (points, maxValue, minValue) =
          _processData(queue, processingChunkSize, config, sendPort);

      sendPort.send({
        'type': 'data',
        'points': points,
        'maxValue': maxValue,
        'minValue': minValue
      });
    }
  }

  static DataProcessingConfig _updateConfig(
    DataProcessingConfig currentConfig,
    UpdateConfigMessage message,
  ) {
    return currentConfig.copyWith(
      scale: message.scale,
      triggerLevel: message.triggerLevel,
      triggerEdge: message.triggerEdge,
      useHysteresis: message.useHysteresis,
      useLowPassFilter: message.useLowPassFilter,
      triggerMode: message.triggerMode,
    );
  }

  static (int value, int channel) _readDataFromQueue(
    Queue<int> queue,
    DeviceConfig deviceConfig,
  ) {
    final bytes = [queue.removeFirst(), queue.removeFirst()];
    final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint16(0, Endian.little);

    final dataValue = uint16Value & deviceConfig.dataMask;

    // Find the lowest 1 bit position in channel mask - that's where channel bits start
    final channelShift = (deviceConfig.channelMask & -deviceConfig.channelMask)
            .toRadixString(2)
            .length -
        1;
    final channel = (uint16Value & deviceConfig.channelMask) >> channelShift;

    return (dataValue, channel);
  }

  static (double x, double y) _calculateCoordinates(
    int uint12Value,
    int pointsLength,
    DataProcessingConfig config,
  ) {
    final x = pointsLength * config.distance;
    final y = (uint12Value - config.mid) * config.scale;
    return (x, y);
  }

  static bool _shouldTrigger(
      double prevY,
      double currentY,
      double triggerLevel,
      TriggerEdge triggerEdge,
      double sensitivity,
      double maxValue,
      double minValue) {
    if (triggerEdge == TriggerEdge.positive) {
      // For initial trigger, only check if we cross the trigger level
      final shouldTrig = prevY < triggerLevel && currentY >= triggerLevel;

      //if (shouldTrig) {
      //  print('Positive trigger detected:');
      //  print('prevY: $prevY');
      //  print('currentY: $currentY');
      //  print('triggerLevel: $triggerLevel');
      //}
      return shouldTrig;
    } else {
      // For negative edge, only check if we cross the trigger level downwards
      final shouldTrig = prevY > triggerLevel && currentY <= triggerLevel;

      //if (shouldTrig) {
      //  print('Negative trigger detected:');
      //  print('prevY: $prevY');
      //  print('currentY: $currentY');
      //  print('triggerLevel: $triggerLevel');
      //}
      return shouldTrig;
    }
  }

  // Helper method to calculate trend
  static double _calculateTrend(List<double> values) {
    if (values.length < 2) return 0;

    double sumX = 0;
    double sumY = 0;
    double sumXY = 0;
    double sumX2 = 0;

    for (int i = 0; i < values.length; i++) {
      sumX += i.toDouble();
      sumY += values[i];
      sumXY += i * values[i];
      sumX2 += i * i;
    }

    final n = values.length.toDouble();
    final slope = (n * sumXY - sumX * sumY) / (n * sumX2 - sumX * sumX);
    return slope;
  }

  static List<double> _applyTriggerFilter(
      List<DataPoint> points, double samplingFrequency,
      {double cutoffFrequency = 50000.0}) {
    //print('\n_applyTriggerFilter Debug:');
    //print('Input points length: ${points.length}');
    //print('First few Y values: ${points.take(5).map((p) => p.y).toList()}');
    //print('Sampling frequency: $samplingFrequency');
    //print('Cutoff frequency: $cutoffFrequency');

    if (points.isEmpty) {
      //print('Empty points list passed to filter');
      return [];
    }

    //print('Filtering ${points.length} points');
    //print('Sampling frequency: $samplingFrequency');
    //print('Cutoff frequency: $cutoffFrequency');

    final filter = LowPassFilter();
    final filteredPoints = filter.apply(points, {
      'cutoffFrequency': cutoffFrequency,
      'samplingFrequency': samplingFrequency,
    });

    //print('Filtered points length: ${filteredPoints.length}');
    //print(
    //    'Filtered first few values: ${filteredPoints.take(5).map((p) => p.y).toList()}');

    return filteredPoints.map((p) => p.y).toList();
  }

  static (List<DataPoint>, double, double) _processData(
    Queue<int> queue,
    int chunkSize,
    DataProcessingConfig config,
    SendPort sendPort,
  ) {
    final points = <DataPoint>[];
    var firstTriggerX = 0.0;
    var foundFirstTrigger = false;
    var waitingForNextTrigger = false;

    double maxValue = double.negativeInfinity;
    double minValue = double.infinity;

    // Read data points
    for (var i = 0;
        i < chunkSize;
        i += 2 * config.deviceConfig.dividingFactor) {
      if (queue.length < 2 * config.deviceConfig.dividingFactor) break;

      // Skip unwanted samples
      for (var j = 0; j < (config.deviceConfig.dividingFactor - 1) * 2; j++) {
        if (queue.isNotEmpty) queue.removeFirst();
      }

      final (uint12Value, _) = _readDataFromQueue(queue, config.deviceConfig);
      final (x, y) = _calculateCoordinates(uint12Value, points.length, config);
      points.add(DataPoint(x, y));

      maxValue = max(maxValue, y);
      minValue = min(minValue, y);
    }

    if (points.isEmpty) {
      return ([], 0.0, 0.0);
    }

    var triggerSensitivity = (maxValue - minValue) * 0.25;
    if (config.triggerEdge == TriggerEdge.positive) {
      if (config.triggerLevel - triggerSensitivity * 1.25 <= minValue) {
        triggerSensitivity = -triggerSensitivity;
      }
    } else {
      if (config.triggerLevel + triggerSensitivity * 1.25 >= maxValue) {
        triggerSensitivity = -triggerSensitivity;
      }
    }

    final List<double> signalForTrigger;
    if (config.useLowPassFilter) {
      signalForTrigger =
          _applyTriggerFilter(points, config.deviceConfig.samplingFrequency);
    } else {
      signalForTrigger = points.map((p) => p.y).toList();
    }

    final result = <DataPoint>[];

    for (var i = 0; i < points.length; i++) {
      final point = points[i];

      if (i > 0) {
        final prevY = signalForTrigger[i - 1];
        final currentY = signalForTrigger[i];

        bool isTriggerCandidate = _shouldTrigger(
            prevY,
            currentY,
            config.triggerLevel,
            config.triggerEdge,
            triggerSensitivity,
            maxValue,
            minValue);

        if (isTriggerCandidate && !waitingForNextTrigger) {
          bool validTrigger = true;

          if (config.useHysteresis) {
            // Calculate available points for trend
            const maxWindowSize = 5;
            final availablePoints = min(i + 1, points.length);
            final windowSize = min(maxWindowSize, availablePoints);

            // Only calculate trend if we have at least 2 points
            if (windowSize >= 2) {
              final trend = _calculateTrend(
                  signalForTrigger.sublist(i - windowSize + 1, i + 1));
              validTrigger =
                  (config.triggerEdge == TriggerEdge.positive && trend > 0) ||
                      (config.triggerEdge == TriggerEdge.negative && trend < 0);
            } else {
              // For single point, use simple threshold comparison
              validTrigger = config.triggerEdge == TriggerEdge.positive
                  ? currentY > prevY
                  : currentY < prevY;
            }
          }

          if (validTrigger) {
            if (!foundFirstTrigger) {
              firstTriggerX = point.x;
              foundFirstTrigger = true;
            }
            result.add(DataPoint(point.x, point.y, isTrigger: true));

            if (config.triggerMode == TriggerMode.normal) {
              waitingForNextTrigger = true;
            } else if (config.triggerMode == TriggerMode.single) {
              // En modo single, si encontramos el primer trigger
              // procesamos el resto de puntos y terminamos
              waitingForNextTrigger = false;
              // No hacemos continue para procesar el resto de puntos después del trigger
            }

            if (config.triggerMode == TriggerMode.normal) {
              continue;
            }
          }
        }

        if (waitingForNextTrigger && config.triggerMode == TriggerMode.normal) {
          if (config.triggerEdge == TriggerEdge.positive) {
            // Reset only when signal goes below trigger level by sensitivity margin
            if (currentY < (config.triggerLevel - triggerSensitivity)) {
              waitingForNextTrigger = false;
              //print('Reset waiting for next positive trigger');
            }
          } else {
            // Reset only when signal goes above trigger level by sensitivity margin
            if (currentY > (config.triggerLevel + triggerSensitivity)) {
              waitingForNextTrigger = false;
              //print('Reset waiting for next negative trigger');
            }
          }
        }
      }
      result.add(point);
    }

    final adjustedPoints = foundFirstTrigger
        ? result
            .map((p) =>
                DataPoint(p.x - firstTriggerX, p.y, isTrigger: p.isTrigger))
            .toList()
        : points;

    //print('\nFinal Results:');
    //print('Total points: ${result.length}');
    //print('Trigger points: ${result.where((p) => p.isTrigger).length}');
    //print('Found first trigger: $foundFirstTrigger');

    return (adjustedPoints, maxValue, minValue);
  }

  void _updateMetrics(
      List<DataPoint> points, double maxValue, double minValue) {
    if (points.isEmpty) return;

    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = maxValue;
    _currentMinValue = minValue;

    _frequencyController.add(_currentFrequency);
    _maxValueController.add(_currentMaxValue);
  }

  double _calculateFrequency(List<DataPoint> points) {
    final triggerPoints =
        points.where((p) => p.isTrigger).map((p) => p.x).toList();

    if (triggerPoints.length < 2) return 0.0;

    final intervals = List.generate(
      triggerPoints.length - 1,
      (i) => triggerPoints[i + 1] - triggerPoints[i],
    );

    final averageInterval =
        intervals.reduce((a, b) => a + b) / intervals.length;
    return averageInterval > 0 ? 1 / averageInterval : 0.0;
  }

  @override
  Future<void> fetchData(String ip, int port) async {
    await stopData();
    await initialize();

    _processingReceivePort = ReceivePort();
    final processingStream = _processingReceivePort!.asBroadcastStream();

    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      mid: mid,
      deviceConfig: deviceConfig.config!,
      useHysteresis: useHysteresis,
      useLowPassFilter: useLowPassFilter,
      triggerMode: triggerMode,
    );

    _processingIsolate = await Isolate.spawn(
      _processingIsolateFunction,
      ProcessingIsolateSetup(
          _processingReceivePort!.sendPort, config, deviceConfig.config!),
    );

    await _setupProcessingIsolate(processingStream);
    await _setupSocketIsolate(ip, port);
  }

  Future<void> _setupProcessingIsolate(Stream processingStream) async {
    final completer = Completer<SendPort>();

    processingStream.listen((message) {
      if (message is SendPort) {
        _socketToProcessingSendPort = message;
        _configSendPort = message;
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        if (message['type'] == 'data') {
          final points = message['points'] as List<DataPoint>;
          final maxValue = message['maxValue'] as double;
          final minValue = message['minValue'] as double;

          _dataController.add(points);
          _updateMetrics(points, maxValue, minValue);
        } else if (message['type'] == 'pause_graph') {
          Get.find<DataAcquisitionProvider>().setPause(true);
        }
      }
    });

    _socketToProcessingSendPort = await completer.future;
  }

  Future<void> _setupSocketIsolate(String ip, int port) async {
    _socketIsolate = await Isolate.spawn(
      _socketIsolateFunction,
      SocketIsolateSetup(_socketToProcessingSendPort!, ip, port),
    );
  }

  @override
  void updateConfig() {
    _configSendPort?.send(UpdateConfigMessage(
      scale: scale,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      useHysteresis: useHysteresis,
      useLowPassFilter: useLowPassFilter,
      triggerMode: triggerMode,
    ));
  }

  @override
  Future<void> stopData() async {
    try {
      _configSendPort?.send('stop');
      _socketToProcessingSendPort?.send('stop');

      await Future.delayed(const Duration(milliseconds: 100));

      final processingDone = Completer<void>();
      final socketDone = Completer<void>();

      if (_processingIsolate != null) {
        final exitPort = ReceivePort();
        _processingIsolate!.addOnExitListener(exitPort.sendPort);
        exitPort.listen((_) {
          exitPort.close();
          processingDone.complete();
        });
      } else {
        processingDone.complete();
      }

      if (_socketIsolate != null) {
        final exitPort = ReceivePort();
        _socketIsolate!.addOnExitListener(exitPort.sendPort);
        exitPort.listen((_) {
          exitPort.close();
          socketDone.complete();
        });
      } else {
        socketDone.complete();
      }

      _processingIsolate?.kill(priority: Isolate.immediate);
      _socketIsolate?.kill(priority: Isolate.immediate);

      await Future.wait([
        processingDone.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => print('Processing isolate kill timeout'),
        ),
        socketDone.future.timeout(
          const Duration(seconds: 2),
          onTimeout: () => print('Socket isolate kill timeout'),
        ),
      ]);

      _processingIsolate = null;
      _socketIsolate = null;
      _processingReceivePort?.close();
      _processingReceivePort = null;
      _socketToProcessingSendPort = null;
      _configSendPort = null;

      _currentFrequency = 0.0;
      _currentMaxValue = 0.0;

      // Only add final values if controllers are not closed
      if (!_disposed) {
        _frequencyController.add(0.0);
        _maxValueController.add(0.0);
        _dataController.add([]);
      }
    } catch (e) {
      print('Error stopping data: $e');
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stopData();

    await Future.wait([
      if (!_dataController.isClosed) _dataController.close(),
      if (!_frequencyController.isClosed) _frequencyController.close(),
      if (!_maxValueController.isClosed) _maxValueController.close(),
    ]);
  }

  @override
  Future<List<double>> autoset(double chartHeight, double chartWidth) async {
    // Primero, actualizamos el triggerLevel al valor medio entre el máximo y el mínimo actuales
    triggerLevel = (_currentMaxValue + _currentMinValue) / 2;

    // Aseguramos que el trigger esté dentro del rango de voltaje
    final voltageRange =
        _currentVoltageScale.scale * pow(2, deviceConfig.usefulBits);
    final halfRange = voltageRange / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);

    updateConfig();

    // Procesamos la señal durante un breve tiempo para obtener una frecuencia con la que trabajar
    await Future.delayed(const Duration(milliseconds: 500));

    // Ahora calculamos los valores de timeScale y valueScale basándonos en la frecuencia obtenida
    if (_currentFrequency <= 0) {
      triggerLevel = 0;
      return [100000, 1];
    }

    // Cálculo de la escala de tiempo
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    final timeScale = chartWidth / totalTime;

    // Cálculo de la escala de valor considerando el valor absoluto más grande entre _currentMaxValue y _currentMinValue
    final maxAbsValue = max(_currentMaxValue.abs(), _currentMinValue.abs());
    final valueScale = maxAbsValue != 0 ? 1.0 / maxAbsValue : 1.0;

    updateConfig();

    return [timeScale, valueScale];
  }

  static double max(double a, double b) => a > b ? a : b;

  // Testing utilities
  @visibleForTesting
  Isolate? get socketIsolate => _socketIsolate;

  @visibleForTesting
  static DataProcessingConfig updateConfigForTest(
    DataProcessingConfig currentConfig,
    UpdateConfigMessage message,
  ) {
    return _updateConfig(currentConfig, message);
  }

  @visibleForTesting
  Isolate? get processingIsolate => _processingIsolate;

  @visibleForTesting
  SendPort? get socketToProcessingSendPort => _socketToProcessingSendPort;

  @visibleForTesting
  SendPort? get configSendPort => _configSendPort;

  @visibleForTesting
  set configSendPort(SendPort? value) => _configSendPort = value;

  @visibleForTesting
  void updateMetrics(
          List<DataPoint> points, double maxValue, double minValue) =>
      _updateMetrics(points, maxValue, minValue);

  @visibleForTesting
  set socketToProcessingSendPort(SendPort? value) {
    _socketToProcessingSendPort = value;
  }

  // 6. Corregir el método de prueba para que coincida con los cambios
  @visibleForTesting
  static List<DataPoint> processDataForTest(
    Queue<int> queue,
    int chunkSize,
    double scale,
    double distance,
    double triggerLevel,
    TriggerEdge triggerEdge,
    double mid,
    bool useHysteresis,
    bool useLowPassFilter,
    TriggerMode triggerMode,
    DeviceConfig deviceConfig,
    SendPort sendPort,
  ) {
    if (queue.isEmpty) {
      print('Empty queue in processDataForTest');
      return [];
    }

    final queueCopy = Queue<int>.from(queue);
    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      mid: mid,
      deviceConfig: deviceConfig,
      useHysteresis: useHysteresis,
      useLowPassFilter: useLowPassFilter,
      triggerMode: triggerMode,
    );

    final (points, _, _) = _processData(queueCopy, chunkSize, config, sendPort);
    return points;
  }

  // Agregar este método a DataAcquisitionService
  @visibleForTesting
  static (List<DataPoint>, bool) processSingleModeDataForTest(
    Queue<int> queue,
    double scale,
    double distance,
    double triggerLevel,
    TriggerEdge triggerEdge,
    double mid,
    bool useHysteresis,
    bool useLowPassFilter,
    DeviceConfig deviceConfig,
    int samplesPerPacket,
    SendPort sendPort,
  ) {
    if (queue.length < samplesPerPacket * 2) {
      return ([], false); // Not enough data
    }

    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      mid: mid,
      deviceConfig: deviceConfig,
      useHysteresis: useHysteresis,
      useLowPassFilter: useLowPassFilter,
      triggerMode: TriggerMode.single,
    );

    final queueCopy = Queue<int>.from(queue);
    final (points, maxValue, minValue) =
        _processData(queueCopy, samplesPerPacket * 2, config, sendPort);

    final hasTrigger = points.any((p) => p.isTrigger);
    return (points.take(samplesPerPacket).toList(), hasTrigger);
  }
}
