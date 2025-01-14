// test/integration_test/data_processing_profilling_test.dart

import 'dart:math';
import 'package:flutter_test/flutter_test.dart';
import 'package:arg_osci_app/features/graph/domain/models/data_point.dart';
import 'package:arg_osci_app/features/graph/domain/services/data_acquisition_service.dart';
import 'package:arg_osci_app/features/graph/domain/services/fft_chart_service.dart';
import 'package:arg_osci_app/features/graph/providers/data_provider.dart';
import 'package:arg_osci_app/features/http/domain/models/http_config.dart';
import 'package:arg_osci_app/features/socket/domain/models/socket_connection.dart';
import 'package:arg_osci_app/features/graph/domain/models/filter_types.dart';
import 'dart:io';
import 'dart:async';

void main() {
  late DataAcquisitionService dataAcquisitionService;
  late GraphProvider graphProvider;
  late FFTChartService fftService;
  late File logFile;
  final stopwatch = Stopwatch();

  Map<String, double> calculateStats(List<DataPoint> points) {
    final n = points.length;
    if (n == 0) return {'mean': 0.0, 'std': 0.0};
    
    final mean = points.map((p) => p.y).reduce((a, b) => a + b) / n;
    final variance = points.map((p) => pow(p.y - mean, 2))
                          .reduce((a, b) => a + b) / n;
    
    return {
      'mean': mean,
      'std': sqrt(variance)
    };
  }

  void logPerformance(String operation, int dataSize, int durationMicros, 
      {String? error, Map<String, dynamic>? extraData}) {
    final timestamp = DateTime.now();
    final logEntry = StringBuffer()
      ..writeln('=== $operation ===')
      ..writeln('Timestamp: $timestamp')
      ..writeln('Data Size: $dataSize points')
      ..writeln('Duration: ${durationMicros}µs');
    
    if (extraData != null) {
      logEntry.writeln('Additional Data:');
      extraData.forEach((key, value) {
        logEntry.writeln('  $key: ${value.toStringAsFixed(6)}');
      });
    }
    
    if (error != null) {
      logEntry.writeln('Error: $error');
    }
    
    logEntry.writeln('-' * 50);
    
    try {
      logFile.writeAsStringSync(logEntry.toString(), mode: FileMode.append);
    } catch (e) {
      print('Error writing to log: $e');
    }
  }

  setUp(() async {
    final httpConfig = HttpConfig('http://localhost:8080');
    final socketConnection = SocketConnection('localhost', 8080);
    
    dataAcquisitionService = DataAcquisitionService(httpConfig);
    await dataAcquisitionService.initialize();
    
    graphProvider = GraphProvider(dataAcquisitionService, socketConnection);
    fftService = FFTChartService(graphProvider);

    final logDir = Directory('test/integration_test');
    if (!logDir.existsSync()) {
      logDir.createSync(recursive: true);
    }

    logFile = File('log/data_processing_performance.log');
    if (!logFile.existsSync()) {
      logFile.createSync();
    }
    
    logFile.writeAsStringSync('\n=== Test Run ${DateTime.now()} ===\n', 
        mode: FileMode.append);
    await Future.delayed(const Duration(milliseconds: 500));
  });

  group('Data Processing Performance Tests', () {
    test('Filter Performance Test', () async {
      final dataSizes = [1000, 10000, 100000];
      final filters = [
        MovingAverageFilter(),
        ExponentialFilter(),
        LowPassFilter()
      ];

      for (final size in dataSizes) {
        final points = List.generate(
          size,
          (i) => DataPoint(i * 0.001, sin(2 * pi * i / 100))
        );

        for (final filter in filters) {
          try {
            graphProvider.setFilter(filter);
            stopwatch.reset();
            stopwatch.start();
            
            final filtered = filter.apply(points, {
              'windowSize': 5,
              'alpha': 0.2,
              'cutoffFrequency': 100.0
            });
            
            stopwatch.stop();
            
            final inputStats = calculateStats(points);
            final outputStats = calculateStats(filtered);
            
            logPerformance(
              'Filter: ${filter.runtimeType}',
              size,
              stopwatch.elapsedMicroseconds,
              extraData: {
                'input_mean': inputStats['mean']!,
                'input_std': inputStats['std']!,
                'output_mean': outputStats['mean']!,
                'output_std': outputStats['std']!
              }
            );
            
            expect(filtered.length, equals(points.length));
          } catch (e) {
            logPerformance(
              'Filter: ${filter.runtimeType}',
              size,
              -1,
              error: e.toString()
            );
            rethrow;
          }
        }
      }
    });

    test('FFT Processing Performance Test', () async {
      final fftResults = <List<DataPoint>>[];
      final completer = Completer<void>();

      final sub = fftService.fftStream.listen((fft) {
        fftResults.add(fft);
        completer.complete();
      });

      final points = List.generate(
        FFTChartService.blockSize,
        (i) => DataPoint(
          i.toDouble(),
          sin(2 * pi * 10 * i / FFTChartService.blockSize) + 
          0.5 * sin(2 * pi * 20 * i / FFTChartService.blockSize)
        )
      );

      stopwatch.reset();
      stopwatch.start();
      
      graphProvider.addPoints(points);

      try {
        await completer.future.timeout(const Duration(seconds: 10));
        
        stopwatch.stop();
        
        final fftStats = calculateStats(fftResults.first);
        
        logPerformance(
          'FFT Processing',
          FFTChartService.blockSize,
          stopwatch.elapsedMicroseconds,
          extraData: {
            'fft_mean': fftStats['mean']!,
            'fft_std': fftStats['std']!
          }
        );

        expect(fftResults.length, equals(1));
        expect(fftResults.first.isNotEmpty, isTrue);
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