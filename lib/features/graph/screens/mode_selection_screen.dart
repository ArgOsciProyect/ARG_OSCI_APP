import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

/// [ModeSelectionScreen] is a Flutter [StatefulWidget] that allows the user to select a graph mode.
class ModeSelectionScreen extends StatefulWidget {
  const ModeSelectionScreen({super.key});

  @override
  State<ModeSelectionScreen> createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen>
    with WidgetsBindingObserver {
  final dataProvider = Get.find<DataAcquisitionProvider>();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    // Stop data when screen is disposed
    if (kDebugMode) {
      print('Stopping data');
    }
    dataProvider.stopData();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final modeProvider = Get.find<UserSettingsProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Select Mode'),
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Get.back(),
        ),
      ),
      body: SafeArea(
        // Add SafeArea to respect system UI
        child: SingleChildScrollView(
          // Add SingleChildScrollView to handle overflow
          child: Center(
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 16.0),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  // Instructions text
                  Padding(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 20, vertical: 10),
                    child: Text(
                      'Select a display mode:',
                      style: Theme.of(context).textTheme.titleLarge,
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 20),
                  // Mode selection buttons
                  ...modeProvider.availableModes.map((mode) => Padding(
                        padding: const EdgeInsets.symmetric(
                            vertical: 10, horizontal: 20),
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            minimumSize: const Size(200, 50),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(10),
                            ),
                          ),
                          onPressed: () => modeProvider.navigateToMode(mode),
                          child: Text(
                            mode,
                            style: const TextStyle(fontSize: 18),
                          ),
                        ),
                      )),
                  // Back button at the bottom
                  const SizedBox(height: 40),
                  TextButton.icon(
                    icon: const Icon(Icons.arrow_back),
                    label: const Text('Return to Setup'),
                    onPressed: () => Get.back(),
                  ),
                  const SizedBox(height: 16), // Add bottom padding
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
