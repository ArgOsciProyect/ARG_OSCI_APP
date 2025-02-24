import 'package:arg_osci_app/config/app_theme.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/unit_format.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const double _offsetX = 50;

/// [FFTChart] is a Flutter [StatelessWidget] that displays the FFT chart and its controls.
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

/// [_ChartArea] is a [StatelessWidget] that defines the chart area.
class _ChartArea extends StatelessWidget {
  late final FFTChartProvider fftChartProvider;

  _ChartArea() : fftChartProvider = Get.find<FFTChartProvider>();

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: AppTheme.getChartAreaColor(context),
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

/// [_ChartGestureHandler] handles user gestures such as scaling and panning on the chart.
class _ChartGestureHandler extends StatelessWidget {
  final FFTChartProvider fftChartProvider;
  final BoxConstraints constraints;

  const _ChartGestureHandler({
    required this.fftChartProvider,
    required this.constraints,
  });

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onScaleStart: (_) {
          fftChartProvider.setInitialScales();
          fftChartProvider.updateDrawingWidth(constraints.biggest, _offsetX);
        },
        onScaleUpdate: _handleScaleUpdate,
        child: Container(
          color: Colors.transparent,
          width: constraints.maxWidth,
          height: constraints.maxHeight,
          child: _ChartPainter(fftChartProvider: fftChartProvider),
        ),
      ),
    );
  }

  /// Handles mouse wheel events for zooming and panning.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind != PointerDeviceKind.mouse) return;

    final delta = event.scrollDelta.dy;
    final noModifier = !HardwareKeyboard.instance.isControlPressed &&
        !HardwareKeyboard.instance.isShiftPressed;
    final factor = 1 - (delta / 500);

    if (HardwareKeyboard.instance.isControlPressed) {
      fftChartProvider.setTimeScale(
        fftChartProvider.timeScale.value * factor,
      );
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      fftChartProvider.setValueScale(
        fftChartProvider.valueScale.value * factor,
      );
    } else if (noModifier) {
      fftChartProvider.zoomXY(factor);
    }
  }

  /// Handles scale update events for panning.
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    // Pan with one finger: use the horizontal delta to adjust horizontalOffset
    if (details.pointerCount == 1) {
      const sensitivity = 50;
      final dx = details.focalPointDelta.dx;
      final newOffset = fftChartProvider.horizontalOffset - (dx * sensitivity);
      fftChartProvider.setHorizontalOffset(newOffset);

      final dyNorm = details.focalPointDelta.dy / constraints.maxHeight;
      fftChartProvider
          .setVerticalOffset(fftChartProvider.verticalOffset - dyNorm);
    }
  }
}

/// [_ChartPainter] is a [StatelessWidget] that uses [CustomPaint] to draw the FFT chart.
class _ChartPainter extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _ChartPainter({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final fftPoints = fftChartProvider.fftPoints.value;
      if (fftPoints.isEmpty) {
        return Center(
            child: CircularProgressIndicator(
          color: AppTheme.getLoadingIndicatorColor(context),
        ));
      }

      return CustomPaint(
        painter: FFTChartPainter(
          fftPoints: fftPoints,
          timeScale: fftChartProvider.timeScale.value,
          valueScale: fftChartProvider.valueScale.value,
          horizontalOffset: fftChartProvider.horizontalOffset,
          verticalOffset: fftChartProvider.verticalOffset,
          fftChartProvider: fftChartProvider,
          context: context,
        ),
      );
    });
  }
}

/// [_PlayPauseButton] is a [StatelessWidget] that provides a play/pause toggle button for the FFT chart.
class _PlayPauseButton extends StatelessWidget {
  final FFTChartProvider fftChartProvider;

  const _PlayPauseButton({required this.fftChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() => IconButton(
          icon: Icon(
            fftChartProvider.isPaused ? Icons.play_arrow : Icons.pause,
          ),
          color: Theme.of(context).iconTheme.color,
          onPressed: () => fftChartProvider.isPaused
              ? fftChartProvider.resume()
              : fftChartProvider.pause(),
        ));
  }
}

/// [_ControlButton] is a reusable [StatelessWidget] for creating control buttons with tap and long press handling.
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
        color: Theme.of(context).iconTheme.color,
        onPressed: null,
      ),
    );
  }
}

/// [_AutosetButton] is a [StatelessWidget] that provides a button to auto-adjust FFT scales based on data.
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
      color: Theme.of(context).iconTheme.color,
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

/// [_OffsetControls] is a [StatelessWidget] that provides control buttons for adjusting the chart offset.
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

