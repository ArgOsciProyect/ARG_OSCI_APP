import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/repository/socket_repository.dart';
import 'package:flutter/foundation.dart';

import 'dart:math' as math;

/// Class to hold transmission statistics
class TransmissionStats {
  final List<double> bytesPerSecond = [];
  final List<DateTime> timestamps = [];

  void addMeasurement(int bytes, DateTime timestamp) {
    timestamps.add(timestamp);

    // Calculate bytes/second if we have at least 2 measurements
    if (timestamps.length > 1) {
      final duration = timestamp
              .difference(timestamps[timestamps.length - 2])
              .inMicroseconds /
          1000000.0;
      final bps = bytes / duration;
      bytesPerSecond.add(bps);
    }
  }

  /// Calculate mean bytes per second
  double get mean {
    if (bytesPerSecond.isEmpty) return 0;
    return bytesPerSecond.reduce((a, b) => a + b) / bytesPerSecond.length;
  }

  /// Calculate median bytes per second
  double get median {
    if (bytesPerSecond.isEmpty) return 0;
    final sorted = List<double>.from(bytesPerSecond)..sort();
    final middle = sorted.length ~/ 2;
    if (sorted.length % 2 == 0) {
      return (sorted[middle - 1] + sorted[middle]) / 2;
    }
    return sorted[middle];
  }

  /// Calculate standard deviation
  double get standardDeviation {
    if (bytesPerSecond.length < 2) return 0;
    final m = mean;
    final variance =
        bytesPerSecond.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) /
            (bytesPerSecond.length - 1);
    return math.sqrt(variance);
  }

  /// Calculate minimum rate
  double get min =>
      bytesPerSecond.isEmpty ? 0 : bytesPerSecond.reduce(math.min);

  /// Calculate maximum rate
  double get max =>
      bytesPerSecond.isEmpty ? 0 : bytesPerSecond.reduce(math.max);

  /// Get statistics summary
  Map<String, double> getSummary() {
    return {
      'mean_bps': mean,
      'median_bps': median,
      'std_dev_bps': standardDeviation,
      'min_bps': min,
      'max_bps': max,
    };
  }
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
  Timer? _statsTimer;

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
        // Setup statistics timer once at connection
        _statsTimer = Timer.periodic(Duration(minutes: 15), (_) {
          final summary = _stats.getSummary();
          print('\n=== Transmission Statistics (15min) ===');
          print(
              'Mean rate: ${summary['mean_bps']?.toStringAsFixed(2)} bytes/sec');
          print(
              'Median rate: ${summary['median_bps']?.toStringAsFixed(2)} bytes/sec');
          print(
              'Std Dev: ${summary['std_dev_bps']?.toStringAsFixed(2)} bytes/sec');
          print(
              'Min rate: ${summary['min_bps']?.toStringAsFixed(2)} bytes/sec');
          print(
              'Max rate: ${summary['max_bps']?.toStringAsFixed(2)} bytes/sec');
          print('======================================\n');
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
          if (kDebugMode) {
            _stats.addMeasurement(data.length, DateTime.now());
          }
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

  /// Subscribes to the data stream.
  ///
  /// Returns a [StreamSubscription] that can be used to manage the subscription.
  @override
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData) {
    final subscription = _controller.stream.listen(onData);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Unsubscribes from the data stream.
  ///
  /// Takes a [StreamSubscription] that was returned by [subscribe].
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
      _socket!.write(utf8.encode(nulledMessage));
      await _socket!.flush();
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
    // Cancel error subscriptions
    for (var subscription in _errorSubscriptions) {
      await subscription.cancel();
    }
    _errorSubscriptions.clear();

    // Cancel data subscriptions
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
