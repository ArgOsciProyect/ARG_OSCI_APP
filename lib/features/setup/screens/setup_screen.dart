// lib/features/setup/screens/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../widgets/ap_selection_dialog.dart';
import '../../graph/screens/graph_screen.dart';
import '../../data_acquisition/domain/services/data_acquisition_service.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Oscilloscope')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await showAPSelectionDialog(context);
                // Iniciar la adquisición de datos
                final dataAcquisitionService = Get.find<DataAcquisitionService>();
                dataAcquisitionService.fetchData();
                // Navegar a GraphScreen
                Get.to(() => GraphScreen());
              },
              child: Text('Select AP Mode'),
            ),
          ],
        ),
      ),
    );
  }
}