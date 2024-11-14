import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:permission_handler/permission_handler.dart';
import 'config/app_theme.dart';
import 'presentation/screens/setup_screen.dart';
import 'application/services/bluetooth_communication_service.dart';
import 'domain/use_cases/send_recognition_message.dart';
import 'domain/use_cases/ble_connect_to_device.dart';
import 'application/controllers/setup_controller.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  // Initialize the services
  final bluetoothService = BluetoothCommunicationService();
  Get.put(bluetoothService);
  // Initialize the use cases
  Get.put(SendRecognitionMessage(bluetoothService));
  Get.put(ConnectToDevice(bluetoothService));
  // Initialize the controllers
  Get.put(SetupController(Get.find<ConnectToDevice>(), Get.find<SendRecognitionMessage>(), bluetoothService));
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await [
    Permission.bluetooth,
    Permission.bluetoothScan,
    Permission.bluetoothConnect,
    Permission.location,
  ].request();
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'ARG_OSCI',
      theme: appTheme,
      home: SetupScreen(),
    );
  }
}