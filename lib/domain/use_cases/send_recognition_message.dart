// lib/domain/use_cases/send_recognition_message.dart
import '../entities/bluetooth_connection.dart';
import '../../application/services/bluetooth_communication_service.dart';

class SendRecognitionMessage {
  final BluetoothCommunicationService bluetoothService;

  SendRecognitionMessage(this.bluetoothService);

  Future<void> execute(BluetoothConnection connection) async {
    try {
      await bluetoothService.sendMessage(connection, "Recognition");
    } catch (e) {
      throw Exception('Failed to send recognition message: $e');
    }
  }
}