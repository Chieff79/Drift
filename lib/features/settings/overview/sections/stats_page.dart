import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/stats/notifier/stats_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class StatsPage extends HookConsumerWidget {
  const StatsPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final stats = ref.watch(statsNotifierProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);

    final isConnected = connectionStatus.asData?.value.isConnected ?? false;

    // Track connection duration
    final connectedSince = useState<DateTime?>(null);
    final elapsed = useState<Duration>(Duration.zero);

    useEffect(() {
      if (isConnected && connectedSince.value == null) {
        connectedSince.value = DateTime.now();
      } else if (!isConnected) {
        connectedSince.value = null;
        elapsed.value = Duration.zero;
      }
      return null;
    }, [isConnected]);

    // Timer to update elapsed duration
    useEffect(() {
      if (!isConnected || connectedSince.value == null) return null;
      final timer = Timer.periodic(const Duration(seconds: 1), (_) {
        elapsed.value = DateTime.now().difference(connectedSince.value!);
      });
      return timer.cancel;
    }, [isConnected, connectedSince.value]);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Статистика')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Connection status card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    isConnected ? Icons.cloud_done_rounded : Icons.cloud_off_rounded,
                    color: isConnected ? Colors.green : Colors.grey,
                    size: 32,
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        isConnected ? 'Подключено' : 'Отключено',
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      if (isConnected)
                        Text(
                          'Время подключения: ${_formatDuration(elapsed.value)}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.onSurfaceVariant,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          const Gap(16),

          // Current speed section
          Text(
            'Текущая скорость',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.arrow_downward_rounded,
                  iconColor: Colors.green,
                  label: 'Загрузка',
                  value: stats.when(
                    data: (info) => _formatSpeed(info.downlink.toInt()),
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: _StatCard(
                  icon: Icons.arrow_upward_rounded,
                  iconColor: Colors.blue,
                  label: 'Отдача',
                  value: stats.when(
                    data: (info) => _formatSpeed(info.uplink.toInt()),
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),

          // Session totals section
          Text(
            'За сессию',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
              color: theme.colorScheme.primary,
            ),
          ),
          const Gap(8),
          Row(
            children: [
              Expanded(
                child: _StatCard(
                  icon: Icons.download_rounded,
                  iconColor: Colors.green,
                  label: 'Загружено',
                  value: stats.when(
                    data: (info) => _formatBytes(info.downlinkTotal.toInt()),
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
              const Gap(8),
              Expanded(
                child: _StatCard(
                  icon: Icons.upload_rounded,
                  iconColor: Colors.blue,
                  label: 'Отдано',
                  value: stats.when(
                    data: (info) => _formatBytes(info.uplinkTotal.toInt()),
                    loading: () => '—',
                    error: (_, __) => '—',
                  ),
                ),
              ),
            ],
          ),
          const Gap(16),

          // Connection duration card
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Icon(
                    Icons.timer_rounded,
                    color: theme.colorScheme.primary,
                    size: 28,
                  ),
                  const Gap(12),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Время подключения',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurfaceVariant,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        isConnected ? _formatDuration(elapsed.value) : '—',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond <= 0) return '0 B/s';
    if (bytesPerSecond < 1024) return '$bytesPerSecond B/s';
    if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(1)} KB/s';
    }
    if (bytesPerSecond < 1024 * 1024 * 1024) {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
    return '${(bytesPerSecond / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB/s';
  }

  static String _formatBytes(int bytes) {
    if (bytes <= 0) return '0 B';
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) {
      return '${(bytes / 1024).toStringAsFixed(1)} KB';
    }
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(2)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(2)} GB';
  }

  static String _formatDuration(Duration duration) {
    final hours = duration.inHours.toString().padLeft(2, '0');
    final minutes = (duration.inMinutes % 60).toString().padLeft(2, '0');
    final seconds = (duration.inSeconds % 60).toString().padLeft(2, '0');
    return '$hours:$minutes:$seconds';
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: iconColor, size: 20),
                const Gap(6),
                Text(
                  label,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
            const Gap(8),
            Text(
              value,
              style: theme.textTheme.titleLarge?.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
