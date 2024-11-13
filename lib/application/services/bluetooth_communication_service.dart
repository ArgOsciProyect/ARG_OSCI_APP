// lib/application/services/bluetooth_communication_service.dart
import 'package:flutter_blue_plus/flutter_blue_plus.dart';
import 'package:get/get.dart';
import '../../domain/entities/bluetooth_connection.dart';

class BluetoothCommunicationService extends GetxService {
  var devices = <BluetoothDevice>[].obs;
  var isScanning = false.obs;

  Future<void> startScan() async {
    devices.clear();
    isScanning.value = true;
    FlutterBluePlus.startScan(timeout: Duration(seconds: 4));
    FlutterBluePlus.scanResults.listen((results) {
      for (ScanResult r in results) {
        if (!devices.contains(r.device)) {
          devices.add(r.device);
        }
      }
    }).onDone(() {
      isScanning.value = false;
    });
  }

  void stopScan() {
    FlutterBluePlus.stopScan();
    isScanning.value = false;
  }

  Future<void> sendMessage(BluetoothConnection connection, String message) async {
    BluetoothDevice? device;
    for (var d in devices) {
      if (d.remoteId.str == connection.deviceId) {
        device = d;
        break;
      }
    }
    if (device != null) {
      try {
        // Connect to the device
        await device.connect();
        // Discover services
        List<BluetoothService> services = await device.discoverServices();
        for (BluetoothService service in services) {
          // Iterate through the characteristics of the service
          for (BluetoothCharacteristic characteristic in service.characteristics) {
            // Check if the characteristic supports write property
            if (characteristic.properties.write) {
              // Write the message to the characteristic
              await characteristic.write(message.codeUnits);
            } else {
              throw Exception('The WRITE property is not supported by this BLE characteristic: ${characteristic.uuid}');
            }
          }
        }
        // Disconnect from the device
        await device.disconnect();
      } catch (e) {
        throw Exception('Failed to send message: $e');
      }
    } else {
      throw Exception('Device not found');
    }
  }
}