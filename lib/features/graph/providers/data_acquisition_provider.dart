import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/models/voltage_scale.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/oscilloscope_chart_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/setup/screens/setup_screen.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'dart:async';

/// [DataAcquisitionProvider] manages the acquisition, processing, and filtering of data for the oscilloscope and FFT charts.
class DataAcquisitionProvider extends GetxController {
  final DataAcquisitionService dataAcquisitionService;
  final SocketConnection socketConnection;

  // Streams and controllers
  final _dataPointsController = StreamController<List<DataPoint>>.broadcast();
  final dataPoints = Rx<List<DataPoint>>([]);

  // Reactive values mirroring the service
  final frequency = RxDouble(0.0);
  final maxValue = RxDouble(0.0);
  final triggerLevel = RxDouble(0.0);
  final triggerEdge = Rx<TriggerEdge>(TriggerEdge.positive);
  final triggerMode = Rx<TriggerMode>(TriggerMode.normal);

  // Filter-related variables
  final currentFilter = Rx<FilterType>(LowPassFilter());
  final windowSize = RxInt(5);
  final alpha = RxDouble(0.2);
  final cutoffFrequency = RxDouble(100.0);
  final useDoubleFilt = true.obs;
  final isReconnecting = false.obs;

  // Direct getters from service
  DeviceConfigProvider get deviceConfig => Get.find<DeviceConfigProvider>();

  /// Get the current minimum value from service
  double get currentMinValue => dataAcquisitionService.currentMinValue;

  /// Reactive wrappers around service values
  final useHysteresis = RxBool(true);
  final useLowPassFilter = RxBool(true);
  final currentVoltageScale = Rx<VoltageScale>(VoltageScales.volt_1);
  final samplingFrequency = RxDouble(1650000);
  final distance = RxDouble(1 / 1650000);
  final scale = RxDouble(1.0);

  // Service sync flags with proper initialization
  bool _updatingFromService = false;
  bool _initialized = false;

  /// Provides a stream of data points for the chart
  Stream<List<DataPoint>> get dataPointsStream => _dataPointsController.stream;

  /// Return the current distance between data points
  double get getDistance => dataAcquisitionService.distance;

  /// Return the current scale factor
  double get getScale => dataAcquisitionService.scale;

  /// Return the current frequency
  double get getFrequency => frequency.value;

  /// Return the current maximum value
  double get getMaxValue => maxValue.value;

  DataAcquisitionProvider(this.dataAcquisitionService, this.socketConnection) {
    if (kDebugMode) {
      print("Initializing DataAcquisitionProvider");
    }

    // Initialize with values from device config
    samplingFrequency.value = deviceConfig.samplingFrequency;
    distance.value = 1 / samplingFrequency.value;

    // First sync from service to ensure initial values match
    _syncValuesFromService();

    // Now set up listeners
    _setupValueChangeListeners();
    _setupStreamSubscriptions();
    _setupConfigListeners();
    _setupConnectionListeners();
    _setupModeChangeListener();

    // Mark as initialized
    _initialized = true;
  }

  // MARK: - Initialization Methods

