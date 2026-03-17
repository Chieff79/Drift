import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/speed_test/speed_test_notifier.dart';
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
      appBar: AppBar(
        title: const Text('Speed Test'),
      ),
      body: Container(
        width: double.infinity,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              theme.colorScheme.surface,
              theme.colorScheme.surface,
              theme.colorScheme.surfaceContainerLow,
            ],
          ),
        ),
        child: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 500),
                child: Column(
                  children: [
                    const Gap(12),
                    // Mode selector
                    _ModeSelector(
                      mode: state.mode,
                      enabled: !isRunning,
                      onChanged: (mode) {
                        ref.read(speedTestNotifierProvider.notifier).setMode(mode);
                      },
                    ),
                    const Gap(16),
                    // Phase indicator
                    _PhaseIndicator(phase: state.phase, mode: state.mode),
                    const Gap(20),
                    // Gauge
                    SpeedGauge(
                      speed: _gaugeSpeed(state),
                      isActive: isRunning,
                    ),
                    const Gap(20),
                    // Start / Cancel button
                    _ActionButton(
                      phase: state.phase,
                      onStart: () => ref
                          .read(speedTestNotifierProvider.notifier)
                          .startTest(state.mode),
                      onCancel: () => ref
                          .read(speedTestNotifierProvider.notifier)
                          .cancelTest(),
                    ),
                    const Gap(20),
                    // Results grid for current mode
                    if (state.phase == SpeedTestPhase.complete ||
                        _hasPartialResults(state))
                      _ResultsGrid(state: state),
                    // Error
                    if (state.error != null) ...[
                      const Gap(12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: theme.colorScheme.errorContainer,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Icon(Icons.error_outline,
                                color: theme.colorScheme.error, size: 20),
                            const Gap(8),
                            Expanded(
                              child: Text(
                                state.error!,
                                style: TextStyle(
                                    color: theme.colorScheme.onErrorContainer,
                                    fontSize: 13),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                    const Gap(12),
                    // Server info
                    if (state.serverCity != null || state.userCity != null)
                      _ServerInfoCards(state: state),
                    // Comparison view
                    if (state.hasBothResults) ...[
                      const Gap(20),
                      _ComparisonView(state: state),
                    ],
                    const Gap(32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  double _gaugeSpeed(SpeedTestState state) {
    switch (state.phase) {
      case SpeedTestPhase.ping:
      case SpeedTestPhase.selectingServer:
      case SpeedTestPhase.download:
      case SpeedTestPhase.upload:
        return state.currentSpeed;
      case SpeedTestPhase.complete:
        return state.downloadSpeed;
      case SpeedTestPhase.idle:
        return 0;
    }
  }

  bool _hasPartialResults(SpeedTestState state) {
    return state.ping > 0 || state.downloadSpeed > 0 || state.uploadSpeed > 0;
  }
}

class _ModeSelector extends StatelessWidget {
  final SpeedTestMode mode;
  final bool enabled;
  final ValueChanged<SpeedTestMode> onChanged;

  const _ModeSelector({
    required this.mode,
    required this.enabled,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return SegmentedButton<SpeedTestMode>(
      segments: [
        ButtonSegment<SpeedTestMode>(
          value: SpeedTestMode.beforeVpn,
          icon: Icon(Icons.signal_wifi_off_rounded, size: 16),
          label: Text('Without VPN', style: TextStyle(fontSize: 12)),
        ),
        ButtonSegment<SpeedTestMode>(
          value: SpeedTestMode.afterVpn,
          icon: Icon(Icons.vpn_lock_rounded, size: 16),
          label: Text('With VPN', style: TextStyle(fontSize: 12)),
        ),
      ],
      selected: {mode},
      onSelectionChanged: enabled
          ? (selected) => onChanged(selected.first)
          : null,
      style: SegmentedButton.styleFrom(
        selectedForegroundColor: theme.colorScheme.onPrimary,
        selectedBackgroundColor: theme.colorScheme.primary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class _PhaseIndicator extends StatelessWidget {
  final SpeedTestPhase phase;
  final SpeedTestMode mode;

  const _PhaseIndicator({required this.phase, required this.mode});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    String label;
    switch (phase) {
      case SpeedTestPhase.idle:
        label = mode == SpeedTestMode.beforeVpn
            ? 'Test without VPN'
            : 'Test with VPN';
      case SpeedTestPhase.selectingServer:
        label = 'Selecting server...';
      case SpeedTestPhase.ping:
        label = 'Measuring ping...';
      case SpeedTestPhase.download:
        label = 'Testing download...';
      case SpeedTestPhase.upload:
        label = 'Testing upload...';
      case SpeedTestPhase.complete:
        label = 'Test complete';
    }

    final isRunning =
        phase != SpeedTestPhase.idle && phase != SpeedTestPhase.complete;

    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (isRunning) ...[
          SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: theme.colorScheme.primary,
            ),
          ),
          const Gap(8),
        ],
        if (phase == SpeedTestPhase.complete)
          Icon(Icons.check_circle, size: 18, color: theme.colorScheme.primary),
        if (phase == SpeedTestPhase.complete) const Gap(6),
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );
  }
}

class _ActionButton extends StatelessWidget {
  final SpeedTestPhase phase;
  final VoidCallback onStart;
  final VoidCallback onCancel;

  const _ActionButton({
    required this.phase,
    required this.onStart,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isRunning =
        phase != SpeedTestPhase.idle && phase != SpeedTestPhase.complete;

    if (isRunning) {
      return OutlinedButton.icon(
        onPressed: onCancel,
        icon: const Icon(Icons.stop_rounded, size: 20),
        label: const Text('Cancel'),
        style: OutlinedButton.styleFrom(
          foregroundColor: theme.colorScheme.error,
          side: BorderSide(
              color: theme.colorScheme.error.withValues(alpha: 0.5)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    }

    if (phase == SpeedTestPhase.complete) {
      return FilledButton.icon(
        onPressed: onStart,
        icon: const Icon(Icons.refresh_rounded, size: 20),
        label: const Text('Test Again'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        ),
      );
    }

    // Idle — show START button
    return SizedBox(
      width: 120,
      height: 120,
      child: Material(
        shape: const CircleBorder(),
        color: theme.colorScheme.primary,
        elevation: 4,
        shadowColor: theme.colorScheme.primary.withValues(alpha: 0.4),
        child: InkWell(
          customBorder: const CircleBorder(),
          onTap: onStart,
          child: Center(
            child: Text(
              'START',
              style: TextStyle(
                color: theme.colorScheme.onPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold,
                letterSpacing: 2,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ResultsGrid extends StatelessWidget {
  final SpeedTestState state;

  const _ResultsGrid({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Expanded(
          child: _ResultTile(
            icon: Icons.download_rounded,
            label: 'Download',
            value: state.downloadSpeed > 0
                ? state.downloadSpeed.toStringAsFixed(1)
                : '--',
            unit: 'Mbps',
            color: const Color(0xFF4FC3F7),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _ResultTile(
            icon: Icons.upload_rounded,
            label: 'Upload',
            value: state.uploadSpeed > 0
                ? state.uploadSpeed.toStringAsFixed(1)
                : '--',
            unit: 'Mbps',
            color: const Color(0xFFAB47BC),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _ResultTile(
            icon: Icons.network_ping_rounded,
            label: 'Ping',
            value:
                state.ping > 0 ? state.ping.toStringAsFixed(0) : '--',
            unit: 'ms',
            color: const Color(0xFF66BB6A),
          ),
        ),
        const Gap(12),
        Expanded(
          child: _ResultTile(
            icon: Icons.swap_vert_rounded,
            label: 'Jitter',
            value: state.jitter > 0
                ? state.jitter.toStringAsFixed(1)
                : '--',
            unit: 'ms',
            color: const Color(0xFFFFB74D),
          ),
        ),
      ],
    );
  }
}

class _ResultTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final String unit;
  final Color color;

  const _ResultTile({
    required this.icon,
    required this.label,
    required this.value,
    required this.unit,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: color, size: 20),
          const Gap(6),
          Text(
            value,
            style: theme.textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.onSurface,
            ),
          ),
          Text(
            unit,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
          const Gap(2),
          Text(
            label,
            style: TextStyle(
              fontSize: 10,
              color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _ServerInfoCards extends StatelessWidget {
  final SpeedTestState state;

  const _ServerInfoCards({required this.state});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (state.userCity != null || state.userCountry != null)
          Expanded(
            child: _InfoCard(
              icon: Icons.my_location_rounded,
              title: 'Your Location',
              subtitle: [
                if (state.userCity != null) state.userCity!,
                if (state.userCountry != null) state.userCountry!,
              ].join(', '),
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        if (state.userCity != null && state.serverCity != null) const Gap(12),
        if (state.serverCity != null || state.serverCountry != null)
          Expanded(
            child: _InfoCard(
              icon: Icons.dns_rounded,
              title: 'Test Server',
              subtitle: [
                if (state.serverCity != null) state.serverCity!,
                if (state.serverCountry != null) state.serverCountry!,
              ].join(', '),
              color: Theme.of(context).colorScheme.secondary,
            ),
          ),
      ],
    );
  }
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(icon, color: color, size: 18),
          ),
          const Gap(10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 10,
                    color:
                        theme.colorScheme.onSurface.withValues(alpha: 0.5),
                  ),
                ),
                Text(
                  subtitle,
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ComparisonView extends StatelessWidget {
  final SpeedTestState state;

  const _ComparisonView({required this.state});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: theme.colorScheme.primary.withValues(alpha: 0.2),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.compare_arrows_rounded,
                  size: 18, color: theme.colorScheme.primary),
              const Gap(8),
              Text(
                'Comparison',
                style: theme.textTheme.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const Gap(12),
          // Header
          Row(
            children: [
              const Expanded(flex: 2, child: SizedBox()),
              Expanded(
                flex: 3,
                child: Text(
                  'Without VPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
              ),
              Expanded(
                flex: 3,
                child: Text(
                  'With VPN',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: theme.colorScheme.primary,
                  ),
                ),
              ),
            ],
          ),
          const Gap(8),
          _ComparisonRow(
            label: 'Download',
            before: '${state.beforeDownload?.toStringAsFixed(1) ?? "--"} Mbps',
            after: '${state.afterDownload?.toStringAsFixed(1) ?? "--"} Mbps',
            theme: theme,
          ),
          const Gap(6),
          _ComparisonRow(
            label: 'Upload',
            before: '${state.beforeUpload?.toStringAsFixed(1) ?? "--"} Mbps',
            after: '${state.afterUpload?.toStringAsFixed(1) ?? "--"} Mbps',
            theme: theme,
          ),
          const Gap(6),
          _ComparisonRow(
            label: 'Ping',
            before: '${state.beforePing?.toStringAsFixed(0) ?? "--"} ms',
            after: '${state.afterPing?.toStringAsFixed(0) ?? "--"} ms',
            theme: theme,
          ),
          const Gap(6),
          _ComparisonRow(
            label: 'Jitter',
            before: '${state.beforeJitter?.toStringAsFixed(1) ?? "--"} ms',
            after: '${state.afterJitter?.toStringAsFixed(1) ?? "--"} ms',
            theme: theme,
          ),
        ],
      ),
    );
  }
}

class _ComparisonRow extends StatelessWidget {
  final String label;
  final String before;
  final String after;
  final ThemeData theme;

  const _ComparisonRow({
    required this.label,
    required this.before,
    required this.after,
    required this.theme,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 10),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          Expanded(
            flex: 2,
            child: Text(
              label,
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w500,
                color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              before,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.onSurface,
              ),
            ),
          ),
          Expanded(
            flex: 3,
            child: Text(
              after,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w600,
                color: theme.colorScheme.primary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
