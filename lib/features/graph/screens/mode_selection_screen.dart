import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';

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
