import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/setup_provider.dart';
import '../../graph/screens/mode_selection_screen.dart';

Future<void> showWiFiNetworkDialog(BuildContext context) async {
  final SetupProvider controller = Get.find<SetupProvider>();

  // Mostrar diálogo de espera
  Get.dialog(
    AlertDialog(
      title: Text('Scanning for WiFi Networks'),
      content: Column(
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

  // Cerrar el diálogo de espera
  Get.back();

  if (!context.mounted) return;
  Get.dialog(
    AlertDialog(
      title: Text('Select WiFi Network'),
      content: Obx(() {
        return SizedBox(
          height: 300, // Ajusta la altura según sea necesario
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
  ).then((password) async {
    if (password != null && context.mounted) {
      final SetupProvider controller = Get.find<SetupProvider>();
      await controller.connectToExternalAP(ssid, password);

      // Mostrar diálogo de espera
      Get.dialog(
        AlertDialog(
          title: Text('Waiting for network change'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Please change your Wi-Fi network to $ssid.'),
              SizedBox(height: 20),
              CircularProgressIndicator(),
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
      Get.to(() => ModeSelectionScreen());
    }
  });
}