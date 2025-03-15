# SetupProvider.dart Documentation

## Overview

`SetupProvider.dart` implements a state management solution for the device setup process in the app, using the GetX framework. This class serves as the bridge between the UI and the underlying `SetupService`, managing the state transitions during the WiFi configuration process.

## Class Structure

### SetupProvider Class

The `SetupProvider` class extends `GetxController` from the GetX framework, which provides reactive state management capabilities. It maintains the setup state and exposes methods to modify this state during the device configuration workflow.

## Key Components

1. **State Management**:
   - Uses an observable (`Rx`) `SetupState` object to track the current state of the setup process
   - Provides a `_updateState()` method to modify state in a controlled manner
   - Exposes state and available networks through getter methods

2. **Setup Service Integration**:
   - Holds a reference to a `SetupService` instance that handles low-level networking operations
   - Delegates network operations to the service while managing state updates

3. **Retry Logic**:
   - Implements connection retry logic with a configurable maximum number of attempts
   - Provides appropriate error handling and status updates during retry operations

## Main Functionality

### Local Access Point Connection

The `connectToLocalAP()` method initiates a connection to the device's local access point. It updates the state to reflect the connection process and handles any errors that might occur.

### WiFi Network Scanning

The `handleExternalAPSelection()` method triggers a scan for available WiFi networks. It updates the state to indicate scanning is in progress and populates the state with discovered networks when complete.

### External Network Connection

The `connectToExternalAP(ssid, password)` method:
1. Encrypts WiFi credentials using the device's public key
2. Attempts to connect the ESP32 device to the specified WiFi network
3. Implements retry logic for failed connection attempts
4. Updates state throughout the process to reflect progress
5. Handles errors and provides descriptive error messages

### Network Change Handling

After initiating a WiFi connection:
1. `waitForNetworkChange(ssid)` monitors for the WiFi connection change
2. `handleNetworkChangeAndConnect(ssid, password)` establishes a connection to the device over the new network

### State Reset

The `reset()` method clears the current state and returns it to initial values, allowing the setup process to be restarted if needed.

## Error Handling

The provider implements comprehensive error handling:
- Catches exceptions from all network operations
- Updates state with descriptive error messages
- Uses rethrow to propagate errors to callers when appropriate
- Provides retry mechanisms for transient failures

## Integration with UI

While not directly visible in this file, the reactive state is designed to be consumed by UI components that respond to state changes, showing appropriate progress indicators, error messages, and network selection options based on the current state.


# SetupService.dart Documentation

## Overview

`SetupService.dart` is a core file in the device setup process, containing three key classes:
1. `NetworkInfoService` - Handles WiFi network detection and connection
2. `SetupService` - Implements the `SetupRepository` interface to manage device configuration and communication
3. `SetupException` - Custom exception class for setup-related errors

The file provides comprehensive functionality for connecting to ESP32 devices, scanning for WiFi networks, and configuring device communications.

## NetworkInfoService Class

`NetworkInfoService` is responsible for low-level WiFi network operations, particularly focusing on connecting to ESP32 access points.

### Key Features:
- Manages default and custom ESP32 access point credentials
- Provides multi-strategy connection approaches with retries
- Verifies connections with HTTP tests
- Supports platform-specific connection behaviors

### Connection Workflow:
1. The service first attempts connection using the WiFiForIoTPlugin (Android only)
2. If that fails, it falls back to traditional SSID verification
3. Both approaches implement retry logic with appropriate delays
4. Connection verification is performed via HTTP test requests

### Methods:
- `connectWithRetries()` - Orchestrates the retry process for ESP32 connection
- `testConnection()` - Verifies connection through HTTP test requests
- `connectToESP32()` - Implements the multi-strategy connection approach
- `getWifiName()` / `getWifiIP()` - Retrieves network information
- `isConnectedToNetwork()` - Checks connection to a specific network

## SetupService Class

`SetupService` implements the `SetupRepository` interface and acts as the main service for device setup and configuration. It handles secure communications, network scanning, and connection management.

### Key Features:
- RSA encryption for secure credential transmission
- WiFi network scanning and connection
- Network mode selection (internal/external)
- Connection verification with encrypted challenge-response
- Cross-platform connection approaches

### RSA Security Workflow:
1. Retrieves the device's public RSA key
2. Encrypts sensitive data (WiFi credentials) before transmission
3. Uses encrypted challenge-response for connection verification

### Setup Process:
1. Connect to the ESP32's access point
2. Scan for available WiFi networks
3. Send encrypted credentials for the selected network
4. Wait for the ESP32 to connect to the selected network
5. Establish connection to ESP32 through the new network

### Methods:
- `connectToLocalAP()` - Connects to the ESP32's local access point
- `scanForWiFiNetworks()` - Retrieves available WiFi networks and gets public key
- `encriptWithPublicKey()` - Encrypts data using the device's RSA public key
- `connectToWiFi()` - Sends encrypted credentials to the ESP32
- `waitForNetworkChange()` - Waits for successful network transition
- `handleNetworkChangeAndConnect()` - Establishes connection through the new network

### Platform-Specific Behavior:
- For Android: Uses WiFiForIoTPlugin for automatic connection
- For iOS and others: Provides user guidance for manual connection and waits for connection detection

## SetupException Class

A custom exception class that encapsulates setup-related errors, providing clear error messages for debugging and user feedback.

## Technical Details

### Connection Management:
- The service maintains global HTTP and Socket configurations
- Connection settings are updated dynamically as network changes occur
- Connection verification uses encrypted challenge-response to ensure security

### Error Handling:
- Comprehensive try/catch blocks with timeouts
- Detailed debug logging (when in debug mode)
- Appropriate exception propagation with descriptive messages
- Platform-specific error handling approaches

### Cross-Platform Support:
- Dedicated code paths for Android using WiFiForIoTPlugin
- Manual connection guidance for iOS and other platforms
- Platform-specific SSID formatting (handling quotes in SSIDs)

### Security Features:
- RSA encryption for credential transmission
- Encrypted challenge-response for connection verification
- Public key retrieval and secure storage

The file demonstrates a robust approach to handling the complex process of device setup with appropriate retry logic, error handling, and security measures.

# SetupStatus.dart Documentation

## Overview

`SetupStatus.dart` defines the state management components used to track the progress of device setup in the application. It contains two main elements: the `SetupStatus` enum and the `SetupState` class.

## SetupStatus Enum

The `SetupStatus` enum represents the various stages a device can go through during the setup process. This provides a type-safe way to track setup progress throughout the app.

### Defined Stages:

1. **initial**: The starting state before any setup actions begin
2. **connecting**: The app is attempting to connect to the device's access point
3. **scanning**: The app is scanning for available WiFi networks
4. **selecting**: User interaction stage - selecting from available networks
5. **configuring**: The app is sending the selected network configuration to the device
6. **waitingForNetworkChange**: The app is waiting for the device to connect to the selected network
7. **error**: An error occurred during the setup process
8. **success**: The current setup step completed successfully
9. **completed**: The entire setup process has been completed successfully

This enum allows the application to track exactly which stage of setup the device is in and render appropriate UI components based on that status.

## SetupState Class

