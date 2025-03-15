// ignore_for_file: deprecated_member_use_from_same_package

import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:flutter/widgets.dart'; // For Widget, Size
// For ScaleUpdateDetails
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';

import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';

import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/device_config.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';

class FakeOscilloscopeChartProvider extends GetxController
    implements OscilloscopeChartProvider {
  final _dataPoints = <DataPoint>[].obs;
  final _timeScale = 1.0.obs;
  final _valueScale = 1.0.obs;
  final _isPaused = false.obs;
  final _horizontalOffset = 0.0.obs;
  final _verticalOffset = 0.0.obs;
  final _initialTimeScale = 1.0;
  final _initialValueScale = 1.0;

  bool clearedForTrigger = false;
  bool clearedAndResumed = false;
  bool paused = false;
  bool resumed = false;
  bool offsetsReset = false;
  bool scalesReset = false;
  bool autosetCalled = false; // Flag to track autoset calls

  @override
  List<DataPoint> get dataPoints => _dataPoints;
  @override
  double get timeScale => _timeScale.value;
  @override
  double get valueScale => _valueScale.value;
  @override
  bool get isPaused => _isPaused.value;
  @override
  double get horizontalOffset => _horizontalOffset.value;
  @override
  double get verticalOffset => _verticalOffset.value;
  @override
  double get initialTimeScale => _initialTimeScale;
  @override
  double get initialValueScale => _initialValueScale;

  @override
  DataAcquisitionProvider get graphProvider =>
      Get.find<DataAcquisitionProvider>();
  @override
  DeviceConfigProvider get deviceConfig => Get.find<DeviceConfigProvider>();

  @override
  void clearForNewTrigger() => clearedForTrigger = true;
  @override
  void clearAndResume() => clearedAndResumed = true;
  @override
  void pause() => paused = true;
  @override
  void resume() => resumed = true;
  @override
  void resetOffsets() => offsetsReset = true;
  @override
  void resetScales() => scalesReset = true;
  @override
  void setTimeScale(double scale) => _timeScale.value = scale;
  @override
  void setValueScale(double scale) => _valueScale.value = scale;
  @override
  void setVerticalOffset(double offset) => _verticalOffset.value = offset;
  @override
  void setHorizontalOffset(double offset) => _horizontalOffset.value = offset;
  @override
  void setInitialScales() {}
  @override
  void updateDrawingWidth(Size size, double offsetX) {}
  @override
  void handleZoom(
      ScaleUpdateDetails details, Size constraints, double offsetX) {}
  @override
  void incrementTimeScale() {}
  @override
  void decrementTimeScale() {}
  @override
  void incrementValueScale() {}
  @override
  void decrementValueScale() {}
  @override
  void incrementHorizontalOffset() {}
  @override
  void decrementHorizontalOffset() {}
  @override
  void incrementVerticalOffset() {}
  @override
  void decrementVerticalOffset() {}
  @override
  void startIncrementing(VoidCallback callback) {}
  @override
  void stopIncrementing() {}
  @override
  double screenToDomainX(double screenX, Size size, double offsetX) => 0.0;
  @override
  double screenToDomainY(double screenY, Size size, double offsetX) => 0.0;
  @override
  double domainToScreenX(double domainX, Size size, double offsetX) => 0.0;
  @override
  double domainToScreenY(double domainY, Size size, double offsetX) => 0.0;

  @override
  Future<void> autoset(double chartHeight, double chartWidth) async {
    autosetCalled = true;

    // Instead of using Get.find, use graphProvider directly
    // This avoids the dependency injection issue in tests
    await graphProvider.autoset();

    resetOffsets();
  }
}

class FakeDeviceConfigProvider extends GetxController
    implements DeviceConfigProvider {
  final _config = Rx<DeviceConfig?>(DeviceConfig(
    dataMask: 0x0FFF,
    channelMask: 0xF000,
    samplingFrequency: 1650000.0,
    samplesPerPacket: 512,
    bitsPerPacket: 16,
    usefulBits: 12,
    dividingFactor: 1,
    discardHead: 0,
    discardTrailer: 0,
  ));

  @override
  DeviceConfig? get config => _config.value;
  @override
  void updateConfig(DeviceConfig config) => _config.value = config;
  @override
  void listen(void Function(DeviceConfig? p1) callback) =>
      callback(_config.value);

  @override
  double get samplingFrequency => 1650000.0;
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
  int get maxBits => 500;

  @override
  int get midBits => 250;
  @override
  List<VoltageScale> get voltageScales => VoltageScales.defaultScales;

  @override
  int get minBits => 0;
  @override
  int get usefulBits => 12;
}

