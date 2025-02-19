import 'dart:math';
import 'dart:ui';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/unit_format.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';

const double _offsetY = 15;
const double _offsetX = 50;
const double _sqrOffsetBot = 15;

/// [OsciloscopeChart] is a Flutter [StatelessWidget] that displays a line chart with zoom, pan, and scale controls.
/// It uses data from providers to plot real-time data.
class OsciloscopeChart extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;
  final DeviceConfigProvider deviceConfig;

  const OsciloscopeChart._({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
    required this.deviceConfig,
    super.key,
  });

  /// Factory constructor that creates an instance of [OsciloscopeChart] with dependencies injected using Get.
  factory OsciloscopeChart({Key? key}) {
    return OsciloscopeChart._(
      key: key,
      oscilloscopeChartProvider: Get.find<OscilloscopeChartProvider>(),
      graphProvider: Get.find<DataAcquisitionProvider>(),
      deviceConfig: Get.find<DeviceConfigProvider>(),
    );
  }

  @override
  Widget build(BuildContext context) {
    final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
    final graphProvider = Get.find<DataAcquisitionProvider>();

    return Column(
      children: [
        Expanded(
            child: _ChartArea(
          oscilloscopeChartProvider: oscilloscopeChartProvider,
          graphProvider: graphProvider,
          deviceConfig: deviceConfig,
        )),
        _ControlPanel(
          oscilloscopeChartProvider: oscilloscopeChartProvider,
          graphProvider: graphProvider,
        ),
      ],
    );
  }
}

/// [_PlayPauseButton] is a [StatelessWidget] that provides a play/pause toggle button for the oscilloscope chart.
class _PlayPauseButton extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;

  const _PlayPauseButton({required this.oscilloscopeChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() => IconButton(
          icon: Icon(
            oscilloscopeChartProvider.isPaused ? Icons.play_arrow : Icons.pause,
          ),
          color: Colors.black,
          onPressed: () => oscilloscopeChartProvider.isPaused
              ? oscilloscopeChartProvider.resume()
              : oscilloscopeChartProvider.pause(),
        ));
  }
}

/// [_ScaleButtons] is a [StatelessWidget] that provides scale adjustment buttons for time and voltage scales.
class _ScaleButtons extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;

  const _ScaleButtons({required this.oscilloscopeChartProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: Icons.remove,
          onTap: oscilloscopeChartProvider.decrementTimeScale,
          onLongPress: oscilloscopeChartProvider.decrementTimeScale,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.add,
          onTap: oscilloscopeChartProvider.incrementTimeScale,
          onLongPress: oscilloscopeChartProvider.incrementTimeScale,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_down,
          onTap: oscilloscopeChartProvider.decrementValueScale,
          onLongPress: oscilloscopeChartProvider.decrementValueScale,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_up,
          onTap: oscilloscopeChartProvider.incrementValueScale,
          onLongPress: oscilloscopeChartProvider.incrementValueScale,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
      ],
    );
  }
}

/// [_AutosetButton] is a [StatelessWidget] that provides a button to auto-adjust chart scales based on data.
class _AutosetButton extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;

  const _AutosetButton({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
  });

  @override
  Widget build(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.autorenew),
      color: Colors.black,
      onPressed: () {
        final size = MediaQuery.of(context).size;
        graphProvider.autoset(size.height, size.width);
        oscilloscopeChartProvider.resetOffsets();
      },
    );
  }
}

/// [_ChartArea] is the main chart area that displays the data plot and handles layout constraints.
class _ChartArea extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;
  final DeviceConfigProvider deviceConfig;

  const _ChartArea({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
    required this.deviceConfig,
  });

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        return Container(
          color: Theme.of(context).scaffoldBackgroundColor,
          child: SizedBox.fromSize(
            size: constraints.biggest,
            child: _ChartGestureHandler(
              oscilloscopeChartProvider: oscilloscopeChartProvider,
              graphProvider: graphProvider,
              deviceConfig: deviceConfig,
              constraints: constraints,
            ),
          ),
        );
      },
    );
  }
}

