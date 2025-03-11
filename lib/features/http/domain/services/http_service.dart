import 'dart:convert';
import 'dart:io';

import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/repository/http_repository.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:arg_osci_app/features/setup/screens/setup_screen.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';

/// [HttpService] implements the [HttpRepository] to provide HTTP request functionality.
class HttpService implements HttpRepository {
  final HttpConfig config;
  static const int _maxRetries = 5;

  // Add this function parameter with default implementation
  final void Function(String) navigateToSetupScreen;

  HttpService(this.config, {void Function(String)? navigateToSetupScreen})
      : navigateToSetupScreen =
            navigateToSetupScreen ?? _defaultNavigateToSetupScreen;

  // Default implementation as a static method
  static void _defaultNavigateToSetupScreen(String errorMessage) async {
    try {
      // Check if we're already on the setup screen to prevent navigation loops
      final bool isAlreadyOnSetupScreen = _isOnSetupScreen();

      if (kDebugMode) {
        print('Current route: ${Get.currentRoute}');
        print('Already on setup screen: $isAlreadyOnSetupScreen');
      }

      if (isAlreadyOnSetupScreen) {
        if (kDebugMode) {
          print('Already on setup screen');
          return;
        }
      }

      // First stop all data acquisition before navigation
      if (Get.isRegistered<DataAcquisitionProvider>()) {
        final dataProvider = Get.find<DataAcquisitionProvider>();
        await dataProvider.stopData().timeout(
          const Duration(seconds: 3),
          onTimeout: () {
            if (kDebugMode) {
              print('Timeout stopping data during error navigation');
            }
            return null;
          },
        );
      }

      // Small delay to ensure cleanup processes complete
      await Future.delayed(const Duration(milliseconds: 200));

      if (isAlreadyOnSetupScreen) {
        // If already on setup screen, just show the error dialog
        if (kDebugMode) {
          print('Already on setup screen');
          return;
        }

        // Show error dialog without navigation
        Get.dialog(
          AlertDialog(
            title: const Text('Connection Error'),
            content: Text(errorMessage),
            actions: [
              TextButton(
                onPressed: () {
                  Get.back(); // Close dialog

                  // Reset state for retry
                  if (Get.isRegistered<SetupProvider>()) {
                    final setupProvider = Get.find<SetupProvider>();
                    setupProvider.reset();
                  }
                },
                child: const Text('OK'),
              ),
            ],
          ),
          barrierDismissible: false,
        );
      } else {
        // Navigate to setup screen with error popup
        if (kDebugMode) {
          print('Navigating to setup screen with error popup');
        }

        Get.offAll(() => const SetupScreen(),
            arguments: {'showErrorPopup': true, 'errorMessage': errorMessage});
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during HTTP error handling: $e');
      }

      // Navigation fallback if error handling fails
      if (!_isOnSetupScreen()) {
        Get.offAll(() => const SetupScreen(),
            arguments: {'showErrorPopup': true, 'errorMessage': errorMessage});
      }
    }
  }

  // Helper method to check if we're on the setup screen
  static bool _isOnSetupScreen() {
    return Get.currentRoute == '/' || Get.currentRoute.contains('setup');
  }

  @override
  String get baseUrl => config.baseUrl;

  /// Retry mechanism for HTTP requests
  /// [skipNavigation] - if true, won't navigate to setup screen on error (default: false)
  Future<dynamic> _retryRequest(
    Future<dynamic> Function() requestFunc, {
    bool skipNavigation = false,
  }) async {
    int retries = 0;
    while (true) {
      try {
        return await requestFunc();
      } catch (e) {
        retries++;
        if (kDebugMode) {
          print('Request failed (attempt $retries): $e');
        }

        if (retries >= _maxRetries) {
          if (skipNavigation) {
            // Just throw the exception without navigation
            throw HttpException('Max retries reached: $e');
          } else {
            // Use the injected function for navigation
            navigateToSetupScreen(
                'Connection failed after $_maxRetries attempts: $e');
            throw HttpException('Max retries reached: $e');
          }
        }

        // Wait before retrying with exponential backoff
        await Future.delayed(Duration(milliseconds: 200 * retries));
      }
    }
  }

  @override
  Future<dynamic> get(String endpoint, {bool skipNavigation = false}) async {
    return _retryRequest(
      () async {
        final response =
            await config.client!.get(Uri.parse('$baseUrl$endpoint'));
        return _handleResponse(response);
      },
      skipNavigation: skipNavigation,
    );
  }

  @override
  Future<dynamic> post(
    String endpoint, [
    Map<String, dynamic>? body,
    bool skipNavigation = false,
  ]) async {
    return _retryRequest(
      () async {
        final response = await config.client!.post(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: body != null ? jsonEncode(body) : null,
        );
        return _handleResponse(response);
      },
      skipNavigation: skipNavigation,
    );
  }

  @override
  Future<dynamic> put(
    String endpoint,
    Map<String, dynamic> body, {
    bool skipNavigation = false,
  }) async {
    return _retryRequest(
      () async {
        final response = await config.client!.put(
          Uri.parse('$baseUrl$endpoint'),
          headers: {'Content-Type': 'application/json'},
          body: jsonEncode(body),
        );
        return _handleResponse(response);
      },
      skipNavigation: skipNavigation,
    );
  }

  @override
  Future<dynamic> delete(String endpoint, {bool skipNavigation = false}) async {
    return _retryRequest(
      () async {
        final response =
            await config.client!.delete(Uri.parse('$baseUrl$endpoint'));
        return _handleResponse(response);
      },
      skipNavigation: skipNavigation,
    );
  }

  /// Handles the HTTP response and parses the JSON body.
  dynamic _handleResponse(dynamic response) {
    if (response.statusCode == 200) {
      try {
        return jsonDecode(response.body);
      } catch (e) {
        throw FormatException('Invalid JSON response: $e');
      }
    } else {
      throw HttpException('Request failed with status: ${response.statusCode}');
    }
  }
}
