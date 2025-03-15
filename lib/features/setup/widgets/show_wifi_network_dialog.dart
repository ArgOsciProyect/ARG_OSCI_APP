import 'package:arg_osci_app/features/setup/domain/models/setup_status.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [showWiFiNetworkDialog] displays a dialog to scan and select available WiFi networks.
///
/// Initiates WiFi network scanning and presents results in a selectable list.
/// Handles different states including scanning, selection, and error conditions.
Future<void> showWiFiNetworkDialog() async {
  final controller = Get.find<SetupProvider>();

  try {
    // Initiate the WiFi network scanning process
    controller.handleExternalAPSelection();

    await Get.dialog(
      PopScope(
        canPop: false,
        child: AlertDialog(
          title: const Text('Scanning Networks'),
          content: SizedBox(
            width: 300,
            height: MediaQuery.of(Get.context!).size.height * 0.5,
            child: Obx(() {
              final state = controller.state;

              switch (state.status) {
                case SetupStatus.scanning:
                  // Display a loading indicator while scanning
                  return const Center(
                    child: CircularProgressIndicator(),
                  );

                case SetupStatus.selecting:
                  // Display the list of available WiFi networks
                  return Column(
                    children: [
                      Expanded(
                        child: ListView.builder(
                          itemCount: state.networks.length,
                          itemBuilder: (_, i) => ListTile(
                            title: Text(state.networks[i]),
                            onTap: () async {
                              Get.back();
                              await askForPassword(state.networks[i]);
                            },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      ElevatedButton.icon(
                        // Button to rescan for WiFi networks
                        onPressed: () {
                          controller.handleExternalAPSelection();
                        },
                        icon: const Icon(Icons.refresh),
                        label: const Text('Rescan Networks'),
                      ),
                    ],
                  );

                case SetupStatus.error:
                  // Display an error message and retry options
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text('Error: ${state.error}'),
                      const SizedBox(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                        children: [
                          TextButton(
                            child: const Text('Retry'),
                            onPressed: () {
                              controller.reset();
                              controller.handleExternalAPSelection();
                            },
                          ),
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Back'),
                          ),
                        ],
                      ),
                    ],
                  );

                default:
                  return const SizedBox.shrink();
              }
            }),
          ),
        ),
      ),
    );
  } catch (e) {
    Get.back();
    Get.snackbar('Error', e.toString());
  }
}

/// [askForPassword] prompts the user for the password of a selected WiFi network.
///
/// Shows a password input dialog and attempts to connect to the selected network.
/// Displays connection progress and handles success/failure states.
///
/// [ssid] The name of the selected WiFi network
Future<void> askForPassword(String ssid) async {
  final passwordController = TextEditingController();
  final controller = Get.find<SetupProvider>();
  final formKey = GlobalKey<FormState>();

  try {
    // Show dialog to input WiFi password once.
    final password = await Get.dialog<String>(
      PopScope(
        canPop: false,
        child: Dialog(
          child: Builder(builder: (context) {
            // Get the orientation
            final isLandscape =
                MediaQuery.of(context).orientation == Orientation.landscape;

            return SingleChildScrollView(
              child: Container(
                padding: const EdgeInsets.all(16),
                width: isLandscape ? 360 : 300,
                child: Form(
                  key: formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Enter Password for $ssid',
                          style: Theme.of(Get.context!).textTheme.titleLarge,
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(
                                horizontal: 12, vertical: 12),
                          ),
                          obscureText: true,
                          autofocus: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                          onFieldSubmitted: (value) {
                            if (formKey.currentState!.validate()) {
                              Get.back(result: value);
                            }
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.end,
                        children: [
                          TextButton(
                            onPressed: () => Get.back(),
                            child: const Text('Cancel'),
                          ),
                          const SizedBox(width: 8),
                          ElevatedButton(
                            onPressed: () {
                              // Hide keyboard first to improve UX
                              FocusScope.of(context).unfocus();

                              if (formKey.currentState!.validate()) {
                                Get.back(result: passwordController.text);
                              }
                            },
                            child: const Text('Connect'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ),
      ),
    );

    // If a password was entered, attempt to connect
    if (password != null && password.isNotEmpty) {
      // Show connecting dialog
      final connectingDialog = Get.dialog(
        PopScope(
          canPop: false,
          child: AlertDialog(
            title: const Text('Connecting'),
            content: SizedBox(
              width: 300,
              child: Obx(() {
                final state = controller.state;
                switch (state.status) {
                  case SetupStatus.configuring:
                    return const Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        CircularProgressIndicator(),
                        SizedBox(height: 16),
                        Text('Connecting to network...'),
                      ],
                    );
                  case SetupStatus.waitingForNetworkChange:
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.wifi, size: 48),
                        const SizedBox(height: 16),
                        Text(
                          'Please connect your device to\n"$ssid"',
                          textAlign: TextAlign.center,
                          style: const TextStyle(fontSize: 16),
                        ),
                        const SizedBox(height: 24),
                        const CircularProgressIndicator(),
                      ],
                    );
                  case SetupStatus.error:
                    return Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(state.error ?? 'Connection failed'),
                        const SizedBox(height: 16),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                          children: [
                            TextButton(
                              onPressed: () async {
                                await controller.connectToExternalAP(
                                    ssid, password);
                              },
                              child: const Text('Retry'),
                            ),
                            TextButton(
                              onPressed: () => Get.back(),
                              child: const Text('Exit'),
                            ),
                          ],
                        ),
                      ],
                    );
                  default:
                    return const SizedBox.shrink();
                }
              }),
            ),
          ),
        ),
      );

      // First connection attempt with the entered password.
      await controller.connectToExternalAP(ssid, password);

      // Wait a short period to see if connection becomes successful.
      await Future.delayed(const Duration(seconds: 2));

      // If connection is successful, proceed; otherwise, the connectingDialog
      // will now show error options for retry or exit.
      if (controller.state.status == SetupStatus.completed) {
        Get.back(); // Close connecting dialog
        await Get.offNamed('/mode_selection');
      } else {
        // Wait for user's action on the connecting dialog.
        await connectingDialog;
      }
    }
  } catch (e) {
    Get.back();
    Get.snackbar(
      'Connection Error',
      e.toString(),
      backgroundColor: Colors.red[100],
      colorText: Colors.red[900],
      duration: const Duration(seconds: 5),
    );
  }
}
