// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/repository/line_chart_repository.dart';

import '../models/data_point.dart';
import '../../providers/data_provider.dart';

class LineChartService implements LineChartRepository {
  final GraphProvider graphProvider;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;
  bool _isPaused = false;

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  @override
  bool get isPaused => _isPaused;

  LineChartService(this.graphProvider) {
    _dataSubscription = graphProvider.dataPointsStream.listen((points) {
      if (!_isPaused) {
        _dataController.add(points);
      }
    });
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _dataController.close();
  }
}