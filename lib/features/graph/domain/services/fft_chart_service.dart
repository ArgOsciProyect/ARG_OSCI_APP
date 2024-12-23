// lib/features/graph/services/fft_chart_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/data_point.dart';
import '../../providers/graph_provider.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';

class FFTChartService {
  final GraphProvider graphProvider;
  final _fftController = StreamController<List<DataPoint>>.broadcast();
  static const int blockSize = 8192 * 2;

  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  FFTChartService(this.graphProvider) {
    graphProvider.dataPoints.listen((points) async {
      for (int i = 0; i < points.length; i += blockSize) {
        final block = points.sublist(i, i + blockSize > points.length ? points.length : i + blockSize);
        final fftPoints = await compute(_computeFFT, block);
        _fftController.add(fftPoints);
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

    final samplingRate = 1 / points.first.x;
    final frequencies = List<double>.generate(halfLength, (i) => i * samplingRate / array.length);

    return List<DataPoint>.generate(
      positiveMagnitudes.length,
      (i) => DataPoint(frequencies[i], positiveMagnitudes[i]),
    );
  }

  void dispose() {
    _fftController.close();
  }
}