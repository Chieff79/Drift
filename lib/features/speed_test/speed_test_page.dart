import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Country capital approximate coordinates (lat, lng).
const _countryCoords = <String, (double lat, double lng)>{
  'RU': (55.75, 37.62),
  'NL': (52.37, 4.90),
  'US': (38.90, -77.04),
  'DE': (52.52, 13.41),
  'FR': (48.86, 2.35),
  'GB': (51.51, -0.13),
  'UA': (50.45, 30.52),
  'KZ': (51.17, 71.43),
  'BY': (53.90, 27.57),
  'TR': (39.93, 32.86),
  'CN': (39.90, 116.40),
  'JP': (35.68, 139.69),
  'SG': (1.35, 103.82),
  'FI': (60.17, 24.94),
  'SE': (59.33, 18.07),
  'CH': (46.95, 7.45),
  'CA': (45.42, -75.70),
  'AU': (-33.87, 151.21),
  'BR': (-15.79, -47.88),
  'IN': (28.61, 77.21),
  'IT': (41.90, 12.50),
  'ES': (40.42, -3.70),
  'PL': (52.23, 21.01),
  'CZ': (50.08, 14.44),
  'AT': (48.21, 16.37),
  'NO': (59.91, 10.75),
  'DK': (55.68, 12.57),
  'PT': (38.72, -9.14),
  'IE': (53.35, -6.26),
  'HK': (22.32, 114.17),
  'KR': (37.57, 126.98),
  'TW': (25.03, 121.57),
  'AR': (-34.60, -58.38),
  'MX': (19.43, -99.13),
  'ZA': (-33.93, 18.42),
  'EG': (30.04, 31.24),
  'AE': (25.20, 55.27),
  'IL': (31.77, 35.22),
  'TH': (13.76, 100.50),
  'VN': (21.03, 105.85),
  'ID': (-6.21, 106.85),
  'MY': (3.14, 101.69),
  'PH': (14.60, 120.98),
  'RO': (44.43, 26.10),
  'BG': (42.70, 23.32),
  'HU': (47.50, 19.04),
  'GR': (37.98, 23.73),
  'HR': (45.81, 15.98),
  'RS': (44.79, 20.47),
  'LT': (54.69, 25.28),
  'LV': (56.95, 24.11),
  'EE': (59.44, 24.75),
  'GE': (41.69, 44.80),
  'AM': (40.18, 44.51),
  'AZ': (40.41, 49.87),
  'UZ': (41.30, 69.28),
  'MD': (47.01, 28.86),
  'IS': (64.15, -21.94),
  'NZ': (-41.29, 174.78),
  'CL': (-33.45, -70.67),
  'CO': (4.71, -74.07),
  'PE': (-12.05, -77.04),
};

Offset _latLngToRelative(double lat, double lng) {
  final x = (lng + 180) / 360;
  final y = (90 - lat) / 180;
  return Offset(x.clamp(0.0, 1.0), y.clamp(0.0, 1.0));
}

Offset? _getPosition(String? countryCode) {
  if (countryCode == null || countryCode.isEmpty) return null;
  final coords = _countryCoords[countryCode.toUpperCase()];
  if (coords == null) return null;
  return _latLngToRelative(coords.$1, coords.$2);
}

