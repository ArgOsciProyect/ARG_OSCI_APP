// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'config/app_theme.dart';
import 'features/setup/screens/setup_screen.dart';
import 'features/socket/domain/services/socket_service.dart';
import 'features/setup/domain/services/setup_service.dart';
import 'features/setup/providers/setup_provider.dart';
import 'features/http/domain/models/http_config.dart'; // Importar HttpConfig
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();

  // Initialize the global services
  final globalSocketService = SocketService();
  final setupService = SetupService(globalSocketService, HttpConfig('http://192.168.4.1'));
  Get.put(globalSocketService);
  Get.put(setupService);

  // Initialize the providers
  Get.put(SetupProvider(setupService));

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