// lib/features/graph/providers/line_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import '../domain/models/filter_types.dart';
import 'dart:async';


class LineChartProvider extends GetxController {
  final LineChartService lineChartService;
  StreamSubscription? _dataSubscription;

  final dataPoints = Rx<List<DataPoint>>([]);
  final currentFilter = Rx<FilterType>(NoFilter());
  final windowSize = RxInt(5);
  final alpha = RxDouble(0.2);
  final cutoffFrequency = RxDouble(100.0);
  final timeScale = RxDouble(1.0);
  final valueScale = RxDouble(1.0);

  LineChartProvider(this.lineChartService) {
    // Subscribe to filtered data stream
    _dataSubscription = lineChartService.dataStream.listen((points) {
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
    lineChartService.setFilter(filter);
  }

  void setWindowSize(int size) {
    windowSize.value = size;
    lineChartService.setWindowSize(size);
  }

  void setAlpha(double value) {
    alpha.value = value;
    lineChartService.setAlpha(value);
  }

  void setCutoffFrequency(double freq) {
    cutoffFrequency.value = freq;
    lineChartService.setCutoffFrequency(freq);
  }

  void setTimeScale(double scale) {
    print('Setting time scale: $scale'); // Debug
    timeScale.value = scale;
  }

  void setValueScale(double scale) {
    print('Setting value scale: $scale'); // Debug
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