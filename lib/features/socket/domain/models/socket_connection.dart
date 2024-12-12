// lib/features/socket/domain/models/socket_connection.dart
import 'package:get/get.dart';

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

  void updateConnection(String newIp, int newPort) {
    ip.value = newIp;
    port.value = newPort;
  }
}