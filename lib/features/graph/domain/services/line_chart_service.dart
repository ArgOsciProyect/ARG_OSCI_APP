// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
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
    _dataSubscription?.cancel();

    if (_graphProvider != null) {
      _dataSubscription = _graphProvider!.dataPointsStream.listen((points) {
        // Verificar primero si hay trigger en modo single
        if (_graphProvider?.triggerMode.value == TriggerMode.single &&
            points.any((p) => p.isTrigger)) {
          _dataController.add(points); // Emitir los puntos con el trigger
          pause(); // Pausar después de emitir
          return; // Salir para evitar más emisiones
        }

        // Para modo normal o sin trigger
        if (!_isPaused) {
          _dataController.add(points);
        }
      });
    }
  }

  @override
  void resumeAndWaitForTrigger() {
    _isPaused = false;
    // No limpiamos los datos aquí - dejemos que el provider lo haga
    _setupSubscriptions();
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