`SetupState` is an immutable class that encapsulates all information about the current state of the setup process. Using an immutable state design pattern allows for predictable state transitions and makes it easier to track state changes.

### Properties:

- **status**: The current stage in the setup process (using the `SetupStatus` enum)
- **error**: Optional error message if setup failed
- **canRetry**: Boolean flag indicating whether the current error state can be retried
- **networks**: List of available WiFi networks discovered during scanning

### Methods:

#### Constructor
The default constructor creates a new state object with optional parameters, defaulting to the initial state with no error, retry enabled, and an empty networks list.

#### copyWith
The `copyWith` method implements the immutable state pattern, allowing for creating a new state instance that's a copy of the current state but with specific properties changed. This enables state transitions without modifying the original state object.

### Usage Pattern:

The `SetupState` is designed to be used with state management solutions (likely GetX based on imports in other files). This pattern allows for:

1. Tracking the full setup flow from initial connection to completion
2. Preserving error information when failures occur
3. Maintaining a list of available networks for selection
4. Supporting retry operations for recoverable errors
5. Creating new state instances for each status change without mutating existing state

This immutable state approach helps ensure consistency across the UI and prevents race conditions during asynchronous operations in the setup process.

# WiFiCredentials.dart Documentation

## Overview

`WiFiCredentials.dart` defines a data model that represents WiFi network credentials (SSID and password) with serialization capabilities. This model facilitates secure transmission of network credentials during the device configuration process.

## WiFiCredentials Class

The `WiFiCredentials` class is a simple data model that encapsulates network identification and authentication information.

### Properties:

- **ssid**: String representing the network name (SSID)
- **password**: String representing the network password

### Methods:

#### Constructor
Creates a new instance with the provided SSID and password.

#### fromJson Factory
Deserializes WiFi credentials from a JSON map structure. It:
- Validates that required fields ('SSID' and 'Password') exist in the input map
- Throws a `FormatException` if fields are missing
- Creates and returns a new `WiFiCredentials` instance with values from the map

#### toJson Method
Serializes the credentials into a JSON-compatible map structure with 'SSID' and 'Password' keys, suitable for API communication.

#### toString Override
Provides a string representation of the credentials, showing only the SSID for security reasons (omitting the password).

### Usage in Context:

Based on other files in the application context, the `WiFiCredentials` class is used to:

1. Transport encrypted credentials when configuring ESP32 devices with WiFi settings
2. Serialize credentials for sending to the device via HTTP requests
3. Deserialize credentials when necessary from API responses
4. Handle error cases when malformed credential data is encountered

The class is designed with security in mind, avoiding exposing passwords in log outputs through its toString implementation.

As seen in the `SetupService` class, these credentials are likely encrypted using RSA before transmission to ensure secure configuration of the device over potentially insecure initial connections.

# SetupScreen.dart Documentation

## Overview

`SetupScreen.dart` serves as the main entry point for the device setup process in the ARG_OSCI application. It provides a user interface for starting the setup process and configuring application preferences.

## Key Components

### SetupScreen Widget

The `SetupScreen` class is a `StatefulWidget` that presents the initial setup interface. It contains:

- An app bar with the application name
- A button to initiate the setup process
- A theme toggle switch for light/dark mode selection

### State Management

The `_SetupScreenState` class maintains the UI state, particularly:

- A reactive boolean (`_isDarkMode`) to track and respond to theme changes
- Lifecycle observers to keep the UI in sync with system-level changes

### Error Handling

The screen includes sophisticated error handling mechanisms:

1. **Error Dialog System**:
   - Detects errors passed via navigation arguments
   - Displays user-friendly error messages with simplified error codes
   - Provides recovery options after errors

2. **Resource Cleanup**:
   - The `_cleanupAfterError()` method ensures proper disposal of services
   - Prevents resource leaks after connection failures
   - Includes error handling for the cleanup process itself

3. **Error Code Extraction**:
   - Parses complex error messages to extract meaningful error codes
   - Falls back to simplified codes when standard patterns aren't found
   - Improves user experience by avoiding overwhelming technical details

### Theme Management

The screen implements a theme toggle that:
- Displays the current theme state (light/dark)
- Allows users to switch between themes
- Updates UI reactively when theme changes occur

### Widget Lifecycle Management

The class implements several lifecycle methods:
- `initState()`: Sets up observers and initial state
- `dispose()`: Cleans up resources when the widget is removed
- `didChangeAppLifecycleState()`: Responds to app state changes
- `didChangeDependencies()`: Updates when inherited widgets change

### Integration with Setup Flow

The screen initiates the setup process by calling `showAPSelectionDialog()` which begins the multi-step setup workflow, detailed in the AP selection dialog component.

## Technical Details

1. **GetX Integration**:
   - Uses GetX for state management (`RxBool`)
   - Leverages GetX navigation and dialog systems
   - Accesses registered services through GetX dependency injection

2. **Error Processing**:
   - Implements regex pattern matching for error code extraction
   - Provides fallbacks for unrecognized error formats
   - Logs detailed information in debug mode

3. **Service Cleanup**:
   - Handles asynchronous disposal of services
   - Implements catch handlers for disposal errors
   - Uses delayed execution to allow resource cleanup to complete

# AP_Selection_Dialog.dart Documentation

## Overview

`AP_Selection_Dialog.dart` provides functionality to guide users through selecting the device's operating mode by connecting to the ESP32 access point and choosing between local and external network modes.

## Key Function: showAPSelectionDialog

This file exports a single function (`showAPSelectionDialog`) that orchestrates the initial connection and mode selection process.

### Connection Workflow

1. **Initial Connection**:
   - Displays a loading dialog while attempting to connect to the ESP32 access point
   - Uses the `SetupProvider` to manage the connection process
   - Provides visual feedback during the connection attempt

2. **Mode Selection**:
   - After successful connection, presents options for AP mode:
     - **Local AP**: Use the ESP32's built-in access point
     - **External AP**: Connect the ESP32 to an existing WiFi network

3. **Next Steps**:
   - For Local AP: Navigates to the Mode Selection Screen
   - For External AP: Initiates WiFi network scanning via `showWiFiNetworkDialog()`

### Error Handling

The function includes comprehensive error handling:
- Catches and displays connection failures
- Closes loading dialogs on error
- Provides user feedback via snackbar notifications

### UI Components

The dialog presents:
- Clear titles and instructions
- Loading indicators during connection
- Action buttons for mode selection
- Appropriate feedback during each process step

## Technical Details

1. **GetX Integration**:
   - Uses GetX for dialog management and navigation
   - Accesses the SetupProvider through GetX dependency injection
   - Provides consistent user feedback through GetX snackbars

2. **Asynchronous Processing**:
   - Handles asynchronous connection operations
   - Manages dialog state during connection processes
   - Properly sequences the multi-step setup workflow

3. **Error Management**:
   - Implements try-catch blocks for error handling
   - Provides meaningful error messages to users
   - Ensures dialogs are dismissed even when errors occur

# ShowWiFiNetworkDialog.dart Documentation

## Overview

`ShowWiFiNetworkDialog.dart` contains two key functions that guide users through WiFi network selection and connection as part of the external AP setup process.

## Primary Functions