class SpeedTestPage extends HookConsumerWidget {
  const SpeedTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;
    final state = ref.watch(speedTestNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isVpnActive = connectionStatus.valueOrNull?.isConnected ?? false;
    final isRunning = state.phase != SpeedTestPhase.idle &&
        state.phase != SpeedTestPhase.complete;
    final hasResults = state.phase == SpeedTestPhase.complete;

    // Map pan offset
    final panOffset = useState(Offset.zero);

    // Particle animation
    final particleCtrl = useAnimationController(
      duration: const Duration(milliseconds: 2400),
    );
    // Pulse animation for dots
    final pulseCtrl = useAnimationController(
      duration: const Duration(milliseconds: 1800),
    );
    // Arc draw animation
    final arcCtrl = useAnimationController(
      duration: const Duration(milliseconds: 1200),
    );
    // Speed wave animation (during test)
    final waveCtrl = useAnimationController(
      duration: const Duration(milliseconds: 3000),
    );

    useEffect(() {
      if (isRunning) {
        particleCtrl.repeat();
        pulseCtrl.repeat(reverse: true);
        arcCtrl.forward(from: 0);
        waveCtrl.repeat();
      } else if (hasResults) {
        particleCtrl.repeat();
        pulseCtrl.repeat(reverse: true);
        arcCtrl.value = 1.0;
        waveCtrl.stop();
      } else {
        particleCtrl.stop();
        particleCtrl.value = 0;
        pulseCtrl.stop();
        pulseCtrl.value = 0;
        arcCtrl.value = 0;
        waveCtrl.stop();
        waveCtrl.value = 0;
      }
      return null;
    }, [isRunning, hasResults]);

    final userPos = _getPosition(state.userCountryCode);
    final serverPos = _getPosition(state.serverCountryCode);

    final mapOpacity = (isRunning || hasResults) ? 0.22 : 0.10;

    return Scaffold(
      body: GestureDetector(
        onPanUpdate: (details) {
          panOffset.value += details.delta;
        },
        onDoubleTap: () {
          panOffset.value = Offset.zero;
        },
        child: Stack(
          children: [
            // ── Full-screen map background ──────────────────────────
            Positioned.fill(
              child: Transform.translate(
                offset: panOffset.value,
                child: ListenableBuilder(
                  listenable: Listenable.merge([particleCtrl, pulseCtrl, arcCtrl, waveCtrl]),
                  builder: (context, _) {
                    return Stack(
                      fit: StackFit.expand,
                      children: [
                        // Map image
                        Image.asset(
                          'assets/images/world_map.png',
                          fit: BoxFit.cover,
                          color: isDark
                              ? Colors.white.withValues(alpha: mapOpacity)
                              : Colors.grey.withValues(alpha: (isRunning || hasResults) ? 0.35 : 0.18),
                          colorBlendMode: isDark ? BlendMode.srcIn : BlendMode.srcATop,
                        ),
                        // Custom paint: dots, arc, particles
                        CustomPaint(
                          painter: _SpeedTestMapPainter(
                            userPos: userPos,
                            serverPos: serverPos,
                            isActive: isRunning || hasResults,
                            isRunning: isRunning,
                            pulseValue: pulseCtrl.value,
                            arcProgress: arcCtrl.value,
                            particleProgress: particleCtrl.value,
                            waveProgress: waveCtrl.value,
                            currentPhase: state.phase,
                            isDark: isDark,
                          ),
                        ),
                      ],
                    );
                  },
                ),
              ),
            ),

            // ── VPN badge (top-left) ────────────────────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              left: 16,
              child: _VpnBadge(isActive: isVpnActive),
            ),

            // ── Ping & Jitter (top-right, small) ───────────────────
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: _PingJitterDisplay(
                ping: state.ping,
                jitter: state.jitter,
                isRunning: state.phase == SpeedTestPhase.ping,
              ),
            ),

            // ── Phase indicator (center) ────────────────────────────
            if (isRunning)
              Positioned(
                top: MediaQuery.of(context).padding.top + 60,
                left: 0,
                right: 0,
                child: Center(
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                    decoration: BoxDecoration(
                      color: _phaseColor(state.phase).withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(
                        color: _phaseColor(state.phase).withValues(alpha: 0.3),
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: _phaseColor(state.phase),
                          ),
                        ),
                        const Gap(8),
                        Text(
                          state.statusMessage ?? _phaseLabel(state.phase),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w500,
                            color: _phaseColor(state.phase),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),

            // ── Route labels on map (when locations known) ──────────
            if ((isRunning || hasResults) && state.userCity != null)
              Positioned(
                top: MediaQuery.of(context).padding.top + (isRunning ? 95 : 60),
                left: 0,
                right: 0,
                child: Center(
                  child: _RouteLabel(
                    from: state.userCity ?? '',
                    fromCountry: state.userCountryCode ?? '',
                    to: state.serverCity ?? state.serverName ?? '',
                    toCountry: state.serverCountryCode ?? '',
                  ),
                ),
              ),

            // ── Bottom panel: speed results + button ────────────────
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: EdgeInsets.only(
                  left: 24,
                  right: 24,
                  top: 24,
                  bottom: MediaQuery.of(context).padding.bottom + 24,
                ),
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.0),
                      theme.scaffoldBackgroundColor.withValues(alpha: 0.7),
                      theme.scaffoldBackgroundColor,
                    ],
                    stops: const [0.0, 0.3, 0.6],
                  ),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // Speed results row
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Download
                        _SpeedDisplay(
                          icon: Icons.arrow_downward_rounded,
                          label: 'Загрузка',
                          value: state.phase == SpeedTestPhase.download
                              ? formatSpeedLive(state.currentSpeed)
                              : formatSpeed(state.downloadSpeed ?? 0),
                          unit: 'Мбит/с',
                          color: const Color(0xFF4FC3F7),
                          isActive: state.phase == SpeedTestPhase.download,
                        ),
                        const Gap(32),
                        // Upload
                        _SpeedDisplay(
                          icon: Icons.arrow_upward_rounded,
                          label: 'Отдача',
                          value: state.phase == SpeedTestPhase.upload
                              ? formatSpeedLive(state.currentSpeed)
                              : formatSpeed(state.uploadSpeed ?? 0),
                          unit: 'Мбит/с',
                          color: const Color(0xFFAB47BC),
                          isActive: state.phase == SpeedTestPhase.upload,
                        ),
                      ],
                    ),
                    const Gap(20),

