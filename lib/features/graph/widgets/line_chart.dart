// lib/features/graph/widgets/line_chart.dart
import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/line_chart_provider.dart';
import '../providers/data_provider.dart';
import 'dart:async';

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
                        : Listener(
                            onPointerSignal: (pointerSignal) {
                              if (pointerSignal is PointerScrollEvent) {
                                final delta = pointerSignal.scrollDelta.dy;
                                if (pointerSignal.kind == PointerDeviceKind.mouse) {
                                  if (RawKeyboard.instance.keysPressed.contains(
                                      LogicalKeyboardKey.controlLeft)) {
                                    lineChartProvider.setTimeScale(
                                      lineChartProvider.timeScale * (1 - delta / 500),
                                    );
                                  } else if (RawKeyboard.instance.keysPressed
                                      .contains(LogicalKeyboardKey.shiftLeft)) {
                                    lineChartProvider.setValueScale(
                                      lineChartProvider.valueScale * (1 - delta / 500),
                                    );
                                  } else {
                                    final scale = 1 - delta / 500;
                                    lineChartProvider.setTimeScale(
                                      lineChartProvider.timeScale * scale,
                                    );
                                    lineChartProvider.setValueScale(
                                      lineChartProvider.valueScale * scale,
                                    );
                                  }
                                }
                              }
                            },
                            child: GestureDetector(
                              onScaleStart: (details) {
                                lineChartProvider.setInitialScales();
                              },
                              onScaleUpdate: (details) {
                                if (details.pointerCount == 2) {
                                  lineChartProvider.handleZoom(details, constraints.biggest);
                                } else if (details.pointerCount == 1) {
                                  lineChartProvider.setHorizontalOffset(
                                    lineChartProvider.horizontalOffset +
                                        details.focalPointDelta.dx / constraints.maxWidth,
                                  );
                                  lineChartProvider.setVerticalOffset(
                                    lineChartProvider.verticalOffset -
                                        details.focalPointDelta.dy / constraints.maxHeight,
                                  );
                                }
                              },
                              child: CustomPaint(
                                painter: LineChartPainter(
                                  dataPoints,
                                  lineChartProvider.timeScale,
                                  lineChartProvider.valueScale,
                                  graphProvider.getMaxValue(),
                                  graphProvider.getDistance(),
                                  graphProvider.getScale(),
                                  Theme.of(context).scaffoldBackgroundColor,
                                  lineChartProvider.horizontalOffset,
                                  lineChartProvider.verticalOffset,
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
          constraints: const BoxConstraints(maxHeight: 48.0),
          child: SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Row(
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
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.decrementTimeScale(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.decrementTimeScale),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_left),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.incrementTimeScale(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.incrementTimeScale),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_right),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.incrementValueScale(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.incrementValueScale),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_upward),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.decrementValueScale(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.decrementValueScale),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_downward),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.autorenew),
                      color: Colors.black,
                      onPressed: () {
                        final size = MediaQuery.of(context).size;
                        graphProvider.autoset(size.height, size.width);
                        lineChartProvider.resetOffsets();
                      },
                    ),
                  ],
                ),
                const SizedBox(width: 20),
                Row(
                  children: [
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.decrementHorizontalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.decrementHorizontalOffset),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.incrementHorizontalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.incrementHorizontalOffset),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_right),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.incrementVerticalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.incrementVerticalOffset),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) => lineChartProvider.decrementVerticalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                          lineChartProvider.decrementVerticalOffset),
                      onLongPressUp: lineChartProvider.stopIncrementing,
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
  final double horizontalOffset;
  final double verticalOffset;

  LineChartPainter(
    this.dataPoints,
    this.timeScale,
    this.valueScale,
    this.maxX,
    this.distance,
    this.voltageScale,
    this.backgroundColor,
    this.horizontalOffset,
    this.verticalOffset,
  );

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    final zeroPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

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

    // Drawing area dimensions
    final drawingWidth = size.width - _offsetX;
    final drawingHeight = size.height - _offsetY - _sqrOffsetBot;
    final centerY = _offsetY + drawingHeight / 2;

    // Background y áreas
    canvas.drawRect(Rect.fromLTWH(0, 0, size.width, _offsetY), backgroundPaint);
    canvas.drawRect(
        Rect.fromLTWH(0, _offsetY, _offsetX, size.height - _offsetY),
        backgroundPaint);
    canvas.drawRect(
        Rect.fromLTWH(_offsetX, _offsetY, drawingWidth, drawingHeight),
        chartBackgroundPaint);

    double valueToScreenY(double value) {
      return centerY -
          ((value * valueScale + verticalOffset) * drawingHeight / 2);
    }

    // Dibujar línea de cero con límites
    final zeroY = valueToScreenY(0.0);
    final clampedZeroY = zeroY.clamp(_offsetY, size.height - _sqrOffsetBot);
    canvas.drawLine(
      Offset(_offsetX, clampedZeroY),
      Offset(size.width, clampedZeroY),
      zeroPaint,
    );

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // Eje X (tiempo)
    for (int i = 0; i <= 10; i++) {
      final x = _offsetX + (drawingWidth * i / 10);
      canvas.drawLine(Offset(x, _offsetY),
          Offset(x, size.height - _sqrOffsetBot), gridPaint);

      final timeValue = ((x - _offsetX) / timeScale -
              horizontalOffset * drawingWidth / timeScale) *
          1e6;
      textPainter.text = TextSpan(
        text: '${timeValue.toStringAsFixed(1)} µs',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas,
          Offset(x - textPainter.width / 2, size.height - _sqrOffsetBot + 5));
    }

    // Modificar cálculo de valores del eje Y
    for (int i = -5; i <= 5; i++) {
      final y = centerY - (i * drawingHeight / 10);
      canvas.drawLine(Offset(_offsetX, y), Offset(size.width, y), gridPaint);

      // Mantener valores consistentes con la visualización
      final value =
          -((y - centerY) / (drawingHeight / 2)) / valueScale - verticalOffset;
      textPainter.text = TextSpan(
        text: '${value.toStringAsFixed(2)} V',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(canvas, Offset(5, y - textPainter.height / 2));
    }
    // Dibujar puntos de datos
    if (dataPoints.length > 1) {
      for (int i = 0; i < dataPoints.length - 1; i++) {
        var p1 = Offset(
            (dataPoints[i].x * timeScale + horizontalOffset * drawingWidth) +
                _offsetX,
            valueToScreenY(dataPoints[i].y));

        var p2 = Offset(
            (dataPoints[i + 1].x * timeScale +
                    horizontalOffset * drawingWidth) +
                _offsetX,
            valueToScreenY(dataPoints[i + 1].y));
        // Skip if both points are outside left boundary
        if (p1.dx < _offsetX && p2.dx < _offsetX) continue;

        // Skip if both points are outside right boundary
        if (p1.dx > size.width && p2.dx > size.width) continue;

        // Clip vertical boundaries
        if (p1.dy < _offsetY) {
          p1 = Offset(p1.dx, _offsetY);
        } else if (p1.dy > size.height - _sqrOffsetBot) {
          p1 = Offset(p1.dx, size.height - _sqrOffsetBot);
        }

        if (p2.dy < _offsetY) {
          p2 = Offset(p2.dx, _offsetY);
        } else if (p2.dy > size.height - _sqrOffsetBot) {
          p2 = Offset(p2.dx, size.height - _sqrOffsetBot);
        }

        // Clip horizontal boundaries
        if (p1.dx < _offsetX) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p1.dy + (_offsetX - p1.dx) * slope;
          p1 = Offset(_offsetX, y);
        } else if (p1.dx > size.width) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p1.dy + (size.width - p1.dx) * slope;
          p1 = Offset(size.width, y);
        }

        if (p2.dx < _offsetX) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final y = p2.dy + (_offsetX - p2.dx) * slope;
          p2 = Offset(_offsetX, y);
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
        Rect.fromLTWH(_offsetX, _offsetY, drawingWidth, drawingHeight),
        borderPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
