import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  late SocketService socketService;
  // ignore: unused_local_variable
  late MockSocket mockSocket;
  const testPort = 8080;

  setUp(() {
    socketService = SocketService(1024);
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
    final connection = SocketConnection('127.0.0.1', 9999);

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
        // ignore: unnecessary_string_escapes
        expect(message, equals(utf8.encode('Hello World\0').toString()));
      });
    });

    final connection = SocketConnection('127.0.0.1', 8080);
    await socketService.connect(connection);
    socketService.listen();
    await socketService.sendMessage('Hello World');

    await server.close();
  });

  test('Cierra el socket y el stream correctamente', () async {
    await socketService.close();

    expect(socketService.socket, isNull);
    expect(socketService.controller.isClosed, isTrue);
  });

  test('Recibe mensajes correctamente', () async {
    final server = await ServerSocket.bind('127.0.0.1', testPort, shared: true);
    final completer = Completer<String>();

    // Create a 1024-byte message
    final message = 'Message from server'.padRight(1024, ' ');

    // Set up server first
    server.listen((client) async {
      await Future.delayed(Duration(milliseconds: 100));
      // Send full packet
      client.add(utf8.encode(message));
      await client.flush();
    });

    final connection = SocketConnection('127.0.0.1', testPort);
    await socketService.connect(connection);
    socketService.listen();

    socketService.subscribe((data) {
      completer.complete(utf8.decode(data).trim()); // Trim padding
    });

    final receivedMessage = await completer.future.timeout(
      Duration(seconds: 5), // Increased timeout
      onTimeout: () => throw TimeoutException('No message received'),
    );

    expect(receivedMessage, equals('Message from server'));
    await server.close();
  });

  test('Suscribe y desuscribe correctamente', () async {
    final server =
        await ServerSocket.bind('127.0.0.1', testPort + 1, shared: true);
    final connection = SocketConnection('127.0.0.1', testPort + 1);
    final completer = Completer<void>();

    var messageReceived = false;
    final message = 'Message from server'.padRight(1024, ' ');

    await socketService.connect(connection);
    socketService.listen();

    final subscription = socketService.subscribe((data) {
      messageReceived = true;
      expect(utf8.decode(data).trim(), equals('Message from server'));
      completer.complete();
    });

    await Future.delayed(Duration(milliseconds: 100));

    server.listen((client) {
      client.add(utf8.encode(message));
      client.flush();
    });

    await completer.future.timeout(
      Duration(seconds: 5),
      onTimeout: () => throw TimeoutException('No message received'),
    );

    expect(messageReceived, isTrue);

    socketService.unsubscribe(subscription);
    await server.close();
  });
}
