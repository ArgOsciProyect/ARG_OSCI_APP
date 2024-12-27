// lib/features/graph/domain/models/filter_types.dart
import 'data_point.dart';

abstract class FilterType {
  String get name;
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterType && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

class NoFilter extends FilterType {
  static final NoFilter _instance = NoFilter._internal();
  factory NoFilter() => _instance;
  NoFilter._internal();

  @override
  String get name => 'None';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    return points;
  }
}

class MovingAverageFilter extends FilterType {
  static final MovingAverageFilter _instance = MovingAverageFilter._internal();
  factory MovingAverageFilter() => _instance;
  MovingAverageFilter._internal();

  @override
  String get name => 'Moving Average';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final windowSize = params['windowSize'] as int;
    final filteredPoints = <DataPoint>[];

    for (int i = 0; i < points.length; i++) {
      double sum = 0;
      int count = 0;

      for (int j = i; j >= 0 && j > i - windowSize; j--) {
        sum += points[j].y;
        count++;
      }

      final average = sum / count;
      filteredPoints.add(DataPoint(points[i].x, average));
    }

    return filteredPoints;
  }
}

class ExponentialFilter extends FilterType {
  static final ExponentialFilter _instance = ExponentialFilter._internal();
  factory ExponentialFilter() => _instance;
  ExponentialFilter._internal();

  @override
  String get name => 'Exponential';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final alpha = params['alpha'] as double;
    final filteredPoints = <DataPoint>[];
    if (points.isEmpty) return filteredPoints;

    filteredPoints.add(points.first);
    for (int i = 1; i < points.length; i++) {
      final currentY = points[i].y;
      final lastFilteredY = filteredPoints.last.y;
      final newY = alpha * currentY + (1 - alpha) * lastFilteredY;
      filteredPoints.add(DataPoint(points[i].x, newY));
    }
    return filteredPoints;
  }
}

class LowPassFilter extends FilterType {
  static final LowPassFilter _instance = LowPassFilter._internal();
  factory LowPassFilter() => _instance;
  LowPassFilter._internal();

  @override
  String get name => 'Low Pass';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final cutoffFreq = params['cutoffFrequency'] as double;
    final filteredPoints = <DataPoint>[];
    if (points.isEmpty) return filteredPoints;

    final dt = points[1].x - points[0].x;
    final rc = 1 / (2 * 3.14159 * cutoffFreq);
    final alpha = dt / (rc + dt);

    filteredPoints.add(points.first);
    for (int i = 1; i < points.length; i++) {
      final currentY = points[i].y;
      final lastFilteredY = filteredPoints.last.y;
      final newY = lastFilteredY + alpha * (currentY - lastFilteredY);
      filteredPoints.add(DataPoint(points[i].x, newY));
    }
    return filteredPoints;
  }
}