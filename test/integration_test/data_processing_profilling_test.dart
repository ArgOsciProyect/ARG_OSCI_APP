// test/integration_test/data_processing_profilling_test.dart

import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:arg_osci_app/features/graph/domain/models/trigger_data.dart';
import 'package:arg_osci_app/features/graph/domain/services/oscilloscope_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:arg_osci_app/features/graph/providers/user_settings_provider.dart';
import 'package:arg_osci_app/features/http/domain/services/http_service.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:get/get.dart';
import 'package:mockito/mockito.dart';

const String LOG_FILE_PATH =
    '/home/jotalora/Tesis/ARG_OSCI_APP/test/integration_test/logs/osci_test_performance_99.log';

// First add mock HTTP service
class MockHttpService extends Mock implements HttpService {
  @override
  Future<Response<dynamic>> post(String path, [dynamic data]) async {
    return Response(
      body: {'status': 'success'},
      statusCode: 200,
    );
  }

  @override
  Future<Response<dynamic>> get(String path) async {
    switch (path) {
      case '/config':
        return Response(
          body: {
            'sampling_frequency': 1650000.0,
            'bits_per_packet': 16,
            'data_mask': 0x0FFF,
            'channel_mask': 0xF000,
            'useful_bits': 9,
            'samples_per_packet': 8192,
          },
          statusCode: 200,
        );
      default:
        throw Exception('Unknown endpoint');
    }
  }
}

class MockUserSettingsProvider extends GetxController
    implements UserSettingsProvider {
  @override
  final mode = RxString('Oscilloscope');
  @override
  final title = RxString('');
  @override
  final frequencySource = FrequencySource.timeDomain.obs;
  @override
  final frequency = 0.0.obs;

  // Remove dependencies on other services
  @override
  final OscilloscopeChartService oscilloscopeService =
      OscilloscopeChartService(null);
  @override
  final FFTChartService fftChartService = FFTChartService(null);

  @override
  void setMode(String newMode) => mode.value = newMode;

  @override
  void setFrequencySource(FrequencySource source) =>
      frequencySource.value = source;

  @override
  Widget getCurrentChart() => Container();

  @override
  void navigateToMode(String selectedMode) {}

  @override
  bool get showFFTControls => false;

  @override
  bool get showTimebaseControls => true;

  @override
  bool get showTriggerControls => true;

  @override
  List<String> get availableModes => ['Oscilloscope', 'FFT'];
}

// Test signal generation helpers
List<DataPoint> generateSineWave(
    int size, double frequency, double amplitude, double sampleRate) {
  return List.generate(
      size,
      (i) => DataPoint(i / sampleRate,
          amplitude * sin(2 * pi * frequency * i / sampleRate)));
}

List<DataPoint> generateComplexSignal(int size, double sampleRate) {
  return List.generate(
      size,
      (i) => DataPoint(
          i / sampleRate,
          sin(2 * pi * 10 * i / sampleRate) +
              0.5 * sin(2 * pi * 20 * i / sampleRate) +
              0.25 * sin(2 * pi * 40 * i / sampleRate)));
}

