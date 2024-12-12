// lib/features/setup/domain/repository/setup_repository.dart
import '../models/wifi_credentials.dart';

abstract class SetupRepository {
  Future<void> connectToWiFi(WiFiCredentials credentials);
  Future<List<String>> scanForWiFiNetworks();
  Future<void> connectToLocalAP();
  Future<void> selectMode(String mode);
  Future<void> handleNetworkChangeAndConnect(String ssid);
  Future<void> waitForNetworkChange(String ssid);
}