### showWiFiNetworkDialog

This function displays a dialog for scanning and selecting available WiFi networks.

#### Workflow:
1. **Initiate Scanning**:
   - Triggers WiFi network scanning through the SetupProvider
   - Shows a loading indicator during the scan

2. **Network Selection**:
   - Displays the list of discovered WiFi networks
   - Handles user selection of a network
   - Provides a rescan option if needed

3. **Error Handling**:
   - Displays appropriate UI for error states
   - Offers retry options when scanning fails
   - Allows users to go back if they change their mind

#### UI States:
- **Scanning**: Shows progress indicator
- **Selecting**: Displays the network list
- **Error**: Shows error details with retry options

### askForPassword

This function prompts users for the password of their selected WiFi network and initiates the connection process.

#### Workflow:
1. **Password Collection**:
   - Displays a form for entering the WiFi password
   - Validates input before proceeding
   - Handles form submission

2. **Connection Process**:
   - Shows connection progress UI
   - Attempts to connect the ESP32 to the selected network
   - Updates UI based on connection state

3. **Status Handling**:
   - Manages different connection states (configuring, waiting, error)
   - Provides appropriate feedback for each state
   - Offers retry options if connection fails

#### UI Components:
- Responsive form that adapts to device orientation
- Password input with validation
- Visual indicators for connection progress
- Clear error messages with recovery options

## Technical Details

1. **Reactive State Management**:
   - Uses Obx for reactive UI updates based on setup state
   - Renders different UI components based on SetupStatus
   - Updates in real-time as connection progresses

2. **Form Handling**:
   - Implements form validation for password input
   - Manages focus and keyboard for improved UX
   - Handles form submission via button and keyboard actions

3. **Dialog Navigation**:
   - Manages multiple nested dialogs
   - Handles dialog dismissal and navigation between screens
   - Controls back navigation to prevent accidental cancellation

4. **Error Recovery**:
   - Provides contextual retry options based on error type
   - Allows graceful exit from the setup process
   - Displays user-friendly error notifications

# WiFiCredentialsDialog.dart Documentation

## Overview

`WiFiCredentialsDialog.dart` implements a form dialog for collecting ESP32 access point credentials, with platform-specific behavior for Android versus other platforms.

## Key Components

### WiFiCredentialsDialog Widget

This StatefulWidget presents a form to collect WiFi credentials:

- For Android: Collects both SSID and password
- For other platforms: Collects only SSID and provides manual connection instructions

### Platform-Specific Behavior

The dialog detects the platform and adapts its UI and behavior accordingly:

1. **Android**:
   - Shows both SSID and password fields
   - Enables automatic connection
   - Uses "Connect" as the action button text

2. **Other Platforms** (iOS, web, desktop):
   - Shows only SSID field
   - Provides instructions to connect manually through system settings
   - Uses "Continue" as the action button text

### Responsive Design

The dialog implements responsive layout handling:
- Adjusts width based on device orientation
- Uses SingleChildScrollView for overflow protection
- Adapts margins and padding appropriately

### Form Validation

Implements form validation for required fields:
- SSID validation ensures field is not empty
- Password validation for Android ensures field is not empty
- Handles keyboard submission and focus management

## Technical Details

1. **Form Implementation**:
   - Uses Flutter's Form and TextFormField widgets
   - Implements a form key for validation
   - Manages text controllers for input fields

2. **Platform Detection**:
   - Uses dart:io Platform class to detect Android
   - Conditionally renders UI components based on platform
   - Provides platform-appropriate instructions

3. **UI Customization**:
   - Implements custom container styling
   - Adapts to the current theme
   - Uses appropriate text styles for different content types

4. **Data Return Pattern**:
   - Returns collected credentials as a structured map
   - Handles cancellation by returning null
   - Ensures data validation before returning

The dialog serves as the initial step in the ESP32 connection process, allowing users to specify the access point details before connection attempts begin.

# SocketService.dart Documentation

## Overview

`SocketService.dart` implements a comprehensive socket communication system for the oscilloscope application. This file provides classes for establishing TCP socket connections, managing data flow between the app and the oscilloscope device, and analyzing transmission performance statistics. The implementation follows the Repository pattern with `SocketService` implementing the `SocketRepository` interface.

## Class Structure

### Measurement Classes

1. **Measurement**
   - A data class representing a single packet transmission measurement
   - Stores bytes count, timestamp, and packet count
   - Used to track incoming data statistics

2. **_SpeedMeasurement**
   - A private class for tracking outgoing message transmission speed
   - Tracks bytes sent, transmission timestamp, and duration
   - Calculates bytes per second automatically through the `speed` getter

### Statistics Classes

1. **TransmissionStats**
   - Tracks and analyzes incoming data transmission performance
   - Implements a sliding window approach to calculate data rates
   - Provides statistical metrics: mean, median, standard deviation, min, max
   - Uses a 15-minute retention window for measurements
   - Provides summary data for performance monitoring

2. **TransmissionSpeedStats**
   - Similar to TransmissionStats but focused on outgoing data speed
   - Analyzes how quickly messages are sent to the device
   - Provides statistical metrics on transmission speeds
   - Also uses a 15-minute retention window

### Socket Implementation

**SocketService**
   - Core implementation class that manages the socket connection
   - Buffers and processes incoming data packets
   - Manages error handling and event propagation
   - Implements the `SocketRepository` interface
   - Provides measurement and statistics collection

## Key Components

### Connection Management

The SocketService maintains the current connection state including:
- Active socket instance
- IP address and port information
- Stream controllers for data and errors
- Subscription management

### Data Processing Pipeline

1. **Data Reception**
   - Raw bytes received from the socket
   - Bytes tracked and measured for statistics
   - Data buffered until complete packets are available

2. **Packet Processing**
   - Fixed-size packets extracted from buffer
   - Complete packets emitted through broadcast controller
   - Buffer maintains any leftover partial packets

3. **Data Subscription**
   - Broadcast controllers allow multiple listeners
   - Subscription management for automatic cleanup

### Statistics Collection

1. **Incoming Data Measurement**
   - Periodic measurement through timer-based sampling
   - Accumulates bytes and packets between measurements
   - Statistics calculated using TransmissionStats

2. **Outgoing Message Measurement**
   - Performance tracked for each sent message
   - Duration measured for speed calculation
   - Statistics calculated using TransmissionSpeedStats

### Error Handling

The class implements comprehensive error handling:
- Stream-based error propagation
- Zone-based unhandled error catching
- Error subscription management
- Graceful cleanup on connection failure

## Key Methods

### Connection Methods

- `connect()` - Establishes socket connection using provided connection parameters
- `listen()` - Starts listening for incoming data and sets up processing pipeline
- `close()` - Cleans up connection resources including timers and subscriptions

### Data Operations

- `_processIncomingData()` - Buffers data and extracts complete packets
- `sendMessage()` - Sends a command to the device with null termination
- `receiveMessage()` - Receives a single data packet from the stream

### Subscription Management

- `subscribe()` - Registers a listener for data packets with tracking
- `unsubscribe()` - Removes a listener and cancels subscription
- `onError()` - Registers a listener for error events

### Statistical Analysis

