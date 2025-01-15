// lib/features/graph/services/fft_chart_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';
import 'dart:math' as math;
import 'package:vector_math/vector_math_64.dart';

const bool USE_CUSTOM_FFT = true; // Switch between implementations

/// Función de nivel superior para usar con `compute`.
List<DataPoint> performFFT(List<DataPoint> points) {
  return _computeFFT(points);
}

/// Calcula la FFT utilizando la implementación personalizada o Scidart.
List<DataPoint> _computeFFT(List<DataPoint> points) {
  if (USE_CUSTOM_FFT) {
    return _computeCustomFFT(points);
  } else {
    return _computeScidartFFT(points);
  }
}

// Modify _computeScidartFFT and _computeCustomFFT to handle both formats
List<DataPoint> _computeScidartFFT(List<DataPoint> points) {
  final yValues = points.map((point) => point.y).toList();
  final array = Array(yValues);
  final fftResult = rfft(array);
  final magnitudes = arrayComplexAbs(fftResult);
  final halfLength = (magnitudes.length / 2).ceil();
  final positiveMagnitudes = magnitudes.getRange(0, halfLength).toList();

  const samplingRate = 1600000.0;
  final frequencyResolution = samplingRate / points.length;
  final frequencies =
      List<double>.generate(halfLength, (i) => i * frequencyResolution);

  if (!FFTChartService.outputInDb) {
    return List<DataPoint>.generate(
        halfLength, (i) => DataPoint(frequencies[i], positiveMagnitudes[i]));
  }

  // Convert to dB
  const bitsPerSample = 9.0;
  final normFactor =
      20 * math.log(points.length * math.pow(2, bitsPerSample) / 2) / math.ln10;

  return List<DataPoint>.generate(halfLength, (i) {
    final magnitude = positiveMagnitudes[i];
    final db = magnitude == 0
        ? -160.0
        : 20 * math.log(magnitude) / math.ln10 - normFactor;
    return DataPoint(frequencies[i], db);
  });
}

List<DataPoint> _computeCustomFFT(List<DataPoint> points) {
  final n = points.length;
  final real = Float32List(n);
  final imag = Float32List(n);

  // Cargar datos sin ventana
  for (var i = 0; i < n; i++) {
    real[i] = points[i].y;
    imag[i] = 0.0;
  }

  _fft(real, imag);

  // Normalizar
  for (var i = 0; i < n; i++) {
    real[i] /= n;
    imag[i] /= n;
  }

  final halfLength = (n / 2).ceil();
  const samplingRate = 1600000.0;
  final freqResolution = samplingRate / n;

  return List<DataPoint>.generate(halfLength, (i) {
    final re = real[i];
    final im = imag[i];
    final magnitude = math.sqrt(re * re + im * im);

    // Convertir a dB tal como en el script
    const bitsPerSample = 9.0;
    final fullScale = math.pow(2, bitsPerSample - 1).toDouble();
    final normFactor = 20 * math.log(fullScale) / math.ln10;
    final db = magnitude == 0
        ? -160.0
        : 20 * math.log(magnitude) / math.ln10 + normFactor;

    return DataPoint(i * freqResolution, db);
  });
}

/// Implementación de FFT con operaciones SIMD.
void _fft(Float32List real, Float32List imag) {
  final n = real.length;

  // Permutación de reversión de bits (secuencial)
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

  // FFT con operaciones SIMD
  for (var step = 1; step < n; step <<= 1) {
    final angle = -math.pi / step;

    for (var group = 0; group < n; group += (step << 1)) {
      for (var pair = 0; pair < step; pair += 4) {
        final remainingPairs = math.min(4, step - pair);

        // Cargar 4 pares de valores en vectores
        final even = Vector4.zero();
        final evenImag = Vector4.zero();
        final odd = Vector4.zero();
        final oddImag = Vector4.zero();

        // Cargar factores de twiddle para 4 elementos
        final angles = Vector4(angle * pair, angle * (pair + 1),
            angle * (pair + 2), angle * (pair + 3));

        final cosAngles = Vector4(math.cos(angles.x), math.cos(angles.y),
            math.cos(angles.z), math.cos(angles.w));

        final sinAngles = Vector4(math.sin(angles.x), math.sin(angles.y),
            math.sin(angles.z), math.sin(angles.w));

        // Cargar datos usando operaciones vectoriales
        for (var i = 0; i < remainingPairs; i++) {
          final evenIdx = group + pair + i;
          final oddIdx = evenIdx + step;

          even[i] = real[evenIdx];
          evenImag[i] = imag[evenIdx];
          odd[i] = real[oddIdx];
          oddImag[i] = imag[oddIdx];
        }

        // Multiplicación compleja usando SIMD
        final oddRotatedReal = odd.clone()..multiply(cosAngles);
        oddRotatedReal.sub(oddImag.clone()..multiply(sinAngles));

        final oddRotatedImag = odd.clone()..multiply(sinAngles);
        oddRotatedImag.add(oddImag.clone()..multiply(cosAngles));

        // Operación butterfly usando SIMD
        final sumReal = even.clone()..add(oddRotatedReal);
        final sumImag = evenImag.clone()..add(oddRotatedImag);
        final diffReal = even.clone()..sub(oddRotatedReal);
        final diffImag = evenImag.clone()..sub(oddRotatedImag);

        // Guardar resultados
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

class FFTChartService {
  final GraphProvider graphProvider;
  final _fftController = StreamController<List<DataPoint>>.broadcast();
  static const int blockSize = 8192 * 2;

  StreamSubscription? _dataPointsSubscription;
  bool _isProcessing = false;
  bool _isPaused = false;
  static bool _outputInDb = true; // Make static mutable

  final List<DataPoint> _dataBuffer = [];

  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  static void setOutputFormat(bool inDb) {
    _outputInDb = inDb;
  }

  static bool get outputInDb => _outputInDb;

  FFTChartService(this.graphProvider) {
    print("Starting FFT Service");
    _dataPointsSubscription = graphProvider.dataPointsStream.listen((points) {
      if (_isProcessing || _isPaused) {
        return;
      }

      _dataBuffer.addAll(points);

      if (_dataBuffer.length >= blockSize) {
        _isProcessing = true;
        final dataToProcess = _dataBuffer.sublist(0, blockSize);
        _dataBuffer.clear();

        compute(performFFT, dataToProcess).then((fftPoints) {
          if (!_isPaused) {
            _fftController.add(fftPoints);
          }
          _isProcessing = false;
        }).catchError((error) {
          print('Error processing FFT: $error');
          _isProcessing = false;
        });
      }
    });
  }

  void pause() {
    _isPaused = true;
    _dataBuffer.clear(); // Clear buffer when paused
  }

  void resume() {
    _isPaused = false;
  }

  Future<void> dispose() async {
    _dataPointsSubscription?.cancel();
    _fftController.close();
    _dataBuffer.clear();
  }
}
