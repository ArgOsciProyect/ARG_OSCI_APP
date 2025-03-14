// ignore_for_file: deprecated_member_use_from_same_package, provide_deprecation_message

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// [DeviceConfigProvider] manages the device configuration parameters.
class DeviceConfigProvider extends GetxController {
  final _config = Rx<DeviceConfig?>(DeviceConfig(
    samplingFrequency: 1650000.0,
    bitsPerPacket: 16,
    dataMask: 0x0FFF,
    channelMask: 0xF000,
    usefulBits: 9,
    samplesPerPacket: 8192,
    dividingFactor: 1,
    discardHead: 0,
    discardTrailer: 0,
  ));

  /// Returns the current device configuration.
  DeviceConfig? get config => _config.value;

  /// Get number of trailing zeros in data mask for bit shifting
  int get dataMaskTrailingZeros => dataMask
      .toRadixString(2)
      .split('')
      .reversed
      .takeWhile((c) => c == '0')
      .length;

  /// Get number of trailing zeros in channel mask for bit shifting
  int get channelMaskTrailingZeros => channelMask
      .toRadixString(2)
      .split('')
      .reversed
      .takeWhile((c) => c == '0')
      .length;

  // Reactive getters for commonly used values
  /// Returns the sampling frequency, adjusted by the dividing factor.
  double get samplingFrequency => _config.value!.samplingFrequency;

  /// Returns the dividing factor for the sampling frequency.
  int get dividingFactor => _config.value?.dividingFactor ?? 1;

  /// Returns the number of bits per packet.
  dynamic get bitsPerPacket => _config.value?.bitsPerPacket ?? 16;

  /// Returns the data mask.
  dynamic get dataMask => _config.value?.dataMask ?? 0x0FFF;

  /// Returns the number of samples to discard from the beginning
  int get discardHead => _config.value?.discardHead ?? 0;

  /// Returns the number of samples to discard from the end
  int get discardTrailer => _config.value?.discardTrailer ?? 0;

  List<VoltageScale> get voltageScales {
    if (_config.value == null) return VoltageScales.defaultScales;

    try {
      return _config.value!.voltageScales.map((scale) {
        final baseRange = double.parse(scale['baseRange'].toString());
        final displayName = scale['displayName'].toString();
        return VoltageScale(baseRange, displayName);
      }).toList();
    } catch (e) {
      if (kDebugMode) {
        print("Error parsing voltage scales: $e");
        print("Raw voltage scales: ${_config.value!.voltageScales}");
      }
      return VoltageScales.defaultScales;
    }
  }

  /// Returns the channel mask.
  dynamic get channelMask => _config.value?.channelMask ?? 0xF000;

  int get maxBits => _config.value?.maxBits ?? 500;
  int get midBits => _config.value?.midBits ?? 250;
  int get minBits => _config.value?.minBits ?? 0;

  /// Returns the number of useful bits.
  @deprecated
  dynamic get usefulBits => _config.value?.usefulBits ?? 12;

  /// Returns the number of samples per packet.
  dynamic get samplesPerPacket {
    var samples = _config.value?.samplesPerPacket ?? 8192;
    return (samples);
  }

  void listen(void Function(DeviceConfig?) onChanged) {
    ever(_config, onChanged);
  }

  /// Updates the device configuration.
  void updateConfig(DeviceConfig config) {
    _config.value = config;
    if (kDebugMode) {
      print("Sampling Frequency: $samplingFrequency");
      print("Dividing Factor: $dividingFactor");
      print("Bits per Packet: $bitsPerPacket");
      print("Data Mask: $dataMask");
      print("Channel Mask: $channelMask");
      print("Useful Bits: $usefulBits");
      print("Samples per Packet: $samplesPerPacket");
      print("Discard Head: $discardHead");
      print("Discard Trailer: $discardTrailer");

      // Print voltage scales
      print("Voltage Scales: [");
      for (var scale in config.voltageScales) {
        print(
            "  {baseRange: ${scale['baseRange']}, displayName: '${scale['displayName']}'}");
      }
      print("]");
    }
  }
}
