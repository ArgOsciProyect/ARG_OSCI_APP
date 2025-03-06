import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/repository/socket_repository.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

class Measurement {
  final int bytes;
  final DateTime timestamp;
  final int packets;

  Measurement(this.bytes, this.timestamp, this.packets);
}

/// Class to hold transmission statistics (bytes rate from incoming data)
class TransmissionStats {
  final List<Measurement> measurements = [];
  final Duration windowSize = Duration(seconds: 1);

  void addMeasurement(int bytes, DateTime timestamp, [int packets = 1]) {
    measurements.add(Measurement(bytes, timestamp, packets));
    _cleanOldMeasurements();
  }

  void _cleanOldMeasurements() {
    final cutoff = DateTime.now().subtract(Duration(minutes: 15));
    measurements.removeWhere((m) => m.timestamp.isBefore(cutoff));
  }

  double _calculateRate(List<Measurement> window) {
    if (window.length < 2) return 0;
    final duration = window.last.timestamp
            .difference(window.first.timestamp)
            .inMicroseconds /
        1e6;
    final totalBytes = window.fold(0, (sum, m) => sum + m.bytes);
    return totalBytes / duration;
  }

  List<double> _getSlidingWindowRates() {
    if (measurements.isEmpty) return [];
    final rates = <double>[];
    var windowStart = 0;
    while (windowStart < measurements.length) {
      var windowEnd = windowStart;
      while (windowEnd < measurements.length &&
          measurements[windowEnd]
                  .timestamp
                  .difference(measurements[windowStart].timestamp) <=
              windowSize) {
        windowEnd++;
      }
      final window = measurements.sublist(windowStart, windowEnd);
      final rate = _calculateRate(window);
      if (rate > 0) rates.add(rate);
      windowStart++;
    }
    return rates;
  }

  double get mean {
    final rates = _getSlidingWindowRates();
    if (rates.isEmpty) return 0;
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  double get median {
    final rates = _getSlidingWindowRates()..sort();
    if (rates.isEmpty) return 0;
    final middle = rates.length ~/ 2;
    return (rates.length % 2 == 0)
        ? (rates[middle - 1] + rates[middle]) / 2
        : rates[middle];
  }

  double get standardDeviation {
    final rates = _getSlidingWindowRates();
    if (rates.length < 2) return 0;
    final m = mean;
    final variance =
        rates.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) /
            (rates.length - 1);
    return math.sqrt(variance);
  }

  double get min => _getSlidingWindowRates().fold(double.infinity, math.min);

  double get max => _getSlidingWindowRates().fold(0, math.max);

  Map<String, dynamic> getSummary() {
    final packetsPerSecond = measurements.isEmpty
        ? 0
        : measurements.length /
            measurements.last.timestamp
                .difference(measurements.first.timestamp)
                .inSeconds;
    return {
      'mean_bps': mean,
      'median_bps': median,
      'std_dev_bps': standardDeviation,
      'min_bps': min,
      'max_bps': max,
      'packets_per_second': packetsPerSecond,
      'total_packets': measurements.length,
      'measurement_window_seconds': measurements.isEmpty
          ? 0
          : measurements.last.timestamp
              .difference(measurements.first.timestamp)
              .inSeconds,
    };
  }
}

/// New class to measure the transmission speed of outgoing messages
/// (i.e. the speed at which the socket sends and flushes a message)
class TransmissionSpeedStats {
  final List<_SpeedMeasurement> _measurements = [];

  void addMeasurement(int bytes, DateTime timestamp, double durationSeconds) {
    if (durationSeconds > 0) {
      _measurements.add(_SpeedMeasurement(bytes, timestamp, durationSeconds));
      _cleanOldMeasurements();
    }
  }

  void _cleanOldMeasurements() {
    final cutoff = DateTime.now().subtract(Duration(minutes: 15));
    _measurements.removeWhere((m) => m.timestamp.isBefore(cutoff));
  }

  List<double> _getSpeeds() {
    return _measurements.map((m) => m.speed).toList();
  }

  double get mean {
    final speeds = _getSpeeds();
    if (speeds.isEmpty) return 0;
    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  double get median {
    final speeds = _getSpeeds()..sort();
    if (speeds.isEmpty) return 0;
    final middle = speeds.length ~/ 2;
    return (speeds.length % 2 == 0)
        ? (speeds[middle - 1] + speeds[middle]) / 2
        : speeds[middle];
  }

  double get standardDeviation {
    final speeds = _getSpeeds();
    if (speeds.length < 2) return 0;
    final m = mean;
    final variance =
        speeds.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) /
            (speeds.length - 1);
    return math.sqrt(variance);
  }

  double get min => _getSpeeds().isEmpty ? 0 : _getSpeeds().reduce(math.min);

  double get max => _getSpeeds().isEmpty ? 0 : _getSpeeds().reduce(math.max);

  Map<String, dynamic> getSummary() {
    return {
      'mean_speed_bps': mean,
      'median_speed_bps': median,
      'std_dev_speed_bps': standardDeviation,
      'min_speed_bps': min,
      'max_speed_bps': max,
      'total_measurements': _measurements.length,
    };
  }
}

