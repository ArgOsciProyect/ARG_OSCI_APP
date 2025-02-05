// lib/features/setup/domain/services/setup_service.dart
import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:encrypt/encrypt.dart';
import 'package:get/get.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/export.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../http/domain/services/http_service.dart';
import '../../../http/domain/models/http_config.dart';
import 'package:http/http.dart' as http;
import '../models/wifi_credentials.dart';
import '../repository/setup_repository.dart';
import 'dart:io';
import 'dart:math';
import 'package:wifi_iot/wifi_iot.dart';

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final _httpClient = http.Client();
  static const String _baseUrl = 'http://192.168.4.1:81';

  Future<bool> connectWithRetries() async {
    const maxRetries = 5;
    const retryDelay = Duration(seconds: 1);

    for (int attempt = 0; attempt < maxRetries; attempt++) {
      print("Connection attempt ${attempt + 1}/$maxRetries");

      if (await connectToESP32()) {
        return true;
      }

      if (attempt < maxRetries - 1) {
        print("Retrying in ${retryDelay.inSeconds} second...");
        await Future.delayed(retryDelay);
      }
    }

    print("Failed to connect after $maxRetries attempts");
    return false;
  }

  Future<bool> testConnection() async {
    try {
      final response = await _httpClient
          .get(
            Uri.parse('$_baseUrl/testConnect'),
          )
          .timeout(
            const Duration(seconds: 2),
            onTimeout: () => throw TimeoutException('Connection timed out'),
          );

      return response.statusCode == 200;
    } catch (e) {
      print('Test connection failed: $e');
      return false;
    }
  }

  Future<bool> connectToESP32() async {
    if (!Platform.isAndroid) return false;

    try {
      print("Attempting to connect to ESP32_AP using IoT plugin...");

      // First attempt: Try WiFiForIoTPlugin
      bool connected = await WiFiForIoTPlugin.connect(
        'ESP32_AP',
        password: 'password123',
        security: NetworkSecurity.WPA,
        joinOnce: true,
        withInternet: false,
      );

      if (connected) {
        print("WiFi connection successful via IoT plugin");
        await Future.delayed(const Duration(seconds: 2));

        if (await WiFiForIoTPlugin.forceWifiUsage(true)) {
          if (await testConnection()) {
            print("Connection verified successfully via IoT plugin");
            return true;
          }
        }
      }

      // Fallback method: Traditional SSID verification
      print("IoT plugin connection failed, trying traditional method...");

      const maxRetries = 30;
      const checkInterval = Duration(seconds: 1);

      for (int i = 0; i < maxRetries; i++) {
        String? currentSSID = await getWifiName();
        if (currentSSID != null) {
          currentSSID = currentSSID.replaceAll('"', '');

          if (currentSSID.startsWith('ESP32_AP')) {
            print("Connected to ESP32_AP via traditional method");

            // Test the connection
            if (await testConnection()) {
              print("Connection verified successfully via traditional method");
              return true;
            }
          }
        }

        if (i < maxRetries - 1) {
          print("Waiting for ESP32_AP connection... (${i + 1}/$maxRetries)");
          await Future.delayed(checkInterval);
        }
      }

      print("Failed to connect via both methods");
      return false;
    } catch (e) {
      print('Error connecting to ESP32: $e');
      return false;
    }
  }

  Future<String?> getWifiName() async {
    return _networkInfo.getWifiName();
  }

  Future<String?> getWifiIP() async {
    return _networkInfo.getWifiIP();
  }
}

class SetupService implements SetupRepository {
  SocketConnection globalSocketConnection;
  HttpConfig globalHttpConfig;
  late HttpService localHttpService;
  RSAPublicKey? _publicKey;
  final NetworkInfoService _networkInfo = NetworkInfoService();

  late dynamic extIp;
  late dynamic extPort;
  late dynamic _pubKey;

  String _generateRandomWord() {
    const chars = 'abcdefghijklmnopqrstuvwxyz';
    final random = Random();
    return List.generate(10, (index) => chars[random.nextInt(chars.length)])
        .join();
  }

  SetupService(this.globalSocketConnection, this.globalHttpConfig) {
    localHttpService = HttpService(globalHttpConfig);
  }

  Future<void> fetchDeviceConfig() async {
    final response = await HttpService(globalHttpConfig).get('/config');
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
  Future<void> connectToWiFi(WiFiCredentials credentials) async {
    final response =
        await localHttpService.post('/connect_wifi', credentials.toJson());
    extIp = response['IP'];
    extPort = response['Port'];

    print("ip recibido: $extIp");
    print("port recibido: $extPort");
  }

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    print("Scanning wifis");
    final publicKeyResponse = await localHttpService.get('/get_public_key');
    _pubKey = publicKeyResponse;
    print(_pubKey["PublicKey"]);
    RSAAsymmetricKey key = RSAKeyParser().parse(_pubKey["PublicKey"]);
    _publicKey = key as RSAPublicKey;

    final wifiResponse = await localHttpService.get('/scan_wifi');
    final wifiData = wifiResponse as List;
    return wifiData.map((item) => item['SSID'] as String).toList();
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
    final response = await localHttpService.get('/internal_mode');
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
    print("Testing connection to network");

    if (Platform.isAndroid) {
      await WiFiForIoTPlugin.forceWifiUsage(false);
    }

    await initializeGlobalHttpConfig('http://$extIp:80', client: client);

    int maxTestRetries = 100;
    String testWord = _generateRandomWord();
    String encryptedWord = encriptWithPublicKey(testWord);

    // Create JSON with same format as WiFiCredentials
    final testRequest = {'word': encryptedWord};

    for (int i = 0; i < maxTestRetries; i++) {
      try {
        final response = await localHttpService.post('/test', testRequest);

        if (response['decrypted'] == testWord) {
          print("Connection verified - correct network");
          await initializeGlobalSocketConnection(extIp, extPort);
          return;
        } else {
          print("Connection test failed: incorrect response");
          print("Expected: $testWord, Received: ${response['decrypted']}");
          print("Crude Response: $response");
        }
      } catch (e) {
        print("Connection test attempt ${i + 1} failed: $e");
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
    if (Platform.isAndroid) {
      final connected = await _networkInfo.connectWithRetries();
      if (!connected) {
        throw Exception('Failed to connect to ESP32_AP');
      }
      await Future.delayed(const Duration(seconds: 2));
      print(await _networkInfo.getWifiName());
      print(await _networkInfo.getWifiIP());
    } else {
      while (true) {
        String? wifiName = await _networkInfo.getWifiName();
        if (Platform.isAndroid && wifiName != null) {
          wifiName = wifiName.replaceAll('"', '');
        }

        if (wifiName != null && wifiName.startsWith('ESP32_AP')) {
          break;
        }

        print('Please connect manually to ESP32_AP network');
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    await initializeGlobalHttpConfig('http://192.168.4.1:81', client: client);
  }

  @override
  Future<void> waitForNetworkChange(String ssid) async {
    String? wifiName = await _networkInfo.getWifiName();
    if (Platform.isAndroid && wifiName != null) {
      wifiName = wifiName.replaceAll('"', '');
    }

    while (wifiName?.startsWith(ssid) == false) {
      await Future.delayed(Duration(seconds: 1));
      wifiName = await _networkInfo.getWifiName();
      if (Platform.isAndroid && wifiName != null) {
        wifiName = wifiName.replaceAll('"', '');
      }
      print("Current WiFi: $wifiName, Expected WiFi: $ssid");
    }
  }
}
