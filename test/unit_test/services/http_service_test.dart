// In http_service_test.dart
import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';

// Mock function for navigation
void mockNavigateToSetupScreen(String errorMessage) {
  // Just log in test, don't try to navigate
  debugPrint('Mock navigation called with error: $errorMessage');
}

void main() {
  // Initialize Flutter binding for tests
  TestWidgetsFlutterBinding.ensureInitialized();

  late HttpService httpService;
  const baseUrl = 'https://api.example.com';

  setUp(() {
    final config = HttpConfig(baseUrl);
    // Pass the mock navigation function to HttpService constructor
    httpService =
        HttpService(config, navigateToSetupScreen: mockNavigateToSetupScreen);
  });

  test('GET exitoso retorna datos correctamente', () async {
    // Configurar un cliente HTTP falso
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/endpoint' &&
          request.method == 'GET') {
        return http.Response(jsonEncode({'key': 'value'}), 200);
      }
      return http.Response('Not Found', 404);
    });

    // Inyectar el cliente HTTP falso en la instancia de HttpService
    httpService = HttpService(HttpConfig(baseUrl, client: client),
        navigateToSetupScreen: mockNavigateToSetupScreen);

    final response = await httpService.get('/endpoint');
    expect(response, equals({'key': 'value'}));
  });

  test('GET lanza excepción en caso de error', () async {
    final client = MockClient((request) async {
      return http.Response('Not Found', 404);
    });

    httpService = HttpService(HttpConfig(baseUrl, client: client),
        navigateToSetupScreen: mockNavigateToSetupScreen);

    expect(
      () => httpService.get('/endpoint'),
      throwsA(isA<HttpException>()),
    );
  });

  test('POST exitoso retorna datos correctamente', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/endpoint' &&
          request.method == 'POST') {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response('Bad Request', 400);
    });

    httpService = HttpService(HttpConfig(baseUrl, client: client),
        navigateToSetupScreen: mockNavigateToSetupScreen);

    final response = await httpService.post('/endpoint', {'key': 'value'});
    expect(response, equals({'success': true}));
  });

  test('POST lanza excepción en caso de error', () async {
    final client = MockClient((request) async {
      return http.Response('Internal Server Error', 500);
    });

    httpService = HttpService(HttpConfig(baseUrl, client: client),
        navigateToSetupScreen: mockNavigateToSetupScreen);

    expect(
      () => httpService.post('/endpoint', {'key': 'value'}),
      throwsA(isA<HttpException>()),
    );
  });
}
