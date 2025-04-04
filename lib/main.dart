import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'config/app_theme.dart';
import 'features/setup/screens/setup_screen.dart';
import 'features/graph/screens/graph_screen.dart';
import 'features/graph/screens/mode_selection_screen.dart';
import 'config/initializer.dart'; // Import the Initializer
import 'package:permission_handler/permission_handler.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Force landscape orientation
  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.landscapeLeft,
    DeviceOrientation.landscapeRight,
  ]);

  // Request permissions on Android devices
  if (Platform.isAndroid) {
    await requestPermissions();
  }
  // Initialize dependencies
  await Initializer.init();

  runApp(MyApp());
}

/// Requests necessary permissions for the app.
Future<void> requestPermissions() async {
  await [
    Permission.nearbyWifiDevices,
  ].request();
}

/// [MyApp] is the root [StatelessWidget] of the application.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      debugShowCheckedModeBanner: false, // Remove debug banner
      title: 'ARG_OSCI',
      theme: AppTheme.lightTheme,
      darkTheme: AppTheme.darkTheme,
      themeMode: ThemeMode.light,
      home: SetupScreen(),
      getPages: [
        GetPage(name: '/', page: () => SetupScreen()),
        GetPage(name: '/mode_selection', page: () => ModeSelectionScreen()),
        GetPage(
            name: '/graph', page: () => GraphScreen(graphMode: 'Oscilloscope')),
      ],
    );
  }
}
