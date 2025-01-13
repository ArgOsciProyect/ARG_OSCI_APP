// lib/features/graph/domain/repository/line_chart_repository.dart
import 'dart:async';
import '../models/data_point.dart';

/// Interface for Line chart repository
abstract class LineChartRepository {
  /// Stream of filtered data points
  Stream<List<DataPoint>> get dataStream;

  /// Applies a moving average filter to the data points
  ///
  /// [points] List of data points to filter
  /// [windowSize] Size of the moving average window
  /// Returns filtered list of data points
  List<DataPoint> applyMovingAverageFilter(
      List<DataPoint> points, int windowSize);

  /// Disposes of resources
  void dispose();
}