// lib/features/socket/domain/services/socket_service.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../models/socket_connection.dart';
import '../repository/socket_repository.dart';

class SocketService implements SocketRepository {
  Socket? _socket;
  final _controller = StreamController<String>.broadcast();

  /// Establishes a connection to a socket server.
  ///
  /// This method attempts to connect to a socket server using the provided
  /// [SocketConnection] object, which contains the IP address and port number.
  /// The connection attempt will timeout after 5 seconds if it is not successful.
  ///
  /// Throws a [SocketException] if the connection fails.
  ///
  /// Prints "connected" to the console upon a successful connection.
  ///
  /// [connection] - The [SocketConnection] object containing the IP address and port number.
  ///
  /// Example usage:
  /// ```dart
  /// final connection = SocketConnection(ip: '192.168.1.1', port: 8080);
  /// await socketService.connect(connection);
  /// ```
  @override
  Future<void> connect(SocketConnection connection) async {
    _socket = await Socket.connect(connection.ip, connection.port, timeout: Duration(seconds: 5));
    print("conected");
  }

  /// Listens for data from the socket and adds it to the stream controller.
  ///
  /// If the socket is connected, it listens for incoming data, decodes it
  /// using UTF-8, and adds the decoded message to the stream controller.
  /// If an error occurs, it adds the error to the stream controller.
  /// When the socket is done, it closes the stream controller.
  ///
  /// Throws an [Exception] if the socket is not connected.
  @override
  void listen() {
    if (_socket != null) {
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
    } else {
      throw Exception('Socket is not connected');
    }
  }

  /// Sends a message through the socket connection.
  ///
  /// The message is appended with a null character (`\0`) before being sent.
  /// If the socket is not connected, an exception is thrown.
  ///
  /// [message] The message to be sent.
  ///
  /// Throws an [Exception] if the socket is not connected.
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

  /// Receives a message from the socket connection.
  ///
  /// This method listens to the first event from the stream controller
  /// and returns it as a string. If the socket is not connected, it throws
  /// an exception.
  ///
  /// Returns:
  ///   A [Future] that completes with the received message as a [String].
  ///
  /// Throws:
  ///   An [Exception] if the socket is not connected.
  @override
  Future<String> receiveMessage() async {
    if (_socket != null) {
      return await _controller.stream.first;
    } else {
      throw Exception('Socket is not connected');
    }
  }

  Stream<String> get messages => _controller.stream;

  /// Closes the socket connection and the associated stream controller.
  ///
  /// This method ensures that the socket connection is properly closed
  /// and the stream controller is also closed to release any resources.
  /// It is an asynchronous operation and should be awaited to ensure
  /// that the closing process completes before proceeding.
  @override
  Future<void> close() async {
    await _socket?.close();
    await _controller.close();
  }

  // Getters and setters
  Socket? get socket => _socket;
  set socket(Socket? socket) => _socket = socket;
  StreamController<String> get controller => _controller;
}