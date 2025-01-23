// lib/features/graph/services/fft_chart_service.dart
import 'dart:async';
import 'dart:typed_data';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

class FFTChartService {
  final GraphProvider graphProvider;
  final _fftController = StreamController<List<DataPoint>>.broadcast();
  static const int blockSize = 8192 * 2;

  StreamSubscription? _dataPointsSubscription;
  bool _isProcessing = false;
  bool _isPaused = false;
  static bool _outputInDb = true;
  double _currentMaxValue = 0;

  final List<DataPoint> _dataBuffer = [];

  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  static void setOutputFormat(bool inDb) {
    _outputInDb = inDb;
  }

  static bool get outputInDb => _outputInDb;

  FFTChartService(this.graphProvider) {
    print("Starting FFT Service");

    _dataPointsSubscription = graphProvider.dataPointsStream.listen((points) {
      if (_isProcessing || _isPaused) return;

      if (points.isNotEmpty) {
        _currentMaxValue = points.map((p) => p.y.abs()).reduce(math.max);
      }

      _dataBuffer.addAll(points);

      if (_dataBuffer.length >= blockSize) {
        _isProcessing = true;
        final dataToProcess = _dataBuffer.sublist(0, blockSize);
        _dataBuffer.clear();

        try {
          final fftPoints = computeFFT(dataToProcess, _currentMaxValue);
          if (!_isPaused) {
            _fftController.add(fftPoints);
          }
        } catch (error) {
          print('Error processing FFT: $error');
        } finally {
          _isProcessing = false;
        }
      }
    });
  }

  List<DataPoint> computeFFT(List<DataPoint> points, double maxValue) {
    final n = points.length;
    final real = Float32List(n);
    final imag = Float32List(n);

    // Load data points
    for (var i = 0; i < n; i++) {
      real[i] = points[i].y;
      imag[i] = 0.0;
    }

    // Perform FFT
    _fft(real, imag);

    // Normalize
    for (var i = 0; i < n; i++) {
      real[i] /= n;
      imag[i] /= n;
    }

    // Calculate frequency domain points
    final halfLength = (n / 2).ceil();
    const samplingRate = 1600000.0;
    final freqResolution = samplingRate / n;

    return List<DataPoint>.generate(halfLength, (i) {
      final re = real[i];
      final im = imag[i];
      final magnitude = math.sqrt(re * re + im * im);
      final db = _outputInDb ? _toDecibels(magnitude, maxValue) : magnitude;
      return DataPoint(i * freqResolution, db);
    });
  }

  static double _toDecibels(double magnitude, double maxValue) {
    if (magnitude == 0.0) return -160.0; 
    return 20 * math.log(magnitude) / math.ln10;
  }

  void _fft(Float32List real, Float32List imag) {
    final n = real.length;

    // Bit reversal permutation
    var j = 0;
    for (var i = 0; i < n - 1; i++) {
      if (i < j) {
        var tempReal = real[i];
        var tempImag = imag[i];
        real[i] = real[j];
        imag[i] = imag[j];
        real[j] = tempReal;
        imag[j] = tempImag;
      }
      var k = n >> 1;
      while (k <= j) {
        j -= k;
        k >>= 1;
      }
      j += k;
    }

    // FFT computation with SIMD optimization
    for (var step = 1; step < n; step <<= 1) {
      final angle = -math.pi / step;

      for (var group = 0; group < n; group += (step << 1)) {
        for (var pair = 0; pair < step; pair += 4) {
          final remainingPairs = math.min(4, step - pair);

          final even = Vector4.zero();
          final evenImag = Vector4.zero();
          final odd = Vector4.zero();
          final oddImag = Vector4.zero();

          final angles = Vector4(angle * pair, angle * (pair + 1),
              angle * (pair + 2), angle * (pair + 3));

          final cosAngles = Vector4(math.cos(angles.x), math.cos(angles.y),
              math.cos(angles.z), math.cos(angles.w));

          final sinAngles = Vector4(math.sin(angles.x), math.sin(angles.y),
              math.sin(angles.z), math.sin(angles.w));

          for (var i = 0; i < remainingPairs; i++) {
            final evenIdx = group + pair + i;
            final oddIdx = evenIdx + step;

            even[i] = real[evenIdx];
            evenImag[i] = imag[evenIdx];
            odd[i] = real[oddIdx];
            oddImag[i] = imag[oddIdx];
          }

          final oddRotatedReal = odd.clone()..multiply(cosAngles);
          oddRotatedReal.sub(oddImag.clone()..multiply(sinAngles));

          final oddRotatedImag = odd.clone()..multiply(sinAngles);
          oddRotatedImag.add(oddImag.clone()..multiply(cosAngles));

          final sumReal = even.clone()..add(oddRotatedReal);
          final sumImag = evenImag.clone()..add(oddRotatedImag);
          final diffReal = even.clone()..sub(oddRotatedReal);
          final diffImag = evenImag.clone()..sub(oddRotatedImag);

          for (var i = 0; i < remainingPairs; i++) {
            final evenIdx = group + pair + i;
            final oddIdx = evenIdx + step;

            real[evenIdx] = sumReal[i];
            imag[evenIdx] = sumImag[i];
            real[oddIdx] = diffReal[i];
            imag[oddIdx] = diffImag[i];
          }
        }
      }
    }
  }

  void pause() {
    _isPaused = true;
    _dataBuffer.clear();
  }

  void resume() {
    _isPaused = false;
  }

  Future<void> dispose() async {
    _dataPointsSubscription?.cancel();
    await _fftController.close();
    _dataBuffer.clear();
  }
}
