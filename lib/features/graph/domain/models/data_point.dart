/// Represents a single data point in the oscilloscope or FFT display
///
/// Contains x and y coordinates and optional trigger and interpolation flags for visualization
class DataPoint {
  /// X-coordinate (time in seconds for oscilloscope, frequency in Hz for FFT)
  double x;

  /// Y-coordinate (voltage in V for oscilloscope, magnitude in dB for FFT)
  final double y;

  /// Whether this point triggered data acquisition
  final bool isTrigger;

  /// Whether this point was interpolated (not an actual measurement)
  final bool isInterpolated;

  /// Creates a new data point
  ///
  /// [x] The x-coordinate
  /// [y] The y-coordinate
  /// [isTrigger] Optional flag indicating if this point triggered acquisition
  /// [isInterpolated] Optional flag indicating if this point was interpolated
  DataPoint(this.x, this.y,
      {this.isTrigger = false, this.isInterpolated = false});

  /// Creates a DataPoint from JSON map
  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      json['x'],
      json['y'],
      isTrigger: json['isTrigger'] ?? false,
      isInterpolated: json['isInterpolated'] ?? false,
    );
  }

  /// Converts DataPoint to JSON map
  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'isTrigger': isTrigger,
      'isInterpolated': isInterpolated,
    };
  }
}
