import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/graph_mode.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/screens/graph_screen.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/oscilloscope_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// Defines the source for frequency measurements used in the application.
enum FrequencySource {
  /// Measure frequency from time-domain signal
  timeDomain,
  
  /// Measure frequency from FFT spectrum analysis
  fft
}

/// [UserSettingsProvider] manages user preferences and settings related to the graph display.
///
/// Controls the display mode (oscilloscope or spectrum analyzer), handles mode switching,
/// manages frequency measurement sources, and provides appropriate UI components.
class UserSettingsProvider extends GetxController {
  final OscilloscopeChartService oscilloscopeService;
  final FFTChartService fftChartService;
  final mode = RxString('');
  final title = RxString('');
  final frequencySource = FrequencySource.timeDomain.obs;
  final frequency = 0.0.obs;

  Timer? _frequencyUpdateTimer;

  // Mode instances for reference
  late final OscilloscopeMode _oscilloscopeMode;
  late final FFTMode _fftMode;

  // Create static constants for mode names to use in availableModes
  static const String osciloscopeMode = 'Oscilloscope';
  static const String spectrumAnalizerMode = 'Spectrum Analyzer';

  // Use the constant mode names
  final availableModes = <String>[osciloscopeMode, spectrumAnalizerMode];

  UserSettingsProvider({
    required this.oscilloscopeService,
    required this.fftChartService,
  }) {
    // Initialize mode instances with services
    _oscilloscopeMode = OscilloscopeMode(oscilloscopeService);
    _fftMode = FFTMode(fftChartService);

    // Set default mode name - use the constant
    mode.value = osciloscopeMode;
    _updateTitle();

    _startFrequencyUpdates();
  }

  /// Starts a timer to periodically update the frequency value.
  ///
  /// Sets up a recurring timer that updates the displayed frequency value
  /// every 2 seconds based on the selected frequency source.
  void _startFrequencyUpdates() {
    _frequencyUpdateTimer?.cancel();
    _frequencyUpdateTimer = Timer.periodic(
      const Duration(seconds: 2),
      (_) => _updateFrequency(),
    );
  }

  /// Updates the frequency value based on the selected frequency source.
  ///
  /// Retrieves the current frequency value either from time-domain measurements
  /// or FFT analysis depending on the selected frequency source.
  void _updateFrequency() {
    frequency.value = frequencySource.value == FrequencySource.timeDomain
        ? Get.find<DataAcquisitionProvider>().frequency.value
        : Get.find<FFTChartProvider>().frequency.value;
  }

  /// Sets the frequency source (Time Domain or FFT).
  ///
  /// Updates the source used for frequency measurements and manages
  /// the FFT chart service state based on the selected source.
  ///
  /// [source] The frequency source to use
  void setFrequencySource(FrequencySource source) {
    frequencySource.value = source;
    if (source == FrequencySource.fft) {
      fftChartService.resume();
    } else if (source == FrequencySource.timeDomain &&
        mode.value == osciloscopeMode) {
      fftChartService.pause();
    }
  }

  /// Sets the graph mode (Oscilloscope or FFT).
  ///
  /// Changes the active display mode, updates related services,
  /// and refreshes the display title.
  ///
  /// [newMode] The display mode to activate
  void setMode(String newMode) {
    mode.value = newMode;
    _updateServices();
    _updateTitle();
  }

  /// Updates the services based on the selected mode.
  ///
  /// Activates the appropriate chart service (oscilloscope or FFT)
  /// and pauses the inactive service to conserve resources.
  void _updateServices() {
    if (mode.value == osciloscopeMode) {
      fftChartService.pause();
      oscilloscopeService.resume();
    } else {
      oscilloscopeService.pause();
      fftChartService.resume();
    }
  }

  /// Updates the title of the graph screen.
  ///
  /// Sets the display title according to the active mode.
  void _updateTitle() {
    if (mode.value == osciloscopeMode) {
      title.value = _oscilloscopeMode.title;
    } else {
      title.value = _fftMode.title;
    }
  }

  /// Returns the current chart widget based on the selected mode.
  ///
  /// Creates and returns either an oscilloscope chart or FFT chart
  /// widget depending on the active display mode.
  ///
  /// Returns the appropriate chart widget for the current mode
  Widget getCurrentChart() {
    return mode.value == osciloscopeMode ? OsciloscopeChart() : FFTChart();
  }

  /// Navigates to the graph screen with the selected mode.
  ///
  /// Performs navigation to the graph screen and passes the selected mode.
  ///
  /// [selectedMode] The display mode to show in the graph screen
  void navigateToMode(String selectedMode) {
    Get.to(() => GraphScreen(graphMode: selectedMode));
  }

  @override
  void onClose() {
    _frequencyUpdateTimer?.cancel();
    super.onClose();
  }

  /// Finds a matching voltage scale in a list of available scales.
  ///
  /// Attempts to find an exact match by comparing display name and base range.
  /// If no match is found, returns the first available scale or the current scale.
  ///
  /// [currentScale] The scale to find a match for
  /// [availableScales] List of available voltage scales to search in
  /// Returns the matching scale or a fallback
  VoltageScale findMatchingScale(
      VoltageScale currentScale, List<VoltageScale> availableScales) {
    // Try to find exact match
    for (var scale in availableScales) {
      if (scale.displayName == currentScale.displayName &&
          scale.baseRange == currentScale.baseRange) {
        return scale;
      }
    }

    // If no match found, return first available scale
    return availableScales.isNotEmpty ? availableScales.first : currentScale;
  }

  /// Returns whether to show trigger controls based on the selected mode.
  bool get showTriggerControls => mode.value == osciloscopeMode
      ? _oscilloscopeMode.showTriggerControls
      : _fftMode.showTriggerControls;

  /// Returns whether to show timebase controls based on the selected mode.
  bool get showTimebaseControls => mode.value == osciloscopeMode
      ? _oscilloscopeMode.showTimebaseControls
      : _fftMode.showTimebaseControls;

  /// Returns whether to show FFT controls based on the selected mode.
  bool get showFFTControls => mode.value == osciloscopeMode
      ? _oscilloscopeMode.showCustomControls
      : _fftMode.showCustomControls;
}