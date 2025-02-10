import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

class FFTChartService {
  DataAcquisitionProvider? _graphProvider;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();
  final _fftController = StreamController<List<DataPoint>>.broadcast();

  // Remove hardcoded blockSize
  late final int blockSize;
  StreamSubscription? _dataPointsSubscription;
  bool _isProcessing = false;
  bool _isPaused = false;
  static const bool _outputInDb = true;
  double _currentMaxValue = 0;

  final List<DataPoint> _dataBuffer = [];

  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  FFTChartService(this._graphProvider) {
    if (kDebugMode) {
      print("Starting FFT Service");
    }
    blockSize = deviceConfig.samplesPerPacket * 2;
    _setupSubscriptions();
  }

  double get frequency {
    if (_lastFFTPoints.isEmpty) return 0.0;

    // Parameters for peak detection
    const minPeakHeight = -160.0; // Adjusted threshold for dB scale
    const minAmplitude = 0.001; // Minimum amplitude threshold
    const startIndex = 1;

    // First check if signal amplitude is too low
    if (_currentMaxValue < minAmplitude) {
      return 0.0;
    }

    var maxIndex = 0;
    var maxMagnitude = -160.0;

    // First find valid positive slope
    var validSlopeIndex = -1;
    for (var i = startIndex; i < _lastFFTPoints.length - 1; i++) {
      if (_lastFFTPoints[i].y < _lastFFTPoints[i + 1].y) {
        validSlopeIndex = i;
        break;
      }
    }

    // Only look for peaks after valid slope
    if (validSlopeIndex >= 0) {
      for (var i = validSlopeIndex; i < _lastFFTPoints.length - 1; i++) {
        final currentMagnitude = _lastFFTPoints[i].y;
        final nextMagnitude = _lastFFTPoints[i + 1].y;

        if (currentMagnitude > minPeakHeight &&
            currentMagnitude > maxMagnitude &&
            currentMagnitude > nextMagnitude) {
          maxMagnitude = currentMagnitude;
          maxIndex = i;
        }
      }
    }

    // Return 0 if no significant peak found
    if (maxMagnitude < minPeakHeight) {
      return 0.0;
    }

    return maxIndex > 0 ? _lastFFTPoints[maxIndex].x : 0.0;
  }

  void _setupSubscriptions() {
    _dataPointsSubscription?.cancel();

    if (_graphProvider != null) {
      _dataPointsSubscription = _graphProvider!.dataPointsStream.listen(
        (points) {
          if (_isProcessing || _isPaused) return;

          // Validate input points
          if (points.isEmpty) {
            _fftController.addError(StateError('Empty points list'));
            return;
          }

          _currentMaxValue = points.map((p) => p.y.abs()).reduce(math.max);
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
              _fftController.addError(error);
            } finally {
              _isProcessing = false;
            }
          }
        },
        onError: (error) {
          _fftController.addError(error);
        },
      );
    }
  }

  void updateProvider(DataAcquisitionProvider provider) {
    _graphProvider = provider;
    _setupSubscriptions();
  }

  List<DataPoint> _lastFFTPoints = [];

  List<DataPoint> computeFFT(List<DataPoint> points, double maxValue) {
    try {
      // Validar entrada
      if (points.isEmpty) {
        throw ArgumentError('Empty points list');
      }

      final n = points.length;
      final real = Float32List(n);
      final imag = Float32List(n);

      // Load data points with validation
      for (var i = 0; i < n; i++) {
        final value = points[i].y;
        if (value.isInfinite || value.isNaN) {
          throw ArgumentError('Invalid data point at index $i: $value');
        }
        real[i] = value;
        imag[i] = 0.0;
      }

      // Perform FFT with error handling
      try {
        _fft(real, imag);
      } catch (e) {
        throw StateError('FFT computation failed: $e');
      }

      // Normalize with validation
      for (var i = 0; i < n; i++) {
        if (n == 0) throw StateError('Division by zero in normalization');
        real[i] /= n;
        imag[i] /= n;
      }

      // Calculate frequency domain points
      final halfLength = (n / 2).ceil();
      final samplingRate = deviceConfig.samplingFrequency;
      final freqResolution = samplingRate / n;

      _lastFFTPoints = List<DataPoint>.generate(halfLength, (i) {
        final re = real[i];
        final im = imag[i];

        // Validate complex values
        if (re.isInfinite || re.isNaN || im.isInfinite || im.isNaN) {
          throw StateError('Invalid FFT result at index $i');
        }

        final magnitude = math.sqrt(re * re + im * im);
        final db = _outputInDb ? _toDecibels(magnitude, maxValue) : magnitude;
        return DataPoint(i * freqResolution, db);
      });

      return _lastFFTPoints;
    } catch (e) {
      // Propagar error con contexto
      throw StateError('FFT computation failed: $e');
    }
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
