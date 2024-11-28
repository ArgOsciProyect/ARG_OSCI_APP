import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import '../domain/services/socket_service.dart';
import '../domain/models/socket_connection.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  late SocketService socketService;
  // ignore: unused_local_variable
  late MockSocket mockSocket;

  setUp(() {
    socketService = SocketService();
    mockSocket = MockSocket();
  });

  test('Se conecta exitosamente al servidor', () async {
    final server = await ServerSocket.bind('127.0.0.1', 8080);
    final connection = SocketConnection('127.0.0.1', 8080);
  
    await socketService.connect(connection);
  
    try {
      socketService.listen();
      expect(true, isTrue); // Si no se lanza ninguna excepción, el test pasa
    } catch (e) {
      expect(e, isNull); // Si se lanza una excepción, el test falla
    }
  
    expect(socketService.socket, isNotNull);
  
    await server.close();
  });

  test('Falla al conectarse con un puerto cerrado', () async {
    final connection = SocketConnection('127.0.0.1',9999);

    expect(
      () async => await socketService.connect(connection),
      throwsA(isA<SocketException>()),
    );
  });

  test('Envía un mensaje correctamente', () async {
    final server = await ServerSocket.bind('127.0.0.1', 8080);
    server.listen((client) {
      client.listen((data) {
        final message = utf8.decode(data);
        expect(message, equals(utf8.encode('Hello World\0').toString()));
      });
    });
  
    final connection = SocketConnection('127.0.0.1', 8080);
    await socketService.connect(connection);
    socketService.listen();
    await socketService.sendMessage('Hello World');
  
    await server.close();
  });

  test('Recibe mensajes correctamente', () async {
    final server = await ServerSocket.bind('127.0.0.1', 8080);
    server.listen((client) {
      client.write('Message from server');
    });

    final connection = SocketConnection('127.0.0.1', 8080);
    await socketService.connect(connection);
    socketService.listen();
    final message = await socketService.receiveMessage();

    expect(message, equals('Message from server'));

    await server.close();
  });

  test('Cierra el socket y el stream correctamente', () async {
    await socketService.close();

    expect(socketService.socket, isNull);
    expect(socketService.controller.isClosed, isTrue);
  });
}