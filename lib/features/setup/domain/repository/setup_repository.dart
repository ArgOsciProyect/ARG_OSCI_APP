// lib/features/setup/domain/repository/setup_repository.dart
import 'package:http/http.dart' as http;
import '../models/wifi_credentials.dart';

abstract class SetupRepository {
  /// Initializes HTTP configuration with given base URL
  Future<void> initializeGlobalHttpConfig(String baseUrl,
      {http.Client? client});

  /// Initializes socket connection with given IP and port
  Future<void> initializeGlobalSocketConnection(String ip, int port);

  /// Connects to a WiFi network using provided credentials
  Future<void> connectToWiFi(WiFiCredentials credentials);

  /// Scans for available WiFi networks
  Future<List<String>> scanForWiFiNetworks();

  /// Encrypts a message using the public key
  String encriptWithPublicKey(String message);

  /// Selects operation mode (External AP or Internal AP)
  Future<void> selectMode(String mode, {http.Client? client});

  /// Handles network change and establishes connection
  Future<void> handleNetworkChangeAndConnect(String ssid, String password,
      {http.Client? client});

  /// Connects to the local access point
  Future<void> connectToLocalAP({http.Client? client});

  /// Waits for network to change to specified SSID
  Future<void> waitForNetworkChange(String ssid);
}
