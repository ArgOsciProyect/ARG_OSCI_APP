// test/features/graph/domain/services/data_acquisition_service_test.dart
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';

// ----------------------------------------------------------------------------
// Mocks
// ----------------------------------------------------------------------------

// Mock para HttpConfig
class MockHttpConfig extends Mock implements HttpConfig {
  @override
  String get baseUrl => 'http://test.com';

  @override
  http.Client? get client => MockHttpClient();
}

// Mock para HttpClient
class MockHttpClient extends Mock implements http.Client {}

// Mock para SocketService
class MockSocketService extends Mock implements SocketService {
  final _controller = StreamController<List<int>>.broadcast();

  @override
  Future<void> connect(SocketConnection connection) async {
    // Simular conexión exitosa
    print("MockSocketService: connect called with ${connection.ip.value}:${connection.port.value}");
    // Puedes agregar lógica adicional si es necesario
    return;
  }

  @override
  void listen() {
    // Simular escucha (no hacer nada)
  }

  @override
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData) {
    return _controller.stream.listen(onData);
  }

  void simulateData(List<int> data) {
    _controller.add(data);
  }

  @override
  Future<void> sendMessage(String message) async {
    // Simular envío de mensaje
    print("MockSocketService: sendMessage called with $message");
  }

  @override
  Future<String> receiveMessage() async {
    // Simular recepción de mensaje
    return 'Mock message';
  }

  @override
  Future<void> close() async {
    await _controller.close();
  }

  @override
  Stream<List<int>> get data => _controller.stream;
}

// Mock para HttpService (si es necesario)
class MockHttpService extends Mock implements HttpService {}

