// lib/features/data_acquisition/domain/services/data_acquisition_service.dart
import 'dart:async';
import 'dart:typed_data';
import '../models/data_point.dart';
import '../repository/data_acquisition_repository.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../http/domain/services/http_service.dart';

class DataAcquisitionService implements DataAcquisitionRepository {
  final SocketService socketService;
  final HttpService httpService;

  // Constantes de escala y distancia (hardcodeadas por ahora)
  double scale = 1.0;
  double distance = 1.0;

  // FIFO para almacenar los datos recibidos
  final List<int> _fifo = [];
  final int _fifoSize = 25000; // Tamaño máximo de la FIFO

  // StreamController para enviar los DataPoints al graficador
  final StreamController<List<DataPoint>> _dataPointsController = StreamController<List<DataPoint>>.broadcast();

  DataAcquisitionService(this.socketService, this.httpService);

  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;

  @override
  Future<void> fetchData() async {
    // Suscribirse al stream de datos del socket
    final subscription = socketService.subscribe((data) {
      // Agregar los datos recibidos a la FIFO
      _fifo.addAll(data);

      // Si la FIFO supera el tamaño máximo, descartar los datos más viejos
      if (_fifo.length > _fifoSize) {
        _fifo.removeRange(0, _fifo.length - _fifoSize);
      }

      // Parsear los datos de la FIFO y enviar los DataPoints al graficador
      final parsedDataPoints = parseData(_fifo);
      _dataPointsController.add(parsedDataPoints);
    });

    // Mantener la adquisición de datos en ejecución
    await Future.delayed(Duration(days: 365));
    socketService.unsubscribe(subscription);
  }

  List<DataPoint> parseData(List<int> data) {
    final List<DataPoint> dataPoints = [];

    // Verificar que los datos recibidos tengan la longitud esperada
    if (data.length % 2 != 0) {
      print('Datos recibidos con longitud incorrecta: ${data.length}');
      return dataPoints;
    }

    // Parsear cada elemento de la lista de datos recibidos y convertirlos en DataPoint
    for (int i = 0; i < data.length; i += 2) {
      final uint16Value = ByteData.sublistView(Uint8List.fromList(data.sublist(i, i + 2))).getUint16(0, Endian.little);
      final uint12Value = uint16Value & 0xFFF; // Extraer los primeros 12 bits

      // Calcular los valores x e y aplicando la escala y la distancia
      final x = (i ~/ 2) * distance;
      final y = uint12Value * scale;
      dataPoints.add(DataPoint(x, y));
    }

    return dataPoints;
  }
}