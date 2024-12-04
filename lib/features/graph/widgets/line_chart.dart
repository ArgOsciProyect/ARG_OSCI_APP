// lib/features/graph/widgets/line_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../data_acquisition/domain/models/data_point.dart';
import '../../data_acquisition/domain/services/data_acquisition_service.dart';

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

  late DataAcquisitionService dataAcquisitionService;

  @override
  void initState() {
    super.initState();
    dataAcquisitionService = Get.find<DataAcquisitionService>();

    // Suscribirse a los streams de frecuencia y valor máximo
    dataAcquisitionService.frequencyStream.listen((newFrequency) {
      setState(() {
        frequency = newFrequency;
      });
    });

    dataAcquisitionService.maxValueStream.listen((newMaxValue) {
      setState(() {
        maxValue = newMaxValue;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: Container(
            height: 300,
            width: double.infinity,
            child: widget.dataPoints.isEmpty
                ? Center(child: Text('No data'))
                : CustomPaint(
                    painter: LineChartPainter(widget.dataPoints, timeScale, valueScale),
                  ),
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
                });
              },
            ),
            IconButton(
              icon: Icon(Icons.arrow_right),
              onPressed: () {
                setState(() {
                  timeScale *= 1.1;
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
                autoset();
              },
            ),
          ],
        ),
      ],
    );
  }

  void autoset() {
    if (widget.dataPoints.isEmpty) return;

    setState(() {
      timeScale = 1 / frequency; // Ajustar el valor según la frecuencia
      valueScale = maxValue; // Ajustar el valor según el valor máximo
    });
  }
}

class LineChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double timeScale;
  final double valueScale;

  LineChartPainter(this.dataPoints, this.timeScale, this.valueScale);

  @override
  void paint(Canvas canvas, Size size) {
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
    final double offsetY = 30;
    final double offsetX = 50;
    final double sqrOffsetBot = 30;
    final double sqrOffsetTop = 30;

    // Dibujar el fondo para las referencias de x e y
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, offsetY, offsetX, size.height - offsetY), backgroundPaint);

    // Dibujar la grilla y las referencias de x e y
    final textPainter = TextPainter(
      textAlign: TextAlign.left,
      textDirection: TextDirection.ltr,
    );

    for (double i = 0; i <= size.width; i += size.width / 10) {
      final x = i / timeScale;
      final xPos = i + offsetX;
      canvas.drawLine(Offset(xPos, offsetY), Offset(xPos, size.height - sqrOffsetBot), gridPaint);

      textPainter.text = TextSpan(
        text: x.toStringAsFixed(2),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(xPos - 5, size.height - sqrOffsetBot + 10));
    }

    for (double i = 0; i <= size.height - sqrOffsetBot; i += (size.height - sqrOffsetBot) / 10) {
      final y = (size.height - sqrOffsetBot - i) / valueScale;
      final yPos = i + offsetY;
      canvas.drawLine(Offset(offsetX, yPos), Offset(size.width, yPos), gridPaint);

      textPainter.text = TextSpan(
        text: y.toStringAsFixed(2),
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(10, yPos - 5));
    }

    // Dibujar las líneas de datos
    for (int i = 0; i < dataPoints.length - 1; i++) {
      final p1 = Offset(dataPoints[i].x * timeScale + offsetX, size.height - dataPoints[i].y * valueScale - sqrOffsetBot);
      final p2 = Offset(dataPoints[i + 1].x * timeScale + offsetX, size.height - dataPoints[i + 1].y * valueScale - sqrOffsetBot);

      // Omitir los puntos que se salen del recuadro negro
      if (p1.dy < offsetY || p1.dy > size.height - sqrOffsetBot || p2.dy < offsetY || p2.dy > size.height - sqrOffsetBot) {
        continue;
      }

      canvas.drawLine(p1, p2, paint);
    }

    // Dibujar el valor 0 en la esquina inferior izquierda
    textPainter.text = TextSpan(
      text: '0',
      style: TextStyle(color: Colors.black, fontSize: 10),
    );
    textPainter.layout();
    textPainter.paint(canvas, Offset(10, size.height - sqrOffsetBot - 5));

    // Dibujar el recuadro negro alrededor de la grilla
    canvas.drawRect(Rect.fromLTWH(offsetX, offsetY, size.width - offsetX, size.height - sqrOffsetBot - offsetY), borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    return true;
  }
}