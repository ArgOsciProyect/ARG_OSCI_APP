// lib/application/services/bluetooth_communication_service.dart
import 'package:universal_ble/universal_ble.dart';
import 'package:get/get.dart';
import '../../domain/entities/bluetooth_connection.dart';
import 'dart:convert';
import 'dart:typed_data';
import 'package:pointycastle/export.dart' as crypto;

// Método para generar una clave AES
List<int> generateAESKey() {
  final key = crypto.KeyParameter(Uint8List(16));
  return key.key;
}

// Método para cifrar una clave AES usando una clave pública RSA
List<int> encryptAESKeyWithRSA(List<int> aesKey, String publicKey) {
  // Separar la clave pública en módulo y exponente
  final parts = publicKey.split('|');
  final modulus = BigInt.parse(parts[0]);
  final exponent = BigInt.parse(parts[1]);

  final rsaPublicKey = crypto.RSAPublicKey(modulus, exponent);
  final encryptor = crypto.OAEPEncoding(crypto.RSAEngine())
    ..init(true, crypto.PublicKeyParameter<crypto.RSAPublicKey>(rsaPublicKey));
  return encryptor.process(Uint8List.fromList(aesKey));
}

// Método para descifrar un mensaje AES
String decryptAES(List<int> encryptedMessage, List<int> aesKey) {
  final key = crypto.KeyParameter(Uint8List.fromList(aesKey));
  final cipher = crypto.PaddedBlockCipher('AES/ECB/PKCS7Padding')
    ..init(false, crypto.ParametersWithIV(key, Uint8List(0)));
  return utf8.decode(cipher.process(Uint8List.fromList(encryptedMessage)));
}

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
            await UniversalBle.writeValue(device.deviceId, service.uuid, characteristic.uuid, Uint8List.fromList(utf8.encode(message)), BleOutputProperty.withResponse);
          }
        }
      }
      // Disconnect from the device
      await UniversalBle.disconnect(device.deviceId);
    } catch (e) {
      throw Exception('Failed to send message: $e');
    }
  }

  Future<String> receivePublicKey(BluetoothConnection connection) async {
    String publicKey = await receiveMessage(connection);
    return publicKey;
  }

  Future<void> sendEncryptedAESKey(BluetoothConnection connection, String publicKey) async {
    List<int> aesKey = generateAESKey();
    List<int> encryptedAESKey = encryptAESKeyWithRSA(aesKey, publicKey);
    await sendMessage(connection, base64Encode(encryptedAESKey));
  }

  Future<String> receiveAndDecryptMessage(BluetoothConnection connection, List<int> aesKey) async {
    final encryptedMessage = await receiveMessage(connection);
    final decodedMessage = base64Decode(encryptedMessage);
    return decryptAES(decodedMessage, aesKey);
  }

  Future<String> receiveMessage(BluetoothConnection connection) async{
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
          // Check if the characteristic supports read property
          if (characteristic.properties.contains(CharacteristicProperty.read)) {
            // Read the value from the characteristic
            List<int> value = await UniversalBle.readValue(device.deviceId, service.uuid, characteristic.uuid);
            return utf8.decode(value);
          }
        }
      }
      // Disconnect from the device
      await UniversalBle.disconnect(device.deviceId);
      throw Exception('No characteristic found to read message');
    } catch (e) {
      throw Exception('Failed to receive message: $e');
    }
  }
}