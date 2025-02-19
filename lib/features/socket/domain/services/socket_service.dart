import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/repository/socket_repository.dart';
import 'package:flutter/foundation.dart';

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

      // Use private fields directly
      _ip = connection.ip.value;
      _port = connection.port.value;

      if (kDebugMode) {
        print("Connected to $_ip:$_port");
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

    // Process packets if enough data is available
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
