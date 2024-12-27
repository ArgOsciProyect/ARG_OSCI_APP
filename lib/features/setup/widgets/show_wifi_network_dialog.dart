// show_wifi_network_dialog.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/setup_provider.dart';
import '../../graph/screens/mode_selection_screen.dart';

Future<void> showWiFiNetworkDialog() async {
  final SetupProvider controller = Get.find<SetupProvider>();

  // Mostrar diálogo de espera
  Get.dialog(
    AlertDialog(
      title: const Text('Scanning for WiFi Networks'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: const [
          Text('Please wait while scanning for available WiFi networks...'),
          SizedBox(height: 20),
          CircularProgressIndicator(),
        ],
      ),
    ),
    barrierDismissible: false,
  );

  await controller.handleExternalAPSelection();

  // Cerrar el diálogo de espera
  Get.back();

  final selectedSSID = await Get.dialog<String>(
    AlertDialog(
      title: const Text('Select WiFi Network'),
      content: Obx(() {
        return SizedBox(
          height: 300,
          width: double.maxFinite,
          child: SingleChildScrollView(
            child: Column(
              children: controller.availableNetworks.map((network) {
                return ListTile(
                  title: Text(network),
                  onTap: () {
                    final ssid = network.split('SSID:').last.trim();
                    Get.back(result: ssid);
                  },
                );
              }).toList(),
            ),
          ),
        );
      }),
    ),
  );

  if (selectedSSID != null) {
    await askForPassword(selectedSSID);
  }
}

Future<void> askForPassword(String ssid) async {
  final passwordController = TextEditingController();
  
  final password = await Get.dialog<String>(
    AlertDialog(
      title: const Text('Enter WiFi Password'),
      content: TextField(
        controller: passwordController,
        decoration: const InputDecoration(hintText: "Enter Password"),
        obscureText: true,
      ),
      actions: [
        TextButton(
          onPressed: () {
            Get.back(result: passwordController.text);
          },
          child: const Text('OK'),
        ),
      ],
    ),
  );

  if (password != null) {
    final SetupProvider controller = Get.find<SetupProvider>();
    await controller.connectToExternalAP(ssid, password);

    // Mostrar diálogo de espera
    Get.dialog(
      AlertDialog(
        title: const Text('Waiting for network change'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('Please change your Wi-Fi network to $ssid.'),
            const SizedBox(height: 20),
            const CircularProgressIndicator(),
          ],
        ),
      ),
      barrierDismissible: false,
    );

    // Esperar a que la red cambie y conectar al socket
    await controller.handleNetworkChangeAndConnect(ssid);

    // Cerrar el diálogo de espera
    Get.back();

    // Navegar a la pantalla de selección de modo
    Get.to(() => const ModeSelectionScreen());
  }
}