import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/graph_provider.dart';

const double _offsetY = 30;
const double _offsetX = 50;
const double _sqrOffsetBot = 30;
late Size _size;

class FFTChart extends StatefulWidget {
  final List<DataPoint> dataPoints;

  const FFTChart({required this.dataPoints, super.key});

  @override
  _FFTChartState createState() => _FFTChartState();
}

class _FFTChartState extends State<FFTChart> {
  late GraphProvider graphProvider;
  List<DataPoint> fftPoints = [];
  double timeScale = 1.0;
  double valueScale = 1.0;
  double frequency = 1.0;
  double maxValue = 1.0;

  @override
  void initState() {
    super.initState();
    graphProvider = Get.find<GraphProvider>();
    _calculateFFT();

    graphProvider.dataAcquisitionService.frequencyStream.listen((newFrequency) {
      setState(() {
        frequency = newFrequency;
      });
    });
  }

  void _calculateFFT() {
    final yValues = widget.dataPoints.map((point) => point.y).toList();
    final array = Array(yValues);
  
    final fftResult = rfft(array);
    final magnitudes = arrayComplexAbs(fftResult);
    final halfLength = (magnitudes.length / 2).ceil();
    final positiveMagnitudes = magnitudes.getRange(0, halfLength).toList();
  
    final samplingRate = 1 / graphProvider.dataAcquisitionService.distance;
    final frequencies = List<double>.generate(halfLength, (i) => i * samplingRate / array.length);
  
    setState(() {
      fftPoints = List<DataPoint>.generate(
        positiveMagnitudes.length,
        (i) => DataPoint(frequencies[i], positiveMagnitudes[i]),
      );
      maxValue = positiveMagnitudes.reduce((a, b) => a > b ? a : b);
    });
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
                child: fftPoints.isEmpty
                    ? const Center(child: Text('No data'))
                    : CustomPaint(
                        painter: FFTChartPainter(
                          fftPoints,
                          timeScale,
                          valueScale,
                          maxValue,
                        ),
                      ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: const Icon(Icons.arrow_left),
              onPressed: () {
                setState(() {
                  timeScale *= 0.9; // Zoom in horizontal
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_right),
              onPressed: () {
                setState(() {
                  timeScale *= 1.1; // Zoom out horizontal
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_upward),
              onPressed: () {
                setState(() {
                  valueScale *= 0.9; // Zoom in vertical
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.arrow_downward),
              onPressed: () {
                setState(() {
                  valueScale *= 1.1; // Zoom out vertical
                });
              },
            ),
            IconButton(
              icon: const Icon(Icons.autorenew),
              onPressed: () {
                setState(() {
                  timeScale = 1.0;
                  valueScale = 1.0;
                });
              },
            ),
          ],
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