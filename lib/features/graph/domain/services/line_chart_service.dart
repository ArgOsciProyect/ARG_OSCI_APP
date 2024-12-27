// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';

enum FilterType { none, movingAverage, exponential, lowPass }

class LineChartService {
  final GraphProvider graphProvider;
  final _dataController = StreamController<List<DataPoint>>.broadcast();

  FilterType _currentFilter = FilterType.none;
  int _windowSize = 5;
  double _alpha = 0.2; // For exponential filter
  double _cutoffFrequency = 100.0; // For low pass filter

  FilterType get currentFilter => _currentFilter;
  int get windowSize => _windowSize;
  double get alpha => _alpha;
  double get cutoffFrequency => _cutoffFrequency;

  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  LineChartService(this.graphProvider) {
    graphProvider.dataAcquisitionService.dataStream.listen((points) {
      final filteredPoints = applyFilter(points);
      _dataController.add(filteredPoints);
    });
  }

  void setFilter(FilterType filter) {
    _currentFilter = filter;
  }

  void setWindowSize(int size) {
    _windowSize = size;
  }

  void setAlpha(double value) {
    _alpha = value;
  }

  void setCutoffFrequency(double freq) {
    _cutoffFrequency = freq;
  }


  List<DataPoint> applyFilter(List<DataPoint> points) {
    switch (_currentFilter) {
      case FilterType.none:
        return points;
      case FilterType.movingAverage:
        return _applyMovingAverageFilter(points, _windowSize);
      case FilterType.exponential:
        return _applyExponentialFilter(points, _alpha);
      case FilterType.lowPass:
        return _applyLowPassFilter(points, _cutoffFrequency);
    }
  }

  List<DataPoint> _applyMovingAverageFilter(
      List<DataPoint> points, int windowSize) {
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

  List<DataPoint> _applyExponentialFilter(
      List<DataPoint> points, double alpha) {
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

  List<DataPoint> _applyLowPassFilter(
      List<DataPoint> points, double cutoffFreq) {
    final filteredPoints = <DataPoint>[];
    if (points.isEmpty) return filteredPoints;

    final dt = points[1].x - points[0].x; // Time step
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

  void dispose() {
    _dataController.close();
  }
}