/// [_ChartGestureHandler] handles all gesture and pointer interactions for the chart, including zooming and panning.
class _ChartGestureHandler extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;
  final DeviceConfigProvider deviceConfig;
  final BoxConstraints constraints;

  const _ChartGestureHandler({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
    required this.deviceConfig,
    required this.constraints,
  });

  /// Handles mouse wheel events for zooming.
  void _handlePointerSignal(PointerSignalEvent event) {
    if (event is! PointerScrollEvent) return;
    if (event.kind != PointerDeviceKind.mouse) return;

    final delta = event.scrollDelta.dy;
    if (HardwareKeyboard.instance.isControlPressed) {
      // Horizontal zoom (time)
      oscilloscopeChartProvider.updateDrawingWidth(
          constraints.biggest, _offsetX);
      oscilloscopeChartProvider.setTimeScale(
        oscilloscopeChartProvider.timeScale * (1 - delta / 500),
      );
    } else if (HardwareKeyboard.instance.isShiftPressed) {
      // Vertical zoom (voltage)
      oscilloscopeChartProvider.updateDrawingWidth(
          constraints.biggest, _offsetX);
      oscilloscopeChartProvider.setValueScale(
        oscilloscopeChartProvider.valueScale * (1 - delta / 500),
      );
    } else {
      // Combined zoom
      oscilloscopeChartProvider.updateDrawingWidth(
          constraints.biggest, _offsetX);
      final scale = 1 - delta / 500;
      oscilloscopeChartProvider
          .setTimeScale(oscilloscopeChartProvider.timeScale * scale);
      oscilloscopeChartProvider
          .setValueScale(oscilloscopeChartProvider.valueScale * scale);
    }
  }

  /// Handles scale update events for zooming and panning.
  void _handleScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount == 2) {
      // Pinch zoom with bounds checking
      oscilloscopeChartProvider.updateDrawingWidth(
          constraints.biggest, _offsetX);
      oscilloscopeChartProvider.handleZoom(
        details,
        constraints.biggest,
        _offsetX,
      );
    } else if (details.pointerCount == 1) {
      // Pan with bounds checking
      oscilloscopeChartProvider.updateDrawingWidth(
          constraints.biggest, _offsetX);
      final newHorizontalOffset = oscilloscopeChartProvider.horizontalOffset +
          details.focalPointDelta.dx / constraints.maxWidth;

      oscilloscopeChartProvider.setHorizontalOffset(newHorizontalOffset);

      oscilloscopeChartProvider.setVerticalOffset(
        oscilloscopeChartProvider.verticalOffset -
            details.focalPointDelta.dy / constraints.maxHeight,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Listener(
      onPointerSignal: _handlePointerSignal,
      child: GestureDetector(
        onScaleStart: (_) => oscilloscopeChartProvider.setInitialScales(),
        onScaleUpdate: _handleScaleUpdate,
        child: _ChartPainter(
          oscilloscopeChartProvider: oscilloscopeChartProvider,
          graphProvider: graphProvider,
          deviceConfig: deviceConfig,
          context: context,
        ),
      ),
    );
  }
}

/// [_ChartPainter] handles the painting of the chart using [CustomPaint].
class _ChartPainter extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;
  final DeviceConfigProvider deviceConfig;
  final BuildContext context;

  const _ChartPainter({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
    required this.deviceConfig,
    required this.context,
  });

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final dataPoints = oscilloscopeChartProvider.dataPoints;
      if (dataPoints.isEmpty) {
        return const Center(child: Text('No data'));
      }

      return CustomPaint(
        painter: OscilloscopeChartPainter(
          dataPoints,
          oscilloscopeChartProvider.timeScale,
          oscilloscopeChartProvider.valueScale,
          graphProvider.getMaxValue(),
          graphProvider.getDistance(),
          graphProvider.getScale(),
          Theme.of(context).scaffoldBackgroundColor,
          oscilloscopeChartProvider.horizontalOffset,
          oscilloscopeChartProvider.verticalOffset,
          deviceConfig,
        ),
      );
    });
  }
}

/// [_ControlPanel] is the bottom control panel with all chart controls.
class _ControlPanel extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;

  const _ControlPanel({
    required this.oscilloscopeChartProvider,
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
            _MainControls(
              oscilloscopeChartProvider: oscilloscopeChartProvider,
              graphProvider: graphProvider,
            ),
            const SizedBox(width: 20),
            _OffsetControls(
                oscilloscopeChartProvider: oscilloscopeChartProvider),
          ],
        ),
      ),
    );
  }
}

