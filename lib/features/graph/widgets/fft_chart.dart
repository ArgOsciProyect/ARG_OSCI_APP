// lib/features/graph/widgets/fft_chart.dart
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:scidart/scidart.dart';
import 'package:scidart/numdart.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/graph_provider.dart';

class FFTChart extends StatefulWidget {
  final List<DataPoint> dataPoints;

  const FFTChart({required this.dataPoints, super.key});

  @override
  _FFTChartState createState() => _FFTChartState();
}

class _FFTChartState extends State<FFTChart> {
  late GraphProvider graphProvider;
  List<DataPoint> fftPoints = [];
  double zoomX = 1.0;
  double zoomY = 1.0;
  double offsetX = 0.0;
  double offsetY = 0.0;

  @override
  void initState() {
    super.initState();
    graphProvider = Get.find<GraphProvider>();
    _calculateFFT();
  }

  void _calculateFFT() {
    final yValues = widget.dataPoints.map((point) => point.y).toList();
    final array = Array(yValues);
  
    final fftResult = rfft(array);
  
    final magnitudes = arrayComplexAbs(fftResult);
    final halfLength = (magnitudes.length / 2).ceil();
    final positiveMagnitudes = magnitudes.getRange(0, halfLength).toList();
  
    // Calcular las frecuencias correspondientes
    final samplingRate = 1 / graphProvider.dataAcquisitionService.distance; // Frecuencia de muestreo
    final frequencies = List<double>.generate(halfLength, (i) => i * samplingRate / array.length);
  
    setState(() {
      fftPoints = List<DataPoint>.generate(
        positiveMagnitudes.length,
        (i) => DataPoint(frequencies[i], positiveMagnitudes[i]),
      );
    });
  }
  
  void _zoomIn() {
    setState(() {
      zoomX *= 1.1;
      zoomY *= 1.1;
    });
  }

  void _zoomOut() {
    setState(() {
      zoomX *= 0.9;
      zoomY *= 0.9;
    });
  }

  void _moveLeft() {
    setState(() {
      offsetX -= 10;
    });
  }

  void _moveRight() {
    setState(() {
      offsetX += 10;
    });
  }

  void _moveUp() {
    setState(() {
      offsetY -= 10;
    });
  }

  void _moveDown() {
    setState(() {
      offsetY += 10;
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
                    ? Center(child: Text('No data'))
                    : CustomPaint(
                        painter: FFTChartPainter(fftPoints, zoomX, zoomY, offsetX, offsetY),
                      ),
              );
            },
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            IconButton(
              icon: Icon(Icons.zoom_in),
              onPressed: _zoomIn,
            ),
            IconButton(
              icon: Icon(Icons.zoom_out),
              onPressed: _zoomOut,
            ),
            IconButton(
              icon: Icon(Icons.arrow_left),
              onPressed: _moveLeft,
            ),
            IconButton(
              icon: Icon(Icons.arrow_right),
              onPressed: _moveRight,
            ),
            IconButton(
              icon: Icon(Icons.arrow_upward),
              onPressed: _moveUp,
            ),
            IconButton(
              icon: Icon(Icons.arrow_downward),
              onPressed: _moveDown,
            ),
          ],
        ),
      ],
    );
  }
}

class FFTChartPainter extends CustomPainter {
  final List<DataPoint> fftPoints;
  final double zoomX;
  final double zoomY;
  final double offsetX;
  final double offsetY;

  FFTChartPainter(this.fftPoints, this.zoomX, this.zoomY, this.offsetX, this.offsetY);

  @override
  void paint(Canvas canvas, Size size) {
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

    const double marginY = 30;
    const double marginX = 50;
    const double sqrOffsetBot = 30;

    final drawingWidth = size.width - marginX;
    final drawingHeight = size.height - marginY - sqrOffsetBot;

    // Fondo
    final backgroundPaint = Paint()
      ..color = Colors.grey[200]!
      ..style = PaintingStyle.fill;
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, marginY), backgroundPaint);
    canvas.drawRect(Rect.fromLTWH(0, marginY, marginX, size.height - marginY), backgroundPaint);

    // Grilla y etiquetas
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Eje X: Frecuencias
    for (int i = 0; i <= 10; i++) {
      final x = marginX + (drawingWidth * i / 10) * zoomX + offsetX;
      canvas.drawLine(
        Offset(x, marginY),
        Offset(x, size.height - sqrOffsetBot),
        gridPaint,
      );

      final freqValue = (i * fftPoints.length / 10).toStringAsFixed(1);
      textPainter.text = TextSpan(
        text: '$freqValue Hz',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, size.height - sqrOffsetBot + 5),
      );
    }

    // Eje Y: Magnitudes
    final maxY = fftPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);
    for (int i = 0; i <= 10; i++) {
      final y = marginY + (drawingHeight * (10 - i) / 10) * zoomY + offsetY;
      canvas.drawLine(
        Offset(marginX, y),
        Offset(size.width, y),
        gridPaint,
      );

      final value = (maxY * i / 10).toStringAsFixed(2);
      textPainter.text = TextSpan(
        text: '$value',
        style: TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, y - textPainter.height / 2),
      );
    }

    // Dibujar puntos FFT
    if (fftPoints.length > 1) {
      for (int i = 0; i < fftPoints.length - 1; i++) {
        final p1 = Offset(
          fftPoints[i].x * drawingWidth / fftPoints.length * zoomX + marginX + offsetX,
          size.height - fftPoints[i].y * drawingHeight / maxY * zoomY - sqrOffsetBot + offsetY,
        );
        final p2 = Offset(
          fftPoints[i + 1].x * drawingWidth / fftPoints.length * zoomX + marginX + offsetX,
          size.height - fftPoints[i + 1].y * drawingHeight / maxY * zoomY - sqrOffsetBot + offsetY,
        );

        canvas.drawLine(p1, p2, paint);
      }
    }

    // Borde
    canvas.drawRect(
      Rect.fromLTWH(marginX, marginY, drawingWidth, drawingHeight),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}