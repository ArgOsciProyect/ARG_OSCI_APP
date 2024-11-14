// lib/application/services/bluetooth_communication_service.dart
import 'package:universal_ble/universal_ble.dart';
import 'package:get/get.dart';
import '../../domain/entities/bluetooth_connection.dart';
import 'dart:convert';

class BluetoothCommunicationService extends GetxService {
  var devices = <BleDevice>[].obs;
  var isScanning = false.obs;

  BluetoothCommunicationService() {
    UniversalBle.onScanResult = (BleDevice device) {
      if (!devices.any((d) => d.deviceId == device.deviceId)) {
        devices.add(device);
      }
    };
  }

  Future<List<BluetoothConnection>> startScan() async {
    devices.clear();
    isScanning.value = true;
    AvailabilityState state = await UniversalBle.getBluetoothAvailabilityState();
    if (state == AvailabilityState.poweredOn) {
      await UniversalBle.startScan();
    }
    await Future.delayed(Duration(seconds: 4)); // Esperar un tiempo para obtener resultados
    isScanning.value = false;
    return devices.map((d) => BluetoothConnection(deviceId: d.deviceId, name: d.name)).toList();
  }

  void stopScan() {
    UniversalBle.stopScan();
    isScanning.value = false;
  }

  Future<void> connectToDevice(BluetoothConnection connection) async {
    BleDevice? device = devices.firstWhereOrNull((d) => d.deviceId == connection.deviceId);
    if (device == null) {
      throw Exception('Device not found');
    }
    await UniversalBle.connect(device.deviceId);
  }

  Future<void> sendMessage(BluetoothConnection connection, String message) async {
    BleDevice? device = devices.firstWhereOrNull((d) => d.deviceId == connection.deviceId);
    if (device == null) {
      throw Exception('Device not found');
    }
    try {
      // Ensure the device is connected
      BleConnectionState connectionState = await UniversalBle.getConnectionState(device.deviceId);
      if (connectionState != BleConnectionState.connected) {
        await UniversalBle.connect(device.deviceId);
      }
      // Discover services
      List<BleService> services = await UniversalBle.discoverServices(device.deviceId);
      for (BleService service in services) {
        // Iterate through the characteristics of the service
        for (BleCharacteristic characteristic in service.characteristics) {
          // Check if the characteristic supports write property
          if (characteristic.properties.contains(CharacteristicProperty.write)) {
            // Write the message to the characteristic
            await UniversalBle.writeValue(device.deviceId, service.uuid, characteristic.uuid, utf8.encode(message), BleOutputProperty.withResponse);
          }
        }
      }
      // Disconnect from the device
      await UniversalBle.disconnect(device.deviceId);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }
}