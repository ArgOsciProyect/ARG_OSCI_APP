import 'package:arg_osci_app/features/setup/widgets/ap_selection_dialog.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [SetupScreen] is a [StatelessWidget] that provides the initial setup screen for the application.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> {
  bool _isDarkMode = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('ARG_OSCI')),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ElevatedButton(
              onPressed: () async {
                await showAPSelectionDialog();
              },
              child: const Text('Select AP Mode'),
            ),
            const SizedBox(height: 20),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('Light Mode'),
                Switch(
                  value: _isDarkMode,
                  onChanged: (value) {
                    setState(() {
                      _isDarkMode = value;
                    });
                    Get.changeThemeMode(
                      _isDarkMode ? ThemeMode.dark : ThemeMode.light,
                    );
                  },
                ),
                const Text('Dark Mode'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
