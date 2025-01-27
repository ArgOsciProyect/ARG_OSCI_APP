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
import 'package:arg_osci_app/features/graph/providers/data_provider.dart';

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

class MockGraphProvider extends Mock implements GraphProvider {
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  final _maxValueController = StreamController<double>.broadcast();
  final _maxValue = Rx<double>(3.3);

  @override
  Stream<List<DataPoint>> get dataPointsStream => _dataController.stream;

  @override
  Rx<double> get maxValue => _maxValue;

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

  group('Pause/Resume Tests', () {
    test('pause stops processing new data', () async {
      final fftResults = <List<DataPoint>>[];
      final sub = service.fftStream.listen(fftResults.add);
      final expectedSize = deviceConfig.samplesPerPacket *2;

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
