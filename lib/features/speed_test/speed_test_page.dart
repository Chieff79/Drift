import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/widget/globe_widget.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedTestPage extends HookConsumerWidget {
  const SpeedTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(speedTestNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isVpnActive = connectionStatus.valueOrNull?.isConnected ?? false;
    final vpnIpInfo = ref.watch(ipInfoNotifierProvider);
    final vpnCountryCode = vpnIpInfo.valueOrNull?.countryCode;
    final isRunning = state.phase != SpeedTestPhase.idle &&
        state.phase != SpeedTestPhase.complete;
    final hasResults = state.phase == SpeedTestPhase.complete;

    return Scaffold(
      body: Stack(
        children: [
          // ── 3D Globe background ────────────────────────────────
          Positioned.fill(
            child: GlobeWidget(
              isConnected: isRunning || hasResults,
              isConnecting: state.phase == SpeedTestPhase.selectingServer,
              userCountryCode: state.userCountryCode,
              vpnCountryCode: vpnCountryCode,
              thirdCountryCode: state.serverCountryCode,
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

          // ── Server label (center, highly visible) ──────────────
          if ((isRunning || hasResults) && (state.serverCity != null || state.serverName != null))
            Positioned(
              top: MediaQuery.of(context).padding.top + 50,
              left: 0,
              right: 0,
              child: Center(
                child: _ServerLabel(
                  serverCity: state.serverCity,
                  serverName: state.serverName,
                  serverCountryCode: state.serverCountryCode,
                  phase: state.phase,
                ),
              ),
            ),

          // ── Phase indicator ────────────────────────────────────
          if (isRunning)
            Positioned(
              top: MediaQuery.of(context).padding.top + 95,
              left: 0,
              right: 0,
              child: Center(
                child: _PhaseIndicator(phase: state.phase, message: state.statusMessage),
              ),
            ),

          // ── Bottom panel: speed results + button ────────────────
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _BottomPanel(
              state: state,
              isRunning: isRunning,
              hasResults: hasResults,
              onStart: () => ref.read(speedTestNotifierProvider.notifier).startTest(vpnCountryCode: vpnCountryCode, isVpnActive: isVpnActive),
              onCancel: () => ref.read(speedTestNotifierProvider.notifier).cancelTest(),
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  VPN Badge
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
//  Ping & Jitter
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
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.4),
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
//  Server Label — clearly visible, with background
// ═══════════════════════════════════════════════════════════════════════════════

class _ServerLabel extends StatelessWidget {
  const _ServerLabel({
    required this.serverCity,
    required this.serverName,
    required this.serverCountryCode,
    required this.phase,
  });

  final String? serverCity;
  final String? serverName;
  final String? serverCountryCode;
  final SpeedTestPhase phase;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayName = serverCity ?? serverName ?? '';
    if (displayName.isEmpty) return const SizedBox.shrink();

    final phaseColor = switch (phase) {
      SpeedTestPhase.download => const Color(0xFF4FC3F7),
      SpeedTestPhase.upload => const Color(0xFFAB47BC),
      SpeedTestPhase.ping => const Color(0xFF66BB6A),
      SpeedTestPhase.complete => const Color(0xFF30D158),
      _ => const Color(0xFF30D158),
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: theme.scaffoldBackgroundColor.withValues(alpha: 0.85),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: phaseColor.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.dns_rounded, size: 14, color: phaseColor),
          const Gap(8),
          Text(
            'Сервер: $displayName',
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: phaseColor,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Phase Indicator
// ═══════════════════════════════════════════════════════════════════════════════

class _PhaseIndicator extends StatelessWidget {
  const _PhaseIndicator({required this.phase, required this.message});

  final SpeedTestPhase phase;
  final String? message;

  @override
  Widget build(BuildContext context) {
    final color = switch (phase) {
      SpeedTestPhase.ping => const Color(0xFF66BB6A),
      SpeedTestPhase.download => const Color(0xFF4FC3F7),
      SpeedTestPhase.upload => const Color(0xFFAB47BC),
      _ => Colors.white70,
    };

    final label = message ?? switch (phase) {
      SpeedTestPhase.selectingServer => 'Поиск сервера...',
      SpeedTestPhase.ping => 'Измерение пинга',
      SpeedTestPhase.download => 'Загрузка',
      SpeedTestPhase.upload => 'Отдача',
      _ => '',
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 12,
            height: 12,
            child: CircularProgressIndicator(
              strokeWidth: 1.5,
              color: color,
            ),
          ),
          const Gap(8),
          Text(
            label,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Bottom Panel — speed results + action button
// ═══════════════════════════════════════════════════════════════════════════════

class _BottomPanel extends StatelessWidget {
  const _BottomPanel({
    required this.state,
    required this.isRunning,
    required this.hasResults,
    required this.onStart,
    required this.onCancel,
  });

  final SpeedTestState state;
  final bool isRunning;
  final bool hasResults;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: _SpeedDisplay(
                  icon: Icons.arrow_downward_rounded,
                  label: 'Загрузка',
                  value: state.phase == SpeedTestPhase.download
                      ? formatSpeedLive(state.currentSpeed)
                      : formatSpeed(state.downloadSpeed ?? 0),
                  unit: 'Мбит/с',
                  color: const Color(0xFF4FC3F7),
                  isActive: state.phase == SpeedTestPhase.download,
                ),
              ),
              Expanded(
                child: _SpeedDisplay(
                  icon: Icons.arrow_upward_rounded,
                  label: 'Отдача',
                  value: state.phase == SpeedTestPhase.upload
                      ? formatSpeedLive(state.currentSpeed)
                      : formatSpeed(state.uploadSpeed ?? 0),
                  unit: 'Мбит/с',
                  color: const Color(0xFFAB47BC),
                  isActive: state.phase == SpeedTestPhase.upload,
                ),
              ),
            ],
          ),
          const Gap(20),

          // Action button
          SizedBox(
            width: double.infinity,
            child: isRunning
                ? FilledButton.icon(
                    onPressed: onCancel,
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
                    onPressed: onStart,
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
    );
  }
}

// ═══════════════════════════════════════════════════════════════════════════════
//  Speed Display — large numbers
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
