import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/line_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/line_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/setup/domain/services/setup_service.dart';
import 'package:arg_osci_app/features/setup/providers/setup_provider.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';


class Initializer {
  static Future<void> init() async {
    try {
      // 1. Initialize configs and base providers
      final globalHttpConfig = HttpConfig('http://192.168.4.1:81');
      final globalSocketConnection = SocketConnection('192.168.4.1', 8080);
      final deviceConfigProvider = DeviceConfigProvider();

      // 2. Register base dependencies

      Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);
      Get.put<HttpConfig>(globalHttpConfig, permanent: true);
      Get.put<SocketConnection>(globalSocketConnection, permanent: true);

      // NEW: Register HttpService before DataAcquisitionService
      final httpService = HttpService(globalHttpConfig);
      Get.put<HttpService>(httpService, permanent: true);

      // 3. Initialize main service
      final dataAcquisitionService = DataAcquisitionService(globalHttpConfig);
      await dataAcquisitionService.initialize();
      Get.put<DataAcquisitionService>(dataAcquisitionService, permanent: true);

      // Rest of initialization...
      final lineChartService = LineChartService(null);
      final fftChartService = FFTChartService(null);

      Get.put<LineChartService>(lineChartService, permanent: true);
      Get.put<FFTChartService>(fftChartService, permanent: true);

      Get.put(
          UserSettingsProvider(
            lineChartService: Get.find<LineChartService>(),
            fftChartService: Get.find<FFTChartService>(),
          ),
          permanent: true);

      final dataAcquisitionProvider = DataAcquisitionProvider(
        dataAcquisitionService,
        globalSocketConnection,
      );
      Get.put<DataAcquisitionProvider>(dataAcquisitionProvider,
          permanent: true);

      lineChartService.updateProvider(dataAcquisitionProvider);
      fftChartService.updateProvider(dataAcquisitionProvider);

      final lineChartProvider = LineChartProvider(lineChartService);
      final fftChartProvider = FFTChartProvider(fftChartService);

      Get.put<LineChartProvider>(lineChartProvider, permanent: true);
      Get.put<FFTChartProvider>(fftChartProvider, permanent: true);

      final setupService =
          SetupService(globalSocketConnection, globalHttpConfig);
      final setupProvider = SetupProvider(setupService);

      Get.put<SetupService>(setupService);
      Get.put<SetupProvider>(setupProvider);
    } catch (e) {
      if (kDebugMode) {
        print('Error during initialization: $e');
      }
      rethrow;
    }
  }
}
