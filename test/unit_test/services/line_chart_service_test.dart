// test/unit_test/line_chart_service_test.dart
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';

class MockDataAcquisitionProvider extends Mock
    implements DataAcquisitionProvider {
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _triggerMode = Rx<TriggerMode>(TriggerMode.normal);

  @override
  Stream<List<DataPoint>> get dataPointsStream => _dataController.stream;

  @override
  Rx<TriggerMode> get triggerMode => _triggerMode;

  @override
  void addPoints(List<DataPoint> points) => _dataController.add(points);
  @override
  void dispose() => _dataController.close();
}

void main() {
  late MockDataAcquisitionProvider mockProvider;
  late OscilloscopeChartService service;
  late DeviceConfigProvider deviceConfig;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize device config
    deviceConfig = DeviceConfigProvider();
    deviceConfig.updateConfig(DeviceConfig(
      samplingFrequency: 1000000,
      bitsPerPacket: 16,
      dataMask: 0x0FFF,
      channelMask: 0xF000,
      // ignore: deprecated_member_use_from_same_package
      usefulBits: 12,
      samplesPerPacket: 4096,
      dividingFactor: 1,
    ));

    Get.put<DeviceConfigProvider>(deviceConfig);
    mockProvider = MockDataAcquisitionProvider();
    service = OscilloscopeChartService(mockProvider);
  });

  tearDown(() async {
    await service.dispose();
    mockProvider.dispose();
    Get.reset();
  });

  group('Basic functionality', () {
    test('constructs with null provider', () {
      final service = OscilloscopeChartService(null);
      expect(service.dataStream, isNotNull);
      expect(service.isPaused, false);
    });

    test('returns correct distance based on sampling frequency', () {
      expect(service.distance, equals(1 / deviceConfig.samplingFrequency));
    });

    test('emits data correctly from provider stream', () async {
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      final points = [
        DataPoint(0.0, 1.0),
        DataPoint(1.0, 2.0),
      ];
      mockProvider.addPoints(points);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1);
      expect(emittedData.first, points);

      await sub.cancel();
    });
  });

  group('Provider updates', () {
    test('updateProvider changes provider and sets up new subscription',
        () async {
      final newProvider = MockDataAcquisitionProvider();
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      service.updateProvider(newProvider);

      final points = [DataPoint(0.0, 1.0)];
      newProvider.addPoints(points);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1);
      expect(emittedData.first, points);

      await sub.cancel();
      newProvider.dispose();
    });
  });

  group('Trigger mode behavior', () {
    test('auto-pauses on trigger in single mode', () async {
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      // Set trigger mode to single
      mockProvider.triggerMode.value = TriggerMode.single;

      // Send data with trigger
      final points = [
        DataPoint(0.0, 1.0),
        DataPoint(1.0, 2.0, isTrigger: true),
        DataPoint(2.0, 3.0),
      ];
      mockProvider.addPoints(points);

      // Wait for processing
      await Future.delayed(const Duration(milliseconds: 50));

      // Verify single emission and paused state
      expect(emittedData.length, 1, reason: 'Should emit points exactly once');
      expect(emittedData.first, points,
          reason: 'Should emit the correct points');
      expect(service.isPaused, true,
          reason: 'Service should be paused after trigger');

      // Verify no more emissions while paused
      mockProvider.addPoints([DataPoint(3.0, 4.0)]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1, reason: 'Should not emit while paused');

      await sub.cancel();
    });

    test('resumeAndWaitForTrigger resets paused state', () async {
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      service.pause();
      expect(service.isPaused, true);

      service.resumeAndWaitForTrigger();
      expect(service.isPaused, false);

      final points = [DataPoint(0.0, 1.0)];
      mockProvider.addPoints(points);

      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1);
      expect(emittedData.first, points);

      await sub.cancel();
    });
  });

  group('Pause/Resume functionality', () {
    test('pause stops data emission', () async {
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      final points1 = [DataPoint(0.0, 1.0)];
      mockProvider.addPoints(points1);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1);

      service.pause();
      final points2 = [DataPoint(1.0, 2.0)];
      mockProvider.addPoints(points2);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1); // Should not receive new data

      await sub.cancel();
    });

    test('resume restarts data emission', () async {
      final emittedData = <List<DataPoint>>[];
      final sub = service.dataStream.listen(emittedData.add);

      service.pause();
      mockProvider.addPoints([DataPoint(0.0, 1.0)]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.isEmpty, true);

      service.resume();
      final points = [DataPoint(1.0, 2.0)];
      mockProvider.addPoints(points);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(emittedData.length, 1);
      expect(emittedData.first, points);

      await sub.cancel();
    });
  });

  group('Cleanup', () {
    test('dispose cancels subscriptions and closes streams', () async {
      mockProvider.addPoints([DataPoint(0.0, 1.0)]);
      await Future.delayed(const Duration(milliseconds: 50));
      expect(() => service.dispose(), returnsNormally);
    });
  });
}
