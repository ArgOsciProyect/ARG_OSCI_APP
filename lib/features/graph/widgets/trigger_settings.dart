// lib/features/graph/widgets/trigger_settings.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/providers/graph_provider.dart';
import '../domain/models/trigger_data.dart';

class TriggerSettings extends StatelessWidget {
  final GraphProvider graphProvider;
  final TextEditingController triggerLevelController;
  
  const TriggerSettings({required this.graphProvider, required this.triggerLevelController, super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 300,
      color: Colors.grey[200],
      child: Padding(
        padding: const EdgeInsets.all(8.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Trigger Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            SizedBox(height: 10),
            Obx(() {
              return DropdownButton<TriggerMode>(
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
              );
            }),
            Obx(() {
              if (graphProvider.triggerMode.value == TriggerMode.manual) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
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
                );
              } else {
                return SizedBox.shrink();
              }
            }),
            Obx(() {
              return DropdownButton<TriggerEdge>(
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
              );
            }),
          ],
        ),
      ),
    );
  }
}