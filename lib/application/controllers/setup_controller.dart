// lib/application/controllers/setup_controller.dart
import 'package:get/get.dart';
import '../../domain/use_cases/ble_connect_to_device.dart';
import '../../domain/use_cases/send_recognition_message.dart';
import '../../domain/entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';

class SetupController extends GetxController {
  final ConnectToDevice connectToDevice;
  final SendRecognitionMessage sendRecognitionMessage;
  final BluetoothCommunicationService bluetoothService;
  var selectedDevice = Rx<BluetoothConnection?>(null);
  var devices = <BluetoothConnection>[].obs;
  final _isScanning = false.obs;

  SetupController(this.connectToDevice, this.sendRecognitionMessage, this.bluetoothService);

  bool get isScanning => _isScanning.value;

  Future<void> startScan() async {
    devices.clear();
    _isScanning.value = true;
    devices.value = await bluetoothService.startScan();
    _isScanning.value = false;
  }

  void stopScan() {
    bluetoothService.stopScan();
    _isScanning.value = false;
  }

  void selectDevice(BluetoothConnection connection) {
    selectedDevice.value = connection;
    connect();
  }

  Future<void> connect() async {
    final connection = selectedDevice.value;
    if (connection != null) {
      await connectToDevice.execute(connection);
    } else {
      Get.snackbar('Error', 'No device selected');
    }
  }

  Future<void> sendRecognition() async {
    final connection = selectedDevice.value;
    if (connection != null) {
      await sendRecognitionMessage.execute(connection);
    } else {
      Get.snackbar('Error', 'No device selected');
    }
  }
}