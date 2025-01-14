// lib/features/graph/providers/graph_provider.dart
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:get/get.dart';
import 'package:simple_kalman/simple_kalman.dart'; // Importar la librería
import 'dart:async';
import '../domain/models/data_point.dart';
import '../domain/services/data_acquisition_service.dart';
import '../domain/models/trigger_data.dart';
import 'line_chart_provider.dart';
import '../domain/models/filter_types.dart';

class GraphProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  final SocketConnection socketConnection;

  // Reactive variables
  final _dataPointsController = StreamController<List<DataPoint>>.broadcast();
  final dataPoints = Rx<List<DataPoint>>([]);
  final frequency = Rx<double>(1.0);
  final maxValue = Rx<double>(1.0);
  final triggerLevel = Rx<double>(0.0);
  final triggerEdge = Rx<TriggerEdge>(TriggerEdge.positive);
  final timeScale = Rx<double>(1.0);
  final valueScale = Rx<double>(1.0);
  final maxX = Rx<double>(1.0);
  final distance = RxDouble(1 / 1600000);
  final scale = RxDouble(3.3 / 512);
  final currentFilter = Rx<FilterType>(NoFilter());
  final windowSize = RxInt(5);
  final alpha = RxDouble(0.2);
  final cutoffFrequency = RxDouble(100.0);

  // Kalman filter instance
  final SimpleKalman kalman =
      SimpleKalman(errorMeasure: 256, errorEstimate: 150, q: 0.9);

  GraphProvider(this.dataAcquisitionService, this.socketConnection) {
    // Subscribe to streams

    dataAcquisitionService.dataStream.listen((points) {
      final filteredPoints = _applyFilter(points);
      dataPoints.value = filteredPoints;
      _dataPointsController.add(filteredPoints);
    });

    dataAcquisitionService.frequencyStream.listen((freq) {
      final filteredFreq = kalman.filtered(freq); // Aplicar el filtro Kalman
      frequency.value = filteredFreq;
    });

    dataAcquisitionService.maxValueStream.listen((max) {
      maxValue.value = max;
    });

    // Observe changes in socket connection
    ever(socketConnection.ip, (_) => _restartDataAcquisition());
    ever(socketConnection.port, (_) => _restartDataAcquisition());

    // Sync initial values
    triggerLevel.value = dataAcquisitionService.triggerLevel;
    triggerEdge.value = dataAcquisitionService.triggerEdge;
    distance.value = dataAcquisitionService.distance;
    scale.value = dataAcquisitionService.scale;
  }

  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;
  double getDistance() => distance.value;
  double getScale() => scale.value;
  double getFrequency() => frequency.value;
  double getMaxValue() => maxValue.value;

  void addPoints(List<DataPoint> points) {
    dataPoints.value = points;
    _dataPointsController.add(points);
  }

  Future<void> _restartDataAcquisition() async {
    await stopData();
    await fetchData();
  }

  Future<void> fetchData() async {
    await dataAcquisitionService.fetchData(
        socketConnection.ip.value, socketConnection.port.value);
  }

  Future<void> stopData() async {
    // Asegurar que los sockets se cierran correctamente
    try {
      await dataAcquisitionService.stopData();
      await Future.delayed(
          const Duration(milliseconds: 100)); // Dar tiempo para cerrar
    } catch (e) {
      print('Error stopping data: $e');
    }
  }

  List<double> autoset(double chartHeight, double chartWidth) {
    final result = dataAcquisitionService.autoset(chartHeight, chartWidth);

    // Notificar al LineChartProvider sobre el cambio de escalas
    final lineChartProvider = Get.find<LineChartProvider>();
    lineChartProvider.setTimeScale(result[0]);
    lineChartProvider.setValueScale(result[1]);

    // Actualizar trigger
    triggerLevel.value = dataAcquisitionService.triggerLevel;
    dataAcquisitionService.updateConfig();

    return result;
  }

  List<DataPoint> _applyFilter(List<DataPoint> points) {
    final params = {
      'windowSize': windowSize.value,
      'alpha': alpha.value,
      'cutoffFrequency': cutoffFrequency.value,
    };
    return currentFilter.value.apply(points, params);
  }

  void setFilter(FilterType filter) {
    currentFilter.value = filter;
  }

  void setWindowSize(int size) {
    windowSize.value = size;
  }

  void setAlpha(double value) {
    alpha.value = value;
  }

  void setCutoffFrequency(double freq) {
    cutoffFrequency.value = freq;
  }

  void setTriggerLevel(double level) {
    triggerLevel.value = level;
    dataAcquisitionService.triggerLevel = level;
    print("Trigger level: $level");
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  void setTriggerEdge(TriggerEdge edge) {
    triggerEdge.value = edge;
    dataAcquisitionService.triggerEdge = edge;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  void setTimeScale(double scale) {
    timeScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  void setValueScale(double scale) {
    valueScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  @override
  void onClose() {
    stopData(); // Stop data acquisition when the controller is closed
    _dataPointsController.close();
    super.onClose();
  }
}
