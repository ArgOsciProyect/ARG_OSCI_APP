# System Architecture Overview

## Application Structure

The ARG_OSCI application implements an oscilloscope and spectrum analyzer using a layered architecture pattern. The application is organized into the following architectural layers:

### 1. Core Framework Layer

- **Main.dart**: Application entry point and bootstrap
- **Initializer.dart**: Dependency initialization and registration
- **AppTheme.dart**: Theme definition and visual styling

### 2. Service Layer

- **HttpService**: Manages HTTP communication with the device
- **SocketService**: Handles real-time data streaming via TCP sockets
- **DataAcquisitionService**: Acquires and processes raw signal data
- **OscilloscopeChartService**: Processes time-domain signal data
- **FFTChartService**: Performs frequency analysis using Fast Fourier Transform
- **SetupService**: Manages device connection and configuration

### 3. Provider Layer

- **DeviceConfigProvider**: Manages hardware configuration parameters
- **DataAcquisitionProvider**: Coordinates data collection and processing
- **OscilloscopeChartProvider**: Manages oscilloscope display state
- **FFTChartProvider**: Manages spectrum analyzer display state
- **UserSettingsProvider**: Handles user preferences and mode selection
- **SetupProvider**: Manages device setup workflow

### 4. UI Components

- **SetupScreen**: Initial connection and configuration interface
- **ModeSelectionScreen**: Visualization mode selection interface
- **GraphScreen**: Main visualization container
- **OscilloscopeChart**: Time-domain waveform visualization
- **FFTChart**: Frequency-domain spectrum visualization

### 5. Data Models

- **DataPoint**: Represents individual measurement points
- **VoltageScale**: Defines voltage measurement ranges
- **DeviceConfig**: Contains device hardware parameters
- **WiFiCredentials**: Manages network connection information
- **TriggerData**: Defines trigger parameters
- **GraphMode**: Represents visualization modes

### 6. Utilities

- **UnitFormat**: Formats values with appropriate SI units
- **FilterTypes**: Implements signal processing algorithms

## Data Flow Architecture

The application implements the following data flow:

1. **Acquisition**: Raw data packets arrive via socket connection
2. **Processing**: Data is converted to voltage values and processed through filters
3. **Analysis**: Signal parameters are extracted (frequency, amplitude)
4. **Visualization**: Processed data is rendered on appropriate charts
5. **User Interaction**: User controls modify acquisition and visualization parameters

## Component Relationships

Key component relationships include:

- **DataAcquisitionService → SocketService**: For raw data reception
- **ChartServices → DataAcquisitionProvider**: For processed data access
- **Providers → Services**: For business logic operations
- **UI Components → Providers**: For state access and updates
- **GraphScreen → UserSettingsProvider**: For mode selection and display configuration

## State Management

The application uses GetX for dependency injection and state management:

- Services and providers are registered as singletons during initialization
- Reactive (Rx) variables enable automatic UI updates
- Controllers manage component lifecycle events
- Navigation is handled through GetX router

## Initialization Sequence

1. Flutter bindings initialization
2. Device permissions request
3. Orientation configuration
4. Dependency registration (Initializer.dart)
5. UI rendering

## Cross-Component Communication

Components communicate through several mechanisms:

- Direct method calls for synchronous operations
- Stream-based communication for asynchronous data flow
- GetX dependency injection for component access
- Controller-based state management for UI updates

# Core Framework Layer

The Core Framework Layer establishes the application's foundation by handling initialization, theming, and bootstrap processes. This layer provides the essential structure upon which all other components are built.

## Main.dart

### Purpose

Main.dart serves as the entry point for the oscilloscope application, handling initial configuration and launching the user interface.

### Responsibilities

- Execute the application bootstrap sequence
- Configure device orientation and permissions
- Initialize the dependency injection system
- Apply application-wide theme settings
- Define the primary navigation routes

### Implementation

The file implements several sequential operations during startup:

```dart
void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeRight, DeviceOrientation.landscapeLeft]);
  if (Platform.isAndroid) {
    await requestPermissions();
  }
  await Initializer.init();
  runApp(MyApp());
}
```

The `MyApp` class configures the GetX navigation system with defined routes:

```dart
getPages: [
  GetPage(name: '/', page: () => SetupScreen()),
  GetPage(name: '/mode_selection', page: () => ModeSelectionScreen()),
  GetPage(name: '/graph', page: () => GraphScreen(graphMode: 'Oscilloscope')),
]
```

### Integration

Main.dart connects with:

- **Initializer.dart**: Called during startup to register dependencies
- **AppTheme.dart**: Applied to configure application appearance
- **SetupScreen**: Registered as the initial route for the application

## Initializer.dart

### Purpose

Initializer.dart establishes the dependency registration system for the application, creating and configuring all service and provider components.

### Responsibilities

- Register configuration objects
- Initialize service layer components
- Configure provider components
- Establish cross-component communication channels
- Ensure proper dependency resolution sequence

### Implementation

The `Initializer` class provides a single static `init()` method that orchestrates the initialization process in specific sequence:

1. Configuration Registration:

```dart
final httpConfig = HttpConfig('http://192.168.4.1:81');
final socketConnection = SocketConnection('192.168.4.1', 8080);
final deviceConfigProvider = DeviceConfigProvider();
```

2. Service Layer Initialization:

```dart
final httpService = HttpService(httpConfig);
final dataAcquisitionService = DataAcquisitionService(httpConfig);
final oscilloscopeChartService = OscilloscopeChartService();
final fftChartService = FFTChartService();
final setupService = SetupService(socketConnection, httpConfig);
```

3. Provider Layer Configuration:

```dart
final userSettingsProvider = UserSettingsProvider(oscilloscopeChartService, fftChartService);
final dataAcquisitionProvider = DataAcquisitionProvider(dataAcquisitionService, socketConnection);
final oscilloscopeChartProvider = OscilloscopeChartProvider(oscilloscopeChartService);
final fftChartProvider = FFTChartProvider(fftChartService);
final setupProvider = SetupProvider(setupService);
```

4. Cross-Component Integration:

```dart
oscilloscopeChartService.updateProvider(dataAcquisitionProvider);
fftChartService.updateProvider(dataAcquisitionProvider);
```

### Integration

Initializer.dart connects with:

- **All Services**: Creates and configures service instances
- **All Providers**: Establishes provider components with their dependencies
- **Main.dart**: Called during application startup

## AppTheme.dart

### Purpose

AppTheme.dart implements the visual design system for the application, providing theme definitions and context-aware styling.

### Responsibilities

- Define light and dark theme configurations
- Provide consistent color schemes across the application
- Supply context-aware styling methods for UI components
- Enable theme-specific visualization styling for charts

### Implementation

The file defines complete theme configurations for both light and dark modes:

```dart
static ThemeData lightTheme = ThemeData(
  brightness: Brightness.light,
  primarySwatch: Colors.blue,
  scaffoldBackgroundColor: Colors.white,
  // Additional properties...
);

static ThemeData darkTheme = ThemeData(
  brightness: Brightness.dark,
  primarySwatch: Colors.blue,
  scaffoldBackgroundColor: Colors.black,
  // Additional properties...
);
```

The class provides context-aware styling methods that examine the current theme:

```dart
static Paint getDataPaint(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Paint()
    ..color = isDark ? Colors.yellow : Colors.blue
    ..strokeWidth = 2;
}
```

### Integration

AppTheme.dart connects with:

- **Main.dart**: Provides theme data for application configuration
- **UI Components**: Supplies styling properties for visual elements
- **Chart Components**: Provides specialized painting styles for visualization

