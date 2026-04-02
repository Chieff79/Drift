import 'dart:async';

import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_failover_notifier.g.dart';

/// Monitors connection health and automatically switches to the best
/// available outbound when the current one becomes unreachable.
@Riverpod(keepAlive: true)
class AutoFailoverNotifier extends _$AutoFailoverNotifier with AppLogger {
  Timer? _healthCheckTimer;
  static const _checkInterval = Duration(seconds: 30);
  static const _failoverDelay = 65000; // ms, considered timeout

  @override
  Future<void> build() async {
    ref.watch(coreRestartSignalProvider);
    final isConnected = await ref
        .watch(serviceRunningProvider.future)
        .catchError((_) => false);

    ref.onDispose(() {
      _healthCheckTimer?.cancel();
    });

    if (!isConnected) {
      _healthCheckTimer?.cancel();
      return;
    }

    // Start periodic health checks when connected
    _healthCheckTimer?.cancel();
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) => _checkAndFailover());
  }

  Future<void> _checkAndFailover() async {
    try {
      final proxyRepo = ref.read(proxyRepositoryProvider);

      // Get current outbound group
      final groupStream = proxyRepo.watchActiveProxies();
      final groups = await groupStream.first;

      final groupList = groups.getOrElse((_) => []);
      if (groupList.isEmpty) return;

      final group = groupList.first;
      if (group.items.length < 2) return; // Need at least 2 outbounds

      // Run URL test on the group
      await proxyRepo.urlTest(group.tag).run();

      // Wait for test results to propagate
      await Future.delayed(const Duration(seconds: 3));

      // Re-fetch updated group
      final updatedGroups = await proxyRepo.watchActiveProxies().first;
      final updatedGroupList = updatedGroups.getOrElse((_) => []);
      if (updatedGroupList.isEmpty) return;

      final updatedGroup = updatedGroupList.first;
      final currentSelected = updatedGroup.selected;

      // Find current outbound's delay
      final currentItem = updatedGroup.items
          .where((e) => e.tag == currentSelected)
          .firstOrNull;

      final currentDelay = currentItem?.urlTestDelay ?? 0;

      // If current is fine (< 5s and > 0), no failover needed
      if (currentDelay > 0 && currentDelay < _failoverDelay) return;

      // Find best alternative (lowest positive delay, under timeout)
      OutboundInfo? bestItem;
      for (final item in updatedGroup.items) {
        if (item.urlTestDelay <= 0 || item.urlTestDelay >= _failoverDelay) continue;
        if (item.tag == currentSelected) continue;
        if (bestItem == null || item.urlTestDelay < bestItem.urlTestDelay) {
          bestItem = item;
        }
      }

      if (bestItem != null) {
        loggy.warning(
          'Auto-failover: current [$currentSelected] delay=${currentDelay}ms, '
          'switching to [${bestItem.tag}] delay=${bestItem.urlTestDelay}ms',
        );
        await proxyRepo.selectProxy(updatedGroup.tag, bestItem.tag).run();
      } else {
        loggy.debug('Auto-failover: no better outbound available');
      }
    } catch (e) {
      loggy.debug('Auto-failover check error: $e');
    }
  }
}
