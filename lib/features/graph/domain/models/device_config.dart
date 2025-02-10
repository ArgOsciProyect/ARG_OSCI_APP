/// Configuration parameters for the oscilloscope device
class DeviceConfig {
  /// Sampling frequency in Hz
  final double samplingFrequency;

  /// Number of bits per data packet
  final int bitsPerPacket;

  /// Bit mask for extracting data values
  final int dataMask;

  /// Bit mask for extracting channel information
  final int channelMask;

  /// Number of useful data bits per sample
  final int usefulBits;

  /// Number of samples contained in each packet
  final int samplesPerPacket;

  /// Factor used to divide incoming data stream
  final int dividingFactor;

  /// Creates a new device configuration
  const DeviceConfig({
    required this.samplingFrequency,
    required this.bitsPerPacket,
    required this.dataMask,
    required this.channelMask,
    required this.usefulBits,
    required this.samplesPerPacket,
    required this.dividingFactor,
  });

  /// Creates DeviceConfig from JSON map with error handling
  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    try {
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

  /// Converts DeviceConfig to JSON map
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
