import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/line_chart_service.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/line_chart.dart';
import 'package:flutter/material.dart';

/// Base class defining display modes for the oscilloscope
abstract class GraphMode {
  /// Short name identifier for this mode
  String get name;

  /// Display title shown in the UI
  String get title;

  /// Builds the chart widget for this mode
  Widget buildChart();

  /// Whether to show trigger control panel
  bool get showTriggerControls;

  /// Whether to show timebase control panel
  bool get showTimebaseControls;

  /// Whether to show mode-specific controls
  bool get showCustomControls;

  /// Called when switching to this mode
  void onActivate();

  /// Called when switching away from this mode
  void onDeactivate();
}

/// Time domain oscilloscope display mode
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

/// Frequency domain FFT display mode
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
