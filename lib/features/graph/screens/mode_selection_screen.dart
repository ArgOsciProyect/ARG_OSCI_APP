// lib/features/graph/screens/mode_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'graph_screen.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Select Mode')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () {
                // Navegar a GraphScreen en modo Oscilloscope
                Get.to(() => GraphScreen(mode: 'Oscilloscope'));
              },
              child: Text('Oscilloscope Mode'),
            ),
            ElevatedButton(
              onPressed: () {
                // Aquí puedes agregar la lógica para el modo Spectrum Analyzer en el futuro
                Get.snackbar('Mode Selection', 'Spectrum Analyzer mode is not implemented yet.');
              },
              child: Text('Spectrum Analyzer Mode'),
            ),
          ],
        ),
      ),
    );
  }
}