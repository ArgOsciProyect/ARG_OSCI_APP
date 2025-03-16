import 'data_point.dart';

import 'dart:math' as math;

/// Helper mixin providing bidirectional filtering functionality
///
/// Implements forward-backward filtering (filtfilt) with various initializations
/// to minimize transient effects at signal boundaries. This approach results
/// in zero-phase filtering that preserves signal timing.
mixin FiltfiltHelper {
  /// Computes initial state for filter to minimize boundary effects
  ///
  /// Calculates the initial filter state based on filter coefficients
  /// to ensure continuity at signal boundaries.
  ///
  /// [b] Filter numerator coefficients
  /// [a] Filter denominator coefficients
  /// Returns initial filter state vector
  List<double> _computeFInitialState(List<double> b, List<double> a) {
    final n = math.max(b.length, a.length);
    // Ensure both vectors have length n (zero padding)
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

    // Calculate cumulative sum in reverse order
    final revDiff = diff.reversed.toList();
    List<double> cumsum = [];
    double sum = 0.0;
    for (final v in revDiff) {
      sum += v;
      cumsum.add(sum);
    }
    final siFull = cumsum.reversed.toList();
    return siFull.sublist(1); // Return n-1 elements
  }

  /// Applies filter with specified initial state to input signal
  ///
  /// Implements single-pass filtering with specified initial conditions
  /// using direct form II transposed structure.
  ///
  /// [b] Filter numerator coefficients
  /// [a] Filter denominator coefficients
  /// [x] Input signal
  /// [zi] Initial filter state
  /// Returns filtered signal
  List<double> _lfilterWithInit(
      List<double> b, List<double> a, List<double> x, List<double> zi) {
    final int nSamples = x.length;
    final m = math.max(b.length, a.length) - 1;
    final y = List<double>.filled(nSamples, 0.0);
    final z = List<double>.from(zi); // State vector of length m
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

  /// Applies single-direction filtering with automatically calculated initial state
  ///
  /// [b] Filter numerator coefficients
  /// [a] Filter denominator coefficients
  /// [x] Input signal
  /// Returns filtered signal
  List<double> _singleFilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    // Calculate initial conditions
    final si = _computeFInitialState(b, a);
    final initFwd = si.map((v) => v * x.first).toList();
    return _lfilterWithInit(b, a, x, initFwd);
  }

  /// Applies zero-phase forward-backward filtering
  ///
  /// Processes signal in forward and backward directions to achieve
  /// zero-phase response. Uses signal reflection at boundaries to
  /// minimize edge effects.
  ///
  /// [b] Filter numerator coefficients
  /// [a] Filter denominator coefficients
  /// [x] Input signal
  /// Returns filtered signal with zero phase distortion
  /// Throws exception if signal is too short for filtering
  List<double> _filtfilt(List<double> b, List<double> a, List<double> x) {
    if (x.isEmpty) return [];
    final n = math.max(b.length, a.length);
    final lrefl = 3 * (n - 1);
    if (x.length <= lrefl) {
      throw Exception("Signal length must be > $lrefl");
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

/// Abstract base class for all signal filter implementations
///
/// Defines the interface for filters that can be applied to oscilloscope data.
/// All concrete filter implementations must extend this class and implement
/// the apply method with consistent behavior.
abstract class FilterType {
  /// User-friendly name of the filter for display in UI
  String get name;

  /// Applies the filter to a list of data points
  ///
  /// [points] Input data points to be filtered
  /// [params] Filter-specific parameters
  /// [doubleFilt] Whether to apply bidirectional filtering
  /// Returns filtered data points with preserved metadata
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

/// No-operation filter that passes data through unchanged
///
/// Implements the FilterType interface but performs no actual filtering.
/// Used as a baseline option and for bypassing the filter system.
class NoFilter extends FilterType {
  static final NoFilter _instance = NoFilter._internal();
  factory NoFilter() => _instance;
  NoFilter._internal();

  @override
  String get name => 'None';

  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params,
      {bool doubleFilt = true}) {
    return points; // NoFilter returns points unmodified, preserving all properties
  }
}

/// Implements a moving average filter
///
/// Smooths signals by averaging each point with its neighbors within
/// a specified window size. The implementation uses bidirectional
/// filtering to maintain zero phase response.
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

    // Preserve all original properties of each point
    return List.generate(
        points.length,
        (i) => DataPoint(points[i].x, filtered[i],
            isTrigger: points[i].isTrigger,
            isInterpolated: points[i].isInterpolated));
  }
}

/// Implements an exponential filter (first-order IIR)
///
/// Smooths signals using exponential weighting, where each output sample
/// is a weighted combination of the current input and previous output.
/// The alpha parameter controls the cutoff frequency, with smaller values
/// producing more aggressive smoothing.
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
        throw Exception("Signal length must be > $lrefl");
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

      // Preserve all original properties of each point
      return List.generate(
          points.length,
          (i) => DataPoint(points[i].x, filtered[i],
              isTrigger: points[i].isTrigger,
              isInterpolated: points[i].isInterpolated));
    } else {
      final filtered = _singleFilt(b, a, signal);

      // Preserve all original properties of each point
      return List.generate(
          points.length,
          (i) => DataPoint(points[i].x, filtered[i],
              isTrigger: points[i].isTrigger,
              isInterpolated: points[i].isInterpolated));
    }
  }
}

/// Implements a second-order Butterworth low-pass filter
///
/// Attenuates high-frequency components while preserving low frequencies
/// based on a specified cutoff frequency. The implementation uses a
/// digital Butterworth filter with bidirectional filtering for zero phase.
class LowPassFilter extends FilterType with FiltfiltHelper {
  @override
  String get name => 'Low Pass';

  List<double> _butterB = [];
  List<double> _butterA = [];

  /// Designs a second-order Butterworth low-pass filter
  ///
  /// Calculates filter coefficients for the specified cutoff frequency
  /// using the bilinear transform.
  ///
  /// [cutoff] Cutoff frequency in Hz
  /// [fs] Sampling frequency in Hz
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

    // Preserve all original properties of each point
    return List.generate(
        points.length,
        (i) => DataPoint(points[i].x, filtered[i],
            isTrigger: points[i].isTrigger,
            isInterpolated: points[i].isInterpolated));
  }
}
