// test/unit_test/fft_chart_service_test.dart
import 'dart:async';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'dart:math' as math;
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_provider.dart';

// Helper functions
void _saveComplexToMagnitude(String inputFile, String outputFile) {
  final input = File(inputFile);
  final output = File(outputFile);
  final buffer = StringBuffer();
  
  final lines = input.readAsLinesSync();
  for (final line in lines) {
    final parts = line.split(',');
    if (parts.length == 2) {
      final real = double.parse(parts[0]);
      final imag = double.parse(parts[1]);
      final magnitude = math.sqrt(real * real + imag * imag);
      buffer.writeln(magnitude.toString());
    }
  }
  
  output.writeAsStringSync(buffer.toString());
}

void _saveMagnitudeToDb(String inputFile, String outputFile) {
  final input = File(inputFile);
  final output = File(outputFile);
  final buffer = StringBuffer();
  
  final lines = input.readAsLinesSync();
  for (final line in lines) {
    final magnitude = double.parse(line);
    buffer.writeln(_toDb(magnitude).toString());
  }
  
  output.writeAsStringSync(buffer.toString());
}

double _toDb(double magnitude) {
  if (magnitude == 0) return -160.0;
  const bitsPerSample = 9.0;
  final fullScale = math.pow(2, bitsPerSample - 1).toDouble();
  final normFactor = 20 * math.log(fullScale) / math.ln10;
  return 20 * math.log(magnitude) / math.ln10 + normFactor;
}

void _checkPeak(
  List<DataPoint> fft,
  double freq,
  double expectedValue,
  double freqTolerance,
  double valueTolerance
) {
  final peak = fft
      .where((p) => (p.x - freq).abs() < freqTolerance)
      .reduce((a, b) => a.y.abs() > b.y.abs() ? a : b);
      
  expect(peak, isNotNull, reason: 'No peak found near $freq Hz');
  expect(
    peak.x,
    closeTo(freq, freqTolerance),
    reason: 'Peak frequency offset at $freq Hz'
  );
  expect(
    peak.y,
    closeTo(expectedValue, valueTolerance),
    reason: 'Incorrect value at $freq Hz'
  );
}

void _saveFftResults(String filename, List<DataPoint> fftPoints) {
  final file = File(filename);
  final buffer = StringBuffer();
  
  // Save FFT results in dB with imaginary part 0
  for (final point in fftPoints) {
    buffer.writeln('${point.y},0.0');
  }
  
  file.writeAsStringSync(buffer.toString());
}

List<double> _loadReferenceValues(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.map((line) {
    final value = double.parse(line);
    return value;
  }).toList();
}

List<DataPoint> _loadTestSignal(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.asMap().entries.map((entry) {
    return DataPoint(entry.key.toDouble(), double.parse(entry.value));
  }).toList();
}

Future<List<DataPoint>> _getFftResults(
  FFTChartService service,
  MockGraphProvider mockProvider,
  List<DataPoint> signal
) async {
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
    await Future.delayed(const Duration(milliseconds: 300));
    
    // Convert test signal files if necessary
    // _saveComplexToMagnitude('test/Ref_db.csv', 'test/Ref_db_magnitude.csv');
    // _saveMagnitudeToDb('test/Ref_db_magnitude.csv', 'test/Ref_db_dB.csv');
  });

  tearDown(() async {
    service.dispose();
    mockProvider.close();
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

  
  test('Compara resultados de FFT con valores de referencia', () async {
    final referenceValues = _loadReferenceValues('test/Ref_db.csv');
    final testSignal = _loadTestSignal('test/test_signal.csv');

    final fftResults = await _getFftResults(service, mockProvider, testSignal);
    
    // Save FFT results if needed
    _saveFftResults('test/internal_fft_results.csv', fftResults);
    
    const tolerance = 1.0;

    for (var i = 0; i < math.min(fftResults.length, referenceValues.length); i++) {
      expect(
        fftResults[i].y,
        closeTo(referenceValues[i], tolerance),
        reason: 'FFT value mismatch at index $i'
      );
    }
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

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('FFT processing timed out')
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

    final points = List.generate(
      FFTChartService.blockSize * 2,
      (i) => DataPoint(i.toDouble(), 1.0),
    );
    mockProvider.addPoints(points);

    await completer.future.timeout(
      const Duration(seconds: 10),
      onTimeout: () => throw TimeoutException('FFT processing timed out')
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