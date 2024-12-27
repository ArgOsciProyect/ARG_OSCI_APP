import 'package:flutter/material.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/fft_chart_provider.dart';

const double _offsetY = 30;
const double _offsetX = 50;
const double _sqrOffsetBot = 30;

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
                        ? const Center(child: Text('No data'))
                        : CustomPaint(
                            painter: FFTChartPainter(
                              fftPoints,
                              timeScale,
                              valueScale,
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
                icon: const Icon(Icons.arrow_left),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.timeScale.value *= 0.9;
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_right),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.timeScale.value *= 1.1;
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_upward),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.valueScale.value *= 1.1;
                },
              ),
              IconButton(
                icon: const Icon(Icons.arrow_downward),
                color: Colors.black,
                onPressed: () {
                  fftChartProvider.valueScale.value *= 0.9;
                },
              ),
              IconButton(
                icon: const Icon(Icons.autorenew),
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

  FFTChartPainter(this.fftPoints, this.timeScale, this.valueScale);

  @override
  void paint(Canvas canvas, Size size) {
    if (fftPoints.isEmpty) return;
  
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;
  
    final gridPaint = Paint()
      ..color = Colors.grey.withOpacity(0.5)
      ..strokeWidth = 0.5;
  
    final chartArea = Rect.fromLTWH(
      _offsetX,
      _offsetY,
      size.width - _offsetX - 10,
      size.height - _offsetY - _sqrOffsetBot
    );
  
    // Fondo blanco
    canvas.drawRect(
      chartArea,
      Paint()..color = Colors.white,
    );
  
    // Valores máximos
    final maxX = fftPoints.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    final minY = fftPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = fftPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);
  
    double toScreenX(double x) {
      return _offsetX + (x / (maxX * timeScale)) * chartArea.width;
    }
  
    double toScreenY(double y) {
      final range = (maxY - minY) * valueScale;
      final normalizedY = (y - minY) / range;
      return chartArea.bottom - (normalizedY * chartArea.height);
    }
  
    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
  
    // Grid y etiquetas X
    final xDivisions = 10;
    for (int i = 0; i <= xDivisions; i++) {
      final x = _offsetX + (chartArea.width * i / xDivisions);
      final xValue = (maxX * timeScale * i / xDivisions);
  
      canvas.drawLine(
        Offset(x, chartArea.top),
        Offset(x, chartArea.bottom),
        gridPaint,
      );
  
      textPainter.text = TextSpan(
        text: '${xValue.toStringAsFixed(1)} Hz',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(x - textPainter.width / 2, chartArea.bottom + 5),
      );
    }
  
    // Grid y etiquetas Y
    final yDivisions = 10;
    for (int i = 0; i <= yDivisions; i++) {
      final y = chartArea.top + (chartArea.height * i / yDivisions);
      final yValue = maxY - (i * (maxY - minY) * valueScale / yDivisions);
  
      canvas.drawLine(
        Offset(_offsetX, y),
        Offset(chartArea.right, y),
        gridPaint,
      );
  
      textPainter.text = TextSpan(
        text: '${yValue.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(_offsetX - textPainter.width - 5, y - textPainter.height / 2),
      );
    }
  
    // Dibujar puntos FFT con clipping
    final path = Path();
    bool firstPoint = true;
  
    for (int i = 0; i < fftPoints.length; i++) {
      var screenX = toScreenX(fftPoints[i].x);
      var screenY = toScreenY(fftPoints[i].y);
  
      // Aplicar clipping
      if (screenX < _offsetX) screenX = _offsetX;
      if (screenX > chartArea.right) screenX = chartArea.right;
      if (screenY < chartArea.top) screenY = chartArea.top;
      if (screenY > chartArea.bottom) screenY = chartArea.bottom;
  
      if (firstPoint) {
        path.moveTo(screenX, screenY);
        firstPoint = false;
      } else {
        path.lineTo(screenX, screenY);
      }
    }
  
    // Aplicar clipping al área del gráfico
    canvas.save();
    canvas.clipRect(chartArea);
    canvas.drawPath(path, paint);
    canvas.restore();
  
    // Borde negro
    canvas.drawRect(
      chartArea,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}