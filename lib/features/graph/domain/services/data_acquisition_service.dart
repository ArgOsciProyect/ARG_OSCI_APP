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
import 'package:simple_kalman/simple_kalman.dart';


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
  final TriggerMode triggerMode;
  final TriggerEdge triggerEdge;
  
  ProcessingIsolateSetup(this.sendPort, this.scale, this.distance, 
      this.triggerLevel, this.triggerMode, this.triggerEdge);
}

class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerMode triggerMode;
  final TriggerEdge triggerEdge;

  UpdateConfigMessage(this.scale, this.triggerLevel, this.triggerMode, this.triggerEdge);
}

class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _frequencyController = StreamController<double>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  late HttpService httpService;

  // Configuration
  double scale = 1.0;
  double distance = 1 / 2000000;
  double triggerLevel = 0.0;
  TriggerMode triggerMode = TriggerMode.automatic;
  TriggerEdge triggerEdge = TriggerEdge.positive;

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
    scale = 1.0;  // Use default values initially
    distance = 1 / 1634000;
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
  
  static Future<void> _connectSocket(SocketService socketService, SocketConnection connection) async {
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
    const processingChunkSize = 8192 * 4;
    const maxQueueSize = 8192 * 32;
  
    double scale = setup.scale;
    double triggerLevel = setup.triggerLevel;
    TriggerMode triggerMode = setup.triggerMode;
    TriggerEdge triggerEdge = setup.triggerEdge;
  
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
            triggerMode,
            triggerEdge
          );
          setup.sendPort.send(points);
        }
      } else if (message is UpdateConfigMessage) {
        scale = message.scale;
        triggerLevel = message.triggerLevel;
        triggerMode = message.triggerMode;
        triggerEdge = message.triggerEdge;
      }
    });
  }

  static List<DataPoint> _processData(
    Queue<int> queue, 
    int chunkSize,
    double scale,
    double distance,
    double triggerLevel,
    TriggerMode triggerMode,
    TriggerEdge triggerEdge
  ) {
    final points = <DataPoint>[];
    final filteredValues = <double>[];
    var triggerActivated = false;
    var triggerIndex = 0;
    const windowSize = 5;
    final kalman = SimpleKalman(errorMeasure: 256, errorEstimate: 150, q: 0.5);

    for (var i = 0; i < chunkSize; i += 2) {
      if (queue.length < 2) break;
      
      final bytes = [queue.removeFirst(), queue.removeFirst()];
      final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint16(0, Endian.little);
      final uint12Value = uint16Value & 0xFFF;
  
      final x = points.length * distance;
      final y = uint12Value * scale;
      
      // Apply filtering and trigger logic
      filteredValues.add(y);
      if (filteredValues.length > windowSize) {
        filteredValues.removeAt(0);
      }
  
      if (!triggerActivated && points.isNotEmpty) {
        final prevY = filteredValues.length > 1 ? 
            filteredValues[filteredValues.length - 2] : y;
        final currentY = filteredValues.last;
        
        final triggerCondition = triggerEdge == TriggerEdge.positive
            ? prevY < triggerLevel && currentY >= triggerLevel
            : prevY > triggerLevel && currentY <= triggerLevel;
  
        if (triggerCondition) {
          triggerActivated = true;
          triggerIndex = points.length;
        }
      }
  
      //points.add(DataPoint(x, kalman.filtered(y)));
      points.add(DataPoint(x, y));
    }
    if (triggerActivated) {
      final triggerX = points[triggerIndex].x;
      return points.sublist(triggerIndex).map((point) {
        return DataPoint(point.x - triggerX, point.y);
      }).toList();
    } else {
      return points;
    }
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
        triggerMode,
        triggerEdge
      )
    );

    // Get processing SendPort and wait for it to be ready
    final setupCompleter = Completer<SendPort>();
    _processingReceivePort!.listen((message) {
      if (message is SendPort) {
        _socketToProcessingSendPort = message;
        _configSendPort = message;
        setupCompleter.complete(message);
      } else if (message is List<DataPoint>) {
        _dataController.add(message);
        _updateMetrics(message);
      }
    });

    _socketToProcessingSendPort = await setupCompleter.future;

    // Start socket isolate with processing SendPort
    _socketIsolate = await Isolate.spawn(
      _socketIsolateFunction,
      SocketIsolateSetup(_socketToProcessingSendPort!, ip, port)
    );
  }

  void updateConfig() {
    print("Updating config");
    if (_configSendPort != null) {
      _configSendPort!.send(UpdateConfigMessage(scale, triggerLevel, triggerMode, triggerEdge));
    }
  }

  double _currentFrequency = 10000.0;
  double _currentMaxValue = 4094.0;
  
  void _updateMetrics(List<DataPoint> points) {
    if (points.isEmpty) return;
    
    _currentFrequency = _calculateFrequency(points);
    _currentMaxValue = points.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    
    _frequencyController.add(_currentFrequency);
    _maxValueController.add(_currentMaxValue);
  }

  double _calculateFrequency(List<DataPoint> points) {
    // Implement actual frequency calculation
    return 10000.0;
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
    triggerMode = TriggerMode.automatic;
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    updateConfig(); // Send updated config to processing isolate
    return [
      chartWidth / totalTime,
      chartHeight / _currentMaxValue
    ];
  }
}