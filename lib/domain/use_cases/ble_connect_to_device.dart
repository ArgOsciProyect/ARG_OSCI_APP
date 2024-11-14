// lib/domain/use_cases/ble_connect_to_device.dart
import '../entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';

class ConnectToDevice {
  final BluetoothCommunicationService bluetoothService;

  ConnectToDevice(this.bluetoothService);

  Future<void> execute(BluetoothConnection connection) async {
    try {
      await bluetoothService.connectToDevice(connection);
    } catch (e) {
      throw Exception('Failed to connect to device: $e');
    }
  }
}