// lib/main.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'config/app_theme.dart';
import 'features/setup/screens/setup_screen.dart';
import 'config/initializer.dart'; // Import the Initializer
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await requestPermissions();

  // Initialize dependencies
  await Initializer.init();

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