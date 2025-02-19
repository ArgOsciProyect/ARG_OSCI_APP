/// Represents a single data point in the oscilloscope or FFT display
///
/// Contains x and y coordinates and optional trigger flag for visualization
class DataPoint {
  /// X-coordinate (time in seconds for oscilloscope, frequency in Hz for FFT)
  double x;

  /// Y-coordinate (voltage in V for oscilloscope, magnitude in dB for FFT)
  final double y;

  /// Whether this point triggered data acquisition
  final bool isTrigger;

  /// Creates a new data point
  ///
  /// [x] The x-coordinate
  /// [y] The y-coordinate
  /// [isTrigger] Optional flag indicating if this point triggered acquisition
  DataPoint(this.x, this.y, {this.isTrigger = false});

  /// Creates a DataPoint from JSON map
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      json['x'],
      json['y'],
      isTrigger: json['isTrigger'] ?? false,
    );
  }

  /// Converts DataPoint to JSON map
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'isTrigger': isTrigger,
    };
  }
}
