import 'dart:math';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import '../../graph/domain/models/data_point.dart';
import '../../graph/providers/line_chart_provider.dart';
import '../providers/data_acquisition_provider.dart';

const double _offsetY = 15;
const double _offsetX = 50;
const double _sqrOffsetBot = 15;

class LineChart extends StatelessWidget {
  const LineChart({super.key});

  @override
  Widget build(BuildContext context) {
    final lineChartProvider = Get.find<LineChartProvider>();
    final graphProvider = Get.find<DataAcquisitionProvider>();

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
                                if (pointerSignal.kind ==
                                    PointerDeviceKind.mouse) {
                                  if (RawKeyboard.instance.keysPressed.contains(
                                      LogicalKeyboardKey.controlLeft)) {
                                    // Zoom horizontal (tiempo)
                                    lineChartProvider.setTimeScale(
                                      lineChartProvider.timeScale *
                                          (1 - delta / 500),
                                    );
                                  } else if (RawKeyboard.instance.keysPressed
                                      .contains(LogicalKeyboardKey.shiftLeft)) {
                                    // Zoom vertical (voltaje)
                                    lineChartProvider.setValueScale(
                                      lineChartProvider.valueScale *
                                          (1 - delta / 500),
                                    );
                                  } else {
                                    // Zoom combinado
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
                                  // Zoom con pinch
                                  lineChartProvider.handleZoom(
                                    details,
                                    constraints.biggest,
                                    _offsetX,
                                  );
                                } else if (details.pointerCount == 1) {
                                  // Desplazamiento
                                  lineChartProvider.setHorizontalOffset(
                                    lineChartProvider.horizontalOffset +
                                        details.focalPointDelta.dx /
                                            constraints.maxWidth,
                                  );
                                  lineChartProvider.setVerticalOffset(
                                    lineChartProvider.verticalOffset -
                                        details.focalPointDelta.dy /
                                            constraints.maxHeight,
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
                        lineChartProvider.decrementTimeScale,
                      ),
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
                        lineChartProvider.incrementTimeScale,
                      ),
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
                        lineChartProvider.incrementValueScale,
                      ),
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
                        lineChartProvider.decrementValueScale,
                      ),
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
                      onTapDown: (_) =>
                          lineChartProvider.decrementHorizontalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                        lineChartProvider.decrementHorizontalOffset,
                      ),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_left),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) =>
                          lineChartProvider.incrementHorizontalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                        lineChartProvider.incrementHorizontalOffset,
                      ),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_right),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) =>
                          lineChartProvider.incrementVerticalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                        lineChartProvider.incrementVerticalOffset,
                      ),
                      onLongPressUp: lineChartProvider.stopIncrementing,
                      child: IconButton(
                        icon: const Icon(Icons.keyboard_arrow_up),
                        color: Colors.black,
                        onPressed: null,
                      ),
                    ),
                    GestureDetector(
                      onTapDown: (_) =>
                          lineChartProvider.decrementVerticalOffset(),
                      onLongPress: () => lineChartProvider.startIncrementing(
                        lineChartProvider.decrementVerticalOffset,
                      ),
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
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();

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

    // Dimensiones de la región de dibujo
    final drawingWidth = size.width - _offsetX;
    final drawingHeight = size.height - _offsetY - _sqrOffsetBot;
    final centerY = _offsetY + drawingHeight / 2;

    // Fondo
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _offsetY),
      backgroundPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _offsetY, _offsetX, size.height - _offsetY),
      backgroundPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(_offsetX, _offsetY, drawingWidth, drawingHeight),
      chartBackgroundPaint,
    );

    // Funciones de conversión
    double domainToScreenY(double domainVal) {
      // Igual que dibujar data
      return centerY -
          ((domainVal * valueScale + verticalOffset) * drawingHeight / 2);
    }

    double screenToDomainY(double screenVal) {
      return -((screenVal - centerY) / (drawingHeight / 2)) / valueScale -
          verticalOffset;
    }

    double domainToScreenX(double domainVal) {
      return (domainVal * timeScale) +
          (horizontalOffset * drawingWidth) +
          _offsetX;
    }

    double screenToDomainX(double screenVal) {
      final localX = screenVal - _offsetX;
      return (localX / timeScale) -
          (horizontalOffset * drawingWidth / timeScale);
    }

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    // ---------------------------
    // Eje Y dinámico
    // Calcula el dominio visible (vertical)
    final yDomainTop = screenToDomainY(_offsetY);
    final yDomainBottom = screenToDomainY(size.height - _sqrOffsetBot);
    final yMin = min(yDomainTop, yDomainBottom);
    final yMax = max(yDomainTop, yDomainBottom);

    // Dividir en ~10 líneas
    const linesCountY = 10;
    final stepY = (yMax - yMin) / linesCountY;

    for (int i = 0; i <= linesCountY; i++) {
      final domainVal = yMin + i * stepY;
      final y = domainToScreenY(domainVal);

      // Línea horizontal
      canvas.drawLine(
        Offset(_offsetX, y),
        Offset(size.width, y),
        gridPaint,
      );

      // Etiqueta a la izquierda
      final label = domainVal.toStringAsFixed(2);
      textPainter.text = TextSpan(
        text: '$label V',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(5, y - textPainter.height / 2),
      );
    }

    // Línea de cero en rojo
    final zeroY = domainToScreenY(0.0);
    // Ajustar para no dibujar fuera del cuadro
    final clampedZeroY = zeroY.clamp(_offsetY, size.height - _sqrOffsetBot);
    canvas.drawLine(
      Offset(_offsetX, clampedZeroY),
      Offset(size.width, clampedZeroY),
      zeroPaint,
    );

    // ---------------------------
    // Eje X dinámico
    // Calcula el dominio visible (horizontal)
    final xDomainLeft = screenToDomainX(_offsetX);
    final xDomainRight = screenToDomainX(size.width);
    final xMin = min(xDomainLeft, xDomainRight);
    final xMax = max(xDomainLeft, xDomainRight);

    // Dividir en ~10 líneas
    const linesCountX = 10;
    final stepX = (xMax - xMin) / linesCountX;

    for (int i = 0; i <= linesCountX; i++) {
      final domainVal = xMin + i * stepX;
      final x = domainToScreenX(domainVal);

      // Línea vertical
      canvas.drawLine(
        Offset(x, _offsetY),
        Offset(x, size.height - _sqrOffsetBot),
        gridPaint,
      );

      // Etiqueta de tiempo en µs
      final timeValue = domainVal * 1e6;
      textPainter.text = TextSpan(
        text: '${timeValue.toStringAsFixed(1)} µs',
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(
          x - textPainter.width / 2,
          size.height - _sqrOffsetBot + 5,
        ),
      );
    }

    // ---------------------------
    // Dibuja la señal
    if (dataPoints.length > 1) {
      for (int i = 0; i < dataPoints.length - 1; i++) {
        var p1 = Offset(
          domainToScreenX(dataPoints[i].x),
          domainToScreenY(dataPoints[i].y),
        );
        var p2 = Offset(
          domainToScreenX(dataPoints[i + 1].x),
          domainToScreenY(dataPoints[i + 1].y),
        );

        // Si alguna coordenada es NaN o infinita, omitimos el trazado
        if (!p1.dx.isFinite ||
            !p1.dy.isFinite ||
            !p2.dx.isFinite ||
            !p2.dy.isFinite) {
          continue;
        }

        // Recortes (clipping) vertical
        if (p1.dy < _offsetY && p2.dy < _offsetY) continue;
        if (p1.dy > size.height - _sqrOffsetBot &&
            p2.dy > size.height - _sqrOffsetBot) continue;
        // Recortes horizontal
        if (p1.dx < _offsetX && p2.dx < _offsetX) continue;
        if (p1.dx > size.width && p2.dx > size.width) continue;

        // Clip vertical en p1
        if (p1.dy < _offsetY) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newX = p1.dx + (_offsetY - p1.dy) / slope;
          p1 = Offset(newX, _offsetY);
        } else if (p1.dy > size.height - _sqrOffsetBot) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newX = p1.dx + (size.height - _sqrOffsetBot - p1.dy) / slope;
          p1 = Offset(newX, size.height - _sqrOffsetBot);
        }
        // Clip vertical en p2
        if (p2.dy < _offsetY) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newX = p2.dx + (_offsetY - p2.dy) / slope;
          p2 = Offset(newX, _offsetY);
        } else if (p2.dy > size.height - _sqrOffsetBot) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newX = p2.dx + (size.height - _sqrOffsetBot - p2.dy) / slope;
          p2 = Offset(newX, size.height - _sqrOffsetBot);
        }
        // Clip horizontal en p1
        if (p1.dx < _offsetX) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newY = p1.dy + (_offsetX - p1.dx) * slope;
          p1 = Offset(_offsetX, newY);
        } else if (p1.dx > size.width) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newY = p1.dy + (size.width - p1.dx) * slope;
          p1 = Offset(size.width, newY);
        }
        // Clip horizontal en p2
        if (p2.dx < _offsetX) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newY = p2.dy + (_offsetX - p2.dx) * slope;
          p2 = Offset(_offsetX, newY);
        } else if (p2.dx > size.width) {
          final slope = (p2.dy - p1.dy) / (p2.dx - p1.dx);
          final newY = p2.dy + (size.width - p2.dx) * slope;
          p2 = Offset(size.width, newY);
        }

        canvas.drawLine(p1, p2, paint);
      }
    }

    // Borde
    canvas.drawRect(
      Rect.fromLTWH(_offsetX, _offsetY, drawingWidth, drawingHeight),
      borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
