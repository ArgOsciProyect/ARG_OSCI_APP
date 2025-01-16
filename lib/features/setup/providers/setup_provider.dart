// lib/features/setup/providers/setup_provider.dart
import 'package:get/get.dart';
import '../domain/models/wifi_credentials.dart';
import '../domain/services/setup_service.dart';

class SetupProvider extends GetxController {
  final SetupService setupService;
  var availableNetworks = <String>[].obs;

  SetupProvider(this.setupService);

  Future<void> connectToLocalAP() async {
    await setupService.connectToLocalAP();
  }

  Future<void> handleModeSelection(String mode) async {
    await setupService.selectMode(mode);
  }

  Future<void> handleExternalAPSelection() async {
    availableNetworks.value = await setupService.scanForWiFiNetworks();
  }

  Future<void> connectToExternalAP(String ssid, String password) async {
    password = setupService.encriptWithPublicKey(password);
    ssid = setupService.encriptWithPublicKey(ssid);
    await setupService.connectToWiFi(WiFiCredentials(ssid, password));
  }

  Future<void> waitForNetworkChange(String ssid) async {
    await setupService.waitForNetworkChange(ssid);
  }

  Future<void> handleNetworkChangeAndConnect(
      String ssid, String password) async {
    await setupService.handleNetworkChangeAndConnect(ssid, password);
  }
}
