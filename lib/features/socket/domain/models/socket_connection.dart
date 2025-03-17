import 'package:get/get.dart';

/// [SocketConnection] manages the IP address and port for socket communication.
///
/// Provides reactive state management for connection parameters using GetX.
/// Allows for serialization to/from JSON for persistence or network transfer.
class SocketConnection extends GetxController {
  /// IP address of the socket connection
  final RxString ip;

  /// Port number of the socket connection
  final RxInt port;

  /// Creates a new socket connection with specified IP address and port
  ///
  /// [ip] Initial IP address for the connection
  /// [port] Initial port number for the connection
  SocketConnection(String ip, int port)
      : ip = ip.obs,
        port = port.obs;

  /// Creates a socket connection from a JSON map
  ///
  /// [json] Map containing 'ip' and 'port' keys
  /// Returns a new SocketConnection instance with the values from the map
  factory SocketConnection.fromJson(Map<String, dynamic> json) {
    return SocketConnection(
      json['ip'],
      json['port'],
    );
  }

  /// Converts the connection to a JSON-serializable map
  ///
  /// Returns a map containing 'ip' and 'port' keys with their current values
  Map<String, dynamic> toJson() {
    return {
      'ip': ip.value,
      'port': port.value,
    };
  }

  /// Updates the IP address and port of the socket connection.
  ///
  /// [newIp] New IP address to set
  /// [newPort] New port number to set
  /// The changes will automatically notify any reactive listeners
  void updateConnection(String newIp, int newPort) {
    ip.value = newIp;
    port.value = newPort;
  }
}
