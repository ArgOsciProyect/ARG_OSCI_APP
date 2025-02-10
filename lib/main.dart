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

  if (Platform.isAndroid) {
    await requestPermissions();
  }
  // Initialize dependencies
  await Initializer.init();

  runApp(MyApp());
}

Future<void> requestPermissions() async {
  await [
    Permission.locationAlways,
    Permission.nearbyWifiDevices,
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
      getPages: [
        GetPage(name: '/', page: () => SetupScreen()),
        GetPage(name: '/mode_selection', page: () => ModeSelectionScreen()),
        GetPage(
            name: '/graph', page: () => GraphScreen(graphMode: 'Oscilloscope')),
      ],
    );
  }
}
