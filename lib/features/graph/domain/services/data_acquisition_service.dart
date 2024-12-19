// lib/features/data_acquisition/domain/services/data_acquisition_service.dart
import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';
import 'dart:collection';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';

import '../models/data_point.dart';
import '../repository/data_acquisition_repository.dart';
import '../../../http/domain/services/http_service.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../models/trigger_data.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';

// Message classes for isolate setup
class SocketIsolateSetup {
  final SendPort sendPort;
  final String ip;
  final int port;
  SocketIsolateSetup(this.sendPort, this.ip, this.port);
}

class ProcessingIsolateSetup {
  final SendPort sendPort;
  final double scale;
  final double distance;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double triggerSensitivity; // Nueva variable

  ProcessingIsolateSetup(
      this.sendPort,
      this.scale,
      this.distance,
      this.triggerLevel,
      this.triggerEdge,
      this.triggerSensitivity);
}

class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double triggerSensitivity; // Nueva variable

  UpdateConfigMessage(this.scale, this.triggerLevel, this.triggerEdge, this.triggerSensitivity);
}

class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _frequencyController = StreamController<double>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  late HttpService httpService;

  // Configuration
  double scale = 1.0;
  double distance = 1 / 1600000;
  double triggerLevel = 0.0;
  TriggerEdge triggerEdge = TriggerEdge.positive;
  double triggerSensitivity = 100.0; // Nueva variable

  // Isolates
  Isolate? _socketIsolate;
  Isolate? _processingIsolate;
  ReceivePort? _socketReceivePort;
  ReceivePort? _processingReceivePort;
  SendPort? _processingSendPort;
  SendPort? _configSendPort;

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;
  @override
  Stream<double> get frequencyStream => _frequencyController.stream;
  @override
  Stream<double> get maxValueStream => _maxValueController.stream;

  DataAcquisitionService(this.httpConfig) {
    httpService = HttpService(httpConfig);
  }

  @override
  Future<void> initialize() async {
    // Don't try to fetch config until services are ready
    scale = 1.0; // Use default values initially
    distance = 1 / 1600000;
  }

  static void _socketIsolateFunction(SocketIsolateSetup setup) async {
    final socketService = SocketService();
    final connection = SocketConnection(setup.ip, setup.port);

    while (true) {
      try {
        await _connectSocket(socketService, connection);
        _listenToSocket(socketService, setup.sendPort);

        // Exit the loop if connection is successful
        break;
      } catch (e) {
        print('Socket error: $e');
        print('Retrying connection in 5 seconds...');
        await Future.delayed(Duration(seconds: 5));
      }
    }
  }

  static Future<void> _connectSocket(
      SocketService socketService, SocketConnection connection) async {
    await socketService.connect(connection);
  }

  static void _listenToSocket(SocketService socketService, SendPort sendPort) {
    socketService.listen();
    socketService.subscribe((data) {
      sendPort.send(data);
    });
  }

  static void _processingIsolateFunction(ProcessingIsolateSetup setup) {
    final receivePort = ReceivePort();
    setup.sendPort.send(receivePort.sendPort);

    final queue = Queue<int>();
    const processingChunkSize = 8192 * 2;
    const maxQueueSize = 8192 * 32;

    double scale = setup.scale;
    double triggerLevel = setup.triggerLevel;
    TriggerEdge triggerEdge = setup.triggerEdge;
    double triggerSensitivity = setup.triggerSensitivity; // Nueva variable

    receivePort.listen((message) {
      if (message is List<int>) {
        queue.addAll(message);

        while (queue.length > maxQueueSize) {
          queue.removeFirst();
        }

        while (queue.length >= processingChunkSize) {
          final points = _processData(
              queue,
              processingChunkSize,
              scale,
              setup.distance,
              triggerLevel,
              triggerEdge,
              triggerSensitivity // Pasar la nueva variable
              );
          setup.sendPort.send(points);
        }
      } else if (message is UpdateConfigMessage) {
        scale = message.scale;
        triggerLevel = message.triggerLevel;
        triggerEdge = message.triggerEdge;
        triggerSensitivity =
            message.triggerSensitivity; // Actualizar la nueva variable
      }
    });
  }


  double _currentFrequency = 10000.0;
  double _currentMaxValue = 512.0;
  double _currentAverage = 256.0;

    static List<DataPoint> _processData(
    Queue<int> queue, 
    int chunkSize,
    double scale,
    double distance,
    double triggerLevel,
    TriggerEdge triggerEdge,
    double triggerSensitivity
  ) {
    final points = <DataPoint>[];
    var firstTriggerX = 0.0;
    var secondTriggerX = 0.0;
    int firstTriggerIndex = -1;
    int lastTriggerIndex = -1;
    int secondTriggerIndex = -1;
    bool foundFirstTrigger = false;
    bool foundSecondTrigger = false;
    
    bool waitingForHysteresis = false;
    double lastTriggerY = 0.0;
  
    for (var i = 0; i < chunkSize; i += 2) {
      if (queue.length < 2) break;
      
      final bytes = [queue.removeFirst(), queue.removeFirst()];
      final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint16(0, Endian.little);
      
      final uint12Value = uint16Value & 0x0FFF;
      final channel = (uint16Value >> 12) & 0x0F;
  
      final x = points.length * distance;
      final y = uint12Value * scale;
  
      if (points.isNotEmpty) {
        final prevY = points.length > 1 ? points[points.length - 2].y : y;
        final currentY = y;
        
        // Unified trigger detection
        if (!waitingForHysteresis) {
          final risingEdgeTrigger = triggerEdge == TriggerEdge.positive &&
              prevY < triggerLevel && currentY >= triggerLevel;
          
          final fallingEdgeTrigger = triggerEdge == TriggerEdge.negative &&
              prevY > triggerLevel && currentY <= triggerLevel;
  
          if (risingEdgeTrigger || fallingEdgeTrigger) {
            if (!foundFirstTrigger) {
              firstTriggerIndex = points.length;
              firstTriggerX = x;
              foundFirstTrigger = true;
              points.add(DataPoint(x, y, isTrigger: true));
            } else {
              lastTriggerIndex = points.length;
              if (!foundSecondTrigger) {
                secondTriggerIndex = points.length;
                secondTriggerX = x;
                foundSecondTrigger = true;
              }
              points.add(DataPoint(x, y, isTrigger: true));
            }
            waitingForHysteresis = true;
            lastTriggerY = currentY;
            continue;
          }
        } else {
          // Apply hysteresis
          if (triggerEdge == TriggerEdge.positive) {
            if (currentY < (triggerLevel - triggerSensitivity)) {
              waitingForHysteresis = false;
            }
          } else {
            if (currentY > (triggerLevel + triggerSensitivity)) {
              waitingForHysteresis = false;
            }
          }
        }
      }
      points.add(DataPoint(x, y));
    }
  
    // Return points based on the last trigger detected before the end of the list
    if (foundFirstTrigger) {
      final endIndex = lastTriggerIndex != -1 ? lastTriggerIndex + 1 : points.length;
      return points
          .sublist(firstTriggerIndex, endIndex)
          .map((point) => DataPoint(point.x - firstTriggerX, point.y, isTrigger: point.isTrigger))
          .toList();
    }
    
    return points;
  }
  
  double _calculateFrequencyFromTriggers(List<DataPoint> points, double distance) {
    if (points.isEmpty) return 0.0;
  
    final triggerPositions = <double>[];
  
    for (var point in points) {
      if (point.isTrigger) {
        triggerPositions.add(point.x);
      }
    }
  
    if (triggerPositions.length < 2) return 0.0;
  
    double totalInterval = 0.0;
    for (var i = 1; i < triggerPositions.length; i++) {
      totalInterval += triggerPositions[i] - triggerPositions[i - 1];
    }
  
    final averageInterval = totalInterval / (triggerPositions.length - 1);
    return 1 / averageInterval;
  }
  
  void _updateMetrics(List<DataPoint> points) {
    if (points.isEmpty) return;
  
    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    _currentAverage =
        points.map((p) => p.y).reduce((a, b) => a + b) / points.length;
  
    _frequencyController.add(_currentFrequency);
    _maxValueController.add(_currentMaxValue);
  }
  
  double _calculateFrequency(List<DataPoint> points) {
    final frequencyFromTriggers = _calculateFrequencyFromTriggers(points, distance);
    return frequencyFromTriggers != 0.0 ? frequencyFromTriggers : 10000.0;
  }
  static List<DataPoint> _applyMovingAverageFilter(
      List<DataPoint> points, int windowSize) {
    final filteredPoints = <DataPoint>[];

    for (int i = 0; i < points.length; i++) {
      double sum = 0;
      int count = 0;

      for (int j = i; j >= 0 && j > i - windowSize; j--) {
        sum += points[j].y;
        count++;
      }

      final average = sum / count;
      filteredPoints.add(DataPoint(points[i].x, average));
    }

    return filteredPoints;
  }

  SendPort? _socketToProcessingSendPort;

  @override
  Future<void> fetchData(String ip, int port) async {
    await stopData();

    _processingReceivePort = ReceivePort();

    // Start processing isolate first
    _processingIsolate = await Isolate.spawn(
        _processingIsolateFunction,
        ProcessingIsolateSetup(
            _processingReceivePort!.sendPort,
            scale,
            distance,
            triggerLevel,
            triggerEdge,
            triggerSensitivity // Pasar la nueva variable
            ));

    // Get processing SendPort and wait for it to be ready
    final setupCompleter = Completer<SendPort>();
    _processingReceivePort!.listen((message) {
      if (message is SendPort) {
        _socketToProcessingSendPort = message;
        _configSendPort = message;
        setupCompleter.complete(message);
      } else if (message is List<DataPoint>) {
        // Apply moving average filter to the points
        final filteredPoints =
            _applyMovingAverageFilter(message, 1); // Example window size of 5
        _dataController.add(filteredPoints);
        _updateMetrics(message);
      }
    });

    _socketToProcessingSendPort = await setupCompleter.future;

    // Start socket isolate with processing SendPort
    _socketIsolate = await Isolate.spawn(_socketIsolateFunction,
        SocketIsolateSetup(_socketToProcessingSendPort!, ip, port));
  }

  void updateConfig() {
    print("Updating config");
    if (_configSendPort != null) {
      _configSendPort!.send(UpdateConfigMessage(
          scale, triggerLevel, triggerEdge, triggerSensitivity));
    }
  }

  @override
  Future<void> stopData() async {
    _socketIsolate?.kill();
    _socketIsolate = null;

    _processingIsolate?.kill();
    _processingIsolate = null;

    _processingReceivePort?.close();
    _processingReceivePort = null;

    _socketToProcessingSendPort = null;
    _configSendPort = null;
  }

  @override
  void dispose() {
    stopData();
    _dataController.close();
    _frequencyController.close();
    _maxValueController.close();
  }

  @override
  List<double> autoset(double chartHeight, double chartWidth) {
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    triggerLevel = _currentAverage;
    updateConfig(); // Send updated config to processing isolate
    return [chartWidth / totalTime, chartHeight / _currentMaxValue];
  }
}