# Service Layer

The Service Layer implements the core business logic and data processing capabilities of the oscilloscope application. This layer mediates between the raw hardware interfaces and the higher-level UI components, providing specialized functionality for network communication, data acquisition, and signal processing.

## HttpService

### Purpose

HttpService implements a communication layer for HTTP-based interactions with the oscilloscope device, handling REST API calls for configuration and control.

### Responsibilities

- Execute HTTP requests to the device's API endpoints
- Handle connection errors with retry mechanisms
- Process HTTP responses and extract relevant data
- Manage navigation to setup screen on connection failures
- Provide a consistent interface for all HTTP operations

### Implementation

The service implements the HttpRepository interface with methods for different HTTP verbs:

```dart
Future<Map<String, dynamic>> get(String endpoint, {bool skipNavigation = false}) async {
  return _retryRequest(() async {
    final response = await _config.client.get(Uri.parse('${_config.baseUrl}/$endpoint'));
    return _handleResponse(response);
  }, endpoint, skipNavigation);
}
```

The retry mechanism implements exponential backoff for connection issues:

```dart
Future<T> _retryRequest<T>(Future<T> Function() request, String endpoint, bool skipNavigation) async {
  int retries = 0;
  while (retries < 5) {
    try {
      return await request();
    } catch (e) {
      retries++;
      if (retries >= 5) {
        if (!skipNavigation) {
          _navigateToSetupScreen(e.toString());
        }
        rethrow;
      }
      await Future.delayed(Duration(milliseconds: 200 * retries));
    }
  }
  throw Exception('Maximum retries exceeded for endpoint: $endpoint');
}
```

### Integration

HttpService connects with:

- **HttpConfig**: For base URL and client configuration
- **SetupScreen**: For navigation on connection failures
- **DataAcquisitionService**: As the HTTP communication channel
- **SetupService**: For device connection verification

## SocketService

### Purpose

SocketService manages real-time binary data transmission between the application and the oscilloscope device using TCP sockets.

### Responsibilities

- Establish and maintain socket connections
- Process incoming binary data packets
- Provide a subscription system for data consumers
- Track transmission performance statistics
- Handle connection errors and recovery

### Implementation

The service implements a data buffering system to handle partial packets:

```dart
void _processIncomingData(Uint8List data) {
  _buffer.addAll(data);
  
  while (_buffer.length >= _expectedPacketSize) {
    final packetBytes = _buffer.sublist(0, _expectedPacketSize);
    _buffer = _buffer.sublist(_expectedPacketSize);
    
    _bytesReceived += _expectedPacketSize;
    _packetsReceived++;
    
    _dataStreamController.add(packetBytes);
  }
}
```

It also implements comprehensive transmission statistics:

```dart
class TransmissionStats {
  final List<Measurement> _measurements = [];
  final Duration _retentionWindow = Duration(minutes: 15);
  
  void addMeasurement(Measurement measurement) {
    _measurements.add(measurement);
    _cleanupOldMeasurements();
  }
  
  double get meanBytesPerSecond {
    if (_measurements.isEmpty) return 0;
    return _measurements.fold<double>(0, (sum, m) => sum + m.bytesPerSecond) / _measurements.length;
  }
  
  // Additional statistical methods...
}
```

### Integration

SocketService connects with:

- **SocketConnection**: For connection parameters
- **DataAcquisitionService**: As the data source for signal processing
- **DataAcquisitionProvider**: For subscription management

## DataAcquisitionService

### Purpose

DataAcquisitionService processes raw binary data from the oscilloscope device, converting it into meaningful voltage measurements and implementing trigger detection.

### Responsibilities

- Receive binary data packets from the socket connection
- Convert raw ADC values to voltage measurements
- Apply trigger detection based on user-defined parameters
- Implement signal filtering and processing
- Distribute processed data to visualization components

### Implementation

The service implements a multi-isolate architecture for performance:

```dart
Future<void> _startSocketIsolate() async {
  final receivePort = ReceivePort();
  final setup = SocketIsolateSetup(
    sendPort: receivePort.sendPort,
    socketConnection: _socketConnection,
  );
  
  _socketIsolate = await Isolate.spawn(_socketIsolateEntryPoint, setup);
  
  _socketIsolateSendPort = await receivePort.first as SendPort;
  _setupSocketIsolateListener();
}
```

Trigger detection logic examines signal transitions:

```dart
bool _isTriggered(double prevValue, double currentValue, double triggerLevel, bool isPositive) {
  if (isPositive) {
    return prevValue < triggerLevel && currentValue >= triggerLevel;
  } else {
    return prevValue > triggerLevel && currentValue <= triggerLevel;
  }
}
```

### Integration

DataAcquisitionService connects with:

- **SocketService**: For raw data acquisition
- **HttpService**: For device configuration
- **DeviceConfigProvider**: For hardware parameters
- **OscilloscopeChartService**: For processed data delivery
- **FFTChartService**: For time-domain data for FFT analysis

## OscilloscopeChartService

### Purpose

OscilloscopeChartService implements time-domain signal processing and display management for the oscilloscope visualization.

### Responsibilities

- Process time-domain waveform data
- Manage trigger-based data flow for display
- Calculate optimal display scaling parameters
- Handle pause/resume functionality for waveform display
- Provide data streams for chart visualization

### Implementation

The service manages different trigger modes:

```dart
void _processDataPoints(List<DataPoint> points) {
  if (_isPaused) return;
  
  if (points.isNotEmpty) {
    // In Single trigger mode, pause after displaying triggered data
    if (points.any((p) => p.isTrigger) && _dataAcquisitionProvider?.triggerMode == TriggerMode.single) {
      _dataController.add(points);
      pause();
    } else {
      _dataController.add(points);
    }
  }
}
```

It also implements automatic scaling calculation:

```dart
Map<String, double> calculateAutosetScales(double frequency, double minValue, double maxValue) {
  // Calculate time scale to show approximately 3 periods
  final timeScale = frequency > 0 ? 3 / (frequency * _getDistance()) : 1.0;
  
  // Calculate value scale to fit signal in view with margin
  final range = maxValue - minValue;
  final valueScale = range > 0 ? 1.0 / (range * 1.2) : 1.0;
  
  // Calculate vertical center point
  final verticalOffset = (maxValue + minValue) / 2;
  
  return {
    'timeScale': timeScale,
    'valueScale': valueScale,
    'verticalOffset': verticalOffset,
  };
}
```

### Integration

OscilloscopeChartService connects with:

- **DataAcquisitionProvider**: As data source
- **OscilloscopeChartProvider**: For display state management
- **DeviceConfigProvider**: For time base calculation

## FFTChartService

### Purpose

FFTChartService performs Fast Fourier Transform analysis on time-domain signals to extract frequency-domain information for spectrum visualization.

### Responsibilities

- Collect time-domain samples for FFT processing
- Execute FFT algorithm to transform to frequency domain
- Detect frequency components in the signal
- Calculate magnitude and phase information
- Provide frequency-domain data for spectrum display

### Implementation

The core FFT algorithm implements the Cooley-Tukey radix-2 decimation-in-time approach:

