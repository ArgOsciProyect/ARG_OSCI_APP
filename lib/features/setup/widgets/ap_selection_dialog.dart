import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../providers/setup_provider.dart';
import 'show_wifi_network_dialog.dart';
import '../../graph/screens/graph_screen.dart';
import '../../data_acquisition/domain/services/data_acquisition_service.dart';

Future<void> showAPSelectionDialog(BuildContext context) async {
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
            onPressed: () async {
              // Handle Local AP selection
              Get.back();
              await controller.handleModeSelection('Internal AP');
              Get.snackbar('AP Mode', 'Local AP selected.');

              // Iniciar la adquisición de datos
              final dataAcquisitionService = Get.find<DataAcquisitionService>();
              dataAcquisitionService.fetchData();

              // Navegar a GraphScreen
              Get.to(() => GraphScreen());
            },
            child: Text('Local AP'),
          ),
          TextButton(
            onPressed: () async {
              // Handle External AP selection
              Get.back();
              await controller.handleModeSelection('External AP');
              await showWiFiNetworkDialog(context);
            },
            child: Text('External AP'),
          ),
        ],
      ),
    );
  });
}