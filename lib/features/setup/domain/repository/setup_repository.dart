// lib/features/setup/domain/repository/setup_repository.dart
import '../models/wifi_credentials.dart';

abstract class SetupRepository {
  Future<void> connectToWiFi(WiFiCredentials credentials);
  Future<List<String>> scanForWiFiNetworks();
  Future<void> sendMessage(String message);
  Future<String> receiveMessage();
}