Multiple methods in TransmissionStats and TransmissionSpeedStats for calculating:
- Mean (average) data rates
- Median rates (less affected by outliers)
- Standard deviation (measuring transmission consistency)
- Minimum and maximum observed rates

## Technical Details

### Socket Handling

- Uses Dart's `Socket` class for TCP communication
- Implements asynchronous operations with Futures and Streams
- Provides timeout-based connection attempts
- Handles socket errors with proper propagation

### Data Buffering

- Maintains a buffer to accumulate partial packets
- Uses fixed-size packet processing based on `_expectedPacketSize`
- Efficiently extracts complete packets while preserving partial data

### Memory Management

- Implements measurement retention windows to prevent memory leaks
- Cancels subscriptions to prevent resource leaks
- Properly closes streams and connections on disposal

### Performance Monitoring

- Statistical methods to evaluate connection performance
- Runtime analysis of data transfer rates
- Median and standard deviation calculations to identify transmission issues

This implementation provides a robust solution for socket-based communication with the oscilloscope device, handling the complexities of streaming binary data while maintaining performance metrics and proper resource management.

# SocketConnection.dart Documentation

## Overview

The `SocketConnection.dart` file defines a reactive model class that manages socket connection parameters for the oscilloscope application. It serves as a key component in the networking infrastructure, enabling real-time connectivity between the mobile application and the oscilloscope device.

## Class Structure

### SocketConnection Class

`SocketConnection` extends the GetX framework's `GetxController` class to leverage reactive state management capabilities. This design choice allows connection parameters to automatically notify dependent UI components when changes occur, ensuring synchronization between the application state and the user interface.

## Properties

The class maintains two primary properties:

1. **IP Address (`ip`)**
   - Implemented as a reactive string (`RxString`) from the GetX framework
   - Stores the target device's IP address (e.g., "192.168.1.100")
   - Changes to this property automatically trigger UI updates in connected components

2. **Port Number (`port`)**
   - Implemented as a reactive integer (`RxInt`) from the GetX framework
   - Stores the numerical port value for socket communication (e.g., 8080)
   - Reactive by design to propagate changes throughout the application

## Functionality

### Construction and Initialization

The class provides two ways to initialize connection parameters:

1. **Standard Constructor**
   - Creates a new instance with explicitly provided IP and port values
   - Wraps these values in GetX reactive containers (`.obs`)
   - Example: `SocketConnection("192.168.1.100", 8080)`

2. **Factory Constructor (fromJson)**
   - Deserializes connection parameters from a JSON map structure
   - Expects a map containing 'ip' and 'port' keys
   - Facilitates loading connection settings from stored configurations

### Data Persistence

The `toJson()` method enables serialization of the connection parameters:
- Extracts the current values from the reactive containers
- Creates a structured map with 'ip' and 'port' keys
- Returns a JSON-compatible representation for storage or network transfer

### State Management

The `updateConnection()` method provides a unified way to modify connection parameters:
- Takes new IP and port values as parameters
- Updates both reactive properties atomically
- Automatically triggers reactivity for all observers
- Provides a clean API for connection changes from other parts of the application

## Technical Implementation Details

The implementation leverages GetX reactivity through several key mechanisms:

1. **Reactive Properties**
   - Uses `.obs` extensions to make values observable
   - Maintains the original type safety (String for IP, int for port)
   - Allows direct value access through `.value` property

2. **GetxController Integration**
   - Extends GetxController to integrate with the broader GetX ecosystem
   - Enables dependency injection and lifecycle management
   - Supports memory management through controller disposal

3. **Update Propagation**
   - Changes to `ip.value` or `port.value` automatically notify dependent widgets
   - No manual notification or rebuilding required
   - Ensures UI consistency with the application state

## Usage Context

Within the broader application architecture, the `SocketConnection` class serves multiple important roles:

1. **Configuration Storage**
   - Maintains the current target device connection information
   - Provides serialization for persistent storage between app sessions

2. **Service Configuration**
   - Used by the `SocketService` to establish actual socket connections
   - Provides the necessary parameters for TCP/IP communication

3. **UI Integration**
   - Supports reactive UI updates when connection details change
   - Enables form binding for connection setting screens

The class exemplifies clean separation of concerns by focusing solely on managing connection parameters while delegating actual socket communication to the `SocketService` class.

# HttpService.dart Documentation

## Overview

`HttpService.dart` implements a robust HTTP client for communicating with the oscilloscope device's API. It provides a reliable communication layer with built-in error handling, retry mechanisms, and automatic navigation to the setup screen when connection issues occur. This file is central to the application's data exchange with the oscilloscope hardware.

## Class Structure

### HttpService Class

The `HttpService` class implements the `HttpRepository` interface, creating a concrete implementation for making HTTP requests to the oscilloscope API. The class handles various types of HTTP requests (GET, POST, PUT, DELETE) with standardized error handling and response processing.

## Key Components

### Configuration and Dependencies

1. **HttpConfig**
   - Stores the base URL for all API requests
   - Contains the HTTP client instance for making requests
   - Allows for configuration of the service behavior

2. **Navigation Function**
   - Customizable function for handling navigation on connection errors
   - Can be injected for testing or specialized handling
   - Defaults to a comprehensive implementation that handles common scenarios

### Retry Mechanism

The service implements a sophisticated retry system with exponential backoff:

1. **Request Wrapping**
   - All HTTP requests are wrapped in the `_retryRequest` method
   - Provides consistent retry behavior across all request types
   - Supports skipping navigation for specific requests

2. **Exponential Backoff**
   - Increases delay between retry attempts (200ms * retry count)
   - Limits total retries to a fixed maximum (5 attempts)
   - Avoids overwhelming the device with rapid retry attempts

3. **Error Escalation**
   - After maximum retries, navigates to setup screen
   - Provides detailed error information for troubleshooting
   - Can bypass navigation when `skipNavigation` flag is set

### Navigation Handling

The service includes sophisticated error navigation:

1. **Loop Prevention**
   - Checks if already on the setup screen before navigating
   - Prevents infinite navigation loops on persistent errors
   - Uses route detection to determine current screen

2. **Resource Cleanup**
   - Stops ongoing data acquisition before navigation
   - Includes timeout handling for cleanup operations
   - Adds small delay to ensure cleanup completes

3. **Error Presentation**
   - Displays connection errors to the user via dialog
   - Provides relevant error information
   - Offers reset capability through the setup provider

### HTTP Methods

The class implements standard HTTP methods required by the repository interface:

1. **GET Requests**
   - Retrieves data from specified endpoints
   - Handles URL construction and response parsing
   - Supports navigation control via flag

2. **POST Requests**
   - Sends JSON data to specified endpoints
   - Handles body encoding and content-type headers
   - Supports optional body payload

3. **PUT Requests**
   - Updates resources at specified endpoints
   - Requires JSON body data
   - Follows same error handling pattern

4. **DELETE Requests**
   - Removes resources at specified endpoints
   - Simplest implementation with minimal parameters
   - Consistent with overall error handling approach

### Response Processing

The `_handleResponse` method provides standardized response handling:

1. **Status Code Verification**
   - Checks for successful status code (200)
   - Throws appropriate exceptions for non-200 responses
   - Provides status code in error message for debugging

