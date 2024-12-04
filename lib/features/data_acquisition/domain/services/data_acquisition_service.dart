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
  final int _fifoSize = 8192 * 4; // Tamaño máximo de la FIFO

  // StreamController para enviar los DataPoints al graficador
  final StreamController<List<DataPoint>> _dataPointsController = StreamController<List<DataPoint>>.broadcast();
  final StreamController<double> _frequencyController = StreamController<double>.broadcast();
  final StreamController<double> _maxValueController = StreamController<double>.broadcast();

  StreamSubscription<List<int>>? _subscription;

  DataAcquisitionService(this.socketService, this.httpService);

  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;
  Stream<double> get frequencyStream => _frequencyController.stream;
  Stream<double> get maxValueStream => _maxValueController.stream;

  @override
  Future<void> fetchData() async {
    // Suscribirse al stream de datos del socket
    _subscription = socketService.subscribe((data) {
      // Agregar los datos recibidos a la FIFO
      _fifo.addAll(data);

      // Si la FIFO supera el tamaño máximo, descartar los datos más viejos
      if (_fifo.length > _fifoSize) {
        _fifo.removeRange(0, _fifo.length - _fifoSize);
      }

      // Parsear los datos de la FIFO y enviar los DataPoints al graficador
      final parsedDataPoints = parseData(_fifo);
      _dataPointsController.add(parsedDataPoints);

      // Calcular la frecuencia y el valor máximo cada 10,000 muestras
      if (_fifo.length >= 10000) {
        final frequency = calculateFrequencyWithMax(parsedDataPoints);
        final maxValue = parsedDataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        _frequencyController.add(frequency);
        _maxValueController.add(maxValue);
      }
    });
  }

  Future<void> stopData() async {
    // Desuscribirse del stream de datos
    await _subscription?.cancel();
    _subscription = null;
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

  double calculateFrequencyWithMax(List<DataPoint> dataPoints) {
    // Implementar la lógica para calcular la frecuencia de la señal
    // Aquí puedes usar FFT o cualquier otro método adecuado
    // Por simplicidad, devolvemos un valor fijo
    return 50.0; // Ejemplo de frecuencia fija
  }
}