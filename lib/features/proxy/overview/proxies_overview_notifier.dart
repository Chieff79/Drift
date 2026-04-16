import 'dart:async';
import 'package:dartx/dartx.dart';
import 'package:hiddify/core/haptic/haptic_service.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/preferences/preferences_provider.dart';
import 'package:hiddify/core/utils/preferences_utils.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/proxy/data/proxy_data_providers.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/riverpod_utils.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'proxies_overview_notifier.g.dart';

enum ProxiesSort {
  unsorted,
  name,
  delay,
  usage;

  String present(TranslationsEn t) => switch (this) {
        ProxiesSort.unsorted => t.pages.proxies.sortOptions.unsorted,
        ProxiesSort.name => t.pages.proxies.sortOptions.name,
        ProxiesSort.delay => t.pages.proxies.sortOptions.delay,
        ProxiesSort.usage => t.pages.proxies.sortOptions.usage,
      };
}

@Riverpod(keepAlive: true)
class ProxiesSortNotifier extends _$ProxiesSortNotifier with AppLogger {
  late final _pref = PreferencesEntry(
    preferences: ref.watch(sharedPreferencesProvider).requireValue,
    key: "proxies_sort_mode",
    defaultValue: ProxiesSort.delay,
    mapFrom: ProxiesSort.values.byName,
    mapTo: (value) => value.name,
  );

  @override
  ProxiesSort build() {
    return _pref.read();
  }

  Future<void> update(ProxiesSort value) {
    state = value;
    return _pref.write(value);
  }
}

@riverpod
class ProxiesOverviewNotifier extends _$ProxiesOverviewNotifier with AppLogger {
  @override
  Stream<OutboundGroup?> build() async* {
    ref.disposeDelay(const Duration(seconds: 15));
    ref.watch(coreRestartSignalProvider);

    final serviceRunning = await ref.watch(serviceRunningProvider.future);
    final sortBy = ref.watch(proxiesSortNotifierProvider);

    if (!serviceRunning) {
      // Return null so CountrySelectionPage can show groups based on local parsing
      // of any cached or loaded profiles even if sing-box isn't "live"
      yield null;
      return;
    }

    yield* ref
        .watch(proxyRepositoryProvider)
        .watchProxies()
        .map(
          (event) => event.getOrElse((err) {
            loggy.warning("error receiving proxies", err);
            throw err;
          }),
        )
        .asyncMap((proxies) async => await _sortOutbounds(proxies, sortBy));
  }

  Future<OutboundGroup?> _sortOutbounds(
      OutboundGroup? proxies, ProxiesSort sortBy) async {
    if (proxies == null) return null;

    final sortedItems = switch (sortBy) {
      ProxiesSort.name => proxies.items.sortedWith((a, b) {
          if (a.isGroup && !b.isGroup) return -1;
          if (!a.isGroup && b.isGroup) return 1;
          return a.tag.compareTo(b.tag);
        }),
      ProxiesSort.delay => proxies.items.sortedWith((a, b) {
          if (a.isGroup && !b.isGroup) return -1;
          if (!a.isGroup && b.isGroup) return 1;

          final ai = a.urlTestDelay;
          final bi = b.urlTestDelay;
          if (ai == 0 && bi == 0) return 0;
          if (ai == 0) return 1;
          if (bi == 0) return -1;
          return ai.compareTo(bi);
        }),
      ProxiesSort.usage => proxies.items.sortedWith((a, b) {
          return (b.upload + b.download).compareTo(a.upload + a.download);
        }),
      ProxiesSort.unsorted => proxies.items,
    };

    proxies.items.clear();
    proxies.items.addAll(sortedItems);
    return proxies;
  }

  Future<void> changeProxy(String groupTag, String outboundTag) async {
    loggy.debug("changing proxy to: [$outboundTag]");

    await ref.read(hapticServiceProvider.notifier).lightImpact();

    // 1. Try to notify the core service if it's running
    try {
      await ref
          .read(proxyRepositoryProvider)
          .selectProxy(groupTag, outboundTag)
          .getOrElse((err) {
        loggy.warning("core selection failed (expected if service not running)");
        throw err;
      }).run();
    } catch (e) {
      loggy.warning("selectProxy exception: $e");
    }

    // 2. Update local state immediately for UI responsiveness
    if (state.hasValue && state.value != null) {
      final current = state.value!;
      current.selected = outboundTag;
      for (var item in current.items) {
        item.isSelected = (item.tag == outboundTag);
      }
      state = AsyncValue.data(current);
    }
  }

  Future<void> urlTest(String groupTag) async {
    if (state.hasValue) {
      await ref.read(hapticServiceProvider.notifier).lightImpact();
      await ref
          .read(proxyRepositoryProvider)
          .urlTest(groupTag)
          .getOrElse((err) => throw err)
          .run();
    }
  }
}
