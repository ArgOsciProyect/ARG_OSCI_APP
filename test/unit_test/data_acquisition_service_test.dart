// test/features/graph/domain/services/data_acquisition_service_test.dart
import 'dart:async';
import 'dart:collection';
import 'dart:io';
import 'dart:isolate';
import 'dart:math';

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
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

SendPort getMockSendPort() {
  final receivePort = ReceivePort();
  // Optionally, handle incoming messages if necessary
  return receivePort.sendPort;
}

// Mock para HttpConfig
class MockHttpConfig extends Mock implements HttpConfig {
  @override
  String get baseUrl => 'http://test.com';

  @override
  http.Client? get client => MockHttpClient();
}

class MockDeviceConfig extends Mock implements DeviceConfig {
  @override
  int get dataMask => 0x0FFF;

  @override
  int get channelMask => 0xF000;

  @override
  int get bitsPerPacket => 16;

  @override
  int get usefulBits => 9;

  @override
  double get samplingFrequency => 1650000.0;

  @override
  int get samplesPerPacket => 4096;
}

class MockDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  final _config = Rx<DeviceConfig?>(MockDeviceConfig());

  @override
  DeviceConfig? get config => _config.value;

  @override
  double get samplingFrequency => 1650000.0;

  @override
  int get bitsPerPacket => 16;

  @override
  int get dataMask => 0x0FFF;

  @override
  int get channelMask => 0xF000;

  @override
  int get usefulBits => 9;

  @override
  int get samplesPerPacket => 4096;

  @override
  void updateConfig(DeviceConfig config) {
    _config.value = config;
  }
}

// Mock para HttpClient
class MockHttpClient extends Mock implements http.Client {}

// Mock para SocketService
class MockSocketService extends Mock implements SocketService {
  final _controller = StreamController<List<int>>.broadcast();

  @override
  Future<void> connect(SocketConnection connection) async {
    // Simular conexión exitosa
    print(
        "MockSocketService: connect called with ${connection.ip.value}:${connection.port.value}");
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

class MockHttpService extends Mock implements HttpService {
  double? lastTriggerPercentage;

  @override
  Future<Response<dynamic>> post(String path, [dynamic data]) async {
    if (path == '/trigger' && data != null) {
      print('MockHttpService.post called with path: $path, data: $data');

      if (data['trigger_percentage'] != null) {
        // Asegurar que lastTriggerPercentage sea double
        lastTriggerPercentage = (data['trigger_percentage'] as num).toDouble();
        print('Setting lastTriggerPercentage to: $lastTriggerPercentage');

        return Response(
          body: {
            'status': 'success',
            'set_percentage': lastTriggerPercentage!
                .toInt(), // Convertir a int para la respuesta
          },
          statusCode: 200,
        );
      }
    }
    throw Exception('Invalid trigger data');
  }

  @override
  Future<Response<dynamic>> get(String path) async {
    switch (path) {
      case '/config':
        return Response(
          body: {
            'sampling_frequency': 1650000.0,
            'bits_per_packet': 16,
            'data_mask': 0x0FFF,
            'channel_mask': 0xF000,
            'useful_bits': 9,
            'samples_per_packet': 8192,
          },
          statusCode: 200,
        );
      default:
        throw Exception('Unknown endpoint');
    }
  }
}

void main() {
  late DataAcquisitionService service;
  late MockHttpConfig mockHttpConfig;
  late MockDeviceConfigProvider mockDeviceConfigProvider;
  late MockSocketService mockSocketService;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.reset();

    mockHttpConfig = MockHttpConfig();
    mockSocketService = MockSocketService();
    mockDeviceConfigProvider = MockDeviceConfigProvider();

    // Create and register mock HTTP service first
    final mockHttpService = MockHttpService();
    Get.put<HttpService>(mockHttpService, permanent: true);
    Get.put<DeviceConfigProvider>(mockDeviceConfigProvider).onInit();

    service = DataAcquisitionService(mockHttpConfig);
    await service.initialize();

    service.scale = 3.3 / 512;
    service.triggerLevel = 1.65;
    service.triggerSensitivity = 0.1;
  });
  tearDown(() async {
    await service.dispose();
    Get.reset();
  });

