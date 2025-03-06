import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:math' as math;

/// [FFTChartService] manages the FFT (Fast Fourier Transform) data processing for the FFT chart.
class FFTChartService {
  DataAcquisitionProvider? _graphProvider;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();
  final _fftController = StreamController<List<DataPoint>>.broadcast();

  late final int blockSize;
  StreamSubscription? _dataPointsSubscription;
  bool _isProcessing = false;
  bool _isPaused = false;
  static const bool _outputInDb = true;
  double _currentMaxValue = 0;

  final List<DataPoint> _dataBuffer = [];
  List<DataPoint> _lastFFTPoints = [];

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

    const minPeakHeight = -160.0;
    const minAmplitude = 0.001;
    const startIndex = 1;

    if (_currentMaxValue < minAmplitude) {
      return 0.0;
    }

    var maxIndex = 0;
    var maxMagnitude = -160.0;

    var validSlopeIndex = -1;
    for (var i = startIndex; i < _lastFFTPoints.length - 1; i++) {
      if (_lastFFTPoints[i].y < _lastFFTPoints[i + 1].y) {
        validSlopeIndex = i;
        break;
      }
    }

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

    if (maxMagnitude < minPeakHeight) {
      return 0.0;
    }

    return maxIndex > 0 ? _lastFFTPoints[maxIndex].x : 0.0;
  }

  void _setupSubscriptions() {
    _dataPointsSubscription?.cancel();

    if (_graphProvider != null) {
      // Listen to the stream of data points from the data acquisition provider.
      _dataPointsSubscription = _graphProvider!.dataPointsStream.listen(
        (points) {
          if (_isProcessing || _isPaused) return;

          if (points.isEmpty) {
            _fftController.addError(StateError('Empty points list'));
            return;
          }

          _currentMaxValue = points.map((p) => p.y.abs()).reduce(math.max);
          _dataBuffer.addAll(points);

          // Process data when the buffer is full.
          if (_dataBuffer.length >= blockSize) {
            _isProcessing = true;
            final dataToProcess = _dataBuffer.sublist(0, blockSize);
            _dataBuffer.clear();

            try {
              // Compute FFT and add the resulting points to the stream.
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

  // Computes the FFT of the given data points.
  List<DataPoint> computeFFT(List<DataPoint> points, double maxValue) {
    try {
      if (points.isEmpty) {
        throw ArgumentError('Empty points list');
      }

      final n = points.length;
      final real = Float32List(n);
      final imag = Float32List(n);

      // Prepare real and imaginary components for FFT.
      for (var i = 0; i < n; i++) {
        final value = points[i].y;
        if (value.isInfinite || value.isNaN) {
          throw ArgumentError('Invalid data point at index $i: $value');
        }
        real[i] = value;
        imag[i] = 0.0;
      }

      try {
        // Perform the FFT using the _fft method.
        _fft(real, imag);
      } catch (e) {
        throw StateError('FFT computation failed: $e');
      }

      // Normalize the FFT results.
      for (var i = 0; i < n; i++) {
        if (n == 0) throw StateError('Division by zero in normalization');
        real[i] /= n;
        imag[i] /= n;
      }

      final halfLength = (n / 2).ceil();
      final samplingRate = deviceConfig.samplingFrequency;
      final freqResolution = samplingRate / n;

      // Convert the FFT results to DataPoint objects.
      _lastFFTPoints = List<DataPoint>.generate(halfLength, (i) {
        final re = real[i];
        final im = imag[i];

        if (re.isInfinite || re.isNaN || im.isInfinite || im.isNaN) {
          throw StateError('Invalid FFT result at index $i');
        }

        final magnitude = math.sqrt(re * re + im * im);
        final db = _outputInDb ? _toDecibels(magnitude, maxValue) : magnitude;
        return DataPoint(i * freqResolution, db);
      });

      return _lastFFTPoints;
    } catch (e) {
      throw StateError('FFT computation failed: $e');
    }
  }

  static double _toDecibels(double magnitude, double maxValue) {
    if (magnitude == 0.0) return -160.0;
    return 20 * math.log(magnitude) / math.ln10;
  }

  // Implements the FFT algorithm.
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

    // FFT computation (scalar version)
    for (var step = 1; step < n; step <<= 1) {
      final angleStep = -math.pi / step;

      for (var group = 0; group < n; group += step * 2) {
        for (var pair = 0; pair < step; pair++) {
          final angle = angleStep * pair;
          final cosAngle = math.cos(angle);
          final sinAngle = math.sin(angle);

          final evenIndex = group + pair;
          final oddIndex = evenIndex + step;

          final oddReal = real[oddIndex];
          final oddImag = imag[oddIndex];

          final rotatedReal = oddReal * cosAngle - oddImag * sinAngle;
          final rotatedImag = oddReal * sinAngle + oddImag * cosAngle;

          real[oddIndex] = real[evenIndex] - rotatedReal;
          imag[oddIndex] = imag[evenIndex] - rotatedImag;
          real[evenIndex] = real[evenIndex] + rotatedReal;
          imag[evenIndex] = imag[evenIndex] + rotatedImag;
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
