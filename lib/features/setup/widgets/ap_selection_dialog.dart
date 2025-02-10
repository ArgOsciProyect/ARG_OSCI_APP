import 'package:arg_osci_app/features/graph/screens/mode_selection_screen.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'show_wifi_network_dialog.dart';

Future<void> showAPSelectionDialog() async {
  final SetupProvider controller = Get.find<SetupProvider>();

  // Mostrar diálogo de espera
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
    // Cerrar el diálogo de espera después de la conexión
    Get.back();

    Get.dialog(
      AlertDialog(
        title: const Text('Select AP Mode'),
        content: const Text('Choose your preferred AP mode.'),
        actions: [
          TextButton(
            onPressed: () async {
              // Handle Local AP selection
              Get.back();
              await controller.handleModeSelection('Internal AP');
              Get.snackbar('AP Mode', 'Local AP selected.');

              // Navegar a la pantalla de selección de modo
              Get.to(() => const ModeSelectionScreen());
            },
            child: const Text('Local AP'),
          ),
          TextButton(
            onPressed: () async {
              // Handle External AP selection
              Get.back();
              await controller.handleModeSelection('External AP');
              Get.snackbar('AP Mode', 'External AP selected.');

              // Mostrar diálogo para seleccionar red WiFi externa
              await showWiFiNetworkDialog();
            },
            child: const Text('External AP'),
          ),
        ],
      ),
    );
  } catch (e) {
    // Manejar errores de conexión
    Get.back();
    Get.snackbar('Error', 'Failed to connect to ESP32 AP: $e');
  }
}