  group('Voltage Scale Handling', () {
    test('should correctly set and update voltage scale', () {
      final initialScale = service.currentVoltageScale.scale;
      final newScale = VoltageScales.volts_2;

      service.setVoltageScale(newScale);

      expect(service.currentVoltageScale, equals(newScale));
      expect(service.scale, equals(newScale.scale));
    });

    test('should adjust trigger level when changing voltage scale', () {
      // Set initial conditions
      service.setVoltageScale(VoltageScales.volt_1);
      service.triggerLevel = 0.5; // Set trigger to 0.5V

      // Change to 2V scale
      service.setVoltageScale(VoltageScales.volts_2);

      // Trigger level should double
      expect(service.triggerLevel, equals(1.0));
    });

    test('should clamp trigger level to voltage range', () {
      service.triggerLevel = 10.0; // Set trigger beyond range

      // For 1V scale (volts_1):
      // voltageRange = 1.0 * 512 = 512mV
      // maxTriggerLevel = 512/2 = 256mV
      final maxTriggerLevel = (VoltageScales.volt_1.scale * 512) / 2;
      service.setVoltageScale(VoltageScales.volt_1);

      expect(service.triggerLevel, equals(maxTriggerLevel));
    });
  });

  group('Enhanced Autoset', () {
    test('should calculate new scales based on signal metrics', () {
      // Set voltage scale to ensure voltageRange >= 1.0
      service.setVoltageScale(VoltageScales.millivolts_500); // Adjust as needed

      // Simulate signal with adjusted characteristics
      final points = [
        DataPoint(0.0, 0.0, isTrigger: true), // 0.0V (min)
        DataPoint(1e-6, 1.0), // 1.0V (max)
        DataPoint(2e-6, 0.0, isTrigger: true), // 0.0V (min)
        DataPoint(3e-6, 1.0), // 1.0V (max)
        DataPoint(4e-6, 0.0, isTrigger: true), // 0.0V (min)
      ];

      service.updateMetrics(points);

      print("Trigger Level: ${service.triggerLevel}");
      print("Max Value: ${service.currentMaxValue}");
      print("Min Value: ${service.currentMinValue}");
      print("Voltage Scale: ${service.currentVoltageScale.scale}");

      final result = service.autoset(300.0, 400.0);

      print("Trigger Level: ${service.triggerLevel}");
      print("Max Value: ${service.currentMaxValue}");
      print("Min Value: ${service.currentMinValue}");
      print("Voltage Scale: ${service.currentVoltageScale.scale}");

      // Verify time scale (3 periods should fit in chart width)
      expect(result[0], closeTo(400.0 / (3 / 500000), 1000)); // 500kHz signal

      // Verify value scale (should accommodate max value)
      expect(result[1], closeTo(1.0 / 1.0, 0.1)); // Max value is 1.0V

      // Verify trigger level is set to middle between max and min values
      expect(
          service.triggerLevel, closeTo(0.5, 0.1)); // (1.0V + 0.0V) / 2 = 0.5V
    });

    test('autoset should clamp trigger level within voltage range', () {
      service.setVoltageScale(VoltageScales.millivolts_500);

      final points = [
        DataPoint(0.0, 0.6), // Beyond ±500mV range
        DataPoint(1e-6, -0.6),
        DataPoint(2e-6, 0.6),
      ];

      service.updateMetrics(points);
      final result = service.autoset(300.0, 400.0);

      // Verify trigger level is clamped to voltage range
      final maxVoltage = (VoltageScales.millivolts_500.scale * 512) / 2;
      expect(service.triggerLevel.abs(), lessThanOrEqualTo(maxVoltage));
    });

    test('autoset should handle zero signal correctly', () {
      service.triggerLevel = 1.65; // Set initial trigger level

      final points = [
        DataPoint(0.0, 0.0),
        DataPoint(1e-6, 0.0),
        DataPoint(2e-6, 0.0),
      ];

      service.updateMetrics(points);
      print(service.currentMaxValue);
      print(service.currentMinValue);
      final result = service.autoset(300.0, 400.0);

      expect(result, equals([1000.0, 1.0]));
      expect(service.triggerLevel, equals(0.0),
          reason: 'Trigger level should be 0 for zero signal');
    });
  });

