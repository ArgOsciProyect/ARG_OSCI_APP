import 'package:arg_osci_app/features/graph/screens/mode_selection_screen.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'show_wifi_network_dialog.dart';

/// [showAPSelectionDialog] displays a dialog to select the Access Point (AP) mode.
Future<void> showAPSelectionDialog() async {
  final SetupProvider controller = Get.find<SetupProvider>();

  // Display a loading dialog while connecting to the ESP32 AP
  Get.dialog(
    AlertDialog(
      title: const Text('Connecting to ESP32 AP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Please wait while connecting to ESP32 AP...'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      ),
    ),
    // Change this to true to allow dismissing by clicking outside
    barrierDismissible: true,
  );

  try {
    // Connect to the local AP
    await controller.connectToLocalAP();
    Get.back();

    // Show dialog to select between Local AP and External AP modes
    Get.dialog(
      AlertDialog(
        title: const Text('Select AP Mode'),
        content: const Text('Choose your preferred AP mode.'),
        actions: [
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.handleModeSelection('Internal AP');
              Get.snackbar('AP Mode', 'Local AP selected.');
              Get.to(() => const ModeSelectionScreen());
            },
            child: const Text('Local AP'),
          ),
          TextButton(
            onPressed: () async {
              Get.back();
              await controller.handleModeSelection('External AP');
              Get.snackbar('AP Mode', 'External AP selected.');
              await showWiFiNetworkDialog();
            },
            child: const Text('External AP'),
          ),
        ],
      ),
      // Change this to true to allow dismissing by clicking outside
      barrierDismissible: true,
    );
  } catch (e) {
    Get.back();
    Get.snackbar('Error', 'Failed to connect to ESP32 AP: $e');
  }
}
