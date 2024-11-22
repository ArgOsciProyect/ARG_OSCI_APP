// lib/features/socket/domain/repository/socket_repository.dart
import '../models/socket_connection.dart';

abstract class SocketRepository {
  Future<void> connect(SocketConnection connection);
  Future<void> sendMessage(String message);
  Future<String> receiveMessage();
  Future<void> close();
}