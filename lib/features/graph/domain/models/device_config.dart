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

  final List<Map<String, dynamic>> voltageScales;

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
    List<Map<String, dynamic>>? voltageScales,
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
        midBits = midBits ?? ((1 << (usefulBits)) ~/ 2),
        // Default voltage scales if not provided
        voltageScales = voltageScales ??
            [
              {'baseRange': 800.0, 'displayName': '400V, -400V'},
              {'baseRange': 4.0, 'displayName': '2V, -2V'},
              {'baseRange': 2.0, 'displayName': '1V, -1V'},
              {'baseRange': 1.0, 'displayName': '500mV, -500mV'},
              {'baseRange': 0.4, 'displayName': '200mV, -200mV'},
              {'baseRange': 0.2, 'displayName': '100mV, -100mV'},
            ];

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    try {
      // Parse voltage scales if available
      List<Map<String, dynamic>>? voltageScales;
      if (json['voltage_scales'] != null) {
        voltageScales = List<Map<String, dynamic>>.from(
          (json['voltage_scales'] as List).map(
            (scale) => {
              'baseRange': double.parse(scale['baseRange'].toString()),
              'displayName': scale['displayName'].toString(),
            },
          ),
        );
      }

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
        voltageScales: voltageScales,
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
        'voltage_scales': voltageScales,
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
    List<Map<String, dynamic>>? voltageScales,
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
      voltageScales: voltageScales ?? this.voltageScales,
    );
  }
}
