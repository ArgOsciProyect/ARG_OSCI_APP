// lib/features/graph/domain/repository/data_acquisition_repository.dart

import 'dart:async';
import '../models/data_point.dart';
import '../models/trigger_data.dart';
import '../models/voltage_scale.dart';

/// Repository interface for data acquisition functionality
abstract class DataAcquisitionRepository {
  // Stream getters
  /// Stream of processed data points
  Stream<List<DataPoint>> get dataStream;

  /// Stream of calculated signal frequency values
  Stream<double> get frequencyStream;

  /// Stream of maximum signal values
  Stream<double> get maxValueStream;

  /// Gets the current voltage scale setting
  VoltageScale get currentVoltageScale;

  // Required properties
  /// Signal scaling factor
  double get scale;
  set scale(double value);

  /// Time between samples (1/sampling frequency)
  double get distance;
  set distance(double value);

  /// Trigger level threshold
  double get triggerLevel;
  set triggerLevel(double value);

  /// Trigger edge direction (positive/negative)
  TriggerEdge get triggerEdge;
  set triggerEdge(TriggerEdge value);

  /// Signal midpoint value calculated from device config
  double get mid;
  set mid(double value);

  /// Current trigger detection mode
  TriggerMode get triggerMode;
  set triggerMode(TriggerMode value);

  // Core functionality
  /// Initializes the repository with device configuration
  /// Must be called before using other methods
  Future<void> initialize();

  /// Starts data acquisition from specified network endpoint
  ///
  /// [ip] Target device IP address
  /// [port] Target device port number
  Future<void> fetchData(String ip, int port);

  /// Stops ongoing data acquisition and cleans up resources
  Future<void> stopData();

  /// Updates current configuration in processing pipeline
  void updateConfig();

  /// Sets voltage scale and updates related configurations
  ///
  /// [voltageScale] New voltage scale to apply
  void setVoltageScale(VoltageScale voltageScale);

  /// Automatically adjusts display settings based on signal
  ///
  /// [chartHeight] Available vertical display space
  /// [chartWidth] Available horizontal display space
  /// Returns [timeScale, valueScale] for display
  List<double> autoset(double chartHeight, double chartWidth);

  /// Releases all resources
  void dispose();
}
