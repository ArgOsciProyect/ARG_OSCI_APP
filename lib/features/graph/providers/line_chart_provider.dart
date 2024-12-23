// lib/features/graph/providers/line_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';

class LineChartProvider extends GetxController {
  final LineChartService lineChartService;

  // Reactive variables
  final dataPoints = Rx<List<DataPoint>>([]);

  LineChartProvider(this.lineChartService) {
    // Subscribe to streams
    lineChartService.dataStream.listen((points) {
      dataPoints.value = points;
    });
  }

  @override
  void onClose() {
    lineChartService.dispose();
    super.onClose();
  }
}