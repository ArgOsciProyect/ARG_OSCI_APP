// lib/features/graph/providers/fft_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/fft_chart_service.dart';
import '../domain/models/data_point.dart';

class FFTChartProvider extends GetxController {
  final FFTChartService fftChartService;

  // Reactive state
  final fftPoints = Rx<List<DataPoint>>([]);
  final timeScale = RxDouble(1.0);
  final valueScale = RxDouble(1.0);
  final _isPaused = false.obs;
  bool get isPaused => _isPaused.value;

  FFTChartProvider(this.fftChartService) {
    // Subscribe to filtered data stream
    fftChartService.fftStream.listen((points) {
      fftPoints.value = points;
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

  void pause() {
    _isPaused.value = true;
    fftChartService.pause();
  }

  void resume() {
    _isPaused.value = false;
    fftChartService.resume();
  }

  @override
  void onClose() {
    fftChartService.dispose();
    super.onClose();
  }
}
