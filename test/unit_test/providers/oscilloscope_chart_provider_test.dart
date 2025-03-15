// oscilloscope_chart_provider_test.dart

import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';

class FakeOscilloscopeChartService implements OscilloscopeChartService {
  final StreamController<List<DataPoint>> _dataController =
      StreamController<List<DataPoint>>.broadcast();

  bool _isPaused = false;
  bool resumeAndWaitCalled = false;
  bool disposeCalled = false;

  // Track if calculateAutosetScales was called with these parameters
  double? lastChartWidth;
  double? lastFrequency;
  double? lastMaxValue;
  double? lastMinValue;
  double? lastMarginFactor;

  // Default values for autoset scales test
  Map<String, double> autosetScalesResult = {
    'timeScale': 5000.0,
    'valueScale': 0.5,
    'verticalCenter': 0.3
  };

  // Add deviceConfig implementation
  @override
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;

  @override
  bool get isPaused => _isPaused;

  @override
  double get distance => 1 / 1650000;

  void emitData(List<DataPoint> points) {
    _dataController.add(points);
  }

  @override
  void pause() {
    _isPaused = true;
  }

  @override
  void resume() {
    _isPaused = false;
  }

  @override
  void resumeAndWaitForTrigger() {
    resumeAndWaitCalled = true;
    _isPaused = false;
  }

  @override
  void updateProvider(DataAcquisitionProvider provider) {}

  @override
  Future<void> dispose() async {
    disposeCalled = true;
    await _dataController.close();
  }

  @override
  Map<String, double> calculateAutosetScales(
      double chartWidth, double frequency, double maxValue, double minValue,
      {double marginFactor = 1.15}) {
    // Record the parameters for testing
    lastChartWidth = chartWidth;
    lastFrequency = frequency;
    lastMaxValue = maxValue;
    lastMinValue = minValue;
    lastMarginFactor = marginFactor;

    // Return the test values
    return autosetScalesResult;
  }
}

