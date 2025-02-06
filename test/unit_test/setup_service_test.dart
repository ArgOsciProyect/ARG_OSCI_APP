import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/setup/domain/services/setup_service.dart';
import 'package:arg_osci_app/features/setup/domain/models/wifi_credentials.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:pointycastle/asymmetric/api.dart';
import 'package:encrypt/encrypt.dart';
import 'package:pointycastle/src/impl/base_asymmetric_block_cipher.dart';
import 'package:pointycastle/asn1.dart';
import 'package:pointycastle/asn1/primitives/asn1_sequence.dart';

class MockSocketService extends Mock implements SocketService {}

final publicKey = File('test/unit_test/public_key_test.pem').readAsStringSync();
final privateKey =
    File('test/unit_test/private_key_test.pem').readAsStringSync();

void main() {
  late SetupService setupService;
  late MockSocketService mockSocketService;
  const baseUrl = 'http://192.168.4.1:81';
  final globalHttpConfig = HttpConfig(baseUrl);
  final globalSocketConnection = SocketConnection('192.168.4.1', 8080);

  setUp(() {
    mockSocketService = MockSocketService();
    setupService = SetupService(globalSocketConnection, globalHttpConfig);
  });

  group('WiFi Connection Tests', () {
    test('connectToWiFi should handle success response correctly', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '$baseUrl/connect_wifi' &&
            request.method == 'POST') {
          return http.Response(
              jsonEncode(
                  {'Success': 'true', 'IP': '192.168.1.1', 'Port': 8080}),
              200);
        }
        return http.Response('Not Found', 404);
      });

      setupService = SetupService(
          globalSocketConnection, HttpConfig(baseUrl, client: client));

      final credentials = WiFiCredentials('testSSID', 'testPassword');
      final result = await setupService.connectToWiFi(credentials);

      expect(result, isTrue);
      expect(setupService.extIp, '192.168.1.1');
      expect(setupService.extPort, 8080);
    });

    test('connectToWiFi should handle failure response correctly', () async {
      final client = MockClient((request) async {
        if (request.url.toString() == '$baseUrl/connect_wifi' &&
            request.method == 'POST') {
          return http.Response(
              jsonEncode({'Success': 'false', 'Error': 'Invalid password'}),
              200);
        }
        return http.Response('Not Found', 404);
      });

      setupService = SetupService(
          globalSocketConnection, HttpConfig(baseUrl, client: client));

      final credentials = WiFiCredentials('testSSID', 'testPassword');
      final result = await setupService.connectToWiFi(credentials);

      expect(result, isFalse);
    });

    test('connectToWiFi should handle timeout', () async {
      final client = MockClient((request) async {
        await Future.delayed(const Duration(seconds: 16));
        return http.Response('Timeout', 408);
      });

      setupService = SetupService(
          globalSocketConnection, HttpConfig(baseUrl, client: client));

      final credentials = WiFiCredentials('testSSID', 'testPassword');

      expect(() => setupService.connectToWiFi(credentials),
          throwsA(isA<SetupException>()));
    });
  });

  group('Network Verification Tests', () {
    MockClient createMockClient({
      bool successfulConnection = true,
      bool shouldTimeout = false,
      bool connectionRefused = false,
    }) {
      return MockClient((request) async {
        // Public key + WiFi scan
        if (request.url.path == '/get_public_key') {
          return http.Response(jsonEncode({'PublicKey': publicKey}), 200);
        }
        if (request.url.path == '/scan_wifi') {
          return http.Response(
              jsonEncode([
                {'SSID': 'Test Network'}
              ]),
              200);
        }

        // Test endpoint scenarios
        if (request.url.path == '/test') {
          if (shouldTimeout) {
            await Future.delayed(const Duration(seconds: 3));
            throw TimeoutException('Connection timed out');
          }
          if (connectionRefused) {
            throw const SocketException('Connection refused');
          }
          if (successfulConnection) {
            final body = jsonDecode(request.body);
            // Decrypt with private key to mimic device
            final keyParser = RSAKeyParser();
            final privKey = keyParser.parse(privateKey) as RSAPrivateKey;
            final encrypter = Encrypter(
              RSA(privateKey: privKey, encoding: RSAEncoding.PKCS1),
            );
            final decryptedText = encrypter.decrypt(
              Encrypted.from64(body['word']),
            );
            // Return the decrypted text
            return http.Response(jsonEncode({'decrypted': decryptedText}), 200);
          }
        }

        return http.Response('Not Found', 404);
      });
    }

    test('handleNetworkChangeAndConnect should verify connection successfully',
        () async {
      final client = createMockClient(successfulConnection: true);

      setupService = SetupService(
        globalSocketConnection,
        HttpConfig('http://192.168.1.1:80', client: client),
      );
      setupService.extIp = '192.168.1.1';
      setupService.extPort = 80;

      // Use the same client for scanning (fetching the public key) and network verification
      await setupService.scanForWiFiNetworks();
      await setupService.handleNetworkChangeAndConnect(
        'testSSID',
        'testPass',
        client: client,
      );
    });

    test('handleNetworkChangeAndConnect should handle timeouts', () async {
      final client = createMockClient(shouldTimeout: true);

      setupService = SetupService(
        globalSocketConnection,
        HttpConfig('http://192.168.1.1:80', client: client),
      );
      setupService.extIp = '192.168.1.1';
      setupService.extPort = 80;

      // Use the same client
      await setupService.scanForWiFiNetworks();
      expect(
        () => setupService.handleNetworkChangeAndConnect('testSSID', 'testPass',
            client: client),
        throwsA(isA<TimeoutException>()),
      );
    });

    test('handleNetworkChangeAndConnect should handle connection errors',
        () async {
      final client = createMockClient(connectionRefused: true);

      setupService = SetupService(
        globalSocketConnection,
        HttpConfig('http://192.168.1.1:80', client: client),
      );
      setupService.extIp = '192.168.1.1';
      setupService.extPort = 80;

      // Use the same client
      await setupService.scanForWiFiNetworks();
      expect(
        () => setupService.handleNetworkChangeAndConnect('testSSID', 'testPass',
            client: client),
        throwsA(isA<Exception>()),
      );
    });
  });
}
