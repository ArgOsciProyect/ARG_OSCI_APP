// lib/features/graph/widgets/user_settings.dart
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/graph_mode_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/data_provider.dart';
import '../providers/line_chart_provider.dart';
import '../domain/models/trigger_data.dart';
import '../domain/models/filter_types.dart';
import '../domain/models/voltage_scale.dart';


class UserSettings extends StatelessWidget {
  final GraphProvider graphProvider;
  final LineChartProvider lineChartProvider;
  final TextEditingController triggerLevelController;
  final TextEditingController windowSizeController = TextEditingController();
  final TextEditingController alphaController = TextEditingController();
  final TextEditingController cutoffFrequencyController =
      TextEditingController();
  final FocusNode _triggerLevelFocus = FocusNode();
  final FocusNode _windowSizeFocus = FocusNode();
  final FocusNode _alphaFocus = FocusNode();
  final FocusNode _cutoffFrequencyFocus = FocusNode();
  static const _frequencyUpdateInterval = Duration(seconds: 2);

  UserSettings({
    required this.graphProvider,
    required this.lineChartProvider,
    required this.triggerLevelController,
    super.key,
  });

  Widget _buildScaleSelector() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Voltage Scale',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Obx(() => DropdownButton<VoltageScale>(
                value: graphProvider.currentVoltageScale.value,
                isExpanded: true,
                onChanged: (scale) {
                  if (scale != null) {
                    graphProvider.setVoltageScale(scale);
                  }
                },
                items: VoltageScales.values.map((scale) {
                  return DropdownMenuItem(
                    value: scale,
                    child: Text(scale.displayName),
                  );
                }).toList(),
              )),
        ],
      ),
    );
  }

  Widget _buildTriggerSettings() {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 16.0),
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Trigger Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Trigger Level:'),
          Obx(() {
            triggerLevelController.text =
                graphProvider.triggerLevel.value.toStringAsFixed(2);
            return TextField(
              controller: triggerLevelController,
              focusNode: _triggerLevelFocus,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                isDense: true,
                contentPadding:
                    EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              ),
              onSubmitted: (value) {
                _triggerLevelFocus.unfocus();
                final level = double.tryParse(value);
                if (level != null) {
                  graphProvider.setTriggerLevel(level);
                }
              },
            );
          }),
          const SizedBox(height: 12),
          const Text('Trigger Edge:'),
          Obx(() => DropdownButton<TriggerEdge>(
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
              )),
          const SizedBox(height: 12),
          const Text('Noise Reduction:'),
          Obx(() => DropdownButton<TriggerMode>(
                value: graphProvider.triggerMode.value,
                isExpanded: true,
                onChanged: (mode) {
                  if (mode != null) {
                    graphProvider.setTriggerMode(mode);
                  }
                },
                items: TriggerMode.values.map((mode) {
                  return DropdownMenuItem(
                    value: mode,
                    child: Text(mode == TriggerMode.hysteresis
                        ? 'Hysteresis'
                        : 'Low-Pass 50kHz'),
                  );
                }).toList(),
              )),
        ],
      ),
    );
  }

  Widget _buildFilterSettings() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(12.0),
      decoration: BoxDecoration(
        border: Border.all(color: Colors.grey),
        borderRadius: BorderRadius.circular(8.0),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text('Filter Settings',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          const Text('Filter Type:'),
          Obx(() => DropdownButton<FilterType>(
                value: graphProvider.currentFilter.value,
                isExpanded: true,
                onChanged: (filter) {
                  if (filter != null) {
                    graphProvider.setFilter(filter);
                  }
                },
                items: [
                  NoFilter(),
                  MovingAverageFilter(),
                  ExponentialFilter(),
                  LowPassFilter(),
                ]
                    .map((type) => DropdownMenuItem(
                          value: type,
                          child: Text(type.name),
                        ))
                    .toList(),
              )),
          const SizedBox(height: 8),
          Obx(() {
            final currentFilter = graphProvider.currentFilter.value;
            if (currentFilter is MovingAverageFilter) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Window Size:'),
                  Obx(() {
                    windowSizeController.text =
                        graphProvider.windowSize.value.toString();
                    return TextField(
                      controller: windowSizeController,
                      focusNode: _windowSizeFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        _windowSizeFocus.unfocus();
                        final size = int.tryParse(value);
                        if (size != null) {
                          graphProvider.setWindowSize(size);
                        }
                      },
                    );
                  }),
                ],
              );
            } else if (currentFilter is ExponentialFilter) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Alpha:'),
                  Obx(() {
                    alphaController.text = graphProvider.alpha.value.toString();
                    return TextField(
                      controller: alphaController,
                      focusNode: _alphaFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        _alphaFocus.unfocus();
                        final alpha = double.tryParse(value);
                        if (alpha != null) {
                          graphProvider.setAlpha(alpha);
                        }
                      },
                    );
                  }),
                ],
              );
            } else if (currentFilter is LowPassFilter) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Cutoff Frequency (Hz):'),
                  Obx(() {
                    cutoffFrequencyController.text =
                        graphProvider.cutoffFrequency.value.toString();
                    return TextField(
                      controller: cutoffFrequencyController,
                      focusNode: _cutoffFrequencyFocus,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        isDense: true,
                        contentPadding:
                            EdgeInsets.symmetric(horizontal: 8, vertical: 8),
                      ),
                      onSubmitted: (value) {
                        _cutoffFrequencyFocus.unfocus();
                        final freq = double.tryParse(value);
                        if (freq != null) {
                          graphProvider.setCutoffFrequency(freq);
                        }
                      },
                    );
                  }),
                ],
              );
            } else {
              return const SizedBox.shrink();
            }
          }),
        ],
      ),
    );
  }

Widget _buildInformationSection() {
  final modeProvider = Get.find<GraphModeProvider>();
  
  return Container(
    width: double.infinity,
    margin: const EdgeInsets.only(bottom: 16.0),
    padding: const EdgeInsets.all(12.0),
    decoration: BoxDecoration(
      border: Border.all(color: Colors.grey),
      borderRadius: BorderRadius.circular(8.0),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Information',
            style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
        const SizedBox(height: 12),
        Row(
          children: [
            const Text('Frequency Source:'),
            const SizedBox(width: 8),
            Obx(() => DropdownButton<FrequencySource>(
              value: modeProvider.frequencySource.value,
              onChanged: (source) {
                if (source != null) {
                  modeProvider.setFrequencySource(source);
                }
              },
              items: FrequencySource.values.map((source) {
                return DropdownMenuItem(
                  value: source,
                  child: Text(source == FrequencySource.timeDomain 
                    ? 'Time Domain' 
                    : 'FFT'),
                );
              }).toList(),
            )),
          ],
        ),
        const SizedBox(height: 8),
        const Text('Frequency:'),
        Obx(() => Text('${modeProvider.frequency.toStringAsFixed(2)} Hz')),
      ],
    ),
  );
}

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          _buildScaleSelector(),
          _buildTriggerSettings(),
          _buildInformationSection(), // Usar el nuevo método
          _buildFilterSettings(),
        ],
      ),
    );
  }
}
