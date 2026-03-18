import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:dio/io.dart';

class SpeedTestServer {
  final String host;
  final int port;
  final String city;
  final String country;

  const SpeedTestServer({
    required this.host,
    required this.port,
    required this.city,
    required this.country,
  });

  String get baseUrl => 'http://$host:$port';
}

/// Format speed value for display: always 2 decimal places for final values
String formatSpeed(double speed) {
  if (speed <= 0) return '--';
  return speed.toStringAsFixed(2);
}

/// Format speed during live test (less precise)
String formatSpeedLive(double speed) {
  if (speed <= 0) return '--';
  if (speed >= 10) return speed.toStringAsFixed(0);
  if (speed >= 1) return speed.toStringAsFixed(1);
  return speed.toStringAsFixed(2);
}

class SpeedTestService {
  /// Russian server — used when VPN is OFF (domestic traffic, fast)
  static const SpeedTestServer russianServer =
      SpeedTestServer(host: '217.144.184.135', port: 8880, city: 'Москва', country: 'Russia');

  /// Map of VPN server IPs to their SpeedTestServer definitions
  static const Map<String, SpeedTestServer> vpnServers = {
    '213.165.50.230': SpeedTestServer(host: '213.165.50.230', port: 8880, city: 'Нью-Йорк', country: 'USA'),
    '217.144.184.135': SpeedTestServer(host: '217.144.184.135', port: 8880, city: 'Москва', country: 'Russia'),
  };

  static const List<SpeedTestServer> allServers = [
    russianServer,
    SpeedTestServer(host: '213.165.50.230', port: 8880, city: 'Нью-Йорк', country: 'USA'),
  ];

  late final Dio _dio;
  CancelToken? _cancelToken;
  bool _disposed = false;

  SpeedTestService() {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    // Force DIRECT connections — bypass any local Hiddify proxy
    // When VPN is ON, traffic goes through the VPN tunnel at the OS level anyway
    _dio.httpClientAdapter = IOHttpClientAdapter(
      createHttpClient: () {
        final client = HttpClient();
        client.findProxy = (_) => 'DIRECT';
        return client;
      },
    );
  }

  void cancel() {
    _cancelToken?.cancel('Speed test cancelled');
    _cancelToken = null;
  }

  void dispose() {
    _disposed = true;
    cancel();
    _dio.close();
  }

  /// Select the appropriate server based on VPN state.
  /// If [vpnServerIp] is provided (VPN is ON), use that server.
  /// Otherwise, use the Russian server (domestic, fast).
  SpeedTestServer selectServer({String? vpnServerIp}) {
    if (vpnServerIp != null && vpnServers.containsKey(vpnServerIp)) {
      return vpnServers[vpnServerIp]!;
    }
    // Default: Russian server for domestic speed test
    return russianServer;
  }

