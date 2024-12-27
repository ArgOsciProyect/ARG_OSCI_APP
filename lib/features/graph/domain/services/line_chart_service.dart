// lib/features/graph/services/line_chart_service.dart
import 'dart:async';
import '../models/data_point.dart';
import '../../providers/data_provider.dart';
import '../models/filter_types.dart';

class LineChartService {
  final GraphProvider graphProvider;
  final _dataController = StreamController<List<DataPoint>>.broadcast();
  StreamSubscription? _dataSubscription;

  int _windowSize = 5;
  double _alpha = 0.2;
  double _cutoffFrequency = 100.0;

  static final List<FilterType> availableFilters = [
    NoFilter(),
    MovingAverageFilter(),
    ExponentialFilter(),
    LowPassFilter(),
  ];

  FilterType _currentFilter = NoFilter();

  FilterType get currentFilter => _currentFilter;
  int get windowSize => _windowSize;
  double get alpha => _alpha;
  double get cutoffFrequency => _cutoffFrequency;

  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  LineChartService(this.graphProvider) {
    // Subscribe to data stream and apply filter
    _dataSubscription = graphProvider.dataPointsStream.listen((points) {
      final filteredPoints = applyFilter(points);
      _dataController.add(filteredPoints);
    });
  }

  void setFilter(FilterType filter) {
    _currentFilter = filter;
  }

  void setWindowSize(int size) {
    _windowSize = size;
  }

  void setAlpha(double value) {
    _alpha = value;
  }

  void setCutoffFrequency(double freq) {
    _cutoffFrequency = freq;
  }


  List<DataPoint> applyFilter(List<DataPoint> points) {
    final params = {
      'windowSize': _windowSize,
      'alpha': _alpha,
      'cutoffFrequency': _cutoffFrequency,
    };
    return _currentFilter.apply(points, params);
  }

  void dispose() {
    _dataSubscription?.cancel();
    _dataController.close();
  }

}