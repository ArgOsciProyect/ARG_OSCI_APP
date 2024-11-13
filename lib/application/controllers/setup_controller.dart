// lib/application/controllers/setup_controller.dart
import 'package:get/get.dart';
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import '../../domain/use_cases/send_recognition_message.dart';
import '../../domain/entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';

class SetupController extends GetxController {
  final SendRecognitionMessage sendRecognitionMessage;
  final BluetoothCommunicationService bluetoothService;
  var selectedDevice = Rx<BluetoothDevice?>(null);
  var devices = <BluetoothDevice>[].obs;
  final _isScanning = false.obs;

  SetupController(this.sendRecognitionMessage, this.bluetoothService) {
    devices.bindStream(bluetoothService.devices.stream);
    _isScanning.bindStream(bluetoothService.isScanning.stream);
  }

  bool get isScanning => _isScanning.value;

  Future<void> startScan() async {
    devices.clear();
    _isScanning.value = true;
    await bluetoothService.startScan();
    _isScanning.value = false;
  }

  void stopScan() {
    bluetoothService.stopScan();
    _isScanning.value = false;
  }

  void selectDevice(BluetoothDevice device) {
    selectedDevice.value = device;
  }

  Future<void> sendRecognition() async {
    final device = selectedDevice.value;
    if (device != null) {
      final connection = BluetoothConnection(
        deviceId: device.remoteId.str,
        deviceName: device.platformName.isNotEmpty ? device.platformName : 'Unknown Device',
      );
      await sendRecognitionMessage.execute(connection);
    } else {
      Get.snackbar('Error', 'No device selected');
    }
  }
}