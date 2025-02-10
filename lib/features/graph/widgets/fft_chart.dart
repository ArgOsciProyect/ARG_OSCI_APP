import 'dart:math';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/unit_formats.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const double _offsetX = 50;

class FFTChart extends StatelessWidget {
  const FFTChart({super.key});

  @override
  Widget build(BuildContext context) {
    final fftChartProvider = Get.find<FFTChartProvider>();
    final graphProvider = Get.find<DataAcquisitionProvider>();

    return Column(
      children: [
        Expanded(child: _ChartArea()),
        _ControlPanel(
          fftChartProvider: fftChartProvider,
          graphProvider: graphProvider,
        ),
      ],
    );
  }
}

/// The main chart area that displays the FFT plot
class _ChartArea extends StatelessWidget {
  late final FFTChartProvider fftChartProvider;

  _ChartArea() : fftChartProvider = Get.find<FFTChartProvider>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox.fromSize(
            size: constraints.biggest,
            child: _ChartGestureHandler(
              fftChartProvider: fftChartProvider,
              constraints: constraints,
            ),
          ),
        );
      },
    );
  }
}

/// Handles zoom gestures for the FFT chart
class _ChartGestureHandler extends StatelessWidget {
  final FFTChartProvider fftChartProvider;
  final BoxConstraints constraints;

  const _ChartGestureHandler({
    required this.fftChartProvider,
    required this.constraints,
  });

  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 2) {
      // Only vertical zoom for pinch gesture
      final newScale = pow(details.scale, 2.0);
      fftChartProvider.setValueScale(
        fftChartProvider.initialValueScale * newScale,
      );
    } else if (details.pointerCount == 1) {
      // Update drawing width before handling pan
      fftChartProvider.updateDrawingWidth(constraints.biggest, _offsetX);

      // Pan with corrected vertical direction
      final newHorizontalOffset = fftChartProvider.horizontalOffset +
          details.focalPointDelta.dx / constraints.maxWidth;

      fftChartProvider.setHorizontalOffset(newHorizontalOffset);

      // Corrected vertical direction (negative for upward movement)
      fftChartProvider.setVerticalOffset(
        fftChartProvider.verticalOffset -
            details.focalPointDelta.dy / constraints.maxHeight,
      );
    }
  }

  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind != PointerDeviceKind.mouse) return;

    final delta = event.scrollDelta.dy;

    if (HardwareKeyboard.instance.isControlPressed) {
      fftChartProvider.setTimeScale(
        fftChartProvider.timeScale.value * (1 - delta / 500),
      );
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      fftChartProvider.setValueScale(
        fftChartProvider.valueScale.value * (1 - delta / 500),
      );
    } else {
      final scale = 1 - delta / 500;
      fftChartProvider.setValueScale(
        fftChartProvider.valueScale.value * scale,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onScaleStart: (_) => fftChartProvider.setInitialScales(),
        onScaleUpdate: _handleScaleUpdate,
        child: _ChartPainter(
          fftChartProvider: fftChartProvider,
        ),
      ),
    );
  }
}

/// Handles the actual painting using CustomPaint
class _ChartPainter extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _ChartPainter({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fftPoints = fftChartProvider.fftPoints.value;
      if (fftPoints.isEmpty) {
        return const Center(child: Text('No data'));
      }

      return CustomPaint(
        painter: FFTChartPainter(
          fftPoints: fftPoints,
          timeScale: fftChartProvider.timeScale.value,
          valueScale: fftChartProvider.valueScale.value,
          horizontalOffset: fftChartProvider.horizontalOffset,
          verticalOffset: fftChartProvider.verticalOffset,
          fftChartProvider: fftChartProvider,
        ),
      );
    });
  }
}

/// Play/Pause toggle button for FFT chart
class _PlayPauseButton extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _PlayPauseButton({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() => IconButton(
          icon: Icon(
            fftChartProvider.isPaused ? Icons.play_arrow : Icons.pause,
          ),
          color: Colors.black,
          onPressed: () => fftChartProvider.isPaused
              ? fftChartProvider.resume()
              : fftChartProvider.pause(),
        ));
  }
}

