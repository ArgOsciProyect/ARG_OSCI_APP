import 'package:arg_osci_app/features/setup/widgets/ap_selection_dialog.dart';
import 'package:flutter/material.dart';

/// [SetupScreen] is a [StatelessWidget] that provides the initial setup screen for the application.
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
              //Calls the AP selection dialog when pressed
              onPressed: () async {
                await showAPSelectionDialog();
              },
              child: const Text('Select AP Mode'),
            ),
          ],
        ),
      ),
    );
  }
}
