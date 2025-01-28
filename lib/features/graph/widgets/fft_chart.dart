// fft_chart.dart
import 'package:arg_osci_app/features/graph/providers/data_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/fft_chart_provider.dart';

const double _offsetY = 30;
const double _offsetX = 50;
const double _sqrOffsetBot = 30;

class FFTChart extends StatelessWidget {
  const FFTChart({super.key});

  @override
  Widget build(BuildContext context) {
    final fftChartProvider = Get.find<FFTChartProvider>();
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
                    final fftPoints = fftChartProvider.fftPoints.value;
                    return fftPoints.isEmpty
                        ? const Center(child: Text('No data'))
                        : Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final delta = pointerSignal.scrollDelta.dy;
                                if (pointerSignal.kind == PointerDeviceKind.mouse) {
                                  if (RawKeyboard.instance.keysPressed.contains(
                                      LogicalKeyboardKey.controlLeft)) {
                                    fftChartProvider.setTimeScale(
                                      fftChartProvider.timeScale.value * (1 - delta / 500),
                                    );
                                  } else if (RawKeyboard.instance.keysPressed
                                      .contains(LogicalKeyboardKey.shiftLeft)) {
                                    fftChartProvider.setValueScale(
                                      fftChartProvider.valueScale.value * (1 - delta / 500),
                                    );
                                  } else {
                                    final scale = 1 - delta / 500;
                                    fftChartProvider.setTimeScale(
                                      fftChartProvider.timeScale.value * scale,
                                    );
                                    fftChartProvider.setValueScale(
                                      fftChartProvider.valueScale.value * scale,
                                    );
                                  }
                                }
                              }
                            },
                            child: GestureDetector(
                              onScaleStart: (details) {
                                fftChartProvider.setInitialScales();
                              },
                              onScaleUpdate: (details) {
                                if (details.pointerCount == 2) {
                                  fftChartProvider.handleZoom(details, constraints.biggest);
                                } else if (details.pointerCount == 1) {
                                  fftChartProvider.setHorizontalOffset(
                                    fftChartProvider.horizontalOffset +
                                        details.focalPointDelta.dx / constraints.maxWidth,
                                  );
                                  fftChartProvider.setVerticalOffset(
                                    fftChartProvider.verticalOffset -
                                        details.focalPointDelta.dy / constraints.maxHeight,
                                  );
                                }
                              },
                              child: CustomPaint(
                                painter: FFTChartPainter(
                                  fftPoints,
                                  fftChartProvider.timeScale.value,
                                  fftChartProvider.valueScale.value,
                                ),
                              ),
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
              // Existing controls
              IconButton(
                icon: Obx(() => Icon(
                      fftChartProvider.isPaused
                          ? Icons.play_arrow
                          : Icons.pause,
                    )),
                color: Colors.black,
                onPressed: () => fftChartProvider.isPaused
                    ? fftChartProvider.resume()
                    : fftChartProvider.pause(),
              ),
              GestureDetector(
                onTapDown: (_) => fftChartProvider.decrementTimeScale(),
                onLongPress: () => fftChartProvider.startIncrementing(
                    fftChartProvider.decrementTimeScale),
                onLongPressUp: fftChartProvider.stopIncrementing,
                child: IconButton(
                  icon: const Icon(Icons.arrow_left),
                  color: Colors.black,
                  onPressed: null,
                ),
              ),
              GestureDetector(
                onTapDown: (_) => fftChartProvider.incrementTimeScale(),
                onLongPress: () => fftChartProvider.startIncrementing(
                    fftChartProvider.incrementTimeScale),
                onLongPressUp: fftChartProvider.stopIncrementing,
                child: IconButton(
                  icon: const Icon(Icons.arrow_right),
                  color: Colors.black,
                  onPressed: null,
                ),
              ),
              GestureDetector(
                onTapDown: (_) => fftChartProvider.incrementValueScale(),
                onLongPress: () => fftChartProvider.startIncrementing(
                    fftChartProvider.incrementValueScale),
                onLongPressUp: fftChartProvider.stopIncrementing,
                child: IconButton(
                  icon: const Icon(Icons.arrow_upward),
                  color: Colors.black,
                  onPressed: null,
                ),
              ),
              GestureDetector(
                onTapDown: (_) => fftChartProvider.decrementValueScale(),
                onLongPress: () => fftChartProvider.startIncrementing(
                    fftChartProvider.decrementValueScale),
                onLongPressUp: fftChartProvider.stopIncrementing,
                child: IconButton(
                  icon: const Icon(Icons.arrow_downward),
                  color: Colors.black,
                  onPressed: null,
                ),
              ),
              // In FFTChart widget:
              IconButton(
                icon: const Icon(Icons.autorenew),
                color: Colors.black,
                onPressed: () {
                  final size = MediaQuery.of(context).size;
                  final fftFrequency = fftChartProvider.frequency.value;
                  // Use FFT frequency, fallback to graph provider if 0
                  final freqToUse = fftFrequency > 0 ? fftFrequency : graphProvider.frequency.value;
                  fftChartProvider.autoset(size, freqToUse);
                },
              ),
              const SizedBox(width: 20),
              // Pan controls
              Row(
                children: [
                  GestureDetector(
                    onTapDown: (_) => fftChartProvider.decrementHorizontalOffset(),
                    onLongPress: () => fftChartProvider.startIncrementing(
                        fftChartProvider.decrementHorizontalOffset),
                    onLongPressUp: fftChartProvider.stopIncrementing,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_left),
                      color: Colors.black,
                      onPressed: null,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => fftChartProvider.incrementHorizontalOffset(),
                    onLongPress: () => fftChartProvider.startIncrementing(
                        fftChartProvider.incrementHorizontalOffset),
                    onLongPressUp: fftChartProvider.stopIncrementing,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_right),
                      color: Colors.black,
                      onPressed: null,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => fftChartProvider.incrementVerticalOffset(),
                    onLongPress: () => fftChartProvider.startIncrementing(
                        fftChartProvider.incrementVerticalOffset),
                    onLongPressUp: fftChartProvider.stopIncrementing,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_up),
                      color: Colors.black,
                      onPressed: null,
                    ),
                  ),
                  GestureDetector(
                    onTapDown: (_) => fftChartProvider.decrementVerticalOffset(),
                    onLongPress: () => fftChartProvider.startIncrementing(
                        fftChartProvider.decrementVerticalOffset),
                    onLongPressUp: fftChartProvider.stopIncrementing,
                    child: IconButton(
                      icon: const Icon(Icons.keyboard_arrow_down),
                      color: Colors.black,
                      onPressed: null,
                    ),
                  ),
                ],
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
      size.height - _offsetY - _sqrOffsetBot,
    );

    // Fondo blanco
    canvas.drawRect(chartArea, Paint()..color = Colors.white);

    // Valores máximos y mínimos
    final maxX = fftPoints.map((p) => p.x).reduce((a, b) => a > b ? a : b);
    final minY = fftPoints.map((p) => p.y).reduce((a, b) => a < b ? a : b);
    final maxY = fftPoints.map((p) => p.y).reduce((a, b) => a > b ? a : b);

    // Calcular escalado centrado
    final centerY = (maxY + minY) / 2;
    final halfRange = ((maxY - minY) / 2) / valueScale;
    final scaledMinY = centerY - halfRange;
    final scaledMaxY = centerY + halfRange;

    double toScreenX(double x) {
      return _offsetX + (x / (maxX * timeScale)) * chartArea.width;
    }

    double toScreenY(double y) {
      final normalizedY = (y - scaledMinY) / (scaledMaxY - scaledMinY);
      return chartArea.bottom - (normalizedY * chartArea.height);
    }

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Grid y etiquetas X
    const xDivisions = 10;
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
    const yDivisions = 10;
    for (int i = 0; i <= yDivisions; i++) {
      final ratio = i / yDivisions;
      final yCoord = chartArea.top + chartArea.height * ratio;
      final yValue = scaledMaxY - ratio * (scaledMaxY - scaledMinY);

      canvas.drawLine(
        Offset(_offsetX, yCoord),
        Offset(chartArea.right, yCoord),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: '${yValue.toStringAsFixed(2)}',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
            _offsetX - textPainter.width - 5, yCoord - textPainter.height / 2),
      );
    }

    // Dibujar curva
    final path = Path();
    bool firstPoint = true;
    for (final point in fftPoints) {
      final sx = toScreenX(point.x);
      final sy = toScreenY(point.y);
      if (firstPoint) {
        path.moveTo(sx, sy);
        firstPoint = false;
      } else {
        path.lineTo(sx, sy);
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
