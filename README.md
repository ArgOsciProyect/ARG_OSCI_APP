# ARG_OSCI App Technical Implementation Guide

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

**ARG_OSCI App** is the software component of the open-source portable oscilloscope platform. This document provides a technical overview of the app's architecture, design decisions, and implementation details. It is intended for engineers and advanced users interested in understanding, building, or modifying the application.

---

## Table of Contents
- [Introduction](#introduction)
- [Design Overview](#design-overview)
- [Architecture and Main Components](#architecture-and-main-components)
  - [1. Initialization and Dependency Management](#1-initialization-and-dependency-management)
  - [2. Theming and UI System](#2-theming-and-ui-system)
  - [3. Application Startup and Navigation](#3-application-startup-and-navigation)
  - [4. Device Setup and State Management](#4-device-setup-and-state-management)
  - [5. Networking and Communication](#5-networking-and-communication)
  - [6. Data Acquisition and Processing](#6-data-acquisition-and-processing)
  - [7. Visualization Modes and Charting](#7-visualization-modes-and-charting)
  - [8. Configuration and Utility Modules](#8-configuration-and-utility-modules)
- [Build and Run Process](#build-and-run-process)
- [Extending and Contributing](#extending-and-contributing)
- [License](#license)
- [Acknowledgements](#acknowledgements)

---

## Introduction

This document describes the implementation of the ARG_OSCI app, including the rationale behind each software block, technical notes, and suggestions for further development. For usage instructions, refer to the user manual. For more precise technical details, see the comments in the source code files.

---

## Design Overview

The app is organized into several functional modules:
- Initialization and Dependency Injection (GetX)
- Theming and UI (light/dark mode, context-aware styling)
- Application Startup and Navigation (routing, permissions, orientation)
- Device Setup and State Management (WiFi, configuration, error handling)
- Networking and Communication (HTTP, sockets)
- Data Acquisition and Processing (multi-isolate, signal processing)
- Visualization Modes and Charting (oscilloscope, FFT)
- Configuration and Utility Modules (unit formatting, voltage scales, etc.)

---

## Architecture and Main Components

### 1. Initialization and Dependency Management

- Centralized in `Initializer.dart`.
- Uses GetX for dependency injection and singleton management.
- Initialization sequence:
  1. Flutter binding initialization (`WidgetsFlutterBinding.ensureInitialized()`)
  2. Configuration objects setup: `HttpConfig`, `SocketConnection`, `DeviceConfigProvider`
  3. Service layer initialization: `HttpService`, `DataAcquisitionService`, `OscilloscopeChartService`, `FFTChartService`, `SetupService`
  4. Provider layer configuration: `UserSettingsProvider`, `DataAcquisitionProvider`, `OscilloscopeChartProvider`, `FFTChartProvider`, `SetupProvider`
  5. Cross-component integration: chart services are connected to their data providers
- Error handling is implemented to catch and log initialization errors.

**Example:**
```dart
try {
  // Initialization code
} catch (e) {
  if (kDebugMode) {
    print('Error during initialization: $e');
  }
  rethrow;
}
```

---

### 2. Theming and UI System

- Defined in `AppTheme.dart`.
- Provides light and dark `ThemeData` configurations.
- Centralizes color schemes, text styles, and context-aware styling methods.
- Exposes static methods for theme-dependent paints and colors (e.g., waveform, chart backgrounds, icons).
- Enables dynamic theme switching and consistent visual identity.

**Example:**
```dart
static Paint getDataPaint(BuildContext context) {
  final isDark = Theme.of(context).brightness == Brightness.dark;
  return Paint()
    ..color = isDark ? Colors.yellow : Colors.blue
    ..strokeWidth = 2;
}
```

---

### 3. Application Startup and Navigation

- Entry point in `main.dart`.
- Startup sequence:
  1. Flutter binding initialization
  2. Orientation lock (landscape)
  3. Permission requests (location, WiFi)
  4. Dependency initialization (`Initializer.init()`)
  5. UI rendering (`runApp(MyApp())`)
- Navigation is managed with GetX routes:
  - `/` → SetupScreen
  - `/mode_selection` → ModeSelectionScreen
  - `/graph` → GraphScreen (oscilloscope or spectrum analyzer)
- Theming is applied at the app level, with light mode as default.

**Example:**
```dart
GetMaterialApp(
  debugShowCheckedModeBanner: false,
  title: 'ARG_OSCI',
  theme: AppTheme.lightTheme,
  darkTheme: AppTheme.darkTheme,
  themeMode: ThemeMode.light,
  home: SetupScreen(),
  getPages: [...],
);
```

---

### 4. Device Setup and State Management

- Managed by `SetupProvider.dart` and related dialogs/screens.
- Uses GetX for reactive state management.
- Handles:
  - Connection to device AP
  - WiFi network scanning and selection
  - Secure credential transmission (RSA encryption)
  - State transitions (connecting, scanning, configuring, waiting, error, success)
  - Retry logic and error handling
- UI components consume the reactive state to display progress, errors, and options.

**Example:**
```dart
// SetupStatus enum
initial, connecting, scanning, selecting, configuring, waitingForNetworkChange, error, success, completed
```

---

### 5. Networking and Communication

- HTTP communication handled by `HttpService.dart` using `HttpConfig`.
- Socket communication managed by `SocketService.dart` and `SocketConnection`.
- Robust error handling, retry mechanisms, and navigation to setup screen on persistent errors.
- Secure endpoints for device configuration (public key retrieval, encrypted credential transmission).

**Example:**
```dart
// HTTP GET with retry
await _retryRequest(() => client.get(url), skipNavigation: false);
```

---

### 6. Data Acquisition and Processing

- Core logic in `DataAcquisitionService.dart`.
- Multi-isolate architecture:
  - Main isolate: orchestrates operation and UI
  - Socket isolate: handles network communication
  - Processing isolate: performs signal processing and trigger detection
- Advanced triggering system (normal/single, edge selection, hysteresis)
- Stream-based data flow for real-time waveform and frequency data
- Error handling and resource management for robust operation

**Example:**
```dart
// Data pipeline
Socket isolate → Processing isolate → Main isolate → UI
```

---

### 7. Visualization Modes and Charting

- Visualization modes defined in `graph_mode.dart`:
  - Oscilloscope (time-domain)
  - FFT/Spectrum Analyzer (frequency-domain)
- Chart providers and services:
  - `OscilloscopeChartProvider`/`OscilloscopeChartService`
  - `FFTChartProvider`/`FFTChartService`
- Chart widgets:
  - `OscilloscopeChart.dart`: time-domain waveform display
  - `FFTChart.dart`: frequency-domain spectrum display
- Features:
  - Zooming, panning, autoset, trigger controls
  - Context-aware UI controls and scaling
  - Efficient rendering and coordinate transformations

---

### 8. Configuration and Utility Modules

- Device configuration: `DeviceConfigProvider.dart`, `device_config.dart`
- Voltage scaling: `voltage_scale.dart`
- Unit formatting: `unit_format.dart` (SI prefixes, auto-scaling)
- Data models: `data_point.dart`, `WiFiCredentials.dart`, etc.
- Trigger configuration: `trigger_data.dart`
- Filter types: `filter_types.dart` (moving average, exponential, low-pass, etc.)

**Example:**
```dart
// Voltage scale calculation
final scale = baseRange / (maxBits - minBits);
```

---

## Build and Run Process

- The app is a Flutter project. To build and run:
  1. Ensure Flutter and Dart SDK are installed.
  2. Run `flutter pub get` to fetch dependencies.
  3. Use `flutter run` to build and launch the app on a device or emulator.
  4. For platform-specific features (e.g., WiFi permissions), test on a real device.

---

## Extending and Contributing

- The app is modular and uses GetX for state management and dependency injection.
- To add new features:
  - Follow the modular structure; add new providers/services as needed.
  - Use streams and reactive variables for data flow.
  - Document new APIs and modules.
  - For hardware or protocol changes, update configuration and communication modules.
- See code comments and documentation for further details.

For guidelines and information on how to contribute to this project, please refer to the [CONTRIBUTING.md](CONTRIBUTING.md) file.

---

## License

This project is licensed under the MIT License. See the [LICENSE](LICENSE) file for details.

---

## Acknowledgements

This project is part of the ARG_OSCI oscilloscope visualization tool suite. For the firmware and hardware used, visit the [ARG_OSCI_FIRMWARE repository](https://github.com/ArgOsciProyect/ARG_OSCI_FIRMWARE) and the [ARG_OSCI_HARDWARE repository](https://github.com/ArgOsciProyect/ARG_OSCI_HARDWARE).