2. **JSON Parsing**
   - Automatically decodes JSON response bodies
   - Handles parsing errors with descriptive exceptions
   - Returns the decoded JSON object for successful responses

## Technical Details

### Error Handling Strategy

The service implements multi-layered error handling:

1. **Request-Level Errors**
   - Network failures, timeouts, or connection issues
   - Handled by retry mechanism with exponential backoff
   - Captured in try-catch blocks with detailed logging

2. **Response-Level Errors**
   - Non-200 status codes from the server
   - Invalid JSON responses
   - Handled with specific exceptions for each case

3. **Navigation Errors**
   - Failures during the error handling itself
   - Implemented with nested try-catch and fallback navigation
   - Ensures user can always reach setup screen on persistent issues

### Debugging Support

The implementation includes comprehensive debugging capabilities:

1. **Conditional Logging**
   - Uses `kDebugMode` to control log output
   - Provides detailed information about failures and retry attempts
   - Logs navigation decisions and error handling steps

2. **Detailed Error Information**
   - Propagates original error messages
   - Includes retry count information
   - Preserves stack traces for debugging

### Integration with GetX

The service leverages GetX framework capabilities:

1. **Dependency Injection**
   - Retrieves providers using GetX dependency injection
   - Supports testing through dependency substitution
   - Accesses global state for coordinating actions

2. **Navigation**
   - Uses GetX navigation system (`Get.offAll`)
   - Passes arguments to target screens
   - Controls dialog presentation

3. **Route Management**
   - Checks current route to prevent navigation loops
   - Uses route patterns for screen identification

This implementation provides a robust communication layer that handles the complexities of network communication while ensuring good user experience even when connectivity issues occur.

# HttpConfig.dart Documentation

## Overview

`HttpConfig.dart` defines a configuration model class for the HTTP client settings used throughout the oscilloscope application. This file provides a structured way to manage HTTP connection settings, particularly the base URL for API endpoints and the HTTP client instance. It serves as a fundamental building block for the application's networking layer.

## Class Structure

### HttpConfig Class

The `HttpConfig` class is a data model that encapsulates the configuration needed for making HTTP requests to the oscilloscope device's API. It follows an immutable pattern, with all fields being final, ensuring configuration stability during runtime.

## Properties

The class defines two primary properties:

1. **baseUrl**
   - A String containing the base URL for all API requests
   - Typically includes protocol, IP address, and port (e.g., "http://192.168.1.100:8080")
   - Used as a prefix for all HTTP endpoint paths
   - Critical for directing requests to the correct oscilloscope device

2. **client**
   - An optional `http.Client` instance from the `package:http/http.dart` library
   - Used to make the actual HTTP requests
   - Can be injected for testing purposes or custom configuration
   - If not provided, a default client is automatically created

## Core Functionality

### Construction and Initialization

The class provides multiple ways to create instances:

1. **Default Constructor**
   - Takes a required baseUrl parameter
   - Accepts an optional client parameter
   - Creates a default HTTP client if none is provided
   - Example: `HttpConfig('http://192.168.1.100:80')`

2. **FromJson Factory**
   - Creates an instance from a JSON map
   - Requires 'baseUrl' key in the map
   - Optional 'client' key to indicate if a client should be created
   - Throws FormatException if required data is missing
   - Used for deserialization from stored settings

### Serialization Support

The class supports serialization for persistence or transfer:

