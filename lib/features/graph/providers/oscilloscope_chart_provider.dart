import 'dart:math';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import 'dart:async';

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
    _valueScale.value = 1.0 / (1 << deviceConfig.usefulBits);
  }

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

  double screenToDomainX(double screenX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (screenX - offsetX) / timeScale -
        (horizontalOffset * drawingWidth / timeScale);
  }

  double domainToScreenX(double domainX, Size size, double offsetX) {
    final drawingWidth = size.width;
    return (domainX * timeScale) + (horizontalOffset * drawingWidth) + offsetX;
  }

  void clearForNewTrigger() {
    _dataPoints.value = [];
    resume(); // Quitamos la pausa primero
    _oscilloscopeChartService.resumeAndWaitForTrigger();
  }

  double screenToDomainY(double screenY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return -((screenY - drawingHeight / 2) / (drawingHeight / 2)) / valueScale -
        verticalOffset;
  }

  double domainToScreenY(double domainY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return (drawingHeight / 2) -
        (domainY + verticalOffset) * (drawingHeight / 2) * valueScale;
  }

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

  void setValueScale(double scale) {
    if (scale > 0) {
      _valueScale.value = scale;
    }
  }

  void setInitialScales() {
    _initialTimeScale = timeScale;
    _initialValueScale = valueScale;
  }

  void resetScales() {
    _timeScale.value = 1.0;
    _valueScale.value = 1.0;
  }

  void resetOffsets() {
    _horizontalOffset.value = 0.0;
    _verticalOffset.value = 0.0;
  }

  void updateDrawingWidth(Size size, double offsetX) {
    _drawingWidth = size.width - offsetX;
    // Reajustar offset al cambiar el tamaño
    setHorizontalOffset(_horizontalOffset.value);
  }

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

  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  void clearAndResume() {
    _dataPoints.value = []; // Clear existing data
    _isPaused.value = false; // Unpause
    _oscilloscopeChartService.resume();
  }

  void incrementTimeScale() {
    setTimeScale(timeScale * zoomFactor);
  }

  void decrementTimeScale() {
    setTimeScale(timeScale * unzoomFactor);
  }

  void incrementValueScale() {
    setValueScale(valueScale * zoomFactor);
  }

  void decrementValueScale() {
    setValueScale(valueScale * unzoomFactor);
  }

  void incrementHorizontalOffset() {
    final newOffset = horizontalOffset + 0.01;
    setHorizontalOffset(newOffset);
  }

  void decrementHorizontalOffset() {
    final newOffset = horizontalOffset - 0.01;
    setHorizontalOffset(newOffset);
  }

  void incrementVerticalOffset() {
    setVerticalOffset(verticalOffset + 0.1);
  }

  void decrementVerticalOffset() {
    setVerticalOffset(verticalOffset - 0.1);
  }

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

  void pause() {
    if (!_isPaused.value) {
      _isPaused.value = true;
      _oscilloscopeChartService.pause();
    }
  }

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

  @override
  void onClose() {
    _incrementTimer?.cancel();
    _dataSubscription?.cancel();
    _oscilloscopeChartService.dispose();
    super.onClose();
  }
}
