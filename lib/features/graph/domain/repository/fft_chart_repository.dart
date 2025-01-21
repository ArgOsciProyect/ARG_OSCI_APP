// lib/features/graph/domain/repository/fft_chart_repository.dart
import 'dart:async';
import '../models/data_point.dart';

abstract class FFTChartRepository {
  /// Block size for FFT processing
  static const int blockSize = 8192 * 2;

  /// Stream of processed FFT data points
  Stream<List<DataPoint>> get fftStream;

  /// Gets the current output format (dB or linear)
  bool get outputInDb;

  /// Sets the output format
  /// [inDb] true for decibel output, false for linear
  void setOutputFormat(bool inDb);

  /// Pauses FFT processing
  void pause();

  /// Resumes FFT processing
  void resume();

  /// Computes FFT for given data points and max value
  ///
  /// [points] List of data points to process
  /// [maxValue] Maximum value for dB calculation
  /// Returns FFT processed data points
  List<DataPoint> computeFFT(List<DataPoint> points, double maxValue);

  /// Disposes resources
  Future<void> dispose();
}