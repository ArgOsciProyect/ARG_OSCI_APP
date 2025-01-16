// show_wifi_network_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/setup_provider.dart';
import '../../graph/screens/mode_selection_screen.dart';

Future<void> showWiFiNetworkDialog() async {
  final SetupProvider controller = Get.find<SetupProvider>();

  // First dialog - Scanning
  Get.dialog(
    AlertDialog(
      title: const Text('Scanning for WiFi Networks'),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('Please wait while scanning for available WiFi networks...'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      ),
    ),
    barrierDismissible: false,
  );

  await controller.handleExternalAPSelection();
  Get.back();

  // Second dialog - Network Selection
  final selectedSSID = await Get.dialog<String>(
    AlertDialog(
      title: const Text('Select WiFi Network'),
      content: SizedBox(
        width: 300,
        height: 400,
        child: Obx(() {
          return ListView.builder(
            itemCount: controller.availableNetworks.length,
            itemBuilder: (context, index) {
              final network = controller.availableNetworks[index];
              return ListTile(
                title: Text(network),
                onTap: () {
                  final ssid = network.split('SSID:').last.trim();
                  Get.back(result: ssid);
                },
              );
            },
          );
        }),
      ),
    ),
  );

  if (selectedSSID != null) {
    await askForPassword(selectedSSID);
  }
}

Future<void> askForPassword(String ssid) async {
  final passwordController = TextEditingController();

  final password = await Get.dialog<String>(
    Material(
      type: MaterialType.transparency,
      child: AlertDialog(
        title: Text('Enter Password for $ssid'),
        content: TextField(
          controller: passwordController,
          decoration: const InputDecoration(
            labelText: 'Password',
            border: OutlineInputBorder(),
          ),
          obscureText: true,
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Get.back(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Get.back(result: passwordController.text),
            child: const Text('Connect'),
          ),
        ],
      ),
    ),
  );

  if (password != null) {
    final SetupProvider controller = Get.find<SetupProvider>();
    await controller.connectToExternalAP(ssid, password);

    Get.dialog(
      AlertDialog(
        title: const Text('Connecting to Network'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Connecting to $ssid...'),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    await controller.handleNetworkChangeAndConnect(ssid, password);
    Get.back();
    Get.to(() => const ModeSelectionScreen());
  }
}