  /// Measure ping (median) and jitter (mean consecutive difference)
  Future<({double ping, double jitter})> measurePing(
    SpeedTestServer server, {
    void Function(double currentPing)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    final rtts = <double>[];

    for (int i = 0; i < 10; i++) {
      if (_disposed || (_cancelToken?.isCancelled ?? false)) break;
      try {
        final stopwatch = Stopwatch()..start();
        await _dio.get(
          '${server.baseUrl}/backend/empty.php',
          cancelToken: _cancelToken,
          options: Options(receiveTimeout: const Duration(seconds: 5)),
        );
        stopwatch.stop();
        rtts.add(stopwatch.elapsedMilliseconds.toDouble());
        onProgress?.call(rtts.last);
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (rtts.isEmpty) {
      return (ping: 0.0, jitter: 0.0);
    }

    final sorted = List<double>.from(rtts)..sort();
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;

    double jitterSum = 0;
    for (int i = 1; i < rtts.length; i++) {
      jitterSum += (rtts[i] - rtts[i - 1]).abs();
    }
    final jitter = rtts.length > 1 ? jitterSum / (rtts.length - 1) : 0.0;

    return (ping: median, jitter: jitter);
  }

  /// Measure download speed using MULTIPLE parallel streams (8 connections)
  Future<double> measureDownloadSpeed(
    SpeedTestServer server, {
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    const int streamCount = 8;
    final stopwatch = Stopwatch()..start();
    int totalBytes = 0;
    final completer = Completer<double>();

    // Progress reporting timer — fires every 250ms
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (stopwatch.elapsedMilliseconds > 0) {
        final speed = (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
      if (stopwatch.elapsed >= duration) {
        _cancelToken?.cancel('Duration reached');
      }
    });

    try {
      // Launch multiple parallel download streams
      final streamFutures = List.generate(streamCount, (i) async {
        // Each stream downloads continuously until cancelled
        while (!_disposed && !(_cancelToken?.isCancelled ?? false) && stopwatch.elapsed < duration) {
          try {
            final response = await _dio.get<ResponseBody>(
              '${server.baseUrl}/backend/garbage.php?ckSize=100',
              cancelToken: _cancelToken,
              options: Options(
                responseType: ResponseType.stream,
                receiveTimeout: const Duration(seconds: 60),
              ),
            );

            final stream = response.data!.stream;
            await for (final chunk in stream) {
              totalBytes += chunk.length;
              if (stopwatch.elapsed >= duration || (_cancelToken?.isCancelled ?? false)) {
                break;
              }
            }
          } on DioException {
            // Expected when duration reached or cancelled
            break;
          } catch (_) {
            break;
          }
        }
      });

      await Future.wait(streamFutures);
    } finally {
      progressTimer?.cancel();
      stopwatch.stop();
      if (!completer.isCompleted) {
        final speed = stopwatch.elapsedMilliseconds > 0
            ? (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000)
            : 0.0;
        completer.complete(speed);
      }
    }

    return await completer.future;
  }

  /// Measure upload speed using MULTIPLE parallel streams (6 connections)
  Future<double> measureUploadSpeed(
    SpeedTestServer server, {
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    const int streamCount = 6;
    // Pre-generate 10MB of random data (shared across streams)
    const chunkSize = 10 * 1024 * 1024;
    final random = Random();
    final uploadData = Uint8List(chunkSize);
    for (int i = 0; i < chunkSize; i++) {
      uploadData[i] = random.nextInt(256);
    }

    final stopwatch = Stopwatch()..start();
    int totalBytes = 0;

    // Progress reporting timer — fires every 250ms
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (stopwatch.elapsedMilliseconds > 0) {
        final speed = (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
    });

    try {
      // Launch multiple parallel upload streams
      final streamFutures = List.generate(streamCount, (i) async {
        while (!_disposed && !(_cancelToken?.isCancelled ?? false) && stopwatch.elapsed < duration) {
          try {
            await _dio.post(
              '${server.baseUrl}/backend/empty.php',
              data: uploadData, // Send Uint8List directly — fixes upload
              cancelToken: _cancelToken,
              options: Options(
                contentType: 'application/octet-stream',
                headers: {'Content-Length': chunkSize},
                sendTimeout: const Duration(seconds: 30),
                receiveTimeout: const Duration(seconds: 10),
              ),
            );
            totalBytes += chunkSize;
          } on DioException catch (e) {
            if (e.type == DioExceptionType.cancel) break;
            // On other errors, retry after brief delay
            await Future.delayed(const Duration(milliseconds: 100));
          } catch (_) {
            break;
          }
        }
      });

      await Future.wait(streamFutures);
    } finally {
      progressTimer?.cancel();
      stopwatch.stop();
    }

    return stopwatch.elapsedMilliseconds > 0
        ? (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000)
        : 0.0;
  }

  /// Get user's geo location using ip-api.com
  Future<({String? city, String? country})> getUserLocation() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'http://ip-api.com/json/',
        options: Options(receiveTimeout: const Duration(seconds: 5)),
      );
      final data = response.data;
      if (data != null && data['status'] == 'success') {
        return (
          city: data['city'] as String?,
          country: data['country'] as String?,
        );
      }
    } catch (_) {
      // Geo-location is best-effort
    }
    return (city: null, country: null);
  }
}