                    // Action button
                    SizedBox(
                      width: double.infinity,
                      child: isRunning
                          ? FilledButton.icon(
                              onPressed: () =>
                                  ref.read(speedTestNotifierProvider.notifier).cancelTest(),
                              icon: const Icon(Icons.stop_rounded, size: 22),
                              label: const Text('Остановить'),
                              style: FilledButton.styleFrom(
                                backgroundColor: theme.colorScheme.error,
                                foregroundColor: theme.colorScheme.onError,
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28)),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            )
                          : FilledButton.icon(
                              onPressed: () {
                                ref.read(speedTestNotifierProvider.notifier).startTest();
                              },
                              icon: Icon(
                                hasResults
                                    ? Icons.refresh_rounded
                                    : Icons.speed_rounded,
                                size: 22,
                              ),
                              label: Text(hasResults
                                  ? 'Проверить снова'
                                  : 'Проверить скорость'),
                              style: FilledButton.styleFrom(
                                padding: const EdgeInsets.symmetric(
                                    horizontal: 32, vertical: 16),
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(28)),
                                textStyle: const TextStyle(
                                    fontSize: 16, fontWeight: FontWeight.w600),
                              ),
                            ),
                    ),

                    // Error
                    if (state.error != null) ...[
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline, color: theme.colorScheme.error, size: 16),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                  color: theme.colorScheme.onErrorContainer,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _phaseLabel(SpeedTestPhase phase) {
    return switch (phase) {
      SpeedTestPhase.selectingServer => 'Поиск сервера...',
      SpeedTestPhase.ping => 'Измерение пинга',
      SpeedTestPhase.download => 'Загрузка',
      SpeedTestPhase.upload => 'Отдача',
      _ => '',
    };
  }

  Color _phaseColor(SpeedTestPhase phase) {
    return switch (phase) {
      SpeedTestPhase.ping => const Color(0xFF66BB6A),
      SpeedTestPhase.download => const Color(0xFF4FC3F7),
      SpeedTestPhase.upload => const Color(0xFFAB47BC),
      _ => Colors.white70,
    };
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  VPN Badge — small indicator top-left
// ═══════════════════════════════════════════════════════════════════════════════

class _VpnBadge extends StatelessWidget {
  const _VpnBadge({required this.isActive});
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final color = isActive ? const Color(0xFF30D158) : Colors.grey;
    final label = isActive ? 'VPN' : 'Без VPN';

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 7,
            height: 7,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color,
              boxShadow: [
                BoxShadow(color: color.withValues(alpha: 0.5), blurRadius: 4),
              ],
            ),
          ),
          const Gap(6),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Ping & Jitter — small numbers top-right
// ═══════════════════════════════════════════════════════════════════════════════

class _PingJitterDisplay extends StatelessWidget {
  const _PingJitterDisplay({
    required this.ping,
    required this.jitter,
    required this.isRunning,
  });

