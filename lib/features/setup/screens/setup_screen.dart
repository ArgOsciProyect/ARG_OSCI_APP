// lib/features/setup/screens/setup_screen.dart
import 'package:flutter/material.dart';
import '../widgets/ap_selection_dialog.dart';

class SetupScreen extends StatelessWidget {
  const SetupScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Oscilloscope')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await showAPSelectionDialog(); // Remove context parameter
              },
              child: const Text('Select AP Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