/// Reusable control button with tap and long press handling
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final FFTChartProvider provider;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
    required this.provider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      onLongPress: () => provider.startIncrementing(onLongPress),
      onLongPressUp: provider.stopIncrementing,
      child: IconButton(
        icon: Icon(icon),
        color: Colors.black,
        onPressed: null,
      ),
    );
  }
}

/// Auto-adjust button to optimize FFT scales based on data
class _AutosetButton extends StatelessWidget {
  final FFTChartProvider fftChartProvider;
  final DataAcquisitionProvider graphProvider;

  const _AutosetButton({
    required this.fftChartProvider,
    required this.graphProvider,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.autorenew),
      color: Colors.black,
      onPressed: () {
        final size = MediaQuery.of(context).size;
        final fftFrequency = fftChartProvider.frequency.value;
        // Use FFT frequency, fallback to graph provider if 0
        final freqToUse =
            fftFrequency > 0 ? fftFrequency : graphProvider.frequency.value;
        fftChartProvider.autoset(size, freqToUse);
      },
    );
  }
}

class _OffsetControls extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _OffsetControls({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: Icons.keyboard_arrow_left,
          onTap: fftChartProvider.decrementHorizontalOffset,
          onLongPress: fftChartProvider.decrementHorizontalOffset,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_right,
          onTap: fftChartProvider.incrementHorizontalOffset,
          onLongPress: fftChartProvider.incrementHorizontalOffset,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_up,
          onTap: fftChartProvider.incrementVerticalOffset,
          onLongPress: fftChartProvider.incrementVerticalOffset,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_down,
          onTap: fftChartProvider.decrementVerticalOffset,
          onLongPress: fftChartProvider.decrementVerticalOffset,
          provider: fftChartProvider,
        ),
      ],
    );
  }
}

class _ControlPanel extends StatelessWidget {
  final FFTChartProvider fftChartProvider;
  final DataAcquisitionProvider graphProvider;

  const _ControlPanel({
    required this.fftChartProvider,
    required this.graphProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      color: Theme.of(context).scaffoldBackgroundColor,
      constraints: const BoxConstraints(maxHeight: 48.0),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _PlayPauseButton(fftChartProvider: fftChartProvider),
            _ScaleButtons(fftChartProvider: fftChartProvider),
            _AutosetButton(
              fftChartProvider: fftChartProvider,
              graphProvider: graphProvider,
            ),
            const SizedBox(width: 20),
            _OffsetControls(fftChartProvider: fftChartProvider),
          ],
        ),
      ),
    );
  }
}

/// Scale adjustment buttons specific to FFT
class _ScaleButtons extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _ScaleButtons({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: Icons.remove,
          onTap: fftChartProvider.decrementTimeScale,
          onLongPress: fftChartProvider.decrementTimeScale,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.add,
          onTap: fftChartProvider.incrementTimeScale,
          onLongPress: fftChartProvider.incrementTimeScale,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_down,
          onTap: fftChartProvider.decrementValueScale,
          onLongPress: fftChartProvider.decrementValueScale,
          provider: fftChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_up,
          onTap: fftChartProvider.incrementValueScale,
          onLongPress: fftChartProvider.incrementValueScale,
          provider: fftChartProvider,
        ),
      ],
    );
  }
}

class FFTChartPainter extends CustomPainter {
  final List<DataPoint> fftPoints;
  final double timeScale;
  final double valueScale;
  final double horizontalOffset;
  final double verticalOffset;
  final FFTChartProvider fftChartProvider;

