// lib/config/initializer.dart
import 'package:get/get.dart';
import '../features/http/domain/models/http_config.dart';
import '../features/socket/domain/models/socket_connection.dart';
import '../features/setup/domain/services/setup_service.dart';
import '../features/setup/providers/setup_provider.dart';
import '../features/graph/domain/services/data_acquisition_service.dart';
import '../features/graph/providers/graph_provider.dart';

class Initializer {
  static Future<void> init() async {
    // Initialize global configurations
    final globalHttpConfig = HttpConfig('http://192.168.4.1:81');
    final globalSocketConnection = SocketConnection('192.168.4.1', 8080);

    // Register core configurations
    Get.put<HttpConfig>(globalHttpConfig);
    Get.put<SocketConnection>(globalSocketConnection);

    // Initialize and register DataAcquisitionService
    final dataAcquisitionService = DataAcquisitionService(globalHttpConfig);
    await dataAcquisitionService.initialize(); // Initialize configuration
    Get.put<DataAcquisitionService>(dataAcquisitionService);

    // Initialize and register SetupService
    final setupService = SetupService(globalSocketConnection, globalHttpConfig);
    Get.put<SetupService>(setupService);

    // Initialize providers
    Get.put<SetupProvider>(SetupProvider(setupService));
    Get.put<GraphProvider>(GraphProvider(
      Get.find<DataAcquisitionService>(),
      Get.find<SocketConnection>()
    ));
  }
}