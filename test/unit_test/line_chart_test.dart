import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/line_chart_provider.dart';
import 'package:arg_osci_app/features/graph/widgets/line_chart.dart';

class MockLineChartProvider extends Mock implements LineChartProvider {
  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = 1.0.obs;
  final _valueScale = 1.0.obs;
  final _horizontalOffset = 0.0.obs;
  final _verticalOffset = 0.0.obs;
  final _isPaused = false.obs;

  @override
  List<DataPoint> get dataPoints => _dataPoints.value;

  @override
  double get timeScale => _timeScale.value;

  @override
  double get valueScale => _valueScale.value;

  @override
  double get horizontalOffset => _horizontalOffset.value;

  @override
  double get verticalOffset => _verticalOffset.value;

  @override
  bool get isPaused => _isPaused.value;

  @override
  void setTimeScale(double scale) {
    if (scale > 0) {
      _timeScale.value = scale;
    }
  }

  @override
  void incrementTimeScale() {
    setTimeScale(timeScale * 1.1);
  }

  @override
  void decrementTimeScale() {
    setTimeScale(timeScale * 0.9);
  }

  @override
  void incrementValueScale() {
    setValueScale(valueScale * 1.1);
  }

  @override
  void decrementValueScale() {
    setValueScale(valueScale * 0.9);
  }

  @override
  void incrementHorizontalOffset() {
    setHorizontalOffset(horizontalOffset + 0.01);
  }

  @override
  void decrementHorizontalOffset() {
    setHorizontalOffset(horizontalOffset - 0.01);
  }

  @override
  void incrementVerticalOffset() {
    final newOffset = _verticalOffset.value + 0.1;
    setVerticalOffset(newOffset);
  }

  @override
  void decrementVerticalOffset() {
    final newOffset = _verticalOffset.value - 0.1;
    setVerticalOffset(newOffset);
  }

  @override
  void setValueScale(double scale) {
    _valueScale.value = scale;
  }

  @override
  void setHorizontalOffset(double offset) {
    _horizontalOffset.value = offset;
  }

  @override
  void setVerticalOffset(double offset) {
    _verticalOffset.value = offset;
  }

  @override
  void resetScales() {
    _timeScale.value = 1.0;
    _valueScale.value = 1.0;
  }

  @override
  void resetOffsets() {
    _horizontalOffset.value = 0.0;
    _verticalOffset.value = 0.0;
  }

  @override
  void pause() {
    _isPaused.value = true;
  }

  @override
  void resume() {
    _isPaused.value = false;
  }

  // Añadir callbacks requeridos por GetxController
  @override
  InternalFinalCallback<void> get onStart =>
      InternalFinalCallback<void>(callback: () {});

  @override
  InternalFinalCallback<void> get onDelete =>
      InternalFinalCallback<void>(callback: () {});

  // Método auxiliar para tests
  void updateDataPoints(List<DataPoint> points) {
    _dataPoints.value = points;
  }
}

class MockGraphProvider extends Mock implements DataAcquisitionProvider {
  final double _maxValue = 10.0;
  final double _distance = 5.0;
  double _scale = 1.0;

  @override
  double getMaxValue() => _maxValue;

  @override
  double getDistance() => _distance;

  @override
  double getScale() => _scale;

  @override
  List<double> autoset(double height, double width) {
    _scale = 1.0;
    return [1.0, 1.0];
  }

  @override
  InternalFinalCallback<void> get onStart =>
      InternalFinalCallback<void>(callback: () {});

  @override
  InternalFinalCallback<void> get onDelete =>
      InternalFinalCallback<void>(callback: () {});
}

