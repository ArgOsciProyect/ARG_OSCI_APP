// lib/features/graph/widgets/fft_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/fft_chart_provider.dart';

const double _offsetY = 30;
const double _offsetX = 50;
const double _sqrOffsetBot = 30;
late Size _size;

class FFTChart extends StatelessWidget {
  FFTChart({super.key});

  @override
  Widget build(BuildContext context) {
    final fftChartProvider = Get.find<FFTChartProvider>();

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
                    final fftPoints = fftChartProvider.fftPoints.value;
                    final timeScale = fftChartProvider.timeScale.value;
                    final valueScale = fftChartProvider.valueScale.value;
                    return fftPoints.isEmpty
                        ? Center(child: Text('No data'))
                        : CustomPaint(
                            painter: FFTChartPainter(
                              fftPoints,
                              timeScale,
                              valueScale,
                              1.0, // maxValue can be set dynamically if needed
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
                icon: Icon(Icons.arrow_left),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.timeScale.value *= 0.9;
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_right),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.timeScale.value *= 1.1;
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_upward),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.valueScale.value *= 1.1;
                },
              ),
              IconButton(
                icon: Icon(Icons.arrow_downward),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.valueScale.value *= 0.9;
                },
              ),
              IconButton(
                icon: Icon(Icons.autorenew),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.timeScale.value = 1.0;
                  fftChartProvider.valueScale.value = 1.0;
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class FFTChartPainter extends CustomPainter {
  final List<DataPoint> fftPoints;
  final double timeScale;
  final double valueScale;
  final double maxValue;

  FFTChartPainter(this.fftPoints, this.timeScale, this.valueScale, this.maxValue);

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

    const double offsetY = _offsetY;
    const double offsetX = _offsetX;
    const double sqrOffsetBot = _sqrOffsetBot;

    final drawingWidth = size.width - offsetX;
    final drawingHeight = size.height - offsetY - sqrOffsetBot;

    // Background
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, offsetY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, offsetY, offsetX, size.height - offsetY), backgroundPaint);

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // X axis grid and labels (frequency)
    final maxFreq = fftPoints.isNotEmpty ? fftPoints.last.x : 0;
    final displayMaxFreq = maxFreq * timeScale; // Ajustado para zoom
    for (int i = 0; i <= 10; i++) {
      final x = offsetX + (drawingWidth * i / 10);
      canvas.drawLine(
        Offset(x, offsetY),
        Offset(x, size.height - sqrOffsetBot),
        gridPaint,
      );

      final freqValue = displayMaxFreq * i / 10;
      textPainter.text = TextSpan(
        text: '${freqValue.toStringAsFixed(1)} Hz',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - sqrOffsetBot + 5),
      );
    }

    // Y axis grid and labels (magnitude)
    final displayMaxValue = maxValue * valueScale; // Ajustado para zoom
    for (int i = 0; i <= 10; i++) {
      final y = offsetY + (drawingHeight * i / 10);
      canvas.drawLine(
        Offset(offsetX, y),
        Offset(size.width, y),
        gridPaint,
      );

      final value = displayMaxValue * (10 - i) / 10;
      textPainter.text = TextSpan(
        text: (value).toStringAsFixed(2),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, y - textPainter.height / 2),
      );
    }

    // Draw FFT points
    if (fftPoints.length > 1) {
      for (int i = 0; i < fftPoints.length - 1; i++) {
        // Normalizar los valores al rango visible actual
        var p1 = Offset(
          offsetX + (fftPoints[i].x * drawingWidth / displayMaxFreq),
          size.height - (fftPoints[i].y * drawingHeight / displayMaxValue) - sqrOffsetBot,
        );
        var p2 = Offset(
          offsetX + (fftPoints[i + 1].x * drawingWidth / displayMaxFreq),
          size.height - (fftPoints[i + 1].y * drawingHeight / displayMaxValue) - sqrOffsetBot,
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

        // Solo dibuja la línea si al menos un punto está dentro del área visible
        if (p1.dx >= offsetX && p1.dx <= size.width &&
            p2.dx >= offsetX && p2.dx <= size.width) {
          canvas.drawLine(p1, p2, paint);
        }
      }
    }

    // Border
    canvas.drawRect(
      Rect.fromLTWH(offsetX, offsetY, drawingWidth, drawingHeight),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}