// test/integration_test/data_processing_profilling_test.dart

import 'dart:math';
import 'dart:io';
import 'dart:async';
import 'package:arg_osci_app/features/graph/providers/device_config_provider.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_acquisition_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'package:get/get.dart';

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
    final timestamp = DateTime.now();
    final logEntry = StringBuffer()
      ..writeln('\n=== Test Case: $testCase ===')
      ..writeln('Operation: $operation')
      ..writeln('Timestamp: $timestamp')
      ..writeln('Data Size: $dataSize points')
      ..writeln(
          'Block Info: ${dataSize ~/ 8192 * 2} blocks of ${8192 * 2} points')
      ..writeln(
          'Duration: ${durationMicros}µs (${(durationMicros / 1000).toStringAsFixed(2)}ms)');

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

    try {
      logFile.writeAsStringSync(logEntry.toString(), mode: FileMode.append);
    } catch (e) {
      print('Error writing to log: $e');
    }
  }

  setUp(() async {
    TestWidgetsFlutterBinding.ensureInitialized();

    // Initialize GetX dependencies first
    final deviceConfigProvider = DeviceConfigProvider();
    Get.put<DeviceConfigProvider>(deviceConfigProvider, permanent: true);

    // Allow GetX to process
    await Future.delayed(Duration.zero);

    // Then create services
    final httpConfig = HttpConfig('http://localhost:8080');
    final socketConnection = SocketConnection('localhost', 8080);

    dataAcquisitionService = DataAcquisitionService(httpConfig);
    await dataAcquisitionService.initialize();

    graphProvider =
        DataAcquisitionProvider(dataAcquisitionService, socketConnection);
    fftService = FFTChartService(graphProvider);

    // Setup logging
    final logDir = Directory('log');
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

    logFile = File('log/data_processing_performance_python.log');
    if (!logFile.existsSync()) {
      logFile.createSync();
    }

    logFile.writeAsStringSync(
        '\n${'#' * 100}\nTest Run: ${DateTime.now()}\n${'#' * 100}\n',
        mode: FileMode.append);
  });
  tearDown(() async {
    await dataAcquisitionService.dispose();
    await fftService.dispose();
    Get.reset(); // Clean up GetX dependencies
  });

  group('Digital Signal Processing Performance Tests', () {
    test('Filter Performance - Various Data Sizes', () async {
      final dataSizes = [1000, 10000, 100000];
      final filters = [
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

            // Add default filter settings
            final filterSettings = {
              'windowSize': 5.0,
              'alpha': 0.2,
              'cutoffFrequency': 100.0,
              'samplingFrequency': 1650000.0, // Add sampling frequency
            };

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
            print('Timeout waiting for FFT processing');
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
