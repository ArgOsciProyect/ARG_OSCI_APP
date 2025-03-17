import 'dart:math';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'dart:async';

/// [OscilloscopeChartProvider] manages the state and logic for the Oscilloscope chart.
///
/// Handles user interactions, zooming, panning, and maintains the state of the
/// time-domain waveform display. Coordinates with data acquisition and chart services.
class OscilloscopeChartProvider extends GetxController {
  final OscilloscopeChartService _oscilloscopeChartService;
  final graphProvider = Get.find<DataAcquisitionProvider>();

  StreamSubscription? _dataSubscription;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();

  static const double zoomFactor = 1.02;
  static const double unzoomFactor = 0.98;

  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = RxDouble(1.0);
  final _valueScale = RxDouble(1.0);
  final _isPaused = false.obs;
  final _horizontalOffset = RxDouble(0.0);
  final _verticalOffset = RxDouble(0.0);
  double _initialTimeScale = 1.0;
  double _initialValueScale = 1.0;
  double _drawingWidth = 0.0;

  Timer? _incrementTimer;

  List<DataPoint> get dataPoints => _dataPoints.value;
  double get timeScale => _timeScale.value;
  double get valueScale => _valueScale.value;
  bool get isPaused => _isPaused.value;
  double get horizontalOffset => _horizontalOffset.value;
  double get verticalOffset => _verticalOffset.value;
  double get initialTimeScale => _initialTimeScale;
  double get initialValueScale => _initialValueScale;

  OscilloscopeChartProvider(this._oscilloscopeChartService) {
    _dataSubscription = _oscilloscopeChartService.dataStream.listen((points) {
      _dataPoints.value = points;
    });
    _timeScale.value = 1.0;

    // Set initial value scale based on new max/min bits range
    final range = deviceConfig.maxBits - deviceConfig.minBits;
    _valueScale.value = 1.0 / range;
  }

  /// Handles zoom gestures, updating scales and offsets while maintaining the focal point.
  ///
  /// Responds to two-finger zoom gestures with proper scaling calculations and
  /// maintains the focal point position during zoom operations.
  ///
  /// [details] Scale gesture information from the gesture detector
  /// [constraints] Current size constraints of the chart
  /// [offsetX] Horizontal offset of the drawing area
  void handleZoom(
      ScaleUpdateDetails details, Size constraints, double offsetX) {
    if (details.pointerCount == 2) {
      final focalDomainX =
          screenToDomainX(details.focalPoint.dx, constraints, offsetX);
      final focalDomainY =
          screenToDomainY(details.focalPoint.dy, constraints, offsetX);

      final newZoomFactor = pow(details.scale, 2.0);
      final newTimeScale = _initialTimeScale * newZoomFactor;

      // Get the last data point (maximum X)
      final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;

      // Allow zoom only if:
      // 1. We're zooming in (increasing the scale)
      // 2. Or if zooming out won't make data occupy less than 100% of visible width
      if (newTimeScale > _timeScale.value ||
          (maxDataX * newTimeScale >= _drawingWidth)) {
        setTimeScale(newTimeScale);
        setValueScale(_initialValueScale * newZoomFactor);

        // Update offset to maintain the focal point
        final newFocalScreenX =
            domainToScreenX(focalDomainX, constraints, offsetX);
        final newFocalScreenY =
            domainToScreenY(focalDomainY, constraints, offsetX);

        final newHorizontalOffset = horizontalOffset +
            (newFocalScreenX - details.focalPoint.dx) / _drawingWidth;
        final newVerticalOffset = verticalOffset -
            (newFocalScreenY - details.focalPoint.dy) / constraints.height;

        setHorizontalOffset(newHorizontalOffset);
        setVerticalOffset(newVerticalOffset);
      }
    }
  }

  /// Converts a screen X coordinate to a domain X coordinate.
  ///
  /// Transforms pixel position to time value accounting for current scale and offset.
  ///
  /// [screenX] X-coordinate in screen/pixel space
  /// [size] Current chart size
  /// [offsetX] Horizontal offset of the drawing area
  /// Returns the corresponding time value in the data domain
  double screenToDomainX(double screenX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (screenX - offsetX) / timeScale -
        (horizontalOffset * drawingWidth / timeScale);
  }

  /// Converts a domain X coordinate to a screen X coordinate.
  ///
  /// Transforms time value to pixel position accounting for current scale and offset.
  ///
  /// [domainX] X-coordinate in time domain
  /// [size] Current chart size
  /// [offsetX] Horizontal offset of the drawing area
  /// Returns the corresponding pixel position on the screen
  double domainToScreenX(double domainX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (domainX * timeScale) + (horizontalOffset * drawingWidth) + offsetX;
  }

