// lib/features/graph/providers/graph_provider.dart
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:get/get.dart';
import '../domain/models/data_point.dart';
import '../domain/services/data_acquisition_service.dart';
import '../domain/models/trigger_data.dart';

class GraphProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  final SocketConnection socketConnection;
  
  // Reactive variables
  final dataPoints = Rx<List<DataPoint>>([]);
  final frequency = Rx<double>(1.0);
  final maxValue = Rx<double>(1.0);
  final triggerLevel = Rx<double>(0.0);
  final triggerMode = Rx<TriggerMode>(TriggerMode.automatic);
  final triggerEdge = Rx<TriggerEdge>(TriggerEdge.positive);
  final timeScale = Rx<double>(1.0);
  final valueScale = Rx<double>(1.0);
  final maxX = Rx<double>(1.0);

  GraphProvider(this.dataAcquisitionService, this.socketConnection) {
    // Subscribe to streams
    dataAcquisitionService.dataStream.listen((points) {
      dataPoints.value = points;
    });

    dataAcquisitionService.frequencyStream.listen((freq) {
      frequency.value = freq;
    });

    dataAcquisitionService.maxValueStream.listen((max) {
      maxValue.value = max;
    });

    // Observe changes in socket connection
    ever(socketConnection.ip, (_) => _restartDataAcquisition());
    ever(socketConnection.port, (_) => _restartDataAcquisition());
  }

  Future<void> _restartDataAcquisition() async {
    await stopData();
    await fetchData();
  }

  Future<void> fetchData() async {
    await dataAcquisitionService.fetchData(
      socketConnection.ip.value,
      socketConnection.port.value
    );
  }

  Future<void> stopData() async {
    await dataAcquisitionService.stopData();
  }

  List<double> autoset(double chartHeight, double chartWidth) {
    print("Autosetting");
    triggerMode.value = TriggerMode.automatic;
    final result = dataAcquisitionService.autoset(chartHeight, chartWidth);
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
    return result;
  }

  void setTriggerLevel(double level) {
    triggerLevel.value = level;
    dataAcquisitionService.triggerLevel = level;
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
  }

  void setTriggerMode(TriggerMode mode) {
    triggerMode.value = mode;
    dataAcquisitionService.triggerMode = mode;
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
  }

  void setTriggerEdge(TriggerEdge edge) {
    triggerEdge.value = edge;
    dataAcquisitionService.triggerEdge = edge;
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
  }

  void setTimeScale(double scale) {
    timeScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
  }

  void setValueScale(double scale) {
    valueScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService.updateConfig(); // Send updated config to processing isolate
  }

  @override
  void onClose() {
    stopData(); // Stop data acquisition when the controller is closed
    super.onClose();
  }
}