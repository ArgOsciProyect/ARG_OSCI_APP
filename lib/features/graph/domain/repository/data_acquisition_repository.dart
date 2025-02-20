import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';

/// Repository interface that defines data acquisition functionality for oscilloscope measurements
abstract class DataAcquisitionRepository {
  /// Stream of processed data points from the oscilloscope
  /// Returns a continuous stream of [List<DataPoint>] representing voltage measurements
  Stream<List<DataPoint>> get dataStream;

  /// Stream of calculated signal frequency values
  /// Returns the real-time frequency of the input signal in Hz
  Stream<double> get frequencyStream;

  /// Stream of maximum signal values
  /// Returns the peak voltage values of the signal
  Stream<double> get maxValueStream;

  /// Current voltage scale setting for the oscilloscope display
  /// Determines the voltage range per division
  VoltageScale get currentVoltageScale;

  /// Whether hysteresis is enabled for trigger detection
  /// Helps prevent false triggers from noise
  bool get useHysteresis;

  /// Whether low pass filtering is enabled for the input signal
  /// Helps reduce high frequency noise
  bool get useLowPassFilter;

  /// Current maximum value of the signal
  /// Used for display scaling and measurements
  double get currentMaxValue;

  /// Current minimum value of the signal
  /// Used for display scaling and measurements
  double get currentMinValue;

  /// Signal scaling factor for voltage measurements
  /// Converts raw ADC values to voltage
  double get scale;
  set scale(double value);

  /// Time between samples (1/sampling frequency)
  /// Determines horizontal resolution
  double get distance;
  set distance(double value);

  /// Trigger level threshold in volts
  /// Signal must cross this level to trigger
  double get triggerLevel;
  set triggerLevel(double value);

  /// Trigger edge direction (positive/negative)
  /// Determines which edge direction triggers acquisition
  TriggerEdge get triggerEdge;
  set triggerEdge(TriggerEdge value);

  /// Signal midpoint value calculated from device config
  /// Used for voltage offset calculations
  double get mid;
  set mid(double value);

  /// Current trigger detection mode (Normal/Single)
  /// Controls how acquisition is triggered
  TriggerMode get triggerMode;
  set triggerMode(TriggerMode value);

  /// Initializes the repository with device configuration
  /// Must be called before using other methods
  /// Returns a Future that completes when initialization is done
  Future<void> initialize();

  /// Starts data acquisition from specified network endpoint
  /// [ip] - Target device IP address
  /// [port] - Target device port number
  /// Returns a Future that completes when connection is established
  Future<void> fetchData(String ip, int port);

  /// Stops ongoing data acquisition and cleans up resources
  /// Returns a Future that completes when acquisition is stopped
  Future<void> stopData();

  /// Updates current configuration in processing pipeline
  /// Should be called after changing any settings
  void updateConfig();

  /// Clears all data queues and buffers
  /// Useful when changing modes or restarting acquisition
  void clearQueues();

  /// Sets voltage scale and updates related configurations
  /// [voltageScale] - New voltage scale to apply
  void setVoltageScale(VoltageScale voltageScale);

  /// Automatically adjusts display settings based on signal
  /// [chartHeight] - Available vertical display space
  /// [chartWidth] - Available horizontal display space
  /// Returns [timeScale, valueScale] for optimal display
  Future<List<double>> autoset(double chartHeight, double chartWidth);

  /// Sends trigger configuration to device
  /// Returns a Future that completes when settings are applied
  Future<void> postTriggerStatus();

  /// Requests single trigger mode from device
  /// Returns a Future that completes when mode is changed
  Future<void> sendSingleTriggerRequest();

  /// Requests normal trigger mode from device
  /// Returns a Future that completes when mode is changed
  Future<void> sendNormalTriggerRequest();

  /// Releases all resources and closes streams
  /// Should be called when repository is no longer needed
  void dispose();
}
