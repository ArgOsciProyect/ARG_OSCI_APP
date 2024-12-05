// lib/features/data_acquisition/domain/models/data_point.dart
class DataPoint {
  double x;
  final double y;

  DataPoint(this.x, this.y);

  // JSON to/from Dart helper functions
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      json['x'],
      json['y'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
    };
  }
}