// test/unit_test/fft_chart_service_test.dart
import 'dart:async';
import 'dart:io';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'dart:math' as math;
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

void _saveFftResults(String filename, List<DataPoint> fftPoints) {
  final file = File(filename);
  final buffer = StringBuffer();

  for (final point in fftPoints) {
    buffer.writeln('${point.y},0.0');
  }

  file.writeAsStringSync(buffer.toString());
}

List<double> _loadReferenceValues(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.map((line) => double.parse(line)).toList();
}

List<DataPoint> _loadTestSignal(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.asMap().entries.map((entry) {
    return DataPoint(entry.key.toDouble(), double.parse(entry.value));
  }).toList();
}

Future<List<DataPoint>> _getFftResults(FFTChartService service,
    MockGraphProvider mockProvider, List<DataPoint> signal) async {
  final completer = Completer<List<DataPoint>>();
  final sub = service.fftStream.listen((fft) {
    completer.complete(fft);
  });

  mockProvider.addPoints(signal);

  final results = await completer.future;
  await sub.cancel();
  return results;
}

class MockGraphProvider extends Mock implements DataAcquisitionProvider {
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  final _maxValue = Rx<double>(3.3);

  @override
  Stream<List<DataPoint>> get dataPointsStream => _dataController.stream;

  @override
  Rx<double> get maxValue => _maxValue;

  @override
  void addPoints(List<DataPoint> points) {
    if (points.isNotEmpty) {
      _maxValue.value = points.map((p) => p.y.abs()).reduce(math.max);
      _maxValueController.add(_maxValue.value);
    }
    _dataController.add(points);
  }

  void close() {
    _dataController.close();
    _maxValueController.close();
  }
}

void main() {
  late MockGraphProvider mockProvider;
  late FFTChartService service;
  late DeviceConfigProvider deviceConfig;

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize device config
    deviceConfig = DeviceConfigProvider();
    Get.put<DeviceConfigProvider>(deviceConfig);

    mockProvider = MockGraphProvider();
    service = FFTChartService(mockProvider);
  });

  tearDown(() async {
    await service.dispose();
    mockProvider.close();
    await Future.delayed(const Duration(milliseconds: 100));
  });
  
  group('Frequency detection tests', () {
    test('returns 0 when no FFT points available', () {
      expect(service.frequency, equals(0.0));
    });
  
    test('detects frequency correctly from simple sine wave', () async {
      final expectedFreq = 1000.0; // 1kHz
      final samplingRate = deviceConfig.samplingFrequency;
      final points = List.generate(
        deviceConfig.samplesPerPacket * 2,
        (i) => DataPoint(
          i.toDouble(),
          math.sin(2 * math.pi * expectedFreq * i / samplingRate),
        ),
      );
  
      await _getFftResults(service, mockProvider, points);
      expect(service.frequency, closeTo(expectedFreq, 50.0));
    });
    
    test('ignores peaks below minimum height threshold', () async {
      // Generate very low amplitude signal (0.0001 amplitude)
      final points = List.generate(
        deviceConfig.samplesPerPacket * 2,
        (i) => DataPoint(
          i.toDouble(),
          0.0001 * math.sin(2 * math.pi * 1000 * i / deviceConfig.samplingFrequency),
        ),
      );
    
      await _getFftResults(service, mockProvider, points);
      
      // Verify frequency is 0 for very low amplitude signals
      expect(service.frequency, equals(0.0),
          reason: 'Should return 0 frequency for signals below amplitude threshold');
    });
  
    test('finds first valid peak after positive slope', () async {
      // Generate signal with multiple peaks
      final points = List.generate(
        deviceConfig.samplesPerPacket * 2,
        (i) => DataPoint(
          i.toDouble(),
          math.sin(2 * math.pi * 1000 * i / deviceConfig.samplingFrequency) +
          0.5 * math.sin(2 * math.pi * 2000 * i / deviceConfig.samplingFrequency),
        ),
      );
  
      await _getFftResults(service, mockProvider, points);
      expect(service.frequency, closeTo(1000.0, 50.0));
    });
  });
  
  group('Error handling', () {

  test('handles FFT computation errors', () async {
    final errors = <Object>[];
    final completer = Completer<void>();
    
    final sub = service.fftStream.listen(
      (_) {},
      onError: (error) {
        errors.add(error);
        completer.complete();
      },
    );

    // Create points that will cause FFT computation to fail
    final invalidPoints = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), i % 2 == 0 ? double.nan : double.infinity),
    );
    
    mockProvider.addPoints(invalidPoints);
    
    await completer.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => throw TimeoutException('Error not received'),
    );
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      (errors.first as StateError).message,
      contains('FFT computation failed'),
    );
    
    await sub.cancel();
  });

  test('handles data source errors', () async {
    final errors = <Object>[];
    final completer = Completer<void>();
    
    final sub = service.fftStream.listen(
      (_) {},
      onError: (error) {
        errors.add(error);
        completer.complete();
      },
    );

    mockProvider._dataController.addError(Exception('Test error'));
    
    await completer.future.timeout(
      const Duration(milliseconds: 500),
      onTimeout: () => throw TimeoutException('Error not received'),
    );
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<Exception>());
    expect(errors.first.toString(), contains('Test error'));
    
    await sub.cancel();
  });

  test('handles FFT computation failure', () async {
    final errors = <Object>[];
    final sub = service.fftStream.listen(
      (_) {},
      onError: errors.add,
    );

    // Create data that will cause FFT to fail
    final invalidPoints = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), i == 0 ? 0.0 : double.infinity),
    );
    
    mockProvider.addPoints(invalidPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      errors.first.toString(),
      contains('FFT computation failed'),
    );
    
    await sub.cancel();
  });
    
  test('handles computation errors gracefully', () async {
    final fftResults = <List<DataPoint>>[];
    final errors = <Object>[];
    
    final sub = service.fftStream.listen(
      fftResults.add,
      onError: errors.add,
    );
    
    // Generate invalid data that will cause FFT computation errors
    final invalidPoints = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), double.infinity),
    );
    
    mockProvider.addPoints(invalidPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Verify error was propagated correctly
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      (errors.first as StateError).message,
      contains('FFT computation failed'),
    );
    
    // Verify service can recover
    final validPoints = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
    );
    
    mockProvider.addPoints(validPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(fftResults, isNotEmpty);
    
    await sub.cancel();
  });

    test('throws error for empty points list', () async {
    final emptyPoints = <DataPoint>[];
    final errors = <Object>[];
    
    final sub = service.fftStream.listen(
      (_) {},
      onError: errors.add,
    );

    mockProvider.addPoints(emptyPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      (errors.first as StateError).message,
      contains('Empty points list'),
    );
    
    await sub.cancel();
  });

