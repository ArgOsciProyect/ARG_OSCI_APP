/// Defines trigger edge direction for oscilloscope acquisition
///
/// Determines whether the oscilloscope triggers on rising or falling signal edges
enum TriggerEdge {
  /// Trigger on rising edge (signal transition from low to high)
  positive,

  /// Trigger on falling edge (signal transition from high to low)
  negative
}

/// Defines trigger mode for oscilloscope acquisition
///
/// Controls whether the oscilloscope continuously captures signals or stops after one trigger
enum TriggerMode {
  /// Continuous triggering mode (auto-retrigger after each capture)
  normal,

  /// Single shot trigger mode (capture once then stop)
  single
}
