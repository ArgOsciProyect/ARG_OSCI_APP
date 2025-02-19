// test/unit_test/models/unit_format_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/unit_format.dart';

void main() {
  group('UnitFormat', () {
    test('formats zero values correctly', () {
      expect(UnitFormat.formatWithUnit(0, "V"), equals("0 V"));
    });

    test('formats small values with SI prefixes', () {
      expect(UnitFormat.formatWithUnit(0.001234, "V"), equals("1.23 mV"));
      expect(UnitFormat.formatWithUnit(0.000001234, "V"), equals("1.23 μV"));
    });

    test('formats large values with SI prefixes', () {
      expect(UnitFormat.formatWithUnit(1234, "Hz"), equals("1.23 kHz"));
      expect(UnitFormat.formatWithUnit(1234000, "Hz"), equals("1.23 MHz"));
    });

    test('handles very small/large numbers with scientific notation', () {
      expect(
          UnitFormat.formatWithUnit(1e-16, "V"), matches(RegExp(r"1.0e-16 V")));
      expect(
          UnitFormat.formatWithUnit(1e16, "V"), matches(RegExp(r"1.0e\+16 V")));
    });
  });
}