```dart
void _fft(Float32List real, Float32List imag) {
  final n = real.length;
  
  // Bit reversal permutation
  var j = 0;
  for (var i = 0; i < n - 1; i++) {
    if (i < j) {
      // Swap elements
      var tempReal = real[i];
      var tempImag = imag[i];
      real[i] = real[j];
      imag[i] = imag[j];
      real[j] = tempReal;
      imag[j] = tempImag;
    }
    
    // Bit arithmetic for reversal index calculation
    var k = n >> 1;
    while (k <= j) {
      j -= k;
      k >>= 1;
    }
    j += k;
  }
  
  // Butterfly operations
  for (var step = 1; step < n; step <<= 1) {
    final angleStep = -math.pi / step;
    
    for (var group = 0; group < n; group += step * 2) {
      for (var pair = 0; pair < step; pair++) {
        final angle = angleStep * pair;
        final cosAngle = math.cos(angle);
        final sinAngle = math.sin(angle);
        
        final evenIndex = group + pair;
        final oddIndex = evenIndex + step;
        
        final oddReal = real[oddIndex];
        final oddImag = imag[oddIndex];
        
        final rotatedReal = oddReal * cosAngle - oddImag * sinAngle;
        final rotatedImag = oddReal * sinAngle + oddImag * cosAngle;
        
        real[oddIndex] = real[evenIndex] - rotatedReal;
        imag[oddIndex] = imag[evenIndex] - rotatedImag;
        real[evenIndex] = real[evenIndex] + rotatedReal;
        imag[evenIndex] = imag[evenIndex] + rotatedImag;
      }
    }
  }
}
```

Frequency detection examines the FFT output to find the fundamental frequency:

```dart
double _detectFrequency(List<DataPoint> fftPoints) {
  if (fftPoints.length < 3) return 0;
  
  // Find significant peak in spectrum
  double maxMagnitude = 0;
  int maxIndex = 0;
  
  // Skip DC component (index 0)
  for (int i = 1; i < fftPoints.length; i++) {
    if (fftPoints[i].y > maxMagnitude) {
      maxMagnitude = fftPoints[i].y;
      maxIndex = i;
    }
  }
  
  // Calculate frequency value from index
  final freqResolution = deviceConfig.samplingFrequency / (fftPoints.length * 2);
  return maxIndex * freqResolution;
}
```

### Integration

FFTChartService connects with:

- **DataAcquisitionProvider**: For time-domain data access
- **FFTChartProvider**: For display management
- **DeviceConfigProvider**: For sampling frequency information

## SetupService

### Purpose

SetupService manages the device connection and configuration process, handling WiFi setup and network transitions.

### Responsibilities

- Connect to the oscilloscope device's access point
- Scan for available WiFi networks
- Configure the device with external WiFi credentials
- Handle secure credential transmission
- Manage network transitions during setup
- Verify device connection after network changes

### Implementation

The service implements secure credential transmission:

```dart
Future<void> connectToWiFi(String ssid, String password) async {
  final publicKey = await _getPublicKey();
  
  final encryptedSsid = await encryptWithPublicKey(ssid, publicKey);
  final encryptedPassword = await encryptWithPublicKey(password, publicKey);
  
  final credentials = WiFiCredentials(ssid: encryptedSsid, password: encryptedPassword);
  
  await _httpService.post('connect', body: credentials.toJson());
}
```

Network scanning retrieves available access points:

```dart
Future<List<String>> scanForWiFiNetworks() async {
  final response = await _httpService.get('scan');
  
  if (response != null && response.containsKey('networks')) {
    final networks = List<String>.from(response['networks']);
    return networks;
  }
  
  return [];
}
```

### Integration

SetupService connects with:

- **HttpService**: For API communication
- **SocketConnection**: For connection parameters
- **NetworkInfoService**: For WiFi operations (on supported platforms)
- **SetupProvider**: For state management
- **SetupScreen**: As the UI component for device setup

# Provider Layer

The Provider Layer implements the state management and business logic coordination for the oscilloscope application. Using the GetX framework's reactive programming model, providers serve as intermediaries between UI components and services, maintaining application state and coordinating user interactions with the underlying functionality.

## DeviceConfigProvider

### Purpose

DeviceConfigProvider manages hardware configuration parameters for the oscilloscope device, providing a centralized repository of device capabilities and settings.

### Responsibilities

- Store and expose device hardware specifications
- Provide access to sampling rate and packet structure information
- Calculate bit masks and scaling factors for data processing
- Supply voltage scale definitions for measurement display
- Update configuration when device parameters change

### Implementation

The provider uses reactive state management to notify dependents of changes:

```dart
final _config = Rxn<DeviceConfig>();

DeviceConfig get config => _config.value ?? _getDefaultConfig();

double get samplingFrequency => config.samplingFrequency;
int get bitsPerPacket => config.bitsPerPacket;
int get dataMask => config.dataMask;
```

The provider calculates bit mask parameters for efficient data processing:

```dart
int get dataMaskTrailingZeros {
  final mask = config.dataMask;
  // Count trailing zeros in binary representation
  if (mask == 0) return 0;
  final binary = mask.toRadixString(2);
  int count = 0;
  for (int i = binary.length - 1; i >= 0; i--) {
    if (binary[i] == '0') {
      count++;
    } else {
      break;
    }
  }
  return count;
}
```

### Integration

DeviceConfigProvider connects with:

- **DataAcquisitionService**: Provides hardware parameters for data processing
- **Chart Services**: Provides sampling rate information for visualization
- **VoltageScale**: For ADC range parameters

## DataAcquisitionProvider

### Purpose

DataAcquisitionProvider coordinates data acquisition operations, acting as an intermediary between UI components and the data acquisition service.

### Responsibilities

- Collect real-time measurement data from hardware
- Apply signal processing filters to raw data
- Manage triggering configuration and modes
- Provide processed data streams to visualization components
- Control data acquisition start/stop

### Implementation

The provider implements a bidirectional synchronization mechanism to maintain consistency between UI state and service state:

```dart
void _syncValuesFromService() {
  _updatingFromService = true;
  try {
    triggerLevel.value = _service.triggerLevel;
    triggerEdge.value = _service.triggerEdge;
    useHysteresis.value = _service.useHysteresis;
  } finally {
    _updatingFromService = false;
  }
}

void _setupValueChangeListeners() {
  ever(triggerLevel, (value) {
    if (!_updatingFromService) {
      _service.triggerLevel = value;
    }
  });
  
  // Additional listeners...
}
```

The provider implements a flexible filtering system:

```dart
List<DataPoint> _applyFilter(List<DataPoint> points) {
  if (points.isEmpty || currentFilter.value == FilterType.noFilter) {
    return points;
  }
  
  final filter = currentFilter.value;
  final params = <String, dynamic>{};
  
  switch (filter.runtimeType) {
    case MovingAverageFilter:
      params['windowSize'] = windowSize.value;
      break;
    case ExponentialFilter:
      params['alpha'] = alpha.value;
      break;
    case LowPassFilter:
      params['cutoffFrequency'] = cutoffFrequency.value;
      params['samplingFrequency'] = _deviceConfigProvider.samplingFrequency;
      break;
  }
  
  return filter.apply(points, params);
}
```

### Integration

DataAcquisitionProvider connects with:

- **DataAcquisitionService**: For hardware communication
- **OscilloscopeChartProvider**: For waveform display
- **FFTChartProvider**: For frequency analysis
- **FilterTypes**: For signal processing

## OscilloscopeChartProvider

### Purpose

OscilloscopeChartProvider manages the state and behavior of the time-domain waveform visualization, handling user interactions and display preferences.

### Responsibilities

- Control the oscilloscope chart display parameters
- Implement zoom and pan functionality
- Process user gesture interactions
- Manage playback state (pause/resume)
- Calculate screen-to-domain coordinate transformations

