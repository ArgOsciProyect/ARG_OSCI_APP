import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'config/themes/app_theme.dart';
import 'presentation/screens/setup_page.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: SetupPage(),
      title: 'ARG_OSCI',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.getTheme(),
    );
  }
}