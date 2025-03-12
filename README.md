# ARG_OSCI - Oscilloscope Visualization Tool

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](https://opensource.org/licenses/MIT)

ARG_OSCI is a versatile oscilloscope visualization tool designed to capture and display real-time data, offering functionalities for signal analysis in both time and frequency domains. It provides a user-friendly interface for configuring data acquisition, adjusting display settings, and analyzing signals, making it suitable for educational, hobbyist, and professional use.

## For Users

This project is useful because it allows you to visualize and analyze electrical signals from hardware, offering features such as adjustable voltage scales, trigger settings, and filter options. It supports both Oscilloscope and Spectrum Analyzer modes, enabling you to examine signals in the time domain and frequency domain, respectively. The application is designed to be cross-platform, with support for Windows, Linux, and Android.

### How to Get Started

1. **Download the App:**
    * **Windows:** Download the `windows-release.zip` file from the latest release in the [Releases](https://github.com/ArgOsciProyect/ARG_OSCI_APP/releases) section. Extract the contents and run the executable.
    * **Linux:** Download the `.AppImage`, `.deb`, or `.rpm` package from the latest release. Make the `.AppImage` executable (`chmod +x arg-osci-1.0.0-x86_64.AppImage`) and run it. Install the `.deb` or `.rpm` package using your distribution's package manager.
    * **Android:** Download the `arg-osci-<version>.apk` file from the latest release and install it on your Android device. You may need to enable "Install from Unknown Sources" in your device settings.

2. **Connect to Your Device:** The application is designed to connect to an ESP32 device via Wi-Fi. Ensure your ESP32 is set up and broadcasting a Wi-Fi network.

3. **Initial Setup:**

    * Open the ARG_OSCI application.

    * **Android:**
        * The app will attempt to automatically connect to the ESP32's Wi-Fi network ("ESP32\_AP").
        * If auto-connection fails, you may need to manually connect to the "ESP32\_AP" network in your device's Wi-Fi settings.

    * **Windows/Linux:**
        * You will need to manually connect your computer to the ESP32's Wi-Fi network ("ESP32\_AP") through your operating system's network settings.

    * Once connected to the ESP32's Wi-Fi network, the app will guide you through the remaining setup steps.

    * Follow the on-screen instructions to configure the connection.

4. **Select a Mode:**
    * After successfully connecting to the ESP32, you'll be presented with a mode selection screen.
    * Choose between "Oscilloscope" mode for time-domain analysis or "Spectrum Analyzer" mode for frequency-domain analysis.

5. **Start Visualizing Data:**
    * Once in the selected mode, the application will start streaming data from the ESP32 and visualizing it in real-time.
    * Use the available controls to adjust the voltage scale, trigger settings, and other parameters to optimize the display for your signal.

## For Contributors

Thank you for considering contributing to ARG_OSCI! This project aims to provide a robust and user-friendly oscilloscope visualization tool. Your contributions can help improve its functionality, stability, and user experience.

The codebase is structured around Flutter and GetX, utilizing a modular architecture to separate concerns. Key areas for contribution include:

* **Data Acquisition:** Improving the reliability and efficiency of data capture from hardware devices.
* **Signal Processing:** Enhancing the signal processing algorithms for both time and frequency domain analysis.
* **User Interface:** Developing new UI components and improving the usability of existing ones.
* **Platform Support:** Extending the application to support additional platforms and devices.

To get started, familiarize yourself with the project structure and coding conventions. More detailed information on how to contribute, including guidelines for submitting pull requests, can be found in the [CONTRIBUTING.md](CONTRIBUTING.md) file.

If you need more help, refer to the project's documentation, which includes details on the data acquisition process, signal processing algorithms, and UI components. You can also explore the source code, which is extensively commented to explain the functionality of each module. Additionally, the project utilizes GitHub Actions for continuous integration, with workflow files in `.github/workflows` that detail the build and deployment processes for different platforms.

## Acknowledgements

This project is part of the ARG_OSCI oscilloscope visualization tool suite. For the firmware and hardware used, visit the [ARG_OSCI_FIRMWARE repository](https://github.com/ArgOsciProyect/ARG_OSCI_FIRMWARE) and the [ARG_OSCI_HARDWARE repository](https://github.com/ArgOsciProyect/ARG_OSCI_HARDWARE).
