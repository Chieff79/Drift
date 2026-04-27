import 'dart:async';

import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/active/protocol_family.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'auto_failover_notifier.g.dart';

/// Smart auto-failover с приоритезацией по семействам протоколов.
///
/// Алгоритм:
/// 1. Раз в 20с делаем urlTest активной группы.
/// 2. Если delay активного outbound < 45с → всё ок, ничего не делаем.
/// 3. Если 2 раза подряд delay >= 45с (или ≤ 0) → переключаемся:
///    a. Сначала ищем живой outbound в **том же семействе** (минимизирует
///       визуальную смену "страны" для пользователя).
///    b. Если в семействе никого — fallback по `fallbackOrder`:
///       RU-cloud → Hysteria2 → XHTTP → EU/US direct.
///    c. Внутри выбранного семейства — берём минимальную задержку.
///
/// Уважение к ручному выбору: auto_failover вмешивается **только когда текущий
/// outbound мёртв**. Если юзер выбрал US Direct и она работает — не трогаем.
/// Полное отключение — `Preferences.useAutoRotation = false`.
@Riverpod(keepAlive: true)
class AutoFailoverNotifier extends _$AutoFailoverNotifier with AppLogger {
  Timer? _healthCheckTimer;
  int _consecutiveFailures = 0;
  static const _checkInterval = Duration(seconds: 20);
  static const _failoverDelay = 45000; // ms — таймаут (мобильная сеть + ТСПУ стресс)
  static const _consecutiveFailuresBeforeSwitch = 2; // hysteresis

  @override
  Future<void> build() async {
    ref.watch(coreRestartSignalProvider);
    final isConnected = await ref
        .watch(serviceRunningProvider.future)
        .catchError((_) => false);
    final useAutoRotation = ref.watch(Preferences.useAutoRotation);

    ref.onDispose(() {
      _healthCheckTimer?.cancel();
    });

    if (!isConnected || !useAutoRotation) {
      _healthCheckTimer?.cancel();
      _consecutiveFailures = 0;
      return;
    }

    _healthCheckTimer?.cancel();
    _consecutiveFailures = 0;
    _healthCheckTimer = Timer.periodic(_checkInterval, (_) => _checkAndFailover());
  }

  Future<void> _checkAndFailover() async {
    try {
      final proxyRepo = ref.read(proxyRepositoryProvider);

      final groupStream = proxyRepo.watchActiveProxies();
      final groups = await groupStream.first;

      final groupList = groups.getOrElse((_) => []);
      if (groupList.isEmpty) return;

      final group = groupList.first;
      if (group.items.length < 2) return;

      await proxyRepo.urlTest(group.tag).run();
      await Future.delayed(const Duration(seconds: 3));

      final updatedGroups = await proxyRepo.watchActiveProxies().first;
      final updatedGroupList = updatedGroups.getOrElse((_) => []);
      if (updatedGroupList.isEmpty) return;

      final updatedGroup = updatedGroupList.first;
      final currentSelected = updatedGroup.selected;

      final currentItem = updatedGroup.items
          .where((e) => e.tag == currentSelected)
          .firstOrNull;

      final currentDelay = currentItem?.urlTestDelay ?? 0;

      if (currentDelay > 0 && currentDelay < _failoverDelay) {
        _consecutiveFailures = 0;
        return;
      }

      _consecutiveFailures++;
      if (_consecutiveFailures < _consecutiveFailuresBeforeSwitch) {
        loggy.debug(
          'Auto-failover: [$currentSelected] unhealthy (delay=${currentDelay}ms), '
          'waiting ($_consecutiveFailures/$_consecutiveFailuresBeforeSwitch)',
        );
        return;
      }

      final next = _pickNextOutbound(
        items: updatedGroup.items,
        currentTag: currentSelected,
      );

      if (next != null) {
        final currentFamily = currentItem == null
            ? ProtocolFamily.unknown
            : detectProtocolFamily(currentItem.tag, outboundType: currentItem.type);
        final nextFamily = detectProtocolFamily(next.tag, outboundType: next.type);
        loggy.warning(
          'Auto-failover: [$currentSelected] (${currentFamily.name}, '
          'delay=${currentDelay}ms) → [${next.tag}] (${nextFamily.name}, '
          'delay=${next.urlTestDelay}ms)',
        );
        await proxyRepo.selectProxy(updatedGroup.tag, next.tag).run();
        _consecutiveFailures = 0;
      } else {
        loggy.debug('Auto-failover: no healthy outbound available in any family');
      }
    } catch (e) {
      loggy.debug('Auto-failover check error: $e');
    }
  }

  /// Возвращает лучший живой outbound с учётом семейств.
  ///
  /// Стратегия (см. doc-comment класса):
  /// 1. Living outbounds в том же семействе, что и `currentTag`.
  /// 2. Если нет — обходим семейства по `fallbackOrder`.
  /// 3. Внутри семейства — минимальная задержка.
  OutboundInfo? _pickNextOutbound({
    required List<OutboundInfo> items,
    required String currentTag,
  }) {
    final alive = items
        .where((e) =>
            e.tag != currentTag &&
            e.urlTestDelay > 0 &&
            e.urlTestDelay < _failoverDelay)
        .toList();
    if (alive.isEmpty) return null;

    final currentItem = items.where((e) => e.tag == currentTag).firstOrNull;
    final currentFamily = currentItem == null
        ? ProtocolFamily.unknown
        : detectProtocolFamily(currentItem.tag, outboundType: currentItem.type);

    OutboundInfo? bestInFamily(ProtocolFamily family) {
      OutboundInfo? best;
      for (final item in alive) {
        if (detectProtocolFamily(item.tag, outboundType: item.type) != family) {
          continue;
        }
        if (best == null || item.urlTestDelay < best.urlTestDelay) {
          best = item;
        }
      }
      return best;
    }

    // 1. Сначала в текущем семействе
    final sameFamily = bestInFamily(currentFamily);
    if (sameFamily != null) return sameFamily;

    // 2. Fallback по приоритету
    final orderedFamilies = ProtocolFamily.values.toList()
      ..sort((a, b) => a.fallbackOrder.compareTo(b.fallbackOrder));
    for (final family in orderedFamilies) {
      if (family == currentFamily) continue;
      final pick = bestInFamily(family);
      if (pick != null) return pick;
    }

    // 3. Совсем крайний случай — любой живой
    alive.sort((a, b) => a.urlTestDelay.compareTo(b.urlTestDelay));
    return alive.first;
  }
}
