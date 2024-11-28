import 'dart:convert';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import '../domain/services/http_service.dart';
import '../domain/models/http_config.dart';

void main() {
  late HttpService httpService;
  const baseUrl = 'https://api.example.com';

  setUp(() {
    final config = HttpConfig(baseUrl);
    httpService = HttpService(config);
  });

  test('GET exitoso retorna datos correctamente', () async {
    // Configurar un cliente HTTP falso
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/endpoint' && request.method == 'GET') {
        return http.Response(jsonEncode({'key': 'value'}), 200);
      }
      return http.Response('Not Found', 404);
    });

    // Inyectar el cliente HTTP falso en la instancia de HttpService
    httpService = HttpService(HttpConfig(baseUrl), client: client);

    final response = await httpService.get('/endpoint');
    expect(response, equals({'key': 'value'}));
  });

  test('GET lanza excepción en caso de error', () async {
    final client = MockClient((request) async {
      return http.Response('Not Found', 404);
    });

    httpService = HttpService(HttpConfig(baseUrl), client: client);

    expect(
      () async => await httpService.get('/endpoint'),
      throwsA(isA<Exception>()),
    );
  });

  test('POST exitoso retorna datos correctamente', () async {
    final client = MockClient((request) async {
      if (request.url.toString() == '$baseUrl/endpoint' && request.method == 'POST') {
        return http.Response(jsonEncode({'success': true}), 200);
      }
      return http.Response('Bad Request', 400);
    });

    httpService = HttpService(HttpConfig(baseUrl), client: client);

    final response = await httpService.post('/endpoint', {'key': 'value'});
    expect(response, equals({'success': true}));
  });

  test('POST lanza excepción en caso de error', () async {
    final client = MockClient((request) async {
      return http.Response('Internal Server Error', 500);
    });

    httpService = HttpService(HttpConfig(baseUrl), client: client);

    expect(
      () async => await httpService.post('/endpoint', {'key': 'value'}),
      throwsA(isA<Exception>()),
    );
  });
}