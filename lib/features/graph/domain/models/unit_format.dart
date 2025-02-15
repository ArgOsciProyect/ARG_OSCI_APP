import 'dart:math';

/// Utility class for formatting values with SI unit prefixes
class UnitFormat {
  /// Map of SI prefix exponents to their symbols
  /// Keys are powers of 10 (e.g. -12 for pico, -9 for nano, etc)
  /// Values are the corresponding prefix symbols
  static final _prefixes = {
    -12: 'p', // pico
    -9: 'n', // nano
    -6: 'μ', // micro
    -3: 'm', // milli
    0: '', // base unit
    3: 'k', // kilo
    6: 'M', // mega
    9: 'G', // giga
    12: 'T' // tera
  };

  /// Formats a numeric value with appropriate SI prefix and unit
  ///
  /// [value] The numeric value to format
  /// [unit] The base unit symbol (e.g. "V" for volts)
  /// Returns formatted string with value, SI prefix and unit
  ///
  /// Examples:
  /// ```dart
  /// formatWithUnit(0.001, "V") // "1 mV"
  /// formatWithUnit(1000, "Hz") // "1 kHz"
  /// ```
  static String formatWithUnit(double value, String unit) {
    if (value == 0) return "0 $unit";

    // Handle very small/large numbers
    if (value.abs() < 1e-15 || value.abs() > 1e15) {
      return "${value.toStringAsExponential(1)} $unit";
    }

    // Find appropriate prefix
    final exp = (log(value.abs()) / ln10).floor();
    final prefixExp = (exp / 3).floor() * 3;

    if (!_prefixes.containsKey(prefixExp)) {
      return "${value.toStringAsExponential(1)} $unit";
    }

    final scaledValue = value / pow(10, prefixExp);
    final prefix = _prefixes[prefixExp] ?? '';

    // Calculate how many decimal places we can show
    final integerPart = scaledValue.abs().floor();
    final integerDigits = integerPart == 0 ? 1 : integerPart.toString().length;
    final maxDecimals = 3 - integerDigits;

    return "${scaledValue.toStringAsFixed(maxDecimals)} $prefix$unit";
  }
}
