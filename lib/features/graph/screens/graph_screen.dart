// lib/features/graph/screens/graph_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/providers/graph_provider.dart';
import '../../graph/domain/services/data_acquisition_service.dart';
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
    triggerLevelController = TextEditingController(text: graphProvider.dataAcquisitionService.triggerLevel.toString());

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
                    value: graphProvider.dataAcquisitionService.triggerMode,
                    onChanged: (TriggerMode? newValue) {
                      setState(() {
                        graphProvider.dataAcquisitionService.triggerMode = newValue!;
                      });
                    },
                    items: TriggerMode.values.map((TriggerMode mode) {
                      return DropdownMenuItem<TriggerMode>(
                        value: mode,
                        child: Text(mode.toString().split('.').last),
                      );
                    }).toList(),
                  ),
                  if (graphProvider.dataAcquisitionService.triggerMode == TriggerMode.manual) ...[
                    TextField(
                      controller: triggerLevelController,
                      decoration: InputDecoration(labelText: 'Trigger Level'),
                      keyboardType: TextInputType.number,
                      onChanged: (value) {
                        setState(() {
                          graphProvider.dataAcquisitionService.triggerLevel = double.parse(value) / graphProvider.dataAcquisitionService.scale;
                        });
                      },
                    ),
                    Row(
                      children: [
                        IconButton(
                          icon: Icon(Icons.add),
                          onPressed: () {
                            setState(() {
                              graphProvider.dataAcquisitionService.triggerLevel += 0.1 / graphProvider.dataAcquisitionService.scale;
                              triggerLevelController.text = (graphProvider.dataAcquisitionService.triggerLevel * graphProvider.dataAcquisitionService.scale).toStringAsFixed(2);
                            });
                          },
                        ),
                        IconButton(
                          icon: Icon(Icons.remove),
                          onPressed: () {
                            setState(() {
                              graphProvider.dataAcquisitionService.triggerLevel -= 0.1 / graphProvider.dataAcquisitionService.scale;
                              triggerLevelController.text = (graphProvider.dataAcquisitionService.triggerLevel * graphProvider.dataAcquisitionService.scale).toStringAsFixed(2);
                            });
                          },
                        ),
                      ],
                    ),
                  ],
                  DropdownButton<TriggerEdge>(
                    value: graphProvider.dataAcquisitionService.triggerEdge,
                    onChanged: (TriggerEdge? newValue) {
                      setState(() {
                        graphProvider.dataAcquisitionService.triggerEdge = newValue!;
                      });
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