1. **toJson Method**
   - Converts the configuration to a JSON-compatible map
   - Includes 'baseUrl' and a flag indicating if a client exists
   - Does not serialize the actual client instance (as this wouldn't be meaningful)
   - Used for saving configuration or sending between components

### Instance Manipulation

For reconfiguration without mutating the original instance:

1. **copyWith Method**
   - Creates a new instance with selectively changed properties
   - Follows the immutable object pattern common in Flutter
   - Preserves unchanged properties from the original
   - Useful when only the URL or client needs to be changed

### String Representation

For debugging and logging purposes:

1. **toString Override**
   - Provides a human-readable representation of the configuration
   - Includes the base URL but omits the client (which wouldn't be meaningful in logs)
   - Useful for debugging network issues

## Usage Context

Within the broader application architecture, the `HttpConfig` class serves several important roles:

1. **Service Configuration**
   - Passed to `HttpService` to configure where requests are sent
   - Determines which oscilloscope device the app communicates with
   - Can be updated when moving between different devices or networks

2. **Testing Support**
   - Enables dependency injection of mock clients for unit testing
   - Facilitates test isolation without network dependencies
   - Supports simulated responses for predictable test behavior

3. **Configuration Persistence**
   - JSON serialization allows saving settings between sessions
   - Enables restoring the last used connection configuration
   - Supports storing multiple device configurations

4. **Dynamic Reconfiguration**
   - Supports changing the target API endpoint at runtime
   - Used during device setup process when IP address changes
   - Enables seamless transition between different network contexts

This configuration class exemplifies clean separation of concerns by isolating connection settings from the actual HTTP request logic, making the application more maintainable and testable.

# DataAcquisitionService.dart Documentation

## Overview

`DataAcquisitionService.dart` implements a sophisticated oscilloscope data acquisition system that connects to hardware devices, processes signal data, and provides real-time waveform visualization capabilities. The file employs advanced concurrency techniques through Dart isolates to separate network operations, signal processing, and UI updates, creating a responsive user experience even during high-frequency data acquisition.

## Core Architecture

The service implements a multi-isolate architecture:

1. **Main Isolate**: Orchestrates overall operation and provides data to UI
2. **Socket Isolate**: Handles network communication with the oscilloscope device
3. **Processing Isolate**: Performs signal processing and trigger detection

This architecture enables dedicated CPU resources for intensive tasks while maintaining UI responsiveness.

## Primary Components

### DataAcquisitionService Class

The central class implementing `DataAcquisitionRepository`, responsible for:
- Managing communication with the oscilloscope device
- Configuring trigger settings and voltage scales
- Processing and exposing waveform data through streams
- Error handling and reconnection strategies

### Support Classes

1. **DataProcessingConfig**: Encapsulates configuration parameters for signal processing:
   - Scaling factors
   - Trigger levels and modes
   - Filter settings
   - Device-specific parameters

2. **Messaging Classes**:
   - `SocketIsolateSetup`: Configuration for the socket isolate
   - `ProcessingIsolateSetup`: Configuration for the processing isolate
   - `UpdateConfigMessage`: Parameters for updating processing configuration

3. **CompleterExtension**: Utility to safely check if a `Completer` is completed

## Data Flow and Processing Pipeline

The service implements a sophisticated data pipeline:

1. **Data Acquisition**:
   - Socket isolate connects to oscilloscope device
   - Raw binary data is received in packets
   - Data is forwarded to the processing isolate

2. **Signal Processing**:
   - Raw data is parsed into bytes according to device protocol
   - Values are converted to voltage using scaling factors
   - Data is processed based on current mode (normal/single)

3. **Trigger Detection**:
   - Applied to identify waveform starting points
   - Uses hysteresis and optional filtering to reduce false triggers
   - Supports both positive and negative edge detection
   - Handles different trigger modes (normal, single)

4. **Data Distribution**:
   - Processed data points are sent back to main isolate
   - Points are published through reactive streams for UI consumption
   - Frequency and amplitude statistics are calculated and published

## Triggering System

The service implements an advanced triggering system:

1. **Trigger Modes**:
   - Normal: Continuously captures signals when trigger conditions are met
   - Single: Captures a single waveform when triggered, then pauses

2. **Trigger Parameters**:
   - Level: Voltage threshold for trigger activation
   - Edge: Rising (positive) or falling (negative) signal transitions
   - Hysteresis: Reduces false triggers by requiring minimum signal change

3. **Trigger Processing**:
   - Precise trigger point detection using interpolation
   - Signal filtering options for noisy environments
   - Automatic rescaling of trigger levels when changing voltage ranges

## Isolate Communication

The service implements a robust inter-isolate communication system:

1. **Message Types**:
   - Data packets (raw binary data)
   - Configuration updates
   - Control commands (start, stop, pause)
   - Error notifications with priority levels

2. **Handshaking Protocol**:
   - Port establishment with acknowledgment
   - Configuration confirmation
   - Ping-pong mechanism for responsiveness verification
   - Error propagation with severity levels

## Error Handling and Recovery

The service includes comprehensive error handling:

1. **Connection Issues**:
   - Detection of socket failures
   - Automatic reconnection attempts
   - Graceful degradation when reconnection fails
   - Navigation to setup screen for manual intervention when necessary

2. **Resource Management**:
   - Proper cleanup of isolates and ports
   - Stream controller lifecycle management
   - Memory leak prevention through queue size limiting
   - Timeout handling for unresponsive operations

## Technical Algorithms

The file implements several sophisticated algorithms:

1. **Trigger Detection**:
   - Edge crossing detection with hysteresis
   - Trend analysis for signal direction confirmation
   - Linear interpolation for precise trigger point location

2. **Signal Analysis**:
   - Frequency calculation from trigger intervals
   - Maximum/minimum value tracking
   - Statistical processing (trend calculation)

3. **Digital Signal Processing**:
   - Optional low-pass filtering for noise reduction
   - Binary data parsing with bit masking
   - Coordinate transformation from raw values to voltage/time

## Integration Points

The service integrates with multiple system components:

1. **Device Communication**:
   - HTTP requests for device configuration
   - Socket connection for real-time data streaming

2. **State Management**:
   - GetX for reactive state updates
   - Stream-based communication with UI components
   - Configuration synchronization between isolates

3. **User Interface**:
   - Provides data streams for waveform display
   - Reports frequency and amplitude measurements
   - Communicates connection status and errors

The implementation balances performance, reliability, and maintainability to deliver professional-grade oscilloscope functionality within a Flutter application.

# DataAcquisitionProvider.dart Documentation

## Overview

`DataAcquisitionProvider.dart` is a key component in the oscilloscope application that acts as the intermediary layer between the UI components and the lower-level `DataAcquisitionService`. This provider implements the GetX pattern for state management, handling the reactive updates, data transformation, and user interactions required for real-time oscilloscope functionality.

## Core Architecture

The provider follows a mediator pattern, implementing bidirectional communication:

1. **Downstream Communication**: Propagates UI state changes (e.g., trigger settings, filter configurations) to the underlying service
2. **Upstream Communication**: Processes data from the service (waveform data, measurements) and delivers it to UI components

The class extends `GetxController` to leverage GetX's reactive state management capabilities, allowing UI components to automatically update when values change.

## Key Components

### State Management

The provider maintains several types of reactive state variables:

1. **Service Mirror Values**: Properties that reflect the current state of the acquisition service (e.g., `triggerLevel`, `triggerEdge`, `useHysteresis`)
2. **UI Configuration Values**: Settings primarily used by the UI (e.g., `currentFilter`, `windowSize`, `alpha`)
3. **Measurement Values**: Data calculated from the acquired signal (e.g., `frequency`, `maxValue`)
4. **Control Flags**: Internal state flags for preventing circular updates and tracking initialization (`_updatingFromService`, `_initialized`)

### Data Flow

The provider implements a complete data pipeline:

1. **Data Acquisition**: Initiates data collection via the service from the oscilloscope device
2. **Data Processing**: Applies filters and transformations to raw waveform data
3. **Data Distribution**: Publishes processed data through streams to connected UI components
4. **Measurement Extraction**: Extracts and publishes key signal measurements (frequency, amplitude)

### Stream Management

The provider manages several data streams:

1. **Data Points Stream**: Delivers processed waveform data to charts and displays
2. **Frequency Stream**: Provides real-time frequency measurements
3. **Maximum Value Stream**: Tracks signal amplitude values

All streams are properly initialized, managed, and disposed of during the provider's lifecycle.

## Synchronization Mechanism

One of the provider's most important functions is maintaining bidirectional synchronization between UI state and service state:

1. **Service-to-Provider Sync**: Through `_syncValuesFromService()`, the provider pulls current values from the service to ensure its state reflects the actual device configuration
2. **Provider-to-Service Sync**: Through reactive listeners established in `_setupValueChangeListeners()`, changes in the provider's state are automatically propagated to the service

To prevent circular updates, the provider uses the `_updatingFromService` flag to distinguish between user-initiated changes and service-synchronized changes.

## Filter System

The provider implements an extensible signal processing system:

1. **Filter Selection**: Allows changing between different filter algorithms (Low Pass, Moving Average, Exponential)
2. **Parameter Configuration**: Exposes methods to modify filter parameters (window size, alpha, cutoff frequency)
3. **Filter Application**: The `_applyFilter()` method processes raw data points using the selected filter with the current parameters
4. **Double Filtering**: Supports an optional second pass filtering for stronger noise reduction

## Trigger Management

The provider handles the oscilloscope's trigger system:

1. **Trigger Level**: Controls the voltage threshold at which to trigger
2. **Trigger Edge**: Manages whether to trigger on rising or falling edges
3. **Trigger Mode**: Switches between normal (continuous) and single modes
4. **Mode-Specific Actions**: Each mode change triggers appropriate UI actions (clearing charts, resetting offsets)

## Socket and Configuration Management

The provider monitors and responds to changes in:

1. **Socket Connection**: Restarts data acquisition when connection parameters change
2. **Device Configuration**: Updates dependent values when device configuration changes
3. **Voltage Scales**: Validates current scale against available scales from the device

## Error Handling

The provider implements comprehensive error handling:

1. **Stream Error Handling**: All stream subscriptions include error handlers
2. **Critical Error Handling**: The `handleCriticalError()` method provides a structured way to handle unrecoverable errors
3. **Service Call Protection**: All service method calls are wrapped in try-catch blocks

## Technical Integration Points

The provider integrates with several other components:

1. **DataAcquisitionService**: For low-level data acquisition and device communication
2. **OscilloscopeChartProvider**: For chart display configuration and control
3. **DeviceConfigProvider**: For device-specific configuration parameters
4. **UserSettingsProvider**: For user preference monitoring
5. **SetupScreen**: For navigation during critical errors

This strategic position in the application architecture makes the DataAcquisitionProvider a crucial component in delivering a responsive, robust oscilloscope experience to the user.

# 

data_point.dart

 Documentation

## Overview



data_point.dart

 defines the fundamental data structure used throughout the oscilloscope application for representing individual measurement points. This model serves as the basic unit of information exchanged between data acquisition, processing, and visualization components.

## Core Data Structure

The file defines the `DataPoint` class, which encapsulates the x-y coordinates of a measurement point along with metadata about the point's characteristics. This design supports both time-domain (oscilloscope) and frequency-domain (FFT) visualizations within the application.

## Key Properties

Each `DataPoint` instance contains four essential properties:

1. **x-coordinate**: Represents time (in seconds) for oscilloscope mode or frequency (in Hz) for FFT mode. This property is mutable to support post-acquisition transformations like trigger alignment.

2. **y-coordinate**: Represents voltage (in volts) for oscilloscope mode or magnitude (in dB) for FFT mode. This is immutable as it represents the actual measured value.

3. **isTrigger**: A boolean flag indicating whether this particular point triggered the oscilloscope acquisition. Used to highlight trigger points in visualizations and to correctly align waveforms.

4. **isInterpolated**: A boolean flag indicating whether this point was mathematically interpolated (not directly measured). This distinguishes between actual measurements and calculated points used for smooth visualizations.

## Serialization Support

The `DataPoint` class implements JSON serialization and deserialization through:

1. **fromJson factory constructor**: Converts a JSON map to a `DataPoint` instance, with graceful handling of missing flags through default values.

2. **toJson method**: Converts a `DataPoint` instance to a JSON-serializable map, preserving all properties including metadata flags.

This serialization capability enables:
- Storing measurement data for later analysis
- Transmitting data between different parts of the application
- Potentially exporting data to external systems

## Usage Context

Within the oscilloscope application, `DataPoint` instances flow through the following components:

1. **Data Acquisition**: Raw measurements are initially captured as `DataPoint` objects
2. **Signal Processing**: Points are processed through filters and transformations
3. **Trigger Detection**: Certain points are marked as triggers based on signal conditions
4. **Visualization**: Points are rendered on charts with special handling for trigger points
5. **Analysis**: Statistics and measurements are performed on collections of points

The simplicity and clarity of this model make it an essential building block for the entire oscilloscope functionality.

# 

voltage_scale.dart

 Documentation

## Overview



voltage_scale.dart

 implements the voltage scaling system for the oscilloscope application, providing a structured way to represent and calculate voltage display ranges. This system is crucial for accurately mapping raw ADC values to real-world voltage measurements.

## Core Components

The file defines two complementary classes:

1. **VoltageScales**: A utility class that provides predefined voltage scale configurations
2. **VoltageScale**: A model class representing a specific voltage measurement range

## Predefined Scales

The `VoltageScales` class serves as a repository of standard voltage scales commonly used in oscilloscope applications:

- High voltage (±400V)
- Standard voltage (±2V, ±1V)
- Millivolt ranges (±500mV, ±200mV, ±100mV)

These predefined scales offer a familiar set of voltage ranges for users, similar to physical oscilloscopes. The class also provides a `defaultScales` list that serves as a fallback when device-specific scales are unavailable.

## Scale Configuration Model

The `VoltageScale` class represents a specific voltage range configuration with two key properties:

1. **baseRange**: The total voltage span (from negative peak to positive peak) used for internal calculations
2. **displayName**: A user-friendly label showing positive and negative limits (e.g., "1V, -1V")

## Scale Factor Calculation

The most important functionality is provided by the `scale` getter, which:

1. Retrieves device configuration parameters (bit ranges) from the global dependency injection container
2. Calculates the volts-per-bit conversion factor based on the device's ADC range
3. Returns a scaling factor that maps raw integer values to actual voltages

This calculation enables accurate conversion between:
- Raw ADC values from the hardware (typically 0-4095 for a 12-bit ADC)
- Physical voltage values displayed to the user (e.g., ±1V)

## Integration with Device Configuration

The class integrates with the `DeviceConfigProvider` through GetX dependency injection:

1. It accesses the current device configuration to obtain bit range parameters
2. Uses these parameters to dynamically calculate appropriate scaling factors
3. Provides debug output in development mode to trace scaling calculations

## Equality and Utility Methods

The class implements proper equality comparison and hashing to support:
- Collection operations (searching, filtering)
- UI state management (detecting changes in selected scale)
- Dropdown and selection widgets that need to identify the current scale

The implementation provides a clean interface for the application to work with different voltage measurement ranges while abstracting away the complexity of ADC value conversion.

# 

unit_format.dart

 Documentation

## Overview



unit_format.dart

 implements a utility for formatting measurement values with appropriate SI (International System of Units) prefixes. This utility ensures that numeric values are displayed with human-readable units across the entire oscilloscope application.

## Core Functionality

The file defines the `UnitFormat` utility class with static methods for formatting values. Its primary purpose is to automatically select appropriate metric prefixes (milli-, micro-, kilo-, etc.) based on the magnitude of the value being formatted.

## SI Prefix System

The class maintains a comprehensive mapping of SI prefix exponents to their corresponding symbols:

- **Small values**: pico (p, 10^-12), nano (n, 10^-9), micro (μ, 10^-6), milli (m, 10^-3)
- **Base unit**: no prefix (10^0)
- **Large values**: kilo (k, 10^3), mega (M, 10^6), giga (G, 10^9), tera (T, 10^12)

This mapping enables automatic selection of the most appropriate prefix based on the value's magnitude.

## Value Formatting Logic

The `formatWithUnit` method implements a sophisticated algorithm that:

1. Handles special cases:
   - Zero values (returns "0" with the base unit)
   - Very small/large values outside the SI prefix range (uses scientific notation)

2. For values within the SI range:
   - Calculates the appropriate power of 10 exponent
   - Rounds to the nearest SI prefix (powers of 3)
   - Scales the value accordingly
   - Appends the correct prefix symbol

3. Implements intelligent decimal precision control:
   - Calculates available space for decimal digits based on integer part length
   - Ensures consistent total display width (typically 3-4 significant digits)
   - Avoids unnecessary trailing zeros

## Display Format

The output format follows international scientific conventions:
- A numeric value with appropriate decimal precision
- A space separator
- The SI prefix (if any) immediately followed by the unit symbol

Examples:
- 0.0012 V → "1.2 mV"
- 1500 Hz → "1.5 kHz"
- 0.000000002 A → "2 nA"

## Usage in Application

This utility is used throughout the oscilloscope application wherever measurements need to be displayed:

- Voltage measurements in the oscilloscope display
- Frequency values in the spectrum analyzer
- Time base settings in the UI controls
- Statistical measurements and indicators

The implementation ensures consistent, readable, and technically correct representation of all physical quantities across the entire application interface.

# 

trigger_data.dart

 Documentation

## Overview



trigger_data.dart

 defines the fundamental trigger configuration enumerations used throughout the oscilloscope application. These enumerations control how the oscilloscope captures and displays waveforms in response to signal conditions.

## Core Enumerations

The file defines two essential enumerations that govern the oscilloscope's triggering behavior:

### TriggerEdge Enumeration

`TriggerEdge` defines the signal transition direction that will activate the trigger:

1. **positive**: The oscilloscope triggers when the signal crosses the trigger threshold in an upward direction (rising edge). This is commonly used to capture waveforms that begin with an upward transition.

2. **negative**: The oscilloscope triggers when the signal crosses the trigger threshold in a downward direction (falling edge). This is useful for capturing waveforms that begin with a downward transition.

This enumeration allows users to select whether the oscilloscope responds to rising or falling signal transitions, similar to physical oscilloscope controls.

### TriggerMode Enumeration

`TriggerMode` defines how the oscilloscope responds after a trigger event occurs:

1. **normal**: The oscilloscope continuously captures and displays new waveforms each time the trigger condition is met. After displaying one waveform, it waits for the next trigger condition to capture the next one. This mode is useful for observing repeating signals.

2. **single**: The oscilloscope captures and displays a single waveform when the trigger condition is met, then stops acquiring new data. This mode is useful for capturing one-time events or for detailed analysis of a specific waveform instance.

## Application Context

These enumerations are used throughout the application:

1. In the user interface, to provide trigger configuration controls
2. In the data acquisition service, to determine how data is captured and processed
3. In the chart providers, to control display behavior after triggering occurs

The simple yet effective design of these enumerations enables a professional oscilloscope triggering system that matches the capabilities of dedicated hardware oscilloscopes.

# 

graph_mode.dart

 Documentation

## Overview



graph_mode.dart

 implements the visualization mode system for the oscilloscope application, providing a flexible architecture that supports multiple display modes (time domain and frequency domain). This enables the application to function as both an oscilloscope and a spectrum analyzer.

## Core Architecture

The file defines an abstract base class and two concrete implementations:

1. **GraphMode**: An abstract base class defining the interface for all visualization modes
2. **OscilloscopeMode**: A concrete implementation for time-domain (oscilloscope) visualization
3. **FFTMode**: A concrete implementation for frequency-domain (spectrum analyzer) visualization

This architecture follows the Strategy pattern, allowing the application to switch between different visualization strategies while maintaining a consistent interface.

## Base Interface

The `GraphMode` abstract class defines the common interface that all visualization modes must implement:

- **Identity properties**: `name` and `title` for displaying mode information in the UI
- **Visualization method**: `buildChart()` to construct the appropriate chart widget
- **Control panel flags**: Properties determining which control panels should be visible
- **Lifecycle methods**: `onActivate()` and `onDeactivate()` for managing mode transitions

This abstraction ensures that all visualization modes provide the necessary functionality while allowing customization of behavior and appearance.

## Time Domain Mode

The `OscilloscopeMode` class implements traditional oscilloscope functionality:

- Displays voltage vs. time waveforms
- Enables trigger controls for synchronizing the display to signal events
- Provides time base controls for adjusting the horizontal time scale
- Integrates with `OscilloscopeChartService` for chart data management
- Returns `OscilloscopeChart` widget for rendering the visualization

## Frequency Domain Mode

The `FFTMode` class implements spectrum analyzer functionality:

- Displays amplitude vs. frequency using Fast Fourier Transform
- Hides trigger and timebase controls (not applicable to frequency domain)
- Enables custom controls specific to frequency analysis
- Integrates with `FFTChartService` for spectrum data management
- Returns `FFTChart` widget for rendering the visualization

## Mode Transitions

Both concrete mode classes implement lifecycle methods for smooth transitions:

- `onActivate()`: Called when switching to the mode, resuming data processing
- `onDeactivate()`: Called when leaving the mode, pausing data processing

This ensures that system resources are efficiently managed and that each mode operates only when active.

## Integration with UI

The architecture provides all necessary information for the UI to adapt to the selected mode:

1. The UI queries the current mode for display title and appropriate controls
2. The mode's `buildChart()` method provides the correct visualization component
3. Control panel visibility is determined by the mode's flag properties

This approach creates a clean separation between the visualization modes and the UI framework, making the system extensible for additional modes in the future.

# 

device_config.dart

 Documentation

## Overview



device_config.dart

 defines the hardware configuration model for the oscilloscope device, providing a structured representation of the device's capabilities and settings. This configuration is essential for correctly interpreting raw data from the device and for adapting the application's behavior to the hardware's characteristics.

## Core Model

The `DeviceConfig` class encapsulates all hardware-specific parameters that affect data acquisition and interpretation:

### Sampling Configuration

- **_baseSamplingFrequency**: The hardware's native sampling rate in Hz
- **dividingFactor**: Factor used to reduce the effective sampling rate
- **samplingFrequency** (calculated): The actual sampling rate after division

These parameters determine the time resolution of the oscilloscope and affect how time values are calculated for each sample.

### Data Packet Structure

- **bitsPerPacket**: Total bits in each data packet from the device
- **samplesPerPacket**: Number of complete samples in each packet
- **dataMask**: Bit mask used to extract actual data values from raw packets
- **channelMask**: Bit mask used to extract channel information from packets
- **dataMaskTrailingZeros**: Pre-calculated number of trailing zeros for efficient bit shifting
- **channelMaskTrailingZeros**: Pre-calculated number of trailing zeros for efficient bit shifting

These parameters enable efficient parsing of binary data packets received from the device.

### Value Range Configuration

- **maxBits**: Maximum valid input value in bits (upper limit of ADC range)
- **midBits**: Middle input value in bits (zero voltage reference point)
- **minBits** (calculated): Minimum valid input value, calculated to maintain symmetry around midpoint

These parameters define the device's ADC (Analog-to-Digital Converter) range and establish the mapping between digital values and voltages.

### Data Trimming Configuration

- **discardHead**: Number of samples to discard from the beginning of each data stream
- **discardTrailer**: Number of samples to discard from the end of each data stream

These parameters allow for removing potentially invalid samples at the edges of data streams.

### Voltage Scale Configuration

- **voltageScales**: List of available voltage scale configurations for the device

This provides device-specific voltage scales that may differ from the default scales.

## Serialization Support

The class includes comprehensive JSON serialization capabilities:

1. **fromJson factory**: Parses device configuration from JSON, with robust error handling and default values
2. **toJson method**: Converts the configuration to a JSON-compatible map for storage or transmission

These methods enable configuration persistence and retrieval from device API endpoints.

## Configuration Updates

The `copyWith` method implements the immutable update pattern:

- Creates a new configuration instance with specific parameters modified
- Preserves all unmodified parameters from the original
- Ensures configuration updates don't have unexpected side effects

This method is crucial for safely updating specific configuration parameters without affecting others.

## Deprecated Parameters

The class includes proper handling of legacy parameters:

- **usefulBits**: A deprecated parameter retained for backward compatibility
- Appropriate compiler annotations to mark deprecated members

This ensures compatibility with older code while encouraging migration to newer parameters.

## Integration Context

Within the oscilloscope application, this configuration model:

1. Is initially populated from the device's API during setup
2. Informs voltage scaling calculations for accurate display
3. Guides data packet parsing for correct signal extraction
4. Determines available voltage scale options in the UI
5. Affects time-domain calculations and display

The comprehensive design of this configuration model ensures that the application can adapt to different oscilloscope hardware variants while maintaining consistent functionality.