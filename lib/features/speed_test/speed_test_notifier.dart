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
  final String? error;

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
    this.error,
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
    String? error,
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
      error: error,
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

  /// Start the speed test.
  /// [vpnServerIp] — if VPN is connected, pass the connected server's IP.
  /// When null, tests against the Russian server (domestic traffic).
  Future<void> startTest({String? vpnServerIp}) async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.complete) {
      return;
    }

    _service = SpeedTestService();
    state = const SpeedTestState(
      phase: SpeedTestPhase.selectingServer,
    );

    try {
      // Get user location in parallel with server selection
      final locationFuture = _service!.getUserLocation();

      // Select server based on VPN state
      final server = _service!.selectServer(vpnServerIp: vpnServerIp);
      state = state.copyWith(
        serverCity: server.city,
        serverCountry: server.country,
      );

      final location = await locationFuture;
      state = state.copyWith(
        userCity: location.city,
        userCountry: location.country,
      );

      // Ping phase
      state = state.copyWith(phase: SpeedTestPhase.ping, progress: 0);
      final pingResult = await _service!.measurePing(
        server,
        onProgress: (currentPing) {
          state = state.copyWith(currentSpeed: currentPing);
        },
      );

      state = state.copyWith(
        ping: pingResult.ping,
        jitter: pingResult.jitter,
        progress: 1.0,
      );

      // Download phase
      state = state.copyWith(
        phase: SpeedTestPhase.download,
        progress: 0,
        currentSpeed: 0,
      );
      final dlSpeed = await _service!.measureDownloadSpeed(
        server,
        onProgress: (speed) {
          state = state.copyWith(currentSpeed: speed);
        },
      );

      // Store exact value
      state = state.copyWith(downloadSpeed: dlSpeed, progress: 1.0);

      // Upload phase
      state = state.copyWith(
        phase: SpeedTestPhase.upload,
        progress: 0,
        currentSpeed: 0,
      );
      final ulSpeed = await _service!.measureUploadSpeed(
        server,
        onProgress: (speed) {
          state = state.copyWith(currentSpeed: speed);
        },
      );

      // Store exact value
      state = state.copyWith(
        uploadSpeed: ulSpeed,
        progress: 1.0,
        phase: SpeedTestPhase.complete,
        currentSpeed: 0,
      );
    } catch (e) {
      state = state.copyWith(
        phase: SpeedTestPhase.idle,
        error: 'Speed test failed: ${e.toString()}',
      );
    } finally {
      _service?.dispose();
      _service = null;
    }
  }

  void cancelTest() {
    _service?.cancel();
    _service?.dispose();
    _service = null;
    state = state.copyWith(
      phase: SpeedTestPhase.idle,
      currentSpeed: 0,
    );
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