### Implementation

The provider implements a comprehensive coordinate transformation system:

```dart
double domainToScreenX(double x) {
  return (x - horizontalOffset.value) * timeScale.value * _drawingWidth;
}

double domainToScreenY(double y) {
  return (verticalOffset.value - y) * valueScale.value * _drawingHeight / 2 + _drawingHeight / 2;
}

double screenToDomainX(double x) {
  return x / (timeScale.value * _drawingWidth) + horizontalOffset.value;
}

double screenToDomainY(double y) {
  return verticalOffset.value - (y - _drawingHeight / 2) * 2 / (valueScale.value * _drawingHeight);
}
```

It also manages zoom operations with proper focal point handling:

```dart
void handleZoom(double scaleFactor, Offset focalPoint) {
  // Calculate domain coordinates of focal point
  final domainX = screenToDomainX(focalPoint.dx);
  final domainY = screenToDomainY(focalPoint.dy);
  
  // Apply zoom factors
  setTimeScale(timeScale.value * scaleFactor);
  setValueScale(valueScale.value * scaleFactor);
  
  // Adjust offsets to keep focal point stationary
  final newDomainX = screenToDomainX(focalPoint.dx);
  final newDomainY = screenToDomainY(focalPoint.dy);
  
  setHorizontalOffset(horizontalOffset.value + (domainX - newDomainX));
  setVerticalOffset(verticalOffset.value + (domainY - newDomainY));
}
```

### Integration

OscilloscopeChartProvider connects with:

- **OscilloscopeChartService**: For data processing
- **OscilloscopeChart**: For UI visualization
- **DataAcquisitionProvider**: For trigger state

## FFTChartProvider

### Purpose

FFTChartProvider manages the state and behavior of the frequency-domain spectrum visualization, enabling spectrum analyzer functionality.

### Responsibilities

- Control FFT chart display parameters
- Manage frequency and amplitude scaling
- Process spectrum data for visualization
- Control frequency range visibility
- Implement auto-scaling for spectrum view

### Implementation

The provider implements automatic view optimization for frequency visualization:

```dart
void autoset() {
  // Get the detected fundamental frequency
  final detectedFreq = frequency.value > 0 
    ? frequency.value 
    : Get.find<DataAcquisitionProvider>().frequency.value;
    
  if (detectedFreq > 0) {
    // Calculate a scale that shows approximately 10x the fundamental frequency
    final targetRange = detectedFreq * 10;
    final nyquistFreq = Get.find<DeviceConfigProvider>().samplingFrequency / 2;
    
    // Set horizontal scale to show target frequency range
    final newTimeScale = nyquistFreq / targetRange;
    setTimeScale(newTimeScale);
    
    // Center the view on the fundamental frequency
    setHorizontalOffset(detectedFreq / 2);
    
    // Reset vertical scale to default
    setValueScale(1.0);
    resetVerticalOffset();
  }
}
```

The provider validates scale changes to maintain proper display constraints:

```dart
void setTimeScale(double scale) {
  // Clamp scale to reasonable bounds
  final clampedScale = scale.clamp(0.1, 100.0);
  timeScale.value = clampedScale;
  
  // Ensure horizontal offset remains valid with new scale
  _clampHorizontalOffset();
}
```

### Integration

FFTChartProvider connects with:

- **FFTChartService**: For spectrum analysis data
- **FFTChart**: For UI visualization
- **DeviceConfigProvider**: For frequency range limits

## UserSettingsProvider

### Purpose

UserSettingsProvider manages user preferences and handles switching between different visualization modes (oscilloscope and spectrum analyzer).

### Responsibilities

- Toggle between time and frequency domain visualizations
- Manage frequency measurement source selection
- Control chart display mode selection
- Coordinate service transitions during mode changes
- Provide UI configuration for mode-specific controls

### Implementation

The provider implements mode switching logic:

```dart
void setMode(String modeName) {
  final previousMode = mode.value;
  
  if (modeName == previousMode) return;
  
  final newMode = availableModes.firstWhere(
    (m) => m.name == modeName,
    orElse: () => availableModes[0]
  );
  
  mode.value = newMode.name;
  title.value = newMode.title;
  
  if (previousMode != null) {
    final oldMode = availableModes.firstWhere((m) => m.name == previousMode);
    oldMode.onDeactivate();
  }
  
  newMode.onActivate();
  _updateServices();
}
```

It also coordinates services based on the selected mode:

```dart
void _updateServices() {
  if (mode.value == oscilloscopeMode) {
    _oscilloscopeChartService.resume();
    _fftChartService.pause();
  } else if (mode.value == spectrumAnalizerMode) {
    _oscilloscopeChartService.pause();
    _fftChartService.resume();
  }
}
```

### Integration

UserSettingsProvider connects with:

- **OscilloscopeChartService**: For time-domain visualization
- **FFTChartService**: For frequency-domain visualization
- **GraphScreen**: For mode-specific UI configuration
- **GraphMode**: For visualization mode definitions

## SetupProvider

### Purpose

SetupProvider manages the device setup workflow, coordinating the connection and configuration process for the oscilloscope device.

### Responsibilities

- Guide the user through the device connection process
- Manage WiFi network discovery and selection
- Handle network transitions during setup
- Track setup process state and progress
- Handle setup errors and retries

### Implementation

The provider implements a state-based setup workflow:

```dart
void _updateState(SetupState Function(SetupState) updater) {
  state.value = updater(state.value);
}

Future<void> connectToLocalAP() async {
  _updateState((currentState) => currentState.copyWith(status: SetupStatus.connecting));
  
  try {
    await _setupService.connectToLocalAP();
    _updateState((currentState) => currentState.copyWith(status: SetupStatus.success));
  } catch (e) {
    _updateState((currentState) => 
      currentState.copyWith(
        status: SetupStatus.error,
        error: e.toString(),
        canRetry: true
      )
    );
    rethrow;
  }
}
```

The provider implements a retry mechanism for WiFi connections:

```dart
Future<void> connectToExternalAP(String ssid, String password) async {
  _updateState((currentState) => currentState.copyWith(
    status: SetupStatus.configuring,
    error: null
  ));
  
  int attempts = 0;
  const maxAttempts = 3;
  bool success = false;
  
  while (attempts < maxAttempts && !success) {
    try {
      await _setupService.connectToWiFi(ssid, password);
      success = true;
    } catch (e) {
      attempts++;
      if (attempts >= maxAttempts) {
        _updateState((currentState) => currentState.copyWith(
          status: SetupStatus.error,
          error: 'Failed to connect after $maxAttempts attempts: ${e.toString()}',
          canRetry: true
        ));
        rethrow;
      }
      await Future.delayed(Duration(seconds: 1));
    }
  }
  
  _updateState((currentState) => currentState.copyWith(
    status: SetupStatus.waitingForNetworkChange
  ));
}
```

### Integration

SetupProvider connects with:

- **SetupService**: For device connection operations
- **SetupScreen**: For UI state display
- **WiFiCredentials**: For network configuration data
- **ModeSelectionScreen**: For navigation after setup

# Data Models

The Data Models layer defines the core data structures that represent measurement values, device parameters, and configuration settings throughout the application. These models serve as the foundation for data exchange between different layers of the application.

## DataPoint

### Purpose

DataPoint represents an individual measurement point in both time-domain (oscilloscope) and frequency-domain (FFT) data, providing a consistent data structure for signal visualization.

### Responsibilities

