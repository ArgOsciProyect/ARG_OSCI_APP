import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

/// Repository interface for FFT (Fast Fourier Transform) chart functionality
abstract class FFTChartRepository {
  /// Stream of processed FFT data points
  /// Returns frequency domain representation of time-domain signals
  Stream<List<DataPoint>> get fftStream;

  /// Current frequency calculated from FFT data
  /// Returns dominant frequency in Hz, or 0 if no significant peak found
  double get frequency;

  /// Block size for FFT processing
  /// Number of samples used in each FFT computation
  int get blockSize;

  /// Current maximum signal value
  /// Used for decibel calculations and scaling
  double get currentMaxValue;

  /// Whether FFT processing is currently paused
  bool get isPaused;

  /// Updates data provider used as signal source
  /// [provider] New data provider to use
  void updateProvider(DataAcquisitionProvider provider);

  /// Computes FFT for given data points
  /// [points] Time domain data points to transform
  /// [maxValue] Maximum signal value for normalization
  /// Returns frequency domain representation
  List<DataPoint> computeFFT(List<DataPoint> points, double maxValue);

  /// Pauses FFT processing and clears buffers
  void pause();

  /// Resumes FFT processing
  void resume();

  /// Releases resources used by FFT processor
  Future<void> dispose();
}