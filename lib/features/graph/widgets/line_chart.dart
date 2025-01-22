// lib/features/graph/widgets/line_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/line_chart_provider.dart';
import '../providers/data_provider.dart';

// ignore: unused_element
late Size _size;
// Mover el gráfico hacia arriba y a la derecha
const double _offsetY = 15;
const double _offsetX = 50;
const double _sqrOffsetBot = 15;

class LineChart extends StatelessWidget {
  const LineChart({super.key});

  @override
  Widget build(BuildContext context) {
    final lineChartProvider = Get.find<LineChartProvider>();
    final graphProvider = Get.find<GraphProvider>();

    return Column(
      children: [
        Expanded(
          child: LayoutBuilder(
            builder: (context, constraints) {
              return Container(
                color: Theme.of(context).scaffoldBackgroundColor,
                child: SizedBox(
                  height: constraints.maxHeight,
                  width: constraints.maxWidth,
                  child: Obx(() {
                    final dataPoints = lineChartProvider.dataPoints;
                    return dataPoints.isEmpty
                        ? const Center(child: Text('No data'))
                        : CustomPaint(
                            painter: LineChartPainter(
                              dataPoints,
                              lineChartProvider.timeScale,
                              lineChartProvider.valueScale,
                              graphProvider.getMaxValue(),
                              graphProvider.getDistance(),
                              graphProvider.getScale(),
                              Theme.of(context).scaffoldBackgroundColor,
                            ),
                          );
                  }),
                ),
              );
            },
          ),
        ),
        Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: Obx(() => Icon(
                      lineChartProvider.isPaused
                          ? Icons.play_arrow
                          : Icons.pause,
                    )),
                color: Colors.black,
                onPressed: () => lineChartProvider.isPaused
                    ? lineChartProvider.resume()
                    : lineChartProvider.pause(),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_left),
                color: Colors.black,
                onPressed: () => lineChartProvider
                    .setTimeScale(lineChartProvider.timeScale * 0.9),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                color: Colors.black,
                onPressed: () => lineChartProvider
                    .setTimeScale(lineChartProvider.timeScale * 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                color: Colors.black,
                onPressed: () => lineChartProvider
                    .setValueScale(lineChartProvider.valueScale * 1.1),
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                color: Colors.black,
                onPressed: () => lineChartProvider
                    .setValueScale(lineChartProvider.valueScale * 0.9),
              ),
              IconButton(
                icon: const Icon(Icons.autorenew),
                color: Colors.black,
                onPressed: () {
                  final size = MediaQuery.of(context).size;
                  graphProvider.autoset(size.height, size.width);
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
  final Color backgroundColor;

  LineChartPainter(this.dataPoints, this.timeScale, this.valueScale, this.maxX,
      this.distance, this.voltageScale, this.backgroundColor);

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
      ..color = backgroundColor
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
    final centerY = offsetY + drawingHeight / 2;

    // Background y áreas
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, offsetY, offsetX, size.height - offsetY),
        backgroundPaint);
    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, drawingWidth, drawingHeight),
        chartBackgroundPaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Eje X (tiempo)
    for (int i = 0; i <= 10; i++) {
      final x = offsetX + (drawingWidth * i / 10);
      canvas.drawLine(
          Offset(x, offsetY), Offset(x, size.height - sqrOffsetBot), gridPaint);

      final timeValue = (x - offsetX) / timeScale * 1e6;
      textPainter.text = TextSpan(
        text: '${timeValue.toStringAsFixed(1)} µs',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, size.height - sqrOffsetBot + 5));
    }

    // Para el eje Y - modificar para que se ajuste con la escala
    for (int i = -5; i <= 5; i++) {
      final y = centerY - (i * drawingHeight / 10);
      canvas.drawLine(Offset(offsetX, y), Offset(size.width, y), gridPaint);

      // El valor debe ser proporcional a la posición en la pantalla
      final value = (centerY - y) / (drawingHeight / 2) / valueScale;
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(2)} V',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }

    // Dibujar puntos de datos
    if (dataPoints.length > 1) {
      for (int i = 0; i < dataPoints.length - 1; i++) {
        var p1 = Offset(dataPoints[i].x * timeScale + offsetX,
            centerY - (dataPoints[i].y * valueScale * drawingHeight / 2));
        var p2 = Offset(dataPoints[i + 1].x * timeScale + offsetX,
            centerY - (dataPoints[i + 1].y * valueScale * drawingHeight / 2));

        // Skip if both points are outside left boundary
        if (p1.dx < offsetX && p2.dx < offsetX) {
          continue;
        }

        // Skip if both points are outside right boundary
        if (p1.dx > size.width && p2.dx > size.width) {
          continue;
        }

        // Clip vertical boundaries
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

        // Clip horizontal boundaries
        if (p1.dx < offsetX) {
          // Calculate intersection with left boundary
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p1.dy + (offsetX - p1.dx) * slope;
          p1 = Offset(offsetX, y);
        } else if (p1.dx > size.width) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p1.dy + (size.width - p1.dx) * slope;
          p1 = Offset(size.width, y);
        }

        if (p2.dx < offsetX) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p2.dy + (offsetX - p2.dx) * slope;
          p2 = Offset(offsetX, y);
        } else if (p2.dx > size.width) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p2.dy + (size.width - p2.dx) * slope;
          p2 = Offset(size.width, y);
        }

        canvas.drawLine(p1, p2, paint);
      }
    }

    // Borde
    canvas.drawRect(
        Rect.fromLTWH(offsetX, offsetY, drawingWidth, drawingHeight),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
