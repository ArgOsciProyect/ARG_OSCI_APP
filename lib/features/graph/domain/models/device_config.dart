// lib/features/graph/domain/models/device_config.dart
class DeviceConfig {
  final double samplingFrequency;
  final int bitsPerPacket;
  final int dataMask;
  final int channelMask;
  final int usefulBits;
  final int samplesPerPacket;
  final int dividingFactor;

  const DeviceConfig({
    required this.samplingFrequency,
    required this.bitsPerPacket,
    required this.dataMask,
    required this.channelMask,
    required this.usefulBits,
    required this.samplesPerPacket,
    required this.dividingFactor,
  });

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    try {
      // Debug prints for incoming values
      print('sampling_frequency: ${json['sampling_frequency']}');
      print('bits_per_packet: ${json['bits_per_packet']}');
      print('data_mask: ${json['data_mask']}');
      print('channel_mask: ${json['channel_mask']}');
      print('useful_bits: ${json['useful_bits']}');
      print('samples_per_packet: ${json['samples_per_packet']}');
      print('dividing_factor: ${json['dividing_factor']}');
      return DeviceConfig(
        samplingFrequency: double.parse(json['sampling_frequency'].toString()),
        bitsPerPacket: int.parse(json['bits_per_packet'].toString()),
        dataMask: int.parse(json['data_mask'].toString()),
        channelMask: int.parse(json['channel_mask'].toString()),
        usefulBits: int.parse(json['useful_bits'].toString()),
        samplesPerPacket: int.parse(json['samples_per_packet'].toString()),
        dividingFactor: int.parse(json['dividing_factor'].toString()),
      );
    } catch (e) {
      throw FormatException(
          'Failed to parse DeviceConfig: $e\nReceived JSON: $json');
    }
  }

  Map<String, dynamic> toJson() => {
        'sampling_frequency': samplingFrequency,
        'bits_per_packet': bitsPerPacket,
        'data_mask': dataMask,
        'channel_mask': channelMask,
        'useful_bits': usefulBits,
        'samples_per_packet': samplesPerPacket,
        'dividing_factor': dividingFactor,
      };
}
