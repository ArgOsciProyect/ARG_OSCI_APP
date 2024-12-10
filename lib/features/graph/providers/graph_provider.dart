// lib/features/graph/providers/graph_provider.dart
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/domain/services/data_acquisition_service.dart';
import '../../graph/domain/models/trigger_data.dart';

class GraphProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  var dataPoints = <DataPoint>[].obs;
  var frequency = 1.0.obs;
  var maxValue = 1.0.obs;
  var triggerLevel = 0.0.obs;
  var triggerMode = TriggerMode.automatic.obs;
  var triggerEdge = TriggerEdge.positive.obs;
  var timeScale = 1.0.obs;
  var valueScale = 1.0.obs;
  var maxX = 1.0.obs;

  GraphProvider(this.dataAcquisitionService);

  Future<void> fetchData() async {
    await dataAcquisitionService.fetchData();
    dataAcquisitionService.dataPointsStream.listen((newDataPoints) {
      dataPoints.value = newDataPoints;
    });
    dataAcquisitionService.frequencyStream.listen((newFrequency) {
      frequency.value = newFrequency;
    });
    dataAcquisitionService.maxValueStream.listen((newMaxValue) {
      maxValue.value = newMaxValue;
    });
  }

  Future<void> stopData() async {
    await dataAcquisitionService.stopData();
  }

  List<double> autoset(double chartHeight, double chartWidth) {
    return dataAcquisitionService.autoset(dataPoints, chartHeight, chartWidth);
  }

  void setTriggerLevel(double level) {
    triggerLevel.value = level;
    dataAcquisitionService.triggerLevel = level;
  }

  void setTriggerMode(TriggerMode mode) {
    triggerMode.value = mode;
    dataAcquisitionService.triggerMode = mode;
  }

  void setTriggerEdge(TriggerEdge edge) {
    triggerEdge.value = edge;
    dataAcquisitionService.triggerEdge = edge;
  }

  void setTimeScale(double scale) {
    timeScale.value = scale;
  }

  void setValueScale(double scale) {
    valueScale.value = scale;
  }
}