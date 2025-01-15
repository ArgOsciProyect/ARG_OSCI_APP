// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';

class LineChartService {
  final GraphProvider graphProvider;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;
  bool _isPaused = false;

  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  LineChartService(this.graphProvider) {
    _dataSubscription = graphProvider.dataPointsStream.listen((points) {
      if (!_isPaused) {
        _dataController.add(points);
      }
    });
  }

  void pause() {
    _isPaused = true;
  }

  void resume() {
    _isPaused = false;
  }

  void dispose() {
    _dataSubscription?.cancel();
    _dataController.close();
  }
}
