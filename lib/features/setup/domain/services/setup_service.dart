import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:arg_osci_app/features/setup/domain/repository/setup_repository.dart';
import 'package:arg_osci_app/features/setup/widgets/wifi_credentials_dialog.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:encrypt/encrypt.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/export.dart';
import 'package:network_info_plus/network_info_plus.dart';
import 'package:http/http.dart' as http;
import 'dart:io';
import 'dart:math';
import 'package:wifi_iot/wifi_iot.dart';

/// [NetworkInfoService] provides network-related information and connection functionalities.
class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final HttpService _httpService;
  static const String _baseUrl = 'http://192.168.4.1:81';

  // Default credentials
  String _apSsid = 'ESP32_AP';
  String _apPassword = 'password123';

  NetworkInfoService() : _httpService = HttpService(HttpConfig(_baseUrl));

  /// Sets custom WiFi credentials for ESP32 AP
  void setApCredentials(String ssid, String password) {
    _apSsid = ssid;
    _apPassword = password;
  }

  /// Attempts to connect to the ESP32 access point with retries.
  Future<bool> connectWithRetries() async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      if (kDebugMode) {
        print("Connection attempt ${attempt + 1}/$maxRetries");
      }

      if (await connectToESP32()) {
        return true;
      }

      if (attempt < maxRetries - 1) {
        if (kDebugMode) {
          print("Retrying in ${retryDelay.inSeconds} second...");
        }
        await Future.delayed(retryDelay);
      }
    }

    if (kDebugMode) {
      print("Failed to connect after $maxRetries attempts");
    }
    return false;
  }

  /// Tests the connection to the ESP32 by making a GET request with improved error handling.
  Future<bool> testConnection() async {
    try {
      await _httpService.get('/testConnect', skipNavigation: true).timeout(
            const Duration(seconds: 5),
            onTimeout: () => throw TimeoutException('Connection timed out'),
          );
      return true;
    } on TimeoutException catch (e) {
      if (kDebugMode) {
        print('Test connection timed out: $e');
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Test connection failed: $e');
      }
      return false;
    }
  }

  /// Attempts to connect to the ESP32 access point with improved null handling.
  Future<bool> connectToESP32() async {
    if (!Platform.isAndroid) return false;

    try {
      // First attempt: WiFiForIoTPlugin with retries
      const pluginRetries = 5;
      const pluginInterval = Duration(seconds: 1);

      if (kDebugMode) {
        print("Attempting to connect to $_apSsid using IoT plugin...");
      }

      for (int i = 0; i < pluginRetries; i++) {
        try {
          bool connected = await WiFiForIoTPlugin.connect(
            _apSsid,
            password: _apPassword,
            security: NetworkSecurity.WPA,
            joinOnce: true,
            withInternet: false,
            timeoutInSeconds: 10,
          );

          if (connected) {
            if (kDebugMode) {
              print("WiFi connection successful via IoT plugin");
            }
            await Future.delayed(const Duration(seconds: 2));

            // Force WiFi usage safely
            try {
              final forceResult = await WiFiForIoTPlugin.forceWifiUsage(true)
                  .timeout(const Duration(seconds: 5));

              if (forceResult) {
                final testResult = await testConnection();
                if (testResult) {
                  if (kDebugMode) {
                    print("Connection verified successfully via IoT plugin");
                  }
                  return true;
                }
              }
            } catch (e) {
              if (kDebugMode) {
                print('Error forcing WiFi usage: $e');
              }
            }
          }

          if (i < pluginRetries - 1) {
            if (kDebugMode) {
              print(
                  "Plugin connection attempt ${i + 1}/$pluginRetries failed, retrying...");
            }
            await Future.delayed(pluginInterval);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Plugin connection error on attempt ${i + 1}: $e');
          }
          if (i == pluginRetries - 1) break;
          await Future.delayed(pluginInterval);
        }
      }

      // Fallback: Traditional SSID verification
      if (kDebugMode) {
        print("IoT plugin connection failed, trying traditional method...");
      }

      const traditionalRetries = 30;
      const checkInterval = Duration(seconds: 1);

      for (int i = 0; i < traditionalRetries; i++) {
        try {
          String? currentSSID = await getWifiName();
          if (currentSSID != null) {
            currentSSID = currentSSID.replaceAll('"', '');

            if (currentSSID == _apSsid) {
              if (kDebugMode) {
                print("Connected to $_apSsid via traditional method");
              }

              // Test connection with proper error handling
              if (await testConnection()) {
                if (kDebugMode) {
                  print(
                      "Connection verified successfully via traditional method");
                }
                return true;
              }
            }
          }

          if (i < traditionalRetries - 1) {
            if (kDebugMode) {
              print(
                  "Waiting for $_apSsid connection... (${i + 1}/$traditionalRetries)");
            }
            await Future.delayed(checkInterval);
          }
        } catch (e) {
          if (kDebugMode) {
            print('Traditional method error on attempt ${i + 1}: $e');
          }
          if (i == traditionalRetries - 1) break;
          await Future.delayed(checkInterval);
        }
      }

      if (kDebugMode) {
        print("Failed to connect via both methods");
      }
      return false;
    } catch (e) {
      if (kDebugMode) {
        print('Fatal error connecting to ESP32: $e');
      }
      return false;
    }
  }

  /// Gets the current WiFi network name.
  Future<String?> getWifiName() async {
    try {
      final name = await _networkInfo.getWifiName();
      // Return empty string instead of null to avoid null checks
      return name?.isNotEmpty == true ? name : null;
    } catch (e) {
      if (kDebugMode) {
        print('Error getting WiFi name: $e');
      }
      return null;
    }
  }

  /// Gets the current WiFi IP address.
  Future<String?> getWifiIP() async {
    return _networkInfo.getWifiIP();
  }

  /// Check if device is connected to a specific WiFi network
  Future<bool> isConnectedToNetwork(String ssid) async {
    String? currentSSID = await getWifiName();
    if (Platform.isAndroid && currentSSID != null) {
      currentSSID = currentSSID.replaceAll('"', '');
    }

    return currentSSID == ssid;
  }
}

