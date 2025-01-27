// lib/config/initializer.dart
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:get/get.dart';
import '../features/http/domain/models/http_config.dart';
import '../features/socket/domain/models/socket_connection.dart';
import '../features/setup/domain/services/setup_service.dart';
import '../features/setup/providers/setup_provider.dart';
import '../features/graph/domain/services/data_acquisition_service.dart';
import '../features/graph/providers/data_provider.dart';
import '../features/graph/domain/services/fft_chart_service.dart';
import '../features/graph/providers/fft_chart_provider.dart';
import '../features/graph/domain/services/line_chart_service.dart';
import '../features/graph/providers/line_chart_provider.dart';
import '../features/graph/providers/graph_mode_provider.dart';

class Initializer {
  static Future<void> init() async {
    // 1. Initialize DeviceConfigProvider first
    final deviceConfigProvider = DeviceConfigProvider();
    Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);

    // 2. Initialize configs
    final globalHttpConfig = HttpConfig('http://192.168.4.1:81');
    final globalSocketConnection = SocketConnection('192.168.4.1', 8080);
    Get.put<HttpConfig>(globalHttpConfig);
    Get.put<SocketConnection>(globalSocketConnection);

    // 3. Initialize DataAcquisitionService
    final dataAcquisitionService = DataAcquisitionService(globalHttpConfig);
    await dataAcquisitionService.initialize();
    Get.put<DataAcquisitionService>(dataAcquisitionService);

    // 4. Initialize GraphProvider first
    final graphProvider = GraphProvider(
      Get.find<DataAcquisitionService>(),
      Get.find<SocketConnection>(),
    );
    Get.put<GraphProvider>(graphProvider);

    // 5. Initialize FFT services
    final fftChartService = FFTChartService(graphProvider);
    Get.put<FFTChartService>(fftChartService);
    Get.put<FFTChartProvider>(FFTChartProvider(fftChartService));

    // 6. Initialize remaining services
    final lineChartService = LineChartService(graphProvider);
    Get.put<LineChartService>(lineChartService);
    Get.put<LineChartProvider>(LineChartProvider(lineChartService));

    // 7. Initialize mode and setup
    Get.put(GraphModeProvider(
      lineChartService: Get.find<LineChartService>(),
      fftChartService: Get.find<FFTChartService>(),
    ));

    final setupService = SetupService(globalSocketConnection, globalHttpConfig);
    Get.put<SetupService>(setupService);
    Get.put<SetupProvider>(SetupProvider(setupService));
  }
}