// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/data_provider.dart';
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
    
    graphProvider.fetchData();

    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor, // Fondo uniforme para el AppBar
        title: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text('Graph - $mode Mode', style: TextStyle(fontSize: 15, color: Colors.black, textBaseline: TextBaseline.ideographic),),
        ),
        leading: Transform.translate(
          offset: Offset(0, -5), // Subir la flecha unos píxeles hacia arriba
          child: IconButton(
            icon: Icon(Icons.arrow_back, size: 15, color: Colors.black, applyTextScaling: true,), // Ajustar el tamaño del icono y color
            onPressed: () {
              graphProvider.stopData(); // Stop data acquisition when navigating back
              Get.back();
            },
          ),
        ),
        toolbarHeight: 25.0, // Ajustar la altura del AppBar
      ),
      body: Container(
        color: Theme.of(context).scaffoldBackgroundColor, // Fondo uniforme para todo el cuerpo
        child: Row(
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
                          ? LineChart()
                          : FFTChart();
                    }
                  }),
                ),
              ),
            ),
            SizedBox(width: 20), // Espacio entre el graficador y UserSettings
            Container(
              width: 170, // Ajustar el ancho del UserSettings
              color: Theme.of(context).scaffoldBackgroundColor, // Fondo uniforme para las opciones
              child: UserSettings(
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