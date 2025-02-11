import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/line_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/screens/graph_screen.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/oscilloscope_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum FrequencySource { timeDomain, fft }

class UserSettingsProvider extends GetxController {
  final OscilloscopeChartService oscilloscopeService;
  final FFTChartService fftChartService;
  final mode = RxString('');
  final title = RxString('');
  final frequencySource = FrequencySource.timeDomain.obs;
  final frequency = 0.0.obs;

  Timer? _frequencyUpdateTimer;

  final availableModes = <String>['Oscilloscope', 'FFT'];

  UserSettingsProvider({
    required this.oscilloscopeService,
    required this.fftChartService,
  }) {
    _startFrequencyUpdates();
  }

  void _startFrequencyUpdates() {
    _frequencyUpdateTimer?.cancel();
    _frequencyUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateFrequency(),
    );
  }

  void _updateFrequency() {
    frequency.value = frequencySource.value == FrequencySource.timeDomain
        ? Get.find<DataAcquisitionProvider>().frequency.value
        : Get.find<FFTChartProvider>().frequency.value;
  }

  void setFrequencySource(FrequencySource source) {
    frequencySource.value = source;
    if (source == FrequencySource.fft) {
      fftChartService.resume();
    } else if (source == FrequencySource.timeDomain &&
        mode.value == 'Oscilloscope') {
      fftChartService.pause();
    }
  }

  void setMode(String newMode) {
    mode.value = newMode;
    _updateServices();
    _updateTitle();
  }

  void _updateServices() {
    if (mode.value == 'Oscilloscope') {
      fftChartService.pause();
      oscilloscopeService.resume();
    } else {
      oscilloscopeService.pause();
      fftChartService.resume();
    }
  }

  void _updateTitle() {
    title.value = 'Graph - ${mode.value} Mode';
  }

  Widget getCurrentChart() {
    return mode.value == 'Oscilloscope' ? OsciloscopeChart() : FFTChart();
  }

  void navigateToMode(String selectedMode) {
    Get.to(() => GraphScreen(graphMode: selectedMode));
  }

  @override
  void onClose() {
    _frequencyUpdateTimer?.cancel();
    super.onClose();
  }

  bool get showTriggerControls => mode.value == 'Oscilloscope';
  bool get showTimebaseControls => mode.value == 'Oscilloscope';
  bool get showFFTControls => mode.value == 'FFT';
}
