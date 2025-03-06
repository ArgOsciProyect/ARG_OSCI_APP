// test/unit_test/models/graph_mode_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/graph_mode.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:mockito/mockito.dart';

class MockOscilloscopeChartService extends Mock
    implements OscilloscopeChartService {}

class MockFFTChartService extends Mock implements FFTChartService {}

void main() {
  group('OscilloscopeMode', () {
    late OscilloscopeMode mode;
    late MockOscilloscopeChartService mockService;

    setUp(() {
      mockService = MockOscilloscopeChartService();
      mode = OscilloscopeMode(mockService);
    });

    test('has correct properties', () {
      expect(mode.name, equals('Oscilloscope'));
      expect(mode.title, equals('Graph - Oscilloscope Mode'));
      expect(mode.showTriggerControls, isTrue);
      expect(mode.showTimebaseControls, isTrue);
      expect(mode.showCustomControls, isFalse);
    });

    test('calls service methods on activate/deactivate', () {
      mode.onActivate();
      verify(mockService.resume()).called(1);

      mode.onDeactivate();
      verify(mockService.pause()).called(1);
    });
  });

  group('FFTMode', () {
    late FFTMode mode;
    late MockFFTChartService mockService;

    setUp(() {
      mockService = MockFFTChartService();
      mode = FFTMode(mockService);
    });

    test('has correct properties', () {
      expect(mode.name, equals('Spectrum Analyzer'));
      expect(mode.title, equals('Graph - Spectrum Analyzer Mode'));
      expect(mode.showTriggerControls, isFalse);
      expect(mode.showTimebaseControls, isFalse);
      expect(mode.showCustomControls, isTrue);
    });

    test('calls service methods on activate/deactivate', () {
      mode.onActivate();
      verify(mockService.resume()).called(1);

      mode.onDeactivate();
      verify(mockService.pause()).called(1);
    });
  });
}
