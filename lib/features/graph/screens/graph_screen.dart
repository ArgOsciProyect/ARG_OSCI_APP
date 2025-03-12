import 'package:arg_osci_app/config/app_theme.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/graph/widgets/user_settings.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [GraphScreen] is a Flutter [StatelessWidget] that displays the graph based on the selected mode (Oscilloscope or FFT).
/// It also includes user settings to adjust the graph's behavior.
class GraphScreen extends StatelessWidget {
  final String graphMode;
  final DataAcquisitionProvider graphProvider;
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final UserSettingsProvider userSettingsProvider;
  final TextEditingController triggerLevelController;

  const GraphScreen._({
    required this.graphMode,
    required this.graphProvider,
    required this.oscilloscopeChartProvider,
    required this.userSettingsProvider,
    required this.triggerLevelController,
    super.key,
  });

  /// Factory constructor that creates an instance of [GraphScreen] with dependencies injected using Get.
  factory GraphScreen({required String graphMode, Key? key}) {
    final graphProvider = Get.find<DataAcquisitionProvider>();
    final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
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
        // Llamar al autoset del OscilloscopeChartProvider
        oscilloscopeChartProvider.autoset(size.height, size.width);
      } else if (graphMode == 'Spectrum Analyzer') {
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
      oscilloscopeChartProvider: oscilloscopeChartProvider,
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
                  style: TextStyle(
                      fontSize: 15,
                      color: AppTheme.getAppBarTextColor(context)),
                ),
              )),
          leading: Transform.translate(
            offset: const Offset(0, -5),
            child: IconButton(
              icon: Icon(Icons.arrow_back,
                  size: 15, color: AppTheme.getIconColor(context)),
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
                  // Change this line to use the scaffold background color
                  color: Theme.of(context).scaffoldBackgroundColor,
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
                  oscilloscopeChartProvider: oscilloscopeChartProvider,
                  graphProvider: graphProvider,
                  triggerLevelController: triggerLevelController,
                ),
              ),
            ],
          ),
        ),
      );
}
