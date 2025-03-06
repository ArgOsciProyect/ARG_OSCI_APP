# Contributing to ARG_OSCI

We welcome contributions to ARG_OSCI! Whether you're fixing a bug, adding a new feature, or improving documentation, your help is greatly appreciated. Please read this guide to understand how to contribute effectively.

## Code of Conduct

Please note that this project is released with a [Contributor Covenant Code of Conduct](CODE_OF_CONDUCT.md). By participating in this project, you agree to abide by its terms.

## How to Contribute

1.  **Fork the Repository:** Start by forking the ARG_OSCI repository to your GitHub account.

2.  **Clone the Fork:** Clone your forked repository to your local machine:

    ```bash
    git clone https://github.com/ArgOsciProyect/ARG_OSCI_APP.git
    cd ARG_OSCI
    ```

3.  **Create a Branch:** Create a new branch for your feature or bug fix:

    ```bash
    git checkout -b feature/your-feature-name
    ```

    or

    ```bash
    git checkout -b fix/your-bug-fix
    ```

4.  **Make Changes:** Implement your changes, adhering to the project's coding standards and guidelines.

5.  **Test Your Changes:** Ensure your changes are thoroughly tested and do not introduce new issues. Run existing tests and add new tests as necessary. Use the following command to run tests:

    ```bash
    flutter test
    ```

6.  **Format Your Code:** Format your code using Dart's formatting tool to maintain consistency:

    ```bash
    dart format .
    ```

7.  **Analyze Your Code:** Run Flutter's analyzer to catch any potential issues:

    ```bash
    flutter analyze
    ```

8.  **Commit Your Changes:** Commit your changes with a clear and concise message:

    ```bash
    git commit -m "Add: your feature description"
    ```

    or

    ```bash
    git commit -m "Fix: your bug fix description"
    ```

9.  **Push to GitHub:** Push your branch to your forked repository:

    ```bash
    git push origin feature/your-feature-name
    ```

    or

    ```bash
    git push origin fix/your-bug-fix
    ```

10. **Create a Pull Request:** Submit a pull request (PR) from your branch to the main repository's `main` or `develop` branch. Provide a detailed description of your changes and reference any related issues.

## General Description

This oscilloscope application, developed in **Flutter**, communicates with an **ESP32** device via **Wi-Fi**. It allows the acquisition, visualization, and analysis of data in real-time, offering functionalities for signal processing and spectral analysis.

## Project Overview

The application is structured around several key components:

*   **Data Acquisition:** Responsible for capturing real-time data from the ESP32 device via Wi-Fi. This involves establishing a socket connection, receiving data packets, and processing the raw data into a usable format.
*   **Signal Processing:** Implements algorithms for signal processing, including FFT (Fast Fourier Transform) for frequency domain analysis and various digital filters for noise reduction and signal enhancement.
*   **Visualization:** Provides real-time visualization of the acquired and processed data in both the time domain (oscilloscope) and frequency domain (FFT). This includes customizable charts, scales, and display settings.
*   **User Interface:** Offers a user-friendly interface for configuring data acquisition, adjusting display settings, and analyzing signals. The UI is designed to be cross-platform, with support for Windows, Linux, and Android.
*   **Configuration and Setup:** Handles the initial setup process, including connecting to the ESP32 device, configuring Wi-Fi settings, and managing device parameters.

## Project Structure

The project follows a modular structure, separating concerns into distinct directories. Here's a breakdown of the key directories and their responsibilities:

### Key Components

