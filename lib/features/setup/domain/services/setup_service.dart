// lib/features/setup/domain/services/setup_service.dart
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:pointycastle/export.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../http/domain/models/http_config.dart';
import '../../../http/domain/services/http_service.dart';
import '../models/wifi_credentials.dart';
import '../repository/setup_repository.dart';
import 'package:http/http.dart' as http;


class SetupService implements SetupRepository {
  SocketService globalSocketService;
  HttpService globalHttpService;
  RSAPublicKey? _publicKey;
  final NetworkInfo _networkInfo = NetworkInfo();
  // Private instances
  HttpService? _privateHttpService;
  late dynamic extIp;
  late dynamic extPort;
  late dynamic _pubKey;

  SetupService(this.globalSocketService, this.globalHttpService) {
    _privateHttpService = globalHttpService;
  }

  void initializeGlobalHttpService(String baseUrl, {http.Client? client}) {
    globalHttpService = HttpService(HttpConfig(baseUrl), client: client);
  }

  Future<void> initializeGlobalSocketService(String ip, int port) async {
    await globalSocketService.connect(SocketConnection(ip, port));
    globalSocketService.listen();
  }

  @override
  Future<void> connectToWiFi(WiFiCredentials credentials) async {
    final response = await _privateHttpService!.post('/connect_wifi', credentials.toJson());
    extIp = response['IP'];
    extPort = response['Port'];
    print("ip recibido: $extIp");
    print("port recibido: $extPort");
  }

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    _pubKey = await _privateHttpService!.get('/get_public_key');
    print(_pubKey["PublicKey"]);
    RSAAsymmetricKey key = RSAKeyParser().parse(_pubKey["PublicKey"]);
    _publicKey = key as RSAPublicKey;
    final response = await _privateHttpService!.get('/scan_wifi');
    return (response as List).map((item) => item['SSID'] as String).toList();
  }

  String encriptWithPublicKey(String message) {
      if (_pubKey == null) {
        throw Exception('Public key is not set');
      }
      final encrypter = Encrypter(RSA(publicKey: _publicKey, encoding: RSAEncoding.PKCS1));
      final encrypted = encrypter.encrypt(message);
      return encrypted.base64;
  } 

  @override
  Future<void> sendMessage(String message) async {
    await globalSocketService.sendMessage(message);
  }

  @override
  Future<String> receiveMessage() async {
    return await globalSocketService.receiveMessage();
  }

  @override
  Future<void> connectToLocalAP({http.Client? client}) async {
    while (await _networkInfo.getWifiName() != '"ESP32_AP"') {
      await Future.delayed(Duration(seconds: 1));
    }
    _privateHttpService ??= HttpService(HttpConfig('http://192.168.4.1:81'), client: client);
  }

  @override
  Future<void> selectMode(String mode, {http.Client? client}) async {
    final response = await _privateHttpService!.get('/internal_mode');
    if (mode == 'External AP') {
      // Handle External AP mode
    } else if (mode == 'Internal AP') {
      final ip = response['IP'];
      final port = response['Port'];
      print("ip recibido: $ip");
      print("port recibido: $port");
      initializeGlobalHttpService('http://$ip', client: client);
      initializeGlobalSocketService(ip, port);
    }
  }

  @override
  Future<void> handleNetworkChangeAndConnect(String ssid, {http.Client? client}) async {
    await waitForNetworkChange(ssid);
    print("Connected to $ssid");
    await Future.delayed(Duration(seconds: 3));
    initializeGlobalHttpService('http://$extIp:80', client: client);

    // Hacer una solicitud GET de prueba a /test y imprimir la respuesta
    final response = await globalHttpService.get("/test");
    print(response);

    await initializeGlobalSocketService(extIp, extPort); // Esperar a que la conexión del socket se complete
  }

  @override
  Future<void> waitForNetworkChange(String ssid) async {
    while (await _networkInfo.getWifiName() != '"' + ssid + '"') {
      await Future.delayed(Duration(seconds: 1));
    }
  }
}