/// [SetupService] implements the [SetupRepository] to manage device setup and network configuration.
class SetupService implements SetupRepository {
  SocketConnection globalSocketConnection;
  HttpConfig globalHttpConfig;
  late HttpService localHttpService;
  RSAPublicKey? _publicKey;
  final NetworkInfoService _networkInfo = NetworkInfoService();

  late dynamic extIp;
  late dynamic extPort;
  late dynamic _pubKey;

  /// Generates a random word for testing the connection.
  String _generateRandomWord() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  SetupService(this.globalSocketConnection, this.globalHttpConfig) {
    localHttpService = HttpService(globalHttpConfig);
  }

  @override
  Future<void> fetchDeviceConfig() async {
    final response = await HttpService(globalHttpConfig)
        .get('/config', skipNavigation: true);
    final config = DeviceConfig.fromJson(response);
    Get.find<DeviceConfigProvider>().updateConfig(config);
  }

  @override
  Future<void> initializeGlobalHttpConfig(String baseUrl,
      {http.Client? client}) async {
    globalHttpConfig = HttpConfig(baseUrl, client: client);
    localHttpService = HttpService(globalHttpConfig);
  }

  @override
  Future<void> initializeGlobalSocketConnection(String ip, int port) async {
    globalSocketConnection.updateConnection(ip, port);
  }

