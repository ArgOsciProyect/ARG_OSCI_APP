import 'dart:math';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import 'dart:async';

class LineChartProvider extends GetxController {
  final LineChartService _lineChartService;
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

  LineChartProvider(this._lineChartService) {
    _dataSubscription = _lineChartService.dataStream.listen((points) {
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
      setTimeScale(_initialTimeScale * newZoomFactor);
      setValueScale(_initialValueScale * newZoomFactor);

      final newFocalScreenX =
          domainToScreenX(focalDomainX, constraints, offsetX);
      final newFocalScreenY =
          domainToScreenY(focalDomainY, constraints, offsetX);

      _horizontalOffset.value +=
          (newFocalScreenX - details.focalPoint.dx) / constraints.width;
      _verticalOffset.value -=
          (newFocalScreenY - details.focalPoint.dy) / constraints.height;
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
    _lineChartService.resumeAndWaitForTrigger();
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
    if (scale > 0) {
      _timeScale.value = scale;
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
  }

  void setHorizontalOffset(double offset) {
    if (_drawingWidth <= 0) return;

    // Calculate maximum offset based on data points
    final maxDataX = dataPoints.isEmpty ? 0.0 : dataPoints.last.x;
    final visibleWidth = maxDataX * timeScale;
    final maxOffset =
        -visibleWidth / _drawingWidth; // Negative because we move left

    if (graphProvider.triggerMode.value == TriggerMode.normal) {
      // In normal mode, prevent moving left of 0 and right of maxOffset
      _horizontalOffset.value = offset.clamp(maxOffset, 0.0);
    } else {
      // In single mode, allow full range movement but limit right edge
      _horizontalOffset.value = offset.clamp(maxOffset, double.infinity);
    }
  }

  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  void clearAndResume() {
    _dataPoints.value = []; // Clear existing data
    _isPaused.value = false; // Unpause
    _lineChartService.resume();
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
      _lineChartService.pause();
    }
  }

  void resume() {
    if (_isPaused.value) {
      _isPaused.value = false;
      _lineChartService.resume();

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
    _lineChartService.dispose();
    super.onClose();
  }
}
