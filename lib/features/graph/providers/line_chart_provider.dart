// lib/features/graph/providers/line_chart_provider.dart
import 'dart:math';

import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import 'dart:async';

class LineChartProvider extends GetxController {
  final LineChartService _lineChartService;
  StreamSubscription? _dataSubscription;

  static const double zoomFactor = 1.02;
  static const double unzoomFactor = 0.98;
  Offset? _scaleStartFocalPoint; // Para detectar inicio de zoom

  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = RxDouble(1.0);
  final _valueScale = RxDouble(1.0);
  final _isPaused = false.obs;
  final _horizontalOffset = RxDouble(0.0);
  final _verticalOffset = RxDouble(0.0);
  double _initialTimeScale = 1.0;
  double _initialValueScale = 1.0;

  Timer? _incrementTimer;

  // Getters
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
  }

  void handleZoom(ScaleUpdateDetails details, Size constraints) {
    if (details.pointerCount == 2) {
      if (_scaleStartFocalPoint == null) {
        _scaleStartFocalPoint = details.focalPoint;
        return;
      }

      // Zoom proporcional a la amplitud del pinch
      final zoomFactor = pow(details.scale, 2.0);
      setTimeScale(_initialTimeScale * zoomFactor);
      setValueScale(_initialValueScale * zoomFactor);
    } else {
      _scaleStartFocalPoint = null;
    }
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
    final minX = _dataPoints.value.isEmpty ? 0 : _dataPoints.value.first.x;
    if ((minX + offset) * timeScale < 0) {
      _horizontalOffset.value = offset;
    }
  }

  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  void incrementTimeScale() {
    setTimeScale(timeScale * 1.02);
  }

  void decrementTimeScale() {
    setTimeScale(timeScale * 0.98);
  }

  void incrementValueScale() {
    setValueScale(valueScale * 1.02);
  }

  void decrementValueScale() {
    setValueScale(valueScale * 0.98);
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

  @override
  void onClose() {
    _incrementTimer?.cancel();
    _dataSubscription?.cancel();
    _lineChartService.dispose();
    super.onClose();
  }

  void pause() {
    _isPaused.value = true;
    _lineChartService.pause();
  }

  void resume() {
    _isPaused.value = false;
    _lineChartService.resume();
  }
}
