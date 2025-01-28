/// line_chart_provider.dart
import 'dart:math';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import 'dart:async';

class LineChartProvider extends GetxController {
  final LineChartService _lineChartService;
  StreamSubscription? _dataSubscription;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();

  static const double zoomFactor = 1.02;
  static const double unzoomFactor = 0.98;
  Offset? _scaleStartFocalPoint;

  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = RxDouble(1.0);
  final _valueScale = RxDouble(1.0);
  final _isPaused = false.obs;
  final _horizontalOffset = RxDouble(0.0);
  final _verticalOffset = RxDouble(0.0);
  double _initialTimeScale = 1.0;
  double _initialValueScale = 1.0;
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

  void handleZoom(ScaleUpdateDetails details, Size constraints, double offsetX) {
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
    return (domainX * timeScale) +
        (horizontalOffset * drawingWidth) +
        offsetX;
  }

  double screenToDomainY(double screenY, Size size, double offsetX) {
    final drawingHeight = size.height;
    return -((screenY - drawingHeight / 2) / (drawingHeight / 2)) /
            valueScale -
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

  void setHorizontalOffset(double offset) {
    _horizontalOffset.value = min(0.0, offset); // Prevent moving left of 0
  }

  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
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
    _isPaused.value = true;
    _lineChartService.pause();
  }

  void resume() {
    _isPaused.value = false;
    _lineChartService.resume();
  }

  @override
  void onClose() {
    _incrementTimer?.cancel();
    _dataSubscription?.cancel();
    _lineChartService.dispose();
    super.onClose();
  }
}