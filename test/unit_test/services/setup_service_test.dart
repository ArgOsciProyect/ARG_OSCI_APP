import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:flutter/services.dart';
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

class MockSocketService extends Mock implements SocketService {}

final publicKey =
    File('test/unit_test/services/public_key_test.pem').readAsStringSync();
final privateKey =
    File('test/unit_test/services/private_key_test.pem').readAsStringSync();

void main() {
  late SetupService setupService;
  const baseUrl = 'http://192.168.4.1:81';
  final globalHttpConfig = HttpConfig(baseUrl);
  final globalSocketConnection = SocketConnection('192.168.4.1', 8080);

  setUp(() {
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
}
