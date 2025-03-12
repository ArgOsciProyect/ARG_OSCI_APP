// test/unit_test/models/voltage_scale_test.dart
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:get/get.dart';

class MockDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  final _config = Rx<DeviceConfig?>(null);

  @override
  DeviceConfig? get config => _config.value;

  @override
  double get samplingFrequency => config?.samplingFrequency ?? 1650000.0;

  @override
  int get bitsPerPacket => config?.bitsPerPacket ?? 16;
  @override
  List<VoltageScale> get voltageScales => VoltageScales.defaultScales;

  @override
  int get dataMask => config?.dataMask ?? 0x0FFF;

  @override
  int get channelMask => config?.channelMask ?? 0xF000;

  @override
  // ignore: deprecated_member_use_from_same_package
  int get usefulBits => config?.usefulBits ?? 9;

  @override
  int get samplesPerPacket => config?.samplesPerPacket ?? 4096;

  @override
  int get dividingFactor => config?.dividingFactor ?? 1;

  @override
  int get discardHead => config?.discardHead ?? 0;

  @override
  int get discardTrailer => config?.discardTrailer ?? 0;

  @override
  int get maxBits => config?.maxBits ?? 500;

  @override
  int get midBits => config?.midBits ?? 250;

  @override
  int get minBits => config?.minBits ?? 0;

  @override
  void updateConfig(DeviceConfig config) {
    _config.value = config;
    _config.refresh(); // Forzar actualización
  }

  // Add the missing implementations:
  @override
  int get dataMaskTrailingZeros => dataMask
      .toRadixString(2)
      .split('')
      .reversed
      .takeWhile((c) => c == '0')
      .length;

  @override
  int get channelMaskTrailingZeros => channelMask
      .toRadixString(2)
      .split('')
      .reversed
      .takeWhile((c) => c == '0')
      .length;

  @override
  void listen(void Function(DeviceConfig? p1) onChanged) {}
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    Get.reset(); // Clear all previous instances
    // Register the mock provider properly
    final deviceConfigProvider = MockDeviceConfigProvider();
    Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);
  });

  tearDown(() {
    Get.reset();
  });

  test('VoltageScales has correct default scales', () {
    expect(VoltageScales.defaultScales.length, equals(6));
    expect(VoltageScales.defaultScales[0], equals(VoltageScales.volts_5));
  });

  test('VoltageScale calculates scale correctly', () {
    const scale = VoltageScales.volt_1;
    expect(scale.baseRange, equals(2.0));
    expect(scale.displayName, equals("1V, -1V"));
    // Since we're mocking deviceConfig with maxBits=500, minBits=0, totalRange=500
    expect(scale.scale, equals(2.0 / 500));
  });

  test('VoltageScale implements equality correctly', () {
    final scale1 = VoltageScale(2.0, "1V, -1V");
    final scale2 = VoltageScale(2.0, "1V, -1V");
    final scale3 = VoltageScale(1.0, "500mV, -500mV");

    expect(scale1, equals(scale2));
    expect(scale1, isNot(equals(scale3)));
  });
}
