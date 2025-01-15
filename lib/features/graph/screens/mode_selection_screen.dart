// lib/features/graph/screens/mode_selection_screen.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/providers/graph_mode_provider.dart';

class ModeSelectionScreen extends StatelessWidget {
  const ModeSelectionScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final modeProvider = Get.find<GraphModeProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: modeProvider.availableModes
              .map((mode) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: ElevatedButton(
                      onPressed: () => modeProvider.navigateToMode(mode),
                      child: Text(mode),
                    ),
                  ))
              .toList(),
        ),
      ),
    );
  }
}
