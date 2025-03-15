import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/repository/oscilloscope_chart_repository.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';

/// [OscilloscopeChartService] implements the [OscilloscopeChartRepository] to manage the data stream for the oscilloscope chart.
class OscilloscopeChartService implements OscilloscopeChartRepository {
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

  OscilloscopeChartService(DataAcquisitionProvider? provider) {
    _graphProvider = provider;
    if (provider != null) {
      _setupSubscriptions();
    }
  }

  /// Sets up the data stream subscription to receive data points from the [DataAcquisitionProvider].
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

  /// Calculates optimal chart scaling values based on signal parameters
  @override
  Map<String, double> calculateAutosetScales(
      double chartWidth, double frequency, double maxValue, double minValue,
      {double marginFactor = 1.15}) {
    // Add margin to min and max values
    final adjustedMaxValue =
        maxValue > 0 ? maxValue * marginFactor : maxValue / marginFactor;
    final adjustedMinValue =
        minValue < 0 ? minValue * marginFactor : minValue / marginFactor;

    // Calculate the total range with margins
    final totalRange = adjustedMaxValue - adjustedMinValue;
    final verticalCenter = (adjustedMaxValue + adjustedMinValue) / 2;

    double timeScale;
    double valueScale;

    if (frequency <= 0) {
      // No frequency detected, use default time scale
      timeScale = 100000;

      // Calculate value scale based on adjusted range
      if (totalRange > 0) {
        valueScale = 1.0 / totalRange;
      } else {
        // Fallback for zero or very small range
        valueScale = 1.0;
      }
    } else {
      // Calculate time scale to show 3 periods
      final period = 1 / frequency;
      final totalTime = 3 * period;
      timeScale = chartWidth / totalTime;

      // Calculate value scale based on adjusted range
      if (totalRange > 0) {
        valueScale = 1.0 / totalRange;
      } else {
        // Fallback using max absolute value
        final maxAbsValue =
            maxValue.abs() > minValue.abs() ? maxValue.abs() : minValue.abs();
        final expandedAbsValue = maxAbsValue * marginFactor;
        valueScale = expandedAbsValue > 0 ? 1.0 / (expandedAbsValue * 2) : 1.0;
      }
    }

    return {
      'timeScale': timeScale,
      'valueScale': valueScale,
      'verticalCenter': verticalCenter
    };
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

  @override
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
