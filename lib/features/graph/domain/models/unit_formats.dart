import 'dart:math';

class UnitFormat {
  static final _prefixes = {
    -12: 'p',
    -9: 'n',
    -6: 'μ',
    -3: 'm',
    0: '',
    3: 'k',
    6: 'M',
    9: 'G',
    12: 'T'
  };

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
    final maxDecimals = 3 -
        integerDigits; // 3 digits max for numbers, leaving room for decimal point

    return "${scaledValue.toStringAsFixed(maxDecimals)} $prefix$unit";
  }
}
