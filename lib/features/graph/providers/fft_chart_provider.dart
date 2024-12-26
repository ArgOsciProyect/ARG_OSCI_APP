// lib/features/graph/providers/fft_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/fft_chart_service.dart';
import '../domain/models/data_point.dart';

class FFTChartProvider extends GetxController {
  final FFTChartService fftChartService;

  // Reactive variables
  final fftPoints = Rx<List<DataPoint>>([]);
  final timeScale = Rx<double>(1.0);
  final valueScale = Rx<double>(1.0);

  FFTChartProvider(this.fftChartService) {
    // Subscribe to streams
    fftChartService.fftStream.listen((points) {
      //print first 1000 points
      fftPoints.value = points;
    });
  }

  @override
  void onClose() {
    fftChartService.dispose();
    super.onClose();
  }
}