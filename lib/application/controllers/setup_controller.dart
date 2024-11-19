// lib/application/controllers/setup_controller.dart
import 'package:arg_osci_app/domain/use_cases/receive_message.dart';
import 'package:get/get.dart';
import '../../domain/use_cases/ble_connect_to_device.dart';
import '../../domain/use_cases/send_message.dart';
import '../../domain/entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';
import 'dart:convert';

class SetupController extends GetxController {
  final ConnectToDevice connectToDevice;
  final SendMessage sendMessage;
  final BluetoothCommunicationService bluetoothService;
  final ReceiveMessage receiveMessage;
  var selectedDevice = Rx<BluetoothConnection?>(null);
  var devices = <BluetoothConnection>[].obs;
  final _isScanning = false.obs;

  SetupController(this.connectToDevice, this.sendMessage, this.bluetoothService, this.receiveMessage);

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

  Future<void> sendMessageToDevice(String message) async {
    final connection = selectedDevice.value;
    if (connection != null) {
      await sendMessage.execute(connection, message);
    } else {
      Get.snackbar('Error', 'No device selected');
    }
  }

  Future<bool> runRecognition() async {
    try {
      final connection = selectedDevice.value;
      if (connection != null) {
        await sendMessageToDevice('ack');
        final message = await receiveMessage.execute(connection);
        if (message == 'ack') {
          Get.snackbar('Nice', 'Recognition successful');
          return true;
        } else {
          Get.snackbar('Error', 'Received ack = $message');
        }
      } else {
        Get.snackbar('Error', 'No device selected');
      }
    } catch (e) {
      Get.snackbar('Error', 'An error occurred: $e');
    }
    return false;
  }

  Future<String?> setupSecureConnection() async {
    final connection = selectedDevice.value;
    if (connection != null) {
      String publicKey = await bluetoothService.receivePublicKey(connection);
      await bluetoothService.sendEncryptedAESKey(connection, publicKey);
      final aesKey = generateAESKey(); // Store the AES key for decryption
      final encryptedMessage = await receiveMessage.execute(connection);
      final decodedMessage = base64Decode(encryptedMessage);
      final decryptedMessage = decryptAES(decodedMessage, aesKey);
      if (decryptedMessage == 'Ready') {
        return 'Ready';
      }
    } else {
      Get.snackbar('Error', 'No device selected');
    }
    return null;
  }
}