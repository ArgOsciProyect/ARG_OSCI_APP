// lib/config/initializer.dart
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:get/get.dart';
import '../features/socket/domain/services/socket_service.dart';
import '../features/setup/domain/services/setup_service.dart';
import '../features/setup/providers/setup_provider.dart';
import '../features/http/domain/models/http_config.dart';
import '../features/data_acquisition/domain/services/data_acquisition_service.dart';

class Initializer {
  static Future<void> init() async {
    // Initialize the global services
    final SocketService globalSocketService = SocketService();
    final HttpService globalHttpService = HttpService(HttpConfig('http://192.168.4.1:81'));
    final setupService = SetupService(globalSocketService, globalHttpService);

    // Register services with GetX
    Get.put(globalSocketService);
    Get.put(setupService);
    Get.put(globalHttpService);

    // Initialize the data acquisition service with the global services
    final dataAcquisitionService = DataAcquisitionService(globalSocketService, globalHttpService);
    Get.put(dataAcquisitionService);

    // Initialize the providers
    Get.put(SetupProvider(setupService));
  }
}