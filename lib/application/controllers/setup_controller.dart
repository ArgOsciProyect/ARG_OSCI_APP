// lib/application/controllers/setup_controller.dart
import 'package:get/get.dart';
import 'package:network_info_plus/network_info_plus.dart';
import '../../domain/use_cases/send_message.dart';
import '../../domain/use_cases/receive_message.dart';

class SetupController extends GetxController {
  final SendMessage sendMessage;
  final ReceiveMessage receiveMessage;
  final NetworkInfo _networkInfo = NetworkInfo();
  var availableNetworks = <String>[].obs;

  SetupController(this.sendMessage, this.receiveMessage);

  Future<void> connectToLocalAP() async {
    await sendMessage.call('Connect to Local AP');
  }

  Future<void> handleExternalAPSelection() async {
    sendMessage.call("Ext AP");
    String availableWifi = await receiveMessage.call();
    availableNetworks.value = availableWifi.split(','); // Assuming the networks are comma-separated
  }

  Future<void> connectToExternalAP(String ssid, String password) async {
    sendMessage.call("SSID: $ssid, Password: $password");
    String recIp = await receiveMessage.call();
    String recPort = await receiveMessage.call();
    Get.snackbar('AP Mode', 'External AP selected, change to the selected network');
    while (await _networkInfo.getWifiName() != ssid) {
      await Future.delayed(Duration(seconds: 1));
    }
    await sendMessage.call('Connect to External AP');
  }
}