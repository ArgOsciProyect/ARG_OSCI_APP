// lib/features/socket/domain/services/socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/socket_connection.dart';
import '../repository/socket_repository.dart';

class SocketService implements SocketRepository {
  Socket? _socket;
  final _controller = StreamController<String>();

  @override
  Future<void> connect(SocketConnection connection) async {
    _socket = await Socket.connect(connection.ip, connection.port);
    _socket!.listen(
      (data) {
        final message = utf8.decode(data);
        _controller.add(message);
      },
      onError: (error) {
        _controller.addError(error);
      },
      onDone: () {
        _controller.close();
      },
    );
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
      return await _controller.stream.first;
    } else {
      throw Exception('Socket is not connected');
    }
  }

  @override
  Future<void> close() async {
    await _socket?.close();
    await _controller.close();
  }
}