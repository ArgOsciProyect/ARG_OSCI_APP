// lib/features/graph/providers/line_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import 'dart:async';


class LineChartProvider extends GetxController {
  final LineChartService lineChartService;
  StreamSubscription? _dataSubscription;

  final dataPoints = Rx<List<DataPoint>>([]);
  final timeScale = RxDouble(1.0);
  final valueScale = RxDouble(1.0);

  LineChartProvider(this.lineChartService) {
    _dataSubscription = lineChartService.dataStream.listen((points) {
      dataPoints.value = points;
    });
  }

  void setTimeScale(double scale) {
    timeScale.value = scale;
  }

  void setValueScale(double scale) {
    valueScale.value = scale;
  }

  void resetScales() {
    timeScale.value = 1.0;
    valueScale.value = 1.0;
  }

  @override
  void onClose() {
    _dataSubscription?.cancel();
    lineChartService.dispose();
    super.onClose();
  }

  double getTimeScale() => timeScale.value; 
  double getValueScale() => valueScale.value;
}