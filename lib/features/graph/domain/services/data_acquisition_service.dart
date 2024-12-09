// lib/features/data_acquisition/domain/services/data_acquisition_service.dart
import 'dart:async';
import 'dart:typed_data';
import '../models/data_point.dart';
import '../repository/data_acquisition_repository.dart';
import '../../../socket/domain/services/socket_service.dart';
import '../../../http/domain/services/http_service.dart';

enum TriggerMode { automatic, manual }
enum TriggerEdge { positive, negative }

class DataAcquisitionService implements DataAcquisitionRepository {
  final SocketService socketService;
  final HttpService httpService;

  // Constantes de escala y distancia (hardcodeadas por ahora)
  double scale = 1.0;
  double distance = 1 / 2000000; // Representa la distancia en segundos entre cada dato
  double _maxValue = 4094;
  double _frequency = 1000;
  // Variables de trigger
  double triggerLevel = 0.0;
  TriggerMode triggerMode = TriggerMode.automatic;
  TriggerEdge triggerEdge = TriggerEdge.positive;

  // FIFO para almacenar los datos recibidos
  final List<int> _fifo = [];
  final int _fifoSize = 8192 * 8; // Tamaño máximo de la FIFO

  // StreamController para enviar los DataPoints al graficador
  final StreamController<List<DataPoint>> _dataPointsController = StreamController<List<DataPoint>>.broadcast();
  final StreamController<double> _frequencyController = StreamController<double>.broadcast();
  final StreamController<double> _maxValueController = StreamController<double>.broadcast();

  StreamSubscription<List<int>>? _subscription;

  DataAcquisitionService(this.socketService, this.httpService);

  @override
  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;
  @override
  Stream<double> get frequencyStream => _frequencyController.stream;
  @override
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

      // Aplicar el trigger y obtener los datos a partir del punto de trigger
      final triggeredDataPoints = applyTrigger(parsedDataPoints);
      if (triggeredDataPoints.isNotEmpty) {
        _dataPointsController.add(triggeredDataPoints);
      }

      // Calcular la frecuencia y el valor máximo solo si triggeredDataPoints no está vacío
      if (triggeredDataPoints.isNotEmpty && _fifo.length >= 10000) {
        _frequency = calculateFrequencyWithMax(triggeredDataPoints);
        _maxValue = triggeredDataPoints.map((e) => e.y).reduce((a, b) => a > b ? a : b);
        _frequencyController.add(_frequency);
        _maxValueController.add(_maxValue);
      }
    });
  }

  @override
  Future<void> stopData() async {
    // Desuscribirse del stream de datos
    await _subscription?.cancel();
    _subscription = null;
  }

  @override
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

  @override
  List<DataPoint> applyTrigger(List<DataPoint> dataPoints) {
    double triggerValue = triggerLevel;
    if (triggerMode == TriggerMode.automatic) {
      triggerValue = dataPoints.map((e) => e.y).reduce((a, b) => a + b) / dataPoints.length;
    }

    for (int i = 1; i < dataPoints.length; i++) {
      bool triggerCondition = triggerEdge == TriggerEdge.positive
          ? dataPoints[i - 1].y < triggerValue && dataPoints[i].y >= triggerValue
          : dataPoints[i - 1].y > triggerValue && dataPoints[i].y <= triggerValue;

      if (triggerCondition) {
        // Desplazar todos los puntos a la izquierda para que el trigger sea el valor en el punto 0 del eje x
        List<DataPoint> triggeredDataPoints = dataPoints.sublist(i);
        double triggerX = triggeredDataPoints[0].x;
        for (var point in triggeredDataPoints) {
          point.x -= triggerX;
        }
        return triggeredDataPoints;
      }
    }
    return [];
  }

  @override
  double calculateFrequencyWithMax(List<DataPoint> dataPoints) {
    // Implementar la lógica para calcular la frecuencia de la señal
    // Aquí puedes usar FFT o cualquier otro método adecuado
    // Por simplicidad, devolvemos un valor fijo
    return 1000.0; // Ejemplo de frecuencia fija
  }

  // lib/features/data_acquisition/domain/services/data_acquisition_service.dart
  
  @override
  List<double> autoset(List<DataPoint> dataPoints, double chartHeight, double chartWidth) {
    // Configurar el trigger en automático
    triggerMode = TriggerMode.automatic;
  
    // Usar la frecuencia actual para calcular el período
    double period = 1 / _frequency; // Período en segundos
    double totalTime = 3 * period; // Tiempo total para 3 períodos
  
    // Calcular timeScaleSend para que 3 períodos se ajusten al ancho del gráfico
    double timeScaleSend = ((chartWidth) / totalTime); // píxeles por segundo
  
    // Calcular valueScaleSend para que el valor máximo se ajuste al alto del gráfico
    double valueScaleSend = chartHeight / _maxValue; // píxeles por unidad de valor
  
    return [timeScaleSend, valueScaleSend];
  }
}