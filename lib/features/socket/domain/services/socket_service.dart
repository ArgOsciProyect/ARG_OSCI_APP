import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/repository/socket_repository.dart';
import 'package:flutter/foundation.dart';
import 'dart:math' as math;

/// Represents a single data measurement with bytes count, timestamp, and packet count
class Measurement {
  /// Number of bytes in the measurement
  final int bytes;

  /// When the measurement was taken
  final DateTime timestamp;

  /// Number of packets in this measurement
  final int packets;

  /// Creates a new measurement record
  ///
  /// [bytes] Count of bytes received
  /// [timestamp] When the measurement was taken
  /// [packets] Count of packets in this measurement
  Measurement(this.bytes, this.timestamp, this.packets);
}

/// Tracks and analyzes incoming data transmission statistics
///
/// Collects measurements of data transfer rates and provides statistical analysis
/// including mean, median, and standard deviation calculations.
class TransmissionStats {
  /// Collection of all measurements within the retention window
  final List<Measurement> measurements = [];

  /// Size of window used for rate calculations
  final Duration windowSize = Duration(seconds: 1);

  /// Adds a new measurement to the statistics collection
  ///
  /// [bytes] The number of bytes in the measurement
  /// [timestamp] When the measurement was taken
  /// [packets] Optional count of packets, defaults to 1
  void addMeasurement(int bytes, DateTime timestamp, [int packets = 1]) {
    measurements.add(Measurement(bytes, timestamp, packets));
    _cleanOldMeasurements();
  }

  /// Removes measurements older than 15 minutes to prevent memory buildup
  void _cleanOldMeasurements() {
    final cutoff = DateTime.now().subtract(Duration(minutes: 15));
    measurements.removeWhere((m) => m.timestamp.isBefore(cutoff));
  }

  /// Calculates bytes per second rate for a window of measurements
  ///
  /// [window] List of measurements to calculate rate from
  /// Returns bytes per second or 0 if insufficient data
  double _calculateRate(List<Measurement> window) {
    if (window.length < 2) return 0;
    final duration = window.last.timestamp
            .difference(window.first.timestamp)
            .inMicroseconds /
        1e6;
    final totalBytes = window.fold(0, (sum, m) => sum + m.bytes);
    return totalBytes / duration;
  }

  /// Calculates rates using a sliding window approach for all measurement periods
  ///
  /// Returns list of calculated rates for each sliding window
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

  /// Returns the mean (average) data transfer rate in bytes per second
  double get mean {
    final rates = _getSlidingWindowRates();
    if (rates.isEmpty) return 0;
    return rates.reduce((a, b) => a + b) / rates.length;
  }

  /// Returns the median data transfer rate in bytes per second
  ///
  /// The median represents the middle value when all rates are sorted,
  /// providing a value that is less affected by outliers than the mean.
  double get median {
    final rates = _getSlidingWindowRates()..sort();
    if (rates.isEmpty) return 0;
    final middle = rates.length ~/ 2;
    return (rates.length % 2 == 0)
        ? (rates[middle - 1] + rates[middle]) / 2
        : rates[middle];
  }

  /// Returns the standard deviation of data transfer rates
  ///
  /// Measures the amount of variation or dispersion from the average rate,
  /// indicating how consistent or variable the data transfer is.
  double get standardDeviation {
    final rates = _getSlidingWindowRates();
    if (rates.length < 2) return 0;
    final m = mean;
    final variance =
        rates.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) /
            (rates.length - 1);
    return math.sqrt(variance);
  }

  /// Returns the minimum data transfer rate observed in bytes per second
  double get min => _getSlidingWindowRates().fold(double.infinity, math.min);

  /// Returns the maximum data transfer rate observed in bytes per second
  double get max => _getSlidingWindowRates().fold(0, math.max);

  /// Generates a summary of all transmission statistics
  ///
  /// Returns a map containing key statistics including mean, median, min, max rates,
  /// packet rates, and measurement window information
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

/// Tracks and analyzes outgoing data transmission speed statistics
///
/// Collects measurements of data transfer speeds for sent messages and provides
/// statistical analysis including mean, median, and standard deviation.
class TransmissionSpeedStats {
  /// Collection of speed measurements within retention window
  final List<_SpeedMeasurement> _measurements = [];

  /// Adds a new speed measurement to the collection
  ///
  /// [bytes] Number of bytes sent
  /// [timestamp] When the transmission occurred
  /// [durationSeconds] How long the transmission took in seconds
  void addMeasurement(int bytes, DateTime timestamp, double durationSeconds) {
    if (durationSeconds > 0) {
      _measurements.add(_SpeedMeasurement(bytes, timestamp, durationSeconds));
      _cleanOldMeasurements();
    }
  }