  final double? ping;
  final double? jitter;
  final bool isRunning;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final hasData = (ping ?? 0) > 0 || isRunning;
    if (!hasData) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        _MiniMetric(
          label: 'Ping',
          value: (ping ?? 0) > 0 ? '${ping!.toStringAsFixed(0)} мс' : '...',
          color: const Color(0xFF66BB6A),
        ),
        const Gap(4),
        _MiniMetric(
          label: 'Jitter',
          value: (jitter ?? 0) > 0 ? '${jitter!.toStringAsFixed(1)} мс' : '...',
          color: const Color(0xFFFFB74D),
        ),
      ],
    );
  }
}

class _MiniMetric extends StatelessWidget {
  const _MiniMetric({
    required this.label,
    required this.value,
    required this.color,
  });

  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const Gap(6),
        Text(
          value,
          style: TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
            color: color.withValues(alpha: 0.85),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Route Label — "City A → City B"
// ═══════════════════════════════════════════════════════════════════════════════

class _RouteLabel extends StatelessWidget {
  const _RouteLabel({
    required this.from,
    required this.fromCountry,
    required this.to,
    required this.toCountry,
  });

  final String from;
  final String fromCountry;
  final String to;
  final String toCountry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: theme.colorScheme.outline.withValues(alpha: 0.15),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.my_location_rounded, size: 12,
              color: const Color(0xFF1A4A9B)),
          const Gap(4),
          Text(
            from.isNotEmpty ? from : fromCountry,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Icon(Icons.arrow_forward_rounded, size: 14,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
          ),
          Icon(Icons.dns_rounded, size: 12,
              color: const Color(0xFF30D158)),
          const Gap(4),
          Text(
            to.isNotEmpty ? to : toCountry,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Speed Display — large numbers at bottom
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeedDisplay extends StatelessWidget {
  const _SpeedDisplay({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.isActive = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isActive;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: isActive ? color : color.withValues(alpha: 0.6), size: 16),
            const Gap(4),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
        const Gap(4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            value,
            key: ValueKey(value),
            style: TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.w700,
              color: isActive ? color : theme.colorScheme.onSurface,
              height: 1.1,
            ),
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 11,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
      ],
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Map Painter — dots, arc, speed wave particles
// ═══════════════════════════════════════════════════════════════════════════════

class _SpeedTestMapPainter extends CustomPainter {
  _SpeedTestMapPainter({
    required this.userPos,
    required this.serverPos,
    required this.isActive,
    required this.isRunning,
    required this.pulseValue,
    required this.arcProgress,
    required this.particleProgress,
    required this.waveProgress,
    required this.currentPhase,
    required this.isDark,
  });

  final Offset? userPos;
  final Offset? serverPos;
  final bool isActive;
  final bool isRunning;
  final double pulseValue;
  final double arcProgress;
  final double particleProgress;
  final double waveProgress;
  final SpeedTestPhase currentPhase;
  final bool isDark;

  static const _userColor = Color(0xFF1A4A9B);
  static const _serverColor = Color(0xFF30D158);
  static const _downloadColor = Color(0xFF4FC3F7);
  static const _uploadColor = Color(0xFFAB47BC);
  static const _pingColor = Color(0xFF66BB6A);

  @override
  void paint(Canvas canvas, Size size) {
    final userPixel = userPos != null
        ? Offset(userPos!.dx * size.width, userPos!.dy * size.height)
        : null;
    final serverPixel = serverPos != null
        ? Offset(serverPos!.dx * size.width, serverPos!.dy * size.height)
        : null;

    // Draw arc
    if (isActive && userPixel != null && serverPixel != null && arcProgress > 0) {
      _drawArc(canvas, size, userPixel, serverPixel);
    }

    // Draw user dot
    if (userPixel != null) {
      _drawDot(canvas, userPixel, _userColor, false);
    }

    // Draw server dot
    if (serverPixel != null && isActive) {
      _drawDot(canvas, serverPixel, _serverColor, true);
    }
  }

  void _drawDot(Canvas canvas, Offset center, Color color, bool pulsing) {
    if (pulsing) {
      final pulseRadius = 10 + pulseValue * 14;
      final pulseAlpha = (0.25 * (1.0 - pulseValue * 0.7)).clamp(0.0, 1.0);
      canvas.drawCircle(
        center,
        pulseRadius,
        Paint()
          ..color = color.withValues(alpha: pulseAlpha)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.5,
      );
      // Second ring
      final p2 = ((pulseValue + 0.5) % 1.0);
      canvas.drawCircle(
        center,
        10 + p2 * 18,
        Paint()
          ..color = color.withValues(alpha: (0.15 * (1.0 - p2 * 0.8)).clamp(0.0, 1.0))
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.0,
      );
    }

    // Glow
    canvas.drawCircle(
      center,
      12,
      Paint()
        ..color = color.withValues(alpha: 0.15)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    // Ring
    canvas.drawCircle(
      center,
      8,
      Paint()
        ..color = color.withValues(alpha: 0.25)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.5,
    );
    // Dot
    canvas.drawCircle(center, 4.5, Paint()..color = color);
    // White center
    canvas.drawCircle(
      center,
      1.8,
      Paint()..color = Colors.white.withValues(alpha: 0.9),
    );
  }

  void _drawArc(Canvas canvas, Size size, Offset from, Offset to) {
    final mid = Offset((from.dx + to.dx) / 2, (from.dy + to.dy) / 2);
    final distance = (to - from).distance;
    final controlPoint = Offset(mid.dx, mid.dy - distance * 0.35);

    final path = Path()
      ..moveTo(from.dx, from.dy)
      ..quadraticBezierTo(controlPoint.dx, controlPoint.dy, to.dx, to.dy);

    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final metric = metrics.first;
    final length = metric.length;

    // Draw arc
    final subPath = metric.extractPath(0, length * arcProgress);

    // Phase color for arc
    Color arcEndColor;
    if (isRunning) {
      arcEndColor = switch (currentPhase) {
        SpeedTestPhase.download => _downloadColor,
        SpeedTestPhase.upload => _uploadColor,
        SpeedTestPhase.ping => _pingColor,
        _ => _serverColor,
      };
    } else {
      arcEndColor = _serverColor;
    }

    canvas.drawPath(
      subPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.0
        ..strokeCap = StrokeCap.round
        ..shader = ui.Gradient.linear(
          from,
          to,
          [_userColor.withValues(alpha: 0.6), arcEndColor.withValues(alpha: 0.6)],
        ),
    );

    // Glow
    canvas.drawPath(
      subPath,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 6.0
        ..strokeCap = StrokeCap.round
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4)
        ..shader = ui.Gradient.linear(
          from,
          to,
          [_userColor.withValues(alpha: 0.08), arcEndColor.withValues(alpha: 0.08)],
        ),
    );

    // Particles
    if (arcProgress >= 1.0) {
      final particleColor = isRunning
          ? switch (currentPhase) {
              SpeedTestPhase.download => _downloadColor,
              SpeedTestPhase.upload => _uploadColor,
              _ => _serverColor,
            }
          : _serverColor;

      // Direction: download → server to user, upload → user to server
      final reverse = currentPhase == SpeedTestPhase.download;

      final count = isRunning ? 5 : 3;
      for (int i = 0; i < count; i++) {
        var offset = (particleProgress + i / count) % 1.0;
        if (reverse) offset = 1.0 - offset;
        final tangent = metric.getTangentForOffset(offset * length);
        if (tangent == null) continue;

        canvas.drawCircle(
          tangent.position,
          4,
          Paint()
            ..color = particleColor.withValues(alpha: 0.3)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
        );
        canvas.drawCircle(
          tangent.position,
          2,
          Paint()..color = Colors.white.withValues(alpha: 0.9),
        );
      }
    }
  }

  @override
  bool shouldRepaint(covariant _SpeedTestMapPainter old) {
    return old.pulseValue != pulseValue ||
        old.arcProgress != arcProgress ||
        old.particleProgress != particleProgress ||
        old.waveProgress != waveProgress ||
        old.isActive != isActive ||
        old.isRunning != isRunning ||
        old.currentPhase != currentPhase ||
        old.userPos != userPos ||
        old.serverPos != serverPos;
  }
}
