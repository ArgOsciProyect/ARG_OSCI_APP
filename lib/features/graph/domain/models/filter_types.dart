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
        final z_next = (j < m - 1) ? z[j + 1] : 0.0;
        final bj = (j + 1 < b.length) ? b[j + 1] : 0.0;
        final aj = (j + 1 < a.length) ? a[j + 1] : 0.0;
        z[j] = bj * xn - aj * yn + z_next;
      }
    }
    return y;
  }

  List<double> _filtfilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    final n = math.max(b.length, a.length);
    final lrefl = 3 * (n - 1); // Número de muestras de extensión
    if (x.length <= lrefl) {
      throw Exception("La longitud de la señal debe ser > $lrefl");
    }
    // Construir la señal extendida mediante reflexión (modo espejo)
    List<double> front = List<double>.generate(lrefl, (i) {
      return 2 * x.first - x[lrefl - i];
    });
    List<double> back = List<double>.generate(lrefl, (i) {
      return 2 * x.last - x[x.length - 2 - i];
    });
    final ext = <double>[]
      ..addAll(front)
      ..addAll(x)
      ..addAll(back);
    // Calcular condiciones iniciales (inspirado en Likhterov & Kopeika)
    final si = _computeFInitialState(b, a);
    final initFwd = si.map((v) => v * ext.first).toList();
    var y = _lfilterWithInit(b, a, ext, initFwd);
    y = y.reversed.toList();
    final initBwd = si.map((v) => v * y.first).toList();
    y = _lfilterWithInit(b, a, y, initBwd);
    y = y.reversed.toList();
    // Extraer exactamente L muestras (L = x.length)
    return y.sublist(lrefl, lrefl + x.length);
  }
}

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

class MovingAverageFilter extends FilterType with FiltfiltHelper {
  static final MovingAverageFilter _instance = MovingAverageFilter._internal();
  factory MovingAverageFilter() => _instance;
  MovingAverageFilter._internal();

  @override
  String get name => 'Moving Average';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final windowSize = params['windowSize'] as int;
    // Si la señal es más corta que el tamaño de ventana, se devuelve sin filtrar.
    if (points.isEmpty || points.length < windowSize) return points;
    // Para cualquier windowSize: b = [1/windowSize, ..., 1/windowSize] y a = [1, 0, ..., 0]
    final b = List<double>.filled(windowSize, 1 / windowSize);
    final a = [1.0]..addAll(List.filled(windowSize - 1, 0.0));
    final signal = points.map((p) => p.y).toList();
    final filtered = _filtfilt(b, a, signal);
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
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    final alpha = params['alpha'] as double;
    if (points.isEmpty) return [];
    // Coeficientes para el filtro exponencial
    final b = [alpha, 0.0, 0.0];
    final a = [1.0, -(1 - alpha), 0.0];
    final signal = points.map((p) => p.y).toList();

    final n = math.max(b.length, a.length);
    final lrefl = 3 * (n - 1);
    if (signal.length <= lrefl) {
      throw Exception("La longitud de la señal debe ser > $lrefl");
    }
    // Extender la señal por reflexión (modo espejo)
    List<double> front = List<double>.generate(lrefl, (i) {
      return 2 * signal.first - signal[lrefl - i];
    });
    List<double> back = List<double>.generate(lrefl, (i) {
      return 2 * signal.last - signal[signal.length - 2 - i];
    });
    final ext = <double>[...front, ...signal, ...back];

    final si = _computeFInitialState(b, a);
    // Se utiliza 2 * signal.first en las condiciones iniciales para corregir
    final initFwd = si.map((v) => v * signal.first * 2).toList();
    var y = _lfilterWithInit(b, a, ext, initFwd);
    y = y.reversed.toList();
    // Igualmente, aplicar factor 2 en el filtrado inverso
    final initBwd = si.map((v) => v * y.first * 2).toList();
    y = _lfilterWithInit(b, a, y, initBwd);
    y = y.reversed.toList();
    final filtered = y.sublist(lrefl, lrefl + signal.length);
    return List.generate(
        points.length, (i) => DataPoint(points[i].x, filtered[i]));
  }
}

class LowPassFilter extends FilterType with FiltfiltHelper {
  @override
  String get name => 'Low Pass';

  List<double> _butterB = [];
  List<double> _butterA = [];

  void _designButter(double cutoff, double fs) {
    // Frecuencia de corte normalizada (0..1, donde 1 corresponde a Nyquist)
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