- Store x-y coordinates for measurement values
- Indicate whether a point represents a trigger event
- Track whether a point was mathematically interpolated
- Support serialization for data exchange

### Implementation

The `DataPoint` class implements a simple but essential data structure:

```dart
class DataPoint {
  double x; // Time (seconds) or frequency (Hz) 
  final double y; // Voltage (volts) or magnitude (dB)
  final bool isTrigger; // Flag for trigger points
  final bool isInterpolated; // Flag for generated points

  DataPoint(this.x, this.y, {this.isTrigger = false, this.isInterpolated = false});

  factory DataPoint.fromJson(Map<String, dynamic> json) {
    return DataPoint(
      json['x'] as double,
      json['y'] as double,
      isTrigger: json['isTrigger'] as bool? ?? false,
      isInterpolated: json['isInterpolated'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'x': x,
      'y': y,
      'isTrigger': isTrigger,
      'isInterpolated': isInterpolated,
    };
  }
}
```

Only the x-coordinate is mutable, allowing for post-acquisition adjustments while preserving the actual measured value in the y-coordinate.

### Integration

DataPoint connects with:

- **DataAcquisitionService**: Created during data processing
- **Chart Services**: Processed through visualization pipelines
- **Chart Components**: Rendered on screen displays
- **FilterTypes**: Processed through signal processing algorithms

## VoltageScale

### Purpose

VoltageScale defines a specific voltage measurement range for the oscilloscope, enabling accurate signal amplitude display.

### Responsibilities

- Define voltage display ranges
- Calculate scaling factors for ADC conversion
- Provide user-friendly display names for UI components
- Handle equality comparison for selection operations

### Implementation

The class contains two primary components: a definition class and a repository of standard scales:

```dart
class VoltageScale {
  final double baseRange;
  final String displayName;

  VoltageScale({required this.baseRange, required this.displayName});

  double get scale {
    final deviceConfig = Get.find<DeviceConfigProvider>();
    final maxBits = deviceConfig.maxBits;
    final minBits = deviceConfig.minBits;
    final bitsRange = maxBits - minBits;
    
    // Calculate volts per bit
    return baseRange / bitsRange;
  }

  @override
  bool operator ==(Object other) =>
    identical(this, other) ||
    other is VoltageScale && baseRange == other.baseRange;

  @override
  int get hashCode => baseRange.hashCode;
}

class VoltageScales {
  static final List<VoltageScale> defaultScales = [
    VoltageScale(baseRange: 800, displayName: "400V, -400V"),
    VoltageScale(baseRange: 4, displayName: "2V, -2V"),
    // Additional scales...
  ];
}
```

The `scale` getter retrieves device configuration parameters and calculates the appropriate scaling factor to convert raw ADC values to physical voltage measurements.

### Integration

VoltageScale connects with:

- **DeviceConfigProvider**: For ADC range parameters
- **DataAcquisitionService**: For voltage conversion calculations
- **OscilloscopeChartProvider**: For display configuration
- **UI Components**: For scale selection in dropdowns

## DeviceConfig

### Purpose

DeviceConfig encapsulates the hardware specifications and capabilities of the oscilloscope device, providing a central model for device-specific parameters.

### Responsibilities

- Store sampling rate configuration
- Define data packet structure and bit masks
- Manage ADC range parameters
- Configure data processing settings
- Track available voltage scales

### Implementation

The `DeviceConfig` class implements a comprehensive parameter repository:

```dart
class DeviceConfig {
  final double _baseSamplingFrequency;
  final int dividingFactor;
  final int bitsPerPacket;
  final int samplesPerPacket;
  final int dataMask;
  final int channelMask;
  final int maxBits;
  final int midBits;
  final int discardHead;
  final int discardTrailer;
  final List<VoltageScale>? voltageScales;

  DeviceConfig({
    required double baseSamplingFrequency,
    this.dividingFactor = 1,
    required this.bitsPerPacket,
    required this.samplesPerPacket,
    required this.dataMask,
    required this.channelMask,
    required this.maxBits,
    required this.midBits,
    this.discardHead = 0,
    this.discardTrailer = 0,
    this.voltageScales,
  }) : _baseSamplingFrequency = baseSamplingFrequency;

  double get samplingFrequency => _baseSamplingFrequency / dividingFactor;
  
  int get minBits => midBits - (maxBits - midBits);

  DeviceConfig copyWith({
    double? baseSamplingFrequency,
    int? dividingFactor,
    // Additional parameters...
  }) {
    return DeviceConfig(
      baseSamplingFrequency: baseSamplingFrequency ?? this._baseSamplingFrequency,
      dividingFactor: dividingFactor ?? this.dividingFactor,
      // Copy remaining parameters...
    );
  }

  factory DeviceConfig.fromJson(Map<String, dynamic> json) {
    // Parse JSON configuration
    return DeviceConfig(
      baseSamplingFrequency: json['baseSamplingFrequency'],
      // Parse remaining parameters...
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'baseSamplingFrequency': _baseSamplingFrequency,
      // Serialize remaining parameters...
    };
  }
}
```

The class implements immutable update patterns through `copyWith()`, which returns a new instance with specific parameters changed.

### Integration

DeviceConfig connects with:

- **DeviceConfigProvider**: As the primary data model
- **DataAcquisitionService**: For data packet processing configuration
- **FFTChartService**: For sampling frequency information
- **OscilloscopeChartService**: For time base calculations

## WiFiCredentials

### Purpose

WiFiCredentials models the network authentication information for connecting the oscilloscope device to an external WiFi network.

### Responsibilities

- Store WiFi SSID (network name)
- Store WiFi password for authentication
- Support serialization for credential transmission
- Provide secure string representation for logging

### Implementation

The model implements a simple structure with serialization capabilities:

```dart
class WiFiCredentials {
  final String ssid;
  final String password;

  WiFiCredentials({required this.ssid, required this.password});

  factory WiFiCredentials.fromJson(Map<String, dynamic> json) {
    if (!json.containsKey('SSID') || !json.containsKey('Password')) {
      throw FormatException('Invalid WiFi credential format');
    }
    
    return WiFiCredentials(
      ssid: json['SSID'],
      password: json['Password'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'SSID': ssid,
      'Password': password,
    };
  }

  @override
  String toString() {
    return 'WiFiCredentials(ssid: $ssid, password: **hidden**)';
  }
}
```

The `toString()` method is overridden to hide the actual password, preventing accidental exposure in logs.

### Integration

WiFiCredentials connects with:

- **SetupService**: For transmitting credentials to the device
- **SetupProvider**: For managing credential transmission workflow
- **WiFiCredentialsDialog**: For user input collection

## TriggerData

### Purpose

TriggerData defines the trigger configuration options for the oscilloscope, establishing when and how the device captures waveforms.

### Responsibilities

- Define trigger edge direction options
- Define trigger mode options
- Provide type-safe enumeration of trigger parameters

### Implementation

The file implements two key enumerations:

```dart
enum TriggerEdge {
  positive,
  negative
}

enum TriggerMode {
  normal,
  single
}
```

These enumerations establish a type-safe way to express trigger configuration throughout the application.

### Integration

TriggerData connects with:

- **DataAcquisitionService**: For implementing trigger detection
- **DataAcquisitionProvider**: For managing trigger configuration
- **OscilloscopeChartService**: For controlling waveform display based on trigger events
- **UI Controls**: For user configuration of trigger parameters

## GraphMode

### Purpose

GraphMode defines the different visualization modes available in the application, enabling switching between time-domain and frequency-domain displays.

### Responsibilities

