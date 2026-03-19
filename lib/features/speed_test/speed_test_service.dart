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

/// Speed test server descriptor
class SpeedServer {
  final String name;
  final String city;
  final String countryCode;
  final String pingUrl;
  final String downloadUrl;
  final String uploadUrl;

  const SpeedServer({
    required this.name,
    required this.city,
    required this.countryCode,
    required this.pingUrl,
    required this.downloadUrl,
    required this.uploadUrl,
  });
}

/// Known speed test servers — traffic goes THROUGH VPN (no DIRECT bypass).
/// Primary: user's own Marzban VPS nodes.
/// Fallbacks: public CDN endpoints that work in Russia.
class SpeedServers {
  // ── User's own servers (aeza.net) — LibreSpeed on port 8880 ─────────────
  static const driftNl = SpeedServer(
    name: 'Drift NL',
    city: 'Amsterdam',
    countryCode: 'NL',
    pingUrl: 'http://62.60.235.92:8880/backend/empty.php',
    downloadUrl: 'http://62.60.235.92:8880/backend/garbage.php?ckSize=100',
    uploadUrl: 'http://62.60.235.92:8880/backend/empty.php',
  );

  static const driftRu = SpeedServer(
    name: 'Drift RU',
    city: 'Москва',
    countryCode: 'RU',
    pingUrl: 'http://217.144.184.135:8880/backend/empty.php',
    downloadUrl: 'http://217.144.184.135:8880/backend/garbage.php?ckSize=100',
    uploadUrl: 'http://217.144.184.135:8880/backend/empty.php',
  );

  static const driftUs = SpeedServer(
    name: 'Drift US',
    city: 'New York',
    countryCode: 'US',
    pingUrl: 'http://213.165.50.230:8880/backend/empty.php',
    downloadUrl: 'http://213.165.50.230:8880/backend/garbage.php?ckSize=100',
    uploadUrl: 'http://213.165.50.230:8880/backend/empty.php',
  );

  // ── Public fallbacks — Russia-accessible ───────────────────────────────────
  // Fast.com uses Netflix CDN — generally accessible in Russia via VPN
  static const fastCom = SpeedServer(
    name: 'Fast.com',
    city: 'Global CDN',
    countryCode: 'US',
    pingUrl: 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNk&urlCount=1',
    downloadUrl: 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNk&urlCount=1',
    uploadUrl: 'https://api.fast.com/netflix/speedtest/v2?https=true&token=YXNkZmFzZGxmbnNkYWZoYXNk&urlCount=1',
  );

  // Cloudflare — blocked in Russia without VPN but accessible through VPN
  static const cloudflare = SpeedServer(
    name: 'Cloudflare',
    city: 'Global CDN',
    countryCode: 'US',
    pingUrl: 'https://speed.cloudflare.com/__down?bytes=0',
    downloadUrl: 'https://speed.cloudflare.com/__down?bytes=10000000',
    uploadUrl: 'https://speed.cloudflare.com/__up',
  );

  static const all = [driftNl, driftRu, driftUs, cloudflare];
}

class SpeedTestService {
  bool _disposed = false;
  bool _cancelled = false;

  /// Create HttpClient that routes through the system proxy (=VPN tunnel).
  /// DO NOT set findProxy to 'DIRECT' — that would bypass the VPN!
  HttpClient _createVpnClient() {
    final client = HttpClient();
    client.badCertificateCallback = (cert, host, port) => true;
    client.connectionTimeout = const Duration(seconds: 10);
    // No findProxy set → uses system proxy → goes through VPN ✓
    return client;
  }

  void cancel() {
    _cancelled = true;
  }

  void dispose() {
    _disposed = true;
    _cancelled = true;
  }

  /// Probe servers and return the first reachable one.
  /// Returns null if no server responds (VPN not connected?).
  Future<SpeedServer?> selectBestServer({
    void Function(String status)? onStatus,
  }) async {
    onStatus?.call('Поиск сервера...');
    for (final server in SpeedServers.all) {
      if (_cancelled || _disposed) break;
      try {
        onStatus?.call('Проверка ${server.city}...');
        final client = _createVpnClient();
        final uri = Uri.parse(server.pingUrl);
        final req = await client.getUrl(uri).timeout(const Duration(seconds: 6));
        final resp = await req.close().timeout(const Duration(seconds: 6));
        await resp.drain<void>();
        client.close();
        return server;
      } catch (_) {
        // try next
      }
    }
    return null;
  }

