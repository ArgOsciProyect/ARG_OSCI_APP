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
  void handleZoom(
      ScaleUpdateDetails details, Size constraints, double offsetX) {
    if (details.pointerCount == 2) {
      final focalDomainX =
          screenToDomainX(details.focalPoint.dx, constraints, offsetX);
      final focalDomainY =
          screenToDomainY(details.focalPoint.dy, constraints, offsetX);

      final newZoomFactor = pow(details.scale, 2.0);
      final newTimeScale = _initialTimeScale * newZoomFactor;

      // Obtener el último punto de datos (máximo X)
      final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;

      // Permitir zoom solo si:
      // 1. Estamos haciendo zoom in (aumentando la escala)
      // 2. O si el zoom out no hará que los datos ocupen menos del 100% del ancho visible
      if (newTimeScale > _timeScale.value ||
          (maxDataX * newTimeScale >= _drawingWidth)) {
        setTimeScale(newTimeScale);
        setValueScale(_initialValueScale * newZoomFactor);

        // Actualizar offset manteniendo el punto focal
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
  double screenToDomainX(double screenX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (screenX - offsetX) / timeScale -
        (horizontalOffset * drawingWidth / timeScale);
  }

  /// Converts a domain X coordinate to a screen X coordinate.
  double domainToScreenX(double domainX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (domainX * timeScale) + (horizontalOffset * drawingWidth) + offsetX;
  }

  /// Clears the data points and resumes data acquisition, waiting for a new trigger.
  void clearForNewTrigger() {
    _dataPoints.value = [];
    resume(); // Quitamos la pausa primero
    _oscilloscopeChartService.resumeAndWaitForTrigger();
  }

  /// Converts a screen Y coordinate to a domain Y coordinate.
  double screenToDomainY(double screenY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return -((screenY - drawingHeight / 2) / (drawingHeight / 2)) / valueScale -
        verticalOffset;
  }

  /// Converts a domain Y coordinate to a screen Y coordinate.
  double domainToScreenY(double domainY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return (drawingHeight / 2) -
        (domainY + verticalOffset) * (drawingHeight / 2) * valueScale;
  }

  /// Sets the time scale, limiting zoom out and enforcing constraints based on trigger mode.
  void setTimeScale(double scale) {
    if (scale <= 0) return;

    final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;

    // En modo trigger, permitir cualquier escala
    if (graphProvider.triggerMode.value != TriggerMode.normal) {
      _timeScale.value = scale;
      return;
    }

    // Solo para modo normal:
    // 1. Zoom in siempre permitido
    // 2. Zoom out solo si los datos ocupan al menos el ancho visible
    if (_drawingWidth <= 0 ||
        scale > _timeScale.value ||
        (maxDataX * scale >= _drawingWidth)) {
      _timeScale.value = scale;
      setHorizontalOffset(_horizontalOffset.value);
    }
  }

  /// Sets the value scale.
  void setValueScale(double scale) {
    if (scale > 0) {
      _valueScale.value = scale;
    }
  }

  /// Sets the initial scales for zooming.
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
  void updateDrawingWidth(Size size, double offsetX) {
    _drawingWidth = size.width - offsetX;
    // Reajustar offset al cambiar el tamaño
    setHorizontalOffset(_horizontalOffset.value);
  }

  /// Sets the horizontal offset, clamping it to valid ranges based on trigger mode and data width.
  void setHorizontalOffset(double offset) {
    if (_drawingWidth <= 0) return;

    final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;
    final scaledDataWidth = maxDataX * timeScale;

    // Si los datos son más pequeños que el área visible y estamos en modo normal, centrar
    if (scaledDataWidth <= _drawingWidth &&
        graphProvider.triggerMode.value == TriggerMode.normal) {
      _horizontalOffset.value = 0.0;
      return;
    }

    // En modo trigger, permitir desplazamiento completamente libre
    if (graphProvider.triggerMode.value != TriggerMode.normal) {
      _horizontalOffset.value = offset;
      return;
    }

    // Para modo normal, mantener límites anteriores
    final minOffset = -((scaledDataWidth - _drawingWidth) / _drawingWidth);
    _horizontalOffset.value = offset.clamp(minOffset, 0.0);
  }

  /// Sets the vertical offset.
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

  /// Increments the horizontal offset.
  void incrementHorizontalOffset() {
    final newOffset = horizontalOffset + 0.01;
    setHorizontalOffset(newOffset);
  }

  /// Decrements the horizontal offset.
  void decrementHorizontalOffset() {
    final newOffset = horizontalOffset - 0.01;
    setHorizontalOffset(newOffset);
  }

  /// Increments the vertical offset.
  void incrementVerticalOffset() {
    setVerticalOffset(verticalOffset + 0.1);
  }

  /// Decrements the vertical offset.
  void decrementVerticalOffset() {
    setVerticalOffset(verticalOffset - 0.1);
  }

  /// Starts a timer to repeatedly execute a callback function.
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
  void resume() {
    if (_isPaused.value) {
      _isPaused.value = false;
      _oscilloscopeChartService.resume();

      // Si estamos en modo single, enviamos una nueva solicitud de trigger
      if (graphProvider.triggerMode.value == TriggerMode.single) {
        _dataPoints.value = []; // Limpiamos los datos existentes
        graphProvider.setPause(false); // Esto enviará GET /single
      }
    }
  }

  /// Automatically scales the chart based on the current signal parameters
  /// Adds a 15% margin above and below the signal's extremes for better visualization
  Future<void> autoset(double chartHeight, double chartWidth) async {
    final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();

    // First, let the data acquisition service adjust its trigger level
    await dataAcquisitionProvider.autoset();

    // Calculate appropriate scales based on signal information
    final frequency = dataAcquisitionProvider.frequency.value;
    final maxValue = dataAcquisitionProvider.maxValue.value;
    final minValue = dataAcquisitionProvider.currentMinValue;

    // Add 15% margin to min and max values
    const marginFactor = 1.15;
    final adjustedMaxValue =
        maxValue > 0 ? maxValue * marginFactor : maxValue / marginFactor;
    final adjustedMinValue =
        minValue < 0 ? minValue * marginFactor : minValue / marginFactor;

    // Calculate the total range with margins
    final totalRange = adjustedMaxValue - adjustedMinValue;

    if (frequency <= 0) {
      // No frequency detected, use default scales
      setTimeScale(100000);

      // Use the adjusted range for value scale
      if (totalRange != 0) {
        // Scale to fit the total range in the chart height
        setValueScale(1.0 / totalRange);
      } else {
        // Fallback for zero or very small range
        setValueScale(1.0);
      }
    } else {
      // Calculate time scale to show 3 periods
      final period = 1 / frequency;
      final totalTime = 3 * period;
      final timeScale = chartWidth / totalTime;

      // Calculate value scale to fit the expanded signal range vertically
      if (totalRange != 0) {
        // Scale to fit the total range in the chart height
        setValueScale(1.0 / totalRange);
      } else {
        // Fallback using max absolute value
        final maxAbsValue = max(maxValue.abs(), minValue.abs());
        final expandedAbsValue = maxAbsValue * marginFactor;
        setValueScale(
            expandedAbsValue != 0 ? 1.0 / (expandedAbsValue * 2) : 1.0);
      }

      setTimeScale(timeScale);
    }

    // Set vertical offset to center the signal
    // This ensures the signal is centered even with asymmetric min/max values
    final verticalCenter = (adjustedMaxValue + adjustedMinValue) / 2;
    setVerticalOffset(-verticalCenter * valueScale);

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
