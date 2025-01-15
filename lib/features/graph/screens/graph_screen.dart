// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/data_provider.dart';
import '../widgets/user_settings.dart';
import '../providers/line_chart_provider.dart';
import '../providers/graph_mode_provider.dart';

class GraphScreen extends StatelessWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final graphProvider = Get.find<GraphProvider>();
    final triggerLevelController = TextEditingController(
        text: graphProvider.triggerLevel.value.toString());
    final lineChartProvider = Get.find<LineChartProvider>();
    final modeProvider = Get.find<GraphModeProvider>();

    modeProvider.setMode(mode);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        title: Obx(() => FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                modeProvider.title.value,
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
                    return modeProvider.getCurrentChart();
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
}
