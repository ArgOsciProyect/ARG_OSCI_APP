// test/unit_test/models/device_config_test.dart
// ignore_for_file: deprecated_member_use_from_same_package

import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';

void main() {
  group('DeviceConfig Construction', () {
    test('creates with required parameters', () {
      final config = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 9,
        samplesPerPacket: 8192,
        dividingFactor: 1,
      );

      expect(config.samplingFrequency, equals(1650000.0));
      expect(config.bitsPerPacket, equals(16));
      expect(config.dataMask, equals(0x0FFF));
      expect(config.channelMask, equals(0xF000));
      expect(config.usefulBits, equals(9));
      expect(config.samplesPerPacket, equals(8192));
      expect(config.dividingFactor, equals(1));
      expect(config.discardHead, equals(0));
      expect(config.discardTrailer, equals(0));
    });

    test('creates with optional parameters', () {
      final config = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 9,
        samplesPerPacket: 8192,
        dividingFactor: 1,
        discardHead: 10,
        discardTrailer: 20,
      );

      expect(config.discardHead, equals(10));
      expect(config.discardTrailer, equals(20));
    });
  });

  group('JSON Serialization', () {
    test('fromJson creates correct instance', () {
      final json = {
        'sampling_frequency': '1650000.0',
        'bits_per_packet': '16',
        'data_mask': '0x0FFF',
        'channel_mask': '0xF000',
        'useful_bits': '9',
        'samples_per_packet': '8192',
        'dividing_factor': '1',
        'discard_head': '10',
        'discard_trailer': '20',
      };

      final config = DeviceConfig.fromJson(json);

      expect(config.samplingFrequency, equals(1650000.0));
      expect(config.bitsPerPacket, equals(16));
      expect(config.dataMask, equals(0x0FFF));
      expect(config.channelMask, equals(0xF000));
      expect(config.usefulBits, equals(9));
      expect(config.samplesPerPacket, equals(8192));
      expect(config.dividingFactor, equals(1));
      expect(config.discardHead, equals(10));
      expect(config.discardTrailer, equals(20));
    });

    test('toJson creates correct map', () {
      final config = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 9,
        samplesPerPacket: 8192,
        dividingFactor: 1,
        discardHead: 10,
        discardTrailer: 20,
      );

      final json = config.toJson();

      expect(json['sampling_frequency'], equals(1650000.0));
      expect(json['bits_per_packet'], equals(16));
      expect(json['data_mask'], equals(0x0FFF));
      expect(json['channel_mask'], equals(0xF000));
      expect(json['useful_bits'], equals(9));
      expect(json['samples_per_packet'], equals(8192));
      expect(json['dividing_factor'], equals(1));
      expect(json['discard_head'], equals(10));
      expect(json['discard_trailer'], equals(20));
    });

    test('handles missing optional fields', () {
      final json = {
        'sampling_frequency': '1650000.0',
        'bits_per_packet': '16',
        'data_mask': '0x0FFF',
        'channel_mask': '0xF000',
        'useful_bits': '9',
        'samples_per_packet': '8192',
        'dividing_factor': '1',
      };

      final config = DeviceConfig.fromJson(json);
      expect(config.discardHead, equals(0));
      expect(config.discardTrailer, equals(0));
    });

    test('throws FormatException on invalid JSON', () {
      final invalidJson = {
        'sampling_frequency': 'invalid',
      };

      expect(
        () => DeviceConfig.fromJson(invalidJson),
        throwsA(isA<FormatException>()),
      );
    });
  });

  group('CopyWith', () {
    test('copies with no changes', () {
      final original = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 9,
        samplesPerPacket: 8192,
        dividingFactor: 1,
        discardHead: 10,
        discardTrailer: 20,
      );

      final copy = original.copyWith();

      expect(copy.samplingFrequency, equals(original.samplingFrequency));
      expect(copy.bitsPerPacket, equals(original.bitsPerPacket));
      expect(copy.dataMask, equals(original.dataMask));
      expect(copy.channelMask, equals(original.channelMask));
      expect(copy.usefulBits, equals(original.usefulBits));
      expect(copy.samplesPerPacket, equals(original.samplesPerPacket));
      expect(copy.dividingFactor, equals(original.dividingFactor));
      expect(copy.discardHead, equals(original.discardHead));
      expect(copy.discardTrailer, equals(original.discardTrailer));
    });

    test('copies with partial changes', () {
      final original = DeviceConfig(
        samplingFrequency: 1650000.0,
        bitsPerPacket: 16,
        dataMask: 0x0FFF,
        channelMask: 0xF000,
        usefulBits: 9,
        samplesPerPacket: 8192,
        dividingFactor: 1,
        discardHead: 10,
        discardTrailer: 20,
      );

      final copy = original.copyWith(
        samplingFrequency: 2000000.0,
        discardHead: 15,
      );

      expect(copy.samplingFrequency, equals(2000000.0));
      expect(copy.bitsPerPacket, equals(original.bitsPerPacket));
      expect(copy.dataMask, equals(original.dataMask));
      expect(copy.channelMask, equals(original.channelMask));
      expect(copy.usefulBits, equals(original.usefulBits));
      expect(copy.samplesPerPacket, equals(original.samplesPerPacket));
      expect(copy.dividingFactor, equals(original.dividingFactor));
      expect(copy.discardHead, equals(15));
      expect(copy.discardTrailer, equals(original.discardTrailer));
    });
  });
}