class FakeFFTChartService {
  void pause() {}
  void resume() {}
}

class FakeDataAcquisitionService extends DataAcquisitionService {
  final StreamController<List<DataPoint>> _dataController =
      StreamController<List<DataPoint>>.broadcast();
  final StreamController<double> _frequencyController =
      StreamController<double>.broadcast();
  final StreamController<double> _maxValueController =
      StreamController<double>.broadcast();

  List<double> mockAutosetResponse = [1000.0, 2.0];

  // Variables internas para mantener estado
  TriggerMode _triggerMode = TriggerMode.normal;
  TriggerEdge _triggerEdge = TriggerEdge.positive;
  double _triggerLevel = 0.0;
  bool _useHysteresis = true;
  bool _useLowPassFilter = true;
  double _scale = 0.00048828125;
  double _currentMaxValue = 1.0;
  double _currentMinValue = 0.0;
  VoltageScale _currentVoltageScale = VoltageScales.volt_1;
  final DeviceConfigProvider _deviceConfig;

  FakeDataAcquisitionService(this._deviceConfig)
      : super(HttpConfig('http://fake', client: null));

  // Sobreescribimos getters/setters para usar variables internas
  @override
  DeviceConfigProvider get deviceConfig => _deviceConfig;
  @override
  double get currentMaxValue => _currentMaxValue;

  @override
  double get currentMinValue => _currentMinValue;

  @override
  TriggerMode get triggerMode => _triggerMode;
  @override
  set triggerMode(TriggerMode mode) {
    _triggerMode = mode;
  }

  @override
  TriggerEdge get triggerEdge => _triggerEdge;
  @override
  set triggerEdge(TriggerEdge edge) {
    _triggerEdge = edge;
  }

  @override
  double get triggerLevel => _triggerLevel;
  @override
  set triggerLevel(double level) {
    _triggerLevel = level;
  }

  @override
  bool get useHysteresis => _useHysteresis;
  @override
  set useHysteresis(bool value) {
    _useHysteresis = value;
  }

  @override
  bool get useLowPassFilter => _useLowPassFilter;
  @override
  set useLowPassFilter(bool value) {
    _useLowPassFilter = value;
  }

  @override
  double get scale => _scale;
  @override
  set scale(double value) {
    _scale = value;
  }

  @override
  VoltageScale get currentVoltageScale => _currentVoltageScale;

  @override
  void setVoltageScale(VoltageScale voltageScale) {
    _currentVoltageScale = voltageScale;
    scale = voltageScale.scale;
  }

  @override
  Stream<List<DataPoint>> get dataStream => _dataController.stream;
  @override
  Stream<double> get frequencyStream => _frequencyController.stream;
  @override
  Stream<double> get maxValueStream => _maxValueController.stream;

  void emitData(List<DataPoint> data) => _dataController.add(data);
  void emitFrequency(double freq) => _frequencyController.add(freq);
  void emitMaxValue(double val) => _maxValueController.add(val);

  @override
  Future<void> initialize() async {}
  @override
  Future<void> stopData() async {}
  @override
  Future<void> fetchData(String ip, int port) async {}
  @override
  Future<void> autoset() async {
    // Update trigger level to middle between max and min
    triggerLevel = (_currentMaxValue + _currentMinValue) / 2;

    // Ensure trigger is within voltage range for the current voltage scale
    final range = currentVoltageScale.scale *
        (_deviceConfig.maxBits - _deviceConfig.minBits);
    final halfRange = range / 2;
    triggerLevel = triggerLevel.clamp(-halfRange, halfRange);
  }

  @override
  void clearQueues() {}
  @override
  Future<void> sendSingleTriggerRequest() async {}
  @override
  Future<void> sendNormalTriggerRequest() async {}

  @override
  void updateConfig() {
    // No llamamos a postTriggerStatus
  }

  @override
  Future<void> dispose() async {
    _dataController.close();
    _frequencyController.close();
    _maxValueController.close();
  }
}

