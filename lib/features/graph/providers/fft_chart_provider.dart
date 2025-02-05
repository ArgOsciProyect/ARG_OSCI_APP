// lib/features/graph/providers/fft_chart_provider.dart
import 'dart:async';
import 'dart:math';

import 'package:flutter/widgets.dart';
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
  final _horizontalOffset = RxDouble(0.0);
  final _verticalOffset = RxDouble(0.0);
  double _initialTimeScale = 1.0;
  double _initialValueScale = 1.0;
  Timer? _incrementTimer;
  final frequency = 0.0.obs;

  // Add getters
  double get horizontalOffset => _horizontalOffset.value;
  double get verticalOffset => _verticalOffset.value;
  double get initialTimeScale => _initialTimeScale;
  double get initialValueScale => _initialValueScale;

  FFTChartProvider(this.fftChartService) {
    // Subscribe to FFT stream
    fftChartService.fftStream.listen((points) {
      fftPoints.value = points;
      // Update frequency when new FFT data arrives
      frequency.value = fftChartService.frequency;
    });
  }

  void setInitialScales() {
    _initialTimeScale = timeScale.value;
    _initialValueScale = valueScale.value;
  }

  void handleZoom(ScaleUpdateDetails details, Size constraints) {
    if (details.pointerCount == 2) {
      final zoomFactor = pow(details.scale, 2.0);
      setTimeScale(_initialTimeScale * zoomFactor);
      setValueScale(_initialValueScale * zoomFactor);
    }
  }

  void setHorizontalOffset(double offset) {
    // Prevent negative offsets (scrolling left of 0)
    _horizontalOffset.value = offset >= 0 ? 0 : offset;
  }

  void autoset(Size size, double frequency) {
    // Calculate time scale to show frequency range from 0 to 7*sampling_frequency/2
    final maxFreq = frequency / 7;
    final pointsPerFreq = size.width / maxFreq;

    // Set scales to show full range
    timeScale.value = pointsPerFreq;
    valueScale.value = 1.0;

    // Reset offsets
    resetOffsets();
  }

  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  void resetOffsets() {
    _horizontalOffset.value = 0.0;
    _verticalOffset.value = 0.0;
  }

  // Add increment/decrement methods
  void incrementTimeScale() => setTimeScale(timeScale.value * 1.02);
  void decrementTimeScale() => setTimeScale(timeScale.value * 0.98);
  void incrementValueScale() => setValueScale(valueScale.value * 1.02);
  void decrementValueScale() => setValueScale(valueScale.value * 0.98);

  void incrementHorizontalOffset() =>
      setHorizontalOffset(horizontalOffset + 0.01);
  void decrementHorizontalOffset() =>
      setHorizontalOffset(horizontalOffset - 0.01);
  void incrementVerticalOffset() => setVerticalOffset(verticalOffset + 0.1);
  void decrementVerticalOffset() => setVerticalOffset(verticalOffset - 0.1);

  void startIncrementing(VoidCallback callback) {
    callback();
    _incrementTimer?.cancel();
    _incrementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      callback();
    });
  }

  void stopIncrementing() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
  }

  @override
  void onClose() {
    _incrementTimer?.cancel();
    super.onClose();
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
}