  /// Measure ping (median RTT) and jitter
  Future<({double ping, double jitter})> measurePing({
    required SpeedServer server,
    void Function(double currentPing)? onProgress,
  }) async {
    _cancelled = false;
    final rtts = <double>[];

    for (int i = 0; i < 10; i++) {
      if (_disposed || _cancelled) break;
      try {
        final sw = Stopwatch()..start();
        final client = _createVpnClient();
        final req = await client.getUrl(Uri.parse(server.pingUrl));
        final resp = await req.close().timeout(const Duration(seconds: 5));
        await resp.drain<void>();
        sw.stop();
        client.close();
        rtts.add(sw.elapsedMilliseconds.toDouble());
        onProgress?.call(rtts.last);
      } catch (_) {
        // skip failed pings
      }
      await Future.delayed(const Duration(milliseconds: 100));
    }

    if (rtts.isEmpty) return (ping: 0.0, jitter: 0.0);

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

  /// Measure download speed through VPN
  Future<double> measureDownloadSpeed({
    required SpeedServer server,
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelled = false;
    const int streamCount = 6;
    int totalBytes = 0;
    final sw = Stopwatch()..start();

    late final Timer progressTimer;
    // ignore: prefer_final_locals
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (sw.elapsedMilliseconds > 0 && !_cancelled && !_disposed) {
        final speed = (totalBytes * 8) / (sw.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
      if (sw.elapsed >= duration || _cancelled || _disposed) {
        t.cancel();
      }
    });

    try {
      final futures = List.generate(streamCount, (_) async {
        final client = _createVpnClient();
        try {
          while (!_disposed && !_cancelled && sw.elapsed < duration) {
            try {
              final req = await client.getUrl(Uri.parse(server.downloadUrl));
              final resp = await req.close();
              await for (final chunk in resp) {
                totalBytes += chunk.length;
                if (sw.elapsed >= duration || _cancelled || _disposed) break;
              }
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
      progressTimer.cancel();
      sw.stop();
    }

    return sw.elapsedMilliseconds > 0
        ? (totalBytes * 8) / (sw.elapsedMilliseconds * 1000)
        : 0.0;
  }

  /// Measure upload speed through VPN
  Future<double> measureUploadSpeed({
    required SpeedServer server,
    Duration duration = const Duration(seconds: 10),
    void Function(double currentSpeedMbps)? onProgress,
  }) async {
    _cancelled = false;
    const int streamCount = 4;
    const chunkSize = 2 * 1024 * 1024; // 2 MB
    final random = Random();
    final uploadData = Uint8List(chunkSize);
    for (int i = 0; i < chunkSize; i++) {
      uploadData[i] = random.nextInt(256);
    }

    int totalBytes = 0;
    final sw = Stopwatch()..start();

    late final Timer progressTimer;
    // ignore: prefer_final_locals
    progressTimer = Timer.periodic(const Duration(milliseconds: 250), (t) {
      if (sw.elapsedMilliseconds > 0 && !_cancelled && !_disposed) {
        final speed = (totalBytes * 8) / (sw.elapsedMilliseconds * 1000);
        onProgress?.call(speed);
      }
      if (sw.elapsed >= duration || _cancelled || _disposed) {
        t.cancel();
      }
    });

    try {
      final futures = List.generate(streamCount, (_) async {
        final client = _createVpnClient();
        try {
          while (!_disposed && !_cancelled && sw.elapsed < duration) {
            try {
              final req = await client.postUrl(Uri.parse(server.uploadUrl));
              req.headers.contentType = ContentType.binary;
              req.contentLength = uploadData.length;
              req.add(uploadData);
              final resp = await req.close();
              await resp.drain<void>();
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
      progressTimer.cancel();
      sw.stop();
    }

    return sw.elapsedMilliseconds > 0
        ? (totalBytes * 8) / (sw.elapsedMilliseconds * 1000)
        : 0.0;
  }
}
