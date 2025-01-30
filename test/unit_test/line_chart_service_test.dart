import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/graph/domain/services/line_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

// Mocks
class MockGraphProvider extends Mock implements DataAcquisitionProvider {
  final _controller = StreamController<List<DataPoint>>.broadcast();

  @override
  Stream<List<DataPoint>> get dataPointsStream => _controller.stream;

  void addPoints(List<DataPoint> points) => _controller.add(points);

  void close() => _controller.close();
}

void main() {
  late MockGraphProvider mockProvider;
  late LineChartService service;
  late DeviceConfigProvider deviceConfigProvider;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize DeviceConfigProvider first
    deviceConfigProvider = DeviceConfigProvider();
    deviceConfigProvider.updateConfig(DeviceConfig(
      samplingFrequency: 1650000.0,
      bitsPerPacket: 16,
      dataMask: 0x0FFF,
      channelMask: 0xF000,
      usefulBits: 12,
      samplesPerPacket: 4096,
    ));

    // Put provider before creating service
    Get.put<DeviceConfigProvider>(deviceConfigProvider);

    mockProvider = MockGraphProvider();
    service = LineChartService(mockProvider);
  });

  tearDown(() async {
    await service.dispose();
    mockProvider.close();
    Get.reset(); // Clean up GetX bindings
  });

  test('Emite datos correctamente al recibir dataPointsStream', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    final points = [
      DataPoint(0.0, 1.0),
      DataPoint(1.0, 2.0),
      DataPoint(2.0, 3.0),
    ];
    mockProvider.addPoints(points);

    // Allow some time for the data to propagate
    await Future.delayed(const Duration(milliseconds: 100));

    expect(emittedData.length, 1);
    expect(emittedData.first, points);

    await sub.cancel();
  });

  test('Emite múltiples conjuntos de datos correctamente', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    final points1 = [
      DataPoint(0.0, 1.0),
      DataPoint(1.0, 2.0),
    ];
    final points2 = [
      DataPoint(2.0, 3.0),
      DataPoint(3.0, 4.0),
    ];

    mockProvider.addPoints(points1);
    mockProvider.addPoints(points2);

    // Allow some time for the data to propagate
    await Future.delayed(const Duration(milliseconds: 100));

    expect(emittedData.length, 2);
    expect(emittedData[0], points1);
    expect(emittedData[1], points2);

    await sub.cancel();
  });

  test('No emite datos cuando no se reciben puntos', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    // No points added
    await Future.delayed(const Duration(milliseconds: 100));

    expect(emittedData, isEmpty);

    await sub.cancel();
  });

  test('Dispose cancela suscripciones y cierra streams sin error', () async {
    // Emit some data before disposing
    mockProvider.addPoints([
      DataPoint(0.0, 1.0),
      DataPoint(1.0, 2.0),
    ]);

    // Allow time for data to be emitted
    await Future.delayed(const Duration(milliseconds: 100));

    // Attempt to dispose
    expect(() => service.dispose(), returnsNormally);
  });

  // Add these tests to line_chart_service_test.dart
  test('pause stops data emission', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    // Initial data
    final points1 = [DataPoint(0.0, 1.0)];
    mockProvider.addPoints(points1);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 1);

    // Pause and send more data
    service.pause();
    final points2 = [DataPoint(1.0, 2.0)];
    mockProvider.addPoints(points2);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 1); // Should not receive new data

    await sub.cancel();
  });

  test('resume restarts data emission', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    service.pause();
    final points1 = [DataPoint(0.0, 1.0)];
    mockProvider.addPoints(points1);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.isEmpty, true);

    service.resume();
    final points2 = [DataPoint(1.0, 2.0)];
    mockProvider.addPoints(points2);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 1);
    expect(emittedData.first, points2);

    await sub.cancel();
  });

  test('handles multiple pause/resume cycles', () async {
    final emittedData = <List<DataPoint>>[];
    final sub = service.dataStream.listen(emittedData.add);

    // Cycle 1
    service.pause();
    mockProvider.addPoints([DataPoint(0.0, 1.0)]);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.isEmpty, true);

    service.resume();
    final points1 = [DataPoint(1.0, 2.0)];
    mockProvider.addPoints(points1);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 1);

    // Cycle 2
    service.pause();
    mockProvider.addPoints([DataPoint(2.0, 3.0)]);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 1);

    service.resume();
    final points2 = [DataPoint(3.0, 4.0)];
    mockProvider.addPoints(points2);
    await Future.delayed(const Duration(milliseconds: 100));
    expect(emittedData.length, 2);

    await sub.cancel();
  });
}
