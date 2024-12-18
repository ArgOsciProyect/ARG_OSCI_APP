// lib/features/data_acquisition/domain/models/data_point.dart
class DataPoint {
  double x;
  final double y;
  final bool isTrigger;

  DataPoint(this.x, this.y, {this.isTrigger = false});

  // JSON to/from Dart helper functions
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      json['x'],
      json['y'],
      isTrigger: json['isTrigger'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'isTrigger': isTrigger,
    };
  }
}