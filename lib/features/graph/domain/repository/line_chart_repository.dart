// lib/features/graph/domain/repository/line_chart_repository.dart
import 'dart:async';
import '../models/data_point.dart';

abstract class LineChartRepository {
  /// Stream of filtered data points
  Stream<List<DataPoint>> get dataStream;

  /// Gets the pause state of the chart
  bool get isPaused;

  /// Pauses the data stream
  void pause();

  /// Resumes the data stream
  void resume();

  /// Disposes of resources
  Future<void> dispose();
}