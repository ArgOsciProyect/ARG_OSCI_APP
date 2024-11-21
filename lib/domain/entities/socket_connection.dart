// lib/domain/entities/socket_connection.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SocketConnection {
  late Socket _socket;
  final _controller = StreamController<String>();

  Future<void> connect(String ip, int port) async {
    _socket = await Socket.connect(ip, port);
    _socket.listen(
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

  void sendMessage(String message) {
    final encodedMessage = utf8.encode(message + '\0');
    _socket.add(encodedMessage);
  }

  Future<String> receiveMessage() async {
    return await _controller.stream.first;
  }

  void close() {
    _socket.close();
    _controller.close();
  }
}