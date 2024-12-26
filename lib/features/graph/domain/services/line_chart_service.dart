// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import '../models/data_point.dart';
import '../../providers/graph_provider.dart';

class LineChartService {
  final GraphProvider graphProvider;
  final _dataController = StreamController<List<DataPoint>>.broadcast();

  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  LineChartService(this.graphProvider) {
    graphProvider.dataPointsStream.listen((points) {
      final filteredPoints = _applyMovingAverageFilter(points, 5); // Example window size of 5
      _dataController.add(filteredPoints);
    });
  }

  List<DataPoint> _applyMovingAverageFilter(List<DataPoint> points, int windowSize) {
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

  void dispose() {
    _dataController.close();
  }
}