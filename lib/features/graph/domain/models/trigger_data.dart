/// Defines trigger edge direction for oscilloscope acquisition
enum TriggerEdge {
  /// Trigger on rising edge
  positive,

  /// Trigger on falling edge
  negative
}

/// Defines trigger mode for oscilloscope acquisition
enum TriggerMode {
  /// Continuous triggering
  normal,

  /// Single shot trigger
  single
}