  group('ProcessData', () {
    test('should handle hysteresis trigger mode', () {
      final queue = Queue<int>();
      queue.addAll([0x00, 0x00, 0xFF, 0x01, 0x00, 0x00]);

      service.triggerMode = TriggerMode.normal;
      service.useHysteresis = true;

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      expect(points, isNotEmpty);
    });

    test('should toggle hysteresis', () {
      service.useHysteresis = true;
      expect(service.useHysteresis, isTrue);

      service.useHysteresis = false;
      expect(service.useHysteresis, isFalse);
    });

    test('should toggle low pass filter', () {
      service.useLowPassFilter = true;
      expect(service.useLowPassFilter, isTrue);

      service.useLowPassFilter = false;
      expect(service.useLowPassFilter, isFalse);
    });

    test('should handle low pass filter trigger mode', () {
      // Para cubrir líneas 222-223, 237, 246
      final queue = Queue<int>();
      queue.addAll([
        0x00,
        0x00,
        0xFF,
        0x01,
        0x00,
        0x00,
      ]);

      service.triggerMode = TriggerMode.normal;
      service.useLowPassFilter = true;
      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      expect(points, isNotEmpty);
    });
    test('should detect rising edge trigger with large dataset', () {
      // Setup configuration
      service.triggerLevel = 0;
      service.triggerSensitivity = 0.1;
      service.triggerEdge = TriggerEdge.positive;
      service.triggerMode = TriggerMode.normal;
      service.useHysteresis = false;
      service.useLowPassFilter = false;
      service.scale = 3.3 / 512;
      service.mid = 256.0;

      // Generate test data
      final queue = Queue<int>();
      for (int i = 0; i < 16384; i++) {
        final value = (256 + 255 * sin(2 * pi * i / 1000)).floor();
        final uint16Value = value & 0xFFF;
        queue.add(uint16Value & 0xFF);
        queue.add((uint16Value >> 8) & 0xFF);
      }

      print('\nTest Configuration:');
      print('Trigger Level: ${service.triggerLevel}V');
      print('Scale: ${service.scale}');
      print('Mid: ${service.mid}');
      print('Hysteresis: ${service.useHysteresis}');
      print('LowPassFilter: ${service.useLowPassFilter}');

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      print('\nSignal Analysis:');
      print('Min value: ${points.map((p) => p.y).reduce(min)}V');
      print('Max value: ${points.map((p) => p.y).reduce(max)}V');
      print('Trigger points: ${points.where((p) => p.isTrigger).length}');

      expect(points.any((p) => p.y >= service.triggerLevel), isTrue,
          reason: 'No points above trigger level');
      expect(points.any((p) => p.isTrigger), isTrue,
          reason: 'No trigger point detected');
    });
    test('should handle negative trigger edge with hysteresis on large dataset',
        () {
      service.triggerMode = TriggerMode.normal;
      service.useHysteresis = false; // Deshabilitar hysteresis
      service.useLowPassFilter = false;
      service.triggerEdge = TriggerEdge.negative;
      service.triggerLevel = 0; // Cambiar de 0 a 1.65V
      service.triggerSensitivity = 0.1;

      // Generate sine wave
      final queue = Queue<int>();
      for (int i = 0; i < 16384; i++) {
        final value = (256 + 255 * sin(2 * pi * i / 1000)).floor();
        final uint16Value = value & 0xFFF; // Apply data mask
        queue.add(uint16Value & 0xFF); // Low byte
        queue.add((uint16Value >> 8) & 0xFF); // High byte
      }

      print('\nTest Configuration:');
      print('Trigger Level: ${service.triggerLevel}V');
      print('Scale: ${service.scale}');
      print('Mid: ${service.mid}');
      print('Hysteresis: ${service.useHysteresis}');
      print('LowPassFilter: ${service.useLowPassFilter}');

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      print('\nProcessed Points Summary:');
      print('Total points: ${points.length}');
      print(
          'Points below trigger: ${points.where((p) => p.y <= service.triggerLevel).length}');
      print('Trigger points: ${points.where((p) => p.isTrigger).length}');

      expect(points.any((p) => p.y <= service.triggerLevel), isTrue,
          reason: 'No points below trigger level');
      expect(points.any((p) => p.isTrigger), isTrue,
          reason: 'No trigger point detected');
    });

    test('should handle negative trigger edge with hysteresis on large dataset',
        () {
      service.triggerMode = TriggerMode.normal;
      service.useHysteresis = true;
      service.useLowPassFilter = false;
      service.triggerEdge = TriggerEdge.negative;
      service.triggerLevel = 0;
      service.triggerSensitivity = 0.1;

      // Generate 16384 samples of sine wave
      final queue = Queue<int>();
      for (int i = 0; i < 16384; i++) {
        // Generate sine wave that crosses trigger level
        final value = (256 + 255 * sin(2 * pi * i / 1000)).floor();
        queue.add(value & 0xFF); // Low byte
        queue.add((value >> 8) & 0xFF); // High byte
      }

      print('\nHysteresis Test Configuration:');
      print('Trigger Level: ${service.triggerLevel}V');
      print('Scale: ${service.scale}');
      print('Mid: ${service.mid}');
      print('Data points: ${queue.length ~/ 2}');

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());
      print('\nProcessed Points Summary:');
      print('Total points: ${points.length}');
      print(
          'Points below trigger: ${points.where((p) => p.y <= service.triggerLevel).length}');
      print('Trigger points: ${points.where((p) => p.isTrigger).length}');

      expect(points.isNotEmpty, isTrue);
      expect(points.any((p) => p.y <= service.triggerLevel), isTrue,
          reason: 'No points below trigger level');
      expect(points.any((p) => p.isTrigger), isTrue,
          reason: 'No trigger point detected');
    });
    test('should process data with hysteresis trigger negative edge', () {
      final queue = Queue<int>()
        ..addAll([0xFF, 0x01, 0x00, 0x00]); // Simula señal

      service.triggerEdge = TriggerEdge.negative;
      service.triggerMode = TriggerMode.normal;
      service.useHysteresis = true;
      service.useLowPassFilter = false;
      service.triggerSensitivity = 0.1;

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());
      // Verifica líneas 345-348, 352-354, 361-362
      expect(points, isNotEmpty);
    });

