// test/unit_test/models/voltage_scale_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';

void main() {
  group('VoltageScales', () {
    test('values list contains all predefined scales', () {
      expect(VoltageScales.values.length, equals(6));
      expect(VoltageScales.values, contains(VoltageScales.volts_5));
      expect(VoltageScales.values, contains(VoltageScales.millivolts_100));
    });

    test('voltage scale toString returns display name', () {
      const scale = VoltageScale(800, "400V, -400V");
      expect(scale.toString(), equals("400V, -400V"));
    });

    test('voltage scale baseRange is stored correctly', () {
      const scale = VoltageScale(0.2, "100mV, -100mV");
      expect(scale.baseRange, equals(0.2));
    });
  });
}
