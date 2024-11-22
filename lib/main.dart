// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'config/app_theme.dart';
import 'features/socket/screens/setup_screen.dart';
import 'features/socket/domain/services/socket_service.dart';
import 'features/socket/providers/setup_provider.dart';
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();
  // Initialize the services
  final socketService = SocketService();
  Get.put(socketService);
  // Initialize the providers
  Get.put(SetupProvider(socketService));
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