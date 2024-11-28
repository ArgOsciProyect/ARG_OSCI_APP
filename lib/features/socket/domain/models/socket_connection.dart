/// A class representing a socket connection with an IP address and port.
///
/// The [SocketConnection] class provides a way to store and manage the
/// connection details for a socket, including the IP address and port number.
///
/// Example usage:
/// ```dart
/// var connection = SocketConnection('192.168.1.1', 8080);
/// print(connection.ip); // Output: 192.168.1.1
/// print(connection.port); // Output: 8080
/// ```
///
/// The class also includes helper functions to convert the connection details
/// to and from JSON format.
///
/// Example usage of JSON conversion:
/// ```dart
/// var json = {'ip': '192.168.1.1', 'port': 8080};
/// var connection = SocketConnection.fromJson(json);
/// print(connection.ip); // Output: 192.168.1.1
/// print(connection.port); // Output: 8080
///
/// var connectionJson = connection.toJson();
/// print(connectionJson); // Output: {ip: 192.168.1.1, port: 8080}
/// ```
// lib/features/socket/domain/models/socket_connection.dart
class SocketConnection {
  final String ip;
  final int port;

  SocketConnection(this.ip, this.port);

  // JSON to/from Dart helper functions
  factory SocketConnection.fromJson(Map<String, dynamic> json) {
    return SocketConnection(
      json['ip'],
      json['port'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip,
      'port': port,
    };
  }
}