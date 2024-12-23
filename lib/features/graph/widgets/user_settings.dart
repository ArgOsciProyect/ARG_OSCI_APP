// lib/features/graph/widgets/user_settings.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/providers/graph_provider.dart';
import '../domain/models/trigger_data.dart';

class UserSettings extends StatelessWidget {
  final GraphProvider graphProvider;
  final TextEditingController triggerLevelController;

  const UserSettings({
    required this.graphProvider,
    required this.triggerLevelController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8.0),
      color: Theme.of(context).scaffoldBackgroundColor, // Fondo uniforme para los UserSettings
      child: SingleChildScrollView(
        hitTestBehavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
              Container(
                padding: const EdgeInsets.all(8.0),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.grey),
                  borderRadius: BorderRadius.circular(8.0),
                  color: Theme.of(context).scaffoldBackgroundColor, // Fondo uniforme para el contenedor interno
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Trigger Settings', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                    SizedBox(height: 10),
                    Text('Trigger Level:'),
                    Obx(() {
                      // Actualizar el controlador de texto cuando el valor de triggerLevel cambie
                    triggerLevelController.text = graphProvider.triggerLevel.value.toStringAsFixed(2);
                      return TextField(
                        controller: triggerLevelController,
                        keyboardType: TextInputType.number,
                        onSubmitted: (value) {
                          final level = double.tryParse(value);
                          if (level != null) {
                          graphProvider.setTriggerLevel(level);
                          }
                        },
                        onChanged: (value) {
                          final level = double.tryParse(value);
                          if (level != null) {
                          graphProvider.setTriggerLevel(level);
                          }
                        },
                      );
                    }),
                    SizedBox(height: 10),
                    Text('Trigger Edge:'),
                    Obx(() {
                      return DropdownButton<TriggerEdge>(
                      value: graphProvider.triggerEdge.value,
                        onChanged: (edge) {
                          if (edge != null) {
                          graphProvider.setTriggerEdge(edge);
                          }
                        },
                        items: TriggerEdge.values.map((edge) {
                          return DropdownMenuItem(
                            value: edge,
                            child: Text(edge.toString().split('.').last),
                          );
                        }).toList(),
                      );
                    }),
                  ],
                ),
              ),
              SizedBox(height: 20),
            Container(
              padding: const EdgeInsets.all(8.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Information', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  SizedBox(height: 10),
                  Text('Frequency:'),
                  Obx(() {
                    return Text('${graphProvider.frequency.value.toStringAsFixed(2)} Hz');
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}