- Define available visualization modes
- Manage mode-specific UI configurations
- Control which chart components to display
- Handle mode transitions and lifecycle events

### Implementation

The file implements an abstract base class and concrete implementations for each mode:

```dart
abstract class GraphMode {
  String get name;
  String get title;
  Widget buildChart();
  bool get showTriggerControls;
  bool get showTimebaseControls;
  bool get showFFTControls;
  void onActivate();
  void onDeactivate();
}

class OscilloscopeMode implements GraphMode {
  final OscilloscopeChartService _oscilloscopeChartService;
  
  @override
  String get name => 'Oscilloscope';
  
  @override
  String get title => 'Oscilloscope';
  
  @override
  Widget buildChart() => OscilloscopeChart();
  
  @override
  bool get showTriggerControls => true;
  
  @override
  bool get showTimebaseControls => true;
  
  @override
  bool get showFFTControls => false;
  
  @override
  void onActivate() {
    _oscilloscopeChartService.resume();
  }
  
  @override
  void onDeactivate() {
    _oscilloscopeChartService.pause();
  }
}

class FFTMode implements GraphMode {
  // Similar implementation for FFT mode
}
```

This approach follows the Strategy pattern, allowing the application to switch between different visualization approaches with a consistent interface.

### Integration

GraphMode connects with:

- **UserSettingsProvider**: For mode selection management
- **GraphScreen**: For building the appropriate chart component
- **OscilloscopeChartService**: For oscilloscope mode activation/deactivation
- **FFTChartService**: For FFT mode activation/deactivation

# UI Components

The UI Components layer implements the visual interface of the oscilloscope application, providing screens for device setup, mode selection, and signal visualization. These components leverage the reactive state management from the Provider layer to create a responsive user experience that adapts to real-time data and user interactions.

## SetupScreen

### Purpose

SetupScreen serves as the entry point for the application, providing an interface for establishing connection with the oscilloscope device and configuring initial settings.

### Responsibilities

- Present initial setup options for device connection
- Handle WiFi configuration for device connectivity
- Manage theme selection options
- Process setup errors and provide recovery options
- Guide users through the multi-step setup process

### Implementation

The screen implements a stateful widget with lifecycle management:

```dart
class SetupScreen extends StatefulWidget {
  @override
  _SetupScreenState createState() => _SetupScreenState();
}

class _SetupScreenState extends State<SetupScreen> with WidgetsBindingObserver {
  final RxBool _isDarkMode = false.obs;
  
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _checkForErrors();
  }
}
```

Error handling is implemented through a systematic approach:

```dart
void _showErrorDialog(String error) {
  final errorCode = _extractErrorCode(error);
  
  Get.dialog(
    AlertDialog(
      title: Text('Connection Error'),
      content: Text('Error code: $errorCode\n\n$error'),
      actions: [
        TextButton(
          onPressed: () {
            Get.back();
            _cleanupAfterError();
          },
          child: Text('OK'),
        ),
      ],
    ),
  );
}

String _extractErrorCode(String error) {
  final regex = RegExp(r'Error\s+(\d+)');
  final match = regex.firstMatch(error);
  return match != null ? match.group(1) ?? 'Unknown' : 'Unknown';
}
```

### Integration

SetupScreen connects with:

- **SetupProvider**: For managing the device setup workflow
- **WiFiCredentialsDialog**: For collecting network credentials
- **AP_Selection_Dialog**: For selecting connection mode
- **ModeSelectionScreen**: For navigation after successful setup

## ModeSelectionScreen

### Purpose

ModeSelectionScreen enables users to choose between oscilloscope and spectrum analyzer visualization modes before entering the main graph display.

### Responsibilities

- Present available visualization modes to the user
- Handle mode selection and navigation
- Manage resource cleanup during transitions
- Provide backward navigation to setup
- Stop data acquisition when leaving the screen

### Implementation

The screen implements a clean selection interface:

```dart
class ModeSelectionScreen extends StatefulWidget {
  @override
  _ModeSelectionScreenState createState() => _ModeSelectionScreenState();
}

class _ModeSelectionScreenState extends State<ModeSelectionScreen> 
    with WidgetsBindingObserver {
  final dataAcquisitionProvider = Get.find<DataAcquisitionProvider>();
  final userSettingsProvider = Get.find<UserSettingsProvider>();
  final setupProvider = Get.find<SetupProvider>();
  
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Select Mode'),
        leading: IconButton(
          icon: Icon(Icons.arrow_back),
          onPressed: _navigateBackToSetup,
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Text(
                  'Select a visualization mode:',
                  style: Theme.of(context).textTheme.headline6,
                ),
              ),
              ...userSettingsProvider.availableModes.map((mode) => 
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: ElevatedButton(
                    onPressed: () => userSettingsProvider.navigateToMode(mode.name),
                    child: Text(mode.title),
                    style: ElevatedButton.styleFrom(
                      minimumSize: Size(double.infinity, 50),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
  
  void _navigateBackToSetup() {
    dataAcquisitionProvider.stopAcquisition();
    
    try {
      setupProvider.reset();
    } catch (e) {
      if (kDebugMode) {
        print('Error resetting setup state: $e');
      }
    }
    
    Get.offAll(() => SetupScreen());
  }
}
```

### Integration

ModeSelectionScreen connects with:

- **UserSettingsProvider**: For available modes and navigation
- **DataAcquisitionProvider**: For control of data acquisition
- **SetupProvider**: For state reset during backward navigation
- **GraphScreen**: For navigation after mode selection

## GraphScreen

### Purpose

GraphScreen serves as the main visualization container, providing a flexible display area for either time-domain or frequency-domain waveforms based on the selected mode.

### Responsibilities

- Display the appropriate chart for the current mode
- Provide mode-specific controls in a sidebar
- Handle screen layout and responsiveness
- Coordinate chart initialization and scaling
- Manage navigation and mode switching

### Implementation

The screen uses a factory constructor pattern for controlled initialization:

```dart
class GraphScreen extends StatelessWidget {
  final String graphMode;
  
  const GraphScreen._({required this.graphMode});
  
  factory GraphScreen({required String graphMode}) {
    final userSettingsProvider = Get.find<UserSettingsProvider>();
    final triggerLevelController = TextEditingController();
    
    // Register controller for disposal
    Get.put(triggerLevelController, tag: 'triggerLevelController');
    
    userSettingsProvider.setMode(graphMode);
    
    // Schedule autoset after first frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (graphMode == 'Oscilloscope') {
        Get.find<OscilloscopeChartProvider>().autoset();
      } else {
        Get.find<FFTChartProvider>().autoset();
      }
    });
    
    return GraphScreen._(graphMode: graphMode);
  }
  
  @override
  Widget build(BuildContext context) {
    final userSettingsProvider = Get.find<UserSettingsProvider>();
    
    return Scaffold(
      appBar: PreferredSize(
        preferredSize: Size.fromHeight(25),
        child: AppBar(
          title: Obx(() => FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(userSettingsProvider.title.value),
          )),
          leading: Transform.translate(
            offset: Offset(0, -5),
            child: IconButton(
              icon: Icon(Icons.arrow_back),
              onPressed: () => Get.back(),
            ),
          ),
        ),
      ),
      body: Row(
        children: [
          Expanded(
            child: Obx(() {
              final chart = userSettingsProvider.getCurrentChart();
              return chart ?? Center(child: CircularProgressIndicator());
            }),
          ),
          Container(
            width: 170,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  // Control panel components based on mode...
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
```

### Integration

GraphScreen connects with:

