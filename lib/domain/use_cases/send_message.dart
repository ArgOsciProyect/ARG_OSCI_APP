// lib/domain/use_cases/send_message.dart
import '../entities/socket_connection.dart';

class SendMessage {
  final SocketConnection socketConnection;

  SendMessage(this.socketConnection);

  Future<void> call(String message) async {
    socketConnection.sendMessage(message);
  }
}