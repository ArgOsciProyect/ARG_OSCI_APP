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
    barrierDismissible: false,
  );

  try {
    await controller.connectToLocalAP();
    // Close the loading dialog after the connection is established
    Get.back();

    Get.dialog(
      AlertDialog(
        title: const Text('Select AP Mode'),
        content: const Text('Choose your preferred AP mode.'),
        actions: [
          TextButton(
            // Handle Local AP selection
            onPressed: () async {
              Get.back();
              await controller.handleModeSelection('Internal AP');
              Get.snackbar('AP Mode', 'Local AP selected.');

              // Navigate to the mode selection screen
              Get.to(() => const ModeSelectionScreen());
            },
            child: const Text('Local AP'),
          ),
          TextButton(
            // Handle External AP selection
            onPressed: () async {
              Get.back();
              await controller.handleModeSelection('External AP');
              Get.snackbar('AP Mode', 'External AP selected.');

              // Show dialog to select external WiFi network
              await showWiFiNetworkDialog();
            },
            child: const Text('External AP'),
          ),
        ],
      ),
    );
  } catch (e) {
    // Handle connection errors
    Get.back();
    Get.snackbar('Error', 'Failed to connect to ESP32 AP: $e');
  }
}
