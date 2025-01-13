// test/features/graph/widgets/fft_chart_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/widgets/fft_chart.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';

// Manual mocks
class MockFFTChartProvider extends Mock implements FFTChartProvider {
  final _fftPoints = Rx<List<DataPoint>>([]);
  final _timeScale = 1.0.obs;
  final _valueScale = 1.0.obs;

  @override
  Rx<List<DataPoint>> get fftPoints => _fftPoints;

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
  InternalFinalCallback<void> get onStart =>
      InternalFinalCallback<void>(callback: () {});

  @override
  InternalFinalCallback<void> get onDelete =>
      InternalFinalCallback<void>(callback: () {});
}

class MockFFTChartService extends Mock implements FFTChartService {}

void main() {
  late MockFFTChartProvider mockProvider;
  late MockFFTChartService mockService;

  setUp(() {
    mockService = MockFFTChartService();
    mockProvider = MockFFTChartProvider();

    // Register dependencies
    Get.put<FFTChartService>(mockService);
    Get.put<FFTChartProvider>(mockProvider);
  });

  tearDown(() {
    Get.reset();
  });

  group('FFTChart Widget Tests', () {
    testWidgets('should show no data message when empty',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFTChart(),
          ),
        ),
      );

      expect(find.text('No data'), findsOneWidget);
    });

    testWidgets('should render chart when data is available',
        (WidgetTester tester) async {
      // Arrange
      mockProvider.fftPoints.value = [
        DataPoint(0, 1),
        DataPoint(1, 2),
      ];

      // Act
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFTChart(),
          ),
        ),
      );

      // Assert
      final customPaintFinder = find.byWidgetPredicate(
        (widget) => widget is CustomPaint && widget.painter is FFTChartPainter,
      );
      expect(customPaintFinder, findsOneWidget);
      expect(find.text('No data'), findsNothing);
    });

    testWidgets('should call setTimeScale when left/right arrows pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFTChart(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_left));
      await tester.pump();
      expect(mockProvider.timeScale.value, closeTo(0.9, 0.01));

      await tester.tap(find.byIcon(Icons.arrow_right));
      await tester.pump();
      expect(mockProvider.timeScale.value, closeTo(0.99, 0.01));
    });

    testWidgets('should call setValueScale when up/down arrows pressed',
        (WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFTChart(),
          ),
        ),
      );

      await tester.tap(find.byIcon(Icons.arrow_upward));
      await tester.pump();
      expect(mockProvider.valueScale.value, closeTo(1.1, 0.01));

      await tester.tap(find.byIcon(Icons.arrow_downward));
      await tester.pump();
      expect(mockProvider.valueScale.value, closeTo(0.99, 0.01));
    });

    testWidgets('should call resetScales when reset button pressed',
        (WidgetTester tester) async {
      // Arrange
      mockProvider.setTimeScale(2.0);
      mockProvider.setValueScale(2.0);

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: FFTChart(),
          ),
        ),
      );

      // Act
      await tester.tap(find.byIcon(Icons.autorenew));
      await tester.pump();

      // Assert
      expect(mockProvider.timeScale.value, equals(1.0));
      expect(mockProvider.valueScale.value, equals(1.0));
    });
  });
}
