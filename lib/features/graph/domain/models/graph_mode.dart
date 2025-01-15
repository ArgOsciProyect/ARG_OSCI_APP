// lib/features/graph/domain/models/graph_mode.dart
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/line_chart_service.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/line_chart.dart';
import 'package:flutter/material.dart';

abstract class GraphMode {
  String get name;
  String get title;
  Widget buildChart();
  bool get showTriggerControls;
  bool get showTimebaseControls;
  bool get showCustomControls;
  void onActivate();
  void onDeactivate();
}

class OscilloscopeMode extends GraphMode {
  final LineChartService lineChartService;

  OscilloscopeMode(this.lineChartService);

  @override
  String get name => 'Oscilloscope';

  @override
  String get title => 'Graph - Oscilloscope Mode';

  @override
  Widget buildChart() => LineChart();

  @override
  bool get showTriggerControls => true;

  @override
  bool get showTimebaseControls => true;

  @override
  bool get showCustomControls => false;

  @override
  void onActivate() => lineChartService.resume();

  @override
  void onDeactivate() => lineChartService.pause();
}

class FFTMode extends GraphMode {
  final FFTChartService fftChartService;

  FFTMode(this.fftChartService);

  @override
  String get name => 'FFT';

  @override
  String get title => 'Graph - FFT Mode';

  @override
  Widget buildChart() => FFTChart();

  @override
  bool get showTriggerControls => false;

  @override
  bool get showTimebaseControls => false;

  @override
  bool get showCustomControls => true;

  @override
  void onActivate() => fftChartService.resume();

  @override
  void onDeactivate() => fftChartService.pause();
}
