import 'dart:async';
import 'dart:convert';
import 'dart:io';

class SocketService {
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
    _socket.write(message + '\0');
  }

  Future<String> receiveMessage() async {
    return await _controller.stream.first;
  }

  void close() {
    _socket.close();
    _controller.close();
  }
}