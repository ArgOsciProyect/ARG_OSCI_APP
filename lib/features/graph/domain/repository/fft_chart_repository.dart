// lib/features/graph/domain/repository/fft_chart_repository.dart
import 'dart:async';
import '../models/data_point.dart';

abstract class FFTChartRepository {
  /// Block size for FFT processing
  static const int blockSize = 8192 * 2;

  /// Stream of processed FFT data points
  Stream<List<DataPoint>> get fftStream;

  /// Initializes the isolate for FFT processing
  /// Returns a Future that completes when isolate is ready
  Future<void> initializeIsolate();

  /// Computes FFT for given data points
  ///
  /// [points] List of data points to process
  /// Returns FFT processed data points
  List<DataPoint> computeFFT(List<DataPoint> points);

  /// Helper function for logarithmic calculations
  ///
  /// [x] Value to calculate log10
  double log10(double x);

  /// Cleans up resources including:
  /// - Isolate
  /// - Stream subscriptions
  /// - Data buffer
  /// - Controllers
  void dispose();
}