/// [_ControlPanel] is a [StatelessWidget] that groups all the control buttons for the FFT chart.
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
      color: AppTheme.getControlPanelColor(context),
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

/// [_ScaleButtons] is a [StatelessWidget] that provides scale adjustment buttons specific to the FFT chart.
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

/// [FFTChartPainter] is a [CustomPainter] that draws the FFT chart on the canvas.
class FFTChartPainter extends CustomPainter {
  final List<DataPoint> fftPoints;
  final double timeScale;
  final double valueScale;
  final double horizontalOffset;
  final double verticalOffset;
  final FFTChartProvider fftChartProvider;
  final BuildContext context; // Add this line

  FFTChartPainter({
    required this.fftPoints,
    required this.timeScale,
    required this.valueScale,
    required this.horizontalOffset,
    required this.verticalOffset,
    required this.fftChartProvider,
    required this.context, // Add this line
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (fftPoints.isEmpty) return;

    const double offsetY = 30;
    const double offsetX = 50;
    const double sqrOffsetBot = 30;

    // Define the chart area
    final chartArea = Rect.fromLTWH(
      offsetX,
      offsetY,
      size.width - offsetX - 10,
      size.height - offsetY - sqrOffsetBot,
    );

    final bgPaint = Paint()..color = AppTheme.getFFTBackgroundColor(context);
    final paint = AppTheme.getFFTDataPaint(context)
      ..style = PaintingStyle.stroke;

    final gridPaint = AppTheme.getFFTGridPaint(context);

    final borderPaint = AppTheme.getFFTBorderPaint(context);

    canvas.drawRect(chartArea, bgPaint);

    // Determine the minimum and maximum Y values in the FFT data
    double minY = double.infinity;
    double maxY = double.negativeInfinity;
    for (final point in fftPoints) {
      if (point.y < minY) minY = point.y;
      if (point.y > maxY) maxY = point.y;
    }

    // Calculate the center and range of Y values for scaling
    final centerY = (maxY + minY) / 2;
    final halfRange = ((maxY - minY) / 2) / valueScale;
    // Apply vertical offset and scaling to determine the minimum and maximum Y values
    final scaledMinY = centerY - halfRange - verticalOffset * halfRange * 2;
    final scaledMaxY = centerY + halfRange - verticalOffset * halfRange * 2;

    final textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );

    const xDivisions = 12;
    // Calculate the Nyquist frequency
    final nyquistFreq = fftChartProvider.samplingFrequency / 2;

    // The horizontalOffset is used directly to calculate the visible range
    final visibleStartFreq = fftChartProvider.horizontalOffset;
    final visibleEndFreq = visibleStartFreq + (nyquistFreq * timeScale);
    final freqStep = (visibleEndFreq - visibleStartFreq) / xDivisions;

    // Draw vertical lines and labels
    for (int i = 0; i <= xDivisions; i++) {
      final freq = visibleStartFreq + (i * freqStep);
      if (freq < 0 || freq > nyquistFreq) continue;

      // Calculate the X position based on the visible range
      final x = offsetX +
          ((freq - visibleStartFreq) / (nyquistFreq * timeScale)) *
              chartArea.width;

      if (x >= chartArea.left - 5 && x <= chartArea.right + 5) {
        // Draw vertical line
        canvas.drawLine(
          Offset(x, chartArea.top),
          Offset(x, chartArea.bottom),
          gridPaint,
        );

        // Draw frequency label
        textPainter.text = TextSpan(
          text: UnitFormat.formatWithUnit(freq, 'Hz'),
          style: TextStyle(
              color: AppTheme.getTextColor(context), fontSize: 8.5),
        );
        textPainter.layout();

        final textX = x - textPainter.width / 2;
        if (x >= chartArea.left - textPainter.width &&
            x <= chartArea.right + textPainter.width) {
          textPainter.paint(canvas, Offset(textX, chartArea.bottom + 2));
        }
      }
    }

    // Draw horizontal lines and labels
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
        style: TextStyle(color: AppTheme.getTextColor(context), fontSize: 9),
      );
      textPainter.layout();
      textPainter.paint(
        canvas,
        Offset(offsetX - textPainter.width - 5, y - textPainter.height / 2),
      );
    }

    final path = Path();
    bool firstPoint = true;
    canvas.save();
    canvas.clipRect(chartArea);

    // Draw the FFT data points
    for (final point in fftPoints) {
      if (point.x > nyquistFreq) break;

      // The same mapping is used for the points
      final xRatio = (point.x - visibleStartFreq) / (nyquistFreq * timeScale);
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

    // Draw the border
    canvas.drawRect(
      chartArea,
      borderPaint,
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