  /// Clears the data points and resumes data acquisition, waiting for a new trigger.
  ///
  /// Used in single trigger mode to prepare for capturing a new waveform.
  void clearForNewTrigger() {
    _dataPoints.value = [];
    resume(); // Remove pause first
    _oscilloscopeChartService.resumeAndWaitForTrigger();
  }

  /// Converts a screen Y coordinate to a domain Y coordinate.
  ///
  /// Transforms pixel position to voltage value accounting for current scale and offset.
  ///
  /// [screenY] Y-coordinate in screen/pixel space
  /// [size] Current chart size
  /// [offsetX] Horizontal offset of the drawing area (unused but kept for symmetry)
  /// Returns the corresponding voltage value in the data domain
  double screenToDomainY(double screenY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return -((screenY - drawingHeight / 2) / (drawingHeight / 2)) / valueScale -
        verticalOffset;
  }

  /// Converts a domain Y coordinate to a screen Y coordinate.
  ///
  /// Transforms voltage value to pixel position accounting for current scale and offset.
  ///
  /// [domainY] Y-coordinate in voltage domain
  /// [size] Current chart size
  /// [offsetX] Horizontal offset of the drawing area (unused but kept for symmetry)
  /// Returns the corresponding pixel position on the screen
  double domainToScreenY(double domainY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return (drawingHeight / 2) -
        (domainY + verticalOffset) * (drawingHeight / 2) * valueScale;
  }

  /// Sets the time scale, limiting zoom out and enforcing constraints based on trigger mode.
  ///
  /// In normal trigger mode, prevents zooming out beyond where data fills the screen.
  /// In single trigger mode, allows unlimited zooming.
  ///
  /// [scale] New time scale factor to apply
  void setTimeScale(double scale) {
    if (scale <= 0) return;

    final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;

    // In trigger mode, any scale is allowed
    if (graphProvider.triggerMode.value != TriggerMode.normal) {
      _timeScale.value = scale;
      return;
    }

    // For normal mode only:
    // 1. Zoom in is always allowed
    // 2. Zoom out is allowed only if data will still fill the visible width
    if (_drawingWidth <= 0 ||
        scale > _timeScale.value ||
        (maxDataX * scale >= _drawingWidth)) {
      _timeScale.value = scale;
      setHorizontalOffset(_horizontalOffset.value);
    }
  }

  /// Sets the value scale for the vertical axis.
  ///
  /// [scale] New value scale factor to apply
  void setValueScale(double scale) {
    if (scale > 0) {
      _valueScale.value = scale;
    }
  }

  /// Sets the initial scales for zooming.
  ///
  /// Stores current scale values as reference points for multi-touch zoom operations.
  void setInitialScales() {
    _initialTimeScale = timeScale;
    _initialValueScale = valueScale;
  }

  /// Resets the scales to their default values.
  void resetScales() {
    _timeScale.value = 1.0;
    _valueScale.value = 1.0;
  }

  /// Resets the offsets to zero.
  void resetOffsets() {
    _horizontalOffset.value = 0.0;
    _verticalOffset.value = 0.0;
  }

  /// Updates the drawing width and adjusts the horizontal offset.
  ///
  /// Called when the chart size changes to maintain proper offsets.
  ///
  /// [size] Current chart size
  /// [offsetX] Horizontal offset of the drawing area
  void updateDrawingWidth(Size size, double offsetX) {
    _drawingWidth = size.width - offsetX;
    // Readjust offset when size changes
    setHorizontalOffset(_horizontalOffset.value);
  }

  /// Sets the horizontal offset, clamping it to valid ranges based on trigger mode and data width.
  ///
  /// In normal mode, constrains panning to keep data visible.
  /// In trigger mode, allows free panning across the entire time domain.
  /// For small datasets, automatically centers the data in normal mode.
  ///
  /// [offset] New horizontal offset value to apply
  void setHorizontalOffset(double offset) {
    if (_drawingWidth <= 0) return;

    final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;
    final scaledDataWidth = maxDataX * timeScale;

    // If data is smaller than the visible area and we're in normal mode, center it
    if (scaledDataWidth <= _drawingWidth &&
        graphProvider.triggerMode.value == TriggerMode.normal) {
      _horizontalOffset.value = 0.0;
      return;
    }

    // In trigger mode, allow completely free panning
    if (graphProvider.triggerMode.value != TriggerMode.normal) {
      _horizontalOffset.value = offset;
      return;
    }

    // For normal mode, maintain previous limits
    final minOffset = -((scaledDataWidth - _drawingWidth) / _drawingWidth);
    _horizontalOffset.value = offset.clamp(minOffset, 0.0);
  }

