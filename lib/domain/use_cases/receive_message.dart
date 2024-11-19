import 'package:arg_osci_app/application/services/bluetooth_communication_service.dart';
import '../entities/bluetooth_connection.dart';


class ReceiveMessage {
  final BluetoothCommunicationService bluetoothService;

  ReceiveMessage(this.bluetoothService);

  Future<String> execute(BluetoothConnection connection) async {
    try {
      final message = await bluetoothService.receiveMessage(connection);
      return message;
    } catch (e) {
      throw Exception('Failed to receive message: $e');
    }
  }

}