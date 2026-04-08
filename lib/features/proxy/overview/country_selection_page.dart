import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/proxy/overview/proxies_overview_notifier.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

/// Groups proxies by country and lets the user pick a country.
/// Auto-selects the best (lowest delay) proxy in that country.
class CountrySelectionPage extends HookConsumerWidget {
  const CountrySelectionPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final proxies = ref.watch(proxiesOverviewNotifierProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Выбор страны')),
      body: proxies.when(
        data: (group) {
          if (group == null || group.items.isEmpty) {
            return Center(child: Text(t.pages.proxies.empty));
          }

          final countries = _groupByCountry(group.items);
          final selectedTag = group.selected;

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: countries.length,
            itemBuilder: (context, index) {
              final country = countries[index];
              final isSelected = country.proxies.any((p) => p.tag == selectedTag);

              return _CountryTile(
                country: country,
                isSelected: isSelected,
                onTap: () async {
                  // Select the best proxy in this country
                  final bestProxy = country.bestProxy;
                  await ref
                      .read(proxiesOverviewNotifierProvider.notifier)
                      .changeProxy(group.tag, bestProxy.tag);
                  if (context.mounted) Navigator.of(context).pop();
                },
              );
            },
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.cloud_off_rounded, size: 48, color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .3)),
                const Gap(16),
                Text(
                  t.pages.home.connectFirst,
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const Gap(8),
                Text(
                  t.pages.home.connectFirstInfo,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: Theme.of(context).colorScheme.onSurface.withValues(alpha: .5),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }

  List<CountryGroup> _groupByCountry(List<OutboundInfo> proxies) {
    final map = <String, List<OutboundInfo>>{};

    for (final proxy in proxies) {
      final code = proxy.ipinfo.countryCode.isNotEmpty
          ? proxy.ipinfo.countryCode.toUpperCase()
          : '??';
      map.putIfAbsent(code, () => []).add(proxy);
    }

    final groups = map.entries
        .map((e) => CountryGroup(countryCode: e.key, proxies: e.value))
        .toList();

    // Sort: countries with working proxies (delay > 0) first, then by best delay
    groups.sort((a, b) {
      final aDelay = a.bestDelay;
      final bDelay = b.bestDelay;
      if (aDelay == 0 && bDelay == 0) return a.countryName.compareTo(b.countryName);
      if (aDelay == 0) return 1;
      if (bDelay == 0) return -1;
      return aDelay.compareTo(bDelay);
    });

    return groups;
  }
}

class CountryGroup {
  final String countryCode;
  final List<OutboundInfo> proxies;

  CountryGroup({required this.countryCode, required this.proxies});

  String get countryName => _countryNames[countryCode] ?? countryCode;

  int get bestDelay {
    int best = 0;
    for (final p in proxies) {
      final d = p.urlTestDelay;
      if (d > 0 && d < 65000) {
        if (best == 0 || d < best) best = d;
      }
    }
    return best;
  }

  OutboundInfo get bestProxy {
    OutboundInfo? best;
    for (final p in proxies) {
      final d = p.urlTestDelay;
      if (d > 0 && d < 65000) {
        if (best == null || d < best.urlTestDelay) best = p;
      }
    }
    return best ?? proxies.first;
  }

  int get serverCount => proxies.length;

  static const _countryNames = {
    'RU': 'Россия',
    'NL': 'Нидерланды',
    'US': 'США',
    'DE': 'Германия',
    'FR': 'Франция',
    'GB': 'Великобритания',
    'UA': 'Украина',
    'KZ': 'Казахстан',
    'BY': 'Беларусь',
    'TR': 'Турция',
    'CN': 'Китай',
    'JP': 'Япония',
    'SG': 'Сингапур',
    'FI': 'Финляндия',
    'SE': 'Швеция',
    'CH': 'Швейцария',
    'CA': 'Канада',
    'AU': 'Австралия',
    'PL': 'Польша',
    'CZ': 'Чехия',
    'AT': 'Австрия',
    'IT': 'Италия',
    'ES': 'Испания',
    'BR': 'Бразилия',
    'IN': 'Индия',
    'KR': 'Южная Корея',
    'HK': 'Гонконг',
    'TW': 'Тайвань',
    'IE': 'Ирландия',
    'RO': 'Румыния',
    'BG': 'Болгария',
    'LT': 'Литва',
    'LV': 'Латвия',
    'EE': 'Эстония',
    'MD': 'Молдова',
    'GE': 'Грузия',
    'AZ': 'Азербайджан',
    'AM': 'Армения',
    'UZ': 'Узбекистан',
    'IL': 'Израиль',
    'AE': 'ОАЭ',
    '??': 'Неизвестно',
  };
}

class _CountryTile extends StatelessWidget {
  const _CountryTile({
    required this.country,
    required this.isSelected,
    required this.onTap,
  });

  final CountryGroup country;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final bestDelay = country.bestDelay;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      child: Material(
        color: isSelected
            ? theme.colorScheme.primaryContainer
            : theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: onTap,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            child: Row(
              children: [
                // Country flag
                SizedBox(
                  width: 48,
                  height: 48,
                  child: country.countryCode != '??'
                      ? CircleFlag(
                          country.countryCode.toLowerCase(),
                          size: 48,
                        )
                      : Container(
                          decoration: BoxDecoration(
                            color: theme.colorScheme.onSurface.withValues(alpha: .08),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.public_outlined,
                            size: 28,
                            color: theme.colorScheme.onSurface.withValues(alpha: .4),
                          ),
                        ),
                ),

                const Gap(16),

                // Country name + server count
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        country.countryName,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
                        ),
                      ),
                      const Gap(2),
                      Text(
                        _serverCountLabel(country.serverCount),
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: .5),
                        ),
                      ),
                    ],
                  ),
                ),

                // Latency indicator
                if (bestDelay > 0)
                  _LatencyBadge(delay: bestDelay)
                else
                  Icon(
                    Icons.signal_cellular_off_rounded,
                    size: 18,
                    color: theme.colorScheme.onSurface.withValues(alpha: .3),
                  ),

                const Gap(8),

                // Selection check
                if (isSelected)
                  Icon(
                    Icons.check_circle_rounded,
                    color: theme.colorScheme.primary,
                    size: 24,
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  String _serverCountLabel(int count) {
    if (count == 1) return '1 сервер';
    if (count >= 2 && count <= 4) return '$count сервера';
    return '$count серверов';
  }
}

class _LatencyBadge extends StatelessWidget {
  const _LatencyBadge({required this.delay});

  final int delay;

  @override
  Widget build(BuildContext context) {
    final color = switch (delay) {
      < 300 => Colors.green,
      < 800 => Colors.lightGreen.shade700,
      < 1500 => Colors.deepOrangeAccent,
      _ => Colors.red,
    };

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Text(
        '$delay ms',
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
