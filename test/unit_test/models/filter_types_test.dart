// test/unit_test/models/filter_types_test.dart
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'dart:math' as math;

List<double> _loadReferenceValues(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.map((line) => double.parse(line)).toList();
}

List<DataPoint> _loadTestSignal(String filename) {
  final file = File(filename);
  final lines = file.readAsLinesSync();
  return lines.asMap().entries.map((entry) {
    return DataPoint(entry.key / 1650000.0, double.parse(entry.value));
  }).toList();
}

void _saveFilterResults(String filename, List<DataPoint> points) {
  final file = File(filename);
  final buffer = StringBuffer();
  for (final point in points) {
    buffer.writeln(point.y);
  }
  file.writeAsStringSync(buffer.toString());
}

void main() {
  group('NoFilter', () {
    late NoFilter filter;
    late List<DataPoint> testPoints;

    setUp(() {
      filter = NoFilter();
      testPoints = List.generate(
        10,
        (i) => DataPoint(i.toDouble(), i.toDouble()),
      );
    });

    test('singleton instance works correctly', () {
      final instance1 = NoFilter();
      final instance2 = NoFilter();
      expect(identical(instance1, instance2), isTrue);
    });

    test('returns unmodified points', () {
      final result = filter.apply(testPoints, {});
      expect(result, equals(testPoints));
    });

    test('handles empty points list', () {
      final result = filter.apply([], {});
      expect(result, isEmpty);
    });
  });

  group('MovingAverageFilter', () {
    late MovingAverageFilter filter;
    late List<DataPoint> testPoints;

    setUp(() {
      filter = MovingAverageFilter();
      testPoints = List.generate(
        10,
        (i) => DataPoint(i.toDouble(), i.toDouble()),
      );
    });

    test('singleton instance works correctly', () {
      final instance1 = MovingAverageFilter();
      final instance2 = MovingAverageFilter();
      expect(identical(instance1, instance2), isTrue);
    });

    test('matches reference implementation', () {
      final testSignal =
          _loadTestSignal('test/unit_test/models/test_signal.csv');
      final referenceValues =
          _loadReferenceValues('test/unit_test/models/ma_filtered_ref.csv');

      final result = filter.apply(testSignal, {'windowSize': 3});
      _saveFilterResults('test/unit_test/models/ma_filtered_test.csv', result);

      for (var i = 0; i < result.length; i++) {
        expect(result[i].y, closeTo(referenceValues[i], 1e-6),
            reason: 'Mismatch at index $i');
      }
    });

    test('handles window size larger than points length', () {
      final result = filter.apply(testPoints, {'windowSize': 20});
      expect(result.length, equals(testPoints.length));
    });

    test('preserves x coordinates', () {
      final result = filter.apply(testPoints, {'windowSize': 3});
      for (int i = 0; i < testPoints.length; i++) {
        expect(result[i].x, equals(testPoints[i].x));
      }
    });
  });

  group('ExponentialFilter', () {
    late ExponentialFilter filter;
    late List<DataPoint> testPoints;

    setUp(() {
      filter = ExponentialFilter();
      testPoints = List.generate(
        10,
        (i) => DataPoint(i.toDouble(), i.toDouble()),
      );
    });

    test('singleton instance works correctly', () {
      final instance1 = ExponentialFilter();
      final instance2 = ExponentialFilter();
      expect(identical(instance1, instance2), isTrue);
    });

    test('matches reference implementation', () {
      final testSignal =
          _loadTestSignal('test/unit_test/models/test_signal.csv');
      final referenceValues =
          _loadReferenceValues('test/unit_test/models/exp_filtered_ref.csv');

      final result = filter.apply(testSignal, {'alpha': 0.5});
      _saveFilterResults('test/unit_test/models/exp_filtered_test.csv', result);

      for (var i = 5; i < result.length; i++) {
        expect(result[i].y, closeTo(referenceValues[i], 1e-2),
            reason: 'Mismatch at index $i');
      }
    });

    test('handles empty points list', () {
      final result = filter.apply([], {'alpha': 0.5});
      expect(result, isEmpty);
    });

    test('preserves x coordinates', () {
      final result = filter.apply(testPoints, {'alpha': 0.5});
      for (int i = 0; i < testPoints.length; i++) {
        expect(result[i].x, equals(testPoints[i].x));
      }
    });
  });

  group('LowPassFilter', () {
    late LowPassFilter filter;
    late List<DataPoint> testPoints;

    setUp(() {
      filter = LowPassFilter();
      testPoints = List.generate(100, (i) {
        final t = i / 1000.0;
        return DataPoint(
          t,
          math.sin(2 * math.pi * 10.0 * t),
        );
      });
    });

    test('matches reference implementation', () {
      final testSignal =
          _loadTestSignal('test/unit_test/models/test_signal.csv');
      final referenceValues =
          _loadReferenceValues('test/unit_test/models/lp_filtered_ref.csv');

      final result = filter.apply(testSignal, {
        'cutoffFrequency': 5000.0,
        'samplingFrequency': 1650000.0,
      });
      _saveFilterResults('test/unit_test/models/lp_filtered_test.csv', result);

      for (var i = 0; i < result.length; i++) {
        expect(result[i].y, closeTo(referenceValues[i], 1e-6),
            reason: 'Mismatch at index $i');
      }
    });

    test('attenuates high frequencies', () {
      final params = {
        'cutoffFrequency': 5.0,
        'samplingFrequency': 1000.0,
      };

      final result = filter.apply(testPoints, params);

      final inputRMS = math.sqrt(
          testPoints.map((p) => p.y * p.y).reduce((a, b) => a + b) /
              testPoints.length);

      final outputRMS = math.sqrt(
          result.map((p) => p.y * p.y).reduce((a, b) => a + b) / result.length);

      expect(outputRMS, lessThan(inputRMS));
    });

    test('handles empty points list', () {
      final params = {
        'cutoffFrequency': 5.0,
        'samplingFrequency': 1000.0,
      };

      final result = filter.apply([], params);
      expect(result, isEmpty);
    });

    test('preserves x coordinates', () {
      final params = {
        'cutoffFrequency': 5.0,
        'samplingFrequency': 1000.0,
      };

      final result = filter.apply(testPoints, params);
      for (int i = 0; i < testPoints.length; i++) {
        expect(result[i].x, equals(testPoints[i].x));
      }
    });
  });

  group('FilterType Equality', () {
    test('same type filters are equal', () {
      expect(NoFilter() == NoFilter(), isTrue);
      expect(MovingAverageFilter() == MovingAverageFilter(), isTrue);
      expect(ExponentialFilter() == ExponentialFilter(), isTrue);
      expect(LowPassFilter() == LowPassFilter(), isTrue);
    });

    test('different type filters are not equal', () {
      expect(NoFilter() == MovingAverageFilter(), isFalse);
      expect(MovingAverageFilter() == ExponentialFilter(), isFalse);
      expect(ExponentialFilter() == LowPassFilter(), isFalse);
    });

    test('hashCode is consistent', () {
      expect(NoFilter().hashCode == NoFilter().hashCode, isTrue);
      expect(MovingAverageFilter().hashCode == MovingAverageFilter().hashCode,
          isTrue);
      expect(
          ExponentialFilter().hashCode == ExponentialFilter().hashCode, isTrue);
      expect(LowPassFilter().hashCode == LowPassFilter().hashCode, isTrue);
    });
  });
}
