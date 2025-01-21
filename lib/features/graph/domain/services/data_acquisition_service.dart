import 'dart:async';
import 'dart:isolate';
import 'dart:math';
import 'dart:typed_data';
import 'dart:collection';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:meta/meta.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import '../models/data_point.dart';
import '../repository/data_acquisition_repository.dart';
import '../../../http/domain/services/http_service.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../models/trigger_data.dart';

// Configurations
const int _processingChunkSize = 8192 * 2;
const int _maxQueueSize = _processingChunkSize * 6;
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

  const ProcessingIsolateSetup(this.sendPort, this.config);
}

class DataProcessingConfig {
  final double scale;
  final double distance;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double triggerSensitivity;
  final double mid;
  final TriggerMode triggerMode;

  const DataProcessingConfig({
    required this.scale,
    required this.distance,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.triggerSensitivity,
    required this.mid,
    this.triggerMode = TriggerMode.hysteresis,
  });
}

class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double triggerSensitivity;
  final TriggerMode triggerMode;

  const UpdateConfigMessage({
    required this.scale,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.triggerSensitivity,
    required this.triggerMode,
  });
}

class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _frequencyController = StreamController<double>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  late final HttpService httpService;

  bool _disposed = false;

  // Configuration with default values
  double _scale = 0;
  double _mid = 512 / 2;
  double _distance = 1 / 1650000;
  double _triggerLevel = 1;
  TriggerEdge _triggerEdge = TriggerEdge.positive;
  double _triggerSensitivity = 70.0;
  TriggerMode _triggerMode = TriggerMode.hysteresis;

  // Metrics
  double _currentFrequency = 0.0;
  double _currentMaxValue = 0.0;
  double _currentAverage = 0.0;
  VoltageScale _currentVoltageScale = VoltageScales.volts_2;

  // Isolates and ports
  Isolate? _socketIsolate;
  Isolate? _processingIsolate;
  ReceivePort? _processingReceivePort;
  SendPort? _configSendPort;
  SendPort? _socketToProcessingSendPort;

  DataAcquisitionService(this.httpConfig) {
    httpService = HttpService(httpConfig);
    setVoltageScale(VoltageScales.volt_1);
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
    // Configuration will be updated when services are ready
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

    // Add exit handler
    final exitPort = ReceivePort();
    Isolate.current.addOnExitListener(exitPort.sendPort);
    exitPort.listen((_) {
      print('Processing isolate exiting, cleaning up...');
      receivePort.close();
      exitPort.close();
    });

    var config = setup.config;
    final queue = Queue<int>();

    receivePort.listen((message) {
      if (message == 'stop') {
        // Process remaining data
        if (queue.isNotEmpty) {
          final points = _processData(queue, queue.length, config);
          setup.sendPort.send(points);
          queue.clear();
        }
      } else if (message is List<int>) {
        _processIncomingData(message, queue, config, setup.sendPort);
      } else if (message is UpdateConfigMessage) {
        config = _updateConfig(config, message);
      }
    });
  }

  static void _processIncomingData(
    List<int> data,
    Queue<int> queue,
    DataProcessingConfig config,
    SendPort sendPort,
  ) {
    queue.addAll(data);

    while (queue.length > _maxQueueSize) {
      queue.removeFirst();
    }

    while (queue.length >= _processingChunkSize) {
      final points = _processData(queue, _processingChunkSize, config);
      sendPort.send(points);
    }
  }

  static DataProcessingConfig _updateConfig(
    DataProcessingConfig currentConfig,
    UpdateConfigMessage message,
  ) {
    return DataProcessingConfig(
      scale: message.scale,
      distance: currentConfig.distance,
      triggerLevel: message.triggerLevel,
      triggerEdge: message.triggerEdge,
      triggerSensitivity: message.triggerSensitivity,
      mid: currentConfig.mid,
    );
  }

  static (int value, int channel) _readDataFromQueue(Queue<int> queue) {
    final bytes = [queue.removeFirst(), queue.removeFirst()];
    final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint16(0, Endian.little);

    final uint12Value = uint16Value & 0x0FFF;
    final channel = (uint16Value >> 12) & 0x0F;

    return (uint12Value, channel);
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

  static List<DataPoint> _processData(
    Queue<int> queue,
    int chunkSize,
    DataProcessingConfig config,
  ) {
    final points = <DataPoint>[];
    var firstTriggerX = 0.0;
    var lastTriggerIndex = -1;
    var foundFirstTrigger = false;
    var waitingForHysteresis = false;

    // Low-pass filter coefficients for 50kHz
    const double dt = 1.0 / 1600000.0; // Sampling period
    const double rc = 1.0 / (2.0 * pi * 50000.0); // Time constant for 50kHz
    const double alpha = dt / (rc + dt);
    var filteredY = 0.0;

    for (var i = 0; i < chunkSize; i += 2) {
      if (queue.length < 2) break;

      final (uint12Value, _) = _readDataFromQueue(queue);
      final (x, y) = _calculateCoordinates(uint12Value, points.length, config);

      // Apply low-pass filter only for trigger detection
      filteredY = config.triggerMode == TriggerMode.lowPassFilter
          ? alpha * y + (1 - alpha) * (points.isEmpty ? y : filteredY)
          : y;

      if (points.isNotEmpty) {
        final prevY = points.length > 1
            ? (config.triggerMode == TriggerMode.lowPassFilter
                ? filteredY
                : points[points.length - 2].y)
            : filteredY;
        final currentY =
            config.triggerMode == TriggerMode.lowPassFilter ? filteredY : y;

        bool shouldAddTrigger = false;

        if (config.triggerMode == TriggerMode.hysteresis) {
          if (!waitingForHysteresis) {
            if (_shouldTrigger(
                prevY, currentY, config.triggerLevel, config.triggerEdge)) {
              shouldAddTrigger = true;
              waitingForHysteresis = true;
            }
          } else {
            if (config.triggerEdge == TriggerEdge.positive) {
              if (currentY <
                  (config.triggerLevel -
                      (config.triggerSensitivity * config.scale))) {
                waitingForHysteresis = false;
              }
            } else {
              if (currentY >
                  (config.triggerLevel +
                      (config.triggerSensitivity * config.scale))) {
                waitingForHysteresis = false;
              }
            }
          }
        } else {
          // Using filtered signal only for trigger detection
          if (_shouldTrigger(
              prevY, currentY, config.triggerLevel, config.triggerEdge)) {
            shouldAddTrigger = true;
          }
        }

        if (shouldAddTrigger) {
          if (!foundFirstTrigger) {
            firstTriggerX = x;
            foundFirstTrigger = true;
          }
          lastTriggerIndex = points.length;
          points.add(DataPoint(x, y, isTrigger: true));
          continue;
        }
      }

      points.add(DataPoint(x, y));
    }

    if (foundFirstTrigger) {
      final endIndex =
          lastTriggerIndex != -1 ? lastTriggerIndex + 1 : points.length;
      return points
          .sublist(0, endIndex)
          .map((point) => DataPoint(point.x - firstTriggerX, point.y,
              isTrigger: point.isTrigger))
          .toList();
    }

    return points;
  }

  void _updateMetrics(List<DataPoint> points) {
    if (points.isEmpty) return;

    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = points.map((p) => p.y).reduce(max);
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
    );

    _processingIsolate = await Isolate.spawn(
      _processingIsolateFunction,
      ProcessingIsolateSetup(_processingReceivePort!.sendPort, config),
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
      triggerMode: triggerMode, // Add missing parameter
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

    // Time scale calculation - igual que antes
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    final timeScale = chartWidth / totalTime;

    // Value scale calculation - ajustado para la escala actual
    final valueScale =
        _currentMaxValue != 0 ? 1.0 / _currentMaxValue.abs() : 1.0;

    // Set trigger to average - ajustado para la escala actual
    triggerLevel = _currentAverage;

    // Ensure trigger is within voltage range
    final voltageRange = _currentVoltageScale.scale * 512;
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
  ) {
    final config = DataProcessingConfig(
      scale: scale,
      distance: distance,
      triggerLevel: triggerLevel,
      triggerEdge: triggerEdge,
      triggerSensitivity: triggerSensitivity,
      mid: mid,
    );
    return _processData(queue, chunkSize, config);
  }
}
