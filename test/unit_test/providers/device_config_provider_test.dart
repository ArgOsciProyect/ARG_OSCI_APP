// device_config_provider_test.dart
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';

void main() {
  late DeviceConfigProvider provider;

  setUp(() {
    Get.reset();
    provider = DeviceConfigProvider();
  });

  tearDown(() {
    Get.reset();
  });

  group('Provider Initialization', () {
    test('should initialize with default values', () {
      expect(provider.samplingFrequency, 1650000.0);
      expect(provider.bitsPerPacket, 16);
      expect(provider.dataMask, 0x0FFF);
      expect(provider.channelMask, 0xF000);
      expect(provider.usefulBits, 9);
      expect(provider.samplesPerPacket, 8192);
      expect(provider.dividingFactor, 1);
      expect(provider.discardHead, 0);
      expect(provider.discardTrailer, 0);
    });

    test('should initialize with valid config object', () {
      expect(provider.config, isNotNull);
      expect(provider.config, isA<DeviceConfig>());
    });
  });

  group('Config Updates', () {
    test('should update all values when new config is set', () {
      final newConfig = DeviceConfig(
        samplingFrequency: 825000.0,
        bitsPerPacket: 8,
        dataMask: 0x00FF,
        channelMask: 0xFF00,
        usefulBits: 8,
        samplesPerPacket: 4096,
        dividingFactor: 2,
        discardHead: 10,
        discardTrailer: 10,
      );

      provider.updateConfig(newConfig);

      // Sampling frequency is divided by dividingFactor
      expect(provider.samplingFrequency, 412500.0); // 825000.0 / 2
      expect(provider.bitsPerPacket, 8);
      expect(provider.dataMask, 0x00FF);
      expect(provider.channelMask, 0xFF00);
      expect(provider.usefulBits, 8);
      expect(provider.samplesPerPacket, 4096);
      expect(provider.dividingFactor, 2);
      expect(provider.discardHead, 10);
      expect(provider.discardTrailer, 10);
    });

    test('should notify listeners when config changes', () {
      var notified = false;
      final newConfig = DeviceConfig(
        samplingFrequency: 825000.0,
        bitsPerPacket: 8,
        dataMask: 0x00FF,
        channelMask: 0xFF00,
        usefulBits: 8,
        samplesPerPacket: 4096,
        dividingFactor: 2,
        discardHead: 10,
        discardTrailer: 10,
      );

      provider.listen((config) {
        notified = true;
        expect(config, equals(newConfig));
      });

      provider.updateConfig(newConfig);
      expect(notified, isTrue);
    });
  });

  group('Bit Mask Calculations', () {
    test('should calculate correct data mask trailing zeros', () {
      final newConfig = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0xF000, // 1111 0000 0000 0000
        channelMask: 0x000F,
        usefulBits: 12,
        samplesPerPacket: 512,
        dividingFactor: 1,
        discardHead: 0,
        discardTrailer: 0,
      );

      provider.updateConfig(newConfig);
      expect(provider.dataMaskTrailingZeros, 12);
    });

    test('should calculate correct channel mask trailing zeros', () {
      final newConfig = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x000F,
        channelMask: 0xF000, // 1111 0000 0000 0000
        usefulBits: 12,
        samplesPerPacket: 512,
        dividingFactor: 1,
        discardHead: 0,
        discardTrailer: 0,
      );

      provider.updateConfig(newConfig);
      expect(provider.channelMaskTrailingZeros, 12);
    });
  });

  group('Configuration Validation', () {
    test('should handle missing config values with defaults', () {
      expect(provider.samplingFrequency, isNotNull);
      expect(provider.bitsPerPacket, isNotNull);
      expect(provider.dataMask, isNotNull);
      expect(provider.channelMask, isNotNull);
      expect(provider.usefulBits, isNotNull);
      expect(provider.samplesPerPacket, isNotNull);
      expect(provider.dividingFactor, isNotNull);
      expect(provider.discardHead, isNotNull);
      expect(provider.discardTrailer, isNotNull);
    });

    test('should adjust sampling frequency by dividing factor', () {
      final newConfig = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 12,
        samplesPerPacket: 512,
        dividingFactor: 2,
        discardHead: 0,
        discardTrailer: 0,
      );

      provider.updateConfig(newConfig);
      expect(provider.samplingFrequency, 825000.0); // 1650000.0 / 2
    });

    test('should handle dividing factor changes', () {
      // Test with initial config
      expect(provider.samplingFrequency, 1650000.0);

      // Update with new dividing factor
      final newConfig = provider.config!.copyWith(dividingFactor: 4);
      provider.updateConfig(newConfig);

      // Check new sampling frequency
      expect(provider.samplingFrequency, 412500.0); // 1650000.0 / 4
    });
  });
}
