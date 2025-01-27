// lib/features/graph/domain/models/device_config.dart

class DeviceConfig {
  final double samplingFrequency;
  final int bitsPerPacket;
  final int dataMask;
  final int channelMask;
  final int usefulBits;
  final int samplesPerPacket;

  const DeviceConfig({
    required this.samplingFrequency,
    required this.bitsPerPacket,
    required this.dataMask,
    required this.channelMask,
    required this.usefulBits,
    required this.samplesPerPacket,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    return DeviceConfig(
      samplingFrequency: json['sampling_frequency'] as double,
      bitsPerPacket: json['bits_per_packet'] as int,
      dataMask: json['data_mask'] as int,
      channelMask: json['channel_mask'] as int,
      usefulBits: json['useful_bits'] as int,
      samplesPerPacket: json['samples_per_packet'] as int,
    );
  }
}