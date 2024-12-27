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
  final double triggerSensitivity;
  final double mid;

  ProcessingIsolateSetup(this.sendPort, this.scale, this.distance,
      this.triggerLevel, this.triggerEdge, this.triggerSensitivity, this.mid);
}

class UpdateConfigMessage {
  final double scale;
  final double triggerLevel;
  final TriggerEdge triggerEdge;
  final double triggerSensitivity;
  UpdateConfigMessage(
      this.scale, this.triggerLevel, this.triggerEdge, this.triggerSensitivity);
}

class DataAcquisitionService implements DataAcquisitionRepository {
  final HttpConfig httpConfig;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _frequencyController = StreamController<double>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  late HttpService httpService;

  // Configuration
  @override
  double scale = (100 / 512);
  double mid = 512 / 2;
  @override
  double distance = 1 / 1600000;
  @override
  double triggerLevel = 0.0;
  @override
  TriggerEdge triggerEdge = TriggerEdge.positive;
  @override
  double triggerSensitivity = 70.0;

  // Isolates
  Isolate? _socketIsolate;
  Isolate? _processingIsolate;
  ReceivePort? _processingReceivePort;
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
    scale = (3.3 / 512); // Use default values initially
    mid = 512 / 2;
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
    double mid = setup.mid;
    double triggerLevel = setup.triggerLevel;
    TriggerEdge triggerEdge = setup.triggerEdge;
    double triggerSensitivity = setup.triggerSensitivity;

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
              triggerSensitivity,
              mid);  // Pass mid parameter
          setup.sendPort.send(points);
        }
      } else if (message is UpdateConfigMessage) {
        scale = message.scale;
        triggerLevel = message.triggerLevel;
        triggerEdge = message.triggerEdge;
        triggerSensitivity =
            message.triggerSensitivity; // Update the new variable
      }
    });
  }

  double _currentFrequency = 0.0;
  double _currentMaxValue = 0;
  double _currentAverage = 0;

  static List<DataPoint> _processData(
      Queue<int> queue,
      int chunkSize,
      double scale,
      double distance,
      double triggerLevel,
      TriggerEdge triggerEdge,
      double triggerSensitivity,
      double mid) {
    final points = <DataPoint>[];
    var firstTriggerX = 0.0;
    // ignore: unused_local_variable
    var secondTriggerX = 0.0;
    int firstTriggerIndex = -1;
    int lastTriggerIndex = -1;
    // ignore: unused_local_variable
    int secondTriggerIndex = -1;
    bool foundFirstTrigger = false;
    bool foundSecondTrigger = false;

    bool waitingForHysteresis = false;
    // ignore: unused_local_variable
    double lastTriggerY = 0.0;

    for (var i = 0; i < chunkSize; i += 2) {
      if (queue.length < 2) break;

      final bytes = [queue.removeFirst(), queue.removeFirst()];
      final uint16Value = ByteData.sublistView(Uint8List.fromList(bytes))
          .getUint16(0, Endian.little);

      final uint12Value = uint16Value & 0x0FFF;
      final channel = (uint16Value >> 12) & 0x0F; // We should add the channel as a field of the DataPoint class

      final x = points.length * distance;
      final y = (uint12Value - mid) * scale;

      if (points.isNotEmpty) {
        final prevY = points.length > 1 ? points[points.length - 2].y : y;
        final currentY = y;

        // Unified trigger detection
        if (!waitingForHysteresis) {
          final risingEdgeTrigger = triggerEdge == TriggerEdge.positive &&
              prevY < triggerLevel &&
              currentY >= triggerLevel;

          final fallingEdgeTrigger = triggerEdge == TriggerEdge.negative &&
              prevY > triggerLevel &&
              currentY <= triggerLevel;

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
          // Apply hysteresis: If the current value crosses the trigger level, 
          // we wait until it moves beyond the hysteresis band before allowing 
          // another trigger event. This prevents multiple triggers from noise 
          // around the trigger level.
          if (triggerEdge == TriggerEdge.positive) {
            if (currentY < (triggerLevel - (triggerSensitivity * scale))) {
              waitingForHysteresis = false;
            }
          } else {
            if (currentY > (triggerLevel + (triggerSensitivity * scale))) {
              waitingForHysteresis = false;
            }
          }
        }
      }
      points.add(DataPoint(x, y));
    }

    // Return points based on the last trigger detected before the end of the list
    if (foundFirstTrigger) {
      final endIndex =
          lastTriggerIndex != -1 ? lastTriggerIndex + 1 : points.length;
      return points
          .sublist(firstTriggerIndex, endIndex)
          .map((point) => DataPoint(point.x - firstTriggerX, point.y,
              isTrigger: point.isTrigger))
          .toList();
    }

    return points;
  }

  double _calculateFrequencyFromTriggers(
      List<DataPoint> points, double distance) {
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
    final frequencyFromTriggers =
        _calculateFrequencyFromTriggers(points, distance);
    return frequencyFromTriggers != 0.0 ? frequencyFromTriggers : 0.0;
  }

  SendPort? _socketToProcessingSendPort;

  @override
  Future<void> fetchData(String ip, int port) async {
    await stopData();

    _processingReceivePort = ReceivePort();
    final processingReceivePortStream = _processingReceivePort!.asBroadcastStream();

    // Start processing isolate first
    _processingIsolate = await Isolate.spawn(
        _processingIsolateFunction,
        ProcessingIsolateSetup(
            _processingReceivePort!.sendPort,
            scale,
            distance,
            triggerLevel,
            triggerEdge,
            triggerSensitivity,
            mid,
            ));

    // Get processing SendPort and wait for it to be ready
    final setupCompleter = Completer<SendPort>();
    processingReceivePortStream.listen((message) {
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
    _socketIsolate = await Isolate.spawn(_socketIsolateFunction,
        SocketIsolateSetup(_socketToProcessingSendPort!, ip, port));
  }

  @override
  void updateConfig() {
    print("Updating config");
    if (_configSendPort != null) {
      _configSendPort!.send(UpdateConfigMessage(
          scale, triggerLevel, triggerEdge, triggerSensitivity));
    }
  }

  @override
  Future<void> stopData() async {
    // Primero detener los isolates
    _processingIsolate?.kill();
    _processingIsolate = null;

    // Esperar un momento para asegurar que el isolate se detuvo
    await Future.delayed(const Duration(milliseconds: 50));

    // Luego detener el socket
    _socketIsolate?.kill();
    _socketIsolate = null;

    // Cerrar los puertos y limpiar las referencias
    _processingReceivePort?.close();
    _processingReceivePort = null;

    _socketToProcessingSendPort = null;
    _configSendPort = null;

    // Limpiar cualquier dato pendiente
    _dataController.add([]);
  }


  @override
  Future<void> dispose() async {
    await stopData();
    _dataController.close();
    _frequencyController.close();
    _maxValueController.close();
  }

  @override
  List<double> autoset(double chartHeight, double chartWidth) {
    if (_currentFrequency <= 0) {
      return [1.0, 1.0];
    }

    // Calcular escala de tiempo
    final period = 1 / _currentFrequency;
    final totalTime = 3 * period;
    final timeScale = chartWidth / totalTime;

    // Calcular escala de valor
    final maxValAbs = _currentMaxValue.abs();
    final valueScale = maxValAbs > 0 ? 1.0 / maxValAbs : 1.0;

    // Actualizar trigger
    triggerLevel = _currentAverage;
    updateConfig();

    print('Autoset: timeScale=$timeScale, valueScale=$valueScale'); // Debug
    return [timeScale, valueScale];
  }
}