  FFTChartPainter({
    required this.fftPoints,
    required this.timeScale,
    required this.valueScale,
    required this.horizontalOffset,
    required this.verticalOffset,
    required this.fftChartProvider,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fftPoints.isEmpty) return;

    const double offsetY = 30;
    const double offsetX = 50;
    const double sqrOffsetBot = 30;

    final chartArea = Rect.fromLTWH(
      offsetX,
      offsetY,
      size.width - offsetX - 10,
      size.height - offsetY - sqrOffsetBot,
    );

    final bgPaint = Paint()..color = Colors.white;
    final paint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2
      ..style = PaintingStyle.stroke;

    final gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    canvas.drawRect(chartArea, bgPaint);

    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final point in fftPoints) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    final centerY = (maxY + minY) / 2;
    final halfRange = ((maxY - minY) / 2) / valueScale;
    final scaledMinY = centerY - halfRange - verticalOffset * halfRange * 2;
    final scaledMaxY = centerY + halfRange - verticalOffset * halfRange * 2;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    const xDivisions = 12;
    final nyquistFreq = fftChartProvider.samplingFrequency / 2;
    final effectiveHorizontalOffset = horizontalOffset.clamp(-1.0, 0.0);

    // Dibujamos líneas de la grilla y etiquetas
    for (int i = 0; i <= xDivisions; i++) {
      final rawFreq = (i / xDivisions) * nyquistFreq;
      final xRatio =
          (rawFreq / (nyquistFreq * timeScale)) + effectiveHorizontalOffset;
      final scaledX = xRatio * chartArea.width;
      final x = offsetX + scaledX;

      if (rawFreq <= nyquistFreq) {
        // Dibujamos la línea vertical
        if (x >= chartArea.left - 5 && x <= chartArea.right + 5) {
          canvas.drawLine(
            Offset(x, chartArea.top),
            Offset(x, chartArea.bottom),
            gridPaint,
          );

          // Preparamos la etiqueta
          textPainter.text = TextSpan(
            text: UnitFormat.formatWithUnit(rawFreq, 'Hz'),
            style: const TextStyle(color: Colors.black, fontSize: 8.5),
          );
          textPainter.layout();

          final textX = x - textPainter.width / 2;
          // Dibujamos la etiqueta incluso si está parcialmente fuera, pero no más allá del área del gráfico
          if (x >= chartArea.left - textPainter.width &&
              x <= chartArea.right + textPainter.width) {
            textPainter.paint(
              canvas,
              Offset(textX, chartArea.bottom + 5),
            );
          }
        }
      }
    }

    // Dibujamos las líneas horizontales y etiquetas
    const yDivisions = 10;
    final yRange = scaledMaxY - scaledMinY;
    for (int i = 0; i <= yDivisions; i++) {
      final ratio = i / yDivisions;
      final y = chartArea.top + chartArea.height * ratio;
      final yValue = scaledMaxY - ratio * yRange;

      canvas.drawLine(
        Offset(offsetX, y),
        Offset(chartArea.right, y),
        gridPaint,
      );

      textPainter.text = TextSpan(
        text: "${yValue.toStringAsFixed(1)} dBV",
        style: const TextStyle(color: Colors.black, fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(offsetX - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    // Dibujamos los puntos de datos
    final path = Path();
    bool firstPoint = true;
    canvas.save();
    canvas.clipRect(chartArea);

    for (final point in fftPoints) {
      if (point.x > nyquistFreq) break;

      final xRatio =
          (point.x.clamp(0.0, nyquistFreq) / (nyquistFreq * timeScale)) +
              effectiveHorizontalOffset;
      final sx = offsetX + (xRatio * chartArea.width);

      final normalizedY = (point.y - scaledMinY) / (scaledMaxY - scaledMinY);
      final sy = offsetY + chartArea.height * (1 - normalizedY);

      if (firstPoint) {
        path.moveTo(sx, sy);
        firstPoint = false;
      } else {
        path.lineTo(sx, sy);
      }
    }

    canvas.drawPath(path, paint);
    canvas.restore();

    // Dibujamos el borde
    canvas.drawRect(
      chartArea,
      Paint()
        ..color = Colors.black
        ..strokeWidth = 1
        ..style = PaintingStyle.stroke,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) {
    if (oldDelegate is FFTChartPainter) {
      return oldDelegate.fftPoints != fftPoints ||
          oldDelegate.timeScale != timeScale ||
          oldDelegate.valueScale != valueScale ||
          oldDelegate.horizontalOffset != horizontalOffset ||
          oldDelegate.verticalOffset != verticalOffset;
    }
    return true;
  }
}
