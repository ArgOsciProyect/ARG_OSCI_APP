import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [UserSettings] is a Flutter [StatelessWidget] that provides a user interface for adjusting various settings
/// related to data acquisition and display, such as voltage scale, trigger settings, filter settings, and information display.
class UserSettings extends StatelessWidget {
  final DataAcquisitionProvider graphProvider;
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final TextEditingController triggerLevelController;
  final TextEditingController windowSizeController = TextEditingController();
  final TextEditingController alphaController = TextEditingController();
  final TextEditingController cutoffFrequencyController =
      TextEditingController();
  final FocusNode _triggerLevelFocus = FocusNode();
  final FocusNode _windowSizeFocus = FocusNode();
  final FocusNode _alphaFocus = FocusNode();
  final FocusNode _cutoffFrequencyFocus = FocusNode();

  UserSettings({
    required this.graphProvider,
    required this.oscilloscopeChartProvider,
    required this.triggerLevelController,
    super.key,
  });

  /// Builds the voltage scale selector dropdown.
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
          // Dropdown to select the voltage scale. Updates the graphProvider's currentVoltageScale.
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

  /// Builds the trigger settings section.
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
          // Add Trigger Mode selector first
          const Text('Trigger Mode:'),
          // Dropdown to select the trigger mode. Updates the graphProvider's triggerMode.
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
                    child: Text(mode.toString().split('.').last),
                  );
                }).toList(),
              )),
          const SizedBox(height: 12),
          const Text('Trigger Level:'),
          // TextField to set the trigger level. Updates the graphProvider's triggerLevel.
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
          // Dropdown to select the trigger edge. Updates the graphProvider's triggerEdge.
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
          // More compact layout for checkboxes
          Wrap(
            spacing: 16,
            runSpacing: 8,
            children: [
              SizedBox(
                width: 130,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Checkbox to enable/disable the low pass filter. Updates the graphProvider's useLowPassFilter.
                    Obx(() => Checkbox(
                          value: graphProvider.useLowPassFilter.value,
                          onChanged: (value) =>
                              graphProvider.setUseLowPassFilter(value ?? false),
                        )),
                    const Text('50kHz Filter', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
              SizedBox(
                width: 130,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Checkbox to enable/disable hysteresis. Updates the graphProvider's useHysteresis.
                    Obx(() => Checkbox(
                          value: graphProvider.useHysteresis.value,
                          onChanged: (value) =>
                              graphProvider.setUseHysteresis(value ?? false),
                        )),
                    const Text('Hysteresis', style: TextStyle(fontSize: 13)),
                  ],
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Builds the filter settings section.
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
          Wrap(
            spacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              SizedBox(
                width: 24, // Fixed width for checkbox
                child: Obx(() => Checkbox(
                      value: graphProvider.useDoubleFilt.value,
                      onChanged: (value) =>
                          graphProvider.setUseDoubleFilt(value ?? true),
                    )),
              ),
              const Text('Zero-Phase Filtering'),
              Tooltip(
                message: 'Removes phase shift using forward-backward filtering',
                child: Icon(Icons.info_outline, size: 16),
              ),
            ],
          ),
          const SizedBox(height: 12),
          const Text('Filter Type:'),
          // Dropdown to select the filter type. Updates the graphProvider's currentFilter.
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
          // Conditionally display filter-specific settings based on the selected filter type.
          Obx(() {
            final currentFilter = graphProvider.currentFilter.value;
            if (currentFilter is MovingAverageFilter) {
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Window Size:'),
                  // TextField to set the window size for the moving average filter. Updates the graphProvider's windowSize.
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
                  // TextField to set the alpha value for the exponential filter. Updates the graphProvider's alpha.
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
                  // TextField to set the cutoff frequency for the low pass filter. Updates the graphProvider's cutoffFrequency.
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

  /// Builds the information section to display frequency source and value.
  Widget _buildInformationSection() {
    final userSettings = Get.find<UserSettingsProvider>();

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
          Wrap(
            spacing: 8,
            runSpacing: 8,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text('Frequency Source:'),
              // Dropdown to select the frequency source. Updates the userSettingsProvider's frequencySource.
              Obx(() => DropdownButton<FrequencySource>(
                    value: userSettings.frequencySource.value,
                    onChanged: (source) {
                      if (source != null) {
                        userSettings.setFrequencySource(source);
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
          // Displays the current frequency value.
          Obx(() =>
              Text('${userSettings.frequency.value.toStringAsFixed(2)} Hz')),
        ],
      ),
    );
  }

  /// Builds the sampling frequency section
  Widget _buildSamplingFrequencySection() {
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
          const Text('Sampling Frequency',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          // Wrap buttons in a container with padding
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8.0),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await graphProvider.decreaseSamplingFrequency();
                      } catch (e) {
                        Get.snackbar(
                            'Error', 'Failed to update sampling frequency');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: const Icon(Icons.remove, size: 20),
                  ),
                ),
                const SizedBox(width: 12),
                SizedBox(
                  width: 40,
                  height: 40,
                  child: ElevatedButton(
                    onPressed: () async {
                      try {
                        await graphProvider.increaseSamplingFrequency();
                      } catch (e) {
                        Get.snackbar(
                            'Error', 'Failed to update sampling frequency');
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                    ),
                    child: const Icon(Icons.add, size: 20),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Center(
            child: Obx(() => Text(
                  'Current: ${(graphProvider.deviceConfig.samplingFrequency / 1000).toStringAsFixed(2)} kHz',
                  style: const TextStyle(fontSize: 16),
                )),
          ),
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
          _buildInformationSection(),
          _buildFilterSettings(),
          _buildSamplingFrequencySection(), // Add the new section
        ],
      ),
    );
  }
}
