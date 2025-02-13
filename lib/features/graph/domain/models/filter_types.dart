import 'dart:math';

import 'data_point.dart';

abstract class FilterType {
  String get name;
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params);

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is FilterType && other.runtimeType == runtimeType;
  }

  @override
  int get hashCode => runtimeType.hashCode;
}

class NoFilter extends FilterType {
  static final NoFilter _instance = NoFilter._internal();
  factory NoFilter() => _instance;
  NoFilter._internal();

  @override
  String get name => 'None';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    return points;
  }
}

class MovingAverageFilter extends FilterType {
  static final MovingAverageFilter _instance = MovingAverageFilter._internal();
  factory MovingAverageFilter() => _instance;
  MovingAverageFilter._internal();

  @override
  String get name => 'Moving Average';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final windowSize = params['windowSize'] as int;
    if (points.isEmpty) return [];

    // Create growable list for padding
    final paddedPoints = <double>[];
    paddedPoints.addAll(List.filled(windowSize - 1, points.first.y));
    paddedPoints.addAll(points.map((p) => p.y));

    final b = List.filled(windowSize, 1.0 / windowSize);
    final filteredPoints = <DataPoint>[];

    for (int i = 0; i < points.length; i++) {
      double sum = 0.0;
      for (int j = 0; j < windowSize; j++) {
        sum += b[j] * paddedPoints[i + windowSize - 1 - j];
      }
      filteredPoints.add(DataPoint(points[i].x, sum));
    }

    return filteredPoints;
  }
}

class ExponentialFilter extends FilterType {
  static final ExponentialFilter _instance = ExponentialFilter._internal();
  factory ExponentialFilter() => _instance;
  ExponentialFilter._internal();

  @override
  String get name => 'Exponential';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final alpha = params['alpha'] as double;
    final filteredPoints = <DataPoint>[];
    if (points.isEmpty) return filteredPoints;

    filteredPoints.add(points.first);
    for (int i = 1; i < points.length; i++) {
      final currentY = points[i].y;
      final lastFilteredY = filteredPoints.last.y;
      final newY = alpha * currentY + (1 - alpha) * lastFilteredY;
      filteredPoints.add(DataPoint(points[i].x, newY));
    }
    return filteredPoints;
  }
}

class LowPassFilter extends FilterType {
  @override
  String get name => 'Low Pass';

  List<double> _butterB = [];
  List<double> _butterA = [];

  void _designButter(double cutoff, double fs) {
    // Normalized cutoff frequency (0..1, where 1 corresponds to Nyquist)
    final wn = cutoff / (fs / 2);
    final k = tan(pi * wn / 2);
    final sqrt2 = sqrt(2.0);
    final a0 = k * k + sqrt2 * k + 1;
    _butterB = [k * k / a0, 2 * k * k / a0, k * k / a0];
    _butterA = [
      1.0,
      2 * (k * k - 1.0) / a0,
      (k * k - sqrt2 * k + 1) / a0,
    ];
  }

  /// Compute initial state vector based on Likhterov & Kopeika (as in Octave’s filtfilt)
  List<double> _computeFInitialState(List<double> b, List<double> a) {
    final kdc = b.reduce((s, v) => s + v) / a.reduce((s, v) => s + v);
    final diff = List<double>.generate(b.length, (i) => b[i] - kdc * a[i]);
    // Compute cumulative sum on reversed diff
    final revDiff = diff.reversed.toList();
    List<double> cumsum = [];
    double sum = 0.0;
    for (final v in revDiff) {
      sum += v;
      cumsum.add(sum);
    }
    // Reverse again and drop first element
    final siFull = cumsum.reversed.toList();
    return siFull.sublist(1); // length = order (here 2)
  }

  /// Direct-form II transposed lfilter with initial state [length = order]
  List<double> _lfilterWithInit(
      List<double> b, List<double> a, List<double> x, List<double> zi) {
    final n = x.length;
    final y = List<double>.filled(n, 0.0);
    // Clone initial state
    final z = List<double>.from(zi);
    for (int i = 0; i < n; i++) {
      final xn = x[i];
      final yn = b[0] * xn + z[0];
      y[i] = yn;
      // Update states:
      // z[0] = b[1]*xn - a[1]*yn + z[1]
      // z[1] = b[2]*xn - a[2]*yn
      z[0] = b[1] * xn - a[1] * yn + z[1];
      z[1] = b[2] * xn - a[2] * yn;
    }
    return y;
  }

  /// filtfilt implementation that mimics Octave's behavior,
  /// including boundary state initialization.
  List<double> _filtfilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    // Filter order: n = max(length(b), length(a)) → for our butter(2) n = 3.
    const n = 3;
    const lrefl = 3 * (n - 1); // Reflection length (6)
    if (x.length <= lrefl) {
      throw Exception("Signal length must be > $lrefl");
    }

    // Build extended signal using mirror reflection (as in Octave):
    // Front: 2*x[0] - x[lrefl] ... 2*x[0] - x[1]
    List<double> front = List<double>.generate(lrefl, (i) {
      return 2 * x.first - x[lrefl - i];
    });
    // Back: 2*x[last] - x[end-1] ... 2*x[last] - x[end-lrefl]
    List<double> back = List<double>.generate(lrefl, (i) {
      return 2 * x.last - x[x.length - 2 - i];
    });
    final ext = <double>[...front, ...x, ...back];

    // Compute initial state vector from filter coefficients.
    final si = _computeFInitialState(b, a);
    // Forward filtering initialization: scale si by ext.first.
    final initFwd = si.map((v) => v * ext.first).toList();
    var y = _lfilterWithInit(b, a, ext, initFwd);
    // Reverse the signal
    y = y.reversed.toList();
    // Backward filtering: initialize with si scaled by first element of reversed signal.
    final initBwd = si.map((v) => v * y.first).toList();
    y = _lfilterWithInit(b, a, y, initBwd);
    y = y.reversed.toList();

    // Remove the added padding.
    return y.sublist(lrefl, y.length - lrefl);
  }

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    if (points.isEmpty) return [];
    final cutoff = params['cutoffFrequency'] as double;
    final fs = params['samplingFrequency'] as double;
    _designButter(cutoff, fs);
    final signal = points.map((p) => p.y).toList();
    final filtered = _filtfilt(_butterB, _butterA, signal);
    return List.generate(
        points.length, (i) => DataPoint(points[i].x, filtered[i]));
  }
}