- **UserSettingsProvider**: For mode-specific display configuration
- **OscilloscopeChartProvider**: For time-domain visualization
- **FFTChartProvider**: For frequency-domain visualization
- **DataAcquisitionProvider**: For data access and control

## OscilloscopeChart

### Purpose

OscilloscopeChart implements the time-domain waveform visualization component, displaying real-time voltage measurements against time with interactive controls.

### Responsibilities

- Render time-domain voltage waveforms
- Process user interactions for zoom and pan
- Manage coordinate transformations
- Draw grid lines and axis labels
- Provide control panel for waveform display settings

### Implementation

The chart uses a custom painter for efficient rendering:

```dart
class OscilloscopeChartPainter extends CustomPainter {
  final List<DataPoint> points;
  final OscilloscopeChartProvider provider;
  final double width;
  final double height;
  final BuildContext context;
  
  // Paints for different chart elements
  late final Paint dataPaint;
  late final Paint zeroPaint;
  late final Paint gridPaint;
  late final Paint backgroundPaint;
  late final Paint borderPaint;
  
  OscilloscopeChartPainter({
    required this.points,
    required this.provider,
    required this.width,
    required this.height,
    required this.context,
  }) {
    dataPaint = AppTheme.getDataPaint(context);
    zeroPaint = AppTheme.getZeroPaint(context);
    gridPaint = AppTheme.getGridPaint(context);
    backgroundPaint = AppTheme.getChartBackgroundPaint(context);
    borderPaint = AppTheme.getBorderPaint(context);
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final drawingWidth = width;
    final drawingHeight = height;
    
    // Draw background and grid
    canvas.drawRect(
      Rect.fromLTWH(0, 0, drawingWidth, drawingHeight),
      backgroundPaint
    );
    
    _drawGrid(canvas, drawingWidth, drawingHeight);
    
    // Draw data points
    if (points.isEmpty) return;
    
    for (int i = 0; i < points.length - 1; i++) {
      final p1 = points[i];
      final p2 = points[i + 1];
      
      final x1 = _domainToScreenX(p1.x);
      final y1 = _domainToScreenY(p1.y);
      final x2 = _domainToScreenX(p2.x);
      final y2 = _domainToScreenY(p2.y);
      
      if (_isLineVisible(x1, y1, x2, y2, drawingWidth, drawingHeight)) {
        final clippedPoints = _clipLine(x1, y1, x2, y2, drawingWidth, drawingHeight);
        
        if (clippedPoints != null) {
          canvas.drawLine(
            Offset(clippedPoints[0], clippedPoints[1]),
            Offset(clippedPoints[2], clippedPoints[3]),
            p1.isTrigger ? zeroPaint : dataPaint
          );
        }
      }
    }
    
    // Draw border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, drawingWidth, drawingHeight),
      borderPaint
    );
  }
  
  // Coordinate transformation methods
  double _domainToScreenX(double x) => provider.domainToScreenX(x);
  double _domainToScreenY(double y) => provider.domainToScreenY(y);
  
  // Additional helper methods for grid drawing and line clipping...
}
```

The chart also implements user interactions through a gesture handler:

```dart
class _ChartGestureHandler extends StatelessWidget {
  final Widget child;
  final OscilloscopeChartProvider provider;
  
  const _ChartGestureHandler({
    required this.child,
    required this.provider,
  });
  
  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onScaleStart: (details) {
        if (details.pointerCount == 1) {
          provider.setInitialScales();
        }
      },
      onScaleUpdate: (details) {
        if (details.pointerCount == 1) {
          // Handle pan
          final dx = details.focalPointDelta.dx;
          final dy = details.focalPointDelta.dy;
          
          provider.setHorizontalOffset(
            provider.horizontalOffset.value - dx / (provider.timeScale.value * provider.drawingWidth)
          );
          
          provider.setVerticalOffset(
            provider.verticalOffset.value + dy * 2 / (provider.valueScale.value * provider.drawingHeight)
          );
        } else if (details.pointerCount == 2) {
          // Handle zoom
          provider.handleZoom(details.scale, details.localFocalPoint);
        }
      },
      child: MouseRegion(
        onMouseWheel: (event) {
          final scaleFactor = event.scrollDelta.dy > 0 ? 0.9 : 1.1;
          
          if (RawKeyboard.instance.isControlPressed) {
            // Horizontal zoom only
            provider.zoomX(scaleFactor, event.localPosition);
          } else if (RawKeyboard.instance.isShiftPressed) {
            // Vertical zoom only
            provider.zoomY(scaleFactor, event.localPosition);
          } else {
            // Zoom both axes
            provider.zoomXY(scaleFactor, event.localPosition);
          }
        },
        child: child,
      ),
    );
  }
}
```

### Integration

OscilloscopeChart connects with:

- **OscilloscopeChartProvider**: For data access and display state
- **DataAcquisitionProvider**: For trigger configuration
- **UnitFormat**: For axis label formatting
- **AppTheme**: For visual styling

## FFTChart

### Purpose

FFTChart implements the frequency-domain visualization component, displaying spectrum analysis of the signal with interactive controls for frequency examination.

### Responsibilities

- Render frequency-domain spectrum data
- Process user interactions for zoom and pan
- Draw frequency and amplitude axes with appropriate labels
- Provide control panel for spectrum display settings
- Enable frequency component analysis

### Implementation

The chart uses a custom painter for spectrum visualization:

```dart
class FFTChartPainter extends CustomPainter {
  final List<DataPoint> points;
  final FFTChartProvider provider;
  final double width;
  final double height;
  final BuildContext context;
  
  // Paints for different chart elements
  late final Paint dataPaint;
  late final Paint gridPaint;
  late final Paint backgroundPaint;
  late final Paint borderPaint;
  
  FFTChartPainter({
    required this.points,
    required this.provider,
    required this.width,
    required this.height,
    required this.context,
  }) {
    dataPaint = AppTheme.getFFTDataPaint(context);
    gridPaint = AppTheme.getGridPaint(context);
    backgroundPaint = AppTheme.getFFTBackgroundPaint(context);
    borderPaint = AppTheme.getBorderPaint(context);
  }
  
  @override
  void paint(Canvas canvas, Size size) {
    final drawingWidth = width;
    final drawingHeight = height;
    
    // Draw background and grid
    canvas.drawRect(
      Rect.fromLTWH(0, 0, drawingWidth, drawingHeight),
      backgroundPaint
    );
    
    _drawGrid(canvas, drawingWidth, drawingHeight);
    
    // Draw FFT data as a path
    if (points.isEmpty) return;
    
    final path = Path();
    var startX = _domainToScreenX(points[0].x);
    var startY = _domainToScreenY(points[0].y);
    
    startY = startY.clamp(0.0, drawingHeight);
    path.moveTo(startX, drawingHeight); // Start at bottom
    path.lineTo(startX, startY);        // Line up to first point
    
    for (int i = 1; i < points.length; i++) {
      final x = _domainToScreenX(points[i].x);
      var y = _domainToScreenY(points[i].y);
      
      // Clamp to visible area
      y = y.clamp(0.0, drawingHeight);
      
      if (x >= 0 && x <= drawingWidth) {
        path.lineTo(x, y);
      }
    }
    
    // Complete the path to form a closed shape
    final lastX = _domainToScreenX(points.last.x);
    path.lineTo(lastX, drawingHeight);
    path.close();
    
    // Draw the filled spectrum
    canvas.drawPath(path, dataPaint);
    
    // Draw border
    canvas.drawRect(
      Rect.fromLTWH(0, 0, drawingWidth, drawingHeight),
      borderPaint
    );
    
    // Draw frequency and magnitude labels
    _drawAxisLabels(canvas, drawingWidth, drawingHeight);
  }
  
  // Coordinate transformation methods
  double _domainToScreenX(double x) => provider.domainToScreenX(x);
  double _domainToScreenY(double y) => provider.domainToScreenY(y);
  
  // Additional helper methods for grid drawing and axis labels...
}
```

