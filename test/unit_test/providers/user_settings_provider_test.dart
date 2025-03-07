import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/fft_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';

class FakeOscilloscopeChartService implements OscilloscopeChartService {
  bool _isPaused = false;
  bool pauseCalled = false;
  bool resumeCalled = false;

  @override
  bool get isPaused => _isPaused;

  @override
  void pause() {
    pauseCalled = true;
    _isPaused = true;
  }

  @override
  void resume() {
    resumeCalled = true;
    _isPaused = false;
  }

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  @override
  double get samplingFrequency => 1650000.0;

  @override
  DeviceConfig? get config => null;

  @override
  int get bitsPerPacket => 16;

  @override
  int get channelMask => 0xF000;

  @override
  int get channelMaskTrailingZeros => 12;

  @override
  int get dataMask => 0x0FFF;

  @override
  int get dataMaskTrailingZeros => 0;

  @override
  int get discardHead => 0;

  @override
  int get discardTrailer => 0;

  @override
  int get dividingFactor => 1;

  @override
  int get samplesPerPacket => 512;

  @override
  int get usefulBits => 12;

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

class FakeFFTChartProvider extends GetxController implements FFTChartProvider {
  @override
  final frequency = 0.0.obs;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeFFTChartService implements FFTChartService {
  bool pauseCalled = false;
  bool resumeCalled = false;
  double _frequency = 0.0;

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

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeOscilloscopeChartProvider extends GetxController
    implements OscilloscopeChartProvider {
  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class FakeDataAcquisitionProvider extends GetxController
    implements DataAcquisitionProvider {
  @override
  final frequency = 1000.0.obs;

  @override
  noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  late UserSettingsProvider provider;
  late FakeOscilloscopeChartService fakeOscilloscopeService;
  late FakeFFTChartService fakeFFTService;
  late FakeFFTChartProvider fakeFFTChartProvider;
  late FakeOscilloscopeChartProvider fakeOscilloscopeChartProvider;
  late FakeDataAcquisitionProvider fakeDataAcquisitionProvider;
  late FakeDeviceConfigProvider fakeDeviceConfigProvider; // Add this

  setUp(() {
    Get.reset();

    // Enable test mode to avoid navigation errors
    Get.testMode = true;

    // Initialize and register all required providers
    fakeDeviceConfigProvider = FakeDeviceConfigProvider();
    Get.put<DeviceConfigProvider>(fakeDeviceConfigProvider);

    fakeDataAcquisitionProvider = FakeDataAcquisitionProvider();
    Get.put<DataAcquisitionProvider>(fakeDataAcquisitionProvider);

    fakeFFTChartProvider = FakeFFTChartProvider();
    Get.put<FFTChartProvider>(fakeFFTChartProvider);

    fakeOscilloscopeChartProvider = FakeOscilloscopeChartProvider();
    Get.put<OscilloscopeChartProvider>(fakeOscilloscopeChartProvider);

    // Initialize services
    fakeOscilloscopeService = FakeOscilloscopeChartService();
    fakeFFTService = FakeFFTChartService();

    provider = UserSettingsProvider(
      oscilloscopeService: fakeOscilloscopeService,
      fftChartService: fakeFFTService,
    );

    // Set initial mode to ensure widgets can be created
    provider.setMode('Oscilloscope');
  });

  tearDown(() {
    Get.reset();
  });
  group('Provider Initialization', () {
    test('should initialize with default values', () {
      expect(provider.mode.value, 'Oscilloscope');
      expect(provider.title.value, 'Graph - Oscilloscope Mode');
      expect(provider.frequencySource.value, FrequencySource.timeDomain);
      expect(provider.frequency.value, 0.0);
      expect(provider.availableModes, ['Oscilloscope', 'Spectrum Analyzer']);
    });
  });

  group('Mode Management', () {
    test('should handle mode switch to Oscilloscope', () {
      provider.setMode('Oscilloscope');

      expect(provider.mode.value, 'Oscilloscope');
      expect(provider.title.value, 'Graph - Oscilloscope Mode');
      expect(fakeFFTService.pauseCalled, true);
      expect(fakeOscilloscopeService.resumeCalled, true);
    });

    test('should handle mode switch to FFT', () {
      provider.setMode('FFT');

      expect(provider.mode.value, 'FFT');
      expect(provider.title.value, 'Graph - Spectrum Analyzer Mode');
      expect(fakeOscilloscopeService.pauseCalled, true);
      expect(fakeFFTService.resumeCalled, true);
    });

    test('should update UI controls visibility based on mode', () {
      provider.setMode('Oscilloscope');
      expect(provider.showTriggerControls, true);
      expect(provider.showTimebaseControls, true);
      expect(provider.showFFTControls, false);

      provider.setMode('FFT');
      expect(provider.showTriggerControls, false);
      expect(provider.showTimebaseControls, false);
      expect(provider.showFFTControls, true);
    });
  });

  group('Frequency Source Management', () {
    test('should handle switch to FFT frequency source', () {
      provider.setFrequencySource(FrequencySource.fft);
      expect(provider.frequencySource.value, FrequencySource.fft);
      expect(fakeFFTService.resumeCalled, true);
    });

    test('should handle switch to time domain frequency source', () {
      // Setup FFT mode first
      provider.setMode('Oscilloscope');
      provider.setFrequencySource(FrequencySource.timeDomain);

      expect(provider.frequencySource.value, FrequencySource.timeDomain);
      expect(fakeFFTService.pauseCalled, true);
    });
  });

  group('Chart Widget Management', () {
    test('should return correct chart widget based on mode', () {
      provider.setMode('Oscilloscope');
      expect(provider.getCurrentChart(), isA<Widget>());

      provider.setMode('FFT');
      expect(provider.getCurrentChart(), isA<Widget>());
    });
  });
  group('Frequency Updates', () {
    test('should update frequency from time domain source', () async {
      provider.setFrequencySource(FrequencySource.timeDomain);
      fakeDataAcquisitionProvider.frequency.value = 1000.0;

      // Wait for timer to trigger update
      await Future.delayed(const Duration(seconds: 3));
      expect(provider.frequency.value, 1000.0);
    });
  });

  group('Resource Management', () {
    test('should cleanup timer on close', () {
      provider.onClose();
      // Verify timer is cancelled by trying to trigger an update
      fakeDataAcquisitionProvider.frequency.value = 3000.0;
      expect(provider.frequency.value, 0.0);
    });
  });
}
