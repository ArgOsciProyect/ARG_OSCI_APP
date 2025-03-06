// lib/config/app_restart_service.dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/config/initializer.dart';
import 'package:arg_osci_app/features/setup/screens/setup_screen.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';

class AppRestartService extends GetxService {
  static final _instance = AppRestartService._internal();
  factory AppRestartService() => _instance;
  AppRestartService._internal();

  // Flag to prevent multiple restarts at once
  bool _isRestarting = false;

  static Future<void> restartApp() async {
    final service = Get.find<AppRestartService>();
    await service._restartInternal();
  }

  Future<void> _restartInternal() async {
    // Prevent multiple concurrent restarts
    if (_isRestarting) {
      if (kDebugMode) {
        print('Restart already in progress, ignoring request');
      }
      return;
    }

    _isRestarting = true;

    if (kDebugMode) {
      print('=== FULL APP RESTART INITIATED ===');
    }

    try {
      // 1. First perform a proper cleanup of all resources
      await _fullCleanup();

      // 2. Force disposal of all GetX controllers and their dependencies
      Get.reset(clearRouteBindings: true);

      // 3. Wait a moment for all resources to finish cleanup
      await Future.delayed(const Duration(milliseconds: 300));

      // 4. Reinitialize from scratch through Initializer
      await Initializer.init();

      // 5. Navigate to home with clean stack, ensuring all previous routes are removed
      await Get.offAll(() => const SetupScreen(), predicate: (_) => false);

      if (kDebugMode) {
        print('=== APP RESTART COMPLETED SUCCESSFULLY ===');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Critical error during app restart: $e');
      }

      // Even if restart fails, try to navigate back to setup screen as safety measure
      Get.offAll(() => const SetupScreen());
    } finally {
      _isRestarting = false;
    }
  }

  Future<void> _fullCleanup() async {
    if (kDebugMode) {
      print('Performing full cleanup of all resources...');
    }

    try {
      // Terminate all data acquisition first
      if (Get.isRegistered<DataAcquisitionService>()) {
        final service = Get.find<DataAcquisitionService>();
        await service.stopData().timeout(const Duration(seconds: 2),
            onTimeout: () {
          if (kDebugMode) {
            print('Warning: stopData() timed out, forcing disposal');
          }
        });
        await service.dispose().timeout(const Duration(seconds: 2),
            onTimeout: () {
          if (kDebugMode) {
            print('Warning: dispose() timed out, continuing cleanup');
          }
        });
      }

      // Close all socket connections
      if (Get.isRegistered<SocketService>()) {
        await Get.find<SocketService>()
            .close()
            .timeout(const Duration(seconds: 2), onTimeout: () {
          if (kDebugMode) {
            print('Warning: socket close timed out, continuing cleanup');
          }
        });
      }

      // Close HTTP clients
      if (Get.isRegistered<HttpConfig>()) {
        final config = Get.find<HttpConfig>();
        config.client?.close();
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error during resource cleanup: $e');
      }
      // Continue with restart even if cleanup fails
    }
  }
}