*   **Models:** Define the data structures used throughout the application. These classes represent the data that the application manipulates, such as `DataPoint`, `DeviceConfig`, `WiFiCredentials`, and `SocketConnection`.
*   **Services:** Implement the core business logic and interact with external resources. Services encapsulate complex operations, such as data acquisition, signal processing, network communication, and device setup. Examples include `DataAcquisitionService`, `SocketService`, `HttpService`, `SetupService`, `OscilloscopeChartService`, and `FFTChartService`.
*   **Repositories:** Provide an abstraction layer for data access, allowing the application to switch between different data sources. Repositories define interfaces for data operations, such as fetching device configurations, connecting to Wi-Fi networks, and sending HTTP requests.
*   **Providers:** Manage the application's state using GetX, providing reactive data streams to the UI. Providers encapsulate the application's state and logic, allowing the UI to react to changes in data and settings. Examples include `DataAcquisitionProvider`, `DeviceConfigProvider`, `SetupProvider`, `OscilloscopeChartProvider`, `FFTChartProvider`, and `UserSettingsProvider`.
*   **Screens:** Contain full screens that include a Scaffold. These screens represent complete views of the application, including the arrangement of widgets, navigation, and user interaction. For example, `SetupScreen` provides the initial setup screen for the application.
*   **Widgets:** Contain all the widgets necessary for a particular feature. These reusable components encapsulate parts of the user interface, allowing for modular and maintainable construction of views. For example, `OsciloscopeChart` and `FFTChart` are widgets that display the oscilloscope and FFT charts, respectively.
*   **Initializers:** The `Initializer` class in `lib/config/initializer.dart` is responsible for setting up the application's dependencies and services at startup. It ensures that all necessary components are initialized and registered with GetX for dependency injection.
*   **Configurations:** The `HttpConfig` class in `lib/http/domain/models/http_config.dart` defines the base URL and client instance for making HTTP requests to the oscilloscope API endpoints. It allows the application to configure the HTTP client and base URL for different environments.

### Key folders

*   `lib/config`: Contains configuration files, such as the app theme (`app_theme.dart`) and dependency injection setup (`initializer.dart`). The `Initializer` class is responsible for initializing all necessary dependencies for the app, ensuring that services and providers are correctly set up at startup.
*   `lib/features`: Contains feature-specific modules, such as `graph`, `setup`, and `socket`.
*   `test`: Contains unit tests and integration tests.

## Requirements

*   **REQ-SW-01: Real-time visualization in the time domain:** Ensure the software accurately represents the signal graphically in the time domain.
*   **REQ-SW-02: Real-time visualization in the frequency domain:** Implement FFT to calculate and display the frequency spectrum of the input signal.
*   **REQ-SW-03: Wi-Fi communication for control and data:** Establish and maintain bidirectional communication with the hardware via Wi-Fi.
*   **REQ-SW-04: Connection to an external access point:** Allow users to configure the device's connection to an external Wi-Fi network.
*   **REQ-SW-05: Data and credentials security:** Implement RSA encryption for all transmitted credentials.
*   **REQ-SW-06: Configurable digital trigger:** Provide a user-configurable digital trigger system with options for level, slope, and modes.
*   **REQ-SW-07: Linux compatibility:** Ensure the software functions correctly on Debian and RedHat-based Linux distributions.
*   **REQ-SW-08: Windows compatibility:** Ensure the software functions correctly on Windows 10 and Windows 11.
*   **REQ-SW-09: Android compatibility:** Ensure the software functions correctly on Android 8.0 or higher.
*   **REQ-SW-10: Configurable digital filters:** Implement user-configurable digital filters, including low-pass and moving average filters.
*   **REQ-SW-11: Interface for custom filter implementation:** Provide a documented API for advanced users to implement custom filters.
*   **REQ-SW-12: Variable zoom in visualizations:** Implement dynamic zoom in the time and frequency domain visualizations.
*   **REQ-SW-13: Bidirectional scrolling of graphs:** Allow horizontal and vertical scrolling of graphs with dynamic restrictions.
*   **REQ-SW-14: Selection of voltage scale:** Offer a selection of predefined voltage scales via a dedicated control in the interface.

## Reporting Bugs

If you find a bug, please submit an issue on GitHub with a clear description of the problem, steps to reproduce it, and any relevant error messages or logs.

## Suggesting Enhancements

If you have an idea for a new feature or enhancement, please submit an issue on GitHub with a detailed description of your proposal.

## Getting Help

If you need help with contributing or have any questions, feel free to reach out to the project maintainers or other contributors via GitHub issues or discussions.

Thank you for your contributions!