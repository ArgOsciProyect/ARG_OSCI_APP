// lib/presentation/widgets/show_wifi_network_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';

Future<void> showWiFiNetworkDialog(BuildContext context) async {
  final SetupController controller = Get.find<SetupController>();
  await controller.handleExternalAPSelection();
  if (!context.mounted) return;
  Get.dialog(
    AlertDialog(
      title: Text('Select WiFi Network'),
      content: Obx(() {
        return ListView.builder(
          shrinkWrap: true,
          itemCount: controller.availableNetworks.length,
          itemBuilder: (context, index) {
            return ListTile(
              title: Text(controller.availableNetworks[index]),
              onTap: () {
                Get.back(result: controller.availableNetworks[index]);
              },
            );
          },
        );
      }),
    ),
  ).then((selectedSSID) {
    if (selectedSSID != null && context.mounted) {
      askForPassword(context, selectedSSID);
    }
  });
}

Future<void> askForPassword(BuildContext context, String ssid) async {
  TextEditingController passwordController = TextEditingController();
  Get.dialog(
    AlertDialog(
      title: Text('Enter WiFi Password'),
      content: TextField(
        controller: passwordController,
        decoration: InputDecoration(hintText: "Enter Password"),
        obscureText: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back(result: passwordController.text);
          },
          child: Text('OK'),
        ),
      ],
    ),
  ).then((password) {
    if (password != null && context.mounted) {
      final SetupController controller = Get.find<SetupController>();
      controller.connectToExternalAP(ssid, password);
    }
  });
}