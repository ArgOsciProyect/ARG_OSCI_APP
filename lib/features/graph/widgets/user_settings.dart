// lib/features/graph/widgets/user_settings.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/data_provider.dart';
import '../providers/line_chart_provider.dart';
import '../domain/models/trigger_data.dart';
import '../domain/services/line_chart_service.dart'; 

class UserSettings extends StatelessWidget {
  final GraphProvider graphProvider;
  final LineChartProvider lineChartProvider;
  final TextEditingController triggerLevelController;

  const UserSettings({
    required this.graphProvider,
    required this.lineChartProvider,
    required this.triggerLevelController,
    super.key,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12.0, vertical: 8.0),
      color: Theme.of(context).scaffoldBackgroundColor,
      width: double.infinity,
      child: SingleChildScrollView(
        hitTestBehavior: HitTestBehavior.translucent,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Trigger Settings
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Trigger Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  const Text('Trigger Level:'),
                  Obx(() {
                    triggerLevelController.text = graphProvider.triggerLevel.value.toStringAsFixed(2);
                    return TextField(
                      controller: triggerLevelController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
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
                  const SizedBox(height: 12),
                  const Text('Trigger Edge:'),
                  Obx(() {
                    return DropdownButton<TriggerEdge>(
                      value: graphProvider.triggerEdge.value,
                      isExpanded: true,
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

            // Information
            Container(
              width: double.infinity,
              margin: const EdgeInsets.only(bottom: 16.0),
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Information',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  const Text('Frequency:'),
                  Obx(() {
                    return Text('${graphProvider.frequency.value.toStringAsFixed(2)} Hz');
                  }),
                ],
              ),
            ),

            // Filter Settings
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12.0),
              decoration: BoxDecoration(
                border: Border.all(color: Colors.grey),
                borderRadius: BorderRadius.circular(8.0),
                color: Theme.of(context).scaffoldBackgroundColor,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Filter Settings',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)
                  ),
                  const SizedBox(height: 12),
                  const Text('Filter Type:'),
                  Obx(() => DropdownButton<FilterType>(
                    value: lineChartProvider.currentFilter.value,
                    isExpanded: true,
                    onChanged: (filter) {
                      if (filter != null) {
                        lineChartProvider.setFilter(filter);
                      }
                    },
                    items: FilterType.values.map((type) => DropdownMenuItem(
                      value: type,
                      child: Text(type.toString().split('.').last),
                    )).toList(),
                  )),
                  const SizedBox(height: 8),
                  Obx(() {
                    final currentFilter = lineChartProvider.currentFilter.value;
                    switch (currentFilter) {
                      case FilterType.movingAverage:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Window Size:'),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onSubmitted: (value) {
                                final size = int.tryParse(value);
                                if (size != null) {
                                  lineChartProvider.setWindowSize(size);
                                }
                              },
                            ),
                          ],
                        );
                      
                      case FilterType.exponential:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Alpha:'),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onSubmitted: (value) {
                                final alpha = double.tryParse(value);
                                if (alpha != null) {
                                  lineChartProvider.setAlpha(alpha);
                                }
                              },
                            ),
                          ],
                        );
                      
                      case FilterType.lowPass:
                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text('Cutoff Frequency (Hz):'),
                            TextField(
                              keyboardType: TextInputType.number,
                              decoration: const InputDecoration(
                                isDense: true,
                                contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                              ),
                              onSubmitted: (value) {
                                final freq = double.tryParse(value);
                                if (freq != null) {
                                  lineChartProvider.setCutoffFrequency(freq);
                                }
                              },
                            ),
                          ],
                        );
                      
                      default:
                        return const SizedBox.shrink();
                    }
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