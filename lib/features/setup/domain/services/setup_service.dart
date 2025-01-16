// lib/features/setup/domain/services/setup_service.dart
import 'package:encrypt/encrypt.dart';
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
import 'package:wifi_iot/wifi_iot.dart';

class NetworkInfoService {
  final NetworkInfo _networkInfo = NetworkInfo();

  Future<bool> connectToESP32() async {
    if (Platform.isAndroid) {
      try {
        print("Connecting to ESP32_AP");

        // Disconnect from current network
        print("Disconnecting from current network");
        await WiFiForIoTPlugin.disconnect();
        await Future.delayed(const Duration(seconds: 2));

        // Try to connect
        print("Attempting connection to ESP32_AP");
        bool connected = await WiFiForIoTPlugin.connect(
          'ESP32_AP',
          password: 'password123',
          security: NetworkSecurity.WPA,
          joinOnce: true,
          withInternet: false,
        );

        if (!connected) {
          print("Failed to connect to ESP32_AP");
          return false;
        }

        await Future.delayed(const Duration(seconds: 3));
        return await WiFiForIoTPlugin.forceWifiUsage(true);
      } catch (e) {
        print('Error connecting to ESP32: $e');
        return false;
      }
    }
    return false;
  }

Future<bool> isConnectedToBSSID(String expectedBSSID) async {
  try {
    String? currentBSSID;
    
    if (Platform.isAndroid) {
      currentBSSID = await WiFiForIoTPlugin.getBSSID();
      if (currentBSSID != null) {
        currentBSSID = currentBSSID.toLowerCase();
      }
    } else {
      currentBSSID = await _networkInfo.getWifiBSSID();
    }
    
    print("Current BSSID: $currentBSSID");
    print("Expected BSSID: $expectedBSSID");
    if (currentBSSID?.toLowerCase() == expectedBSSID.toLowerCase()){
      WiFiForIoTPlugin.forceWifiUsage(true);
      return true;
    }
    else{
      return false;
    }
    
  } catch (e) {
    print('Error checking BSSID: $e');
    return false;
  }
}

  Future<String?> getWifiName() async {
    return _networkInfo.getWifiName();
  }

  Future<String?> getWifiIP() async {
    return _networkInfo.getWifiIP();
  }

  Future<String?> getBSSID() async {
    return _networkInfo.getWifiBSSID();
  }
}

class SetupService implements SetupRepository {
  SocketConnection globalSocketConnection;
  HttpConfig globalHttpConfig;
  late SocketService localSocketService;
  late HttpService localHttpService;
  RSAPublicKey? _publicKey;
  //final NetworkInfo _networkInfo = NetworkInfo();
  final NetworkInfoService _networkInfo = NetworkInfoService();

  late dynamic extIp;
  late dynamic extPort;
  late dynamic extBSSID;
  late dynamic _pubKey;

  SetupService(this.globalSocketConnection, this.globalHttpConfig) {
    localSocketService = SocketService();
    localHttpService = HttpService(globalHttpConfig);
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
    localSocketService = SocketService();
  }

  @override
  Future<void> connectToWiFi(WiFiCredentials credentials) async {
    final response =
        await localHttpService.post('/connect_wifi', credentials.toJson());
    extIp = response['IP'];
    extPort = response['Port'];
    extBSSID = response['BSSID'];

    print("ip recibido: $extIp");
    print("port recibido: $extPort");
    print("bssid recibido: $extBSSID");
  }

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    print("Scannig wifis");
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
    if (mode == 'External AP') {
      // Handle External AP mode
    } else if (mode == 'Internal AP') {
      final ip = response['IP'];
      final port = response['Port'];
      print("ip recibido: $ip");
      print("port recibido: $port");
      await initializeGlobalHttpConfig('http://$ip', client: client);
      await initializeGlobalSocketConnection(ip, port);
    }
  }

  @override
  Future<void> handleNetworkChangeAndConnect(String ssid, String password,
      {http.Client? client}) async {
    print("Waiting for connection to $ssid");

    // Wait for user to connect to the network and verify BSSID
    bool connected = false;
    int maxRetries = 100; // 30 seconds timeout

    for (int i = 0; i < maxRetries && !connected; i++) {
      connected = await _networkInfo.isConnectedToBSSID(extBSSID);
      if (!connected) {
        print("Waiting for network connection... ($i/$maxRetries)");
        await Future.delayed(const Duration(seconds: 1));
      }
    }

    if (!connected) {
      throw Exception(
          'Failed to connect to correct network after $maxRetries seconds');
    }

    print("Connected to correct network");
    await Future.delayed(const Duration(seconds: 2));
    await initializeGlobalHttpConfig('http://$extIp:80', client: client);

    // Test connection with retries
    //int maxTestRetries = 10;
    //for (int i = 0; i < maxTestRetries; i++) {
    //  try {
    //    final response = await localHttpService.get('/test');
    //    print("Connection test successful: $response");
    //    break;
    //  } catch (e) {
    //    print("Connection test attempt ${i + 1} failed: $e");
    //    if (i == maxTestRetries - 1) {
    //      throw Exception(
    //          'Failed to establish connection after $maxTestRetries attempts');
    //    }
    //    await Future.delayed(const Duration(seconds: 1));
    //  }
    //}

    await initializeGlobalSocketConnection(extIp, extPort);
  }

  @override
  Future<void> connectToLocalAP({http.Client? client}) async {
    if (Platform.isAndroid) {
      final connected = await _networkInfo.connectToESP32();
      if (!connected) {
        throw Exception('Failed to connect to ESP32_AP');
      }
      // Wait for connection to stabilize
      await Future.delayed(const Duration(seconds: 2));
      print(await _networkInfo.getWifiName());
      print(await _networkInfo.getWifiIP());
    } else {
      // Original manual connection check
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
