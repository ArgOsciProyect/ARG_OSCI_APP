// lib/features/graph/domain/models/voltage_scale.dart
class VoltageScale {
  final double scale;
  final String displayName;

  const VoltageScale(this.scale, this.displayName);

  @override
  String toString() => displayName;
}

class VoltageScales {
  static const volts_5 = VoltageScale(800 / 512, "400V, -400V");
  static const volts_2 = VoltageScale(4.0 / 512, "2V, -2V");
  static const volt_1 = VoltageScale(2.0 / 512, "1V, -1V");
  static const millivolts_500 = VoltageScale(1 / 512, "500mV, -500mV");
  static const millivolts_200 = VoltageScale(0.4 / 512, "200mV, -200mV");
  static const millivolts_100 = VoltageScale(0.2 / 512, "100mV, -100mV");

  static const List<VoltageScale> values = [
    volts_5,
    volts_2,
    volt_1,
    millivolts_500,
    millivolts_200,
    millivolts_100,
  ];
}
