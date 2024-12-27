// lib/features/socket/domain/repository/socket_repository.dart
import 'dart:async';
import '../models/socket_connection.dart';

abstract class SocketRepository {
  /// Connects to a socket with the given connection parameters
  Future<void> connect(SocketConnection connection);

  /// Starts listening to incoming socket data
  void listen();

  /// Sends a message through the socket
  Future<void> sendMessage(String message);

  /// Receives a single message from the socket
  Future<String> receiveMessage();

  /// Closes the socket connection and all subscriptions
  Future<void> close();

  /// Subscribes to the data stream
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData);

  /// Unsubscribes from the data stream
  void unsubscribe(StreamSubscription<List<int>> subscription);

  /// Gets the data stream
  Stream<List<int>> get data;

  /// Gets current IP address
  dynamic get ip;

  /// Gets current port number  
  dynamic get port;
}