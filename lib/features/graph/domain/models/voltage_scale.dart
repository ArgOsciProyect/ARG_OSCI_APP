import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Pre-defined voltage scale settings
class VoltageScales {
  /// ±400V range
  static const volts_5 = VoltageScale(800, "400V, -400V");

  /// ±2V range
  static const volts_2 = VoltageScale(4.0, "2V, -2V");

  /// ±1V range
  static const volt_1 = VoltageScale(2.0, "1V, -1V");

  /// ±500mV range
  static const millivolts_500 = VoltageScale(1.0, "500mV, -500mV");

  /// ±200mV range
  static const millivolts_200 = VoltageScale(0.4, "200mV, -200mV");

  /// ±100mV range
  static const millivolts_100 = VoltageScale(0.2, "100mV, -100mV");

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

class VoltageScale {
  final double baseRange;
  final String displayName;

  const VoltageScale(this.baseRange, this.displayName);

  double get scale {
    int div = 1 << Get.find<DeviceConfigProvider>().usefulBits;
    if (div == 0) div = 1;
    final result = baseRange / div;

    if (kDebugMode) {
      print(
          'VoltageScale: $displayName, baseRange: $baseRange, div: $div, scale: $result');
    }
    return result;
  }

  @override
  String toString() => displayName;
}
