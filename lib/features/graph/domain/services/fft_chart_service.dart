// lib/features/graph/services/fft_chart_service.dart
import 'dart:async';
import 'dart:isolate';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';
import 'dart:math' as math;
import 'dart:typed_data';
import 'package:vector_math/vector_math_64.dart';

const bool USE_CUSTOM_FFT = true; // Switch between implementations

class FFTChartService {
  final GraphProvider graphProvider;
  final _fftController = StreamController<List<DataPoint>>.broadcast();
  static const int blockSize = 8192 * 2;

  late Isolate _isolate;
  late ReceivePort _receivePort;
  late SendPort _sendPort;
  StreamSubscription? _receivePortSubscription;
  StreamSubscription? _dataPointsSubscription;
  final _isolateReady = Completer<void>();
  bool _isProcessing = false;

  final List<DataPoint> _dataBuffer = [];

  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  FFTChartService(this.graphProvider) {
    print("Starting FFT Service");
    _initializeIsolate().then((_) {
      _dataPointsSubscription = graphProvider.dataPointsStream.listen((points) {
        if (!_isolateReady.isCompleted) return;
        if (_isProcessing) {
          //print("FFT processing in progress, discarding ${points.length} points");
          return; // Skip new data while processing
        }

        _dataBuffer.addAll(points);

        if (_dataBuffer.length >= blockSize) {
          _isProcessing = true;
          //print("Starting FFT processing with ${_dataBuffer.length} points");

          final dataToProcess = _dataBuffer.sublist(0, blockSize);
          _dataBuffer.clear(); // Clear buffer immediately

          _sendPort.send(dataToProcess);
        }
      });
    });
  }
  Future<void> _initializeIsolate() async {
    print("Initializing Isolate");
    if (_isolateReady.isCompleted) return;

    _receivePort = ReceivePort();
    final broadcastStream = _receivePort.asBroadcastStream();
    _isolate = await Isolate.spawn(_isolateFunction, _receivePort.sendPort);

    _sendPort = await broadcastStream.first;

    _receivePortSubscription?.cancel();
    _receivePortSubscription = broadcastStream.listen((message) {
      if (message is List<DataPoint>) {
        _fftController.add(message);
        _isProcessing = false; // Reset processing flag
        //print("FFT processing complete");
      }
    });

    _isolateReady.complete();
  }

  static void _isolateFunction(SendPort mainSendPort) {
    final receivePort = ReceivePort();
    mainSendPort.send(receivePort.sendPort);

    receivePort.listen((message) {
      if (message is List<DataPoint>) {
        final fftPoints = _computeFFT(message);
        mainSendPort.send(fftPoints);
      }
    });
  }

    static List<DataPoint> _computeFFT(List<DataPoint> points) {
    if (USE_CUSTOM_FFT) {
      return _computeCustomFFT(points);
    } else {
      return _computeScidartFFT(points);
    }
  }

  // Original scidart implementation
  static List<DataPoint> _computeScidartFFT(List<DataPoint> points) {
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
    
    // Convert to dB
    const bitsPerSample = 9.0;
    final normFactor = 
        20 * math.log(points.length * math.pow(2, bitsPerSample) / 2) / math.ln10;
    
    return List.generate(halfLength, (i) {
      final magnitude = positiveMagnitudes[i];
      final db = magnitude == 0 ? -160.0 : 
                 20 * math.log(magnitude) / math.ln10 - normFactor;
      return DataPoint(frequencies[i], db);
    });
  }

  static void _fft(Float32List real, Float32List imag) {
    final n = real.length;
    
    // Bit reversal
    var j = 0;
    for (var i = 0; i < n - 1; i++) {
      if (i < j) {
        // Simple swap without Vector2
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
  
    // Compute FFT using butterflies
    for (var step = 1; step < n; step <<= 1) {
      final angle = -math.pi / step;
      final wReal = math.cos(angle);
      final wImag = math.sin(angle);
  
      for (var group = 0; group < n; group += (step << 1)) {
        var currentReal = 1.0;
        var currentImag = 0.0;
  
        for (var pair = 0; pair < step; pair++) {
          final evenIndex = group + pair;
          final oddIndex = evenIndex + step;
  
          final oddReal = real[oddIndex] * currentReal - imag[oddIndex] * currentImag;
          final oddImag = real[oddIndex] * currentImag + imag[oddIndex] * currentReal;
  
          real[oddIndex] = real[evenIndex] - oddReal;
          imag[oddIndex] = imag[evenIndex] - oddImag;
          real[evenIndex] = real[evenIndex] + oddReal;
          imag[evenIndex] = imag[evenIndex] + oddImag;
  
          // Rotate for next pair
          final nextReal = currentReal * wReal - currentImag * wImag;
          currentImag = currentReal * wImag + currentImag * wReal;
          currentReal = nextReal;
        }
      }
    }
  }
  
  static List<DataPoint> _computeCustomFFT(List<DataPoint> points) {
    final n = points.length;
    final real = Float32List(n);
    final imag = Float32List(n);
    
    // Copy input and apply window function
    for (var i = 0; i < n; i++) {
      // Hann window
      final window = 0.5 * (1 - math.cos(2 * math.pi * i / (n - 1)));
      real[i] = points[i].y * window;
      imag[i] = 0.0;
    }
    
    _fft(real, imag);
    
    final halfLength = (n / 2).ceil();
    const samplingRate = 1600000.0;
    final freqResolution = samplingRate / n;
    
    // Scale factor for magnitude calculation
    final scale = 2.0 / n;
    
    return List<DataPoint>.generate(halfLength, (i) {
      // Calculate magnitude properly
      final re = real[i] * scale;
      final im = imag[i] * scale;
      final magnitude = math.sqrt(re * re + im * im);
      
      // Convert to dB with proper normalization
      const bitsPerSample = 9.0;
      final fullScale = math.pow(2, bitsPerSample - 1);
      final normFactor = 20 * math.log(fullScale) / math.ln10;
      
      var db = magnitude > 0 
          ? 20 * math.log(magnitude) / math.ln10 + normFactor
          : -160.0;
      
      return DataPoint(i * freqResolution, db);
    });
  }

// Helper function for log10
  static double log10(double x) => log(x) / ln10;
  Future <void> dispose() async {
    _dataPointsSubscription?.cancel();
    _receivePortSubscription?.cancel();
    if (_isolateReady.isCompleted) {
      _isolate.kill();
      _receivePort.close();
    }
    _fftController.close();
    _dataBuffer.clear();
  }
}