void main() {
  late DataAcquisitionService dataAcquisitionService;
  late DataAcquisitionProvider graphProvider;
  late FFTChartService fftService;
  late File logFile;
  final stopwatch = Stopwatch();

  // Performance metrics calculation
  Map<String, double> calculateStats(List<DataPoint> points) {
    final n = points.length;
    if (n == 0) return {'mean': 0.0, 'std': 0.0};

    final mean = points.map((p) => p.y).reduce((a, b) => a + b) / n;
    final variance =
        points.map((p) => pow(p.y - mean, 2)).reduce((a, b) => a + b) / n;

    return {'mean': mean, 'std': sqrt(variance)};
  }

  // Enhanced logging with test case info
  void logPerformance(
      String testCase, String operation, int dataSize, int durationMicros,
      {String? error, Map<String, dynamic>? extraData}) {
    try {
      final logFile = File(LOG_FILE_PATH);

      // Ensure directory exists
      if (!logFile.parent.existsSync()) {
        logFile.parent.createSync(recursive: true);
      }

      // Create file if doesn't exist
      if (!logFile.existsSync()) {
        logFile.createSync();
      }

      final timestamp = DateTime.now();
      final logEntry = StringBuffer()
        ..writeln('\n=== Test Case: $testCase ===')
        ..writeln('Operation: $operation')
        ..writeln('Timestamp: $timestamp')
        ..writeln('Data Size: $dataSize points')
        ..writeln(
            'Block Info: ${dataSize ~/ 8192 * 2} blocks of ${8192 * 2} points')
        ..writeln(
            'Duration: $durationMicrosµs (${(durationMicros / 1000).toStringAsFixed(2)}ms)');

      if (extraData != null) {
        logEntry.writeln('\nPerformance Metrics:');
        extraData.forEach((key, value) {
          logEntry.writeln('  $key: ${value.toStringAsFixed(6)}');
        });
      }

      if (error != null) {
        logEntry.writeln('\nError:');
        logEntry.writeln('  $error');
      }

      logEntry.writeln('\n${'=' * 80}\n');

      // Use IOSink for buffered writing
      final sink = logFile.openWrite(mode: FileMode.append);
      sink.write(logEntry.toString());
      // Ensure data is written
      sink.flush();
      sink.close();

      if (kDebugMode) {
        print('Logged entry to file: $LOG_FILE_PATH');
        print(logEntry.toString());
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error writing to log: $e');
        print('Attempted to write to: $LOG_FILE_PATH');
      }
    }
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();
    Get.reset();

    // Initialize log file first
    try {
      final logFile = File(LOG_FILE_PATH);
      if (!logFile.existsSync()) {
        if (!logFile.parent.existsSync()) {
          logFile.parent.createSync(recursive: true);
        }
        logFile.createSync();
        // Write header only once
        logFile.writeAsStringSync(
            '=== Performance Test Results ===\n' +
                'Started at: ${DateTime.now()}\n\n',
            mode: FileMode.append);
      }
      if (kDebugMode) {
        print('Using log file at $LOG_FILE_PATH');
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error initializing log file: $e');
      }
    }

    // Rest of setup...
    final deviceConfigProvider = DeviceConfigProvider();
    Get.put<DeviceConfigProvider>(deviceConfigProvider);

    final mockHttpService = MockHttpService();
    Get.put<HttpService>(mockHttpService, permanent: true);

    final mockUserSettings = MockUserSettingsProvider();
    Get.put<UserSettingsProvider>(mockUserSettings, permanent: true);

    final httpConfig = HttpConfig('http://localhost:8080');
    dataAcquisitionService = DataAcquisitionService(httpConfig);
    await dataAcquisitionService.initialize();

    final socketConnection = SocketConnection('localhost', 8080);
    graphProvider =
        DataAcquisitionProvider(dataAcquisitionService, socketConnection);
    Get.put<DataAcquisitionProvider>(graphProvider, permanent: true);

    fftService = FFTChartService(graphProvider);
    Get.put<FFTChartService>(fftService);

    // Service configuration
    dataAcquisitionService.scale = 3.3 / 512;
    dataAcquisitionService.triggerLevel = 0.0;
    dataAcquisitionService.triggerEdge = TriggerEdge.positive;
    dataAcquisitionService.triggerMode = TriggerMode.normal;
    dataAcquisitionService.useHysteresis = false;
    dataAcquisitionService.useLowPassFilter = false;
  });

  tearDown(() async {
    await dataAcquisitionService.dispose();
    await fftService.dispose();
    Get.reset();

    try {
      final logFile = File(LOG_FILE_PATH);
      if (logFile.existsSync()) {
        final content = logFile.readAsStringSync();
        if (kDebugMode) {
          print('Log file content:');
          print(content);
        }
      }
    } catch (e) {
      if (kDebugMode) {
        print('Error reading log file: $e');
      }
    }
  });

  group('Digital Signal Processing Performance Tests', () {
    test('Filter Performance - Various Data Sizes', () async {
      final dataSizes = [1000, 10000, 100000];
      final filters = <FilterType>[
        MovingAverageFilter(),
        ExponentialFilter(),
        LowPassFilter()
      ];
      const sampleRate = 1650000.0;

      for (final size in dataSizes) {
        final points = generateSineWave(size, 1000.0, 1.0, sampleRate);

        for (final filter in filters) {
          try {
            graphProvider.setFilter(filter);
            stopwatch.reset();
            stopwatch.start();

            // Type-safe filter settings
            final Map<String, dynamic> filterSettings;
            if (filter is MovingAverageFilter) {
              filterSettings = {
                'windowSize': 5,
                'samplingFrequency': sampleRate,
              };
            } else if (filter is ExponentialFilter) {
              filterSettings = {
                'alpha': 0.2,
                'samplingFrequency': sampleRate,
              };
            } else {
              filterSettings = {
                'cutoffFrequency': 100.0,
                'samplingFrequency': sampleRate,
              };
            }

            final filtered = filter.apply(points, filterSettings);

            stopwatch.stop();

            final inputStats = calculateStats(points);
            final outputStats = calculateStats(filtered);

            logPerformance(
                'Filter Benchmark',
                '${filter.runtimeType} with $size points',
                size,
                stopwatch.elapsedMicroseconds,
                extraData: {
                  'input_mean': inputStats['mean']!,
                  'input_std': inputStats['std']!,
                  'output_mean': outputStats['mean']!,
                  'output_std': outputStats['std']!,
                  'points_per_second':
                      size / (stopwatch.elapsedMicroseconds / 1000000)
                });

            expect(filtered.length, equals(points.length));
          } catch (e) {
            logPerformance('Filter Error',
                '${filter.runtimeType} with $size points', size, -1,
                error: e.toString());
            rethrow;
          }
        }
      }
    });
    test('Single FFT Block Performance', () async {
      final fftResults = <List<DataPoint>>[];
      final completer = Completer<void>();
      const sampleRate = 1600000.0;

      final sub = fftService.fftStream.listen((fft) {
        fftResults.add(fft);
        completer.complete();
      });

      try {
        final points = generateComplexSignal(8192 * 2, sampleRate);

        stopwatch.reset();
        stopwatch.start();
        graphProvider.addPoints(points);
        await completer.future.timeout(const Duration(seconds: 10));
        stopwatch.stop();

        final fftStats = calculateStats(fftResults.first);

        logPerformance('Single FFT Block', 'FFT Processing', 8192 * 2,
            stopwatch.elapsedMicroseconds,
            extraData: {
              'fft_mean': fftStats['mean']!,
              'fft_std': fftStats['std']!,
              'processing_time_ms': stopwatch.elapsedMicroseconds / 1000.0
            });

        expect(fftResults.length, equals(1));
        expect(fftResults.first.isNotEmpty, isTrue);
      } finally {
        await sub.cancel();
      }
    });

    test('Continuous Stream FFT Performance', () async {
      const numBlocks = 5;
      final allFftResults = <List<DataPoint>>[];
      final processingTimes = <int>[];
      var blocksReceived = 0;
      var blocksSent = 0;
      const sampleRate = 1600000.0;

      final sub = fftService.fftStream.listen((fft) {
        allFftResults.add(fft);
        processingTimes.add(stopwatch.elapsedMicroseconds);
        blocksReceived++;
      });

      try {
        final points = generateComplexSignal(8192 * 2, sampleRate);
        stopwatch.start();

        // Simulate real-time data stream
        for (var i = 0; i < numBlocks && blocksReceived < numBlocks; i++) {
          graphProvider.addPoints(points);
          blocksSent++;
          await Future.delayed(const Duration(milliseconds: 50));
        }

        // Wait for processing completion
        while (blocksReceived < blocksSent) {
          await Future.delayed(const Duration(milliseconds: 10));
          if (stopwatch.elapsed > const Duration(seconds: 20)) {
            if (kDebugMode) {
              print('Timeout waiting for FFT processing');
            }
            break;
          }
        }

        stopwatch.stop();
        final totalTime = stopwatch.elapsedMicroseconds;
        final throughput = (blocksReceived * 8192 * 2) / (totalTime / 1000000);
        final averageProcessingTime =
            blocksReceived > 0 ? totalTime / blocksReceived : 0;

        logPerformance('Continuous FFT Stream', 'Multiple Blocks Processing',
            blocksReceived * 8192 * 2, totalTime,
            extraData: {
              'blocks_sent': blocksSent.toDouble(),
              'blocks_received': blocksReceived.toDouble(),
              'total_time_ms': totalTime / 1000.0,
              'throughput_points_per_second': throughput,
              'average_block_time_ms': averageProcessingTime / 1000.0,
              'processing_ratio': blocksReceived / blocksSent.toDouble(),
              'min_block_time_ms': processingTimes.isNotEmpty
                  ? processingTimes.reduce(min) / 1000.0
                  : 0,
              'max_block_time_ms': processingTimes.isNotEmpty
                  ? processingTimes.reduce(max) / 1000.0
                  : 0,
              'data_rate_mbps': (8192 * 2 * 4 * 8 * blocksReceived) /
                  (totalTime / 1000000) /
                  1000000
            });

        expect(blocksReceived, greaterThan(0));
        expect(allFftResults.every((block) => block.isNotEmpty), isTrue);
      } finally {
        await sub.cancel();
      }
    });
  });

  tearDown(() async {
    await dataAcquisitionService.dispose();
    await fftService.dispose();
  });
}
