// lib/features/data_acquisition/domain/repository/data_acquisition_repository.dart
import 'dart:async';
import '../models/data_point.dart';
import '../models/trigger_data.dart';

/// Interface for data acquisition repository
abstract class DataAcquisitionRepository {
  // Stream getters

  /// Stream of data points
  Stream<List<DataPoint>> get dataStream;

  /// Stream of frequency values
  Stream<double> get frequencyStream;

  /// Stream of maximum values
  Stream<double> get maxValueStream;

  // Data acquisition methods

  /// Fetches data from the specified IP and port
  ///
  /// [ip] The IP address to connect to
  /// [port] The port to connect to
  Future<void> fetchData(String ip, int port);

  /// Stops data acquisition
  Future<void> stopData();

  /// Disposes the repository, cleaning up resources
  void dispose();

  // Configuration and calculations

  /// Initializes the repository
  Future<void> initialize();

  /// Automatically sets the configuration based on chart dimensions
  ///
  /// [chartHeight] The height of the chart
  /// [chartWidth] The width of the chart
  /// Returns a list of doubles representing the time scale and value scale
  List<double> autoset(double chartHeight, double chartWidth);

  /// Updates the configuration
  void updateConfig();

  // Configuration properties

  /// Gets the scale value
  double get scale;

  /// Sets the scale value
  set scale(double value);

  /// Gets the distance value
  double get distance;

  /// Sets the distance value
  set distance(double value);

  /// Gets the trigger level
  double get triggerLevel;

  /// Sets the trigger level
  set triggerLevel(double value);

  /// Gets the trigger edge
  TriggerEdge get triggerEdge;

  /// Sets the trigger edge
  set triggerEdge(TriggerEdge value);

  /// Gets the trigger sensitivity
  double get triggerSensitivity;

  /// Sets the trigger sensitivity
  set triggerSensitivity(double value);
}
