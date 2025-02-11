import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/screens/graph_screen.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/oscilloscope_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

enum FrequencySource { timeDomain, fft }

/// [UserSettingsProvider] manages user preferences and settings related to the graph display.
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

  /// Starts a timer to periodically update the frequency value.
  void _startFrequencyUpdates() {
    _frequencyUpdateTimer?.cancel();
    _frequencyUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateFrequency(),
    );
  }

  /// Updates the frequency value based on the selected frequency source.
  void _updateFrequency() {
    frequency.value = frequencySource.value == FrequencySource.timeDomain
        ? Get.find<DataAcquisitionProvider>().frequency.value
        : Get.find<FFTChartProvider>().frequency.value;
  }

  /// Sets the frequency source (Time Domain or FFT).
  void setFrequencySource(FrequencySource source) {
    frequencySource.value = source;
    if (source == FrequencySource.fft) {
      fftChartService.resume();
    } else if (source == FrequencySource.timeDomain &&
        mode.value == 'Oscilloscope') {
      fftChartService.pause();
    }
  }

  /// Sets the graph mode (Oscilloscope or FFT).
  void setMode(String newMode) {
    mode.value = newMode;
    _updateServices();
    _updateTitle();
  }

  /// Updates the services based on the selected mode.
  void _updateServices() {
    if (mode.value == 'Oscilloscope') {
      fftChartService.pause();
      oscilloscopeService.resume();
    } else {
      oscilloscopeService.pause();
      fftChartService.resume();
    }
  }

  /// Updates the title of the graph screen.
  void _updateTitle() {
    title.value = 'Graph - ${mode.value} Mode';
  }

  /// Returns the current chart widget based on the selected mode.
  Widget getCurrentChart() {
    return mode.value == 'Oscilloscope' ? OsciloscopeChart() : FFTChart();
  }

  /// Navigates to the graph screen with the selected mode.
  void navigateToMode(String selectedMode) {
    Get.to(() => GraphScreen(graphMode: selectedMode));
  }

  @override
  void onClose() {
    _frequencyUpdateTimer?.cancel();
    super.onClose();
  }

  /// Returns whether to show trigger controls based on the selected mode.
  bool get showTriggerControls => mode.value == 'Oscilloscope';

  /// Returns whether to show timebase controls based on the selected mode.
  bool get showTimebaseControls => mode.value == 'Oscilloscope';

  /// Returns whether to show FFT controls based on the selected mode.
  bool get showFFTControls => mode.value == 'FFT';
}
