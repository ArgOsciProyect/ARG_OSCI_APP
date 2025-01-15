// lib/features/graph/providers/graph_mode_provider.dart
import 'package:arg_osci_app/features/graph/screens/graph_screen.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/widgets/line_chart.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../domain/services/line_chart_service.dart';
import '../domain/services/fft_chart_service.dart';

// lib/features/graph/providers/graph_mode_provider.dart
class GraphModeProvider extends GetxController {
  final LineChartService lineChartService;
  final FFTChartService fftChartService;
  final mode = RxString('');
  final title = RxString('');

  // Agregar lista de modos disponibles
  final availableModes = <String>['Oscilloscope', 'FFT'];

  GraphModeProvider({
    required this.lineChartService,
    required this.fftChartService,
  });

  void setMode(String newMode) {
    mode.value = newMode;
    _updateServices();
    _updateTitle();
  }

  void _updateServices() {
    if (mode.value == 'Oscilloscope') {
      fftChartService.pause();
      lineChartService.resume();
    } else {
      lineChartService.pause();
      fftChartService.resume();
    }
  }

  void _updateTitle() {
    title.value = 'Graph - ${mode.value} Mode';
  }

  Widget getCurrentChart() {
    return mode.value == 'Oscilloscope' ? LineChart() : FFTChart();
  }

  // Método para navegar al modo seleccionado
  void navigateToMode(String selectedMode) {
    Get.to(() => GraphScreen(mode: selectedMode));
  }

  bool get showTriggerControls => mode.value == 'Oscilloscope';
  bool get showTimebaseControls => mode.value == 'Oscilloscope';
  bool get showFFTControls => mode.value == 'FFT';
}
