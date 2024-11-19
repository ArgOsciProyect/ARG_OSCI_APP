// lib/presentation/screens/setup_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../application/controllers/setup_controller.dart';
import '../widgets/recognition_button.dart';
import '../../application/services/bluetooth_communication_service.dart';
import '../../domain/use_cases/send_message.dart';
import '../../domain/use_cases/ble_connect_to_device.dart';
import '../widgets/show_bluetooth_device_dialog.dart';
import '../../domain/use_cases/receive_message.dart';

class SetupScreen extends StatelessWidget {
  final SetupController controller = Get.put(SetupController(
    Get.find<ConnectToDevice>(),
    Get.find<SendMessage>(),
    Get.find<BluetoothCommunicationService>(),
    Get.find<ReceiveMessage>(),
  ));

  SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Oscilloscope')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                showBluetoothDeviceDialog(context);
              },
              child: Text('Select Bluetooth Device'),
            ),
            SizedBox(height: 20),
            RecognitionButton(),
          ],
        ),
      ),
    );
  }
}