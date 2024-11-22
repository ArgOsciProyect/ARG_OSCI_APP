// lib/features/socket/providers/setup_provider.dart
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../domain/services/socket_service.dart';
import '../domain/models/socket_connection.dart';

class SetupProvider extends GetxController {
  final SocketService socketService;
  final NetworkInfo _networkInfo = NetworkInfo();
  var availableNetworks = <String>[].obs;

  SetupProvider(this.socketService);

  Future<void> connectToLocalAP() async {
    //await checkForLocalNetwork();
    await connectToSocket("192.168.4.1", 8080);
  }

  Future<void> checkForLocalNetwork() async {
    while (await _networkInfo.getWifiName() != 'ESP32_AP') {
      await Future.delayed(Duration(seconds: 1));
      print(await _networkInfo.getWifiName());
    }
  }

  Future<void> handleExternalAPSelection() async {
    await socketService.sendMessage("Ext_AP");
    String availableWifi = await socketService.receiveMessage();
    print(availableWifi);
    availableNetworks.value =
        availableWifi.split(','); // Assuming the networks are comma-separated
  }

  Future<void> connectToExternalAP(String ssid, String password) async {
    await socketService.sendMessage("SSID: $ssid, Password: $password");
    print(ssid);
  }

  Future<void> waitForNetworkChange(String ssid) async {
    while (await _networkInfo.getWifiName() != '"' + ssid + '"') {
      print(await _networkInfo.getWifiName());
      print(ssid);
      print(await _networkInfo.getWifiName() != '"' + ssid + '"');
      await Future.delayed(Duration(seconds: 1));
    }
  }

  Future<void> connectToSocket(String ip, int port) async {
    await socketService.connect(SocketConnection(ip, port));
  }

  Future<void> handleNetworkChangeAndConnect(String ssid) async {
    String recIp = await socketService.receiveMessage();
    String recPort = await socketService.receiveMessage();
    print(recIp);
    print(recPort);
    await waitForNetworkChange(ssid);
    await connectToSocket(recIp, int.parse(recPort));
  }
}
