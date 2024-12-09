// lib/features/data_acquisition/domain/repository/data_acquisition_repository.dart
import '../models/data_point.dart';

abstract class DataAcquisitionRepository {
  Future<void> fetchData();
  Stream<List<DataPoint>> get dataPointsStream;
  Stream<double> get frequencyStream;
  Stream<double> get maxValueStream;
  Future<void> stopData();
  List<DataPoint> parseData(List<int> data);
  List<DataPoint> applyTrigger(List<DataPoint> dataPoints);
  double calculateFrequencyWithMax(List<DataPoint> dataPoints);
  List<double> autoset(List<DataPoint> dataPoints, double chartHeight, double chartWidth);
}