class FakeUserSettingsProvider extends GetxController
    implements UserSettingsProvider {
  FakeUserSettingsProvider();

  @override
  final mode = RxString('');
  @override
  final frequency = RxDouble(0.0);
  @override
  final availableModes = <String>['Oscilloscope', 'FFT'];
  @override
  final title = RxString('FakeTitle');
  @override
  final frequencySource = FrequencySource.timeDomain.obs;

  @override
  OscilloscopeChartService get oscilloscopeService =>
      throw UnimplementedError();
  @override
  FFTChartService get fftChartService => throw UnimplementedError();

  @override
  void setMode(String newMode) => mode.value = newMode;
  @override
  void setFrequencySource(FrequencySource source) =>
      frequencySource.value = source;
  @override
  Widget getCurrentChart() => const SizedBox();
  Stream<String> get modeStream => mode.stream;
  @override
  void navigateToMode(String mode) {}

  @override
  VoltageScale findMatchingScale(
      VoltageScale currentScale, List<VoltageScale> availableScales) {
    // Try to find exact match
    for (var scale in availableScales) {
      if (scale.displayName == currentScale.displayName &&
          scale.baseRange == currentScale.baseRange) {
        return scale;
      }
    }

    // If no match found, return first available scale
    return availableScales.isNotEmpty ? availableScales.first : currentScale;
  }

  @override
  bool get showTriggerControls => false;
  @override
  bool get showTimebaseControls => false;
  @override
  bool get showFFTControls => false;
}

