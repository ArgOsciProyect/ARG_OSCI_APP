// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/graph_provider.dart';
import '../widgets/line_chart.dart';
import '../widgets/fft_chart.dart';
import '../widgets/user_settings.dart';

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
    } else {
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
            child: Container(
              color: Colors.white, // Fondo para el gráfico
              child: Center(
                child: Obx(() {
                  final points = graphProvider.dataPoints.value;
                  if (points.isEmpty) {
                    return const CircularProgressIndicator();
                  } else {
                    return mode == 'Oscilloscope'
                        ? LineChart(dataPoints: points)
                        : FFTChart(dataPoints: points);
                  }
                }),
              ),
            ),
          ),
          Container(
            width: 200,
            color: Colors.grey[200], // Fondo para las opciones
            child: UserSettings(
              graphProvider: graphProvider,
              triggerLevelController: triggerLevelController,
            ),
          ),
        ],
      ),
    );
  }
}