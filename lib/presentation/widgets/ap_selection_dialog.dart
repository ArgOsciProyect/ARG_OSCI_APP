// lib/presentation/widgets/ap_selection_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';
import 'show_wifi_network_dialog.dart';

void showAPSelectionDialog(BuildContext context) {
  final SetupController controller = Get.find<SetupController>();
  controller.connectToLocalAP().then((_) {
    Get.dialog(
      AlertDialog(
        title: Text('Select AP Mode'),
        content: Text('Choose your preferred AP mode.'),
        actions: [
          TextButton(
            onPressed: () {
              // Handle Local AP selection
              Get.back();
              Get.snackbar('AP Mode', 'Local AP selected.');
            },
            child: Text('Local AP'),
          ),
          TextButton(
            onPressed: () {
              // Handle External AP selection
              Get.back();
              showWiFiNetworkDialog(context);
            },
            child: Text('External AP'),
          ),
        ],
      ),
    );
  });
}