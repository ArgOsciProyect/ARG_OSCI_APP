// lib/features/setup/providers/setup_provider.dart
import 'package:arg_osci_app/features/setup/domain/models/setup_status.dart';
import 'package:get/get.dart';
import '../domain/models/wifi_credentials.dart';
import '../domain/services/setup_service.dart';

class SetupProvider extends GetxController {
  final SetupService setupService;
  final _state = SetupState().obs;

  static const maxRetries = 2;

  SetupState get state => _state.value;
  List<String> get availableNetworks => state.networks;

  SetupProvider(this.setupService);

  void _updateState(SetupState Function(SetupState) update) {
    _state.value = update(_state.value);
  }

  Future<void> connectToLocalAP() async {
    try {
      _updateState((s) => s.copyWith(status: SetupStatus.connecting));
      await setupService.connectToLocalAP();
      _updateState((s) => s.copyWith(status: SetupStatus.success));
    } catch (e) {
      _updateState(
          (s) => s.copyWith(status: SetupStatus.error, error: e.toString()));
      rethrow;
    }
  }

  Future<void> handleModeSelection(String mode) async {
    await setupService.selectMode(mode);
  }

  Future<void> handleExternalAPSelection() async {
    try {
      _updateState((s) => s.copyWith(status: SetupStatus.scanning));
      final networks = await setupService.scanForWiFiNetworks();
      _updateState(
          (s) => s.copyWith(status: SetupStatus.selecting, networks: networks));
    } catch (e) {
      _updateState(
          (s) => s.copyWith(status: SetupStatus.error, error: e.toString()));
      rethrow;
    }
  }

  Future<void> connectToExternalAP(String ssid, String password) async {
    int attempts = 0;
    print("Connecting ESP32 to ExternalAP");
    try {
      _updateState((s) => s.copyWith(status: SetupStatus.configuring));

      final encryptedPass = setupService.encriptWithPublicKey(password);
      final encryptedSsid = setupService.encriptWithPublicKey(ssid);
      final credentials = WiFiCredentials(encryptedSsid, encryptedPass);

      while (attempts < maxRetries) {
        attempts++;
        print("Connection attempt $attempts/$maxRetries");

        try {
          final success = await setupService.connectToWiFi(credentials);
          if (success) {
            _updateState(
                (s) => s.copyWith(status: SetupStatus.waitingForNetworkChange));
            try {
              await handleNetworkChangeAndConnect(ssid, password);
              _updateState((s) => s.copyWith(status: SetupStatus.completed));
              return;
            } catch (e) {
              _updateState((s) => s.copyWith(
                  status: SetupStatus.error,
                  error: 'Failed to connect to network: $e'));
              rethrow;
            }
          }

          if (attempts < maxRetries) {
            _updateState((s) => s.copyWith(
                status: SetupStatus.error,
                error: 'Connection failed, retrying...'));
            await Future.delayed(Duration(seconds: 2));
            continue;
          }
        } catch (e) {
          if (attempts >= maxRetries) {
            rethrow;
          }
          _updateState((s) => s.copyWith(
              status: SetupStatus.error, error: 'Error: $e\nRetrying...'));
          await Future.delayed(Duration(seconds: 2));
          continue;
        }
      }

      throw SetupException('Failed to connect after $maxRetries attempts');
    } catch (e) {
      _updateState(
          (s) => s.copyWith(status: SetupStatus.error, error: e.toString()));
      rethrow;
    }
  }

  Future<void> waitForNetworkChange(String ssid) async {
    await setupService.waitForNetworkChange(ssid);
  }

  Future<void> handleNetworkChangeAndConnect(
      String ssid, String password) async {
    await setupService.handleNetworkChangeAndConnect(ssid, password);
  }

  void reset() {
    _updateState((_) => SetupState());
  }
}
