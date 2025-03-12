import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// Pre-defined voltage scale settings
class VoltageScales {
  static const VoltageScale volts_5 = VoltageScale(800, "400V, -400V");
  static const VoltageScale volts_2 = VoltageScale(4.0, "2V, -2V");
  static const VoltageScale volt_1 = VoltageScale(2.0, "1V, -1V");
  static const VoltageScale millivolts_500 = VoltageScale(1.0, "500mV, -500mV");
  static const VoltageScale millivolts_200 = VoltageScale(0.4, "200mV, -200mV");
  static const VoltageScale millivolts_100 = VoltageScale(0.2, "100mV, -100mV");

  // This will now be used only as a fallback
  static const List<VoltageScale> defaultScales = [
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

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is VoltageScale &&
        other.baseRange == baseRange &&
        other.displayName == displayName;
  }

  double get scale {
    final deviceConfig = Get.find<DeviceConfigProvider>();
    final totalRange = deviceConfig.maxBits - deviceConfig.minBits;

    // The scale factor should map the total range to baseRange
    // Example: if baseRange is 2.0 (±1V) and range is 614 (635-21),
    // then scale should be 2.0/614 V/bit
    if (kDebugMode) {
      print(
          "mid and max bits: ${deviceConfig.minBits} ${deviceConfig.maxBits}");
      print("baseRange: $baseRange");
      print("totalRange: $totalRange");
    }
    return baseRange / totalRange;
  }

  @override
  int get hashCode => baseRange.hashCode ^ displayName.hashCode;

  @override
  String toString() => displayName;
}