/// [_MainControls] contains main control buttons for the line chart, including play/pause, zoom, and autoset.
class _MainControls extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;
  final DataAcquisitionProvider graphProvider;

  const _MainControls({
    required this.oscilloscopeChartProvider,
    required this.graphProvider,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _PlayPauseButton(oscilloscopeChartProvider: oscilloscopeChartProvider),
        _ScaleButtons(oscilloscopeChartProvider: oscilloscopeChartProvider),
        _AutosetButton(
          oscilloscopeChartProvider: oscilloscopeChartProvider,
          graphProvider: graphProvider,
        ),
      ],
    );
  }
}

/// [_OffsetControls] provides navigation controls for chart offset.
class _OffsetControls extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;

  const _OffsetControls({required this.oscilloscopeChartProvider});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        _ControlButton(
          icon: Icons.keyboard_arrow_left,
          onTap: oscilloscopeChartProvider.decrementHorizontalOffset,
          onLongPress: oscilloscopeChartProvider.decrementHorizontalOffset,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_right,
          onTap: oscilloscopeChartProvider.incrementHorizontalOffset,
          onLongPress: oscilloscopeChartProvider.incrementHorizontalOffset,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_up,
          onTap: oscilloscopeChartProvider.incrementVerticalOffset,
          onLongPress: oscilloscopeChartProvider.incrementVerticalOffset,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
        _ControlButton(
          icon: Icons.keyboard_arrow_down,
          onTap: oscilloscopeChartProvider.decrementVerticalOffset,
          onLongPress: oscilloscopeChartProvider.decrementVerticalOffset,
          oscilloscopeChartProvider: oscilloscopeChartProvider,
        ),
      ],
    );
  }
}

/// [_ControlButton] is a reusable control button with tap and long press handling.
class _ControlButton extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final OscilloscopeChartProvider oscilloscopeChartProvider;

  const _ControlButton({
    required this.icon,
    required this.onTap,
    required this.onLongPress,
    required this.oscilloscopeChartProvider,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => onTap(),
      onLongPress: () =>
          oscilloscopeChartProvider.startIncrementing(onLongPress),
      onLongPressUp: oscilloscopeChartProvider.stopIncrementing,
      child: IconButton(
        icon: Icon(icon),
        color: Colors.black,
        onPressed: null,
      ),
    );
  }
}

/// [OscilloscopeChartPainter] is a custom painter for rendering a line chart with grid lines, labels, and data points.
class OscilloscopeChartPainter extends CustomPainter {
  final List<DataPoint> dataPoints;
  final double timeScale;
  final double valueScale;
  final double maxX;
  final double distance;
  final double voltageScale;
  final Color backgroundColor;
  final double horizontalOffset;
  final double verticalOffset;
  final DeviceConfigProvider deviceConfig;

  late final Paint _dataPaint;
  late final Paint _gridPaint;
  late final Paint _zeroPaint;
  late final Paint _borderPaint;
  late final Paint _backgroundPaint;
  late final Paint _chartBackgroundPaint;
  late final TextPainter _textPainter;

  double _drawingWidth = 0.0;
  double _drawingHeight = 0.0;
  double _centerY = 0.0;

  OscilloscopeChartPainter(
    this.dataPoints,
    this.timeScale,
    this.valueScale,
    this.maxX,
    this.distance,
    this.voltageScale,
    this.backgroundColor,
    this.horizontalOffset,
    this.verticalOffset,
    this.deviceConfig,
  ) {
    _initializePaints();
  }

