// lib/features/socket/domain/repository/socket_repository.dart
import '../models/socket_connection.dart';

/// An abstract class that defines the contract for a socket repository.
/// This repository handles socket connections, sending and receiving messages,
/// and closing the connection.
abstract class SocketRepository {
  /// Connects to a socket using the provided [SocketConnection].
  ///
  /// Throws an exception if the connection fails.
  Future<void> connect(SocketConnection connection);

  /// Listens for incoming messages or events from the socket.
  ///
  /// This method should be implemented to handle incoming data.
  void listen();

  /// Sends a [message] through the socket.
  ///
  /// Throws an exception if the message fails to send.
  Future<void> sendMessage(String message);

  /// Receives a message from the socket.
  ///
  /// Returns the received message as a [String].
  /// Throws an exception if receiving the message fails.
  Future<String> receiveMessage();

  /// Closes the socket connection.
  ///
  /// Throws an exception if closing the connection fails.
  Future<void> close();
}