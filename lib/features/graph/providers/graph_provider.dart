// lib/features/graph/providers/graph_provider.dart
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/domain/services/data_acquisition_service.dart';

class GraphProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  var dataPoints = <DataPoint>[].obs;
  var frequency = 1.0.obs;
  var maxValue = 1.0.obs;

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

  List<double> autoset(double valueScale, double timeScale, double chartHeight, double chartWidth) {
    return dataAcquisitionService.autoset(dataPoints, valueScale, timeScale, chartHeight, chartWidth);
  }
}