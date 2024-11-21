// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'config/app_theme.dart';
import 'presentation/screens/setup_screen.dart';
import 'domain/entities/socket_connection.dart';
import 'domain/use_cases/send_message.dart';
import 'domain/use_cases/receive_message.dart';
import 'application/controllers/setup_controller.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  // Initialize the entities
  final socketConnection = SocketConnection();
  Get.put(socketConnection);
  // Initialize the use cases
  Get.put(SendMessage(socketConnection));
  Get.put(ReceiveMessage(socketConnection));
  // Initialize the controllers
  Get.put(SetupController(Get.find<SendMessage>(), Get.find<ReceiveMessage>()));
  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await [
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