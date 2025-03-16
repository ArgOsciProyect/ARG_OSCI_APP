import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

/// [FFTChartProvider] manages the state for the FFT chart.
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

  /// Sets the time scale (horizontal zoom) for the FFT chart.
  ///
  /// Limits "zoom out" to 1.0 (full view) while allowing "zoom in" (scale < 1.0).
  /// Adjusts horizontal offset if necessary to keep the view within valid range.
  ///
  /// [scale] New scale factor to apply, where smaller values mean higher zoom
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

  /// Sets the value scale (vertical zoom) for the FFT chart.
  ///
  /// If horizontal scale is at maximum (1.0) and attempting to increase
  /// vertical scale, the operation is ignored to maintain readability.
  ///
  /// [scale] New vertical scale factor, where larger values show more detail
  void setValueScale(double scale) {
    if (timeScale.value == 1.0 && scale > valueScale.value) {
      return;
    }
    if (scale > 0) {
      valueScale.value = scale;
    }
  }

  /// Applies zoom to both axes simultaneously.
  ///
  /// If the resulting horizontal scale would exceed 1.0, it's clamped
  /// to the maximum allowed value while preserving aspect ratio.
  ///
  /// [factor] Zoom factor to apply (> 1 zooms out, < 1 zooms in)
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

  /// Ensures the horizontal offset stays within valid range.
  ///
  /// Calculates the maximum allowed offset based on current zoom level
  /// and adjusts the current offset if it exceeds the valid range.
  void _clampHorizontalOffset() {
    final visibleRange = nyquistFreq * timeScale.value;
    // If timeScale < 1, visible range < nyquist, allowing panning
    final maxOffset = nyquistFreq - visibleRange;
    if (kDebugMode) {
      print("Max offset: $maxOffset");
      print("Visible range: $visibleRange");
      print("Horizontal offset: ${_horizontalOffset.value}");
    }
    final clamped = _horizontalOffset.value.clamp(0.0, maxOffset);
    _horizontalOffset.value = clamped;
  }

  /// Sets the horizontal offset (panning position) in frequency domain.
  ///
  /// [freqOffset] New frequency offset value in Hz
  void setHorizontalOffset(double freqOffset) {
    if (freqOffset == 0) {
      _horizontalOffset.value = 1;
    } else {
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

  /// Automatically adjusts the chart view to optimally display the detected signal.
  ///
  /// Calculates and applies the best scale and offset to show approximately
  /// ten times the fundamental frequency while centering the view around
  /// the primary signal component.
  ///
  /// [size] Current chart size
  /// [freq] The fundamental frequency to focus on
  void autoset(Size size, double freq) {
    // Guard against invalid frequency or size
    if (freq <= 0 || size.width <= 0) {
      resetScales();
      return;
    }

    // Calculate optimal scale to show roughly 10 times the fundamental frequency
    final targetFreq = freq * 10;
    final nyquistFreq = samplingFrequency / 2;

    // Calculate what portion of nyquist frequency we want to show
    final desiredScale = targetFreq / nyquistFreq;

    // Clamp the scale between 0.001 and 1.0
    final clampedScale = desiredScale.clamp(0.001, 1.0);

    if (kDebugMode) {
      print("Auto-set calculation:");
      print("Target frequency: $targetFreq Hz");
      print("Nyquist frequency: $nyquistFreq Hz");
      print("Desired scale: $desiredScale");
      print("Clamped scale: $clampedScale");
    }

    // Apply the new scales
    timeScale.value = clampedScale;
    valueScale.value = 1.0;

    // Center the view on the frequency of interest
    final centerOffset = freq - ((nyquistFreq * clampedScale) / 2);
    setHorizontalOffset(
        centerOffset.clamp(0.0, nyquistFreq - (nyquistFreq * clampedScale)));
  }

  /// Increases time scale zoom level (zooms in)
  void incrementTimeScale() => setTimeScale(timeScale.value / 1.02);

  /// Decreases time scale zoom level (zooms out)
  void decrementTimeScale() => setTimeScale(timeScale.value * 1.02);

  /// Increases value scale zoom level (zooms in)
  void incrementValueScale() => setValueScale(valueScale.value / 1.02);

  /// Decreases value scale zoom level (zooms out)
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

  /// Starts continuous action when button is held down.
  ///
  /// Sets up a periodic timer to continuously call the provided callback
  /// while a control button is held down.
  ///
  /// [callback] Function to call repeatedly
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
