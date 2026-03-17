import 'package:flutter/foundation.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum SpeedTestPhase { idle, selectingServer, ping, download, upload, complete }

enum SpeedTestMode { beforeVpn, afterVpn }

@immutable
class SpeedTestState {
  final SpeedTestPhase phase;
  final SpeedTestMode mode;
  final double currentSpeed; // real-time gauge value
  final double progress; // 0.0 - 1.0
  final String? userCity;
  final String? userCountry;
  final String? serverCity;
  final String? serverCountry;
  final String? error;

  // "Before VPN" results
  final double? beforeDownload;
  final double? beforeUpload;
  final double? beforePing;
  final double? beforeJitter;

  // "After VPN" results
  final double? afterDownload;
  final double? afterUpload;
  final double? afterPing;
  final double? afterJitter;

  const SpeedTestState({
    this.phase = SpeedTestPhase.idle,
    this.mode = SpeedTestMode.beforeVpn,
    this.currentSpeed = 0,
    this.progress = 0,
    this.userCity,
    this.userCountry,
    this.serverCity,
    this.serverCountry,
    this.error,
    this.beforeDownload,
    this.beforeUpload,
    this.beforePing,
    this.beforeJitter,
    this.afterDownload,
    this.afterUpload,
    this.afterPing,
    this.afterJitter,
  });

  // Current mode getters
  double get downloadSpeed => mode == SpeedTestMode.beforeVpn
      ? (beforeDownload ?? 0)
      : (afterDownload ?? 0);
  double get uploadSpeed => mode == SpeedTestMode.beforeVpn
      ? (beforeUpload ?? 0)
      : (afterUpload ?? 0);
  double get ping => mode == SpeedTestMode.beforeVpn
      ? (beforePing ?? 0)
      : (afterPing ?? 0);
  double get jitter => mode == SpeedTestMode.beforeVpn
      ? (beforeJitter ?? 0)
      : (afterJitter ?? 0);

  bool get hasBothResults =>
      beforeDownload != null && afterDownload != null;

  SpeedTestState copyWith({
    SpeedTestPhase? phase,
    SpeedTestMode? mode,
    double? currentSpeed,
    double? progress,
    String? userCity,
    String? userCountry,
    String? serverCity,
    String? serverCountry,
    String? error,
    double? beforeDownload,
    double? beforeUpload,
    double? beforePing,
    double? beforeJitter,
    double? afterDownload,
    double? afterUpload,
    double? afterPing,
    double? afterJitter,
  }) {
    return SpeedTestState(
      phase: phase ?? this.phase,
      mode: mode ?? this.mode,
      currentSpeed: currentSpeed ?? this.currentSpeed,
      progress: progress ?? this.progress,
      userCity: userCity ?? this.userCity,
      userCountry: userCountry ?? this.userCountry,
      serverCity: serverCity ?? this.serverCity,
      serverCountry: serverCountry ?? this.serverCountry,
      error: error,
      beforeDownload: beforeDownload ?? this.beforeDownload,
      beforeUpload: beforeUpload ?? this.beforeUpload,
      beforePing: beforePing ?? this.beforePing,
      beforeJitter: beforeJitter ?? this.beforeJitter,
      afterDownload: afterDownload ?? this.afterDownload,
      afterUpload: afterUpload ?? this.afterUpload,
      afterPing: afterPing ?? this.afterPing,
      afterJitter: afterJitter ?? this.afterJitter,
    );
  }
}

class SpeedTestNotifier extends StateNotifier<SpeedTestState> {
  SpeedTestNotifier() : super(const SpeedTestState());

  SpeedTestService? _service;

  void setMode(SpeedTestMode mode) {
    if (state.phase == SpeedTestPhase.idle || state.phase == SpeedTestPhase.complete) {
      state = state.copyWith(mode: mode);
    }
  }

  Future<void> startTest(SpeedTestMode mode) async {
    if (state.phase != SpeedTestPhase.idle && state.phase != SpeedTestPhase.complete) {
      return;
    }

    final useDirectConnection = mode == SpeedTestMode.beforeVpn;
    _service = SpeedTestService(useDirectConnection: useDirectConnection);
    state = state.copyWith(
      phase: SpeedTestPhase.selectingServer,
      mode: mode,
      currentSpeed: 0,
      progress: 0,
      error: null,
    );

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

      if (mode == SpeedTestMode.beforeVpn) {
        state = state.copyWith(
          beforePing: pingResult.ping,
          beforeJitter: pingResult.jitter,
          progress: 1.0,
        );
      } else {
        state = state.copyWith(
          afterPing: pingResult.ping,
          afterJitter: pingResult.jitter,
          progress: 1.0,
        );
      }

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

      if (mode == SpeedTestMode.beforeVpn) {
        state = state.copyWith(beforeDownload: downloadSpeed, progress: 1.0);
      } else {
        state = state.copyWith(afterDownload: downloadSpeed, progress: 1.0);
      }

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

      if (mode == SpeedTestMode.beforeVpn) {
        state = state.copyWith(
          beforeUpload: uploadSpeed,
          progress: 1.0,
          phase: SpeedTestPhase.complete,
          currentSpeed: 0,
        );
      } else {
        state = state.copyWith(
          afterUpload: uploadSpeed,
          progress: 1.0,
          phase: SpeedTestPhase.complete,
          currentSpeed: 0,
        );
      }
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
