import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
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
  final double triggerSensitivity;
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
    required this.triggerSensitivity,
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
    double? triggerSensitivity,
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
      triggerSensitivity: triggerSensitivity ?? this.triggerSensitivity,
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
  final double triggerSensitivity;
  final bool useHysteresis;
  final bool useLowPassFilter;
  final TriggerMode triggerMode;

  const UpdateConfigMessage({
    required this.scale,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.triggerSensitivity,
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

  late final int _processingChunkSize;
  late final double _distance;
  late final double _mid;

  bool _disposed = false;
  bool _initialized = false;
  double _scale = 0;
  double _triggerLevel = 1;
  TriggerEdge _triggerEdge = TriggerEdge.positive;
  double _triggerSensitivity = 70.0;
  TriggerMode _triggerMode = TriggerMode.normal;
  VoltageScale _currentVoltageScale = VoltageScales.volts_2;
  bool _useHysteresis = false;
  bool _useLowPassFilter = false;

  // Metrics
  double _currentFrequency = 0.0;
  double _currentMaxValue = 0.0;
  double _currentMinValue = 0.0;
  double _currentAverage = 0.0;

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
      httpService = HttpService(httpConfig);
    } catch (e) {
      throw StateError('Failed to initialize DataAcquisitionService: $e');
    }
  }

  void _initializeFromDeviceConfig() {
    _processingChunkSize = deviceConfig.samplesPerPacket;
    _distance = 1 / deviceConfig.samplingFrequency;
    _mid = (1 << deviceConfig.usefulBits) / 2;
  }

  bool get useHysteresis => _useHysteresis;
  set useHysteresis(bool value) {
    _useHysteresis = value;
    updateConfig();
  }

  bool get useLowPassFilter => _useLowPassFilter;
  set useLowPassFilter(bool value) {
    _useLowPassFilter = value;
    updateConfig();
  }

  @override
  double get mid => _mid;

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
  double get distance => _distance;

  @override
  set distance(double value) {
    _distance = value;
    updateConfig();
  }

  @override
  double get triggerLevel => _triggerLevel;

  @override
  set triggerLevel(double value) {
    _triggerLevel = value;
    updateConfig();
  }

  @override
  TriggerEdge get triggerEdge => _triggerEdge;

  @override
  set triggerEdge(TriggerEdge value) {
    _triggerEdge = value;
    updateConfig();
  }

  @override
  double get triggerSensitivity => _triggerSensitivity;

  @override
  set triggerSensitivity(double value) {
    _triggerSensitivity = value;
    updateConfig();
  }

  @override
  TriggerMode get triggerMode => _triggerMode;

  @override
  set triggerMode(TriggerMode value) {
    _triggerMode = value;
    updateConfig();
  }

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

    receivePort.listen((message) {
      if (message == 'stop') {
        if (queue.isNotEmpty) {
          final points =
              _processData(queue, queue.length, config, setup.sendPort);
          setup.sendPort.send(points);
          queue.clear();
        }
      } else if (message is List<int>) {
        _processIncomingData(message, queue, config, setup.sendPort,
            maxQueueSize, processingChunkSize);
      } else if (message is UpdateConfigMessage) {
        config = _updateConfig(config, message);
      } else if (message is Map<String, dynamic>) {
        // Manejamos el caso "pause_graph"
        if (message['type'] == 'pause_graph') {
          // Simplemente reenviamos al isolate principal para pausar
          setup.sendPort.send({'type': 'pause_graph'});
        }
      }
    });
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
      final points = _processData(
        queue,
        processingChunkSize,
        config,
        sendPort,
      );
      sendPort.send(points);
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
      triggerSensitivity: message.triggerSensitivity,
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
  ) {
    final risingEdgeTrigger = triggerEdge == TriggerEdge.positive &&
        prevY < triggerLevel &&
        currentY >= triggerLevel;

    final fallingEdgeTrigger = triggerEdge == TriggerEdge.negative &&
        prevY > triggerLevel &&
        currentY <= triggerLevel;

    return risingEdgeTrigger || fallingEdgeTrigger;
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

  static List<DataPoint> _processData(
    Queue<int> queue,
    int chunkSize,
    DataProcessingConfig config,
    SendPort sendPort,
  ) {
    final points = <DataPoint>[];
    var firstTriggerX = 0.0;
    var lastTriggerIndex = -1;
    var foundFirstTrigger = false;
    var waitingForNextTrigger = false;
    // Low-pass filter setup
    final dt = 1.0 / config.deviceConfig.samplingFrequency;
    const cutoffFrequency = 50000.0;
    const rc = 1.0 / (2.0 * pi * cutoffFrequency);
    final alpha = dt / (rc + dt);
    var filteredY = 0.0;

    // Window for trend analysis
    const trendWindowSize = 5;
    final trendWindow = Queue<double>();

    for (var i = 0; i < chunkSize; i += 2) {
      if (queue.length < 2) break;

      final (uint12Value, _) = _readDataFromQueue(queue, config.deviceConfig);
      final (x, y) = _calculateCoordinates(uint12Value, points.length, config);

      // Apply low-pass filter for trigger detection if enabled
      final signalForTrigger = config.useLowPassFilter
          ? alpha * y + (1 - alpha) * (points.isEmpty ? y : filteredY)
          : y;
      filteredY = signalForTrigger;

      // Update trend window
      if (config.useHysteresis) {
        trendWindow.add(y);
        if (trendWindow.length > trendWindowSize) {
          trendWindow.removeFirst();
        }
      }

      if (points.isNotEmpty) {
        final prevY = points.last.y;
        bool isTriggerCandidate = _shouldTrigger(
            prevY, signalForTrigger, config.triggerLevel, config.triggerEdge);

        if (isTriggerCandidate && !waitingForNextTrigger) {
          bool validTrigger = true;

          if (config.useHysteresis && trendWindow.length >= trendWindowSize) {
            final trend = _calculateTrend(trendWindow.toList());
            validTrigger =
                (config.triggerEdge == TriggerEdge.positive && trend > 0) ||
                    (config.triggerEdge == TriggerEdge.negative && trend < 0);
          }

          if (validTrigger) {
            if (!foundFirstTrigger) {
              firstTriggerX = x;
              foundFirstTrigger = true;
            }
            lastTriggerIndex = points.length;
            points.add(DataPoint(x, y, isTrigger: true));
            waitingForNextTrigger = config.triggerMode == TriggerMode.normal;
            continue;
          }
        }

        // Reset waiting state only in normal mode
        if (waitingForNextTrigger && config.triggerMode == TriggerMode.normal) {
          final sensitivity = config.triggerSensitivity * config.scale;
          if (config.triggerEdge == TriggerEdge.positive) {
            if (signalForTrigger < (config.triggerLevel - sensitivity)) {
              waitingForNextTrigger = false;
            }
          } else {
            if (signalForTrigger > (config.triggerLevel + sensitivity)) {
              waitingForNextTrigger = false;
            }
          }
        }
      }

      points.add(DataPoint(x, y));
    }

    if (foundFirstTrigger && config.triggerMode == TriggerMode.single) {
      sendPort.send({'type': 'pause_graph'});
    }

    if (foundFirstTrigger) {
      return points
          .map((point) => DataPoint(
                point.x - firstTriggerX,
                point.y,
                isTrigger: point.isTrigger,
              ))
          .toList();
    }
    return points;
  }

  void _updateMetrics(List<DataPoint> points) {
    if (points.isEmpty) return;

    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = points.map((p) => p.y).reduce(max);
    _currentMinValue = points.map((p) => p.y).reduce(min);
    _currentAverage =
        points.map((p) => p.y).reduce((a, b) => a + b) / points.length;

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

    _processingReceivePort = ReceivePort();
    final processingStream = _processingReceivePort!.asBroadcastStream();

    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      triggerSensitivity: triggerSensitivity,
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
      } else if (message is List<DataPoint>) {
        _dataController.add(message);
        _updateMetrics(message);
      } else if (message is Map<String, dynamic>) {
        if (message['type'] == 'pause_graph') {
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
      triggerSensitivity: triggerSensitivity,
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
      _currentAverage = 0.0;

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
  List<double> autoset(double chartHeight, double chartWidth) {
    if (_currentFrequency <= 0) return [1.0, 1.0];

    // Time scale calculation
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    final timeScale = chartWidth / totalTime;

    // Value scale calculation
    final valueScale =
        _currentMaxValue != 0 ? 1.0 / _currentMaxValue.abs() : 1.0;

    // Set trigger to midpoint between max and min
    triggerLevel = (_currentMaxValue + _currentMinValue) / 2;

    // Ensure trigger is within voltage range
    final voltageRange =
        _currentVoltageScale.scale * pow(2,deviceConfig.usefulBits);
    final halfRange = voltageRange / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);

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
  void updateMetrics(List<DataPoint> points) => _updateMetrics(points);

  @visibleForTesting
  set socketToProcessingSendPort(SendPort? value) {
    _socketToProcessingSendPort = value;
  }

  @visibleForTesting
  static List<DataPoint> processDataForTest(
    Queue<int> queue,
    int chunkSize,
    double scale,
    double distance,
    double triggerLevel,
    TriggerEdge triggerEdge,
    double triggerSensitivity,
    double mid,
    DeviceConfig deviceConfig,
    SendPort sendPort,
  ) {
    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      triggerSensitivity: triggerSensitivity,
      mid: mid,
      deviceConfig: deviceConfig,
    );
    return _processData(queue, chunkSize, config, sendPort);
  }
}
