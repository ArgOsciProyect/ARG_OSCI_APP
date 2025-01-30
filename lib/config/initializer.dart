// lib/config/initializer.dart
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';
import '../features/http/domain/models/http_config.dart';
import '../features/socket/domain/models/socket_connection.dart';
import '../features/setup/domain/services/setup_service.dart';
import '../features/setup/providers/setup_provider.dart';
import '../features/graph/domain/services/data_acquisition_service.dart';
import '../features/graph/providers/data_acquisition_provider.dart';
import '../features/graph/domain/services/fft_chart_service.dart';
import '../features/graph/providers/fft_chart_provider.dart';
import '../features/graph/domain/services/line_chart_service.dart';
import '../features/graph/providers/line_chart_provider.dart';
import '../features/graph/providers/graph_mode_provider.dart';

class Initializer {
  static Future<void> init() async {
    try {
      // 1. Initialize configs and base providers
      final globalHttpConfig = HttpConfig('http://192.168.4.1:81');
      final globalSocketConnection = SocketConnection('192.168.4.1', 8080);
      final deviceConfigProvider = DeviceConfigProvider();

      // 2. Register base dependencies
      Get.put<HttpConfig>(globalHttpConfig, permanent: true);
      Get.put<SocketConnection>(globalSocketConnection, permanent: true);
      Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);

      // 3. Initialize main service
      final dataAcquisitionService = DataAcquisitionService(globalHttpConfig);
      await dataAcquisitionService.initialize();
      Get.put<DataAcquisitionService>(dataAcquisitionService, permanent: true);

      // 4. Initialize chart services first since they don't have dependencies
      final lineChartService = LineChartService(null); // Will be updated later
      final fftChartService = FFTChartService(null); // Will be updated later

      Get.put<LineChartService>(lineChartService, permanent: true);
      Get.put<FFTChartService>(fftChartService, permanent: true);

      // 5. Initialize GraphModeProvider before DataAcquisitionProvider
      final graphModeProvider = GraphModeProvider(
        lineChartService: lineChartService,
        fftChartService: fftChartService,
      );
      Get.put<GraphModeProvider>(graphModeProvider, permanent: true);

      // 6. Now initialize DataAcquisitionProvider
      final dataAcquisitionProvider = DataAcquisitionProvider(
        dataAcquisitionService,
        globalSocketConnection,
      );
      Get.put<DataAcquisitionProvider>(dataAcquisitionProvider,
          permanent: true);

      // 7. Update services with the provider
      lineChartService.updateProvider(dataAcquisitionProvider);
      fftChartService.updateProvider(dataAcquisitionProvider);

      // 8. Initialize remaining chart providers
      final lineChartProvider = LineChartProvider(lineChartService);
      final fftChartProvider = FFTChartProvider(fftChartService);

      Get.put<LineChartProvider>(lineChartProvider, permanent: true);
      Get.put<FFTChartProvider>(fftChartProvider, permanent: true);

      // 9. Initialize setup related dependencies last
      final setupService =
          SetupService(globalSocketConnection, globalHttpConfig);
      final setupProvider = SetupProvider(setupService);

      Get.put<SetupService>(setupService);
      Get.put<SetupProvider>(setupProvider);
    } catch (e) {
      print('Error during initialization: $e');
      rethrow;
    }
  }
}
