import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';
import 'dart:collection';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/domain/repository/data_acquisition_repository.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';

extension CompleterExtension<T> on Completer<T> {
  bool get isCompleted {
    var completed = false;
    Future.sync(() =>
        future.then((_) => completed = true, onError: (_) => completed = true));
    return completed;
  }
}

// Message classes for isolate communication
/// [SocketIsolateSetup] configures the socket isolate with necessary parameters.
class SocketIsolateSetup {
  final SendPort sendPort;
  final String ip;
  final int port;
  final int packetSize;

  const SocketIsolateSetup(this.sendPort, this.ip, this.port, this.packetSize);
}

/// [ProcessingIsolateSetup] configures the processing isolate with data processing parameters.
class ProcessingIsolateSetup {
  final SendPort sendPort;
  final DataProcessingConfig config;
  final DeviceConfig deviceConfig;

  const ProcessingIsolateSetup(this.sendPort, this.config, this.deviceConfig);
}

/// [DataProcessingConfig] holds the configuration for data processing.
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

/// [UpdateConfigMessage] is used to send configuration updates to the processing isolate.
class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final bool useHysteresis;
  final bool useLowPassFilter;
  final TriggerMode triggerMode;
  final double distance;
  final DeviceConfig? deviceConfig;

  const UpdateConfigMessage({
    required this.scale,
    required this.triggerLevel,
    required this.triggerEdge,
    required this.useHysteresis,
    required this.useLowPassFilter,
    required this.triggerMode,
    required this.distance,
    this.deviceConfig,
  });
}

