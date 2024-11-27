// lib/features/socket/domain/services/socket_service_test.dart
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/socket/domain/services/socket_service.dart';

class MockSocket extends Mock implements Socket {}

void main() {
  late SocketService socketService;
  late MockSocket mockSocket;

  setUp(() {
    socketService = SocketService();
    mockSocket = MockSocket();
  });

  test('connect should establish a connection', () async {
    final connection = SocketConnection('127.0.0.1', 8080);
    when(Socket.connect(connection.ip, connection.port, timeout: anyNamed('timeout')))
        .thenAnswer((_) async => mockSocket);

    await socketService.connect(connection);

    verify(Socket.connect(connection.ip, connection.port, timeout: anyNamed('timeout'))).called(1);
  });

  test('sendMessage should send a message', () async {
    final connection = SocketConnection('127.0.0.1', 8080);
    when(Socket.connect(connection.ip, connection.port, timeout: anyNamed('timeout')))
        .thenAnswer((_) async => mockSocket);
    await socketService.connect(connection);
    socketService.socket = mockSocket;

    await socketService.sendMessage('Hello');

    verify(mockSocket.write(utf8.encode('Hello\0'))).called(1);
    verify(mockSocket.flush()).called(1);
  });

  test('receiveMessage should receive a message', () async {
    final connection = SocketConnection('127.0.0.1', 8080);
    when(Socket.connect(connection.ip, connection.port, timeout: anyNamed('timeout')))
        .thenAnswer((_) async => mockSocket);
    await socketService.connect(connection);
    socketService.socket = mockSocket;

    when(mockSocket.listen(any, onError: anyNamed('onError'), onDone: anyNamed('onDone')))
        .thenAnswer((invocation) {
      final onData = invocation.positionalArguments[0] as void Function(Uint8List);
      onData(Uint8List.fromList(utf8.encode('Hello')));
      return StreamSubscriptionMock();
    });

    final message = await socketService.receiveMessage();

    expect(message, 'Hello');
  });

  test('close should close the socket and controller', () async {
    final connection = SocketConnection('127.0.0.1', 8080);
    when(Socket.connect(connection.ip, connection.port, timeout: anyNamed('timeout')))
        .thenAnswer((_) async => mockSocket);
    await socketService.connect(connection);
    socketService.socket = mockSocket;

    await socketService.close();

    verify(mockSocket.close()).called(1);
    expect(socketService.controller.isClosed, true);
  });
}

class StreamSubscriptionMock extends Mock implements StreamSubscription<Uint8List> {}