// lib/features/graph/providers/line_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';

class LineChartProvider extends GetxController {
  final LineChartService lineChartService;

  // Reactive variables
  final dataPoints = Rx<List<DataPoint>>([]);
  final currentFilter = Rx<FilterType>(FilterType.movingAverage);
  final windowSize = RxInt(5);
  final alpha = RxDouble(0.2);
  final cutoffFrequency = RxDouble(100.0);

  LineChartProvider(this.lineChartService) {
    // Subscribe to filtered data stream
    lineChartService.dataStream.listen((points) {
      dataPoints.value = points;
    });

    // Initialize values from service
    currentFilter.value = lineChartService.currentFilter;
    windowSize.value = lineChartService.windowSize;
    alpha.value = lineChartService.alpha;
    cutoffFrequency.value = lineChartService.cutoffFrequency;
  }

  void setFilter(FilterType filter) {
    currentFilter.value = filter;
    print("Filter: $filter");
    lineChartService.setFilter(filter);
  }

  void setWindowSize(int size) {
    windowSize.value = size;
    print("Window size: $size");
    lineChartService.setWindowSize(size);
  }

  void setAlpha(double value) {
    alpha.value = value;
    print("Alpha: $value");
    lineChartService.setAlpha(value);
  }

  void setCutoffFrequency(double freq) {
    cutoffFrequency.value = freq;
    print("Cutoff frequency: $freq");
    lineChartService.setCutoffFrequency(freq);
  }

  @override
  void onClose() {
    lineChartService.dispose();
    super.onClose();
  }
}