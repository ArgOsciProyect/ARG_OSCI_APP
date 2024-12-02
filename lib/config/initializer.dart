// lib/config/initializer.dart
import 'package:get/get.dart';
import '../features/socket/domain/services/socket_service.dart';
import '../features/setup/domain/services/setup_service.dart';
import '../features/setup/providers/setup_provider.dart';
import '../features/http/domain/models/http_config.dart';

class Initializer {
  static Future<void> init() async {
    // Initialize the global services
    final globalSocketService = SocketService();
    final setupService = SetupService(globalSocketService, HttpConfig('http://192.168.4.1:81'));
    
    // Register services with GetX
    Get.put(globalSocketService);
    Get.put(setupService);
    
    // Initialize the providers
    Get.put(SetupProvider(setupService));
  }
}