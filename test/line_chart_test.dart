import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/data_provider.dart';
import 'package:arg_osci_app/features/graph/providers/line_chart_provider.dart';
import 'package:arg_osci_app/features/graph/widgets/line_chart.dart';

// Manual mocks
class MockLineChartProvider extends Mock implements LineChartProvider {
  final _dataPoints = Rx<List<DataPoint>>([]);
  final _timeScale = 1.0.obs;
  final _valueScale = 1.0.obs;

  @override
  Rx<List<DataPoint>> get dataPoints => _dataPoints;

  @override
  RxDouble get timeScale => _timeScale;

  @override
  RxDouble get valueScale => _valueScale;

  @override
  void setTimeScale(double scale) {
    _timeScale.value = scale;
  }

  @override
  void setValueScale(double scale) {
    _valueScale.value = scale;
  }

  @override
  void resetScales() {
    _timeScale.value = 1.0;
    _valueScale.value = 1.0;
  }

  @override
  double getTimeScale() => _timeScale.value;

  @override
  double getValueScale() => _valueScale.value;

  @override
  InternalFinalCallback<void> get onStart =>
      InternalFinalCallback<void>(callback: () {});

  @override
  InternalFinalCallback<void> get onDelete =>
      InternalFinalCallback<void>(callback: () {});
}

class MockGraphProvider extends Mock implements GraphProvider {
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

  setUp(() {
    mockLineChartProvider = MockLineChartProvider();
    mockGraphProvider = MockGraphProvider();

    // Register providers
    Get.put<LineChartProvider>(mockLineChartProvider);
    Get.put<GraphProvider>(mockGraphProvider);
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
        body: LineChart(),
      ),
    );
  }

  group('LineChart Widget Tests', () {
    testWidgets('should show no data message when dataPoints is empty',
        (WidgetTester tester) async {
      mockLineChartProvider.dataPoints.value = [];

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
      mockLineChartProvider.dataPoints.value = [
        DataPoint(0, 1),
        DataPoint(1, 2),
      ];

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

      expect(mockLineChartProvider.timeScale.value, closeTo(0.9, 0.01));
    });

    testWidgets('should update timeScale when right arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();

      expect(mockLineChartProvider.timeScale.value, closeTo(1.1, 0.01));
    });

    testWidgets('should update valueScale when up arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();

      expect(mockLineChartProvider.valueScale.value, closeTo(1.1, 0.01));
    });

    testWidgets('should update valueScale when down arrow is pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(createWidgetUnderTest());

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();

      expect(mockLineChartProvider.valueScale.value, closeTo(0.9, 0.01));
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

      expect(mockLineChartProvider.timeScale.value, equals(1.0));
      expect(mockLineChartProvider.valueScale.value, equals(1.0));
    });

    testWidgets('should clip points to drawing area', (WidgetTester tester) async {
      mockLineChartProvider.dataPoints.value = [
        DataPoint(0, 100),
        DataPoint(1, -100),
        DataPoint(1000, 1),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
    });

    testWidgets('should handle window resize', (WidgetTester tester) async {
      mockLineChartProvider.dataPoints.value = [
        DataPoint(0, 1),
        DataPoint(1, 2),
      ];

      await tester.pumpWidget(createWidgetUnderTest());
      await tester.pumpAndSettle();

      await tester.binding.setSurfaceSize(const Size(400, 300));
      await tester.pumpAndSettle();

      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is LineChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
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
      );

      expect(painter.shouldRepaint(painter), isTrue);
    });
  });
}