The chart includes specialized controls for spectrum analysis:

```dart
class _FFTControlPanel extends StatelessWidget {
  final FFTChartProvider provider;
  
  const _FFTControlPanel({required this.provider});
  
  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _PlayPauseButton(
          onPlayPause: () {
            if (provider.isPaused.value) {
              provider.resume();
            } else {
              provider.pause();
            }
          },
          isPaused: provider.isPaused,
        ),
        const SizedBox(height: 16),
        _ScaleControls(provider: provider),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: provider.autoset,
          child: Text('Autoset'),
        ),
        const SizedBox(height: 16),
        _OffsetControls(provider: provider),
      ],
    );
  }
}
```

### Integration

FFTChart connects with:

- **FFTChartProvider**: For spectrum data and display state
- **DataAcquisitionProvider**: For frequency information
- **UnitFormat**: For frequency and amplitude formatting
- **AppTheme**: For visual styling

# Utilities

The Utilities layer provides specialized helper classes and functions that support the oscilloscope application with specific technical capabilities. These utilities focus on discrete tasks like signal processing and measurement formatting, providing consistent functionality throughout the application.

## UnitFormat

### Purpose

UnitFormat implements a utility for formatting numerical values with appropriate SI (International System of Units) prefixes, ensuring consistent and readable measurement display.

### Responsibilities

- Format measurement values with appropriate SI unit prefixes
- Select the most appropriate metric prefix based on value magnitude
- Handle edge cases (zero, very small, very large values)
- Provide consistent decimal precision control
- Support different physical quantities (voltage, time, frequency)

### Implementation

The class uses a mapping of SI prefix exponents to symbols:

```dart
static const Map<int, String> _siPrefixes = {
  -12: 'p',  // pico
  -9: 'n',   // nano
  -6: 'μ',   // micro
  -3: 'm',   // milli
  0: '',     // base unit
  3: 'k',    // kilo
  6: 'M',    // mega
  9: 'G',    // giga
  12: 'T',   // tera
};
```

The main formatting method implements the SI prefix selection algorithm:

```dart
static String formatWithUnit(double value, String unit) {
  // Handle special cases
  if (value == 0) return '0 $unit';
  
  // Calculate magnitude
  final double absValue = value.abs();
  final int exponent = (math.log10(absValue) / 3).floor() * 3;
  
  // Check if the exponent is within our prefix range
  if (exponent < -12 || exponent > 12) {
    return value.toStringAsExponential(2) + ' $unit';
  }
  
  // Format with appropriate prefix
  final double scaledValue = value / math.pow(10, exponent);
  final String prefix = _siPrefixes[exponent] ?? '';
  
  // Format decimal places based on magnitude
  final String formattedValue = _formatDecimalPlaces(scaledValue);
  
  return '$formattedValue $prefix$unit';
}
```

The class also provides specialized formatting for different value types:

```dart
static String formatFrequency(double frequency) {
  return formatWithUnit(frequency, 'Hz');
}

static String formatVoltage(double voltage) {
  return formatWithUnit(voltage, 'V');
}

static String formatTime(double seconds) {
  return formatWithUnit(seconds, 's');
}
```

### Integration

UnitFormat connects with:

- **OscilloscopeChart**: For formatting time and voltage axis labels
- **FFTChart**: For formatting frequency and amplitude axis labels
- **UI Components**: For displaying measurement values in controls
- **DataAcquisitionProvider**: For formatting frequency and amplitude displays

## FilterTypes

### Purpose

FilterTypes implements a collection of digital signal processing filters that can be applied to waveform data for noise reduction and signal enhancement.

### Responsibilities

- Define a common interface for all filter types
- Implement various filtering algorithms (moving average, exponential, low pass)
- Process signal data points with minimal distortion
- Preserve important signal metadata during filtering
- Support dynamic parameter configuration

### Implementation

The file defines an abstract base class for all filters:

```dart
abstract class FilterType {
  const FilterType();
  String get name;
  
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params);
  
  @override
  String toString() => name;
}
```

Several concrete filter implementations are provided:

```dart
class NoFilter extends FilterType {
  static final NoFilter _instance = NoFilter._();
  
  factory NoFilter() => _instance;
  
  NoFilter._();
  
  @override
  String get name => 'No Filter';
  
  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    return points;
  }
}

class MovingAverageFilter extends FilterType with FiltfiltHelper {
  static final MovingAverageFilter _instance = MovingAverageFilter._();
  
  factory MovingAverageFilter() => _instance;
  
  MovingAverageFilter._();
  
  @override
  String get name => 'Moving Average';
  
  @override
  List<DataPoint> apply(List<DataPoint> points, Map<String, dynamic> params) {
    if (points.length < 3) return points;
    
    final windowSize = params['windowSize'] as int? ?? 5;
    if (windowSize < 2) return points;
    
    final yValues = Float32List.fromList(points.map((p) => p.y).toList());
    final result = _applyMovingAverage(yValues, windowSize);
    
    return List.generate(points.length, (i) {
      return DataPoint(
        points[i].x, 
        result[i],
        isTrigger: points[i].isTrigger,
        isInterpolated: points[i].isInterpolated
      );
    });
  }
  
  Float32List _applyMovingAverage(Float32List values, int windowSize) {
    final half = windowSize ~/ 2;
    final result = Float32List(values.length);
    
    for (int i = 0; i < values.length; i++) {
      double sum = 0;
      int count = 0;
      
      for (int j = i - half; j <= i + half; j++) {
        if (j >= 0 && j < values.length) {
          sum += values[j];
          count++;
        }
      }
      
      result[i] = sum / count;
    }
    
    return result;
  }
}
```

The file also implements a sophisticated bidirectional filtering helper:

```dart
mixin FiltfiltHelper {
  /// Applies forward-backward filtering for zero-phase distortion
  Float32List _filtfilt(Float32List x, List<double> b, List<double> a) {
    // Filter forward
    final y1 = _singleFilt(x, b, a);
    
    // Reverse the signal
    for (int i = 0; i < y1.length ~/ 2; i++) {
      final temp = y1[i];
      y1[i] = y1[y1.length - 1 - i];
      y1[y1.length - 1 - i] = temp;
    }
    
    // Filter reversed signal
    final y2 = _singleFilt(y1, b, a);
    
    // Reverse again to get final result
    for (int i = 0; i < y2.length ~/ 2; i++) {
      final temp = y2[i];
      y2[i] = y2[y2.length - 1 - i];
      y2[y2.length - 1 - i] = temp;
    }
    
    return y2;
  }
  
  // Implementation details for filter initialization and application...
}
```

### Integration

FilterTypes connects with:

- **DataAcquisitionProvider**: For configuring and applying filters
- **DataPoint**: For preserving trigger and interpolation flags
- **OscilloscopeChart**: For displaying filtered waveforms
- **UserSettingsProvider**: For filter selection UI

This concludes the documentation of all major components in the ARG_OSCI application. The document now provides a comprehensive overview of the system architecture and detailed information about each component's purpose, responsibilities, implementation, and integration points.
