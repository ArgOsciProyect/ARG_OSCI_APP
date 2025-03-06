// test/unit_test/models/data_point_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';

void main() {
  group('DataPoint Construction', () {
    test('creates with required parameters', () {
      final point = DataPoint(1.0, 2.0);

      expect(point.x, equals(1.0));
      expect(point.y, equals(2.0));
      expect(point.isTrigger, isFalse);
    });

    test('creates with optional trigger parameter', () {
      final point = DataPoint(1.0, 2.0, isTrigger: true);

      expect(point.x, equals(1.0));
      expect(point.y, equals(2.0));
      expect(point.isTrigger, isTrue);
    });
  });

  group('JSON Serialization', () {
    test('fromJson creates correct instance', () {
      final json = {
        'x': 1.0,
        'y': 2.0,
        'isTrigger': true,
      };

      final point = DataPoint.fromJson(json);

      expect(point.x, equals(1.0));
      expect(point.y, equals(2.0));
      expect(point.isTrigger, isTrue);
    });

    test('toJson creates correct map', () {
      final point = DataPoint(1.0, 2.0, isTrigger: true);
      final json = point.toJson();

      expect(json['x'], equals(1.0));
      expect(json['y'], equals(2.0));
      expect(json['isTrigger'], isTrue);
    });

    test('handles missing trigger in JSON', () {
      final json = {
        'x': 1.0,
        'y': 2.0,
      };

      final point = DataPoint.fromJson(json);
      expect(point.isTrigger, isFalse);
    });

    test('handles null values in JSON', () {
      final json = {
        'x': null,
        'y': null,
        'isTrigger': null,
      };

      expect(
        () => DataPoint.fromJson(json),
        throwsA(isA<TypeError>()),
      );
    });

    test('round-trip JSON serialization preserves values', () {
      final original = DataPoint(1.0, 2.0, isTrigger: true);
      final json = original.toJson();
      final decoded = DataPoint.fromJson(json);

      expect(decoded.x, equals(original.x));
      expect(decoded.y, equals(original.y));
      expect(decoded.isTrigger, equals(original.isTrigger));
    });
  });

  group('Value Handling', () {
    test('handles zero values', () {
      final point = DataPoint(0.0, 0.0);

      expect(point.x, equals(0.0));
      expect(point.y, equals(0.0));
    });

    test('handles negative values', () {
      final point = DataPoint(-1.0, -2.0);

      expect(point.x, equals(-1.0));
      expect(point.y, equals(-2.0));
    });

    test('handles large values', () {
      final point = DataPoint(double.maxFinite, double.maxFinite);

      expect(point.x, equals(double.maxFinite));
      expect(point.y, equals(double.maxFinite));
    });

    test('handles small values', () {
      final point = DataPoint(double.minPositive, double.minPositive);

      expect(point.x, equals(double.minPositive));
      expect(point.y, equals(double.minPositive));
    });
  });

  group('Mutable X Coordinate', () {
    test('allows modification of x coordinate', () {
      final point = DataPoint(1.0, 2.0);
      point.x = 3.0;

      expect(point.x, equals(3.0));
    });

    test('y coordinate remains immutable', () {
      final point = DataPoint(1.0, 2.0);

      expect(
        () => (point as dynamic).y = 3.0,
        throwsNoSuchMethodError,
      );
    });
  });
}