class FakeDataAcquisitionProvider extends GetxController
    implements DataAcquisitionProvider {
  @override
  final triggerMode = TriggerMode.normal.obs;
  @override
  final frequency = RxDouble(1.0);
  @override
  final maxValue = RxDouble(1.0);
  double _currentMinValue = 0.0;
  bool _autosetCalled = false;

  @override
  void setPause(bool paused) {}

  @override
  void setTriggerMode(TriggerMode mode) {
    triggerMode.value = mode;
  }

  // Add missing getters/methods needed for tests
  @override
  double get currentMinValue => _currentMinValue;

  // Create setter for test purposes
  void setCurrentMinValue(double value) {
    _currentMinValue = value;
  }

  // Implement autoset as a method, not a property
  @override
  Future<void> autoset() async {
    _autosetCalled = true;
    return Future.value();
  }

  // Getter to check if autoset was called (for test verification)
  bool get wasAutosetCalled => _autosetCalled;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  @override
  int get usefulBits => 12;

  @override
  double get samplingFrequency => 1650000.0;

  @override
  int get maxBits => 500;

  @override
  int get midBits => 250;

  @override
  int get minBits => 0;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late OscilloscopeChartProvider provider;
  late FakeOscilloscopeChartService fakeService;
  late FakeDataAcquisitionProvider fakeDataAcquisitionProvider;
  late FakeDeviceConfigProvider fakeDeviceConfigProvider;

  setUp(() {
    Get.reset();

    fakeDeviceConfigProvider = FakeDeviceConfigProvider();
    Get.put<DeviceConfigProvider>(fakeDeviceConfigProvider);

    fakeDataAcquisitionProvider = FakeDataAcquisitionProvider();
    Get.put<DataAcquisitionProvider>(fakeDataAcquisitionProvider);

    fakeService = FakeOscilloscopeChartService();
    provider = OscilloscopeChartProvider(fakeService);
  });

  tearDown(() async {
    await fakeService.dispose();
    Get.reset();
  });

  group('Provider Initialization', () {
    test('should initialize with default values', () {
      expect(provider.timeScale, 1.0);
      expect(provider.valueScale, 1.0 / 500);
      expect(provider.isPaused, false);
      expect(provider.horizontalOffset, 0.0);
      expect(provider.verticalOffset, 0.0);
      expect(provider.initialTimeScale, 1.0);
      expect(provider.initialValueScale, 1.0);
    });
  });

  group('Autoset', () {
    test(
        'should call DataAcquisitionProvider.autoset and apply calculated scales',
        () async {
      // Define test signal values
      const frequency = 100.0;
      const maxValue = 1.0;
      const minValue = -0.5;

      // Setup mock data
      fakeDataAcquisitionProvider.frequency.value = frequency;
      fakeDataAcquisitionProvider.maxValue.value = maxValue;
      fakeDataAcquisitionProvider.setCurrentMinValue(minValue);

      // Set expected scale values that will be returned from the service
      fakeService.autosetScalesResult = {
        'timeScale': 5000.0,
        'valueScale': 0.5,
        'verticalCenter': 0.3
      };

      // Call autoset
      const chartHeight = 600.0;
      const chartWidth = 800.0;
      await provider.autoset(chartHeight, chartWidth);

      // Verify autoset was called on DAP
      expect(fakeDataAcquisitionProvider.wasAutosetCalled, isTrue);

      // Verify service was called with correct parameters
      expect(fakeService.lastChartWidth, equals(chartWidth));
      expect(fakeService.lastFrequency, equals(frequency));
      expect(fakeService.lastMaxValue, equals(maxValue));
      expect(fakeService.lastMinValue, equals(minValue));
      expect(fakeService.lastMarginFactor, equals(1.15)); // Default margin

      // Verify scales were applied
      expect(provider.timeScale,
          equals(fakeService.autosetScalesResult['timeScale']));
      expect(provider.valueScale,
          equals(fakeService.autosetScalesResult['valueScale']));

      // Verify vertical offset was applied correctly
      final expectedVerticalOffset =
          -fakeService.autosetScalesResult['verticalCenter']! *
              fakeService.autosetScalesResult['valueScale']!;
      expect(provider.verticalOffset, equals(expectedVerticalOffset));

      // Verify horizontal offset was reset
      expect(provider.horizontalOffset, equals(0.0));
    });

    test('should handle edge case with zero frequency', () async {
      // Define test signal values
      const frequency = 0.0; // Zero frequency edge case
      const maxValue = 1.0;
      const minValue = -0.5;

      // Setup mock data
      fakeDataAcquisitionProvider.frequency.value = frequency;
      fakeDataAcquisitionProvider.maxValue.value = maxValue;
      fakeDataAcquisitionProvider.setCurrentMinValue(minValue);

      // Set expected scale values for zero frequency
      fakeService.autosetScalesResult = {
        'timeScale': 100000.0, // Default for zero frequency
        'valueScale': 0.5,
        'verticalCenter': 0.3
      };

      // Call autoset
      const chartHeight = 600.0;
      const chartWidth = 800.0;
      await provider.autoset(chartHeight, chartWidth);

      // Verify service was called with zero frequency
      expect(fakeService.lastFrequency, equals(0.0));

      // Verify scales were applied
      expect(provider.timeScale,
          equals(fakeService.autosetScalesResult['timeScale']));
      expect(provider.valueScale,
          equals(fakeService.autosetScalesResult['valueScale']));
    });

    test('should handle edge case with zero range signal', () async {
      // Define test signal values for zero range (min=max)
      const frequency = 100.0;
      const maxValue = 0.5;
      const minValue = 0.5; // Same as max -> zero range

      // Setup mock data
      fakeDataAcquisitionProvider.frequency.value = frequency;
      fakeDataAcquisitionProvider.maxValue.value = maxValue;
      fakeDataAcquisitionProvider.setCurrentMinValue(minValue);

      // Set expected scale values for zero range
      fakeService.autosetScalesResult = {
        'timeScale': 5000.0,
        'valueScale': 0.8, // Some arbitrary value service would calculate
        'verticalCenter': 0.5 // Should be equal to maxValue/minValue
      };

      // Call autoset
      const chartHeight = 600.0;
      const chartWidth = 800.0;
      await provider.autoset(chartHeight, chartWidth);

      // Verify service was called with zero range
      expect(fakeService.lastMaxValue, equals(fakeService.lastMinValue));

      // Verify scales were applied
      expect(provider.timeScale,
          equals(fakeService.autosetScalesResult['timeScale']));
      expect(provider.valueScale,
          equals(fakeService.autosetScalesResult['valueScale']));
    });
  });

  group('Scale Management', () {
    test('should set time scale with constraints', () {
      provider.setTimeScale(2.0);
      expect(provider.timeScale, 2.0);

      provider.setTimeScale(0); // Should not accept 0
      expect(provider.timeScale, 2.0);
    });

    test('should set value scale with constraints', () {
      provider.setValueScale(2.0);
      expect(provider.valueScale, 2.0);

      provider.setValueScale(0); // Should not accept 0
      expect(provider.valueScale, 2.0);
    });
  });

  group('Zoom Handling', () {
    test('should handle zoom gestures', () {
      final size = Size(800, 600);
      const offsetX = 50.0;

      provider.setInitialScales();
      final initialTimeScale = provider.timeScale;
      final initialValueScale = provider.valueScale;

      final details = ScaleUpdateDetails(
        focalPoint: Offset(400, 300),
        scale: 2.0,
        pointerCount: 2,
      );

      provider.updateDrawingWidth(size, offsetX);
      provider.handleZoom(details, size, offsetX);

      expect(provider.timeScale, greaterThan(initialTimeScale));
      expect(provider.valueScale, greaterThan(initialValueScale));
    });

    test('should reset scales', () {
      provider.setTimeScale(2.0);
      provider.setValueScale(2.0);
      provider.resetScales();
      expect(provider.timeScale, 1.0);
      expect(provider.valueScale, 1.0);
    });
  });

  group('Offset Controls', () {
    test('should set horizontal offset in trigger mode', () {
      const testOffset = 100.0;
      final size = Size(800, 600);
      const offsetX = 50.0;

      // Setup drawing width and data points
      provider.updateDrawingWidth(size, offsetX);
      fakeService.emitData([DataPoint(0, 0), DataPoint(200, 0)]);

      // Switch to trigger mode to allow free offset
      fakeDataAcquisitionProvider.triggerMode.value = TriggerMode.single;

      // Try setting offset
      provider.setHorizontalOffset(testOffset);
      expect(provider.horizontalOffset, testOffset);
    });

    test('should handle offset increments in trigger mode', () {
      final size = Size(800, 600);
      const offsetX = 50.0;

      // Setup drawing width and data points
      provider.updateDrawingWidth(size, offsetX);
      fakeService.emitData([DataPoint(0, 0), DataPoint(200, 0)]);

      // Switch to trigger mode
      fakeDataAcquisitionProvider.triggerMode.value = TriggerMode.single;

      final initialHOffset = provider.horizontalOffset;
      final initialVOffset = provider.verticalOffset;

      provider.incrementHorizontalOffset();
      expect(provider.horizontalOffset, greaterThan(initialHOffset));

      provider.incrementVerticalOffset();
      expect(provider.verticalOffset, greaterThan(initialVOffset));
    });
    test('should clamp horizontal offset in normal mode', () {
      const testOffset = 100.0;

      // Add data points to allow offset
      final points = [DataPoint(0, 0), DataPoint(200, 0)];
      fakeService.emitData(points);

      // Set drawing width
      provider.updateDrawingWidth(Size(800, 600), 50);

      provider.setHorizontalOffset(testOffset);
      expect(provider.horizontalOffset, lessThanOrEqualTo(testOffset));
      expect(provider.horizontalOffset, greaterThanOrEqualTo(0.0));
    });

    test('should set vertical offset', () {
      provider.setVerticalOffset(0.5);
      expect(provider.verticalOffset, 0.5);
    });

    test('should reset offsets', () {
      provider.setHorizontalOffset(100);
      provider.setVerticalOffset(0.5);
      provider.resetOffsets();
      expect(provider.horizontalOffset, 0.0);
      expect(provider.verticalOffset, 0.0);
    });
  });

  group('Coordinate Transformations', () {
    final size = Size(800, 600);
    const offsetX = 50.0;

    test('should convert between screen and domain coordinates', () {
      const screenX = 400.0;
      const screenY = 300.0;

      final domainX = provider.screenToDomainX(screenX, size, offsetX);
      final domainY = provider.screenToDomainY(screenY, size, offsetX);

      final backToScreenX = provider.domainToScreenX(domainX, size, offsetX);
      final backToScreenY = provider.domainToScreenY(domainY, size, offsetX);

      expect(backToScreenX, closeTo(screenX, 0.001));
      expect(backToScreenY, closeTo(screenY, 0.001));
    });
  });

  group('Pause/Resume', () {
    test('should handle pause', () {
      provider.pause();
      expect(provider.isPaused, true);
      expect(fakeService.isPaused, true);
    });

    test('should handle resume', () {
      provider.pause();
      provider.resume();
      expect(provider.isPaused, false);
      expect(fakeService.isPaused, false);
    });
  });

  group('Trigger Handling', () {
    test('should clear for new trigger', () {
      final initialPoints = [DataPoint(0, 1), DataPoint(1, 2)];
      fakeService.emitData(initialPoints);

      provider.clearForNewTrigger();
      expect(provider.dataPoints, isEmpty);
      expect(fakeService.resumeAndWaitCalled, true);
    });

    test('should clear and resume', () {
      final initialPoints = [DataPoint(0, 1), DataPoint(1, 2)];
      fakeService.emitData(initialPoints);

      provider.clearAndResume();
      expect(provider.dataPoints, isEmpty);
      expect(provider.isPaused, false);
    });
  });

  group('Resource Management', () {
    test('should dispose resources', () async {
      provider.onClose();
      expect(fakeService.disposeCalled, true);
    });
  });

  group('Increment/Decrement Controls', () {
    test('should handle time scale increments', () {
      final initialScale = provider.timeScale;

      provider.incrementTimeScale();
      expect(provider.timeScale, greaterThan(initialScale));

      final afterIncrement = provider.timeScale;
      provider.decrementTimeScale();
      expect(provider.timeScale, lessThan(afterIncrement));
    });

    test('should handle value scale increments', () {
      final initialScale = provider.valueScale;

      provider.incrementValueScale();
      expect(provider.valueScale, greaterThan(initialScale));

      final afterIncrement = provider.valueScale;
      provider.decrementValueScale();
      expect(provider.valueScale, lessThan(afterIncrement));
    });
  });
}