  /// Sets up the value change listeners to update service when provider values change
  void _setupValueChangeListeners() {
    // When provider values change, update service
    ever(triggerLevel, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.triggerLevel = triggerLevel.value;
        if (kDebugMode) {
          print("Provider → Service: triggerLevel = ${triggerLevel.value}");
        }
      }
    });

    ever(triggerEdge, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.triggerEdge = triggerEdge.value;
        if (kDebugMode) {
          print("Provider → Service: triggerEdge = ${triggerEdge.value}");
        }
      }
    });

    ever(triggerMode, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.triggerMode = triggerMode.value;
        if (kDebugMode) {
          print("Provider → Service: triggerMode = ${triggerMode.value}");
        }
      }
    });

    ever(useHysteresis, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.useHysteresis = useHysteresis.value;
        if (kDebugMode) {
          print("Provider → Service: useHysteresis = ${useHysteresis.value}");
        }
      }
    });

    ever(useLowPassFilter, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.useLowPassFilter = useLowPassFilter.value;
        if (kDebugMode) {
          print(
              "Provider → Service: useLowPassFilter = ${useLowPassFilter.value}");
        }
      }
    });

    ever(scale, (_) {
      if (!_updatingFromService && _initialized) {
        dataAcquisitionService.scale = scale.value;
        if (kDebugMode) {
          print("Provider → Service: scale = ${scale.value}");
        }
      }
    });

    ever(currentVoltageScale, (_) {
      if (!_updatingFromService && _initialized) {
        setVoltageScale(currentVoltageScale.value);
      }
    });
  }

  /// Sets up the stream subscriptions to the data acquisition service
  void _setupStreamSubscriptions() {
    // Listen for data points
    dataAcquisitionService.dataStream.listen((points) {
      final filteredPoints = _applyFilter(points);
      dataPoints.value = filteredPoints;
      _dataPointsController.add(filteredPoints);
    }, onError: (e) {
      if (kDebugMode) {
        print("Error from data stream: $e");
      }
    });

    // Listen for frequency updates
    dataAcquisitionService.frequencyStream.listen((freq) {
      frequency.value = freq;
    }, onError: (e) {
      if (kDebugMode) {
        print("Error from frequency stream: $e");
      }
    });

    // Listen for max value updates
    dataAcquisitionService.maxValueStream.listen((max) {
      maxValue.value = max;
    }, onError: (e) {
      if (kDebugMode) {
        print("Error from max value stream: $e");
      }
    });

    if (kDebugMode) {
      print("Stream subscriptions established in DataAcquisitionProvider");
    }
  }

  /// Set up config change listeners
  void _setupConfigListeners() {
    deviceConfig.listen((config) {
      if (config != null) {
        // Update frequency-related values
        samplingFrequency.value = config.samplingFrequency;
        distance.value = 1 / config.samplingFrequency;
        setCutoffFrequency(config.samplingFrequency / 2);

        // Ensure voltage scale is valid with new config
        _validateAndUpdateVoltageScale();

        if (kDebugMode) {
          print(
              "Device config updated: samplingFrequency=${config.samplingFrequency}, distance=${distance.value}");
        }
      }
    });
  }

  /// Set up socket connection listeners
  void _setupConnectionListeners() {
    ever(socketConnection.ip, (_) {
      if (kDebugMode) {
        print("Socket IP changed, restarting data acquisition");
      }
      restartDataAcquisition();
    });
    ever(socketConnection.port, (_) {
      if (kDebugMode) {
        print("Socket port changed, restarting data acquisition");
      }
      restartDataAcquisition();
    });
  }

  /// Sync values from service to provider
  void _syncValuesFromService() {
    _updatingFromService = true;

    try {
      // First get the voltage scale from service and set in provider
      currentVoltageScale.value = dataAcquisitionService.currentVoltageScale;

      // Get other values that depend on scale
      triggerLevel.value = dataAcquisitionService.triggerLevel;
      scale.value = dataAcquisitionService.scale;

      // Get remaining values
      triggerEdge.value = dataAcquisitionService.triggerEdge;
      triggerMode.value = dataAcquisitionService.triggerMode;
      distance.value = dataAcquisitionService.distance;
      useHysteresis.value = dataAcquisitionService.useHysteresis;
      useLowPassFilter.value = dataAcquisitionService.useLowPassFilter;

      if (kDebugMode) {
        print("Values synced from service:");
        print(
            "  currentVoltageScale: ${currentVoltageScale.value.displayName}");
        print("  scale: ${scale.value}");
        print("  triggerLevel: ${triggerLevel.value}");
        print("  triggerEdge: ${triggerEdge.value}");
        print("  triggerMode: ${triggerMode.value}");
        print("  distance: ${distance.value}");
        print("  useHysteresis: ${useHysteresis.value}");
        print("  useLowPassFilter: ${useLowPassFilter.value}");
      }
    } catch (e) {
      if (kDebugMode) {
        print("Error syncing values from service: $e");
      }
    } finally {
      _updatingFromService = false;
    }

    // Set initial filter
    setFilter(LowPassFilter());
    setCutoffFrequency(deviceConfig.samplingFrequency / 2);
  }

  /// Set up mode change listener
  void _setupModeChangeListener() {
    try {
      ever(Get.find<UserSettingsProvider>().mode, (mode) {
        if (mode == 'FFT') {
          setTriggerMode(TriggerMode.normal);
        }
      });
    } catch (e) {
      if (kDebugMode) {
        print("Error setting up mode change listener: $e");
      }
    }
  }

  /// Validate current voltage scale against available scales and update if needed
  void _validateAndUpdateVoltageScale() {
    final newScales = deviceConfig.voltageScales;
    bool scaleExists = newScales.any((scale) =>
        scale.baseRange == currentVoltageScale.value.baseRange &&
        scale.displayName == currentVoltageScale.value.displayName);

    if (!scaleExists && newScales.isNotEmpty) {
      setVoltageScale(newScales.first);
      if (kDebugMode) {
        print(
            "Voltage scale updated to ${newScales.first.displayName} (previous scale not found)");
      }
    } else if (scaleExists) {
      // Find the matching scale and reapply to ensure consistency
      final matchingScale = newScales.firstWhere((scale) =>
          scale.baseRange == currentVoltageScale.value.baseRange &&
          scale.displayName == currentVoltageScale.value.displayName);

      setVoltageScale(matchingScale);
      if (kDebugMode) {
        print("Reapplied voltage scale: ${matchingScale.displayName}");
      }
    }
  }

  // MARK: - Public Methods

  /// Adds a list of data points to the data stream.
  void addPoints(List<DataPoint> points) {
    dataPoints.value = points;
    _dataPointsController.add(points);
  }

  /// Restarts data acquisition by stopping and then re-fetching data.
  Future<void> restartDataAcquisition() async {
    await stopData();
    // Ensure value sync before restarting
    _syncValuesFromService();
    _setupStreamSubscriptions();
    await fetchData();
  }

  /// Sets whether hysteresis is used for triggering.
  void setUseHysteresis(bool value) {
    useHysteresis.value = value;
    if (kDebugMode) {
      print("Setting use hysteresis: $value");
    }
  }

  /// Handles critical errors by navigating to the setup screen.
  void handleCriticalError(String errorMessage) {
    if (isReconnecting.value) return;
    isReconnecting.value = true;

    if (kDebugMode) {
      print('CRITICAL ERROR: $errorMessage - Navigating to setup screen');
    }

    // Stop data acquisition
    stopData().then((_) {
      isReconnecting.value = false;
      Get.offAll(() => const SetupScreen(),
          arguments: {'showErrorPopup': true, 'errorMessage': errorMessage});
    }).catchError((e) {
      if (kDebugMode) {
        print('Error stopping data during critical error: $e');
      }
      isReconnecting.value = false;
      Get.offAll(() => const SetupScreen(), arguments: {
        'showErrorPopup': true,
        'errorMessage': '$errorMessage (Failed to clean up: $e)'
      });
    });
  }

  /// Sets whether the low pass filter is used.
  void setUseLowPassFilter(bool value) {
    useLowPassFilter.value = value;
    if (kDebugMode) {
      print("Setting use low pass filter: $value");
    }
  }

  /// Sets whether double filtering is used.
  void setUseDoubleFilt(bool value) {
    useDoubleFilt.value = value;
  }

  /// Sets the voltage scale and updates related parameters.
  void setVoltageScale(VoltageScale scale) {
    if (_updatingFromService) return;

    if (kDebugMode) {
      print("Setting voltage scale: ${scale.displayName}");
    }

    currentVoltageScale.value = scale;
    dataAcquisitionService.setVoltageScale(scale);

    // Update provider's scale value to match service
    this.scale.value = dataAcquisitionService.scale;

    // Update trigger level from service to ensure consistency
    _updatingFromService = true;
    triggerLevel.value = dataAcquisitionService.triggerLevel;
    _updatingFromService = false;
  }

  /// Fetches data from the data acquisition service.
  Future<void> fetchData() async {
    isReconnecting.value = false;
    await dataAcquisitionService.fetchData(
        socketConnection.ip.value, socketConnection.port.value);
  }

  /// Stops data acquisition.
  Future<void> stopData() async {
    try {
      await dataAcquisitionService.stopData();
      await Future.delayed(const Duration(milliseconds: 100));
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

    final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();

    if (mode == TriggerMode.single) {
      dataAcquisitionService.clearQueues();
      oscilloscopeChartProvider.clearForNewTrigger();
      _sendSingleTriggerRequest();
    } else if (mode == TriggerMode.normal) {
      _sendNormalTriggerRequest();
      oscilloscopeChartProvider.clearAndResume();
      oscilloscopeChartProvider.resetOffsets();
    }
  }

  /// Sets the pause state of the data acquisition.
  void setPause(bool paused) {
    final oscilloscopeChartProvider = Get.find<OscilloscopeChartProvider>();

    if (paused) {
      oscilloscopeChartProvider.pause();
    } else {
      if (triggerMode.value == TriggerMode.single) {
        dataAcquisitionService.clearQueues();
        oscilloscopeChartProvider.clearForNewTrigger();
        _sendSingleTriggerRequest();
      } else {
        _sendNormalTriggerRequest();
        oscilloscopeChartProvider.resume();
      }
    }
  }

  /// Automatically adjusts internal settings like trigger level based on the data.
  Future<void> autoset() async {
    await dataAcquisitionService.autoset();
    triggerLevel.value = dataAcquisitionService.triggerLevel;
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
  void setCutoffFrequency(double freq) {
    // Calculate Nyquist limit
    final nyquistLimit = samplingFrequency.value / 2;
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
  }

  /// Sets the trigger edge.
  void setTriggerEdge(TriggerEdge edge) {
    triggerEdge.value = edge;
    dataAcquisitionService.triggerEdge = edge;
  }

  /// Sets the time scale.
  void setTimeScale(double scale) {
    dataAcquisitionService.scale = scale;
    this.scale.value = scale;
  }

  /// Increases the sampling frequency.
  Future<void> increaseSamplingFrequency() async {
    await dataAcquisitionService.increaseSamplingFrequency();
  }

  /// Decreases the sampling frequency.
  Future<void> decreaseSamplingFrequency() async {
    await dataAcquisitionService.decreaseSamplingFrequency();
  }

  /// Sets the value scale.
  void setValueScale(double scale) {
    dataAcquisitionService.scale = scale;
    this.scale.value = scale;
  }

  // MARK: - Private Helper Methods

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

  @override
  void onClose() {
    _initialized = false;
    stopData().then((_) {
      if (kDebugMode) {
        print('Data acquisition stopped on provider close');
      }
    });
    _dataPointsController.close();
    super.onClose();
  }
}