  /// Removes measurements older than 15 minutes to prevent memory buildup
  void _cleanOldMeasurements() {
    final cutoff = DateTime.now().subtract(Duration(minutes: 15));
    _measurements.removeWhere((m) => m.timestamp.isBefore(cutoff));
  }

  /// Returns a list of all calculated speeds in bytes per second
  List<double> _getSpeeds() {
    return _measurements.map((m) => m.speed).toList();
  }

  /// Returns the mean (average) transmission speed in bytes per second
  double get mean {
    final speeds = _getSpeeds();
    if (speeds.isEmpty) return 0;
    return speeds.reduce((a, b) => a + b) / speeds.length;
  }

  /// Returns the median transmission speed in bytes per second
  ///
  /// The median represents the middle value when all speeds are sorted,
  /// providing a value that is less affected by outliers than the mean.
  double get median {
    final speeds = _getSpeeds()..sort();
    if (speeds.isEmpty) return 0;
    final middle = speeds.length ~/ 2;
    return (speeds.length % 2 == 0)
        ? (speeds[middle - 1] + speeds[middle]) / 2
        : speeds[middle];
  }

  /// Returns the standard deviation of transmission speeds
  ///
  /// Measures the amount of variation or dispersion from the average speed,
  /// indicating how consistent or variable the transmission speed is.
  double get standardDeviation {
    final speeds = _getSpeeds();
    if (speeds.length < 2) return 0;
    final m = mean;
    final variance =
        speeds.map((x) => math.pow(x - m, 2)).reduce((a, b) => a + b) /
            (speeds.length - 1);
    return math.sqrt(variance);
  }

  /// Returns the minimum transmission speed observed in bytes per second
  double get min => _getSpeeds().isEmpty ? 0 : _getSpeeds().reduce(math.min);

  /// Returns the maximum transmission speed observed in bytes per second
  double get max => _getSpeeds().isEmpty ? 0 : _getSpeeds().reduce(math.max);

  /// Generates a summary of all speed statistics
  ///
  /// Returns a map containing key statistics including mean, median, min, max speeds
  /// and the total number of measurements taken
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

/// Internal measurement class for tracking message transmission speed
///
/// Stores bytes sent, timestamp, and duration to calculate transmission speed
class _SpeedMeasurement {
  /// Number of bytes sent
  final int bytes;

  /// When the transmission occurred
  final DateTime timestamp;

  /// How long the transmission took in seconds
  final double durationSeconds;

  /// Creates a new speed measurement
  ///
  /// [bytes] Number of bytes sent
  /// [timestamp] When the transmission occurred
  /// [durationSeconds] How long the transmission took in seconds
  _SpeedMeasurement(this.bytes, this.timestamp, this.durationSeconds);

  /// Calculated speed in bytes per second
  double get speed => bytes / durationSeconds;
}

/// Implements [SocketRepository] to manage socket connections and data streaming
///
/// Handles connecting to the oscilloscope device, sending commands, and
/// processing incoming data packets of a specific expected size.
class SocketService implements SocketRepository {
  /// Active socket connection
  Socket? _socket;

  /// Broadcast controller for emitting data packets
  final _controller = StreamController<List<int>>.broadcast();

  /// Broadcast controller for emitting error events
  final _errorController = StreamController<Object>.broadcast();

  /// Collection of active data subscriptions
  final List<StreamSubscription<List<int>>> _subscriptions = [];

  /// Collection of active error subscriptions
  final List<StreamSubscription<Object>> _errorSubscriptions = [];

  /// Buffer for accumulating incoming data until complete packets are available
  final List<int> _buffer = [];

  /// Expected size of each data packet in bytes
  final int _expectedPacketSize;

  /// Current connection IP address
  String? _ip;

  /// Current connection port number
  int? _port;

  /// Statistics tracker for incoming data
  final TransmissionStats _stats = TransmissionStats();

  /// Timer for periodic measurement aggregation
  Timer? _measurementTimer;

  /// Accumulator for incoming bytes between measurements
  int _incomingBytesAcc = 0;

  /// Accumulator for incoming packets between measurements
  int _incomingPacketsAcc = 0;

  /// Timestamp of last measurement
  DateTime _lastMeasurementTime = DateTime.now();

  /// Statistics tracker for outgoing transmission speeds
  final TransmissionSpeedStats _speedStats = TransmissionSpeedStats();

