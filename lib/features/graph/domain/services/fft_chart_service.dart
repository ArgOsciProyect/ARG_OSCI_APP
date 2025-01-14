// lib/features/graph/services/fft_chart_service.dart
import 'dart:async';
import 'dart:ffi';
import 'dart:isolate';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';

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
          print("Starting FFT processing with ${_dataBuffer.length} points");

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
        print("FFT processing complete");
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
    final yValues = points.map((point) => point.y).toList();
    final array = Array(yValues);

    final fftResult = rfft(array);
    final magnitudes = arrayComplexAbs(fftResult);
    final halfLength = (magnitudes.length / 2).ceil();
    final positiveMagnitudes = magnitudes.getRange(0, halfLength).toList();

    // Calculate frequencies
    const samplingRate = 1600000.0; // 1.6 MHz
    final frequencyResolution = samplingRate / points.length;
    final frequencies =
        List<double>.generate(halfLength, (i) => i * frequencyResolution);

    // Convert to dB and normalize
    const bitsPerSample = 9.0; // ADC bit depth
    final fftLength = points.length;
    final normalizationFactor =
        20 * log10(fftLength * pow(2, bitsPerSample) / 2);

    final normalizedMagnitudes = positiveMagnitudes.map((magnitude) {
      if (magnitude == 0) return -160.0; // Floor for log10(0)
      final db = 20 * log10(magnitude);
      return db - normalizationFactor;
    }).toList();

    final fftPoints = List<DataPoint>.generate(
      normalizedMagnitudes.length,
      (i) => DataPoint(frequencies[i], normalizedMagnitudes[i]),
    );

    // Debug print
    print(
        "First 5 FFT Points (Hz, dB): ${fftPoints.take(5).map((p) => '(${p.x.toStringAsFixed(2)}, ${p.y.toStringAsFixed(2)})').join(', ')}");

    return fftPoints;
  }

// Helper function for log10
  static double log10(double x) => log(x) / ln10;
  Future <void> dispose() async {
    _dataPointsSubscription?.cancel();
    _receivePortSubscription?.cancel();
    if (_isolateReady.isCompleted && _isolate != null) {
      _isolate.kill();
      _receivePort.close();
    }
    _fftController.close();
    _dataBuffer.clear();
  }
}