  /// Initializes all the paints used in the chart.
  void _initializePaints() {
    _dataPaint = Paint()
      ..color = Colors.blue
      ..strokeWidth = 2;

    _gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;

    _zeroPaint = Paint()
      ..color = Colors.red
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    _borderPaint = Paint()
      ..color = Colors.black
      ..strokeWidth = 1
      ..style = PaintingStyle.stroke;

    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;

    _chartBackgroundPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;

    _textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
    );
  }

  /// Converts a domain Y value to a screen Y value.
  double _domainToScreenY(double domainVal) {
    if (domainVal.isNaN || domainVal.isInfinite) return 0.0;
    return _centerY -
        ((domainVal * valueScale + verticalOffset) * _drawingHeight / 2);
  }

  /// Converts a screen Y value to a domain Y value.
  double _screenToDomainY(double screenVal) {
    return -((screenVal - _centerY) / (_drawingHeight / 2)) / valueScale -
        verticalOffset;
  }

  /// Converts a domain X value to a screen X value.
  double _domainToScreenX(double domainVal) {
    if (domainVal.isNaN || domainVal.isInfinite) return _offsetX;
    return (domainVal * timeScale) +
        (horizontalOffset * _drawingWidth) +
        _offsetX;
  }

  /// Converts a screen X value to a domain X value.
  double _screenToDomainX(double screenVal) {
    final localX = screenVal - _offsetX;
    return (localX / timeScale) -
        (horizontalOffset * _drawingWidth / timeScale);
  }

  /// Draws the background of the chart.
  void _drawBackground(Canvas canvas, Size size) {
    canvas.drawRect(
      Rect.fromLTWH(0, 0, size.width, _offsetY),
      _backgroundPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(0, _offsetY, _offsetX, size.height - _offsetY),
      _backgroundPaint,
    );
    canvas.drawRect(
      Rect.fromLTWH(_offsetX, _offsetY, _drawingWidth, _drawingHeight),
      _chartBackgroundPaint,
    );
  }

  /// Draws the Y-axis grid lines and labels.
  void _drawYAxisGridAndLabels(Canvas canvas, Size size) {
    try {
      final yDomainTop = _screenToDomainY(_offsetY);
      final yDomainBottom = _screenToDomainY(size.height - _sqrOffsetBot);
      final yMin = min(yDomainTop, yDomainBottom);
      final yMax = max(yDomainTop, yDomainBottom);

      if (yMin.isInfinite || yMax.isInfinite) return;

      const rangeExtensionFactor = 2.0;
      final yRange = yMax - yMin;
      if (yRange == 0) return;

      final extendedYMin = yMin - (yRange * (rangeExtensionFactor - 1) / 2);
      final extendedYMax = yMax + (yRange * (rangeExtensionFactor - 1) / 2);

      const linesCountY = 20;
      final stepY = (extendedYMax - extendedYMin) / linesCountY;
      if (stepY == 0) return;

      for (int i = 0; i <= linesCountY; i++) {
        final domainVal = extendedYMin + i * stepY;
        final y = _domainToScreenY(domainVal);

        if (y >= _offsetY && y <= size.height - _sqrOffsetBot) {
          canvas.drawLine(
            Offset(_offsetX, y),
            Offset(size.width, y),
            _gridPaint,
          );

          final formattedValue = UnitFormat.formatWithUnit(domainVal, 'V');
          _textPainter.text = TextSpan(
            text: formattedValue,
            style: const TextStyle(color: Colors.black, fontSize: 10),
          );
          _textPainter.layout();
          _textPainter.paint(
            canvas,
            Offset(5, y - _textPainter.height / 2),
          );
        }
      }
    } catch (e) {
      // Handle or log error if needed
      return;
    }
  }

  /// Draws the X-axis grid lines and labels.
  void _drawXAxisGridAndLabels(Canvas canvas, Size size) {
    final xDomainLeft = _screenToDomainX(_offsetX);
    final xDomainRight = _screenToDomainX(size.width);
    final xMin = min(xDomainLeft, xDomainRight);
    final xMax = max(xDomainLeft, xDomainRight);

    const linesCountX = 15;
    final stepX = (xMax - xMin) / linesCountX;

    for (int i = 0; i <= linesCountX; i++) {
      final domainVal = xMin + i * stepX;
      final x = _domainToScreenX(domainVal);

      canvas.drawLine(
        Offset(x, _offsetY),
        Offset(x, size.height - _sqrOffsetBot),
        _gridPaint,
      );

      final timeValue = domainVal;
      _textPainter.text = TextSpan(
        text: UnitFormat.formatWithUnit(timeValue, 's'),
        style: const TextStyle(color: Colors.black, fontSize: 10),
      );
      _textPainter.layout();
      _textPainter.paint(
        canvas,
        Offset(x - _textPainter.width / 2, size.height - _sqrOffsetBot + 5),
      );
    }
  }

  /// Draws the zero line on the chart.
  void _drawZeroLine(Canvas canvas, Size size) {
    final zeroY = _domainToScreenY(0.0);
    final clampedZeroY = zeroY.clamp(_offsetY, size.height - _sqrOffsetBot);
    canvas.drawLine(
      Offset(_offsetX, clampedZeroY),
      Offset(size.width, clampedZeroY),
      _zeroPaint,
    );
  }

  /// Draws the data points on the chart.
  void _drawDataPoints(Canvas canvas, Size size) {
    if (dataPoints.length <= 1) return;

    for (int i = 0; i < dataPoints.length - 1; i++) {
      final x1 = _domainToScreenX(dataPoints[i].x);
      final y1 = _domainToScreenY(dataPoints[i].y);
      final x2 = _domainToScreenX(dataPoints[i + 1].x);
      final y2 = _domainToScreenY(dataPoints[i + 1].y);

      // Skip if any coordinate is NaN or infinite
      if (x1.isNaN ||
          y1.isNaN ||
          x2.isNaN ||
          y2.isNaN ||
          x1.isInfinite ||
          y1.isInfinite ||
          x2.isInfinite ||
          y2.isInfinite) {
        continue;
      }

      var p1 = Offset(x1, y1);
      var p2 = Offset(x2, y2);

      if (!_isLineVisible(p1, p2, size)) continue;

      p1 = _clipPoint(p1, p2, size);
      p2 = _clipPoint(p2, p1, size);

      // Final validation before drawing
      if (p1.dx.isFinite &&
          p1.dy.isFinite &&
          p2.dx.isFinite &&
          p2.dy.isFinite) {
        canvas.drawLine(p1, p2, _dataPaint);
      }
    }
  }

  /// Checks if a line is visible on the chart.
  bool _isLineVisible(Offset p1, Offset p2, Size size) {
    if (p1.dy < _offsetY && p2.dy < _offsetY) return false;
    if (p1.dy > size.height - _sqrOffsetBot &&
        p2.dy > size.height - _sqrOffsetBot) {
      return false;
    }
    if (p1.dx < _offsetX && p2.dx < _offsetX) return false;
    if (p1.dx > size.width && p2.dx > size.width) return false;
    return true;
  }

  /// Clips a point to the chart boundaries.
  Offset _clipPoint(Offset point, Offset other, Size size) {
    if (point.dx.isNaN || point.dy.isNaN || other.dx.isNaN || other.dy.isNaN) {
      return Offset(_offsetX, _centerY);
    }

    var result = point;
    if (other.dx == point.dx) return result; // Prevent division by zero

    final slope = (other.dy - point.dy) / (other.dx - point.dx);
    if (slope.isNaN || slope.isInfinite) return result;

    // Vertical clipping
    if (point.dy < _offsetY) {
      final newX = point.dx + (_offsetY - point.dy) / slope;
      result = Offset(newX, _offsetY);
    } else if (point.dy > size.height - _sqrOffsetBot) {
      final newX = point.dx + (size.height - _sqrOffsetBot - point.dy) / slope;
      result = Offset(newX, size.height - _sqrOffsetBot);
    }

    // Horizontal clipping
    if (point.dx < _offsetX) {
      final newY = point.dy + (_offsetX - point.dx) * slope;
      result = Offset(_offsetX, newY);
    } else if (point.dx > size.width) {
      final newY = point.dy + (size.width - point.dx) * slope;
      result = Offset(size.width, newY);
    }

    return result;
  }

  @override
  void paint(Canvas canvas, Size size) {
    _drawingWidth = size.width - _offsetX;
    _drawingHeight = size.height - _offsetY - _sqrOffsetBot;
    _centerY = _offsetY + _drawingHeight / 2;

    _drawBackground(canvas, size);
    _drawYAxisGridAndLabels(canvas, size);
    _drawXAxisGridAndLabels(canvas, size);
    _drawZeroLine(canvas, size);
    _drawDataPoints(canvas, size);

    canvas.drawRect(
      Rect.fromLTWH(_offsetX, _offsetY, _drawingWidth, _drawingHeight),
      _borderPaint,
    );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}