  /// Sets the vertical offset for panning in the Y direction.
  ///
  /// [offset] New vertical offset value to apply
  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  /// Clears the data and resumes data acquisition.
  void clearAndResume() {
    _dataPoints.value = []; // Clear existing data
    _isPaused.value = false; // Unpause
    _oscilloscopeChartService.resume();
  }

  /// Increments the time scale (zoom in).
  void incrementTimeScale() {
    setTimeScale(timeScale * zoomFactor);
  }

  /// Decrements the time scale (zoom out).
  void decrementTimeScale() {
    setTimeScale(timeScale * unzoomFactor);
  }

  /// Increases the value scale (vertical zoom in)
  ///
  /// Applies zoom and adjusts vertical offset to maintain the center of the view.
  void incrementValueScale() {
    // 1. Record the original scale
    final oldScale = valueScale;

    // 2. Apply zoom
    final newScale = valueScale * zoomFactor;
    setValueScale(newScale);

    // 3. Adjust offset to maintain centered view
    // When increasing scale (zooming in), offset must increase proportionally
    setVerticalOffset(verticalOffset * (newScale / oldScale));
  }

  /// Decreases the value scale (vertical zoom out)
  ///
  /// Applies zoom and adjusts vertical offset to maintain the center of the view.
  void decrementValueScale() {
    // 1. Record the original scale
    final oldScale = valueScale;

    // 2. Apply zoom
    final newScale = valueScale * unzoomFactor;
    setValueScale(newScale);

    // 3. Adjust offset to maintain centered view
    // When decreasing scale (zooming out), offset must decrease proportionally
    setVerticalOffset(verticalOffset * (newScale / oldScale));
  }

  /// Increments the horizontal offset to pan right.
  void incrementHorizontalOffset() {
    final newOffset = horizontalOffset + 0.01;
    setHorizontalOffset(newOffset);
  }

  /// Decrements the horizontal offset to pan left.
  void decrementHorizontalOffset() {
    final newOffset = horizontalOffset - 0.01;
    setHorizontalOffset(newOffset);
  }

  /// Increments the vertical offset to pan up.
  void incrementVerticalOffset() {
    setVerticalOffset(verticalOffset + 0.1);
  }

  /// Decrements the vertical offset to pan down.
  void decrementVerticalOffset() {
    setVerticalOffset(verticalOffset - 0.1);
  }

  /// Starts a timer to repeatedly execute a callback function.
  ///
  /// Used for continuous control adjustments while a button is held down.
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

  /// Pauses data acquisition.
  void pause() {
    if (!_isPaused.value) {
      _isPaused.value = true;
      _oscilloscopeChartService.pause();
    }
  }

  /// Resumes data acquisition.
  ///
  /// If in single trigger mode, clears existing data and initiates a new trigger request.
  void resume() {
    if (_isPaused.value) {
      _isPaused.value = false;
      _oscilloscopeChartService.resume();

      // If we're in single mode, send a new trigger request
      if (graphProvider.triggerMode.value == TriggerMode.single) {
        _dataPoints.value = []; // Clear existing data
        graphProvider.setPause(false); // This will send GET /single
      }
    }
  }

  /// Automatically scales the chart based on the current signal parameters
  ///
  /// Adjusts time and voltage scales to optimally display the signal with margins.
  /// Centers the signal vertically and resets horizontal panning.
  ///
  /// [chartHeight] Current height of the chart in pixels
  /// [chartWidth] Current width of the chart in pixels
  Future<void> autoset(double chartHeight, double chartWidth) async {
    final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();

    // First, let the data acquisition service adjust its trigger level
    await dataAcquisitionProvider.autoset();

    // Get signal parameters
    final frequency = dataAcquisitionProvider.frequency.value;
    final maxValue = dataAcquisitionProvider.maxValue.value;
    final minValue = dataAcquisitionProvider.currentMinValue;

    // Use the service to calculate optimal scales
    final scales = _oscilloscopeChartService.calculateAutosetScales(
        chartWidth, frequency, maxValue, minValue);

    // Apply calculated scales
    setTimeScale(scales['timeScale']!);
    setValueScale(scales['valueScale']!);

    // Set vertical offset to center the signal
    setVerticalOffset(-scales['verticalCenter']! * valueScale);

    // Reset horizontal offset
    setHorizontalOffset(0.0);
  }

  @override
  void onClose() {
    _incrementTimer?.cancel();
    _dataSubscription?.cancel();
    _oscilloscopeChartService.dispose();
    super.onClose();
  }
}
