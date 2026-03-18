import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
import 'package:hiddify/features/speed_test/speed_test_service.dart';
import 'package:hiddify/features/speed_test/widgets/data_flow_animation.dart';
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
          // Data flow animation
          _buildAnimation(state, theme),
          const Gap(12),

          // Results grid (always visible, shows -- before test)
          _buildResults(state, theme),
          const Gap(8),

          // Server route
          _buildServerRoute(state, theme),
          const Gap(12),

          // Action button
          _buildActionButton(context, ref, state, theme, isRunning),

          // Error display
          if (state.error != null) ...[
            const Gap(8),
            _buildError(state, theme),
          ],
        ],
      ),
    );
  }

  Widget _buildAnimation(SpeedTestState state, ThemeData theme) {
    DataFlowDirection direction;
    switch (state.phase) {
      case SpeedTestPhase.download:
        direction = DataFlowDirection.download;
      case SpeedTestPhase.upload:
        direction = DataFlowDirection.upload;
      default:
        direction = DataFlowDirection.idle;
    }

    return DataFlowAnimation(
      direction: direction,
      speed: state.currentSpeed,
      leftLabel: state.userCity ?? '',
      rightLabel: state.serverCity ?? '',
      height: 120,
    );
  }

  Widget _buildResults(SpeedTestState state, ThemeData theme) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Expanded(
            child: _ResultItem(
              icon: Icons.download_rounded,
              label: 'Download',
              value: formatSpeed(state.downloadSpeed ?? 0),
              unit: 'Mbps',
              color: const Color(0xFF4FC3F7),
              isActive: state.phase == SpeedTestPhase.download,
              liveValue: state.phase == SpeedTestPhase.download
                  ? formatSpeed(state.currentSpeed)
                  : null,
            ),
          ),
          Expanded(
            child: _ResultItem(
              icon: Icons.upload_rounded,
              label: 'Upload',
              value: formatSpeed(state.uploadSpeed ?? 0),
              unit: 'Mbps',
              color: const Color(0xFFAB47BC),
              isActive: state.phase == SpeedTestPhase.upload,
              liveValue: state.phase == SpeedTestPhase.upload
                  ? formatSpeed(state.currentSpeed)
                  : null,
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
              isActive: state.phase == SpeedTestPhase.ping,
              liveValue: state.phase == SpeedTestPhase.ping
                  ? state.currentSpeed.toStringAsFixed(0)
                  : null,
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
              isActive: false,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildServerRoute(SpeedTestState state, ThemeData theme) {
    final from = state.userCity ?? '';
    final to = state.serverCity ?? '';

    if (from.isEmpty && to.isEmpty) return const SizedBox.shrink();

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(Icons.my_location_rounded, size: 14, color: theme.colorScheme.primary),
        const Gap(4),
        Text(
          from.isNotEmpty ? from : '...',
          style: theme.textTheme.bodySmall?.copyWith(fontWeight: FontWeight.w500),
        ),
        const Gap(6),
        Icon(Icons.arrow_forward_rounded, size: 14,
            color: theme.colorScheme.onSurface.withValues(alpha: 0.4)),
        const Gap(6),
        Icon(Icons.dns_rounded, size: 14, color: theme.colorScheme.secondary),
        const Gap(4),
        Text(
          to.isNotEmpty ? to : '...',
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
      // Show phase label + cancel button
      return Column(
        children: [
          _buildPhaseLabel(state, theme),
          const Gap(4),
          TextButton(
            onPressed: () => ref.read(speedTestNotifierProvider.notifier).cancelTest(),
            child: Text(
              'Остановить',
              style: TextStyle(color: theme.colorScheme.error, fontSize: 13),
            ),
          ),
        ],
      );
    }

    final isComplete = state.phase == SpeedTestPhase.complete;
    return FilledButton.icon(
      onPressed: () => ref.read(speedTestNotifierProvider.notifier).startTest(),
      icon: Icon(
        isComplete ? Icons.refresh_rounded : Icons.speed_rounded,
        size: 20,
      ),
      label: Text(isComplete ? 'Проверить снова' : 'Проверить скорость'),
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        textStyle: const TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildPhaseLabel(SpeedTestState state, ThemeData theme) {
    String label;
    switch (state.phase) {
      case SpeedTestPhase.selectingServer:
        label = 'Выбор сервера...';
      case SpeedTestPhase.ping:
        label = 'Измерение пинга...';
      case SpeedTestPhase.download:
        label = 'Тест загрузки...';
      case SpeedTestPhase.upload:
        label = 'Тест отдачи...';
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

  Widget _buildError(SpeedTestState state, ThemeData theme) {
    return Container(
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
    );
  }
}

class _ResultItem extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;
  final bool isActive;
  final String? liveValue;

  const _ResultItem({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
    this.isActive = false,
    this.liveValue,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final displayValue = liveValue ?? value;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: isActive ? color : color.withValues(alpha: 0.6), size: 18),
        const Gap(4),
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 200),
          child: Text(
            displayValue,
            key: ValueKey(displayValue),
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: isActive ? color : null,
            ),
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
