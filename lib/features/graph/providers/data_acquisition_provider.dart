import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:simple_kalman/simple_kalman.dart'; // Importar la librería
import 'dart:async';

/// [DataAcquisitionProvider] manages the acquisition, processing, and filtering of data for the oscilloscope and FFT charts.
class DataAcquisitionProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  final SocketConnection socketConnection;

  // Reactive variables
  final _dataPointsController = StreamController<List<DataPoint>>.broadcast();
  final dataPoints = Rx<List<DataPoint>>([]);
  final frequency = Rx<double>(1.0);
  final maxValue = Rx<double>(1.0);
  final triggerLevel = Rx<double>(0.0);
  final triggerEdge = Rx<TriggerEdge>(TriggerEdge.positive);
  final triggerMode = Rx<TriggerMode>(TriggerMode.normal);
  final timeScale = Rx<double>(1.0);
  final valueScale = Rx<double>(1.0);
  final maxX = Rx<double>(1.0);
  final samplingFrequency = Rx<double>(1650000);
  final distance = RxDouble(1 / 1650000);
  final scale = RxDouble(0);
  final currentFilter = Rx<FilterType>(LowPassFilter());
  final windowSize = RxInt(5);
  final alpha = RxDouble(0.2);
  final cutoffFrequency = RxDouble(100.0);
  final currentVoltageScale = Rx<VoltageScale>(VoltageScales.volt_1);
  final useHysteresis = true.obs;
  final useLowPassFilter = true.obs;
  final useDoubleFilt = true.obs; // Start with double filtering enabled
  final DeviceConfigProvider deviceConfig = Get.find<DeviceConfigProvider>();

  // Kalman filter instance
  final SimpleKalman kalman =
      SimpleKalman(errorMeasure: 256, errorEstimate: 150, q: 0.9);

  DataAcquisitionProvider(this.dataAcquisitionService, this.socketConnection) {
    // Update sampling frequency from device config
    samplingFrequency.value = deviceConfig.samplingFrequency;
    distance.value = 1 / deviceConfig.samplingFrequency;

    // Subscribe to streams
    dataAcquisitionService.dataStream.listen((points) {
      final filteredPoints = _applyFilter(points);
      dataPoints.value = filteredPoints;
      _dataPointsController.add(filteredPoints);
    });

    dataAcquisitionService.frequencyStream.listen((freq) {
      frequency.value = freq;
    });

    dataAcquisitionService.maxValueStream.listen((max) {
      maxValue.value = max;
    });

    // Observe changes in socket connection
    ever(socketConnection.ip, (_) => restartDataAcquisition());
    ever(socketConnection.port, (_) => restartDataAcquisition());
    deviceConfig.listen((config) {
      if (config != null) {
        samplingFrequency.value = config.samplingFrequency;
        distance.value = 1 / config.samplingFrequency;
        // Update cutoff frequency when sampling frequency changes
        if (currentFilter.value is LowPassFilter) {
          setCutoffFrequency(config.samplingFrequency / 2);
        }
      }
    });
    // Sync initial values
    triggerLevel.value = dataAcquisitionService.triggerLevel;
    triggerEdge.value = dataAcquisitionService.triggerEdge;
    distance.value = dataAcquisitionService.distance;
    scale.value = dataAcquisitionService.scale;
    currentVoltageScale.value = dataAcquisitionService.currentVoltageScale;
    dataAcquisitionService.useHysteresis = true;
    dataAcquisitionService.useLowPassFilter = true;
    triggerMode.value = dataAcquisitionService.triggerMode;
    // Initialize filter with Nyquist frequency from device config
    setFilter(LowPassFilter());
    setCutoffFrequency(deviceConfig.config!.samplingFrequency / 2);

    // Listen to mode changes to handle FFT switch
    ever(Get.find<UserSettingsProvider>().mode, (mode) {
      if (mode == 'FFT') {
        setTriggerMode(TriggerMode.normal);
      }
    });
  }

  /// Provides a stream of data points for the chart.
  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;
  double getDistance() => distance.value;
  double getScale() => scale.value;
  double getFrequency() => frequency.value;
  double getMaxValue() => maxValue.value;

  /// Adds a list of data points to the data stream.
  void addPoints(List<DataPoint> points) {
    dataPoints.value = points;
    _dataPointsController.add(points);
  }

  /// Restarts data acquisition by stopping and then re-fetching data.
  Future<void> restartDataAcquisition() async {
    await stopData();
    await fetchData();
  }

  /// Sets whether hysteresis is used for triggering.
  void setUseHysteresis(bool value) {
    useHysteresis.value = value;
    dataAcquisitionService.useHysteresis = value;
    if (kDebugMode) {
      print("Use hysteresis: $value");
    }
    dataAcquisitionService.updateConfig();
  }

  /// Sets whether the low pass filter is used.
  void setUseLowPassFilter(bool value) {
    useLowPassFilter.value = value;
    dataAcquisitionService.useLowPassFilter = value;
    if (kDebugMode) {
      print("Use low pass filter: $value");
    }
    dataAcquisitionService.updateConfig();
  }

  void setUseDoubleFilt(bool value) {
    useDoubleFilt.value = value;
  }

  /// Sets the voltage scale and updates related parameters.
  void setVoltageScale(VoltageScale scale) {
    currentVoltageScale.value = scale;

    // Update service scale
    dataAcquisitionService.setVoltageScale(scale);

    // Update reactive values
    this.scale.value = scale.scale;

    // Update trigger level after scale change
    triggerLevel.value = dataAcquisitionService.triggerLevel;

    // Force config update
    dataAcquisitionService.updateConfig();
  }

  /// Fetches data from the data acquisition service.
  Future<void> fetchData() async {
    await dataAcquisitionService.fetchData(
        socketConnection.ip.value, socketConnection.port.value);
  }

  /// Stops data acquisition.
  Future<void> stopData() async {
    // Ensure that sockets are closed correctly
    try {
      await dataAcquisitionService.stopData();
      await Future.delayed(
          const Duration(milliseconds: 100)); // Give time to close
    } catch (e) {
      if (kDebugMode) {
        print('Error stopping data: $e');
      }
    }
  }

  /// Sets the trigger mode and handles related actions.
  void setTriggerMode(TriggerMode mode) {
    if (kDebugMode) {
      print("Changing to $mode");
    }
    triggerMode.value = mode;
    dataAcquisitionService.triggerMode = mode;

    if (mode == TriggerMode.single) {
      // Reset the processing state in the isolate
      dataAcquisitionService.clearQueues();

      final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
      oscilloscopeChartProvider.clearForNewTrigger();
      _sendSingleTriggerRequest();
    } else if (mode == TriggerMode.normal) {
      _sendNormalTriggerRequest();
      final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
      oscilloscopeChartProvider.clearAndResume(); // Changed from just resume()
      oscilloscopeChartProvider.resetOffsets();
    }
  }

  /// Sends a single trigger request to the data acquisition service.
  Future<void> _sendSingleTriggerRequest() async {
    try {
      await dataAcquisitionService.sendSingleTriggerRequest();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending single trigger request: $e');
      }
    }
  }

  /// Sends a normal trigger request to the data acquisition service.
  Future<void> _sendNormalTriggerRequest() async {
    try {
      await dataAcquisitionService.sendNormalTriggerRequest();
    } catch (e) {
      if (kDebugMode) {
        print('Error sending normal trigger request: $e');
      }
    }
  }

  /// Sets the pause state of the data acquisition.
  void setPause(bool paused) {
    if (paused) {
      final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
      oscilloscopeChartProvider.pause();
    } else {
      if (triggerMode.value == TriggerMode.single) {
        dataAcquisitionService.clearQueues();
        final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
        oscilloscopeChartProvider.clearForNewTrigger();
        _sendSingleTriggerRequest();
      } else {
        _sendNormalTriggerRequest();
        final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
        oscilloscopeChartProvider.resume();
      }
    }
  }

  /// Automatically adjusts the time and value scales based on the data.
  Future<List<double>> autoset(double chartHeight, double chartWidth) async {
    final result =
        await dataAcquisitionService.autoset(chartHeight, chartWidth);

    // Update scales in line chart provider
    final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();
    oscilloscopeChartProvider.setTimeScale(result[0]);
    oscilloscopeChartProvider.setValueScale(result[1]);

    // Update trigger level
    triggerLevel.value = dataAcquisitionService.triggerLevel;

    return result;
  }

  /// Applies the selected filter to the data points.
  List<DataPoint> _applyFilter(List<DataPoint> points) {
    final params = {
      'windowSize': windowSize.value,
      'alpha': alpha.value,
      'cutoffFrequency': cutoffFrequency.value,
      'samplingFrequency': samplingFrequency.value
    };
    return currentFilter.value
        .apply(points, params, doubleFilt: useDoubleFilt.value);
  }

  /// Sets the current filter type.
  void setFilter(FilterType filter) {
    currentFilter.value = filter;
  }

  /// Sets the window size for the moving average filter.
  void setWindowSize(int size) {
    windowSize.value = size;
  }

  /// Sets the alpha value for the exponential filter.
  void setAlpha(double value) {
    alpha.value = value;
  }

  /// Sets the cutoff frequency for the low pass filter.
  /// Enforces Nyquist limit (samplingFrequency/2)
  void setCutoffFrequency(double freq) {
    // Calculate Nyquist limit
    final nyquistLimit = samplingFrequency.value / 2;

    // Clamp frequency to valid range (0 to nyquistLimit)
    final clampedFreq = freq.clamp(0.0, nyquistLimit);

    if (freq != clampedFreq && kDebugMode) {
      if (kDebugMode) {
        print(
            'Cutoff frequency clamped from $freq to $clampedFreq Hz (Nyquist limit)');
      }
    }

    cutoffFrequency.value = clampedFreq;
  }

  /// Sets the trigger level.
  void setTriggerLevel(double level) {
    triggerLevel.value = level;
    dataAcquisitionService.triggerLevel = level;
    if (kDebugMode) {
      print("Trigger level: $level");
    }
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  /// Sets the trigger edge.
  void setTriggerEdge(TriggerEdge edge) {
    triggerEdge.value = edge;
    dataAcquisitionService.triggerEdge = edge;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  /// Sets the time scale.
  void setTimeScale(double scale) {
    timeScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  /// Sets the value scale.
  void setValueScale(double scale) {
    valueScale.value = scale;
    dataAcquisitionService.scale = scale;
    dataAcquisitionService
        .updateConfig(); // Send updated config to processing isolate
  }

  @override
  void onClose() {
    stopData(); // Stop data acquisition when the controller is closed
    _dataPointsController.close();
    super.onClose();
  }
}
