import 'package:arg_osci_app/features/setup/domain/models/setup_status.dart';
import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:arg_osci_app/features/setup/domain/services/setup_service.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';

/// [SetupProvider] manages the state and logic for the setup process.
class SetupProvider extends GetxController {
  final SetupService setupService;
  final _state = SetupState().obs;

  static const maxRetries = 2;

  SetupState get state => _state.value;
  List<String> get availableNetworks => state.networks;

  SetupProvider(this.setupService);

  /// Updates the setup state using a function.
  void _updateState(SetupState Function(SetupState) update) {
    _state.value = update(_state.value);
  }

  /// Connects to the local access point.
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

  /// Handles the selection of a mode.
  Future<void> handleModeSelection(String mode) async {
    await setupService.selectMode(mode);
  }

  /// Handles the selection of an external access point.
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

  /// Connects to an external access point.
  Future<void> connectToExternalAP(String ssid, String password) async {
    int attempts = 0;
    if (kDebugMode) {
      print("Connecting ESP32 to ExternalAP");
    }
    try {
      _updateState((s) => s.copyWith(status: SetupStatus.configuring));

      // Encrypt the SSID and password using the device's public key
      final encryptedPass = setupService.encriptWithPublicKey(password);
      final encryptedSsid = setupService.encriptWithPublicKey(ssid);
      final credentials = WiFiCredentials(encryptedSsid, encryptedPass);

      while (attempts < maxRetries) {
        attempts++;
        if (kDebugMode) {
          print("Connection attempt $attempts/$maxRetries");
        }

        try {
          final success = await setupService.connectToWiFi(credentials);
          if (success) {
            _updateState(
                (s) => s.copyWith(status: SetupStatus.waitingForNetworkChange));
            try {
              // After connecting to WiFi, handle network change and connect
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

  /// Waits for the network to change to the specified SSID.
  Future<void> waitForNetworkChange(String ssid) async {
    await setupService.waitForNetworkChange(ssid);
  }

  /// Handles the network change and connects to the new network.
  Future<void> handleNetworkChangeAndConnect(
      String ssid, String password) async {
    await setupService.handleNetworkChangeAndConnect(ssid, password);
  }

  /// Resets the setup state.
  void reset() {
    _updateState((_) => SetupState());
  }
}
