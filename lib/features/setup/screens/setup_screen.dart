import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:arg_osci_app/features/setup/widgets/ap_selection_dialog.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [SetupScreen] is a [StatefulWidget] that provides the initial setup screen for the application.
class SetupScreen extends StatefulWidget {
  const SetupScreen({super.key});

  @override
  State<SetupScreen> createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final RxBool _isDarkMode = false.obs;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _isDarkMode.value = Get.isDarkMode;

    // Check for error arguments and show dialog if needed
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _checkAndShowErrorDialog();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      // Update when app resumes
      _isDarkMode.value = Get.isDarkMode;
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Update when dependencies change
    _isDarkMode.value = Get.isDarkMode;
  }

  void _checkAndShowErrorDialog() {
    final args = Get.arguments;
    if (args != null && args['showErrorPopup'] == true) {
      final errorMessage = args['errorMessage'] ?? 'Connection failed';

      // Ensure all services are properly cleaned up first
      _cleanupAfterError();

      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => AlertDialog(
          title: const Text('Connection Error'),
          content: Text(errorMessage),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                // Reset state and prepare for fresh start
                if (Get.isRegistered<SetupProvider>()) {
                  final setupProvider = Get.find<SetupProvider>();
                  setupProvider.reset();
                }
                final dataProvider = Get.find<DataAcquisitionProvider>();
                dataProvider.restartDataAcquisition();
              },
              child: const Text('OK'),
            ),
          ],
        ),
      );
    }
  }

  void _cleanupAfterError() {
    try {
      // Force cleanup of any remaining connections
      if (Get.isRegistered<DataAcquisitionService>()) {
        final service = Get.find<DataAcquisitionService>();
        service.dispose().catchError((e) {
          if (kDebugMode) {
            print('Error during service disposal: $e');
          }
        });
      }

      // Allow time for resources to be released
      Future.delayed(Duration(milliseconds: 500), () {
        if (kDebugMode) {
          print('Finished error cleanup');
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print('Error during cleanup: $e');
      }
    }
  }

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
                Obx(() => Switch(
                      value: _isDarkMode.value,
                      onChanged: (value) {
                        // Set theme first, then update the observable
                        Get.changeThemeMode(
                          value ? ThemeMode.dark : ThemeMode.light,
                        );

                        // Force update the observable to match the theme mode
                        _isDarkMode.value = value;
                      },
                    )),
                const Text('Dark Mode'),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
