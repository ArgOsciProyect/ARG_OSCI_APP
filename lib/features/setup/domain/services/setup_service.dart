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

class SetupService implements SetupRepository {
  SocketConnection globalSocketConnection;
  HttpConfig globalHttpConfig;
  late SocketService localSocketService;
  late HttpService localHttpService;
  RSAPublicKey? _publicKey;
  final NetworkInfo _networkInfo = NetworkInfo();
  late dynamic extIp;
  late dynamic extPort;
  late dynamic extBSSID;
  late dynamic _pubKey;

  SetupService(this.globalSocketConnection, this.globalHttpConfig) {
    localSocketService = SocketService();
    localHttpService = HttpService(globalHttpConfig);
  }

  Future<void> initializeGlobalHttpConfig(String baseUrl, {http.Client? client}) async {
    globalHttpConfig = HttpConfig(baseUrl, client : client);
    localHttpService = HttpService(globalHttpConfig);
  }

  Future<void> initializeGlobalSocketConnection(String ip, int port) async {
    globalSocketConnection.updateConnection(ip, port);
    localSocketService = SocketService();
  }

  @override
  Future<void> connectToWiFi(WiFiCredentials credentials) async {
    final response = await localHttpService.post('/connect_wifi', credentials.toJson());
    extIp = response['IP'];
    extPort = response['Port'];
    
    print("ip recibido: $extIp");
    print("port recibido: $extPort");
  }

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    final publicKeyResponse = await localHttpService.get('/get_public_key');
    _pubKey = publicKeyResponse;
    print(_pubKey["PublicKey"]);
    RSAAsymmetricKey key = RSAKeyParser().parse(_pubKey["PublicKey"]);
    _publicKey = key as RSAPublicKey;

    final wifiResponse = await localHttpService.get('/scan_wifi');
    final wifiData = wifiResponse as List;
    return wifiData.map((item) => item['SSID'] as String).toList();
  }

  String encriptWithPublicKey(String message) {
    if (_publicKey == null) {
      throw Exception('Public key is not set');
    }
    final encrypter = Encrypter(RSA(publicKey: _publicKey, encoding: RSAEncoding.PKCS1));
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
  Future<void> handleNetworkChangeAndConnect(String ssid, {http.Client? client}) async {
    await waitForNetworkChange(ssid);
    print("Connected to $ssid");
    await Future.delayed(Duration(seconds: 3));
    await initializeGlobalHttpConfig('http://$extIp:80', client: client);

    // Hacer una solicitud GET de prueba a /test y imprimir la respuesta
    final response = await localHttpService.get('/test');
    print(response);

    await initializeGlobalSocketConnection(extIp, extPort); // Esperar a que la conexión del socket se complete
  }

  @override
  Future<void> connectToLocalAP({http.Client? client}) async {
    while (true) {
      // Obtener nombre de red WiFi
      String? wifiName = await _networkInfo.getWifiName();
      if (Platform.isAndroid && wifiName != null) {
        wifiName = wifiName.replaceAll('"', '');
      }
  
      // Obtener IP del dispositivo
      String? ipAddress = await _networkInfo.getWifiIP();
      
      // Verificar si está conectado a la red ESP32_AP y tiene la IP correcta
      if (ipAddress != null && ipAddress.startsWith('192.168.4.')) {
        break;
      }
  
      print('WiFi: $wifiName, IP: $ipAddress');
      await Future.delayed(Duration(seconds: 1));
    }
  
    await initializeGlobalHttpConfig('http://192.168.4.1:81', client: client);
  }
  @override
  Future<void> waitForNetworkChange(String ssid) async {
    String? wifiName = await _networkInfo.getWifiName();
    print(wifiName);
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