  @override
  Future<bool> connectToWiFi(WiFiCredentials credentials) async {
    if (kDebugMode) {
      print("Connecting ESP32 to WiFi");
    }
    try {
      final response = await localHttpService
          .post('/connect_wifi', credentials.toJson(), true) // Skip navigation
          .timeout(Duration(seconds: 20));

      if (response['Success'] == "false") {
        return false;
      }

      extIp = response['IP'];
      extPort = response['Port'];

      if (kDebugMode) {
        print("ip recibido: $extIp");
      }
      if (kDebugMode) {
        print("port recibido: $extPort");
      }
      return true;
    } on TimeoutException {
      throw SetupException('Connection attempt timed out');
    } catch (e) {
      throw SetupException('Failed to connect: $e');
    }
  }

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    try {
      // Fetch the public key from the device
      final publicKeyResponse = await localHttpService
          .get('/get_public_key', skipNavigation: false)
          .timeout(Duration(seconds: 5));

      _pubKey = publicKeyResponse;
      RSAAsymmetricKey key = RSAKeyParser().parse(_pubKey["PublicKey"]);
      _publicKey = key as RSAPublicKey;

      // Scan for available WiFi networks
      final wifiResponse = await localHttpService
          .get('/scan_wifi', skipNavigation: false)
          .timeout(Duration(seconds: 15));

      final wifiData = wifiResponse as List;
      if (wifiData.isEmpty) {
        throw SetupException('No WiFi networks found');
      }

      return wifiData.map((item) => item['SSID'] as String).toList();
    } catch (e) {
      throw SetupException('Failed to scan networks: $e');
    }
  }

  @override
  String encriptWithPublicKey(String message) {
    if (_publicKey == null) {
      throw Exception('Public key is not set');
    }
    final encrypter =
        Encrypter(RSA(publicKey: _publicKey, encoding: RSAEncoding.PKCS1));
    final encrypted = encrypter.encrypt(message);
    return encrypted.base64;
  }

  @override
  Future<void> selectMode(String mode, {http.Client? client}) async {
    final response =
        await localHttpService.get('/internal_mode', skipNavigation: true);
    if (mode == 'Internal AP') {
      final ip = response['IP'];
      final port = response['Port'];
      await initializeGlobalHttpConfig('http://$ip:81', client: client);
      await initializeGlobalSocketConnection(ip, port);
      await fetchDeviceConfig();
    }
  }

  @override
  Future<void> handleNetworkChangeAndConnect(String ssid, String password,
      {http.Client? client}) async {
    if (kDebugMode) {
      print("Testing connection to network");
    }

    await initializeGlobalHttpConfig('http://$extIp:80', client: client);
    if (Platform.isAndroid) {
      await WiFiForIoTPlugin.forceWifiUsage(false)
          .timeout(const Duration(seconds: 5));
    }

    int maxTestRetries = 50;
    String testWord = _generateRandomWord();
    String encryptedWord = encriptWithPublicKey(testWord);

    final testRequest = {'word': encryptedWord};

    // Retry the connection test multiple times
    for (int i = 0; i < maxTestRetries; i++) {
      try {
        // print("Posting to: ${globalHttpConfig.baseUrl}");
        final response = await HttpService(globalHttpConfig)
            .post('/test', testRequest, true)
            .timeout(const Duration(seconds: 5));

        if (response['decrypted'] == testWord) {
          if (kDebugMode) {
            print("Connection verified - correct network");
          }
          await initializeGlobalSocketConnection(extIp, extPort);
          fetchDeviceConfig();
          return;
        } else {
          if (kDebugMode) {
            print("Connection test failed: incorrect response");
            print("Expected: $testWord, Received: ${response['decrypted']}");
            print("Crude Response: $response");
          }
        }
      } on TimeoutException {
        if (kDebugMode) {
          print("Connection test attempt ${i + 1} timed out");
        }
        if (i == maxTestRetries - 1) {
          throw TimeoutException('Failed to verify connection - timeout');
        }
        await Future.delayed(const Duration(seconds: 1));
      } catch (e) {
        if (kDebugMode) {
          print("Connection test attempt ${i + 1} failed: $e");
        }
        if (i == maxTestRetries - 1) {
          throw Exception(
              'Failed to verify connection after $maxTestRetries attempts');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    throw Exception('Failed to verify connection to correct network');
  }

  @override
  Future<void> connectToLocalAP({http.Client? client}) async {
    // Show credentials dialog for all platforms
    Map<String, String>? credentials = await Get.dialog<Map<String, String>>(
      const WiFiCredentialsDialog(),
      barrierDismissible: false,
    );

    if (credentials == null) {
      // User canceled the dialog
      throw SetupException('Setup canceled by user');
    }

    // Set the target SSID for any platform
    final targetSsid = credentials['ssid'] ?? 'ESP32_AP';

    if (Platform.isAndroid) {
      // For Android, use WiFiForIoTPlugin to connect automatically
      _networkInfo.setApCredentials(
        targetSsid,
        credentials['password'] ?? 'password123',
      );

      final connected = await _networkInfo.connectWithRetries();
      if (!connected) {
        // Show error message
        Get.snackbar(
          'Connection Failed',
          'Failed to connect to $targetSsid. Please check credentials and try again.',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        throw SetupException('Failed to connect to $targetSsid');
      }
    } else {
      // For other platforms, guide the user to connect manually
      Get.snackbar(
        'Manual Connection Required',
        'Please connect your device to the $targetSsid WiFi network in your device settings.',
        snackPosition: SnackPosition.BOTTOM,
        duration: const Duration(seconds: 8),
      );

      // Wait for the user to connect to the specified network
      const maxWaitTime = Duration(minutes: 2);
      final startTime = DateTime.now();

      while (true) {
        // Check if we've exceeded the maximum wait time
        if (DateTime.now().difference(startTime) > maxWaitTime) {
          throw TimeoutException(
              'Connection timeout: Please connect to $targetSsid network');
        }

        // Check if connected to the target network with careful null handling
        String? currentSSID = await _networkInfo.getWifiName();

        // Break early on null to avoid null checks
        if (currentSSID == null) {
          await Future.delayed(const Duration(seconds: 1));
          continue;
        }

        if (Platform.isIOS) {
          // On iOS, remove quotes that might be around SSID
          currentSSID = currentSSID.replaceAll('"', '');
        }

        if (currentSSID.startsWith(targetSsid)) {
          if (kDebugMode) {
            print("Successfully connected to $targetSsid");
          }
          break;
        }

        if (kDebugMode) {
          print(
              'Waiting for connection to $targetSsid. Current network: $currentSSID');
        }
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    await Future.delayed(const Duration(seconds: 2));

    // Safely log WiFi connection details
    try {
      final wifiName = await _networkInfo.getWifiName() ?? "Unknown";
      final wifiIP = await _networkInfo.getWifiIP() ?? "Unknown";

      if (kDebugMode) {
        print('Connected to WiFi: $wifiName');
        print('IP address: $wifiIP');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error getting WiFi information: $e');
      }
    }

    await initializeGlobalHttpConfig('http://192.168.4.1:81', client: client);
  }

  @override
  Future<void> waitForNetworkChange(String ssid) async {
    const maxAttempts = 60; // 1 minute timeout
    int attempts = 0;

    while (attempts < maxAttempts) {
      attempts++;

      try {
        String? wifiName = await _networkInfo.getWifiName();

        // Skip iteration if wifi name is null
        if (wifiName == null) {
          await Future.delayed(Duration(seconds: 1));
          continue;
        }

        if (Platform.isAndroid) {
          wifiName = wifiName.replaceAll('"', '');
        }

        // Wait until the WiFi name starts with the expected SSID
        if (wifiName.startsWith(ssid)) {
          if (kDebugMode) {
            print("Successfully connected to $ssid network");
          }
          return;
        }

        if (kDebugMode && attempts % 5 == 0) {
          // Log only every 5 attempts to reduce spam
          if (kDebugMode) {
            print(
                "Current WiFi: $wifiName, Expected WiFi: $ssid (attempt $attempts/$maxAttempts)");
          }
        }
      } catch (e) {
        if (kDebugMode) {
          print("Error checking WiFi network: $e");
        }
      }

      await Future.delayed(Duration(seconds: 1));
    }

    // If we get here, we've timed out
    throw TimeoutException(
        'Failed to detect network change to $ssid after $maxAttempts seconds');
  }
}

/// [SetupException] is a custom exception class for setup-related errors.
class SetupException implements Exception {
  final String message;
  SetupException(this.message);
  @override
  String toString() => message;
}
