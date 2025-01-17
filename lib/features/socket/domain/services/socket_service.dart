// lib/features/socket/domain/services/socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/socket_connection.dart';
import '../repository/socket_repository.dart';

class SocketService implements SocketRepository {
  Socket? _socket;
  final _controller = StreamController<List<int>>.broadcast();
  final List<StreamSubscription<List<int>>> _subscriptions = [];
  @override
  dynamic ip;
  @override
  dynamic port;

  @override
  Future<void> connect(SocketConnection connection) async {
    _socket = await Socket.connect(connection.ip.value, connection.port.value,
        timeout: Duration(seconds: 5));
    ip = connection.ip.value;
    port = connection.port.value;
    print("connected");
  }

  @override
  void listen() {
    if (_socket != null) {
      _socket!.listen(
        (data) {
          _controller.add(data);
        },
        onError: (error) {
          _controller.addError(error);
        },
        onDone: () {
          _controller.close();
        },
      );
    } else {
      throw Exception('Socket is not connected');
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
    for (var subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
    await socket?.flush();
    _socket?.destroy();
    await _controller.close();
  }

  @override
  Stream<List<int>> get data => _controller.stream;

  // Getters and setters
  Socket? get socket => _socket;
  set socket(Socket? socket) => _socket = socket;
  StreamController<List<int>> get controller => _controller;
}
