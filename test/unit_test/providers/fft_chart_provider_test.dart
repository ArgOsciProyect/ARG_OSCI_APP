import 'dart:async';

import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:flutter/widgets.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';

class FakeFFTChartService extends FFTChartService {
  final StreamController<List<DataPoint>> _fftController =
      StreamController<List<DataPoint>>.broadcast();
  bool pauseCalled = false;
  bool resumeCalled = false;
  double _frequency = 0.0;

  FakeFFTChartService() : super(null);

  @override
  Stream<List<DataPoint>> get fftStream => _fftController.stream;

  @override
  double get frequency => _frequency;
  set frequency(double value) => _frequency = value;

  @override
  void pause() {
    pauseCalled = true;
  }

  @override
  void resume() {
    resumeCalled = true;
  }

  void emitPoints(List<DataPoint> points) {
    _fftController.add(points);
  }

  @override
  Future<void> dispose() async {
    await _fftController.close();
  }
}

class FakeDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  @override
  double get samplingFrequency => 1650000.0;

  // Implement other required members with default values
  @override
  DeviceConfig? get config => null;
  @override
  dynamic get bitsPerPacket => 16;
  @override
  dynamic get channelMask => 0xF000;
  @override
  int get channelMaskTrailingZeros => 12;
  @override
  dynamic get dataMask => 0x0FFF;
  @override
  int get dataMaskTrailingZeros => 0;
  @override
  int get discardHead => 0;
  @override
  int get discardTrailer => 0;
  @override
  int get dividingFactor => 1;
  @override
  dynamic get samplesPerPacket => 512;
  @override
  dynamic get usefulBits => 12;
  @override
  int get maxBits => 500;

  @override
  int get midBits => 250;

  @override
  int get minBits => 0;
  @override
  void listen(void Function(DeviceConfig?) cb) {}
  @override
  void updateConfig(DeviceConfig config) {}
}

