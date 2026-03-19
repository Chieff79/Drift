import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SpeedTestPhase { idle, selectingServer, ping, download, upload, complete }

@immutable
class SpeedTestState {
  final SpeedTestPhase phase;
  final double currentSpeed; // real-time gauge value
  final double progress; // 0.0 - 1.0
  final String? userCity;
  final String? userCountry;
  final String? serverCity;
  final String? serverCountry;
  final String? serverName;
  final String? error;
  final String? statusMessage;

  final double? downloadSpeed;
  final double? uploadSpeed;
  final double? ping;
  final double? jitter;

  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.currentSpeed = 0,
    this.progress = 0,
    this.userCity,
    this.userCountry,
    this.serverCity,
    this.serverCountry,
    this.serverName,
    this.error,
    this.statusMessage,
    this.downloadSpeed,
    this.uploadSpeed,
    this.ping,
    this.jitter,
  });

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? currentSpeed,
    double? progress,
    String? userCity,
    String? userCountry,
    String? serverCity,
    String? serverCountry,
    String? serverName,
    String? error,
    String? statusMessage,
    double? downloadSpeed,
    double? uploadSpeed,
    double? ping,
    double? jitter,
  }) {
    return SpeedTestState(
      phase: phase ?? this.phase,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      progress: progress ?? this.progress,
      userCity: userCity ?? this.userCity,
      userCountry: userCountry ?? this.userCountry,
      serverCity: serverCity ?? this.serverCity,
      serverCountry: serverCountry ?? this.serverCountry,
      serverName: serverName ?? this.serverName,
      error: error,
      statusMessage: statusMessage ?? this.statusMessage,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      jitter: jitter ?? this.jitter,
    );
  }
}

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  SpeedTestNotifier() : super(const SpeedTestState());

  SpeedTestService? _service;

  /// Fetch user's real IP info to populate City A (where user is)
  Future<Map<String, String>> _fetchUserLocation() async {
    try {
      final client = HttpClient()
        ..connectionTimeout = const Duration(seconds: 6)
        ..findProxy = (uri) => 'DIRECT';
      final req = await client.getUrl(Uri.parse('https://ipapi.co/json/'));
      req.headers.set('User-Agent', 'Mozilla/5.0');
      final resp = await req.close().timeout(const Duration(seconds: 6));
      if (resp.statusCode == 200) {
        final body = await resp.transform(const SystemEncoding().decoder).join();
        final city = _extractJson(body, 'city') ?? '';
        final country = _extractJson(body, 'country_name') ?? _extractJson(body, 'country') ?? '';
        final countryCode = _extractJson(body, 'country_code') ?? '';
        client.close();
        return {'city': city, 'country': country, 'countryCode': countryCode};
      }
      client.close();
    } catch (_) {}
    return {};
  }

  String? _extractJson(String body, String key) {
    final pattern = RegExp('"$key"\\s*:\\s*"([^"]*)"');
    return pattern.firstMatch(body)?.group(1);
  }

  /// Start the speed test. Traffic goes THROUGH the VPN.
  Future<void> startTest() async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.complete) {
      return;
    }

    _service = SpeedTestService();

    // Kick off user location lookup in parallel (non-blocking)
    final userLocationFuture = _fetchUserLocation();

    state = const SpeedTestState(
      phase: SpeedTestPhase.selectingServer,
      statusMessage: 'Поиск сервера...',
    );

    try {
      // ── 1. Select server ────────────────────────────────────────────────────
      final server = await _service!.selectBestServer(
        onStatus: (msg) {
          if (!_disposed) state = state.copyWith(statusMessage: msg);
        },
      );

      if (server == null) {
        state = state.copyWith(
          phase: SpeedTestPhase.idle,
          error: 'Не удалось подключиться к серверу. Включён ли VPN?',
        );
        return;
      }

      // Apply server info to state
      state = state.copyWith(
        serverCity: server.city,
        serverCountry: server.countryCode,
        serverName: server.name,
        statusMessage: 'Сервер: ${server.city}',
      );

      // Wait for user location (should be done by now)
      final userLoc = await userLocationFuture;
      if (userLoc.isNotEmpty) {
        state = state.copyWith(
          userCity: userLoc['city'],
          userCountry: userLoc['countryCode'],
        );
      }

      // ── 2. Ping phase ───────────────────────────────────────────────────────
      state = state.copyWith(phase: SpeedTestPhase.ping, progress: 0, currentSpeed: 0);
      final pingResult = await _service!.measurePing(
        server: server,
        onProgress: (currentPing) {
          if (!_disposed) state = state.copyWith(currentSpeed: currentPing);
        },
      );
      state = state.copyWith(
        ping: pingResult.ping,
        jitter: pingResult.jitter,
        progress: 1.0,
      );

      // ── 3. Download phase ───────────────────────────────────────────────────
      state = state.copyWith(phase: SpeedTestPhase.download, progress: 0, currentSpeed: 0);
      final dlSpeed = await _service!.measureDownloadSpeed(
        server: server,
        onProgress: (speed) {
          if (!_disposed) state = state.copyWith(currentSpeed: speed);
        },
      );
      state = state.copyWith(downloadSpeed: dlSpeed, progress: 1.0);

      // ── 4. Upload phase ─────────────────────────────────────────────────────
      state = state.copyWith(phase: SpeedTestPhase.upload, progress: 0, currentSpeed: 0);
      final ulSpeed = await _service!.measureUploadSpeed(
        server: server,
        onProgress: (speed) {
          if (!_disposed) state = state.copyWith(currentSpeed: speed);
        },
      );
      state = state.copyWith(
        uploadSpeed: ulSpeed,
        progress: 1.0,
        phase: SpeedTestPhase.complete,
        currentSpeed: 0,
        statusMessage: null,
      );
    } catch (e) {
      state = state.copyWith(
        phase: SpeedTestPhase.idle,
        error: 'Ошибка теста скорости: ${e.toString()}',
      );
    } finally {
      _service?.dispose();
      _service = null;
    }
  }

  bool get _disposed => !mounted;

  void cancelTest() {
    _service?.cancel();
    _service?.dispose();
    _service = null;
    state = state.copyWith(phase: SpeedTestPhase.idle, currentSpeed: 0);
  }

  void reset() {
    _service?.cancel();
    _service?.dispose();
    _service = null;
    state = const SpeedTestState();
  }

  @override
  void dispose() {
    _service?.cancel();
    _service?.dispose();
    super.dispose();
  }
}

final speedTestNotifierProvider =
    StateNotifierProvider.autoDispose<SpeedTestNotifier, SpeedTestState>(
  (ref) => SpeedTestNotifier(),
);
