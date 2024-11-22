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