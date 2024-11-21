// lib/domain/use_cases/receive_message.dart
import '../entities/socket_connection.dart';

class ReceiveMessage {
  final SocketConnection socketConnection;

  ReceiveMessage(this.socketConnection);

  Future<String> call() async {
    return await socketConnection.receiveMessage();
  }
}