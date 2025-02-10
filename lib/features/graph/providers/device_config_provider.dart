import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:get/get.dart';

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

  DeviceConfig? get config => _config.value;

  // Reactive getters for commonly used values
  double get samplingFrequency =>
      (_config.value?.samplingFrequency ?? 1650000.0) / dividingFactor;
  int get dividingFactor => _config.value?.dividingFactor ?? 1;
  dynamic get bitsPerPacket => _config.value?.bitsPerPacket ?? 16;
  dynamic get dataMask => _config.value?.dataMask ?? 0x0FFF;
  dynamic get channelMask => _config.value?.channelMask ?? 0xF000;
  dynamic get usefulBits => _config.value?.usefulBits ?? 12;
  dynamic get samplesPerPacket => _config.value?.samplesPerPacket ?? 8192 * 2;

  void updateConfig(DeviceConfig config) {
    _config.value = config;
  }
}
