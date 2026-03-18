import 'dart:async';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

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
  /// LibreSpeed fallback server
  static const String _libreSpeedHost = '217.144.184.135';
  static const int _libreSpeedPort = 8880;

  bool _disposed = false;
  bool _cancelled = false;

  /// Create a fresh HttpClient that bypasses any proxy (including Hiddify)
  HttpClient _createDirectClient() {
    final client = HttpClient();
    client.findProxy = (_) => 'DIRECT';
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 10);
    return client;
  }

  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _disposed = true;
    _cancelled = true;
  }

  /// Measure ping (median RTT) and jitter using Cloudflare endpoint
  Future<({double ping, double jitter})> measurePing({
    void Function(double currentPing)? onProgress,
  }) async {
    _cancelled = false;
    final rtts = <double>[];

    // Try Cloudflare first
    var client = _createDirectClient();
    bool useFallback = false;

    for (int i = 0; i < 10; i++) {
      if (_disposed || _cancelled) break;
      try {
        final sw = Stopwatch()..start();
        final uri = useFallback
            ? Uri.parse('http://$_libreSpeedHost:$_libreSpeedPort/backend/empty.php')
            : Uri.parse('https://speed.cloudflare.com/__down?bytes=0');
        final request = await client.getUrl(uri);
        final response = await request.close();
        await response.drain<void>();
        sw.stop();
        rtts.add(sw.elapsedMilliseconds.toDouble());
        onProgress?.call(rtts.last);
      } catch (_) {
        // If first Cloudflare attempt fails, switch to fallback
        if (i == 0 && !useFallback) {
          useFallback = true;
          client.close(force: true);
          client = _createDirectClient();
        }
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    client.close(force: true);

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

  /// Measure download speed using dart:io HttpClient with Cloudflare CDN
  /// Falls back to LibreSpeed if Cloudflare fails
  Future<double> measureDownloadSpeed({
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelled = false;
    const int streamCount = 6;
    int totalBytes = 0;
    final sw = Stopwatch()..start();

    // Try Cloudflare first with a quick probe
    bool useCloudflare = await _probeCloudflare();

    // Progress reporting timer
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (sw.elapsedMilliseconds > 0 && !_cancelled && !_disposed) {
        final speed = (totalBytes * 8) / (sw.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
      if (sw.elapsed >= duration || _cancelled || _disposed) {
        progressTimer?.cancel();
      }
    });

    try {
      final futures = List.generate(streamCount, (_) async {
        final client = _createDirectClient();
        try {
          while (!_disposed && !_cancelled && sw.elapsed < duration) {
            try {
              final uri = useCloudflare
                  ? Uri.parse('https://speed.cloudflare.com/__down?bytes=10000000')
                  : Uri.parse('http://$_libreSpeedHost:$_libreSpeedPort/backend/garbage.php?ckSize=100');
              final request = await client.getUrl(uri);
              final response = await request.close();
              await for (final chunk in response) {
                totalBytes += chunk.length;
                if (sw.elapsed >= duration || _cancelled || _disposed) break;
              }
            } catch (_) {
              // If Cloudflare stream fails mid-test, just break this stream
              break;
            }
          }
        } finally {
          client.close(force: true);
        }
      });

      await Future.wait(futures);
    } finally {
      progressTimer?.cancel();
      sw.stop();
    }

    return sw.elapsedMilliseconds > 0
        ? (totalBytes * 8) / (sw.elapsedMilliseconds * 1000)
        : 0.0;
  }

  /// Measure upload speed using dart:io HttpClient with Cloudflare CDN
  /// Falls back to LibreSpeed if Cloudflare fails
  Future<double> measureUploadSpeed({
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelled = false;
    const int streamCount = 4;
    // Pre-generate 2MB of random data
    const chunkSize = 2 * 1024 * 1024;
    final random = Random();
    final uploadData = Uint8List(chunkSize);
    for (int i = 0; i < chunkSize; i++) {
      uploadData[i] = random.nextInt(256);
    }

    int totalBytes = 0;
    final sw = Stopwatch()..start();

    bool useCloudflare = await _probeCloudflare();

    // Progress reporting timer
    Timer? progressTimer;
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      if (sw.elapsedMilliseconds > 0 && !_cancelled && !_disposed) {
        final speed = (totalBytes * 8) / (sw.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
      if (sw.elapsed >= duration || _cancelled || _disposed) {
        progressTimer?.cancel();
      }
    });

    try {
      final futures = List.generate(streamCount, (_) async {
        final client = _createDirectClient();
        try {
          while (!_disposed && !_cancelled && sw.elapsed < duration) {
            try {
              final uri = useCloudflare
                  ? Uri.parse('https://speed.cloudflare.com/__up')
                  : Uri.parse('http://$_libreSpeedHost:$_libreSpeedPort/backend/empty.php');
              final request = await client.postUrl(uri);
              request.headers.contentType = ContentType.binary;
              request.contentLength = uploadData.length;
              request.add(uploadData);
              final response = await request.close();
              await response.drain<void>();
              totalBytes += uploadData.length;
            } catch (_) {
              break;
            }
          }
        } finally {
          client.close(force: true);
        }
      });

      await Future.wait(futures);
    } finally {
      progressTimer?.cancel();
      sw.stop();
    }

    return sw.elapsedMilliseconds > 0
        ? (totalBytes * 8) / (sw.elapsedMilliseconds * 1000)
        : 0.0;
  }

  /// Quick probe to check if Cloudflare is reachable
  Future<bool> _probeCloudflare() async {
    final client = _createDirectClient();
    try {
      final request = await client.getUrl(
        Uri.parse('https://speed.cloudflare.com/__down?bytes=0'),
      ).timeout(const Duration(seconds: 5));
      final response = await request.close().timeout(const Duration(seconds: 5));
      await response.drain<void>();
      return true;
    } catch (_) {
      return false;
    } finally {
      client.close(force: true);
    }
  }
}
