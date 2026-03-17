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

class SpeedTestService {
  static const List<SpeedTestServer> servers = [
    SpeedTestServer(host: '217.144.184.135', port: 8880, city: 'Ufa', country: 'Russia'),
    SpeedTestServer(host: '213.165.50.230', port: 8880, city: 'New York', country: 'USA'),
    SpeedTestServer(host: '62.60.235.92', port: 8880, city: 'Amsterdam', country: 'Netherlands'),
  ];

  static const int _parallelStreams = 4;

  late final Dio _dio;
  CancelToken? _cancelToken;
  final bool useDirectConnection;

  SpeedTestService({this.useDirectConnection = true}) {
    _dio = Dio(
      BaseOptions(
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 60),
        sendTimeout: const Duration(seconds: 60),
      ),
    );
    if (useDirectConnection) {
      _dio.httpClientAdapter = IOHttpClientAdapter(
        createHttpClient: () {
          final client = HttpClient();
          client.findProxy = (_) => 'DIRECT';
          return client;
        },
      );
    }
    // When useDirectConnection is false, use default adapter (goes through VPN)
  }

  void cancel() {
    _cancelToken?.cancel('Speed test cancelled');
    _cancelToken = null;
  }

  void dispose() {
    cancel();
    _dio.close();
  }

  /// Pick the server with the lowest ping
  Future<SpeedTestServer> selectBestServer() async {
    SpeedTestServer? best;
    double bestPing = double.infinity;

    for (final server in servers) {
      try {
        final stopwatch = Stopwatch()..start();
        await _dio.head(
          '${server.baseUrl}/',
          options: Options(
            receiveTimeout: const Duration(seconds: 3),
          ),
        );
        stopwatch.stop();
        final rtt = stopwatch.elapsedMilliseconds.toDouble();
        if (rtt < bestPing) {
          bestPing = rtt;
          best = server;
        }
      } catch (_) {
        // Server unreachable, skip
      }
    }

    return best ?? servers.first;
  }

  /// Measure ping (median) and jitter (mean consecutive difference)
  Future<({double ping, double jitter})> measurePing(
    SpeedTestServer server, {
    void Function(double currentPing)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    final rtts = <double>[];

    for (int i = 0; i < 10; i++) {
      if (_cancelToken?.isCancelled ?? false) break;
      try {
        final stopwatch = Stopwatch()..start();
        await _dio.head(
          '${server.baseUrl}/',
          cancelToken: _cancelToken,
          options: Options(
            receiveTimeout: const Duration(seconds: 5),
          ),
        );
        stopwatch.stop();
        rtts.add(stopwatch.elapsedMilliseconds.toDouble());
        onProgress?.call(rtts.last);
      } catch (e) {
        if (e is DioException && e.type == DioExceptionType.cancel) rethrow;
        // Skip failed pings
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (rtts.isEmpty) {
      return (ping: 0.0, jitter: 0.0);
    }

    // Median ping
    final sorted = List<double>.from(rtts)..sort();
    final median = sorted.length.isOdd
        ? sorted[sorted.length ~/ 2]
        : (sorted[sorted.length ~/ 2 - 1] + sorted[sorted.length ~/ 2]) / 2;

    // Jitter: average absolute difference between consecutive RTTs
    double jitterSum = 0;
    for (int i = 1; i < rtts.length; i++) {
      jitterSum += (rtts[i] - rtts[i - 1]).abs();
    }
    final jitter = rtts.length > 1 ? jitterSum / (rtts.length - 1) : 0.0;

    return (ping: median, jitter: jitter);
  }

  /// Measure download speed in Mbps using parallel streams
  Future<double> measureDownloadSpeed(
    SpeedTestServer server, {
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    final stopwatch = Stopwatch()..start();
    int totalBytes = 0;
    double lastSpeed = 0;
    final completer = Completer<double>();

    // Progress reporting timer
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (stopwatch.elapsedMilliseconds > 0) {
        lastSpeed = (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
        onProgress?.call(lastSpeed);
      }
      if (stopwatch.elapsed >= duration && !completer.isCompleted) {
        _cancelToken?.cancel('Duration reached');
      }
    });

    int streamsCompleted = 0;

    void _onStreamFinished() {
      streamsCompleted++;
      if (streamsCompleted >= _parallelStreams && !completer.isCompleted) {
        progressTimer?.cancel();
        stopwatch.stop();
        final speed = stopwatch.elapsedMilliseconds > 0
            ? (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000)
            : 0.0;
        completer.complete(speed);
      }
    }

    // Launch parallel download streams
    for (int i = 0; i < _parallelStreams; i++) {
      _launchDownloadStream(server, duration, stopwatch, (bytes) {
        totalBytes += bytes;
      }).then((_) {
        _onStreamFinished();
      }).catchError((_) {
        _onStreamFinished();
      });
    }

    return await completer.future;
  }

  Future<void> _launchDownloadStream(
    SpeedTestServer server,
    Duration duration,
    Stopwatch stopwatch,
    void Function(int bytes) onData,
  ) async {
    try {
      final response = await _dio.get<ResponseBody>(
        '${server.baseUrl}/garbage?ckSize=100',
        cancelToken: _cancelToken,
        options: Options(
          responseType: ResponseType.stream,
          receiveTimeout: const Duration(seconds: 60),
        ),
      );

      final stream = response.data!.stream;
      final streamCompleter = Completer<void>();

      StreamSubscription<List<int>>? subscription;
      subscription = stream.listen(
        (chunk) {
          onData(chunk.length);
          if (stopwatch.elapsed >= duration) {
            subscription?.cancel();
            if (!streamCompleter.isCompleted) streamCompleter.complete();
          }
        },
        onDone: () {
          if (!streamCompleter.isCompleted) streamCompleter.complete();
        },
        onError: (_) {
          if (!streamCompleter.isCompleted) streamCompleter.complete();
        },
        cancelOnError: false,
      );

      await streamCompleter.future;
    } on DioException {
      // Stream cancelled or failed — expected when duration reached
    }
  }

  /// Measure upload speed in Mbps using parallel streams
  Future<double> measureUploadSpeed(
    SpeedTestServer server, {
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelToken = CancelToken();
    // Pre-generate upload data once (4MB)
    const chunkSize = 4 * 1024 * 1024;
    final random = Random();
    final uploadData = Uint8List(chunkSize);
    for (int i = 0; i < chunkSize; i++) {
      uploadData[i] = random.nextInt(256);
    }

    final stopwatch = Stopwatch()..start();
    int totalBytes = 0;
    double lastSpeed = 0;

    // Progress reporting timer
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (stopwatch.elapsedMilliseconds > 0) {
        lastSpeed = (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000);
        onProgress?.call(lastSpeed);
      }
    });

    final completer = Completer<double>();
    int streamsCompleted = 0;

    void _onStreamFinished() {
      streamsCompleted++;
      if (streamsCompleted >= _parallelStreams && !completer.isCompleted) {
        progressTimer?.cancel();
        stopwatch.stop();
        final speed = stopwatch.elapsedMilliseconds > 0
            ? (totalBytes * 8) / (stopwatch.elapsedMilliseconds * 1000)
            : 0.0;
        completer.complete(speed);
      }
    }

    // Launch parallel upload streams
    for (int i = 0; i < _parallelStreams; i++) {
      _launchUploadStream(server, duration, stopwatch, uploadData, chunkSize, (bytes) {
        totalBytes += bytes;
      }).then((_) {
        _onStreamFinished();
      }).catchError((_) {
        _onStreamFinished();
      });
    }

    return await completer.future;
  }

  Future<void> _launchUploadStream(
    SpeedTestServer server,
    Duration duration,
    Stopwatch stopwatch,
    Uint8List uploadData,
    int chunkSize,
    void Function(int bytes) onData,
  ) async {
    try {
      while (stopwatch.elapsed < duration) {
        if (_cancelToken?.isCancelled ?? false) break;

        try {
          await _dio.post(
            '${server.baseUrl}/empty',
            data: uploadData,
            cancelToken: _cancelToken,
            options: Options(
              contentType: 'application/octet-stream',
              headers: {'Content-Length': chunkSize},
              sendTimeout: const Duration(seconds: 30),
              receiveTimeout: const Duration(seconds: 10),
            ),
          );
          onData(chunkSize);
        } on DioException catch (e) {
          if (e.type == DioExceptionType.cancel) break;
          break;
        }
      }
    } catch (_) {
      // Stream finished
    }
  }

  /// Get user's geo location using ip-api.com
  Future<({String? city, String? country})> getUserLocation() async {
    try {
      final response = await _dio.get<Map<String, dynamic>>(
        'http://ip-api.com/json/',
        options: Options(
          receiveTimeout: const Duration(seconds: 5),
        ),
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