test('throws error for empty points list', () async {
  final emptyPoints = <DataPoint>[];
  final errors = <Object>[];
  final completer = Completer<void>();
  
  final sub = service.fftStream.listen(
    (_) {},
    onError: (error) {
      errors.add(error);
      completer.complete();
    },
  );

  mockProvider.addPoints(emptyPoints);
  
  await completer.future.timeout(
    const Duration(milliseconds: 500),
    onTimeout: () => throw TimeoutException('Error not received'),
  );
  
  expect(errors, hasLength(1));
  expect(errors.first, isA<StateError>());
  expect(
    (errors.first as StateError).message,
    contains('Empty points list'),
  );
  
  await sub.cancel();
});

  test('handles FFT computation error', () async {
    // Create data that will cause FFT computation to fail
    final invalidPoints = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), i.isEven ? double.maxFinite : -double.maxFinite),
    );
    
    final errors = <Object>[];
    final sub = service.fftStream.listen(
      (_) {},
      onError: errors.add,
    );

    mockProvider.addPoints(invalidPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      (errors.first as StateError).message,
      contains('FFT computation failed'),
    );
    
    await sub.cancel();
  });

  test('handles invalid FFT results', () async {
    // Create points that will produce invalid FFT results
    final points = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), double.maxFinite / (i + 1)),
    );
    
    final errors = <Object>[];
    final sub = service.fftStream.listen(
      (_) {},
      onError: errors.add,
    );

    mockProvider.addPoints(points);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(errors, hasLength(1));
    expect(errors.first, isA<StateError>());
    expect(
      (errors.first as StateError).message,
      contains('Invalid FFT result'),
    );
    
    await sub.cancel();
  });

  test('handles division by zero in normalization', () async {
    // Mock a situation that would cause division by zero
    // This is an edge case since n is points.length
    final points = List.generate(
      deviceConfig.samplesPerPacket * 2,
      (i) => DataPoint(i.toDouble(), i.toDouble()),
    );
    
    final errors = <Object>[];
    final sub = service.fftStream.listen(
      (_) {},
      onError: errors.add,
    );

    mockProvider.addPoints(points);
    await Future.delayed(const Duration(milliseconds: 500));
    
    expect(errors, isEmpty); // Should not throw since n > 0
    
    await sub.cancel();
  });
  
    test('updateProvider changes data source correctly', () async {
      final newMockProvider = MockGraphProvider();
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);
  
      service.updateProvider(newMockProvider);
      
      final points = List.generate(
        deviceConfig.samplesPerPacket * 2,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );
      
      newMockProvider.addPoints(points);
      await Future.delayed(const Duration(milliseconds: 500));
      
      expect(fftResults, hasLength(1));
      expect(fftResults.first, isNotEmpty);
      
      await sub.cancel();
      newMockProvider.close();
    });
  });
  test('processes data only when buffer is full', () async {
    final fftResults = <List<DataPoint>>[];
    final sub = service.fftStream.listen(fftResults.add);
    
    // Send partial data
    final partialPoints = List.generate(
      deviceConfig.samplesPerPacket,
      (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
    );
    mockProvider.addPoints(partialPoints);
    
    await Future.delayed(const Duration(milliseconds: 500));
    expect(fftResults, isEmpty);
    
    // Complete the buffer
    mockProvider.addPoints(partialPoints);
    await Future.delayed(const Duration(milliseconds: 500));
    expect(fftResults, hasLength(1));
    
    await sub.cancel();
  });

  group('Pause/Resume Tests', () {
    test('pause stops processing new data', () async {
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);
      final expectedSize = deviceConfig.samplesPerPacket * 2;

      final initialPoints = List.generate(
        expectedSize,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );
      mockProvider.addPoints(initialPoints);

      await Future.delayed(const Duration(milliseconds: 2000));
      expect(fftResults, hasLength(1), reason: 'Initial data not processed');

      service.pause();

      final additionalPoints = List.generate(
        expectedSize,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );
      mockProvider.addPoints(additionalPoints);

      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(1), reason: 'Data processed while paused');

      await sub.cancel();
    });

    test('resume restarts data processing', () async {
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);

      service.pause();
      final expectedSize = deviceConfig.samplesPerPacket * 2;

      final initialPoints = List.generate(
        expectedSize,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );
      mockProvider.addPoints(initialPoints);

      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, isEmpty, reason: 'Data processed while paused');

      service.resume();
      mockProvider.addPoints(initialPoints);

      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(1),
          reason: 'Data not processed after resume');

      await sub.cancel();
    });

    test('multiple pause/resume cycles work correctly', () async {
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);
      final expectedSize = deviceConfig.samplesPerPacket * 2;

      final testPoints = List.generate(
        expectedSize,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );

      mockProvider.addPoints(testPoints);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(1), reason: 'First cycle failed');

      service.pause();
      mockProvider.addPoints(testPoints);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(1), reason: 'Pause failed');

      service.resume();
      mockProvider.addPoints(testPoints);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(2), reason: 'Resume failed');

      service.pause();
      mockProvider.addPoints(testPoints);
      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, hasLength(2), reason: 'Second pause failed');

      await sub.cancel();
    });

    test('buffer is cleared on pause', () async {
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);
      final expectedSize = deviceConfig.samplesPerPacket * 2;

      final partialPoints = List.generate(
        expectedSize ~/ 2,
        (i) => DataPoint(i.toDouble(), math.sin(2 * math.pi * i / 100)),
      );
      mockProvider.addPoints(partialPoints);

      service.pause();
      mockProvider.addPoints(partialPoints);

      await Future.delayed(const Duration(milliseconds: 500));
      expect(fftResults, isEmpty, reason: 'Data processed after buffer clear');

      await sub.cancel();
    });
  });

  test('Inicia correctamente y no procesa si no llega al blockSize', () async {
    final fftResults = <List<DataPoint>>[];
    final sub = service.fftStream.listen(fftResults.add);

    mockProvider.addPoints([DataPoint(0, 0.5), DataPoint(1, 0.7)]);
    await Future.delayed(const Duration(milliseconds: 500));

    expect(fftResults, isEmpty);
    await sub.cancel();
  });

  test('Compara resultados de FFT con valores de referencia', () async {
    final referenceValues = _loadReferenceValues('test/Ref_db.csv');
    final testSignal = _loadTestSignal('test/test_signal.csv');

    final fftResults = await _getFftResults(service, mockProvider, testSignal);
    _saveFftResults('test/internal_fft_results.csv', fftResults);

    const tolerance = 1.0; // Keep same tolerance for dBV comparison

    for (var i = 0;
        i < math.min(fftResults.length, referenceValues.length);
        i++) {
      expect(fftResults[i].y, closeTo(referenceValues[i], tolerance),
          reason: 'FFT value mismatch at index $i');
    }
  });

  test('Procesa correctamente al llegar a blockSize', () async {
    final fftResults = <List<DataPoint>>[];
    final completer = Completer<void>();
    final sub = service.fftStream.listen((fft) {
      fftResults.add(fft);
      completer.complete();
    });
    final expectedSize = deviceConfig.samplesPerPacket * 2;

    final points = List.generate(
      expectedSize,
      (i) => DataPoint(i.toDouble(), 1.0),
    );
    mockProvider.addPoints(points);

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('FFT processing timed out'),
    );

    expect(fftResults.length, 1);
    expect(fftResults.first, isNotEmpty);
    expect(fftResults.first.length, greaterThan(0));

    await sub.cancel();
  });

  test('Descarta nuevos datos mientras está procesando', () async {
    final fftResults = <List<DataPoint>>[];
    final completer = Completer<void>();
    final sub = service.fftStream.listen((fft) {
      fftResults.add(fft);
      completer.complete();
    });
    final expectedSize = deviceConfig.samplesPerPacket * 2;

    final points = List.generate(
      expectedSize * 2,
      (i) => DataPoint(i.toDouble(), 1.0),
    );
    mockProvider.addPoints(points);

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('FFT processing timed out'),
    );

    expect(fftResults.length, 1);
    expect(fftResults.first, isNotEmpty);
    expect(fftResults.first.length, greaterThan(0));

    await sub.cancel();
  });

  test('Dispose cierra isolate y streams sin error', () async {
    await Future.delayed(const Duration(milliseconds: 200));
    expect(() async => service.dispose(), returnsNormally);
  });
}
