// lib/features/graph/widgets/line_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/graph_provider.dart';

late Size _size;
// Mover el gráfico hacia arriba y a la derecha
const double _offsetY = 15;
const double _offsetX = 50;
const double _sqrOffsetBot = 15;
const double _sqrOffsetTop = 30;

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
  double voltageScale = 1.0;

  late GraphProvider graphProvider;

  @override
  void initState() {
    super.initState();
    graphProvider = Get.find<GraphProvider>();

    graphProvider.dataAcquisitionService.frequencyStream.listen((newFrequency) {
      setState(() {
        frequency = newFrequency;
      });
    });

    graphProvider.dataAcquisitionService.maxValueStream.listen((newMaxValue) {
      setState(() {
        maxX = newMaxValue;
      });
    });

    voltageScale = graphProvider.dataAcquisitionService.scale;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                color: Colors.grey[200],
                child: SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: widget.dataPoints.isEmpty
                      ? Center(child: Text('No data'))
                      : CustomPaint(
                          painter: LineChartPainter(
                            widget.dataPoints,
                            timeScale,
                            valueScale,
                            maxX,
                            graphProvider.dataAcquisitionService.distance,
                            voltageScale,
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        Container(
          color: Colors.grey[200],
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Icon(Icons.arrow_left),
                color: Colors.black, // Color del icono
                onPressed: () {
                  setState(() {
                    timeScale *= 0.9;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_right),
                color: Colors.black, // Color del icono
                onPressed: () {
                  setState(() {
                    timeScale *= 1.1;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_upward),
                color: Colors.black, // Color del icono
                onPressed: () {
                  setState(() {
                    valueScale *= 1.1;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_downward),
                color: Colors.black, // Color del icono
                onPressed: () {
                  setState(() {
                    valueScale *= 0.9;
                  });
                },
              ),
              IconButton(
                icon: Icon(Icons.autorenew),
                color: Colors.black, // Color del icono
                onPressed: () {
                  final List<double> auto = graphProvider.autoset(
                    _size.height - _offsetY * 2,
                    _size.width - _offsetX,
                  );
                  setState(() {
                    valueScale = auto[1];
                    timeScale = auto[0];
                  });
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class LineChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double timeScale;
  final double valueScale;
  final double maxX;
  final double distance;
  final double voltageScale;

  LineChartPainter(this.dataPoints, this.timeScale, this.valueScale, 
      this.maxX, this.distance, this.voltageScale);

  @override
  void paint(Canvas canvas, Size size) {
    _size = size;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    final borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;

    final chartBackgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    const double offsetY = _offsetY;
    const double offsetX = _offsetX;
    const double sqrOffsetBot = _sqrOffsetBot;

    // Drawing area dimensions
    final drawingWidth = size.width - offsetX;
    final drawingHeight = size.height - offsetY - sqrOffsetBot;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, offsetY, offsetX, size.height - offsetY), backgroundPaint);

    // Chart background
    canvas.drawRect(Rect.fromLTWH(offsetX, offsetY, drawingWidth, drawingHeight), chartBackgroundPaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
 
    for (int i = 0; i <= 10; i++) {
      final x = offsetX + (drawingWidth * i / 10);
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, size.height - sqrOffsetBot),
        gridPaint
      );

      // Calcular el tiempo real en este punto
      final timeValue = (x - offsetX) / timeScale * 1e6;  // en microsegundos
      textPainter.text = TextSpan(
        text: '${timeValue.toStringAsFixed(1)} µs',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - sqrOffsetBot + 5)
      );
    }

    // Y axis grid and labels
    // Usar la misma transformación que usamos para los puntos
    for (int i = 0; i <= 10; i++) {
      final y = offsetY + (drawingHeight * i / 10);
      canvas.drawLine(
        Offset(offsetX, y),
        Offset(size.width, y),
        gridPaint
      );

      // Calcular el valor real en este punto usando la misma transformación
      final value = ((size.height - y - sqrOffsetBot) / valueScale) * voltageScale;
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(2)} V',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, y - textPainter.height / 2)
      );
    }

    // Draw data points
    if (dataPoints.length > 1) {
      for (int i = 0; i < dataPoints.length - 1; i++) {
        var p1 = Offset(
          dataPoints[i].x * timeScale + offsetX,
          size.height - dataPoints[i].y * valueScale - sqrOffsetBot
        );
        var p2 = Offset(
          dataPoints[i + 1].x * timeScale + offsetX,
          size.height - dataPoints[i + 1].y * valueScale - sqrOffsetBot
        );

        // Clip points to drawing area
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

        // Clip points to the right edge of the drawing area
        if (p1.dx > size.width) {
          p1 = Offset(size.width, p1.dy);
        }
        if (p2.dx > size.width) {
          p2 = Offset(size.width, p2.dy);
        }

        canvas.drawLine(p1, p2, paint);
      }
    }

    // Border
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, drawingWidth, drawingHeight),
      borderPaint
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}