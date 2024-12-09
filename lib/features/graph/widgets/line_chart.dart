// lib/features/graph/widgets/line_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/graph_provider.dart';

late Size _size;
// Mover el gráfico hacia arriba y a la derecha
final double _offsetY = 30;
final double _offsetX = 50;
final double _sqrOffsetBot = 30;
final double _sqrOffsetTop = 30;

class LineChart extends StatefulWidget {
  final List<DataPoint> dataPoints;

  const LineChart({required this.dataPoints, super.key});

  @override
  _LineChartState createState() => _LineChartState();
}

class _LineChartState extends State<LineChart> {
  double timeScale = 1.0;
  double valueScale = 1.0;
  double frequency = 1.0;
  double maxValue = 1.0;
  double maxX = 1.0;

  late GraphProvider graphProvider;

  @override
  void initState() {
    super.initState();
    graphProvider = Get.find<GraphProvider>();

    // Suscribirse a los streams de frecuencia y valor máximo
    graphProvider.dataAcquisitionService.frequencyStream.listen((newFrequency) {
      setState(() {
        frequency = newFrequency;
      });
    });

    graphProvider.dataAcquisitionService.maxValueStream.listen((newMaxValue) {
      setState(() {
        maxValue = newMaxValue;
      });
    });

    // Calcular el valor máximo de X
    if (widget.dataPoints.isNotEmpty) {
      maxX = widget.dataPoints.map((e) => e.x).reduce((a, b) => a > b ? a : b);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return SizedBox(
                height: constraints.maxHeight,
                width: constraints.maxWidth,
                child: widget.dataPoints.isEmpty
                    ? Center(child: Text('No data'))
                    : CustomPaint(
                        painter: LineChartPainter(widget.dataPoints, timeScale, valueScale, maxX, graphProvider.dataAcquisitionService.distance),
                      ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.arrow_left),
              onPressed: () {
                setState(() {
                  timeScale *= 0.9;
                  print(timeScale);
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_right),
              onPressed: () {
                setState(() {
                  timeScale *= 1.1;
                  print(timeScale);
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: () {
                setState(() {
                  valueScale *= 1.1;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  valueScale *= 0.9;
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.autorenew),
              onPressed: () {
                print("Previous time scale: $timeScale");
                print("Previous value scale: $valueScale");
                print(_size.height);
                print(_size.width);
                final List<double> auto = graphProvider.autoset(_size.height - _offsetY * 2, _size.width - _offsetX);
                valueScale = auto[1];
                timeScale = auto[0];
                print("New time scale: $timeScale");
                print("New value scale: $valueScale");
              },
            ),
          ],
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  static const double MAX_ADC_VALUE = 4094.0; // Valor máximo del ADC de 12 bits
  final List<DataPoint> dataPoints;
  final double timeScale;
  final double valueScale;
  final double maxX;
  final double distance;

  LineChartPainter(this.dataPoints, this.timeScale, this.valueScale, this.maxX, this.distance);

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    // Dibujar la grilla
    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    // Color de fondo para las referencias
    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;

    // Mover el gráfico hacia arriba y a la derecha
    final double offsetY = _offsetY;
    final double offsetX = _offsetX;
    final double sqrOffsetBot = _sqrOffsetBot;
    final double sqrOffsetTop = _sqrOffsetTop;

    // Dibujar el fondo para las referencias de x e y
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, offsetY, offsetX, size.height - offsetY), backgroundPaint);

    // Dibujar la grilla y las referencias de x e y
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Dibujar etiquetas en el eje X
    for (int i = 0; i <= 10; i++) {
      double xPos = offsetX + (size.width - offsetX) * i / 10;
      canvas.drawLine(Offset(xPos, offsetY), Offset(xPos, size.height - sqrOffsetBot), gridPaint);

      // Calcular el tiempo en microsegundos para las etiquetas
      double timeInSeconds = (xPos - offsetX) / timeScale;
      double timeInUs = timeInSeconds * 1e6;

      textPainter.text = TextSpan(
        text: timeInUs.toStringAsFixed(1) + " µs",
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xPos - textPainter.width / 2, size.height - sqrOffsetBot + 5));
    }

    // Dibujar etiquetas en el eje Y
    for (int i = 0; i <= 10; i++) {
      double yPos = offsetY + (size.height - offsetY - sqrOffsetBot) * i / 10;
      canvas.drawLine(Offset(offsetX, yPos), Offset(size.width, yPos), gridPaint);

      // Calcular el valor del ADC para las etiquetas
      double adcValue = MAX_ADC_VALUE - (MAX_ADC_VALUE * i / 10);

      textPainter.text = TextSpan(
        text: adcValue.toInt().toString(),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, yPos - textPainter.height / 2));
    }

    // Dibujar las líneas de datos
    for (int i = 0; i < dataPoints.length - 1; i++) {
      var p1 = Offset(dataPoints[i].x * timeScale + offsetX, size.height - dataPoints[i].y * valueScale - sqrOffsetBot);
      var p2 = Offset(dataPoints[i + 1].x * timeScale + offsetX, size.height - dataPoints[i + 1].y * valueScale - sqrOffsetBot);

      // Recortar las líneas en los bordes del recuadro
      if (p1.dy < offsetY) {
        p1 = Offset(p1.dx, offsetY);
      } else if (p1.dy > size.height - sqrOffsetBot) {
        p1 = Offset(p1.dx, size.height - sqrOffsetBot);
      }

      if (p2.dy < offsetY) {
        p2 = Offset(p2.dx, offsetY);
      } else if (p2.dy > size.height - sqrOffsetBot) {
        p2 = Offset(p2.dx, size.height - sqrOffsetBot);
      }

      if (p1.dx > size.width) {
        p1 = Offset(size.width, p1.dy);
      }

      if (p2.dx > size.width) {
        p2 = Offset(size.width, p2.dy);
      }

      canvas.drawLine(p1, p2, paint);
    }
    // Dibujar el recuadro negro alrededor de la grilla
    canvas.drawRect(Rect.fromLTWH(offsetX, offsetY, size.width - offsetX, size.height - sqrOffsetBot - offsetY), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}