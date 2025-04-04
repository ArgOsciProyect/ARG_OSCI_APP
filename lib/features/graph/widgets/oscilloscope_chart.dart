import 'dart:math';
import 'dart:ui';
import 'package:arg_osci_app/config/app_theme.dart';
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

/// [OsciloscopeChart] is a Flutter [StatelessWidget] that displays a time-domain waveform chart with zoom, pan, and scale controls.
/// It uses data from providers to plot real-time oscilloscope data.
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
///
/// Toggles between data acquisition and pause states for the oscilloscope display.
class _PlayPauseButton extends StatelessWidget {
  final OscilloscopeChartProvider oscilloscopeChartProvider;

  const _PlayPauseButton({required this.oscilloscopeChartProvider});

  @override
  Widget build(BuildContext context) {
    return Obx(() => IconButton(
          icon: Icon(
            oscilloscopeChartProvider.isPaused ? Icons.play_arrow : Icons.pause,
          ),
          color: Theme.of(context).iconTheme.color,
          onPressed: () => oscilloscopeChartProvider.isPaused
              ? oscilloscopeChartProvider.resume()
              : oscilloscopeChartProvider.pause(),
        ));
  }
}

/// [_ScaleButtons] is a [StatelessWidget] that provides scale adjustment buttons for time and voltage scales.
///
/// Presents controls for adjusting both horizontal (time) and vertical (voltage) scales.
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
///
/// Automatically configures the display to optimally show the captured waveform with proper scaling.
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
      color: Theme.of(context).iconTheme.color,
      onPressed: () {
        final size = MediaQuery.of(context).size;
        oscilloscopeChartProvider.autoset(size.height, size.width);
      },
    );
  }
}

/// [_ChartArea] is the main chart area that displays the data plot and handles layout constraints.
///
/// Creates a container for the oscilloscope display with appropriate sizing and background.
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
          color: AppTheme.getChartAreaColor(context),
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
///
/// Processes touch and mouse input to enable interactive zoom and pan operations on the oscilloscope display.
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
  ///
  /// Processes scroll wheel input with modifier keys to perform different zoom operations:
  /// - Ctrl+Scroll: Adjust horizontal (time) zoom
  /// - Shift+Scroll: Adjust vertical (voltage) zoom
  /// - Scroll alone: Adjust both axes simultaneously
  ///
  /// [event] The pointer signal event containing scroll information
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
  ///
  /// Processes touch gestures to zoom and pan the chart view:
  /// - Two-finger pinch: Zoom in/out while maintaining focal point
  /// - One-finger drag: Pan horizontally and vertically
  ///
  /// [details] Scale update details from the gesture detector
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
///
/// Observes the oscilloscope data stream and renders the appropriate visualization.
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
          graphProvider.maxValue.value,
          graphProvider.distance.value,
          graphProvider.scale.value,
          Theme.of(context).scaffoldBackgroundColor,
          oscilloscopeChartProvider.horizontalOffset,
          oscilloscopeChartProvider.verticalOffset,
          deviceConfig,
          context,
        ),
      );
    });
  }
}

/// [_ControlPanel] is the bottom control panel with all chart controls.
///
/// Provides a horizontal toolbar with all available chart controls in a scrollable container.
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
      color: AppTheme.getControlPanelColor(context),
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

/// [_MainControls] contains main control buttons for the oscilloscope chart, including play/pause, zoom, and autoset.
///
/// Groups primary control functions for convenient access in the control panel.
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
///
/// Presents navigation controls for panning the chart view in all directions.
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
///
/// Provides consistent button behavior for immediate action on tap and continuous action on long press.
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
        color: Theme.of(context).iconTheme.color,
        onPressed: null,
      ),
    );
  }
}

