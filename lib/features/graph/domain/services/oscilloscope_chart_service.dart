import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/repository/oscilloscope_chart_repository.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';

/// [OscilloscopeChartService] implements the [OscilloscopeChartRepository] to manage the data stream for the oscilloscope chart.
///
/// Processes and forwards time-domain data from the acquisition system to the chart display,
/// while handling trigger conditions and display state.
class OscilloscopeChartService implements OscilloscopeChartRepository {
  DataAcquisitionProvider? _graphProvider;
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;
  bool _isPaused = false;

  @override
  double get distance => 1 / deviceConfig.samplingFrequency;

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  @override
  bool get isPaused => _isPaused;

  /// Creates a new OscilloscopeChartService with the specified data provider
  ///
  /// [provider] The data acquisition provider that supplies time-domain data
  OscilloscopeChartService(DataAcquisitionProvider? provider) {
    _graphProvider = provider;
    if (provider != null) {
      _setupSubscriptions();
    }
  }

  /// Sets up the data stream subscription to receive data points from the [DataAcquisitionProvider].
  ///
  /// Configures the subscription to handle different trigger modes and manages
  /// the flow of data points to the chart display.
  void _setupSubscriptions() {
    _dataSubscription?.cancel();

    if (_graphProvider != null) {
      _dataSubscription = _graphProvider!.dataPointsStream.listen((points) {
        // Check first if there's a trigger in single mode
        if (_graphProvider?.triggerMode.value == TriggerMode.single &&
            points.any((p) => p.isTrigger)) {
          _dataController.add(points); // Emit points with the trigger
          pause(); // Pause after emitting
          return; // Exit to prevent further emissions
        }

        // For normal mode or without trigger
        if (!_isPaused) {
          _dataController.add(points);
        }
      });
    }
  }

  /// Calculates optimal chart scaling values based on signal parameters
  ///
  /// Determines appropriate time and voltage scales to display the signal
  /// with proper margins and visibility.
  ///
  /// [chartWidth] Width of the chart area in pixels
  /// [frequency] Detected frequency of the signal in Hz
  /// [maxValue] Maximum voltage value in the signal
  /// [minValue] Minimum voltage value in the signal
  /// [marginFactor] Optional multiplier to add margins around the signal (default: 1.15)
  /// Returns a map with timeScale, valueScale, and verticalCenter values
  @override
  Map<String, double> calculateAutosetScales(
      double chartWidth, double frequency, double maxValue, double minValue,
      {double marginFactor = 1.15}) {
    // Add margin to min and max values
    final adjustedMaxValue =
        maxValue > 0 ? maxValue * marginFactor : maxValue / marginFactor;
    final adjustedMinValue =
        minValue < 0 ? minValue * marginFactor : minValue / marginFactor;

    // Calculate the total range with margins
    final totalRange = adjustedMaxValue - adjustedMinValue;
    final verticalCenter = (adjustedMaxValue + adjustedMinValue) / 2;

    double timeScale;
    double valueScale;

    if (frequency <= 0) {
      // No frequency detected, use default time scale
      timeScale = 100000;

      // Calculate value scale based on adjusted range
      if (totalRange > 0) {
        valueScale = 1.0 / totalRange;
      } else {
        // Fallback for zero or very small range
        valueScale = 1.0;
      }
    } else {
      // Calculate time scale to show 3 periods
      final period = 1 / frequency;
      final totalTime = 3 * period;
      timeScale = chartWidth / totalTime;

      // Calculate value scale based on adjusted range
      if (totalRange > 0) {
        valueScale = 1.0 / totalRange;
      } else {
        // Fallback using max absolute value
        final maxAbsValue =
            maxValue.abs() > minValue.abs() ? maxValue.abs() : minValue.abs();
        final expandedAbsValue = maxAbsValue * marginFactor;
        valueScale = expandedAbsValue > 0 ? 1.0 / (expandedAbsValue * 2) : 1.0;
      }
    }

    return {
      'timeScale': timeScale,
      'valueScale': valueScale,
      'verticalCenter': verticalCenter
    };
  }

  /// Resumes data flow and prepares for a new trigger event
  ///
  /// Used in single trigger mode to reactivate data acquisition
  /// while waiting for the next trigger condition.
  @override
  void resumeAndWaitForTrigger() {
    _isPaused = false;
    // We don't clear data here - let the provider handle it
    _setupSubscriptions();
  }

  /// Pauses the data flow from acquisition system to chart
  @override
  void pause() {
    _isPaused = true;
  }

  /// Resumes the data flow from acquisition system to chart
  @override
  void resume() {
    _isPaused = false;
  }

  /// Updates the data provider used by this service
  ///
  /// [provider] The new data acquisition provider to use
  @override
  void updateProvider(DataAcquisitionProvider provider) {
    _graphProvider = provider;
    _setupSubscriptions();
  }

  /// Releases resources used by the service
  ///
  /// Cancels subscriptions and closes stream controllers
  @override
  Future<void> dispose() async {
    await _dataSubscription?.cancel();
    await _dataController.close();
  }
}