void main() {
  late FFTChartProvider provider;
  late FakeFFTChartService fakeService;
  late FakeDeviceConfigProvider fakeDeviceConfig;

  setUp(() {
    Get.reset();
    fakeDeviceConfig = FakeDeviceConfigProvider();
    Get.put<DeviceConfigProvider>(fakeDeviceConfig);

    fakeService = FakeFFTChartService();
    provider = FFTChartProvider(fakeService);
  });

  tearDown(() async {
    await fakeService.dispose();
    Get.reset();
  });

  group('Provider Initialization', () {
    test('should initialize with default values', () {
      expect(provider.timeScale.value, 1.0);
      expect(provider.valueScale.value, 1.0);
      expect(provider.isPaused, false);
      expect(provider.horizontalOffset, 0.0);
      expect(provider.verticalOffset, 0.0);
      expect(provider.initialTimeScale, 1.0);
      expect(provider.initialValueScale, 1.0);
    });

    test('should get correct nyquist frequency', () {
      expect(provider.nyquistFreq, fakeDeviceConfig.samplingFrequency / 2);
    });
  });

  group('Scale Management', () {
    test('should limit time scale to 1.0', () {
      provider.setTimeScale(2.0);
      expect(provider.timeScale.value, 1.0);
    });

    test('should allow time scale values below 1.0', () {
      provider.setTimeScale(0.5);
      expect(provider.timeScale.value, 0.5);
    });

    test('should handle value scale changes when timeScale < 1.0', () {
      provider.setTimeScale(0.5); // Set timeScale < 1.0 first
      provider.setValueScale(2.0);
      expect(provider.valueScale.value, 2.0);
    });

    test('should limit value scale increases when timeScale = 1.0', () {
      provider.setTimeScale(1.0);
      final initialValue = provider.valueScale.value;
      provider.setValueScale(initialValue * 2);
      expect(provider.valueScale.value, initialValue);
    });

    test('should allow value scale decreases when timeScale = 1.0', () {
      provider.setTimeScale(1.0);
      final initialValue = provider.valueScale.value;
      provider.setValueScale(initialValue / 2);
      expect(provider.valueScale.value, initialValue / 2);
    });

    test('should handle simultaneous XY zoom', () {
      provider.zoomXY(0.5);
      expect(provider.timeScale.value, 0.5);
      expect(provider.valueScale.value, 0.5);
    });

    test('should reset scales', () {
      provider.setTimeScale(0.5);
      provider.setValueScale(2.0);
      provider.resetScales();
      expect(provider.timeScale.value, 1.0);
      expect(provider.valueScale.value, 1.0);
    });
  });

  group('Offset Controls', () {
    test('should set horizontal offset within bounds', () {
      provider.setTimeScale(0.5); // Show half the frequency range
      final visibleRange = provider.nyquistFreq * 0.5;
      final maxOffset = provider.nyquistFreq - visibleRange;

      provider.setHorizontalOffset(maxOffset / 2);
      expect(provider.horizontalOffset, maxOffset / 2);
    });

    test('should clamp horizontal offset to valid range', () {
      provider.setTimeScale(0.5);
      final visibleRange = provider.nyquistFreq * 0.5;
      final maxOffset = provider.nyquistFreq - visibleRange;

      provider.setHorizontalOffset(maxOffset * 2); // Try to set beyond max
      expect(provider.horizontalOffset, maxOffset);
    });

    test('should not allow horizontal offset when timeScale = 1.0', () {
      provider.setTimeScale(1.0);
      provider.setHorizontalOffset(100);
      expect(provider.horizontalOffset, 0.0);
    });

    test('should set vertical offset', () {
      provider.setVerticalOffset(0.5);
      expect(provider.verticalOffset, 0.5);
    });

    test('should clamp horizontal offset based on time scale', () {
      provider.setTimeScale(0.5); // Show half the frequency range
      final maxOffset = provider.nyquistFreq * 0.5;
      provider.setHorizontalOffset(maxOffset + 1000);
      expect(provider.horizontalOffset, maxOffset);
    });

    test('should reset offsets', () {
      provider.setHorizontalOffset(100);
      provider.setVerticalOffset(0.5);
      provider.resetOffsets();
      expect(provider.horizontalOffset, 0.0);
      expect(provider.verticalOffset, 0.0);
    });
  });

  group('Autoset', () {
    test('should adjust scales based on frequency', () {
      const testFreq = 1000.0;
      fakeService.frequency = testFreq;

      provider.autoset(Size(800, 600), testFreq);
      expect(provider.timeScale.value, lessThanOrEqualTo(1.0));
      expect(provider.valueScale.value, 1.0);
      expect(provider.horizontalOffset, 1.0);
      expect(provider.verticalOffset, 0.0);
    });

    test('should handle zero frequency', () {
      provider.autoset(Size(800, 600), 0.0);
      expect(provider.timeScale.value, 1.0);
      expect(provider.valueScale.value, 1.0);
    });
  });

  group('Pause/Resume', () {
    test('should handle pause', () {
      provider.pause();
      expect(provider.isPaused, true);
      expect(fakeService.pauseCalled, true);
    });

    test('should handle resume', () {
      provider.resume();
      expect(provider.isPaused, false);
      expect(fakeService.resumeCalled, true);
    });
  });

  group('FFT Data Handling', () {
    test('should update FFT points from service', () async {
      final points = [
        DataPoint(0, 1),
        DataPoint(1, 2),
      ];

      // Wait for points to be processed
      final future = expectLater(provider.fftPoints.stream, emits(points));

      fakeService.emitPoints(points);
      await future;
    });
  });

  group('Increment/Decrement Controls', () {
    test('should increment time scale for zoom in', () {
      final initialScale = provider.timeScale.value;
      provider.incrementTimeScale();
      expect(provider.timeScale.value, lessThan(initialScale));
    });

    test('should decrement time scale for zoom out', () {
      provider.setTimeScale(0.5);
      final initialScale = provider.timeScale.value;
      provider.decrementTimeScale();
      expect(provider.timeScale.value, greaterThan(initialScale));
    });

    test('should increment time scale for zoom in', () {
      final initialScale = provider.timeScale.value;
      provider.incrementTimeScale();
      expect(provider.timeScale.value, lessThan(initialScale));
    });

    test('should decrement time scale for zoom out up to 1.0', () {
      provider.setTimeScale(0.5);
      final initialScale = provider.timeScale.value;
      provider.decrementTimeScale();
      expect(provider.timeScale.value,
          allOf(greaterThan(initialScale), lessThanOrEqualTo(1.0)));
    });

    test('should increment/decrement horizontal offset within bounds', () {
      final initialOffset = provider.horizontalOffset;
      provider.setTimeScale(0.5); // Set scale to allow offset
      provider.incrementHorizontalOffset();
      expect(provider.horizontalOffset, greaterThanOrEqualTo(initialOffset));
    });
  });
}
