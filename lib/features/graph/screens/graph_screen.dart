// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/providers/graph_provider.dart';
import '../../graph/domain/services/data_acquisition_service.dart'; // Importar TriggerEdge y TriggerMode
import '../widgets/line_chart.dart';

class GraphScreen extends StatefulWidget {
  final String mode;

  const GraphScreen({required this.mode, super.key});

  @override
  _GraphScreenState createState() => _GraphScreenState();
}

class _GraphScreenState extends State<GraphScreen> {
  late GraphProvider graphProvider;
  late TextEditingController triggerLevelController;

  @override
  void initState() {
    super.initState();
    graphProvider = Get.find<GraphProvider>();
    triggerLevelController = TextEditingController(text: graphProvider.triggerLevel.value.toString());

    if (widget.mode == 'Oscilloscope') {
      // Iniciar la adquisición de datos en modo Oscilloscope
      graphProvider.fetchData();
    }
  }

  @override
  void dispose() {
    // Detener la adquisición de datos cuando se sale de la pantalla
    graphProvider.stopData();
    triggerLevelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Graph - ${widget.mode} Mode')),
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
          Container(
            width: 300,
            color: Colors.grey[200],
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Trigger Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  DropdownButton<TriggerMode>(
                    value: graphProvider.triggerMode.value,
                    onChanged: (TriggerMode? newValue) {
                      if (newValue != null) {
                        graphProvider.setTriggerMode(newValue);
                      }
                    },
                    items: TriggerMode.values.map((TriggerMode mode) {
                      return DropdownMenuItem<TriggerMode>(
                        value: mode,
                        child: Text(mode.toString().split('.').last),
                      );
                    }).toList(),
                  ),
                  if (graphProvider.triggerMode.value == TriggerMode.manual) ...[
                    TextField(
                      controller: triggerLevelController,
                      decoration: InputDecoration(labelText: 'Trigger Level'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        graphProvider.setTriggerLevel(double.parse(value));
                      },
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            graphProvider.setTriggerLevel(graphProvider.triggerLevel.value + 0.1);
                            triggerLevelController.text = graphProvider.triggerLevel.value.toStringAsFixed(2);
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            graphProvider.setTriggerLevel(graphProvider.triggerLevel.value - 0.1);
                            triggerLevelController.text = graphProvider.triggerLevel.value.toStringAsFixed(2);
                          },
                        ),
                      ],
                    ),
                  ],
                  DropdownButton<TriggerEdge>(
                    value: graphProvider.triggerEdge.value,
                    onChanged: (TriggerEdge? newValue) {
                      if (newValue != null) {
                        graphProvider.setTriggerEdge(newValue);
                      }
                    },
                    items: TriggerEdge.values.map((TriggerEdge edge) {
                      return DropdownMenuItem<TriggerEdge>(
                        value: edge,
                        child: Text(edge.toString().split('.').last),
                      );
                    }).toList(),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}