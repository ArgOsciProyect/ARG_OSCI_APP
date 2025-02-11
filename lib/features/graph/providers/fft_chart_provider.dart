import 'dart:async';
import 'dart:math';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// [FFTChartProvider] manages the state and logic for the FFT chart.
class FFTChartProvider extends GetxController {
  final FFTChartService fftChartService;
  final deviceConfig = Get.find<DeviceConfigProvider>();

  // Reactive variables for FFT data, scales, and offsets
  final fftPoints = Rx<List<DataPoint>>([]);
  final timeScale = RxDouble(1.0);
  final valueScale = RxDouble(1.0);
  final _isPaused = false.obs;
  final _horizontalOffset = 0.0.obs;
  final _verticalOffset = 0.0.obs;

  // Getters for reactive variables
  bool get isPaused => _isPaused.value;
  double get horizontalOffset => _horizontalOffset.value;
  double get verticalOffset => _verticalOffset.value;

  // Internal variables for initial scales, timer, frequency, and drawing width
  double _initialTimeScale = 1.0;
  double _initialValueScale = 1.0;
  Timer? _incrementTimer;
  final frequency = 0.0.obs;
  double _drawingWidth = 0.0;

  // Computed properties based on device configuration
  double get samplingFrequency => deviceConfig.samplingFrequency;
  double get initialTimeScale => _initialTimeScale;
  double get initialValueScale => _initialValueScale;
  double get nyquistFreq => samplingFrequency / 2;

  FFTChartProvider(this.fftChartService) {
    // Listen to the FFT data stream and update the FFT points and frequency
    fftChartService.fftStream.listen((points) {
      fftPoints.value = points;
      frequency.value = fftChartService.frequency;
    });
  }

  @override
  void onClose() {
    _incrementTimer?.cancel();
    super.onClose();
  }

  /// Sets the initial scales for zooming.
  void setInitialScales() {
    _initialTimeScale = timeScale.value;
    _initialValueScale = valueScale.value;
  }

  /// Updates the drawing width of the chart area.
  void updateDrawingWidth(Size size, double offsetX) {
    _drawingWidth = (size.width - offsetX).clamp(0, double.maxFinite);
  }

  /// Limitamos "zoom out" a 1.0, permitimos zoom in (< 1.0).
  void setTimeScale(double scale) {
    if (scale > 1.0) {
      if (timeScale.value == 1.0) return; 
      scale = 1.0;
    }
    final oldScale = timeScale.value;
    timeScale.value = scale;
    if (timeScale.value != oldScale) {
      _clampHorizontalOffset();
    }
  }

  /// Si X está en 1.0 y se intenta subir Y => no forzar para mantener proporción
  void setValueScale(double scale) {
    if (timeScale.value == 1.0 && scale > valueScale.value) {
      return;
    }
    if (scale > 0) {
      valueScale.value = scale;
    }
  }

  /// Zoom simultáneo. Si factor > 1 => clamp a 1
  void zoomXY(double factor) {
    final newTS = timeScale.value * factor;
    if (newTS > 1.0) {
      if (timeScale.value == 1.0) return;
      setTimeScale(1.0);
      return;
    }
    final oldTS = timeScale.value;
    setTimeScale(newTS);
    if (timeScale.value != oldTS) {
      setValueScale(valueScale.value * factor);
    }
  }

  void zoomX(double factor) {
  setTimeScale(timeScale.value * factor);
}

void zoomY(double factor) {
  setValueScale(valueScale.value * factor);
}

  /// Sets the vertical offset of the chart.
  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  /// Clamps the horizontal offset to ensure it stays within the valid range.
  void _clampHorizontalOffset() {
    final visibleRange = nyquistFreq * timeScale.value; 
    // Si timeScale < 1 => visibleRange < nyquist => podemos desplazar
    final maxOffset = nyquistFreq - visibleRange; 
    print("Max offset: $maxOffset");
    print("Visible range: $visibleRange");
    print("Horizontal offset: ${_horizontalOffset.value}");
    final clamped = _horizontalOffset.value.clamp(0.0, maxOffset);
    _horizontalOffset.value = clamped;
  }

  /// Sets the horizontal offset of the chart.
  void setHorizontalOffset(double freqOffset) {
    if(freqOffset == 0){
      _horizontalOffset.value = 1;
    }
    else{
    _horizontalOffset.value = freqOffset;
    }
    _clampHorizontalOffset();
  }

  /// Resets both horizontal and vertical offsets to zero.
  void resetOffsets() {
    _horizontalOffset.value = 0.0;
    _verticalOffset.value = 0.0;
  }

  /// Resets scales and offsets to their default values.
  void resetScales() {
    timeScale.value = 1.0;
    valueScale.value = 1.0;
    resetOffsets();
  }

  /// Automatically adjusts the time scale based on the frequency and chart size.
  void autoset(Size size, double freq) {
    final useFreq = freq > 0 ? freq/7 : 1;
    updateDrawingWidth(size, 50);
    final newScale = (_drawingWidth <= 0) ? 1.0 : max(1e-3, _drawingWidth / useFreq);
    final clampedScale = min(newScale, 1.0);
    timeScale.value = clampedScale;
    valueScale.value = 1.0;
    resetOffsets();
  }

  /// Invertimos increment/decrement para que "increment" haga zoom-in (scale disminuye)
  void incrementTimeScale() => setTimeScale(timeScale.value / 1.02);
  void decrementTimeScale() => setTimeScale(timeScale.value * 1.02);

  /// Igual para Y
  void incrementValueScale() => setValueScale(valueScale.value / 1.02);
  void decrementValueScale() => setValueScale(valueScale.value * 1.02);

  /// Increments the horizontal offset by a fixed amount.
  void incrementHorizontalOffset() =>
      setHorizontalOffset(_horizontalOffset.value + 50);

  /// Decrements the horizontal offset by a fixed amount.
  void decrementHorizontalOffset() =>
      setHorizontalOffset(_horizontalOffset.value - 50);

  /// Increments the vertical offset by a fixed amount.
  void incrementVerticalOffset() =>
      setVerticalOffset(_verticalOffset.value + 0.1);

  /// Decrements the vertical offset by a fixed amount.
  void decrementVerticalOffset() =>
      setVerticalOffset(_verticalOffset.value - 0.1);

  /// Mantener presionado un botón para repetir acción
  void startIncrementing(VoidCallback callback) {
    callback();
    _incrementTimer?.cancel();
    _incrementTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
      callback();
    });
  }

  /// Stops the incrementing timer.
  void stopIncrementing() {
    _incrementTimer?.cancel();
    _incrementTimer = null;
  }

  /// Pauses the FFT chart data acquisition.
  void pause() {
    _isPaused.value = true;
    fftChartService.pause();
  }

  /// Resumes the FFT chart data acquisition.
  void resume() {
    _isPaused.value = false;
    fftChartService.resume();
  }
}