// lib/domain/use_cases/send_message.dart
import '../entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';

class SendMessage {
  final BluetoothCommunicationService bluetoothService;

  SendMessage(this.bluetoothService);

  Future<void> execute(BluetoothConnection connection, String message) async {
    try {
      await bluetoothService.sendMessage(connection, message);
    } catch (e) {
      throw Exception('Failed to send recognition message: $e');
    }
  }
}