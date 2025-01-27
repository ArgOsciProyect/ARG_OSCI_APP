// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/repository/line_chart_repository.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';

import '../models/data_point.dart';
import '../../providers/data_provider.dart';

class LineChartService implements LineChartRepository {
  final GraphProvider graphProvider;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;
  bool _isPaused = false;
  
  // Add distance getter
  @override
  double get distance => 1 / deviceConfig.samplingFrequency;

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  @override
  bool get isPaused => _isPaused;

  LineChartService(this.graphProvider) {
    _dataSubscription = graphProvider.dataPointsStream.listen((points) {
      if (!_isPaused) {
        // Transform points using device config if needed
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