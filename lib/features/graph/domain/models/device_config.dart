// ignore_for_file: provide_deprecation_message, deprecated_member_use_from_same_package

class DeviceConfig {
  /// Private base sampling frequency in Hz
  final double _baseSamplingFrequency;

  /// Number of bits per data packet
  final int bitsPerPacket;

  /// Bit mask for extracting data values
  final int dataMask;

  /// Bit mask for extracting channel information
  final int channelMask;

  /// Number of useful bits in each packet
  @deprecated
  final int usefulBits;

  /// Number of samples contained in each packet
  final int samplesPerPacket;

  /// Factor used to divide incoming data stream
  final int dividingFactor;

  /// Number of samples to discard from the beginning
  final int discardHead;

  /// Number of samples to discard from the end
  final int discardTrailer;

  /// Cached number of trailing zeros in data mask
  final int dataMaskTrailingZeros;

  /// Cached number of trailing zeros in channel mask
  final int channelMaskTrailingZeros;

  /// Max input value in bits
  final int maxBits;

  /// Mid input value in bits
  final int midBits;

  /// Returns effective sampling frequency (base frequency divided by dividing factor)
  double get samplingFrequency => _baseSamplingFrequency / dividingFactor;

  // Add getter for minBits
  int get minBits => (midBits * 2) - maxBits;

  DeviceConfig({
    required double samplingFrequency,
    required this.bitsPerPacket,
    required this.dataMask,
    required this.channelMask,
    @deprecated this.usefulBits = 12,
    required this.samplesPerPacket,
    required this.dividingFactor,
    this.discardHead = 0,
    this.discardTrailer = 0,
    int? maxBits,
    int? midBits,
  })  : _baseSamplingFrequency = samplingFrequency,
        dataMaskTrailingZeros = dataMask
            .toRadixString(2)
            .split('')
            .reversed
            .takeWhile((c) => c == '0')
            .length,
        channelMaskTrailingZeros = channelMask
            .toRadixString(2)
            .split('')
            .reversed
            .takeWhile((c) => c == '0')
            .length,
        maxBits = maxBits ?? (1 << (usefulBits)),
        midBits = midBits ?? ((1 << (usefulBits)) ~/ 2);

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    try {
      return DeviceConfig(
        samplingFrequency: double.parse(json['sampling_frequency'].toString()),
        bitsPerPacket: int.parse(json['bits_per_packet'].toString()),
        dataMask: int.parse(json['data_mask'].toString()),
        channelMask: int.parse(json['channel_mask'].toString()),
        usefulBits: int.parse(json['useful_bits']?.toString() ?? '12'),
        samplesPerPacket: int.parse(json['samples_per_packet'].toString()),
        dividingFactor: int.parse(json['dividing_factor'].toString()),
        discardHead: int.parse(json['discard_head']?.toString() ?? '0'),
        discardTrailer: int.parse(json['discard_trailer']?.toString() ?? '0'),
        maxBits: json['max_bits'] != null
            ? int.parse(json['max_bits'].toString())
            : null,
        midBits: json['mid_bits'] != null
            ? int.parse(json['mid_bits'].toString())
            : null,
      );
    } catch (e) {
      throw FormatException(
          'Failed to parse DeviceConfig: $e\nReceived JSON: $json');
    }
  }

  Map<String, dynamic> toJson() => {
        'sampling_frequency': _baseSamplingFrequency,
        'bits_per_packet': bitsPerPacket,
        'data_mask': dataMask,
        'channel_mask': channelMask,
        'useful_bits': usefulBits,
        'samples_per_packet': samplesPerPacket,
        'dividing_factor': dividingFactor,
        'discard_head': discardHead,
        'discard_trailer': discardTrailer,
        'max_bits': maxBits,
        'mid_bits': midBits,
      };

  DeviceConfig copyWith({
    double? samplingFrequency,
    int? bitsPerPacket,
    int? dataMask,
    int? channelMask,
    int? usefulBits,
    int? samplesPerPacket,
    int? dividingFactor,
    int? discardHead,
    int? discardTrailer,
    int? maxBits,
    int? midBits,
  }) {
    return DeviceConfig(
      samplingFrequency: samplingFrequency ?? _baseSamplingFrequency,
      bitsPerPacket: bitsPerPacket ?? this.bitsPerPacket,
      dataMask: dataMask ?? this.dataMask,
      channelMask: channelMask ?? this.channelMask,
      usefulBits: usefulBits ?? this.usefulBits,
      samplesPerPacket: samplesPerPacket ?? this.samplesPerPacket,
      dividingFactor: dividingFactor ?? this.dividingFactor,
      discardHead: discardHead ?? this.discardHead,
      discardTrailer: discardTrailer ?? this.discardTrailer,
      maxBits: maxBits ?? this.maxBits,
      midBits: midBits ?? this.midBits,
    );
  }
}
