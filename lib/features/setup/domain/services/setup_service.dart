// lib/features/setup/domain/services/setup_service.dart
import 'package:network_info_plus/network_info_plus.dart';
import '../../../socket/domain/models/socket_connection.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../http/domain/models/http_config.dart';
import '../../../http/domain/services/http_service.dart';
import '../models/wifi_credentials.dart';
import '../repository/setup_repository.dart';

class SetupService implements SetupRepository {
  final SocketService globalSocketService;
  HttpService? globalHttpService;
  final HttpConfig httpConfig;
  final NetworkInfo _networkInfo = NetworkInfo();

  // Private instances
  HttpService? _privateHttpService;
  late dynamic extIp;
  late dynamic extPort;

  SetupService(this.globalSocketService, this.httpConfig) {
    _privateHttpService = HttpService(httpConfig);
  }

  void initializeGlobalHttpService(String baseUrl) {
    globalHttpService = HttpService(HttpConfig(baseUrl));
  }

  void initializeGlobalSocketService(String ip, int port) async {
    await globalSocketService.connect(SocketConnection(ip, port));
  }

  @override
  Future<void> connectToWiFi(WiFiCredentials credentials) async {
    final response = await _privateHttpService!.post('/connect_wifi', credentials.toJson());

    extIp = response['IP'];
    extPort = response['Port'];
    print("ip recibido: $extIp");
    print("port recibido: $extPort");
  }

  //@override
  //Future<List<String>> scanForWiFiNetworks() async {
  //  final response = await _privateHttpService!.get('/scan_wifi');
  //  final List<dynamic> networks = response['networks'];
  //  return networks.map((item) => item['SSID'] as String).toList();
  //}

  @override
  Future<List<String>> scanForWiFiNetworks() async {
    final response = await _privateHttpService!.get('/scan_wifi');
    return (response as List).map((item) => item['SSID'] as String).toList();
  }

  @override
  Future<void> sendMessage(String message) async {
    await globalSocketService.sendMessage(message);
  }

  @override
  Future<String> receiveMessage() async {
    return await globalSocketService.receiveMessage();
  }

  Future<void> connectToLocalAP() async {
    while (await _networkInfo.getWifiName() != '"ESP32_AP"') {
      await Future.delayed(Duration(seconds: 1));
    }
    _privateHttpService ??= HttpService(HttpConfig('http://192.168.4.1:81'));
  }

  Future<void> selectMode(String mode) async {
    final response = await _privateHttpService!.get('/internal_mode');
    if (mode == 'External AP') {
      // Handle External AP mode
    } else if (mode == 'Internal AP') {
      final ip = response['IP'];
      final port = response['Port'];
      initializeGlobalHttpService('http://$ip');
      initializeGlobalSocketService(ip, int.parse(port));
    }
  }

  Future<void> handleNetworkChangeAndConnect(String ssid) async {
    await waitForNetworkChange(ssid);
    print("Connected to $ssid");
    await Future.delayed(Duration(seconds: 3));
    initializeGlobalHttpService('http://$extIp:80');
    
    // Hacer una solicitud GET de prueba a /test y imprimir la respuesta
    final response = await globalHttpService!.get("/test");
    print(response);

    initializeGlobalSocketService(extIp, extPort);
    dynamic rec = await globalSocketService.receiveMessage();
    print(rec);
  }

  Future<void> waitForNetworkChange(String ssid) async {
    while (await _networkInfo.getWifiName() != '"' + ssid + '"') {
      await Future.delayed(Duration(seconds: 1));
    }
  }
}