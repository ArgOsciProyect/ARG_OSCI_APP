import 'data_point.dart';

import 'dart:math' as math;

mixin FiltfiltHelper {
  List<double> _computeFInitialState(List<double> b, List<double> a) {
    final n = math.max(b.length, a.length);
    // Asegurar que ambos vectores tengan longitud n (zero padding)
    final bPadded = List<double>.from(b);
    while (bPadded.length < n) {
      bPadded.add(0.0);
    }
    final aPadded = List<double>.from(a);
    while (aPadded.length < n) {
      aPadded.add(0.0);
    }

    final kdc =
        bPadded.reduce((s, v) => s + v) / aPadded.reduce((s, v) => s + v);
    final diff = List<double>.generate(n, (i) => bPadded[i] - kdc * aPadded[i]);

    // Cálculo de la suma acumulada en orden inverso
    final revDiff = diff.reversed.toList();
    List<double> cumsum = [];
    double sum = 0.0;
    for (final v in revDiff) {
      sum += v;
      cumsum.add(sum);
    }
    final siFull = cumsum.reversed.toList();
    return siFull.sublist(1); // Devuelve n-1 elementos
  }

  List<double> _lfilterWithInit(
      List<double> b, List<double> a, List<double> x, List<double> zi) {
    final int nSamples = x.length;
    final m = math.max(b.length, a.length) - 1;
    final y = List<double>.filled(nSamples, 0.0);
    final z = List<double>.from(zi); // Estado de longitud m
    for (int i = 0; i < nSamples; i++) {
      final xn = x[i];
      final yn = b[0] * xn + z[0];
      y[i] = yn;
      for (int j = 0; j < m; j++) {
        final zNext = (j < m - 1) ? z[j + 1] : 0.0;
        final bj = (j + 1 < b.length) ? b[j + 1] : 0.0;
        final aj = (j + 1 < a.length) ? a[j + 1] : 0.0;
        z[j] = bj * xn - aj * yn + zNext;
      }
    }
    return y;
  }

  List<double> _singleFilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    // Calculate initial conditions
    final si = _computeFInitialState(b, a);
    final initFwd = si.map((v) => v * x.first).toList();
    return _lfilterWithInit(b, a, x, initFwd);
  }

  List<double> _filtfilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    final n = math.max(b.length, a.length);
    final lrefl = 3 * (n - 1);
    if (x.length <= lrefl) {
      throw Exception("La longitud de la señal debe ser > $lrefl");
    }
    // Build extended signal using reflection (mirror mode)
    List<double> front = List<double>.generate(lrefl, (i) {
      return 2 * x.first - x[lrefl - i];
    });
    List<double> back = List<double>.generate(lrefl, (i) {
      return 2 * x.last - x[x.length - 2 - i];
    });
    final ext = <double>[...front, ...x, ...back];

    final si = _computeFInitialState(b, a);
    final initFwd = si.map((v) => v * ext.first).toList();
    var y = _lfilterWithInit(b, a, ext, initFwd);
    y = y.reversed.toList();
    final initBwd = si.map((v) => v * y.first).toList();
    y = _lfilterWithInit(b, a, y, initBwd);
    y = y.reversed.toList();

    return y.sublist(lrefl, lrefl + x.length);
  }
}

abstract class FilterType {
  String get name;
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true});

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
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true}) {
    return points;
  }
}

class MovingAverageFilter extends FilterType with FiltfiltHelper {
  static final MovingAverageFilter _instance = MovingAverageFilter._internal();
  factory MovingAverageFilter() => _instance;
  MovingAverageFilter._internal();

  @override
  String get name => 'Moving Average';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true}) {
    final windowSize = params['windowSize'] as int;
    if (points.isEmpty || points.length < windowSize) return points;

    final b = List<double>.filled(windowSize, 1 / windowSize);
    final a = [1.0, ...List.filled(windowSize - 1, 0.0)];
    final signal = points.map((p) => p.y).toList();

    final filtered =
        doubleFilt ? _filtfilt(b, a, signal) : _singleFilt(b, a, signal);

    return List.generate(
        points.length, (i) => DataPoint(points[i].x, filtered[i]));
  }
}

class ExponentialFilter extends FilterType with FiltfiltHelper {
  static final ExponentialFilter _instance = ExponentialFilter._internal();
  factory ExponentialFilter() => _instance;
  ExponentialFilter._internal();

  @override
  String get name => 'Exponential';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true}) {
    final alpha = params['alpha'] as double;
    if (points.isEmpty) return [];

    final b = [alpha, 0.0, 0.0];
    final a = [1.0, -(1 - alpha), 0.0];
    final signal = points.map((p) => p.y).toList();

    if (doubleFilt) {
      final n = math.max(b.length, a.length);
      final lrefl = 3 * (n - 1);
      if (signal.length <= lrefl) {
        throw Exception("La longitud de la señal debe ser > $lrefl");
      }
      // Extended signal with reflection
      List<double> front = List<double>.generate(lrefl, (i) {
        return 2 * signal.first - signal[lrefl - i];
      });
      List<double> back = List<double>.generate(lrefl, (i) {
        return 2 * signal.last - signal[signal.length - 2 - i];
      });
      final ext = <double>[...front, ...signal, ...back];

      final si = _computeFInitialState(b, a);
      final initFwd = si.map((v) => v * signal.first * 2).toList();
      var y = _lfilterWithInit(b, a, ext, initFwd);
      y = y.reversed.toList();
      final initBwd = si.map((v) => v * y.first * 2).toList();
      y = _lfilterWithInit(b, a, y, initBwd);
      y = y.reversed.toList();
      final filtered = y.sublist(lrefl, lrefl + signal.length);
      return List.generate(
          points.length, (i) => DataPoint(points[i].x, filtered[i]));
    } else {
      final filtered = _singleFilt(b, a, signal);
      return List.generate(
          points.length, (i) => DataPoint(points[i].x, filtered[i]));
    }
  }
}

class LowPassFilter extends FilterType with FiltfiltHelper {
  @override
  String get name => 'Low Pass';

  List<double> _butterB = [];
  List<double> _butterA = [];

  void _designButter(double cutoff, double fs) {
    final wn = cutoff / (fs / 2);
    final k = math.tan(math.pi * wn / 2);
    final sqrt2 = math.sqrt(2.0);
    final a0 = k * k + sqrt2 * k + 1;
    _butterB = [k * k / a0, 2 * k * k / a0, k * k / a0];
    _butterA = [
      1.0,
      2 * (k * k - 1.0) / a0,
      (k * k - sqrt2 * k + 1) / a0,
    ];
  }

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true}) {
    if (points.isEmpty) return [];
    final cutoff = params['cutoffFrequency'] as double;
    final fs = params['samplingFrequency'] as double;
    _designButter(cutoff, fs);

    final signal = points.map((p) => p.y).toList();
    final filtered = doubleFilt
        ? _filtfilt(_butterB, _butterA, signal)
        : _singleFilt(_butterB, _butterA, signal);

    return List.generate(
        points.length, (i) => DataPoint(points[i].x, filtered[i]));
  }
}
