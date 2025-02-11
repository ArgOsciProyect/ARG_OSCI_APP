import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:http/http.dart' as http;

/// Repository interface for device setup and network configuration
abstract class SetupRepository {
  /// Initializes HTTP configuration with given base URL
  ///
  /// [baseUrl] Base URL for HTTP requests
  /// [client] Optional HTTP client for testing
  Future<void> initializeGlobalHttpConfig(String baseUrl,
      {http.Client? client});

  /// Initializes socket connection with given IP and port
  ///
  /// [ip] Target device IP address
  /// [port] Target device port number
  Future<void> initializeGlobalSocketConnection(String ip, int port);

  /// Connects device to WiFi network using provided credentials
  ///
  /// [credentials] Encrypted WiFi credentials
  /// Returns true if connection successful
  /// Throws [SetupException] if connection fails
  Future<bool> connectToWiFi(WiFiCredentials credentials);

  /// Scans for available WiFi networks
  ///
  /// Returns list of SSID strings
  /// Throws [SetupException] if scan fails
  Future<List<String>> scanForWiFiNetworks();

  /// Encrypts message using device public key
  ///
  /// [message] Plain text message to encrypt
  /// Returns Base64 encoded encrypted string
  /// Throws if public key not available
  String encriptWithPublicKey(String message);

  /// Sets device operation mode
  ///
  /// [mode] Either 'Internal AP' or 'External AP'
  /// [client] Optional HTTP client for testing
  Future<void> selectMode(String mode, {http.Client? client});

  /// Handles network change and connects to new network
  ///
  /// [ssid] Network SSID to connect to
  /// [password] Network password
  /// [client] Optional HTTP client for testing
  /// Throws [SetupException] if connection fails
  Future<void> handleNetworkChangeAndConnect(String ssid, String password,
      {http.Client? client});

  /// Connects to device access point
  ///
  /// [client] Optional HTTP client for testing
  /// Throws [SetupException] if connection fails
  Future<void> connectToLocalAP({http.Client? client});

  /// Waits for network to change to specified SSID
  ///
  /// [ssid] Expected network SSID
  /// Times out after 30 seconds
  Future<void> waitForNetworkChange(String ssid);

  /// Fetches device configuration
  ///
  /// Returns parsed DeviceConfig
  /// Throws [SetupException] if fetch fails
  Future<void> fetchDeviceConfig();
}
