// lib/features/data_acquisition/domain/repository/data_acquisition_repository.dart
import 'dart:async';
import '../models/data_point.dart';
import '../models/trigger_data.dart';

abstract class DataAcquisitionRepository {
  // Stream getters
  Stream<List<DataPoint>> get dataStream;
  Stream<double> get frequencyStream;
  Stream<double> get maxValueStream;

  // Data acquisition methods
  Future<void> fetchData(String ip, int port);
  Future<void> stopData();
  void dispose();

  // Configuration and calculations
  Future<void> initialize();
  List<double> autoset(double chartHeight, double chartWidth);
  void updateConfig();

  // Configuration properties
  double get scale;
  set scale(double value);

  double get distance;
  set distance(double value);

  double get triggerLevel;
  set triggerLevel(double value);

  TriggerEdge get triggerEdge;
  set triggerEdge(TriggerEdge value);

  double get triggerSensitivity;
  set triggerSensitivity(double value);
}
