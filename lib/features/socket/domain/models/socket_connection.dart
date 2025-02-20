import 'package:get/get.dart';

/// [SocketConnection] manages the IP address and port for socket communication.
class SocketConnection extends GetxController {
  final RxString ip;
  final RxInt port;

  SocketConnection(String ip, int port)
      : ip = ip.obs,
        port = port.obs;

  // JSON to/from Dart helper functions
  factory SocketConnection.fromJson(Map<String, dynamic> json) {
    return SocketConnection(
      json['ip'],
      json['port'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'ip': ip.value,
      'port': port.value,
    };
  }

  /// Updates the IP address and port of the socket connection.
  void updateConnection(String newIp, int newPort) {
    ip.value = newIp;
    port.value = newPort;
  }
}
