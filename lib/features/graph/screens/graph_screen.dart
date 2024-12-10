// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/providers/graph_provider.dart';
import '../widgets/line_chart.dart';
import '../widgets/trigger_settings.dart';

class GraphScreen extends StatelessWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final GraphProvider graphProvider = Get.find<GraphProvider>();
    final TextEditingController triggerLevelController = TextEditingController(text: graphProvider.triggerLevel.value.toString());

    if (mode == 'Oscilloscope') {
      // Iniciar la adquisición de datos en modo Oscilloscope
      graphProvider.fetchData();
    }

    return Scaffold(
      appBar: AppBar(title: Text('Graph - $mode Mode')),
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: Obx(() {
                if (graphProvider.dataPoints.isNotEmpty) {
                  return LineChart(dataPoints: graphProvider.dataPoints);
                } else {
                  return Center(child: CircularProgressIndicator());
                }
              }),
            ),
          ),
          TriggerSettings(graphProvider: graphProvider, triggerLevelController: triggerLevelController),
        ],
      ),
    );
  }
}