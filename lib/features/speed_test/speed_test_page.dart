import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hiddify/features/speed_test/widgets/speed_gauge.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class SpeedTestPage extends HookConsumerWidget {
  const SpeedTestPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(speedTestNotifierProvider);
    final isRunning = state.phase != SpeedTestPhase.idle &&
        state.phase != SpeedTestPhase.complete;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 500),
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              child: Column(
                children: [
                  // Luxury Speedometer
                  SpeedGauge(
                    speed: state.currentSpeed,
                    maxSpeed: 1000,
                    isActive: isRunning,
                    size: 280,
                    phaseLabel: _phaseLabel(state.phase),
                  ),
                  const Gap(8),

                  // Current speed: 40sp bold white
                  Text(
                    state.currentSpeed > 0
                        ? state.currentSpeed.toStringAsFixed(2)
                        : '0.00',
                    style: TextStyle(
                      fontSize: 40,
                      fontWeight: FontWeight.w700,
                      color: theme.colorScheme.onSurface,
                      height: 1,
                    ),
                  ),
                  const Gap(2),
                  // Unit: 16sp gray
                  Text(
                    '\u041c\u0431\u0438\u0442/\u0441', // Мбит/с
                    style: TextStyle(
                      fontSize: 16,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                  ),
                  // Phase indicator with color
                  if (_phaseLabel(state.phase) != null) ...[
                    const Gap(4),
                    Text(
                      _phaseLabelWithArrow(state.phase),
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: _phaseColor(state.phase),
                      ),
                    ),
                  ],
                  const Gap(24),

                  // Results grid 2x2
                  _buildResultsGrid(state, theme),
                  const Gap(16),

                  // Server route
                  _buildServerRoute(state, theme),
                  const Gap(24),

                  // Action button
                  _buildActionButton(context, ref, state, theme, isRunning),

                  // Error display
                  if (state.error != null) ...[
                    const Gap(12),
                    _buildError(state, theme),
                  ],

                  const Gap(24),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  String? _phaseLabel(SpeedTestPhase phase) {
    switch (phase) {
      case SpeedTestPhase.selectingServer:
        return '\u0412\u044b\u0431\u043e\u0440 \u0441\u0435\u0440\u0432\u0435\u0440\u0430...';
      case SpeedTestPhase.ping:
        return '\u041f\u0438\u043d\u0433';
      case SpeedTestPhase.download:
        return '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430';
      case SpeedTestPhase.upload:
        return '\u041e\u0442\u0434\u0430\u0447\u0430';
      default:
        return null;
    }
  }

  String _phaseLabelWithArrow(SpeedTestPhase phase) {
    switch (phase) {
      case SpeedTestPhase.selectingServer:
        return '\u23f3 \u0412\u044b\u0431\u043e\u0440 \u0441\u0435\u0440\u0432\u0435\u0440\u0430...';
      case SpeedTestPhase.ping:
        return '\u25c9 \u041f\u0438\u043d\u0433';
      case SpeedTestPhase.download:
        return '\u25bc \u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430';
      case SpeedTestPhase.upload:
        return '\u25b2 \u041e\u0442\u0434\u0430\u0447\u0430';
      default:
        return '';
    }
  }

  Color _phaseColor(SpeedTestPhase phase) {
    switch (phase) {
      case SpeedTestPhase.ping:
        return const Color(0xFF66BB6A); // green
      case SpeedTestPhase.download:
        return const Color(0xFF4FC3F7); // blue
      case SpeedTestPhase.upload:
        return const Color(0xFFAB47BC); // purple
      default:
        return Colors.white70;
    }
  }

  Widget _buildResultsGrid(SpeedTestState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          // Row 1: Download & Upload (large 24sp)
          Row(
            children: [
              Expanded(
                child: _ResultTile(
                  icon: Icons.download_rounded,
                  label: '\u0417\u0430\u0433\u0440\u0443\u0437\u043a\u0430',
                  value: _formatFinalSpeed(state.downloadSpeed),
                  liveValue: state.phase == SpeedTestPhase.download
                      ? formatSpeedLive(state.currentSpeed)
                      : null,
                  unit: '\u041c\u0431\u0438\u0442/\u0441',
                  color: const Color(0xFF4FC3F7),
                  isActive: state.phase == SpeedTestPhase.download,
                  isLarge: true,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _ResultTile(
                  icon: Icons.upload_rounded,
                  label: '\u041e\u0442\u0434\u0430\u0447\u0430',
                  value: _formatFinalSpeed(state.uploadSpeed),
                  liveValue: state.phase == SpeedTestPhase.upload
                      ? formatSpeedLive(state.currentSpeed)
                      : null,
                  unit: '\u041c\u0431\u0438\u0442/\u0441',
                  color: const Color(0xFFAB47BC),
                  isActive: state.phase == SpeedTestPhase.upload,
                  isLarge: true,
                ),
              ),
            ],
          ),
          const Gap(12),
          // Row 2: Ping & Jitter (small 14sp)
          Row(
            children: [
              Expanded(
                child: _ResultTile(
                  icon: Icons.network_ping_rounded,
                  label: '\u041f\u0438\u043d\u0433',
                  value: (state.ping ?? 0) > 0
                      ? state.ping!.toStringAsFixed(0)
                      : '--',
                  liveValue: state.phase == SpeedTestPhase.ping
                      ? state.currentSpeed.toStringAsFixed(0)
                      : null,
                  unit: '\u043c\u0441',
                  color: const Color(0xFF66BB6A),
                  isActive: state.phase == SpeedTestPhase.ping,
                  isLarge: false,
                ),
              ),
              const Gap(12),
              Expanded(
                child: _ResultTile(
                  icon: Icons.swap_vert_rounded,
                  label: '\u0414\u0436\u0438\u0442\u0442\u0435\u0440',
                  value: (state.jitter ?? 0) > 0
                      ? state.jitter!.toStringAsFixed(1)
                      : '--',
                  unit: '\u043c\u0441',
                  color: const Color(0xFFFFB74D),
                  isActive: false,
                  isLarge: false,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _formatFinalSpeed(double? speed) {
    if (speed == null || speed <= 0) return '--';
    return speed.toStringAsFixed(2);
  }

  Widget _buildServerRoute(SpeedTestState state, ThemeData theme) {
    // Show "Cloudflare CDN" as the target
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.my_location_rounded, size: 14, color: theme.colorScheme.primary),
        const Gap(4),
        Text(
          state.userCity?.isNotEmpty == true ? state.userCity! : '\u0412\u0430\u0448 IP',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(8),
        Text(
          '\u2192',
          style: TextStyle(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
          ),
        ),
        const Gap(8),
        Icon(Icons.dns_rounded, size: 14, color: theme.colorScheme.secondary),
        const Gap(4),
        Text(
          'Cloudflare CDN',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
      ],
    );
  }

  Widget _buildActionButton(
    BuildContext context,
    WidgetRef ref,
    SpeedTestState state,
    ThemeData theme,
    bool isRunning,
  ) {
    if (isRunning) {
      return SizedBox(
        width: double.infinity,
        child: FilledButton.icon(
          onPressed: () => ref.read(speedTestNotifierProvider.notifier).cancelTest(),
          icon: const Icon(Icons.stop_rounded, size: 22),
          label: const Text('\u041e\u0441\u0442\u0430\u043d\u043e\u0432\u0438\u0442\u044c'),
          style: FilledButton.styleFrom(
            backgroundColor: theme.colorScheme.error,
            foregroundColor: theme.colorScheme.onError,
            padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
            textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
          ),
        ),
      );
    }

    final isComplete = state.phase == SpeedTestPhase.complete;
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: () => ref.read(speedTestNotifierProvider.notifier).startTest(),
        icon: Icon(
          isComplete ? Icons.refresh_rounded : Icons.speed_rounded,
          size: 22,
        ),
        label: Text(isComplete
            ? '\u041f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c \u0441\u043d\u043e\u0432\u0430'
            : '\u041f\u0440\u043e\u0432\u0435\u0440\u0438\u0442\u044c \u0441\u043a\u043e\u0440\u043e\u0441\u0442\u044c'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          textStyle: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
      ),
    );
  }

  Widget _buildError(SpeedTestState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.errorContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Icon(Icons.error_outline, color: theme.colorScheme.error, size: 18),
          const Gap(8),
          Expanded(
            child: Text(
              state.error!,
              style: TextStyle(color: theme.colorScheme.onErrorContainer, fontSize: 12),
            ),
          ),
        ],
      ),
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String? liveValue;
  final String unit;
  final Color color;
  final bool isActive;
  final bool isLarge;

  const _ResultTile({
    required this.icon,
    required this.label,
    required this.value,
    this.liveValue,
    required this.unit,
    required this.color,
    this.isActive = false,
    this.isLarge = true,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = liveValue ?? value;
    final fontSize = isLarge ? 24.0 : 14.0;
    final unitSize = isLarge ? 12.0 : 11.0;

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: isActive
            ? color.withValues(alpha: 0.08)
            : Colors.transparent,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: isActive ? color : color.withValues(alpha: 0.6), size: 16),
              const Gap(4),
              Text(
                label,
                style: TextStyle(
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                ),
              ),
            ],
          ),
          const Gap(6),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 200),
            child: Text(
              displayValue,
              key: ValueKey(displayValue),
              style: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.w700,
                color: isActive ? color : theme.colorScheme.onSurface,
              ),
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: unitSize,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
            ),
          ),
        ],
      ),
    );
  }
}
