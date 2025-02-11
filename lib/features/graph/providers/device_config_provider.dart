import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
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
  ));

  /// Returns the current device configuration.
  DeviceConfig? get config => _config.value;

  // Reactive getters for commonly used values
  /// Returns the sampling frequency, adjusted by the dividing factor.
  double get samplingFrequency =>
      (_config.value?.samplingFrequency ?? 1650000.0) / dividingFactor;

  /// Returns the dividing factor for the sampling frequency.
  int get dividingFactor => _config.value?.dividingFactor ?? 1;

  /// Returns the number of bits per packet.
  dynamic get bitsPerPacket => _config.value?.bitsPerPacket ?? 16;

  /// Returns the data mask.
  dynamic get dataMask => _config.value?.dataMask ?? 0x0FFF;

  /// Returns the channel mask.
  dynamic get channelMask => _config.value?.channelMask ?? 0xF000;

  /// Returns the number of useful bits.
  dynamic get usefulBits => _config.value?.usefulBits ?? 12;

  /// Returns the number of samples per packet.
  dynamic get samplesPerPacket => _config.value?.samplesPerPacket ?? 8192 * 2;

  /// Updates the device configuration.
  void updateConfig(DeviceConfig config) {
    _config.value = config;
  }
}
