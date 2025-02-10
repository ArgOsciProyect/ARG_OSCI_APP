import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:arg_osci_app/features/setup/domain/repository/setup_repository.dart';
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

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();
  final HttpService _httpService;
  static const String _baseUrl = 'http://192.168.4.1:81';

  NetworkInfoService() : _httpService = HttpService(HttpConfig(_baseUrl));

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

  Future<bool> testConnection() async {
    try {
      await _httpService.get('/testConnect').timeout(
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

  Future<bool> connectToESP32() async {
    if (!Platform.isAndroid) return false;

    try {
      // First attempt: WiFiForIoTPlugin with 5 retries
      const pluginRetries = 5;
      const pluginInterval = Duration(seconds: 1);

      if (kDebugMode) {
        print("Attempting to connect to ESP32_AP using IoT plugin...");
      }

      for (int i = 0; i < pluginRetries; i++) {
        try {
          bool connected = await WiFiForIoTPlugin.connect(
            'ESP32_AP',
            password: 'password123',
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

            if (await WiFiForIoTPlugin.forceWifiUsage(true)
                .timeout(const Duration(seconds: 5))) {
              if (await testConnection().timeout(const Duration(seconds: 5))) {
                if (kDebugMode) {
                  print("Connection verified successfully via IoT plugin");
                }
                return true;
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

      // Fallback: Traditional SSID verification with 30 retries
      if (kDebugMode) {
        print("IoT plugin connection failed, trying traditional method...");
      }
      //Snackbar asking to connecto to ESP32 net manually
      SnackBar(
          content: Text(
              'Failed to autoconnect, please connect to ESP32_AP network manually'));
      const traditionalRetries = 30;
      const checkInterval = Duration(seconds: 1);

      for (int i = 0; i < traditionalRetries; i++) {
        try {
          String? currentSSID = await getWifiName();
          if (currentSSID != null) {
            currentSSID = currentSSID.replaceAll('"', '');

            if (currentSSID.startsWith('ESP32_AP')) {
              if (kDebugMode) {
                print("Connected to ESP32_AP via traditional method");
              }

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
                  "Waiting for ESP32_AP connection... (${i + 1}/$traditionalRetries)");
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

  @override
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
  Future<bool> connectToWiFi(WiFiCredentials credentials) async {
    if (kDebugMode) {
      print("Connecting ESP32 to WiFi");
    }
    try {
      final response = await localHttpService
          .post('/connect_wifi', credentials.toJson())
          .timeout(Duration(seconds: 15));

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
      final publicKeyResponse = await localHttpService
          .get('/get_public_key')
          .timeout(Duration(seconds: 5));

      _pubKey = publicKeyResponse;
      RSAAsymmetricKey key = RSAKeyParser().parse(_pubKey["PublicKey"]);
      _publicKey = key as RSAPublicKey;

      final wifiResponse = await localHttpService
          .get('/scan_wifi')
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
    if (kDebugMode) {
      print("Testing connection to network");
    }

    await initializeGlobalHttpConfig('http://$extIp:80', client: client);

    int maxTestRetries = 10;
    String testWord = _generateRandomWord();
    String encryptedWord = encriptWithPublicKey(testWord);

    final testRequest = {'word': encryptedWord};

    for (int i = 0; i < maxTestRetries; i++) {
      try {
        // print("Posting to: ${globalHttpConfig.baseUrl}");
        final response = await HttpService(globalHttpConfig)
            .post('/test', testRequest)
            .timeout(const Duration(seconds: 2));

        if (response['decrypted'] == testWord) {
          if (kDebugMode) {
            print("Connection verified - correct network");
          }
          await initializeGlobalSocketConnection(extIp, extPort);
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
    if (Platform.isAndroid) {
      final connected = await _networkInfo.connectWithRetries();
      if (!connected) {
        throw Exception('Failed to connect to ESP32_AP');
      }
      await Future.delayed(const Duration(seconds: 2));
      if (kDebugMode) {
        print(await _networkInfo.getWifiName());
        print(await _networkInfo.getWifiIP());
      }
    } else {
      while (true) {
        String? wifiName = await _networkInfo.getWifiName();
        if (Platform.isAndroid && wifiName != null) {
          wifiName = wifiName.replaceAll('"', '');
        }

        if (wifiName != null && wifiName.startsWith('ESP32_AP')) {
          break;
        }

        if (kDebugMode) {
          print('Please connect manually to ESP32_AP network');
        }
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
      if (kDebugMode) {
        print("Current WiFi: $wifiName, Expected WiFi: $ssid");
      }
    }
  }
}

class SetupException implements Exception {
  final String message;
  SetupException(this.message);
  @override
  String toString() => message;
}
