import 'dart:async';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter TCP Client',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: Scaffold(
        appBar: AppBar(title: Text('Oscilloscope')),
        body: OscilloscopeWidget(),
      ),
    );
  }
}

class OscilloscopeWidget extends StatefulWidget {
  @override
  _OscilloscopeWidgetState createState() => _OscilloscopeWidgetState();
}

class _OscilloscopeWidgetState extends State<OscilloscopeWidget> {
  static const int initialN = 30000; // Valor inicial de N
  int _N = initialN; // Variable para almacenar el valor de N
  List<int> _samples = [];
  Isolate? _dataIsolate;
  ReceivePort _receivePort = ReceivePort();
  int _dataReceived = 0;

  @override
  void dispose() {
    _dataIsolate?.kill(priority: Isolate.immediate);
    _receivePort.close();
    super.dispose();
  }

  Future<void> _startDataIsolate() async {
    _dataIsolate = await Isolate.spawn(
      _dataReceiver,
      _receivePort.sendPort,
    );

    // Escucha los datos del Isolate y actualiza la interfaz
    _receivePort.listen((data) {
      if (data is List<int>) {
        setState(() {
          _samples.addAll(data);
          if (_samples.length > _N) {
            _samples = _samples.sublist(_samples.length - _N);
          }
        });
      } else if (data is int) {
        _dataReceived = data;
        print('Average reception speed: ${(_dataReceived / (1024 * 1024) / 5).toStringAsFixed(2)} MB/s');
        _dataReceived = 0;
      }
    });
  }

  static Future<void> _dataReceiver(SendPort sendPort) async {
    final ReceivePort receivePort = ReceivePort();
    sendPort.send(receivePort.sendPort);

    try {
      Socket socket = await Socket.connect('192.168.4.1', 8080);
      print('Connected to server');

      int dataReceived = 0;
      Timer.periodic(Duration(seconds: 5), (timer) {
        sendPort.send(dataReceived);
        dataReceived = 0;
      });

      socket.listen((Uint8List data) {
        dataReceived += data.length;
        List<int> samples = [];
        for (int i = 0; i < data.length; i += 2) {
          int rawValue = (data[i] & 0xFF) | ((data[i + 1] & 0xFF) << 8);
          int adcData = rawValue & 0x0FFF; // Extraer los 12 bits de datos
          samples.add(adcData);
        }
        sendPort.send(samples);
      });
    } catch (e) {
      print("Connection failed: $e");
    }
  }

  void _incrementN() {
    setState(() {
      _N += 1000;
    });
  }

  void _decrementN() {
    setState(() {
      if (_N > 1000) {
        _N -= 1000;
      }
    });
  }

  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(8.0),
      child: Column(
        children: [
          Expanded(child: _buildChart()),
          SizedBox(height: 0),
          Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_downward),
                onPressed: _decrementN,
              ),
              IconButton(
                icon: Icon(Icons.arrow_upward),
                onPressed: _incrementN,
              ),
            ],
          ),
          SizedBox(height: 0),
          ElevatedButton(
            onPressed: () {
              _dataIsolate?.kill(priority: Isolate.immediate);
            },
            child: Text('Disconnect'),
          ),
          SizedBox(height: 0),
          ElevatedButton(
            onPressed: _startDataIsolate,
            child: Text('Retry Connection'),
          ),
        ],
      ),
    );
  }

  Widget _buildChart() {
    return LineChart(
      LineChartData(
        lineBarsData: [
          LineChartBarData(
            spots: _samples.asMap().entries.map((e) {
              return FlSpot(e.key.toDouble(), e.value.toDouble());
            }).toList(),
            isCurved: true,
            color: Colors.blue,
            dotData: FlDotData(show: false),
          ),
        ],
        minY: 0, // Valor mínimo del eje Y
        maxY: 520, // Valor máximo del eje Y
        minX: 0, // Valor mínimo del eje X
        maxX: _N.toDouble(), // Valor máximo del eje X
        titlesData: FlTitlesData(
          leftTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 25, // Ajusta el intervalo según sea necesario
              reservedSize: 50, // Aumenta el espacio reservado para los títulos
              getTitlesWidget: (value, meta) {
                return Text(value.toInt().toString());
              },
            ),
          ),
          bottomTitles: AxisTitles(
            sideTitles: SideTitles(
              showTitles: true,
              interval: 2500, // Ajusta el intervalo según sea necesario
              reservedSize: 20, // Aumenta el espacio reservado para los títulos
              getTitlesWidget: (value, meta) {
                return Text(value.toString());
              },
            ),
          ),
          rightTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: true, reservedSize: 50,
              getTitlesWidget: (value, meta) {
                return Text("");
              },
            ),
          ),
          topTitles: AxisTitles(
            sideTitles: SideTitles(showTitles: false),
          ),
        ),
        borderData: FlBorderData(show: true),
      ),
    );
  }
}