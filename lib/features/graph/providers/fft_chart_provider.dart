// lib/features/graph/providers/fft_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/fft_chart_service.dart';
import '../domain/models/data_point.dart';

class FFTChartProvider extends GetxController {
  final FFTChartService fftChartService;

  // Reactive variables
  final fftPoints = Rx<List<DataPoint>>([]);

  FFTChartProvider(this.fftChartService) {
    // Subscribe to streams
    fftChartService.fftStream.listen((points) {
      fftPoints.value = points;
    });
  }

  @override
  void onClose() {
    fftChartService.dispose();
    super.onClose();
  }
}