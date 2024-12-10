import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/setup/domain/services/setup_service.dart';
import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:encrypt/encrypt.dart';



class MockSocketService extends Mock implements SocketService {}

final publicKey = File('test/public_key_test.pem').readAsStringSync();
final privateKey = File('test/private_key_test.pem').readAsStringSync();

void main() {
  late SetupService setupService;
  late MockSocketService mockSocketService;


  const baseUrl = 'http://192.168.4.1:81';

  setUp(() {

    mockSocketService = MockSocketService();

    setupService = SetupService(
      mockSocketService, // Puedes pasar un mock para el SocketService si es necesario
      HttpConfig(baseUrl),
    );
  });

  test('connectToWiFi debe configurar extIp y extPort correctamente', () async {
    // Mock del cliente HTTP
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/connect_wifi' && request.method == 'POST') {
        return http.Response(jsonEncode({'IP': '192.168.1.1', 'Port': 8080}), 200);
      }
      else{ 
        return http.Response('Not Found', 404);
      }
    });

    // Configurar el servicio con el cliente HTTP mockeado
    setupService = SetupService(
      mockSocketService,
      HttpConfig(baseUrl),
      client: client,
    );

    final credentials = WiFiCredentials('testSSID', 'testPassword');
    await setupService.connectToWiFi(credentials);

    expect(setupService.extIp, '192.168.1.1');
    expect(setupService.extPort, 8080);
  });

  test('scanForWiFiNetworks debe devolver una lista de SSIDs', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/scan_wifi' && request.method == 'GET') {
        return http.Response(
          jsonEncode([
            {'SSID': 'Network1'},
            {'SSID': 'Network2'},
          ]),
          200,
        );
      }
      else if( request.url.toString() == '$baseUrl/get_public_key' && request.method == 'GET'){
        return http.Response(jsonEncode({"PublicKey": publicKey}), 200);
      }
      else{ 
        return http.Response('Not Found', 404);
      }
      //return http.Response('Not Found', 404); // Catch-all for unmatched requests
    });

    setupService = SetupService(
      mockSocketService,
      HttpConfig(baseUrl),
      client: client,
    );

    final ssids = await setupService.scanForWiFiNetworks();
    expect(ssids, ['Network1', 'Network2']);
  });

  test('encriptWithPublicKey lanza excepción si la clave pública no está configurada', () {
    expect(() => setupService.encriptWithPublicKey('mensaje'), throwsException);
  });

  test('encriptWithPublicKey debe devolver un mensaje encriptado', () async {
    //print(publicKey);
    // Mock del cliente HTTP
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/get_public_key' && request.method == 'GET') {
        return http.Response(jsonEncode({"PublicKey": publicKey}), 200);
      }
      else if( request.url.toString() == '$baseUrl/scan_wifi' && request.method == 'GET'){
        return http.Response(
          jsonEncode([
            {'SSID': 'Network1'},
            {'SSID': 'Network2'},
          ]),
          200,
        );
      }
      else{ 
        return http.Response('Not Found', 404);
      }
    });

    setupService = SetupService(
      mockSocketService,
      HttpConfig(baseUrl),
      client: client,
    );

    // Obtener la clave pública
    await setupService.scanForWiFiNetworks();

    // Encriptar un mensaje
    final encryptedMessage = setupService.encriptWithPublicKey('091218. 3 a 1. RIP');

    // Desencriptar el mensaje usando la clave privada
    final privateKeyParser = RSAKeyParser().parse(privateKey) as RSAPrivateKey;
    final decrypter = Encrypter(RSA(privateKey: privateKeyParser, encoding: RSAEncoding.PKCS1));
    final decryptedMessage = decrypter.decrypt(Encrypted.fromBase64(encryptedMessage));
    expect(encryptedMessage, isNotNull);
    expect(decryptedMessage, '091218. 3 a 1. RIP');
  });
}
