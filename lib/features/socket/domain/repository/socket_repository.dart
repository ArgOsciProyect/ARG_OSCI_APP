import 'dart:async';

import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';

/// Repository interface for socket communication with oscilloscope device
abstract class SocketRepository {
  /// Connects to a socket with the given connection parameters
  /// 
  /// [connection] Connection parameters including IP and port
  /// Throws [SocketException] if connection fails
  Future<void> connect(SocketConnection connection);

  /// Starts listening to incoming socket data
  /// 
  /// Must be called after connect()
  /// Throws [StateError] if socket not connected
  void listen();

  /// Sends a text message through the socket
  /// 
  /// [message] Message to send
  /// Throws [StateError] if socket not connected
  /// Throws [SocketException] if send fails
  Future<void> sendMessage(String message);

  /// Receives a single message from the socket
  /// 
  /// Returns decoded message string
  /// Throws [StateError] if socket not connected
  Future<String> receiveMessage();

  /// Subscribes to the raw data stream
  /// 
  /// [onData] Callback for received data packets
  /// Returns subscription that can be used to unsubscribe
  StreamSubscription<List<int>> subscribe(void Function(List<int>) onData);

  /// Unsubscribes from the data stream
  /// 
  /// [subscription] Subscription returned from subscribe()
  void unsubscribe(StreamSubscription<List<int>> subscription);

  /// Sets error handler for socket errors
  /// 
  /// [handler] Error callback function
  void onError(void Function(Object) handler);

  /// Closes the socket connection and all subscriptions
  /// 
  /// Flushes pending data before closing
  Future<void> close();

  /// Raw data stream of incoming packets
  Stream<List<int>> get data;

  /// Current connected IP address
  String? get ip;

  /// Current connected port number 
  int? get port;

  /// Expected size of incoming data packets
  int get expectedPacketSize;
}