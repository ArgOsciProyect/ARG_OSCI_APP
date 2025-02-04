// lib/features/graph/domain/repository/line_chart_repository.dart
import 'dart:async';
import '../models/data_point.dart';

// In LineChartRepository, add missing methods:
abstract class LineChartRepository {
  /// Stream of filtered data points
  Stream<List<DataPoint>> get dataStream;

  /// Gets the pause state of the chart
  bool get isPaused;

  /// Gets the time between samples (1/sampling frequency)
  double get distance;

  /// Pauses the data stream
  void pause();

  /// Resumes the data stream
  void resume();

  /// Clears current data and waits for new trigger
  void resumeAndWaitForTrigger();

  /// Disposes of resources
  Future<void> dispose();
}