/// [OscilloscopeChartPainter] is a custom painter for rendering a waveform chart with grid lines, labels, and data points.
///
/// Renders the time-domain waveform with grid lines, axes labels, and data visualization.
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
  final BuildContext context;

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
    this.context,
  ) {
    _initializePaints();
  }

  /// Initializes all the paints used in the chart.
  void _initializePaints() {
    _dataPaint = AppTheme.getDataPaint(context);
    _gridPaint = Paint()
      ..color = Colors.grey
      ..strokeWidth = 0.5;
    _zeroPaint = AppTheme.getZeroPaint(context);
    _borderPaint = AppTheme.getBorderPaint(context);
    _backgroundPaint = Paint()
      ..color = backgroundColor
      ..style = PaintingStyle.fill;
    _chartBackgroundPaint = AppTheme.getChartBackgroundPaint(context);

    final isDark = Theme.of(context).brightness == Brightness.dark;

    _textPainter = TextPainter(
      textAlign: TextAlign.center,
      textDirection: TextDirection.ltr,
      text: TextSpan(
        style: TextStyle(
          color: isDark ? Colors.white : Colors.black,
          fontSize: 10,
        ),
      ),
    );
  }

  /// Converts a domain Y value (voltage) to a screen Y coordinate.
  ///
  /// [domainVal] Voltage value to convert
  /// Returns corresponding Y position on screen in pixels
  double _domainToScreenY(double domainVal) {
    if (domainVal.isNaN || domainVal.isInfinite) return 0.0;
    return _centerY -
        ((domainVal * valueScale + verticalOffset) * _drawingHeight / 2);
  }

  /// Converts a domain X value (time) to a screen X coordinate.
  ///
  /// [domainVal] Time value to convert
  /// Returns corresponding X position on screen in pixels
  double _domainToScreenX(double domainVal) {
    if (domainVal.isNaN || domainVal.isInfinite) return _offsetX;
    return (domainVal * timeScale) +
        (horizontalOffset * _drawingWidth) +
        _offsetX;
  }

  /// Converts a screen X coordinate to a domain X value (time).
  ///
  /// [screenVal] X position on screen in pixels
  /// Returns corresponding time value
  double _screenToDomainX(double screenVal) {
    final localX = screenVal - _offsetX;
    return (localX / timeScale) -
        (horizontalOffset * _drawingWidth / timeScale);
  }

  /// Draws the background of the chart including axes areas.
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
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

  /// Draws the Y-axis grid lines and labels (voltage scale).
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
  void _drawYAxisGridAndLabels(Canvas canvas, Size size) {
    const factor = 9;
    final suggestedStep = (1 / valueScale) / factor;
    if (suggestedStep <= 0) return;

    double baseVal = 0.0;
    double valUp = baseVal;
    while (true) {
      final y = _domainToScreenY(valUp);
      if (y < _offsetY) break;
      if (y <= size.height - _sqrOffsetBot) {
        _drawHorizontalLineAndLabel(canvas, size, valUp, y);
      }
      valUp += suggestedStep;
    }

    double valDown = baseVal - suggestedStep;
    while (true) {
      final y = _domainToScreenY(valDown);
      if (y > size.height - _sqrOffsetBot) break;
      if (y >= _offsetY) {
        _drawHorizontalLineAndLabel(canvas, size, valDown, y);
      }
      valDown -= suggestedStep;
    }
  }

  /// Draws a horizontal grid line and its corresponding voltage label.
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
  /// [val] Voltage value for this grid line
  /// [y] Y-coordinate for this grid line
  void _drawHorizontalLineAndLabel(
      Canvas canvas, Size size, double val, double y) {
    canvas.drawLine(Offset(_offsetX, y), Offset(size.width, y), _gridPaint);
    _textPainter.text = TextSpan(
      text: UnitFormat.formatWithUnit(val, 'V'),
      style: TextStyle(
        color: Theme.of(context).textTheme.bodyLarge?.color,
        fontSize: 10,
      ),
    );
    _textPainter.layout();
    _textPainter.paint(canvas, Offset(5, y - _textPainter.height / 2));
  }

  /// Draws the X-axis grid lines and labels (time scale).
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
  void _drawXAxisGridAndLabels(Canvas canvas, Size size) {
    final xDomainLeft = _screenToDomainX(_offsetX);
    final xDomainRight = _screenToDomainX(size.width);
    final xMin = min(xDomainLeft, xDomainRight);
    final xMax = max(xDomainLeft, xDomainRight);

    const linesCountX = 12;
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
        style: TextStyle(
            color: Theme.of(context).textTheme.bodyLarge?.color, fontSize: 10),
      );
      _textPainter.layout();
      _textPainter.paint(
        canvas,
        Offset(x - _textPainter.width / 2, size.height - _sqrOffsetBot + 5),
      );
    }
  }

  /// Draws the zero voltage reference line on the chart.
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
  void _drawZeroLine(Canvas canvas, Size size) {
    final zeroY = _domainToScreenY(0.0);
    final clampedZeroY = zeroY.clamp(_offsetY, size.height - _sqrOffsetBot);
    canvas.drawLine(
      Offset(_offsetX, clampedZeroY),
      Offset(size.width, clampedZeroY),
      _zeroPaint,
    );
  }

  /// Draws the waveform data points on the chart.
  ///
  /// [canvas] Canvas to draw on
  /// [size] Size of the drawing area
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

  /// Checks if a line segment is visible within the chart area.
  ///
  /// [p1] First endpoint of the line
  /// [p2] Second endpoint of the line
  /// [size] Size of the drawing area
  /// Returns true if at least part of the line should be visible
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
  ///
  /// Ensures line segments are properly clipped to the visible chart area
  /// using the Cohen-Sutherland line clipping algorithm approach.
  ///
  /// [point] Point to clip
  /// [other] The other endpoint of the line segment
  /// [size] Size of the drawing area
  /// Returns the clipped point
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