/// [DataAcquisitionService] implements the [DataAcquisitionRepository] to manage data acquisition, processing, and control.
class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  late final DeviceConfigProvider deviceConfig;

  // Use nullable StreamControllers and initialize them as needed
  StreamController<List<DataPoint>>? _dataController;
  StreamController<double>? _frequencyController;
  StreamController<double>? _maxValueController;

  late final HttpService httpService;
  bool _isReconnecting = false;

  bool _disposed = false;
  bool _initialized = false;
  double _scale = 0;
  double _triggerLevel = 1;
  // ignore: unused_field
  double _distance = 0.0;
  // ignore: unused_field
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

  /// Creates a new DataAcquisitionService instance
  DataAcquisitionService(this.httpConfig) {
    try {
      deviceConfig = Get.find<DeviceConfigProvider>();
      if (deviceConfig.config == null) {
        throw StateError('DeviceConfigProvider has no configuration');
      }
      httpService = Get.find<HttpService>();
      _ensureControllersExist();
    } catch (e) {
      throw StateError('Failed to initialize DataAcquisitionService: $e');
    }
  }

  // Create or recreate stream controllers if they're closed
  void _ensureControllersExist() {
    if (_disposed) {
      _disposed = false; // Reset the disposed flag when recreating controllers
    }

    if (_dataController == null || _dataController!.isClosed) {
      _dataController = StreamController<List<DataPoint>>.broadcast();
    }

    if (_frequencyController == null || _frequencyController!.isClosed) {
      _frequencyController = StreamController<double>.broadcast();
    }

    if (_maxValueController == null || _maxValueController!.isClosed) {
      _maxValueController = StreamController<double>.broadcast();
    }
  }

  @override
  Future<void> sendSingleTriggerRequest() async {
    try {
      await httpService.get('/single');
    } catch (e) {
      if (kDebugMode) {
        print('Error sending single trigger request: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> sendNormalTriggerRequest() async {
    try {
      await httpService.get('/normal');
    } catch (e) {
      if (kDebugMode) {
        print('Error sending normal trigger request: $e');
      }
      rethrow;
    }
  }

  /// Initializes the service from the device configuration.
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
  double get mid {
    if (kDebugMode) {
      print('Mid: ${deviceConfig.midBits}');
    }
    return deviceConfig.midBits.toDouble();
  }

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

  /// Sends the trigger configuration to the device via HTTP.
  @override
  Future<void> postTriggerStatus() async {
    try {
      // Convert voltage trigger to raw value considering the new scaling
      final range = deviceConfig.maxBits - deviceConfig.minBits;
      final rawTrigger = (_triggerLevel / scale) + deviceConfig.midBits;

      // Calculate percentage based on the full range
      final percentage = ((rawTrigger - deviceConfig.minBits) / range) * 100;

      await httpService.post(
          '/trigger',
          {
            'trigger_percentage': percentage.clamp(0, 100),
            'trigger_edge':
                _triggerEdge == TriggerEdge.positive ? 'positive' : 'negative',
          },
          true);
    } catch (e) {
      if (kDebugMode) {
        print('Error posting trigger status: $e');
      }
      rethrow;
    }
  }

  @override
  double get triggerLevel => _triggerLevel;

  @override
  set triggerLevel(double value) {
    // Calculate voltage range based on current scale and bits
    final range = _currentVoltageScale.scale *
        (deviceConfig.maxBits - deviceConfig.minBits);
    final halfRange = range / 2;

    // Clamp the trigger level to the valid voltage range
    _triggerLevel = value.clamp(-halfRange, halfRange);

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
    _ensureControllersExist();
    return _dataController!.stream;
  }

  @override
  Stream<double> get frequencyStream {
    _ensureControllersExist();
    return _frequencyController!.stream;
  }

  @override
  VoltageScale get currentVoltageScale => _currentVoltageScale;

  @override
  Stream<double> get maxValueStream {
    _ensureControllersExist();
    return _maxValueController!.stream;
  }

  @override
  void setVoltageScale(VoltageScale voltageScale) {
    if (kDebugMode) {
      print('Setting voltage scale to: ${voltageScale.scale}');
    }
    final oldScale = _currentVoltageScale.scale;
    _currentVoltageScale = voltageScale;
    scale = voltageScale.scale;

    // Adjust trigger level proportionally to new scale
    final ratio = voltageScale.scale / oldScale;
    triggerLevel *= ratio;

    // Clamp trigger level to new voltage range
    final range =
        voltageScale.scale * (deviceConfig.maxBits - deviceConfig.minBits);
    final halfRange = range / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);

    updateConfig();
  }

  Future<void> increaseSamplingFrequency() async {
    try {
      final response = await httpService.post('/freq', {'action': 'more'});
      if (response['sampling_frequency'] != null) {
        final newFreq = double.parse(response['sampling_frequency'].toString());
        if (kDebugMode) {
          print('New sampling frequency: $newFreq');
          Get.snackbar(
              'New sampling frequency', 'New sampling frequency: $newFreq');
        }
        deviceConfig.updateConfig(deviceConfig.config!.copyWith(
          samplingFrequency: newFreq,
        ));
        if (kDebugMode) {
          print('New sampling frequency: $newFreq');
        }
        updateConfig();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating sampling frequency: $e');
        //Snackbar for debug
        Get.snackbar('Error', 'Error updating sampling frequency: $e');
      }
      rethrow;
    }
  }

  Future<void> decreaseSamplingFrequency() async {
    try {
      final response = await httpService.post('/freq', {'action': 'less'});
      if (response['sampling_frequency'] != null) {
        final newFreq = double.parse(response['sampling_frequency'].toString());
        if (kDebugMode) {
          print('New sampling frequency: $newFreq');
          Get.snackbar(
              'New sampling frequency', 'New sampling frequency: $newFreq');
        }
        deviceConfig.updateConfig(deviceConfig.config!.copyWith(
          samplingFrequency: newFreq,
        ));
        if (kDebugMode) {
          print('New sampling frequency: $newFreq');
        }
        updateConfig();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error updating sampling frequency: $e');
        Get.snackbar('Error', 'Error updating sampling frequency: $e');
      }
      rethrow;
    }
  }

  @override
  Future<void> initialize() async {
    if (_initialized) return;
    setVoltageScale(VoltageScales.volt_1);
    _initializeFromDeviceConfig();
    _initialized = true;
  }

  /// Isolate function for handling socket connections.
  static Future<void> _socketIsolateFunction(SocketIsolateSetup setup) async {
    final socketService = SocketService(setup.packetSize);
    final connection = SocketConnection(setup.ip, setup.port);
    final exitPort = ReceivePort();
    final errorPort = ReceivePort(); // New dedicated error port

    runZonedGuarded(() async {
      Isolate.current.addOnExitListener(exitPort.sendPort);
      Isolate.current
          .addErrorListener(errorPort.sendPort); // Add error listener

      exitPort.listen((_) async {
        await socketService.close();
        exitPort.close();
        errorPort.close();
      });

      // Listen for errors on the isolate level
      errorPort.listen((error) {
        if (kDebugMode) {
          print("Socket isolate error from error port: $error");
        }
        // Send error directly to main isolate
        setup.sendPort.send({
          'type': 'connection_error',
          'error': 'Socket isolate error: $error',
          'critical': true // Mark as critical
        });
      });

      bool isConnected = false;
      int retryCount = 0;
      const maxRetries = 3;

      while (!isConnected && retryCount < maxRetries) {
        try {
          await socketService.connect(connection).timeout(
                const Duration(seconds: 5),
                onTimeout: () =>
                    throw TimeoutException('Socket connection timeout'),
              );

          isConnected = true;
          if (kDebugMode) {
            print(
                "Socket connected to ${connection.ip.value}:${connection.port.value}");
            print("Packet size: ${setup.packetSize}");
          }

          // Register a direct error handler on the socket
          socketService.onError((error) {
            if (kDebugMode) {
              print("Socket error detected: $error");
            }

            // Send error message with high priority
            setup.sendPort.send({
              'type': 'connection_error',
              'error': error.toString(),
              'critical': true // Mark as critical for immediate handling
            });

            // Force isolate to exit on critical errors
            if (error is SocketException) {
              Isolate.current.kill(priority: Isolate.immediate);
            }
          });

          _setupSocketListener(socketService, setup.sendPort);
        } catch (e) {
          retryCount++;
          if (kDebugMode) {
            print("Socket connection attempt $retryCount failed: $e");
          }

          if (retryCount >= maxRetries) {
            setup.sendPort.send({
              'type': 'connection_error',
              'error': 'Failed to connect after $maxRetries attempts: $e',
              'critical': true
            });
            return;
          }
          await Future.delayed(Duration(seconds: 1));
        }
      }
    }, (error, stack) {
      // This catches any uncaught error in the isolate
      if (kDebugMode) {
        print("Socket isolate uncaught error: $error");
        print(stack);
      }

      // Send error with high priority
      setup.sendPort.send({
        'type': 'connection_error',
        'error': 'Uncaught socket error: $error',
        'critical': true
      });
    });
  }

  /// Sets up the socket listener to receive data and send it to the main isolate.
  static void _setupSocketListener(
      SocketService socketService, SendPort sendPort) {
    socketService.listen();
    socketService.subscribe(sendPort.send);
  }

  // New helper function to handle single mode processing
  /// Processes data in single trigger mode.
  static List<DataPoint>? _handleSingleModeProcessing(
    Queue<int> singleModeQueue,
    int processingChunkSize,
    DataProcessingConfig config,
    SendPort sendPort,
  ) {
    // If we have enough data to process
    if (singleModeQueue.length >= processingChunkSize) {
      final tempQueue = Queue<int>.from(singleModeQueue);
      final (points, maxValue, minValue) =
          _processData(tempQueue, singleModeQueue.length, config, sendPort);

      // If we find a trigger, send and return the points
      if (points.isNotEmpty && points.any((p) => p.isTrigger)) {
        sendPort.send({
          'type': 'data',
          'points': points,
          'maxValue': maxValue,
          'minValue': minValue
        });
        return points;
      }
    }
    return null;
  }

  // New helper function to handle normal mode processing
  /// Processes data in normal trigger mode.
  static void _handleNormalModeProcessing(
    Queue<int> queue,
    int processingChunkSize,
    DataProcessingConfig config,
    SendPort sendPort,
  ) {
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

  // New helper function to manage queue size
  /// Manages the size of the data queue.
  static void _manageQueueSize(
    Queue<int> queue,
    List<int> newData,
    int maxQueueSize,
    int processingChunkSize,
  ) {
    queue.addAll(newData);
    while (queue.length > maxQueueSize) {
      for (var i = 0; i < processingChunkSize; i++) {
        if (queue.isNotEmpty) queue.removeFirst();
      }
    }
  }

  /// Isolate function for processing data.
  static void _processingIsolateFunction(ProcessingIsolateSetup setup) {
    final receivePort = ReceivePort();
    setup.sendPort.send(receivePort.sendPort);

    var config = setup.config;
    final processingChunkSize = setup.deviceConfig.samplesPerPacket;
    final maxQueueSize = processingChunkSize;
    final queue = Queue<int>();
    final singleModeQueue = Queue<int>();
    final maxSingleModeQueueSize = processingChunkSize;
    bool processingEnabled = true;

    receivePort.listen((message) {
      // First check if it's an error message from socket - give it highest priority
      if (message is Map<String, dynamic> &&
          message['type'] == 'connection_error') {
        // Forward error messages immediately to main isolate, skipping processing
        setup.sendPort.send(message);
        return;
      }

      // Process normal messages as before
      if (message == 'stop') {
        processingEnabled = false;
        queue.clear();
        singleModeQueue.clear();
      } else if (message == 'clear_queue') {
        queue.clear();
        singleModeQueue.clear();
        processingEnabled = true;
      } else if (message is List<int> && processingEnabled) {
        if (config.triggerMode == TriggerMode.single) {
          _manageQueueSize(singleModeQueue, message, maxSingleModeQueueSize,
              processingChunkSize);

          final points = _handleSingleModeProcessing(
              singleModeQueue, processingChunkSize, config, setup.sendPort);

          if (points != null) {
            setup.sendPort.send({'type': 'pause_graph'});
            singleModeQueue.clear();
            processingEnabled = false;
          }
        } else {
          // Normal mode
          _manageQueueSize(queue, message, maxQueueSize, processingChunkSize);
          _handleNormalModeProcessing(
              queue, processingChunkSize, config, setup.sendPort);
        }
      } else if (message is UpdateConfigMessage) {
        config = _updateConfig(config, message);
        if (config.triggerMode == TriggerMode.normal) {
          processingEnabled = true;
        }
        queue.clear();
        singleModeQueue.clear();
      }
    });
  }

  /// Updates the data processing configuration.
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
      distance: message.distance,
      deviceConfig: message.deviceConfig ?? currentConfig.deviceConfig,
    );
  }

  /// Reads data from the queue and extracts the value and channel.
  static (int value, int channel) _readDataFromQueue(
    Queue<int> queue,
    DeviceConfig deviceConfig,
  ) {
    final bytes = [queue.removeFirst(), queue.removeFirst()];
    final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
        .getUint16(0, Endian.little);

    // Apply masks and shift as needed
    final value = (uint16Value & deviceConfig.dataMask) >>
        deviceConfig.dataMaskTrailingZeros;

    if (deviceConfig.channelMask == 0) {
      return (value, 0);
    }

    // Apply channel mask and shift by trailing zeros
    final channel = (uint16Value & deviceConfig.channelMask) >>
        deviceConfig.channelMaskTrailingZeros;

    return (value, channel);
  }

  /// Calculates the x and y coordinates from the raw data.
  static (double x, double y) _calculateCoordinates(
    int uint12Value,
    int pointsLength,
    DataProcessingConfig config,
  ) {
    final x = pointsLength * config.distance;
    final y = (uint12Value - config.mid) * config.scale;
    return (x, y);
  }

  /// Determines if a trigger should occur based on the signal characteristics.
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
      return shouldTrig;
    } else {
      // For negative edge, only check if we cross the trigger level downwards
      final shouldTrig = prevY > triggerLevel && currentY <= triggerLevel;
      return shouldTrig;
    }
  }

  // Helper method to calculate trend
  /// Calculates the trend of a list of values.
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

  /// Applies a low-pass filter to the trigger signal.
  static List<double> _applyTriggerFilter(
      List<DataPoint> points, double samplingFrequency,
      {double cutoffFrequency = 50000.0}) {
    if (points.isEmpty) {
      return [];
    }
    final filter = LowPassFilter();
    final filteredPoints = filter.apply(
        points,
        {
          'cutoffFrequency': cutoffFrequency,
          'samplingFrequency': samplingFrequency,
        },
        doubleFilt: true);

    return filteredPoints.map((p) => p.y).toList();
  }

  /// Processes the data to extract data points and apply triggering logic.
  /// Preserves original data points when they exactly match the trigger level.
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

    // Extract data points from queue
    for (var i = 0; i < (chunkSize ~/ 2); i++) {
      if (queue.length < 2) break;
      if (i % config.deviceConfig.dividingFactor == 0) {
        final (uint12Value, _) = _readDataFromQueue(queue, config.deviceConfig);
        final (x, y) =
            _calculateCoordinates(uint12Value, points.length, config);
        points.add(DataPoint(x, y));

        maxValue = max(maxValue, y);
        minValue = min(minValue, y);
      } else {
        queue.removeFirst();
        queue.removeFirst();
      }
    }

    if (points.isEmpty) {
      return ([], 0.0, 0.0);
    }

    // Apply trigger logic to remaining points
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

    // Create a copy of the original points for processing
    final result = List<DataPoint>.from(points);

    // Process points for trigger detection
    for (var i = 1; i < points.length; i++) {
      final prevPoint = points[i - 1];
      final currentPoint = points[i];
      final prevY = signalForTrigger[i - 1];
      final currentY = signalForTrigger[i];

      // Check for exact match to trigger level first
      final bool exactMatch =
          prevY == config.triggerLevel || currentY == config.triggerLevel;

      // Check if this pair of points contains a trigger crossing
      bool isTriggerCandidate = exactMatch ||
          _shouldTrigger(prevY, currentY, config.triggerLevel,
              config.triggerEdge, triggerSensitivity, maxValue, minValue);

      if (isTriggerCandidate && !waitingForNextTrigger) {
        bool validTrigger = true;

        if (config.useHysteresis && !exactMatch) {
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
          DataPoint triggerPoint;

          // If we have an exact match, mark the existing point as trigger instead of interpolating
          if (exactMatch) {
            // Use the original point that matches the trigger level
            if (prevY == config.triggerLevel) {
              result[i - 1] =
                  DataPoint(prevPoint.x, prevPoint.y, isTrigger: true);
              triggerPoint = result[i - 1];
            } else {
              // currentY == config.triggerLevel
              result[i] =
                  DataPoint(currentPoint.x, currentPoint.y, isTrigger: true);
              triggerPoint = result[i];
            }
          } else {
            // Interpolate to find exact trigger point
            triggerPoint = _interpolateTriggerPoint(prevPoint.x, prevY,
                currentPoint.x, currentY, config.triggerLevel);

            // Replace the previous point with the interpolated trigger point
            result[i - 1] = triggerPoint;
          }

          if (!foundFirstTrigger) {
            firstTriggerX = triggerPoint.x;
            foundFirstTrigger = true;
          }

          if (config.triggerMode == TriggerMode.normal) {
            waitingForNextTrigger = true;
          } else if (config.triggerMode == TriggerMode.single) {
            waitingForNextTrigger = false;
          }
        }
      }

      // Handle waitingForNextTrigger reset conditions
      if (waitingForNextTrigger && config.triggerMode == TriggerMode.normal) {
        if (config.triggerEdge == TriggerEdge.positive) {
          // Reset only when signal goes below trigger level by sensitivity margin
          if (currentY < (config.triggerLevel - triggerSensitivity)) {
            waitingForNextTrigger = false;
          }
        } else {
          // Reset only when signal goes above trigger level by sensitivity margin
          if (currentY > (config.triggerLevel + triggerSensitivity)) {
            waitingForNextTrigger = false;
          }
        }
      }
    }

    final adjustedPoints = foundFirstTrigger
        ? result
            .map((p) =>
                DataPoint(p.x - firstTriggerX, p.y, isTrigger: p.isTrigger))
            .toList()
        : points;

    return (adjustedPoints, maxValue, minValue);
  }

  /// Interpolates to find the exact point where signal crosses trigger level
  static DataPoint _interpolateTriggerPoint(
      double x1, double y1, double x2, double y2, double triggerLevel) {
    // If the points are identical or already at trigger level
    if (y1 == y2 || y1 == triggerLevel) {
      return DataPoint(x1, triggerLevel, isTrigger: true, isInterpolated: true);
    }
    if (y2 == triggerLevel) {
      return DataPoint(x2, triggerLevel, isTrigger: true, isInterpolated: true);
    }

    // Calculate the ratio for linear interpolation
    final ratio = (triggerLevel - y1) / (y2 - y1);

    // Calculate the x coordinate where the line crosses the trigger level
    final xTrigger = x1 + ratio * (x2 - x1);

    return DataPoint(xTrigger, triggerLevel,
        isTrigger: true, isInterpolated: true);
  }

  @override
  void clearQueues() {
    _configSendPort?.send('clear_queue');
  }

  /// Updates the metrics (frequency, max value, min value) based on the processed data.
  void _updateMetrics(
      List<DataPoint> points, double maxValue, double minValue) {
    if (points.isEmpty || _disposed) return;

    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = maxValue;
    _currentMinValue = minValue;

    _ensureControllersExist();
    _frequencyController!.add(_currentFrequency);
    _maxValueController!.add(_currentMaxValue);
  }

  /// Calculates the frequency of the signal based on the trigger points.
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

  /// Handles connection errors by attempting to reconnect or navigating to the setup screen.
  Future<void> _handleConnectionError() async {
    if (_isReconnecting) {
      if (kDebugMode) {
        print('Already handling reconnection, ignoring duplicate call');
      }
      return;
    }
    _isReconnecting = true;

    if (kDebugMode) {
      print('Handling connection error. Attempting to reconnect first...');
    }

    try {
      // Check if we're already on the setup screen
      final currentRoute = Get.currentRoute;
      if (currentRoute == '/' || currentRoute.contains('SetupScreen')) {
        if (kDebugMode) {
          print('Already on setup screen, stopping reconnection attempts');
        }
        _isReconnecting = false;
        return;
      }
      // First notify the user we're attempting to reconnect
      Get.snackbar(
        'Connection issue detected',
        'Attempting to reconnect...',
        duration: const Duration(seconds: 3),
      );

      // Try to get new connection parameters without cleaning up first
      final response = await httpService.get('/reset').timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Server not responding'),
          );

      // If we got here, the server is still reachable - try to reconnect
      final newIp = response['ip'] as String;
      final newPort = response['port'] as int;

      // Only minimal cleanup before attempting new connection
      await stopData();

      // Reset reconnecting flag before attempting new connection
      _isReconnecting = false;

      // Update the socket connection in the provider
      try {
        final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();
        dataAcquisitionProvider.socketConnection
            .updateConnection(newIp, newPort);

        // The provider will automatically restart acquisition due to the socket connection changes
        // but we'll add a message to confirm reconnection
        Get.snackbar(
          'Connection restored',
          'Reconnected to $newIp:$newPort',
          duration: const Duration(seconds: 3),
        );
      } catch (e) {
        if (kDebugMode) {
          print('Error updating socket connection in provider: $e');
        }
        // If we can't update the provider, try direct reconnection
        await fetchData(newIp, newPort);

        Get.snackbar(
          'Connection restored',
          'The connection has been successfully restored',
          duration: const Duration(seconds: 3),
        );
      }
    } catch (e) {
      if (kDebugMode) {
        print('Failed to reconnect: $e - Now cleaning up resources...');
      }

      // Only clean up resources if reconnection failed
      try {
        // Make sure all resources are released
        await stopData();

        // Ensure we're really disconnected
        _processingIsolate = null;
        _socketIsolate = null;
        _processingReceivePort = null;
        _socketToProcessingSendPort = null;
        _configSendPort = null;

        _isReconnecting = false;

        // Navigate to setup screen since reconnection failed
        final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();
        dataAcquisitionProvider.handleCriticalError('Connection lost: $e');
      } catch (cleanupError) {
        if (kDebugMode) {
          print('Error during cleanup: $cleanupError');
        }
        _isReconnecting = false;

        // Even if cleanup fails, try to navigate back to setup
        final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();
        dataAcquisitionProvider.handleCriticalError(
            'Connection lost: $e (Cleanup error: $cleanupError)');
      }
    }
  }

  @override
  Future<void> fetchData(String ip, int port) async {
    await stopData();
    await initialize();

    _ensureControllersExist(); // Make sure controllers are created or recreated

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

    // Clear any previous data on start
    _dataController?.add([]);

    _processingIsolate = await Isolate.spawn(
      _processingIsolateFunction,
      ProcessingIsolateSetup(
          _processingReceivePort!.sendPort, config, deviceConfig.config!),
    );

    await _setupProcessingIsolate(processingStream);
    await _setupSocketIsolate(ip, port);
  }

  /// Sets up the processing isolate to receive data and send it to the main isolate.
  Future<void> _setupProcessingIsolate(Stream processingStream) async {
    final completer = Completer<SendPort>();

    processingStream.listen((message) {
      if (message is SendPort) {
        _socketToProcessingSendPort = message;
        _configSendPort = message;
        completer.complete(message);
      } else if (message is Map<String, dynamic>) {
        // Check for critical connection errors first with highest priority
        if (message['type'] == 'connection_error') {
          final errorMsg =
              message['error']?.toString() ?? 'Unknown socket error';
          final isCritical = message['critical'] == true;

          if (kDebugMode) {
            print(
                'Received ${isCritical ? "CRITICAL " : ""}connection error: $errorMsg');
          }

          // Check if we're already handling an error or already on the setup screen
          if (_isReconnecting) {
            if (kDebugMode) {
              print('Already handling reconnection, ignoring duplicate error');
            }
            return;
          }

          // Only handle if critical
          if (isCritical) {
            // Run on next event loop iteration to avoid potential race conditions
            Future.microtask(() => _handleConnectionError());
          }
          return; // Skip other processing for error messages
        }

        // Process normal messages
        if (message['type'] == 'data') {
          if (_disposed) return; // Skip if disposed

          final points = message['points'] as List<DataPoint>;
          final maxValue = message['maxValue'] as double;
          final minValue = message['minValue'] as double;

          _ensureControllersExist();
          _dataController?.add(points);
          _updateMetrics(points, maxValue, minValue);
        } else if (message['type'] == 'pause_graph') {
          Get.find<DataAcquisitionProvider>().setPause(true);
        }
      }
    }, onError: (error) {
      if (kDebugMode) {
        print('Processing stream error: $error');
      }

      // Only handle error if not already reconnecting
      if (!_isReconnecting) {
        Future.microtask(() => _handleConnectionError());
      }
    }, cancelOnError: false);

    _socketToProcessingSendPort = await completer.future;
  }

  /// Sets up the socket isolate to receive data from the socket and send it to the processing isolate.
  Future<void> _setupSocketIsolate(String ip, int port) async {
    final packetSize = deviceConfig.samplesPerPacket; // 2 bytes per sample

    _socketIsolate = await Isolate.spawn(
      _socketIsolateFunction,
      SocketIsolateSetup(_socketToProcessingSendPort!, ip, port, packetSize),
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
      distance: distance,
      deviceConfig: deviceConfig.config,
    ));
  }

  @override
  Future<void> stopData() async {
    try {
      _isReconnecting = false;

      // 1. First attempt graceful shutdown
      if (_configSendPort != null) {
        try {
          _configSendPort?.send('stop');
        } catch (e) {
          if (kDebugMode) {
            print('Error sending stop to config port: $e');
          }
        }
      }

      if (_socketToProcessingSendPort != null) {
        try {
          _socketToProcessingSendPort?.send('stop');
        } catch (e) {
          if (kDebugMode) {
            print('Error sending stop to socket port: $e');
          }
        }
      }

      // Give isolates time to process stop messages
      await Future.delayed(const Duration(milliseconds: 300));

      // 2. Create new tracking mechanism with ReceivePorts
      final processingDone = Completer<void>();
      final socketDone = Completer<void>();

      // 3. Improved exit listener setup
      if (_processingIsolate != null) {
        final exitPort = ReceivePort();
        _processingIsolate!.addOnExitListener(exitPort.sendPort);
        exitPort.listen((_) {
          if (kDebugMode) {
            print('Processing isolate exited normally');
          }
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
          if (kDebugMode) {
            print('Socket isolate exited normally');
          }
          exitPort.close();
          socketDone.complete();
        });
      } else {
        socketDone.complete();
      }

      // 4. Force kill the isolates with better error handling
      if (_processingIsolate != null) {
        try {
          _processingIsolate!.kill(priority: Isolate.immediate);
        } catch (e) {
          if (kDebugMode) {
            print('Error killing processing isolate: $e');
          }
          // Ensure completer is completed even on error
          if (!processingDone.isCompleted) {
            processingDone.complete();
          }
        }
      }

      if (_socketIsolate != null) {
        try {
          _socketIsolate!.kill(priority: Isolate.immediate);
        } catch (e) {
          if (kDebugMode) {
            print('Error killing socket isolate: $e');
          }
          // Ensure completer is completed even on error
          if (!socketDone.isCompleted) {
            socketDone.complete();
          }
        }
      }

      // 5. Wait for isolates to terminate with improved timeout handling
      try {
        await Future.wait([
          processingDone.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              if (kDebugMode) {
                print(
                    'WARNING: Processing isolate kill timeout - forcing termination');
              }
              return null;
            },
          ),
          socketDone.future.timeout(
            const Duration(seconds: 3),
            onTimeout: () {
              if (kDebugMode) {
                print(
                    'WARNING: Socket isolate kill timeout - forcing termination');
              }
              return null;
            },
          ),
        ]);
      } catch (e) {
        if (kDebugMode) {
          print('Error waiting for isolates to terminate: $e');
        }
        // Continue with cleanup even if there was an error
      }

      // 6. Clean up all resources, ensuring null checks
      _processingIsolate = null;
      _socketIsolate = null;

      if (_processingReceivePort != null) {
        try {
          _processingReceivePort!.close();
        } catch (e) {
          if (kDebugMode) {
            print('Error closing processing receive port: $e');
          }
        }
        _processingReceivePort = null;
      }

      _socketToProcessingSendPort = null;
      _configSendPort = null;

      _currentFrequency = 0.0;
      _currentMaxValue = 0.0;

      // Only add final values if controllers are not closed and we're not disposed
      if (!_disposed) {
        try {
          _ensureControllersExist();
          _frequencyController?.add(0.0);
          _maxValueController?.add(0.0);
          _dataController?.add([]);
        } catch (e) {
          if (kDebugMode) {
            print('Error updating controllers: $e');
          }
        }
      }

      // 7. Final delay to help with resource cleanup
      await Future.delayed(const Duration(milliseconds: 100));
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping data: $e');
      }
      // Even if there was an error, set all references to null to help GC
      _processingIsolate = null;
      _socketIsolate = null;
      _processingReceivePort = null;
      _socketToProcessingSendPort = null;
      _configSendPort = null;
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    _disposed = true;
    await stopData();

    // Safely close controllers and set to null
    try {
      await Future.wait([
        if (_dataController != null && !_dataController!.isClosed)
          _dataController!.close().catchError((e) {
            if (kDebugMode) {
              print('Error closing data controller: $e');
            }
            return null;
          }),
        if (_frequencyController != null && !_frequencyController!.isClosed)
          _frequencyController!.close().catchError((e) {
            if (kDebugMode) {
              print('Error closing frequency controller: $e');
            }
            return null;
          }),
        if (_maxValueController != null && !_maxValueController!.isClosed)
          _maxValueController!.close().catchError((e) {
            if (kDebugMode) {
              print('Error closing max value controller: $e');
            }
            return null;
          }),
      ].whereType<Future>().toList());
    } catch (e) {
      if (kDebugMode) {
        print('Error during controller disposal: $e');
      }
    }

    // Set controllers to null after closing
    _dataController = null;
    _frequencyController = null;
    _maxValueController = null;
  }

  @override
  Future<List<double>> autoset(double chartHeight, double chartWidth) async {
    // Update trigger level to middle between max and min
    triggerLevel = (_currentMaxValue + _currentMinValue) / 2;

    // Ensure trigger is within voltage range using new maxBits/midBits system
    final range = _currentVoltageScale.scale *
        (deviceConfig.maxBits - deviceConfig.minBits);
    final halfRange = range / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);

    updateConfig();

    // Process signal briefly to get working frequency
    await Future.delayed(const Duration(milliseconds: 1000));

    // Calculate timeScale and valueScale based on obtained frequency
    if (_currentFrequency <= 0) {
      triggerLevel = triggerLevel;
      final maxAbsValue = max(_currentMaxValue.abs(), _currentMinValue.abs());
      final valueScale = maxAbsValue != 0 ? 1.0 / maxAbsValue : 1.0;
      return [100000, valueScale];
    }

    // Time scale calculation
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    final timeScale = chartWidth / totalTime;

    // Value scale calculation considering max absolute value
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
      if (kDebugMode) {
        print('Empty queue in processDataForTest');
      }
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

  @visibleForTesting
  Future<(int, int)> maskDataForTest(int input) async {
    final queue = Queue<int>()
      ..add(input & 0xFF)
      ..add((input >> 8) & 0xFF);
    return _readDataFromQueue(queue, deviceConfig.config!);
  }
}
