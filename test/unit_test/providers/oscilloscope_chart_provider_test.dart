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
}

class FakeDataAcquisitionProvider extends GetxController
    implements DataAcquisitionProvider {
  @override
  final triggerMode = TriggerMode.normal.obs;

  @override
  void setPause(bool paused) {}

  @override
  void setTriggerMode(TriggerMode mode) {
    triggerMode.value = mode;
  }

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
      expect(provider.valueScale,
          1.0 / (1 << fakeDeviceConfigProvider.usefulBits));
      expect(provider.isPaused, false);
      expect(provider.horizontalOffset, 0.0);
      expect(provider.verticalOffset, 0.0);
      expect(provider.initialTimeScale, 1.0);
      expect(provider.initialValueScale, 1.0);
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
