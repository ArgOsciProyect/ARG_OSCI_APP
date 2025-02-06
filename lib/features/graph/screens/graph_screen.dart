// lib/features/graph/screens/graph_screen.dart
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/data_acquisition_provider.dart';
import '../widgets/user_settings.dart';
import '../providers/line_chart_provider.dart';
import '../providers/user_settings_provider.dart';

class GraphScreen extends StatelessWidget {
  final String graphMode;
  final DataAcquisitionProvider graphProvider;
  final LineChartProvider lineChartProvider;
  final UserSettingsProvider userSettingsProvider;
  final TextEditingController triggerLevelController;

  const GraphScreen._({
    required this.graphMode,
    required this.graphProvider,
    required this.lineChartProvider,
    required this.userSettingsProvider,
    required this.triggerLevelController,
    super.key,
  });

  factory GraphScreen({required String graphMode, Key? key}) {
    final graphProvider = Get.find<DataAcquisitionProvider>();
    final lineChartProvider = Get.find<LineChartProvider>();
    final userSettingsProvider = Get.find<UserSettingsProvider>();
    final controller = TextEditingController(
        text: graphProvider.triggerLevel.value.toString());

    // Register controller for disposal
    Get.put(controller, tag: 'trigger_level_controller');

    userSettingsProvider.setMode(graphMode);

    // Ejecutar autoset después de la inicialización según el modo
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (graphMode == 'Oscilloscope') {
        final size = Get.size;
        graphProvider.autoset(size.height, size.width);
        lineChartProvider.resetOffsets();
      } else if (graphMode == 'FFT') {
        final size = Get.size;
        final fftProvider = Get.find<FFTChartProvider>();
        final frequency = fftProvider.frequency.value > 0 
            ? fftProvider.frequency.value 
            : graphProvider.frequency.value;
        fftProvider.autoset(size, frequency);
      }
    });

    return GraphScreen._(
      graphMode: graphMode,
      graphProvider: graphProvider,
      lineChartProvider: lineChartProvider,
      userSettingsProvider: userSettingsProvider,
      triggerLevelController: controller,
      key: key,
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          title: Obx(() => FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(
                  userSettingsProvider.title.value,
                  style: const TextStyle(fontSize: 15, color: Colors.black),
                ),
              )),
          leading: Transform.translate(
            offset: const Offset(0, -5),
            child: IconButton(
              icon: const Icon(Icons.arrow_back, size: 15, color: Colors.black),
              onPressed: () => Get.back(),
            ),
          ),
          toolbarHeight: 25.0,
        ),
        body: Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            children: [
              Expanded(
                child: Container(
                  color: Colors.white,
                  child: Center(
                    child: Obx(() {
                      final points = graphProvider.dataPoints.value;
                      if (points.isEmpty) {
                        return const CircularProgressIndicator();
                      }
                      return userSettingsProvider.getCurrentChart();
                    }),
                  ),
                ),
              ),
              const SizedBox(width: 20),
              Container(
                width: 170,
                color: Theme.of(context).scaffoldBackgroundColor,
                child: UserSettings(
                  lineChartProvider: lineChartProvider,
                  graphProvider: graphProvider,
                  triggerLevelController: triggerLevelController,
                ),
              ),
            ],
          ),
        ),
      );
}
