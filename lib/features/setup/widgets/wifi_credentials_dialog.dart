import 'dart:io';
import 'package:flutter/material.dart';

class WiFiCredentialsDialog extends StatefulWidget {
  const WiFiCredentialsDialog({super.key});

  @override
  State<WiFiCredentialsDialog> createState() => _WiFiCredentialsDialogState();
}

class _WiFiCredentialsDialogState extends State<WiFiCredentialsDialog> {
  final TextEditingController _ssidController = TextEditingController(text: 'ESP32_AP');
  final TextEditingController _passwordController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final bool _isAndroid = Platform.isAndroid;

  @override
  void dispose() {
    _ssidController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Instead of a dialog, use a landscape-friendly bottom sheet
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Builder(builder: (context) {
        // Get the orientation
        final isLandscape = MediaQuery.of(context).orientation == Orientation.landscape;

        return Center(
          child: SingleChildScrollView(
            child: Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Theme.of(context).dialogBackgroundColor,
                borderRadius: BorderRadius.circular(8),
              ),
              width: isLandscape ? 360 : null,
              child: Form(
                key: _formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Text(
                        _isAndroid
                            ? 'ESP32 WiFi Credentials'
                            : 'Enter ESP32 Network Name',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TextFormField(
                        controller: _ssidController,
                        decoration: const InputDecoration(
                          labelText: 'ESP32 AP SSID',
                          border: OutlineInputBorder(),
                          contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          hintText: 'Default: ESP32_AP',
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter SSID';
                          }
                          return null;
                        },
                      ),
                    ),
                    // Only show password field for Android
                    if (_isAndroid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: TextFormField(
                          controller: _passwordController,
                          decoration: const InputDecoration(
                            labelText: 'Password',
                            border: OutlineInputBorder(),
                            contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                          ),
                          obscureText: true,
                          validator: (value) {
                            if (value == null || value.isEmpty) {
                              return 'Please enter password';
                            }
                            return null;
                          },
                        ),
                      ),
                    // Explanation text for non-Android platforms
                    if (!_isAndroid)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 16),
                        child: Text(
                          'Please connect to the ESP32 WiFi network manually in your device settings, then enter the network name above.',
                          style: Theme.of(context).textTheme.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 8),
                        ElevatedButton(
                          onPressed: () {
                            // Hide keyboard first to improve UX
                            FocusScope.of(context).unfocus();

                            if (_formKey.currentState!.validate()) {
                              Navigator.pop(
                                context,
                                {
                                  'ssid': _ssidController.text,
                                  'password': _isAndroid ? _passwordController.text : '',
                                },
                              );
                            }
                          },
                          child: Text(_isAndroid ? 'Connect' : 'Continue'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      }),
    );
  }
}