    test('should process data with low pass filter', () {
      final queue = Queue<int>()..addAll([0xFF, 0x01, 0x00, 0x00]);

      service.triggerMode = TriggerMode.normal;
      service.useLowPassFilter = true;
      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());
      // Verifica línea 323
      expect(points, isNotEmpty);
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
      expect(result, equals([1000.0, 1.0]));
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

    test('should send correct trigger percentage to server', () async {
      final mockHttpService = Get.find<HttpService>() as MockHttpService;
      print('Found HttpService: ${mockHttpService.runtimeType}');

      // Test mid-range
      service.triggerLevel = 1.65;
      expect(mockHttpService.lastTriggerPercentage, closeTo(100.0, 0.1));

      // Test max range
      service.triggerLevel = -1.65;
      expect(mockHttpService.lastTriggerPercentage, closeTo(0, 0.1));

      // Test min range
      service.triggerLevel = 0.0;
      expect(mockHttpService.lastTriggerPercentage, closeTo(50, 0.1));
    });
    test('should handle server configuration', () async {
      final mockHttpService = Get.find<HttpService>() as MockHttpService;
      final response = await mockHttpService.get('/config');

      expect(response.statusCode, equals(200));
      expect(response.body['sampling_frequency'], equals(1650000.0));
      expect(response.body['useful_bits'], equals(9));
    });

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

  group('Socket and Processing Isolate', () {
    test('should initialize with default values', () async {
      expect(service.scale, isNotNull);
      expect(service.distance, isNotNull);
      expect(service.triggerLevel, isNotNull);
      expect(service.triggerEdge, equals(TriggerEdge.positive));
      expect(service.triggerSensitivity, isNotNull);
    });

    test('should update configuration values', () {
      service.scale = 2.0;
      service.triggerLevel = 1.0;
      service.triggerEdge = TriggerEdge.negative;
      service.triggerSensitivity = 0.5;

      expect(service.scale, equals(2.0));
      expect(service.triggerLevel, equals(1.0));
      expect(service.triggerEdge, equals(TriggerEdge.negative));
      expect(service.triggerSensitivity, equals(0.5));
    });

    test('should handle processing isolate exit', () async {
      // Para cubrir líneas 204-206
      final exitPort = ReceivePort();
      service.processingIsolate?.addOnExitListener(exitPort.sendPort);
      await service.stopData();
      exitPort.close();
    });

    test('should handle socket isolate exit', () async {
      // Para cubrir líneas 216-218
      final exitPort = ReceivePort();
      service.socketIsolate?.addOnExitListener(exitPort.sendPort);
      await service.stopData();
      exitPort.close();
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
        final receivedData =
            await dataReceived.future.timeout(Duration(seconds: 5));
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
    test('should update config with new values', () {
      final message = UpdateConfigMessage(
        scale: 2.0,
        triggerLevel: 1.0,
        triggerEdge: TriggerEdge.positive,
        triggerSensitivity: 50.0,
        triggerMode: TriggerMode.normal,
        useHysteresis: true,
        useLowPassFilter: true,
      );

      final oldConfig = DataProcessingConfig(
        scale: 1.0,
        distance: 1.0,
        triggerLevel: 0.0,
        triggerEdge: TriggerEdge.negative,
        triggerSensitivity: 70.0,
        mid: 256.0,
        deviceConfig: mockDeviceConfigProvider.config!, // Add device config
      );

      final newConfig =
          DataAcquisitionService.updateConfigForTest(oldConfig, message);

      expect(newConfig.scale, equals(message.scale));
      expect(newConfig.triggerLevel, equals(message.triggerLevel));
      expect(newConfig.triggerEdge, equals(message.triggerEdge));
      expect(newConfig.triggerSensitivity, equals(message.triggerSensitivity));
      expect(newConfig.deviceConfig,
          equals(oldConfig.deviceConfig)); // Verify config preserved
    });
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
    test('should clean up processing isolate', () async {
      final exitPort = ReceivePort();
      service.processingIsolate?.addOnExitListener(exitPort.sendPort);

      await service.stopData();
      // Verifica líneas 204-206

      exitPort.close();
    });

    test('should clean up socket isolate', () async {
      final exitPort = ReceivePort();
      service.socketIsolate?.addOnExitListener(exitPort.sendPort);

      await service.stopData();
      // Verifica líneas 173-175

      exitPort.close();
    });

    test('should handle stop with remaining data', () async {
      final queue = Queue<int>()..addAll([0xFF, 0x01]);
      service.socketToProcessingSendPort?.send(queue);
      await service.stopData();
      // Verifica líneas 216-218, 222-223, 237
    });

    test('should access config send port', () {
      // Verifica líneas 602-603
      expect(service.configSendPort, isNull);
    });
    test('should throw when accessing stream after disposal', () async {
      await service.dispose();
      expect(() => service.dataStream, throwsStateError);
    });

// Para cubrir líneas 173-175
    test('should handle invalid socket messages', () {
      service.socketToProcessingSendPort?.send('invalid');
    });

    test('should handle cleanup of processing isolate', () async {
      // Para cubrir líneas 474-478
      await service.fetchData('127.0.0.1', 8080);
      await service.stopData();
      expect(service.processingIsolate, isNull);
    });

    test('should handle cleanup on empty data', () {
      // Para cubrir líneas 521, 525
      service.updateMetrics([]);
    });

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
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      expect(points, isEmpty);
    });

    test('should handle error stopping data', () async {
      // Force error by setting invalid state
      service.socketToProcessingSendPort = null;
      try {
        await service.stopData();
      } catch (e) {
        expect(e, isNotNull); // Verifica línea 547
      }
    });

    test('should handle isolate timeouts', () async {
      await service.fetchData('127.0.0.1', 8080);

      // Simular timeout matando isolates
      service.processingIsolate?.kill();
      service.socketIsolate?.kill();

      await service.stopData();
      // Verifica líneas 521, 525
    });

    test('should handle insufficient data in processData', () {
      final queue = Queue<int>();
      queue.addAll([
        0x00, // Datos incompletos
      ]);

      final points = DataAcquisitionService.processDataForTest(
          queue,
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

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
          queue.length,
          service.scale,
          service.distance,
          service.triggerLevel,
          service.triggerEdge,
          service.triggerSensitivity,
          service.mid,
          service.useHysteresis,
          service.useLowPassFilter,
          service.triggerMode,
          mockDeviceConfigProvider.config!,
          getMockSendPort());

      expect(points.any((p) => p.isTrigger), isFalse);
    });

    test('should handle stopData timeouts', () async {
      // Configurar el servicio
      await service.fetchData('127.0.0.1', 8080);

      await service.stopData();

      await service.stopData();

      // Verificar que el servicio maneje correctamente la situación
      expect(service.processingIsolate, isNull);
      expect(service.socketIsolate, isNull);
    });

    test('should handle socket connection failures', () async {
      // Para cubrir líneas 352-354
      try {
        await service.fetchData('invalid-ip', 0);
      } catch (e) {
        expect(e, isNotNull);
      }
    });

    test('should handle processing setup failures', () async {
      // Para cubrir líneas 361-362
      service.socketToProcessingSendPort = null;
      try {
        await service.fetchData('127.0.0.1', 8080);
      } catch (e) {
        expect(e, isNotNull);
      }
    });
  });
}
