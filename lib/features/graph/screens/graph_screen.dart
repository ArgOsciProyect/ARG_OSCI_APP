// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/graph_provider.dart';
import '../widgets/line_chart.dart';
import '../widgets/trigger_settings.dart';

class GraphScreen extends StatelessWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  Widget build(BuildContext context) {
    final graphProvider = Get.find<GraphProvider>();
    final triggerLevelController = TextEditingController(
      text: graphProvider.triggerLevel.value.toString()
    );

    if (mode == 'Oscilloscope') {
      graphProvider.fetchData();
    }

    return Scaffold(
      appBar: AppBar(
        title: Text('Graph - $mode Mode'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: () {
            graphProvider.stopData(); // Stop data acquisition when navigating back
            Get.back();
          },
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: Center(
              child: Obx(() {
                final points = graphProvider.dataPoints.value;
                return points.isEmpty
                    ? const CircularProgressIndicator()
                    : LineChart(dataPoints: points);
              }),
            ),
          ),
          TriggerSettings(
            graphProvider: graphProvider,
            triggerLevelController: triggerLevelController
          ),
        ],
      ),
    );
  }
}