  /// Creates a new socket service
  ///
  /// [_expectedPacketSize] The size in bytes expected for incoming data packets
  SocketService(this._expectedPacketSize);

  /// Registers an error handler for socket errors
  ///
  /// [handler] Function to call when socket errors occur
  /// The handler will receive the error object as parameter
  @override
  void onError(void Function(Object) handler) {
    final subscription = _errorController.stream.listen(handler);
    _errorSubscriptions.add(subscription);
  }

  /// Current connected IP address
  @override
  String? get ip => _ip;

  /// Current connected port number
  @override
  int? get port => _port;

  /// Expected size of incoming data packets in bytes
  @override
  int get expectedPacketSize => _expectedPacketSize;

  /// Raw data stream of incoming packets
  @override
  Stream<List<int>> get data => _controller.stream;

  /// Establishes a socket connection to the specified endpoint
  ///
  /// [connection] Connection parameters including IP and port
  /// Throws [SocketException] if connection fails
  @override
  Future<void> connect(SocketConnection connection) async {
    try {
      _socket = await Socket.connect(connection.ip.value, connection.port.value,
          timeout: Duration(seconds: 5));
      _ip = connection.ip.value;
      _port = connection.port.value;
      if (kDebugMode) {
        print("Connected to $_ip:$_port");
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

  /// Begins listening for incoming data on the socket connection
  ///
  /// Sets up data processing pipeline and error handling
  /// Throws [Exception] if socket is not connected
  @override
  void listen() {
    if (_socket != null) {
      // Use zones to catch otherwise unhandled errors
      runZonedGuarded(
        () {
          _socket!.listen(
            (data) {
              _processIncomingData(data);
              _incomingBytesAcc += data.length;
              _incomingPacketsAcc++;
            },
            onError: (error) {
              if (kDebugMode) {
                print("Socket listen error: $error");
              }
              _errorController.add(error);
            },
            onDone: () {
              _errorController.add(Exception('Socket connection closed'));
              _controller.close();
            },
          );
        },
        (error, stack) {
          if (kDebugMode) {
            print("Socket zoned error: $error");
          }
          _errorController.add(error);
        },
      );
    } else {
      throw Exception('Socket is not connected');
    }
  }

  /// Processes incoming data by buffering and emitting complete packets
  ///
  /// Accumulates incoming data in a buffer and extracts fixed-size packets
  /// when enough data is available. Complete packets are emitted through the
  /// data stream controller.
  ///
  /// [data] Raw incoming socket data
  void _processIncomingData(List<int> data) {
    _buffer.addAll(data);
    while (_buffer.length >= _expectedPacketSize) {
      final packet = _buffer.sublist(0, _expectedPacketSize);
      _buffer.removeRange(0, _expectedPacketSize);
      _controller.add(packet);
    }
  }

  /// Subscribes to the data stream with a callback function
  ///
  /// [onData] Function called for each received data packet
  /// Returns a subscription that can be used to cancel listening
  @override
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData) {
    final subscription = _controller.stream.listen(onData);
    _subscriptions.add(subscription);
    return subscription;
  }

  /// Cancels a data stream subscription
  ///
  /// [subscription] The subscription to cancel, previously returned by subscribe()
  @override
  void unsubscribe(StreamSubscription<List<int>> subscription) {
    subscription.cancel();
    _subscriptions.remove(subscription);
  }

  /// Sends a text message through the socket connection
  ///
  /// Appends a null terminator to the message before sending
  /// Tracks transmission speed statistics for the message
  ///
  /// [message] The text message to send
  /// Throws [Exception] if socket is not connected
  @override
  Future<void> sendMessage(String message) async {
    if (_socket != null) {
      // Append null terminator to the message
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

  /// Receives a single message from the socket
  ///
  /// Returns the decoded UTF-8 message
  /// Throws [Exception] if socket is not connected
  @override
  Future<String> receiveMessage() async {
    if (_socket != null) {
      return utf8.decode(await _controller.stream.first);
    } else {
      throw Exception('Socket is not connected');
    }
  }

  /// Closes the socket connection and cleans up all resources
  ///
  /// Cancels all subscriptions, timers, and closes streams
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

  /// Access to the underlying socket
  ///
  /// Used for direct socket operations in specialized cases
  // ignore: unnecessary_getters_setters
  Socket? get socket => _socket;

  /// Sets the underlying socket
  ///
  /// Used for testing or specialized socket initialization
  set socket(Socket? socket) => _socket = socket;

  /// Access to the underlying stream controller
  ///
  /// Used for direct stream operations or testing
  StreamController<List<int>> get controller => _controller;
}