class _SpeedMeasurement {
  final int bytes;
  final DateTime timestamp;
  final double durationSeconds; // in seconds
  _SpeedMeasurement(this.bytes, this.timestamp, this.durationSeconds);

  double get speed => bytes / durationSeconds;
}

/// [SocketService] implements the [SocketRepository] to manage socket connections and data streaming.
class SocketService implements SocketRepository {
  Socket? _socket;
  final _controller = StreamController<List<int>>.broadcast();
  final _errorController = StreamController<Object>.broadcast();
  final List<StreamSubscription<List<int>>> _subscriptions = [];
  final List<StreamSubscription<Object>> _errorSubscriptions = [];
  final List<int> _buffer = [];
  final int _expectedPacketSize;
  String? _ip;
  int? _port;
  final TransmissionStats _stats = TransmissionStats();
  // Timer for aggregating incoming data measurements without per-packet overhead.
  Timer? _measurementTimer;
  int _incomingBytesAcc = 0;
  int _incomingPacketsAcc = 0;
  DateTime _lastMeasurementTime = DateTime.now();
  // New field for tracking outgoing transmission speeds.
  final TransmissionSpeedStats _speedStats = TransmissionSpeedStats();

  SocketService(this._expectedPacketSize);

  @override
  void onError(void Function(Object) handler) {
    final subscription = _errorController.stream.listen(handler);
    _errorSubscriptions.add(subscription);
  }

  @override
  String? get ip => _ip;

  @override
  int? get port => _port;

  @override
  int get expectedPacketSize => _expectedPacketSize;

  @override
  Stream<List<int>> get data => _controller.stream;

  @override
  Future<void> connect(SocketConnection connection) async {
    try {
      _socket = await Socket.connect(connection.ip.value, connection.port.value,
          timeout: Duration(seconds: 5));
      _ip = connection.ip.value;
      _port = connection.port.value;
      if (kDebugMode) {
        print("Connected to $_ip:$_port");
        // Timer to periodically print incoming data stats (every minute)
        // Timer to aggregate incoming data measurements (every second)
        _measurementTimer = Timer.periodic(Duration(seconds: 1), (_) {
          final now = DateTime.now();
          final elapsed =
              now.difference(_lastMeasurementTime).inMicroseconds / 1e6;
          if (_incomingBytesAcc > 0 && elapsed > 0) {
            _stats.addMeasurement(_incomingBytesAcc, now, _incomingPacketsAcc);
          }
          _incomingBytesAcc = 0;
          _incomingPacketsAcc = 0;
          _lastMeasurementTime = now;
        });
      }
      _socket!.handleError((error) {
        _errorController.add(error);
      });
    } catch (e) {
      throw SocketException('Failed to connect: $e');
    }
  }

  @override
  void listen() {
    if (_socket != null) {
      _socket!.listen(
        (data) {
          _processIncomingData(data);
          // Instead of calling addMeasurement on every packet,
          // accumulate data for periodic measurement.
          _incomingBytesAcc += data.length;
          _incomingPacketsAcc++;
        },
        onError: (error) {
          _errorController.add(error);
          _controller.addError(error);
        },
        onDone: () {
          _errorController.add(Exception('Socket connection closed'));
          _controller.close();
        },
      );
    } else {
      throw Exception('Socket is not connected');
    }
  }

  /// Processes incoming data by buffering and emitting complete packets.
  void _processIncomingData(List<int> data) {
    _buffer.addAll(data);
    while (_buffer.length >= _expectedPacketSize) {
      final packet = _buffer.sublist(0, _expectedPacketSize);
      _buffer.removeRange(0, _expectedPacketSize);
      _controller.add(packet);
    }
  }

  @override
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData) {
    final subscription = _controller.stream.listen(onData);
    _subscriptions.add(subscription);
    return subscription;
  }

  @override
  void unsubscribe(StreamSubscription<List<int>> subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  @override
  Future<void> sendMessage(String message) async {
    if (_socket != null) {
      // ignore: prefer_interpolation_to_compose_strings, unnecessary_string_escapes
      String nulledMessage = message + '\0';
      final data = utf8.encode(nulledMessage);
      final start = DateTime.now();
      _socket!.write(data);
      await _socket!.flush();
      final end = DateTime.now();
      final durationSeconds = end.difference(start).inMicroseconds / 1e6;
      // Record the transmission speed measurement (bytes per second)
      _speedStats.addMeasurement(data.length, start, durationSeconds);
    } else {
      throw Exception('Socket is not connected');
    }
  }

  @override
  Future<String> receiveMessage() async {
    if (_socket != null) {
      return utf8.decode(await _controller.stream.first);
    } else {
      throw Exception('Socket is not connected');
    }
  }

  @override
  Future<void> close() async {
    _measurementTimer?.cancel();
    for (var subscription in _errorSubscriptions) {
      await subscription.cancel();
    }
    _errorSubscriptions.clear();
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await _socket?.flush();
    _socket?.destroy();
    await _controller.close();
    await _errorController.close();
  }

  // Getters and setters
  // ignore: unnecessary_getters_setters
  Socket? get socket => _socket;
  set socket(Socket? socket) => _socket = socket;
  StreamController<List<int>> get controller => _controller;
}