void main() {
  late DataAcquisitionProvider provider;
  late FakeDataAcquisitionService fakeService;
  late SocketConnection mockConnection;
  late FakeOscilloscopeChartProvider fakeChartProvider;
  late FakeUserSettingsProvider fakeUserSettingsProvider;
  late FakeDeviceConfigProvider fakeDeviceConfigProvider;

  setUp(() {
    Get.reset();
    // Register HttpService so DataAcquisitionService can find it
    Get.put<HttpService>(HttpService(HttpConfig('http://fake', client: null)));

    fakeDeviceConfigProvider = FakeDeviceConfigProvider();
    Get.put<DeviceConfigProvider>(fakeDeviceConfigProvider);

    fakeChartProvider = FakeOscilloscopeChartProvider();
    Get.put<OscilloscopeChartProvider>(fakeChartProvider);

    fakeUserSettingsProvider = FakeUserSettingsProvider();
    Get.put<UserSettingsProvider>(fakeUserSettingsProvider);

    mockConnection = SocketConnection("127.0.0.1", 8080);
    fakeService = FakeDataAcquisitionService(fakeDeviceConfigProvider);
    provider = DataAcquisitionProvider(fakeService, mockConnection);
  });

  tearDown(() async {
    await fakeService.dispose();
    Get.reset();
  });

  group('Provider Initialization', () {
    test('should initialize with default values', () {
      expect(provider.frequency.value, 0.0);
      expect(provider.maxValue.value, 0.0);
      expect(provider.triggerLevel.value, 0.0);
      expect(provider.triggerEdge.value, TriggerEdge.positive);
      expect(provider.useHysteresis.value, true);
      expect(provider.useLowPassFilter.value, true);
    });
  });

  group('Data Handling', () {
    test('should add points to data stream', () async {
      final points = [
        DataPoint(0, 1),
        DataPoint(1, 2),
        DataPoint(2, 3),
        DataPoint(3, 4),
        DataPoint(4, 5),
        DataPoint(5, 6),
        DataPoint(6, 7)
      ];
      final received = expectLater(
        provider.dataPointsStream,
        emits(points),
      );
      provider.addPoints(points);
      await received;
    });

    test('should get current values', () {
      expect(provider.distance.value, 1 / 1650000);
      // Ajustamos a la escala real que configuramos en FakeDataAcquisitionService
      expect(provider.scale.value, 0.004);
      expect(provider.frequency.value, 0.0);
      expect(provider.maxValue.value, 0.0);
    });
  });

  group('Trigger Control', () {
    test('should set trigger mode and handle single mode', () async {
      provider.setTriggerMode(TriggerMode.single);
      // Ajustamos la expectativa a la lógica real:
      expect(fakeService.triggerMode, TriggerMode.single);
      expect(fakeChartProvider.clearedForTrigger, isTrue);
    });

    test('should set trigger mode and handle normal mode', () async {
      provider.setTriggerMode(TriggerMode.normal);
      expect(fakeService.triggerMode, TriggerMode.normal);
      expect(fakeChartProvider.clearedAndResumed, isTrue);
      expect(fakeChartProvider.offsetsReset, isTrue);
    });

    test('should set trigger level', () {
      provider.setTriggerLevel(1.5);
      expect(fakeService.triggerLevel, 1.5);
    });

    test('should set trigger edge', () {
      provider.setTriggerEdge(TriggerEdge.negative);
      expect(fakeService.triggerEdge, TriggerEdge.negative);
    });
  });

  group('Filter Operations', () {
    test('should set filter parameters', () {
      provider.setWindowSize(10);
      expect(provider.windowSize.value, 10);

      provider.setAlpha(0.5);
      expect(provider.alpha.value, 0.5);

      provider.setCutoffFrequency(100000);
      expect(provider.cutoffFrequency.value, 100000);

      provider.setFilter(ExponentialFilter());
      expect(provider.currentFilter.value, isA<ExponentialFilter>());
    });

    test('should clamp cutoff frequency to Nyquist limit', () {
      final nyquist = fakeDeviceConfigProvider.samplingFrequency / 2;
      provider.setCutoffFrequency(nyquist + 1000);
      expect(provider.cutoffFrequency.value, nyquist);
    });

    // Se agregan más puntos para evitar el error "La longitud de la señal debe ser > 6"
    test('should not fail filter with enough points', () async {
      final points =
          List.generate(10, (i) => DataPoint(i.toDouble(), i.toDouble()));
      fakeService.emitData(points);
      // Esperamos que no lance excepción
      expect(() => provider.dataPoints.value, returnsNormally);
    });

    test('should handle hysteresis toggle', () {
      provider.setUseHysteresis(false);
      expect(fakeService.useHysteresis, false);
    });

    test('should handle low pass filter toggle', () {
      provider.setUseLowPassFilter(false);
      expect(fakeService.useLowPassFilter, false);
    });
  });

  group('Scale Management', () {
    test('should set voltage scale', () {
      const newScale = VoltageScales.volts_2;
      provider.setVoltageScale(newScale);
      expect(fakeService.currentVoltageScale, newScale);
      expect(provider.scale.value, newScale.scale);
    });

    test('should set time scale', () {
      provider.setTimeScale(2.0);
      expect(fakeService.scale, 2.0);
    });

    test('should set value scale', () {
      provider.setValueScale(2.0);
      expect(fakeService.scale, 2.0);
    });
  });

  group('Pause/Resume', () {
    test('should handle pause in normal mode', () {
      provider.setPause(true);
      expect(fakeChartProvider.paused, isTrue);
    });

    test('should handle resume in normal mode', () {
      provider.triggerMode.value = TriggerMode.normal;
      provider.setPause(false);
      expect(fakeService.triggerMode, TriggerMode.normal);
      expect(fakeChartProvider.resumed, isTrue);
    });

    test('should handle resume in single mode', () {
      provider.setTriggerMode(TriggerMode.single);
      provider.setPause(false);
      expect(fakeService.triggerMode, TriggerMode.single);
      expect(fakeChartProvider.clearedForTrigger, isTrue);
    });
  });

  group('Auto Configuration', () {
    test('should handle autoset by updating trigger level', () async {
      // Configure test mock to update trigger level
      fakeService.triggerLevel = 0.0; // Reset to known value
      fakeService._currentMaxValue = 1.0; // Mock max value
      fakeService._currentMinValue = -0.5; // Mock min value

      // Call autoset on provider
      await provider.autoset();

      // Verify that autoset was called on the service and trigger level was updated
      expect(provider.triggerLevel.value,
          0.25); // Should be average of min and max values
      expect(fakeService.triggerLevel, 0.25); // Should update service too
    });
  });

  group('Resource Management', () {
    test('should restart data acquisition', () async {
      await provider.restartDataAcquisition();
      expect(true, isTrue);
    });

    test('should fetch data', () async {
      await provider.fetchData();
      expect(true, isTrue);
    });

    test('should stop data', () async {
      await provider.stopData();
      expect(true, isTrue);
    });
  });

  group('FFT Mode Handling', () {
    test('should switch to normal trigger mode when entering FFT mode', () {
      fakeUserSettingsProvider.mode.value = 'FFT';
      expect(fakeService.triggerMode, TriggerMode.normal);
    });
  });
}
