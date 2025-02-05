import 'dart:math' as math;

class UnitFormat {
  static const _prefixes = {
    -12: 'p',
    -9: 'n',
    -6: 'µ',
    -3: 'm',
    0: '',
    3: 'k',
    6: 'M',
    9: 'G',
  };

  static String formatWithUnit(double value, String baseUnit) {
    if (value == 0) return "0.0 $baseUnit";

    // Get the order of magnitude using correct log function
    final magnitude = (math.log(value.abs()) / math.ln10 / 3).floor() * 3;

    // Find the closest available prefix
    final prefixMagnitude = _prefixes.keys.where((k) => k <= magnitude).reduce(
        (a, b) => (magnitude - a).abs() < (magnitude - b).abs() ? a : b);

    final scaledValue = value / math.pow(10, prefixMagnitude);
    final prefix = _prefixes[prefixMagnitude] ?? '';

    // Format to ensure 3 digits + 1 decimal
    if (scaledValue.abs() < 10) {
      return "${scaledValue.toStringAsFixed(2)} $prefix$baseUnit";
    } else if (scaledValue.abs() < 100) {
      return "${scaledValue.toStringAsFixed(1)} $prefix$baseUnit";
    } else {
      return "${scaledValue.toStringAsFixed(0)} $prefix$baseUnit";
    }
  }
}
