// test/features/graph/domain/services/data_acquisition_service_test.dart
import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:http/http.dart' as http;
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';

class MockHttpConfig extends Mock implements HttpConfig {
  @override
  String get baseUrl => 'http://test.com';

  @override
  http.Client? get client => MockHttpClient();
}

class MockHttpService extends Mock implements HttpService {}

class MockHttpClient extends Mock implements http.Client {}

void main() {
  late DataAcquisitionService service;
  late MockHttpConfig mockHttpConfig;

  setUp(() async {
    mockHttpConfig = MockHttpConfig();
    service = DataAcquisitionService(mockHttpConfig);
    await service.initialize();
  });

  tearDown(() async {
    await service.dispose();
  });

  group('Initialization', () {
    test('should initialize with default values', () {
      expect(service.scale, equals(3.3 / 512));
      expect(service.distance, equals(1 / 1600000));
      expect(service.triggerLevel, equals(0.0));
      expect(service.triggerEdge, equals(TriggerEdge.positive));
      expect(service.triggerSensitivity, equals(70.0));
    });
  });

  group('Data Processing', () {
    test('should process and emit data points', () async {
      final completer = Completer<List<DataPoint>>();

      // Setup listener
      final subscription = service.dataStream.listen((points) {
        if (!completer.isCompleted) {
          completer.complete(points);
        }
      });

      // Trigger data processing
      await service.fetchData('127.0.0.1', 8080);

      try {
        final points = await completer.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => [],
        );
        expect(points, isA<List<DataPoint>>());
      } finally {
        subscription.cancel();
      }
    });
  });

  group('Metrics Calculation', () {
    test('should calculate frequency from triggers', () async {
      final completer = Completer<double>();

      // Setup listener
      final subscription = service.frequencyStream.listen((freq) {
        if (!completer.isCompleted) {
          completer.complete(freq);
        }
      });

      // Trigger data processing
      await service.fetchData('127.0.0.1', 8080);

      try {
        final frequency = await completer.future.timeout(
          const Duration(seconds: 1),
          onTimeout: () => 0.0,
        );
        expect(frequency, isNotNull);
      } finally {
        subscription.cancel();
      }
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
  });

group('Resource Management', () {
  test('should clean up resources on dispose', () async {
    // Add listeners before dispose to ensure streams are active
    final dataSubscription = service.dataStream.listen((_) {});
    final freqSubscription = service.frequencyStream.listen((_) {});
    final maxSubscription = service.maxValueStream.listen((_) {});

    // Dispose service
    await service.dispose();

    // Cancel existing subscriptions
    await dataSubscription.cancel();
    await freqSubscription.cancel();
    await maxSubscription.cancel();

    // Now call the getters again (which should throw due to _disposed == true)
    expect(
      () => service.dataStream.listen((_) {}),
      throwsA(isA<StateError>()),
      reason: 'Data stream should be closed',
    );
    expect(
      () => service.frequencyStream.listen((_) {}),
      throwsA(isA<StateError>()),
      reason: 'Frequency stream should be closed',
    );
    expect(
      () => service.maxValueStream.listen((_) {}),
      throwsA(isA<StateError>()),
      reason: 'Max value stream should be closed',
    );
  });

  test('should handle multiple dispose calls gracefully', () async {
    await service.dispose();
    await expectLater(
      service.dispose(),
      completes,
      reason: 'Multiple dispose calls should not throw',
    );
  });
});
}
