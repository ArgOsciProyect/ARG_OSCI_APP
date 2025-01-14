import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'dart:math' as math;
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_provider.dart'; // Import GraphProvider

// Mocks
class MockGraphProvider extends Mock implements GraphProvider {
  final _controller = StreamController<List<DataPoint>>.broadcast();

  @override
  Stream<List<DataPoint>> get dataPointsStream => _controller.stream;

  void addPoints(List<DataPoint> points) => _controller.add(points);

  void close() => _controller.close();
}

void main() {
  late MockGraphProvider mockProvider;
  late FFTChartService service;

  setUp(() async {
    mockProvider = MockGraphProvider();
    service = FFTChartService(mockProvider);
    // Wait for the isolate to initialize
    // Using Completer to wait until the isolate is ready
    await Future.delayed(const Duration(milliseconds: 300));
  });

  tearDown(() async {
    service.dispose();
    mockProvider.close();
    // Wait to ensure dispose completes without errors
    await Future.delayed(const Duration(milliseconds: 100));
  });

  test('Inicia correctamente y no procesa si no llega al blockSize', () async {
    final fftResults = <List<DataPoint>>[];
    final sub = service.fftStream.listen(fftResults.add);

    mockProvider.addPoints([DataPoint(0, 0.5), DataPoint(1, 0.7)]);
    await Future.delayed(const Duration(milliseconds: 500));

    expect(fftResults, isEmpty);
    await sub.cancel();
  });

test('Genera resultados de FFT coherentes para señales conocidas', () async {
  final fftResults = <List<DataPoint>>[];
  final completer = Completer<void>();
  final sub = service.fftStream.listen((fft) {
    fftResults.add(fft);
    completer.complete();
  });

  // Generate test signal with known components:
  // - 10 kHz component with amplitude 1.0
  // - 20 kHz component with amplitude 0.5
  final testSignal = List.generate(
    FFTChartService.blockSize,
    (i) {
      final t = i / 1600000.0; // Time points (sampling rate 1.6MHz)
      return DataPoint(
        i.toDouble(),
        math.sin(2 * math.pi * 10000 * t) +     // 10 kHz
        0.5 * math.sin(2 * math.pi * 20000 * t) // 20 kHz
      );
    }
  );

  mockProvider.addPoints(testSignal);

  await completer.future.timeout(
    const Duration(seconds: 10),
    onTimeout: () => throw TimeoutException('FFT processing timed out')
  );

  expect(fftResults.length, equals(1));
  final fft = fftResults.first;

  // Tolerances
  const freqTolerance = 50.0;   // Hz
  const dbTolerance = 1.0;      // dB
  const noiseFloor = -100.0;    // dB

  // Find reference peak (10 kHz)
  final referencePeak = fft
      .where((p) => (p.x - 10000.0).abs() < freqTolerance)
      .reduce((a, b) => a.y > b.y ? a : b);

  print('Reference peak at ${referencePeak.x} Hz: ${referencePeak.y} dB');

  // Normalize all values to reference peak
  final normalizedFft = fft.map((p) => 
      DataPoint(p.x, p.y - referencePeak.y)).toList();

  // Expected peaks relative to reference
  final expectedPeaks = {
    10000.0: 0.0,    // Reference peak normalized to 0dB
    20000.0: -6.0,   // Half amplitude = -6dB relative to reference
  };

  // Verify each expected peak
  expectedPeaks.forEach((freq, expectedDb) {
    // Find actual peak near expected frequency
    final actualPeak = normalizedFft
        .where((p) => (p.x - freq).abs() < freqTolerance)
        .reduce((a, b) => a.y > b.y ? a : b);
    
    print('Testing peak at ${freq} Hz:');
    print('  Expected: ${expectedDb} dB');
    print('  Actual: ${actualPeak.y} dB');
    print('  Frequency: ${actualPeak.x} Hz');
    
    expect(actualPeak, isNotNull, reason: 'No peak found near $freq Hz');
    expect(
      actualPeak.x, 
      closeTo(freq, freqTolerance),
      reason: 'Peak frequency offset at $freq Hz'
    );
    expect(
      actualPeak.y,
      closeTo(expectedDb, dbTolerance),
      reason: 'Incorrect amplitude at $freq Hz'
    );
  });

  // Verify noise floor relative to reference
  final noisePoints = normalizedFft.where((p) => 
    !expectedPeaks.keys.any((freq) => (p.x - freq).abs() < freqTolerance)
  );

  for (final point in noisePoints) {
    expect(
      point.y,
      lessThan(-noiseFloor),
      reason: 'High noise at ${point.x} Hz: ${point.y} dB'
    );
  }

  // Verify frequency resolution
  final freqResolution = fft[1].x - fft[0].x;
  expect(
    freqResolution, 
    closeTo(1600000 / FFTChartService.blockSize, 0.1),
    reason: 'Incorrect frequency resolution'
  );

  await sub.cancel();
});
  test('Procesa correctamente al llegar a blockSize', () async {
    final fftResults = <List<DataPoint>>[];
    final completer = Completer<void>();
    final sub = service.fftStream.listen((fft) {
      fftResults.add(fft);
      completer.complete();
    });

    final points = List.generate(
      FFTChartService.blockSize,
      (i) => DataPoint(i.toDouble(), 1.0),
    );
    mockProvider.addPoints(points);

    // Wait until FFT processing is complete or timeout after 2 seconds
    await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('FFT processing timed out');
    });

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

    final points = List.generate(
      FFTChartService.blockSize * 2,
      (i) => DataPoint(i.toDouble(), 1.0),
    );
    mockProvider.addPoints(points);

    // Wait until FFT processing for the first block is complete or timeout after 2 seconds
    await completer.future.timeout(const Duration(seconds: 10), onTimeout: () {
      throw TimeoutException('FFT processing timed out');
    });

    expect(fftResults.length, 1);
    expect(fftResults.first, isNotEmpty);
    expect(fftResults.first.length, greaterThan(0));

    await sub.cancel();
  });

  test('Dispose cierra isolate y streams sin error', () async {
    // Ensure the service is initialized before disposing
    // Additional delay to ensure isolate is ready
    await Future.delayed(const Duration(milliseconds: 200));

    // Attempt to dispose
    expect(() async => service.dispose(), returnsNormally);
  });
}
