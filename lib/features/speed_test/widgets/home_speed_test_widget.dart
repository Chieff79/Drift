import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/widgets/speed_gauge.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class HomeSpeedTestWidget extends HookConsumerWidget {
  const HomeSpeedTestWidget({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final state = ref.watch(speedTestNotifierProvider);
    final isRunning = state.phase != SpeedTestPhase.idle &&
        state.phase != SpeedTestPhase.complete;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Idle state: show Run button
          if (state.phase == SpeedTestPhase.idle && !_hasResults(state))
            _buildStartButton(context, ref, theme),

          // Running state: show gauge + phase label + cancel
          if (isRunning) ...[
            _buildPhaseLabel(state, theme),
            const Gap(8),
            SizedBox(
              width: 180,
              height: 180,
              child: SpeedGauge(
                speed: state.currentSpeed,
                isActive: true,
                size: 180,
              ),
            ),
            const Gap(8),
            _buildCancelButton(ref, theme),
          ],

          // Complete state: show results
          if (state.phase == SpeedTestPhase.complete && _hasResults(state)) ...[
            _buildResults(state, theme),
            const Gap(8),
            _buildServerRoute(state, theme),
            const Gap(8),
            _buildTestAgainButton(ref, theme),
          ],

          // Error
          if (state.error != null) ...[
            const Gap(8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: theme.colorScheme.errorContainer,
                borderRadius: BorderRadius.circular(10),
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
            ),
          ],
        ],
      ),
    );
  }

  bool _hasResults(SpeedTestState state) {
    return (state.downloadSpeed ?? 0) > 0 || (state.uploadSpeed ?? 0) > 0;
  }

  Widget _buildStartButton(BuildContext context, WidgetRef ref, ThemeData theme) {
    return FilledButton.icon(
      onPressed: () => ref.read(speedTestNotifierProvider.notifier).startTest(),
      icon: const Icon(Icons.speed_rounded, size: 20),
      label: const Text('Run Speed Test'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
    );
  }

  Widget _buildPhaseLabel(SpeedTestState state, ThemeData theme) {
    String label;
    switch (state.phase) {
      case SpeedTestPhase.selectingServer:
        label = 'Selecting server...';
      case SpeedTestPhase.ping:
        label = 'Measuring ping...';
      case SpeedTestPhase.download:
        label = 'Testing download...';
      case SpeedTestPhase.upload:
        label = 'Testing upload...';
      default:
        label = '';
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 14,
          height: 14,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: theme.colorScheme.primary,
          ),
        ),
        const Gap(8),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }

  Widget _buildCancelButton(WidgetRef ref, ThemeData theme) {
    return TextButton.icon(
      onPressed: () => ref.read(speedTestNotifierProvider.notifier).cancelTest(),
      icon: Icon(Icons.stop_rounded, size: 16, color: theme.colorScheme.error),
      label: Text('Cancel', style: TextStyle(color: theme.colorScheme.error, fontSize: 12)),
    );
  }

  Widget _buildResults(SpeedTestState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ResultItem(
              icon: Icons.download_rounded,
              label: 'Download',
              value: (state.downloadSpeed ?? 0) > 0
                  ? (state.downloadSpeed!).toStringAsFixed(1)
                  : '--',
              unit: 'Mbps',
              color: const Color(0xFF4FC3F7),
            ),
          ),
          Expanded(
            child: _ResultItem(
              icon: Icons.upload_rounded,
              label: 'Upload',
              value: (state.uploadSpeed ?? 0) > 0
                  ? (state.uploadSpeed!).toStringAsFixed(1)
                  : '--',
              unit: 'Mbps',
              color: const Color(0xFFAB47BC),
            ),
          ),
          Expanded(
            child: _ResultItem(
              icon: Icons.network_ping_rounded,
              label: 'Ping',
              value: (state.ping ?? 0) > 0
                  ? (state.ping!).toStringAsFixed(0)
                  : '--',
              unit: 'ms',
              color: const Color(0xFF66BB6A),
            ),
          ),
          Expanded(
            child: _ResultItem(
              icon: Icons.swap_vert_rounded,
              label: 'Jitter',
              value: (state.jitter ?? 0) > 0
                  ? (state.jitter!).toStringAsFixed(1)
                  : '--',
              unit: 'ms',
              color: const Color(0xFFFFB74D),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerRoute(SpeedTestState state, ThemeData theme) {
    final from = state.userCity ?? 'You';
    final to = state.serverCity ?? 'Server';
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.my_location_rounded, size: 14, color: theme.colorScheme.primary),
        const Gap(4),
        Text(
          from,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
        const Gap(6),
        Icon(Icons.arrow_forward_rounded, size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        const Gap(6),
        Icon(Icons.dns_rounded, size: 14, color: theme.colorScheme.secondary),
        const Gap(4),
        Text(
          to,
          style: theme.textTheme.bodySmall?.copyWith(
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTestAgainButton(WidgetRef ref, ThemeData theme) {
    return TextButton.icon(
      onPressed: () => ref.read(speedTestNotifierProvider.notifier).startTest(),
      icon: const Icon(Icons.refresh_rounded, size: 16),
      label: const Text('Test Again', style: TextStyle(fontSize: 12)),
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: color, size: 18),
        const Gap(4),
        Text(
          value,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.bold,
          ),
        ),
        Text(
          unit,
          style: TextStyle(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          label,
          style: TextStyle(
            fontSize: 9,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
      ],
    );
  }
}
