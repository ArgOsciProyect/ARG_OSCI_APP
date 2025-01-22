// lib/features/graph/providers/line_chart_provider.dart
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/models/data_point.dart';
import 'dart:async';

class LineChartProvider extends GetxController {
  final LineChartService _lineChartService;
  StreamSubscription? _dataSubscription;

  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = RxDouble(1.0);
  final _valueScale = RxDouble(1.0);
  final _isPaused = false.obs;

  // Getters
  List<DataPoint> get dataPoints => _dataPoints.value;
  double get timeScale => _timeScale.value;
  double get valueScale => _valueScale.value;
  bool get isPaused => _isPaused.value;
  
  LineChartProvider(this._lineChartService) {
    _dataSubscription = _lineChartService.dataStream.listen((points) {
      _dataPoints.value = points;
    });
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

  void resetScales() {
    _timeScale.value = 1.0;
    _valueScale.value = 1.0;
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
    _dataSubscription?.cancel();
    _lineChartService.dispose();
    super.onClose();
  }
}