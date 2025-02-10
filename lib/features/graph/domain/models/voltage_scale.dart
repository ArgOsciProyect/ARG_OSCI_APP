/// Represents a voltage scale setting for the oscilloscope
class VoltageScale {
  /// Scale factor to convert raw ADC values to voltage
  final double scale;

  /// Human readable display name for this scale
  final String displayName;

  const VoltageScale(this.scale, this.displayName);

  @override
  String toString() => displayName;
}

/// Pre-defined voltage scale settings
class VoltageScales {
  /// ±400V range
  static const volts_5 = VoltageScale(800 / 512, "400V, -400V");

  /// ±2V range
  static const volts_2 = VoltageScale(4.0 / 512, "2V, -2V");

  /// ±1V range
  static const volt_1 = VoltageScale(2.0 / 512, "1V, -1V");

  /// ±500mV range
  static const millivolts_500 = VoltageScale(1 / 512, "500mV, -500mV");

  /// ±200mV range
  static const millivolts_200 = VoltageScale(0.4 / 512, "200mV, -200mV");

  /// ±100mV range
  static const millivolts_100 = VoltageScale(0.2 / 512, "100mV, -100mV");

  /// List of all available voltage scales
  static const List<VoltageScale> values = [
    volts_5,
    volts_2,
    volt_1,
    millivolts_500,
    millivolts_200,
    millivolts_100,
  ];
}
