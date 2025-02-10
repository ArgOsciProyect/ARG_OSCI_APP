import 'dart:async';
import 'dart:math';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

class FFTChartProvider extends GetxController {
  final FFTChartService fftChartService;
  final deviceConfig = Get.find<DeviceConfigProvider>();

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
  double _drawingWidth = 0.0;

  // Add getters
  double get horizontalOffset => _horizontalOffset.value;
  double get verticalOffset => _verticalOffset.value;
  double get initialTimeScale => _initialTimeScale;
  double get initialValueScale => _initialValueScale;
  double get samplingFrequency => deviceConfig.samplingFrequency;

  FFTChartProvider(this.fftChartService) {
    fftChartService.fftStream.listen((points) {
      fftPoints.value = points;
      frequency.value = fftChartService.frequency;
    });
  }

  void setInitialScales() {
    _initialTimeScale = timeScale.value;
    _initialValueScale = valueScale.value;
  }

  void updateDrawingWidth(Size size, double offsetX) {
    _drawingWidth = size.width - offsetX;
  }

  void handleZoom(ScaleUpdateDetails details, Size constraints) {
    if (details.pointerCount == 2) {
      final zoomFactor = pow(details.scale, 2.0);
      // Calcular nuevo timeScale
      final newTimeScale = _initialTimeScale * zoomFactor;

      // Comprobar si el nuevo timeScale mostraría frecuencias más allá de Nyquist
      final nyquistFreq = deviceConfig.samplingFrequency / 2;
      final visibleFreqAtRightEdge = nyquistFreq / newTimeScale;

      // Solo permitir zoom si no excede la frecuencia de Nyquist
      if (visibleFreqAtRightEdge >= nyquistFreq) {
        setTimeScale(newTimeScale);
      }

      setValueScale(_initialValueScale * zoomFactor);
    }
  }

  double _calculateMaxOffset(double width) {
    if (width <= 0) return 0.0;

    final nyquistFreq = deviceConfig.samplingFrequency / 2;
    final dataWidth = nyquistFreq * timeScale.value;

    if (dataWidth <= width) return 0.0;
    return -(dataWidth - width) / width;
  }

  void setHorizontalOffset(double offset) {
    final maxOffset = _calculateMaxOffset(_drawingWidth);
    _horizontalOffset.value = offset.clamp(maxOffset, 0.0);
  }

  double toScreenX(double x, double width, double nyquistFreq, double offsetX) {
    // Clamp x to Nyquist frequency
    final clampedX = x.clamp(0.0, nyquistFreq);

    // Calculate screen position with clamped horizontal offset
    return offsetX +
        ((clampedX / nyquistFreq) * width) +
        (_horizontalOffset.value.clamp(-1.0, 0.0) * width);
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
    // Calcular la frecuencia visible en el borde derecho con el nuevo scale
    final nyquistFreq = deviceConfig.samplingFrequency / 2;
    final visibleFreqAtRightEdge = nyquistFreq / scale;

    // Solo permitir el cambio si no excede la frecuencia de Nyquist
    if (visibleFreqAtRightEdge >= nyquistFreq || scale < timeScale.value) {
      timeScale.value = scale;
    }
  }

  void setValueScale(double scale) {
    if (scale > 0) {
      valueScale.value = scale;
    }
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
