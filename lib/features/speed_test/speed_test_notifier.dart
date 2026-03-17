import 'package:flutter/foundation.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SpeedTestPhase { idle, selectingServer, ping, download, upload, complete }

@immutable
class SpeedTestState {
  final SpeedTestPhase phase;
  final double downloadSpeed; // Mbps
  final double uploadSpeed; // Mbps
  final double ping; // ms
  final double jitter; // ms
  final double currentSpeed; // real-time during test
  final double progress; // 0.0 - 1.0
  final String? userCity;
  final String? userCountry;
  final String? serverCity;
  final String? serverCountry;
  final String? error;

  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.downloadSpeed = 0,
    this.uploadSpeed = 0,
    this.ping = 0,
    this.jitter = 0,
    this.currentSpeed = 0,
    this.progress = 0,
    this.userCity,
    this.userCountry,
    this.serverCity,
    this.serverCountry,
    this.error,
  });

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    double? downloadSpeed,
    double? uploadSpeed,
    double? ping,
    double? jitter,
    double? currentSpeed,
    double? progress,
    String? userCity,
    String? userCountry,
    String? serverCity,
    String? serverCountry,
    String? error,
  }) {
    return SpeedTestState(
      phase: phase ?? this.phase,
      downloadSpeed: downloadSpeed ?? this.downloadSpeed,
      uploadSpeed: uploadSpeed ?? this.uploadSpeed,
      ping: ping ?? this.ping,
      jitter: jitter ?? this.jitter,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      progress: progress ?? this.progress,
      userCity: userCity ?? this.userCity,
      userCountry: userCountry ?? this.userCountry,
      serverCity: serverCity ?? this.serverCity,
      serverCountry: serverCountry ?? this.serverCountry,
      error: error,
    );
  }
}

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  SpeedTestNotifier() : super(const SpeedTestState());

  SpeedTestService? _service;

  Future<void> startTest() async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.complete) {
      return;
    }

    _service = SpeedTestService();
    state = const SpeedTestState(phase: SpeedTestPhase.selectingServer);

    try {
      // Get user location in parallel with server selection
      final locationFuture = _service!.getUserLocation();

      // Select best server
      final server = await _service!.selectBestServer();
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
      final downloadSpeed = await _service!.measureDownloadSpeed(
        server,
        onProgress: (speed) {
          state = state.copyWith(currentSpeed: speed);
        },
      );
      state = state.copyWith(
        downloadSpeed: downloadSpeed,
        progress: 1.0,
      );

      // Upload phase
      state = state.copyWith(
        phase: SpeedTestPhase.upload,
        progress: 0,
        currentSpeed: 0,
      );
      final uploadSpeed = await _service!.measureUploadSpeed(
        server,
        onProgress: (speed) {
          state = state.copyWith(currentSpeed: speed);
        },
      );
      state = state.copyWith(
        uploadSpeed: uploadSpeed,
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
    state = const SpeedTestState(phase: SpeedTestPhase.idle);
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