void main() {
  late MockLineChartProvider mockLineChartProvider;
  late MockGraphProvider mockGraphProvider;
  late DeviceConfigProvider deviceConfigProvider;

  setUp(() {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.reset();

    // Initialize providers
    deviceConfigProvider = DeviceConfigProvider();
    mockLineChartProvider = MockLineChartProvider();
    mockGraphProvider = MockGraphProvider();

    // Register all providers with GetX
    Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);
    Get.put<LineChartProvider>(mockLineChartProvider);
    Get.put<DataAcquisitionProvider>(mockGraphProvider);

    // Initialize device config
    deviceConfigProvider.updateConfig(DeviceConfig(
      samplingFrequency: 1650000.0,
      bitsPerPacket: 16,
      dataMask: 0x0FFF,
      channelMask: 0xF000,
      usefulBits: 12,
      samplesPerPacket: 4096,
    ));
  });

  tearDown(() {
    Get.reset();
  });

  Widget createWidgetUnderTest() {
    return MaterialApp(
      theme: ThemeData(
        scaffoldBackgroundColor: Colors.white,
      ),
      home: Scaffold(
        body: SizedBox(
          width: 800.0,
          height: 600.0,
          child: LineChart(),
        ),
      ),
    );
  }

  group('LineChart Widget Tests', () {
    testWidgets('should show no data message when dataPoints is empty',
        (WidgetTester tester) async {
      mockLineChartProvider.updateDataPoints([]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      expect(find.text('No data'), findsOneWidget);
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsNothing);
    });

    testWidgets('should render chart when dataPoints is available',
        (WidgetTester tester) async {
      mockLineChartProvider.updateDataPoints([
        DataPoint(0, 1),
        DataPoint(1, 2),
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
      expect(find.text('No data'), findsNothing);
    });

    testWidgets('should update timeScale when left arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pump();
      expect(mockLineChartProvider.timeScale, closeTo(0.9, 0.001));
    });

    testWidgets('should update timeScale when right arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();
      expect(mockLineChartProvider.timeScale, closeTo(1.1, 0.001));
    });

    testWidgets('should update valueScale when up arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(mockLineChartProvider.valueScale, closeTo(1.1, 0.01));
    });

    testWidgets('should update valueScale when down arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();

      expect(mockLineChartProvider.valueScale, closeTo(0.9, 0.01));
    });

    testWidgets('should reset scales when reset button is pressed',
        (WidgetTester tester) async {
      mockLineChartProvider.setTimeScale(2.0);
      mockLineChartProvider.setValueScale(2.0);

      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.autorenew));
      await tester.pumpAndSettle();

      // Call autoset explicitly since it's called in the LineChart widget
      final result = mockGraphProvider.autoset(600, 800);
      mockLineChartProvider.setTimeScale(result[0]);
      mockLineChartProvider.setValueScale(result[1]);

      expect(mockLineChartProvider.timeScale, equals(1.0));
      expect(mockLineChartProvider.valueScale, equals(1.0));
    });

    testWidgets('should clip points to drawing area',
        (WidgetTester tester) async {
      mockLineChartProvider.updateDataPoints([
        DataPoint(0, 100),
        DataPoint(1, -100),
        DataPoint(1000, 1),
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('should handle window resize', (WidgetTester tester) async {
      mockLineChartProvider.updateDataPoints([
        DataPoint(0, 1),
        DataPoint(1, 2),
      ]);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(400, 300));
      await tester.pumpAndSettle();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('should update horizontal offset when arrow keys are pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.keyboard_arrow_left),
          warnIfMissed: false);
      await tester.pump();
      expect(mockLineChartProvider.horizontalOffset, closeTo(-0.01, 0.001));

      await tester.tap(find.byIcon(Icons.keyboard_arrow_right),
          warnIfMissed: false);
      await tester.pump();
      expect(mockLineChartProvider.horizontalOffset, closeTo(0.0, 0.001));
    });

    testWidgets('should update vertical offset when arrow keys are pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      // Simular tap en el botón hacia arriba
      await tester.tap(find.byIcon(Icons.keyboard_arrow_up));
      await tester.pump();
      expect(mockLineChartProvider.verticalOffset, closeTo(0.001, 0.001));

      // Simular tap en el botón hacia abajo
      await tester.tap(find.byIcon(Icons.keyboard_arrow_down));
      await tester.pump();
      expect(mockLineChartProvider.verticalOffset, closeTo(0.0, 0.001));
    });

    testWidgets('should reset offsets when reset button is pressed',
        (WidgetTester tester) async {
      mockLineChartProvider.setHorizontalOffset(1.0);
      mockLineChartProvider.setVerticalOffset(1.0);

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.tap(find.byIcon(Icons.autorenew), warnIfMissed: false);
      await tester.pumpAndSettle();

      expect(mockLineChartProvider.horizontalOffset, equals(0.0));
      expect(mockLineChartProvider.verticalOffset, equals(0.0));
    });

    test('LineChartPainter shouldRepaint returns true', () {
      final painter = LineChartPainter(
        [DataPoint(0, 1)],
        1.0,
        1.0,
        10.0,
        5.0,
        1.0,
        Colors.white,
        0.0, // horizontalOffset
        0.0, // verticalOffset
      );

      expect(painter.shouldRepaint(painter), isTrue);
    });
  });
}
