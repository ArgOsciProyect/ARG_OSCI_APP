import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/setup_provider.dart';
import 'show_wifi_network_dialog.dart';

void showAPSelectionDialog(BuildContext context) {
  final SetupProvider controller = Get.find<SetupProvider>();
  
  // Mostrar diálogo de espera
  Get.dialog(
    AlertDialog(
      title: Text('Connecting to ESP32 AP'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please wait while connecting to ESP32 AP...'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      ),
    ),
    barrierDismissible: false,
  );

  controller.connectToLocalAP().then((_) {
    // Cerrar el diálogo de espera
    Get.back();

    Get.dialog(
      AlertDialog(
        title: Text('Select AP Mode'),
        content: Text('Choose your preferred AP mode.'),
        actions: [
          TextButton(
            onPressed: () {
              // Handle Local AP selection
              Get.back();
              controller.handleModeSelection('Internal AP');
              Get.snackbar('AP Mode', 'Local AP selected.');
            },
            child: Text('Local AP'),
          ),
          TextButton(
            onPressed: () {
              // Handle External AP selection
              Get.back();
              controller.handleModeSelection('External AP');
              showWiFiNetworkDialog(context);
            },
            child: Text('External AP'),
          ),
        ],
      ),
    );
  });
}