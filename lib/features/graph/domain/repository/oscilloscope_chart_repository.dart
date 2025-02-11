import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

/// Repository interface for real-time line chart display functionality
abstract class OscilloscopeChartRepository {
  /// Stream of processed data points for chart display
  /// Returns continuous time-domain signal measurements
  Stream<List<DataPoint>> get dataStream;

  /// Whether chart updating is currently paused
  bool get isPaused;

  /// Time interval between samples in seconds
  /// Calculated as 1/sampling_frequency
  double get distance;

  /// Updates data source provider
  /// [provider] New data acquisition provider to use
  void updateProvider(DataAcquisitionProvider provider);

  /// Pauses chart updates while maintaining current display
  void pause();

  /// Resumes normal chart updating
  void resume();

  /// Clears display and resumes waiting for next trigger event
  /// Used in single trigger mode to prepare for next capture
  void resumeAndWaitForTrigger();

  /// Releases all resources used by chart
  /// Should be called when chart is no longer needed
  Future<void> dispose();
}