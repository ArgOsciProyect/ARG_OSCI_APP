// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/repository/line_chart_repository.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';

import '../models/data_point.dart';
import '../../providers/data_acquisition_provider.dart';

class LineChartService implements LineChartRepository {
  DataAcquisitionProvider? _graphProvider;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;
  bool _isPaused = false;

  @override
  double get distance => 1 / deviceConfig.samplingFrequency;

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  @override
  bool get isPaused => _isPaused;

  LineChartService(DataAcquisitionProvider? provider) {
    _graphProvider = provider;
    if (provider != null) {
      _setupSubscriptions();
    }
  }

  void _setupSubscriptions() {
    // Cancel existing subscription if any
    _dataSubscription?.cancel();

    if (_graphProvider != null) {
      _dataSubscription = _graphProvider!.dataPointsStream.listen((points) {
        if (!_isPaused) {
          _dataController.add(points);
        }
      });
    }
  }

  void resumeAndWaitForTrigger() {
    _isPaused = false;
    _dataController.add([]); // Clear current data
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  void updateProvider(DataAcquisitionProvider provider) {
    _graphProvider = provider;
    _setupSubscriptions();
  }

  @override
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _dataController.close();
  }
}