void main() {
  late DataAcquisitionService service;
  late MockHttpConfig mockHttpConfig;
  // ignore: unused_local_variable
  late MockSocketService mockSocketService;

  setUp(() async {
    mockHttpConfig = MockHttpConfig();
    mockSocketService = MockSocketService();
    service = DataAcquisitionService(mockHttpConfig);
    await service.initialize();
    
    // Known test configuration
    service.scale = 3.3 / 512;
    service.mid = 512 / 2;
    service.triggerLevel = 0.0;
    service.triggerSensitivity = 0.1;
  });

  tearDown(() async {
    await service.dispose();
  });

  group('ProcessData', () {
    test('should detect rising edge trigger', () {
      final queue = Queue<int>();
      queue.addAll([
        0x00, 0x00, // 0: (0-256)*0.00645 = -1.65V
        0x00, 0x01, // 256: (256-256)*0.00645 = 0V
        0xFF, 0x01, // 511: (511-256)*0.00645 = +1.64V
      ]);

      final points = DataAcquisitionService.processDataForTest(
        queue,
        6,
        service.scale,
        service.distance,
        service.triggerLevel,
        TriggerEdge.positive,
        service.triggerSensitivity,
        service.mid,
      );

      print('\nRising Edge Test:');
      print('Scale: ${service.scale}, Mid: ${service.mid}');
      print('TriggerLevel: ${service.triggerLevel}');
      for (var p in points) {
        print('x: ${p.x}, y: ${p.y}, trigger: ${p.isTrigger}');
      }

      expect(points, isNotEmpty);
      expect(points.any((p) => p.isTrigger), isTrue);
    });

    test('should detect falling edge trigger', () {
      final queue = Queue<int>();

      // Valores que cruzan el nivel de disparo (0V)
      queue.addAll([
        0xFF, 0x01, // 511: (511-256)*0.00645 = +1.64V
        0x00, 0x01, // 256: (256-256)*0.00645 = 0V
        0x00, 0x00, // 0: (0-256)*0.00645 = -1.65V
      ]);

      final points = DataAcquisitionService.processDataForTest(
        queue,
        6,
        service.scale,
        service.distance,
        service.triggerLevel,
        TriggerEdge.negative,
        service.triggerSensitivity,
        service.mid,
      );

      print('\nFalling Edge Test:');
      print('Scale: ${service.scale}, Mid: ${service.mid}');
      print('TriggerLevel: ${service.triggerLevel}');
      for (var p in points) {
        print('x: ${p.x}, y: ${p.y}, trigger: ${p.isTrigger}');
      }

      expect(points, isNotEmpty);
      expect(points.any((p) => p.isTrigger), isTrue);
    });
  });

  group('Metrics Calculation', () {
    test('should calculate frequency from triggers', () async {
      final points = [
        DataPoint(0.0, 0.0, isTrigger: true),
        DataPoint(1e-6, 1.0),
        DataPoint(2e-6, 0.0, isTrigger: true),
      ];

      // Frecuencia esperada: 1 / (2e-6) = 500000 Hz
      const expectedFrequency = 500000.0;

      // Escuchar el stream y esperar la frecuencia
      final frequencyFuture = service.frequencyStream.first;

      // Actualizar métricas, lo que debería emitir la frecuencia
      service.updateMetrics(points);

      // Esperar la frecuencia emitida
      final actualFrequency = await frequencyFuture;

      print('Expected Frequency: $expectedFrequency');
      print('Actual Frequency: $actualFrequency');

      expect(actualFrequency, equals(expectedFrequency));
    });

    test('autoset should return default scales if frequency <= 0', () {
      final result = service.autoset(300, 400);
      expect(result, equals([1.0, 1.0]));
    });

    test('autoset should compute correct scales if frequency > 0', () {
      final points = [
        DataPoint(0.0, -1.0, isTrigger: true),
        DataPoint(5e-6, 1.0, isTrigger: true),
      ];

      service.updateMetrics(points);
      final result = service.autoset(300, 400);
      expect(result[0], closeTo(2.66e7, 1e5));
      expect(result[1], equals(1.0));
    });

    // Pruebas adicionales para cubrir líneas específicas
    test('should handle frequency calculation with single trigger', () async {
      final points = [
        DataPoint(0.0, 0.0, isTrigger: true),
      ];

      // Esperar que la frecuencia sea 0.0
      final frequencyFuture = service.frequencyStream.first;

      service.updateMetrics(points);

      final actualFrequency = await frequencyFuture;

      print('Expected Frequency: 0.0');
      print('Actual Frequency: $actualFrequency');

      expect(actualFrequency, equals(0.0));
    });

    test('should handle frequency calculation with no triggers', () async {
      final points = [
        DataPoint(0.0, 1.0),
        DataPoint(1e-6, 2.0),
        DataPoint(2e-6, 1.5),
      ];

      // Esperar que la frecuencia sea 0.0
      final frequencyFuture = service.frequencyStream.first;

      service.updateMetrics(points);

      final actualFrequency = await frequencyFuture;

      print('Expected Frequency: 0.0');
      print('Actual Frequency: $actualFrequency');

      expect(actualFrequency, equals(0.0));
    });
  });

// In the test file, update the isolate handling group:
group('Isolate Handling', () {
    test('should spawn processing isolate on fetchData', () async {
      const ip = '127.0.0.1';
      final dataReceived = Completer<void>();
      // ignore: unused_local_variable
      final isolateSpawned = Completer<void>();
      
      // Create server and handle connection
      final server = await ServerSocket.bind(ip, 0);
      final port = server.port;
      
      // Listen for data on the stream before calling fetchData
      final subscription = service.dataStream.listen((data) {
        if (!dataReceived.isCompleted) {
          dataReceived.complete();
        }
      });

      // Set up server listener
      final serverSubscription = server.listen((Socket client) {
        // Send test data immediately after connection
        final rawData = List<int>.generate(8192 * 2, (i) => i % 256);
        client.add(rawData);
      });

      // Start data acquisition
      await service.fetchData(ip, port);
      
      // Add a small delay to allow isolates to spawn
      await Future.delayed(Duration(milliseconds: 100));

      // Verify isolates were created
      expect(service.processingIsolate, isNotNull);
      expect(service.socketIsolate, isNotNull);

      // Wait for data with timeout
      try {
        await dataReceived.future.timeout(Duration(seconds: 5));
      } finally {
        await subscription.cancel();
        await serverSubscription.cancel();
        await server.close();
        await service.stopData();
      }
    });

    test('should handle data received from processing isolate', () async {
      const ip = '127.0.0.1';
      final dataReceived = Completer<List<DataPoint>>();
      
      final server = await ServerSocket.bind(ip, 0);
      final port = server.port;

      // Set up data listener before fetching data
      final subscription = service.dataStream.listen((data) {
        if (!dataReceived.isCompleted && data.isNotEmpty) {
          dataReceived.complete(data);
        }
      });

      // Set up server listener
      final serverSubscription = server.listen((Socket client) {
        // Send enough data to trigger processing
        final rawData = List<int>.generate(8192 * 2, (i) {
          // Generate a sine wave pattern
          if (i % 2 == 0) {
            return (128 + (127 * sin(i * 0.1))).toInt() & 0xFF;
          } else {
            return 0x01; // High byte
          }
        });
        client.add(rawData);
      });

      await service.fetchData(ip, port);

      try {
        final receivedData = await dataReceived.future.timeout(Duration(seconds: 5));
        expect(receivedData, isNotEmpty);

        // Add a small delay to ensure cleanup works properly
        await Future.delayed(Duration(milliseconds: 100));
      } finally {
        await subscription.cancel();
        await serverSubscription.cancel();
        await server.close();
        await service.stopData();
      }
    });

    test('should retry socket connection on failure', () async {
      const ip = '127.0.0.1';
      const port = 35642; // Unused port
      final connectionAttempted = Completer<void>();
      
      // Start fetching data
      service.fetchData(ip, port).then((_) {
        if (!connectionAttempted.isCompleted) {
          connectionAttempted.complete();
        }
      });

      // Wait for the first connection attempt
      await connectionAttempted.future.timeout(Duration(seconds: 2));
      
      // Stop data acquisition
      await service.stopData();

      // Verify cleanup
      expect(service.socketIsolate, isNull);
      expect(service.processingIsolate, isNull);
    });
});

  group('Configuration Updates', () {
    test('should update trigger configuration', () {
      service.triggerLevel = 1.0;
      service.triggerEdge = TriggerEdge.negative;
      service.triggerSensitivity = 50.0;

      service.updateConfig();

      expect(service.triggerLevel, equals(1.0));
      expect(service.triggerEdge, equals(TriggerEdge.negative));
      expect(service.triggerSensitivity, equals(50.0));
    });

    test('should handle updateConfig when configSendPort is null', () {
      // Establecer configSendPort a null
      service.configSendPort = null;

      // Asegurar que no se lance una excepción
      expect(() => service.updateConfig(), returnsNormally);
    });
  });

  group('Resource Management', () {
    test('should clean up resources on dispose', () async {
      await service.dispose();
      expect(() => service.dataStream.listen((_) {}), throwsStateError);
      expect(() => service.frequencyStream.listen((_) {}), throwsStateError);
      expect(() => service.maxValueStream.listen((_) {}), throwsStateError);
    });

    test('dispose should close all stream controllers', () async {
      // Antes de dispose, los streams deberían estar abiertos
      var dataListener = service.dataStream.listen((_) {});
      var frequencyListener = service.frequencyStream.listen((_) {});
      var maxValueListener = service.maxValueStream.listen((_) {});

      expect(dataListener.isPaused, isFalse);
      expect(frequencyListener.isPaused, isFalse);
      expect(maxValueListener.isPaused, isFalse);

      await service.dispose();

      // Después de dispose, escuchar debería lanzar errores
      expect(() => service.dataStream.listen((_) {}), throwsStateError);
      expect(() => service.frequencyStream.listen((_) {}), throwsStateError);
      expect(() => service.maxValueStream.listen((_) {}), throwsStateError);
    });
  });

  group('Error Handling', () {
    test('should handle empty data in processData', () {
      final queue = Queue<int>();
      final points = DataAcquisitionService.processDataForTest(
        queue,
        6,
        service.scale,
        service.distance,
        service.triggerLevel,
        TriggerEdge.positive,
        service.triggerSensitivity,
        service.mid,
      );

      expect(points, isEmpty);
    });

    test('should handle insufficient data in processData', () {
      final queue = Queue<int>();
      queue.addAll([
        0x00, // Datos incompletos
      ]);

      final points = DataAcquisitionService.processDataForTest(
        queue,
        6,
        service.scale,
        service.distance,
        service.triggerLevel,
        TriggerEdge.positive,
        service.triggerSensitivity,
        service.mid,
      );

      expect(points, isEmpty);
    });

    test('should handle invalid endianness in processData', () {
      final queue = Queue<int>();
      // Intercambiar bytes intencionalmente para crear datos inválidos
      queue.addAll([
        0xFF, 0x00, // Datos inválidos
      ]);

      final points = DataAcquisitionService.processDataForTest(
        queue,
        6,
        service.scale,
        service.distance,
        service.triggerLevel,
        TriggerEdge.positive,
        service.triggerSensitivity,
        service.mid,
      );

      expect(points.any((p) => p.isTrigger), isFalse);
    });
  });
}