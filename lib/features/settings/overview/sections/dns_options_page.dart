import 'package:flutter/material.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class DnsOptionsPage extends HookConsumerWidget {
  const DnsOptionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    return Scaffold(
      appBar: AppBar(title: const Text('DNS')),
      body: ListView(
        children: [
          SwitchListTile.adaptive(
            title: const Text('Блокировка рекламы'),
            subtitle: const Text('Блокирует рекламу и трекеры через AdGuard DNS'),
            secondary: const Icon(Icons.shield_rounded),
            value: ref.watch(ConfigOptions.blockAds),
            onChanged: ref.read(ConfigOptions.blockAds.notifier).update,
          ),
          const Divider(),
          ValuePreferenceWidget(
            value: ref.watch(ConfigOptions.remoteDnsAddress),
            icon: Icons.vpn_lock_rounded,
            preferences: ref.watch(ConfigOptions.remoteDnsAddress.notifier),
            title: t.pages.settings.dns.remoteDns,
            description: 'DNS-сервер для зашифрованных запросов',
          ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.remoteDnsDomainStrategy),
            preferences: ref.watch(ConfigOptions.remoteDnsDomainStrategy.notifier),
            choices: DomainStrategy.values,
            title: t.pages.settings.dns.remoteDnsDomainStrategy,
            description: 'Стратегия разрешения доменов',
            icon: Icons.sync_alt_rounded,
            presentChoice: (value) => value.present(t),
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.dns.enableFakeDns),
            subtitle: const Text('Ускоряет подключение через подмену DNS'),
            secondary: const Icon(Icons.private_connectivity_rounded),
            value: ref.watch(ConfigOptions.enableFakeDns),
            onChanged: ref.read(ConfigOptions.enableFakeDns.notifier).update,
          ),
          ValuePreferenceWidget(
            title: t.pages.settings.dns.directDns,
            icon: Icons.public_rounded,
            value: ref.watch(ConfigOptions.directDnsAddress),
            preferences: ref.watch(ConfigOptions.directDnsAddress.notifier),
            description: 'DNS для прямых соединений',
          ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.directDnsDomainStrategy),
            preferences: ref.watch(ConfigOptions.directDnsDomainStrategy.notifier),
            choices: DomainStrategy.values,
            title: t.pages.settings.dns.directDnsDomainStrategy,
            description: 'Стратегия для прямых запросов',
            icon: Icons.sync_alt_rounded,
            presentChoice: (value) => value.present(t),
          ),
          // SwitchListTile.adaptive(
          //   title: Text(t.pages.settings.dns.enableDnsRouting),
          //   secondary: const Icon(Icons.private_connectivity_rounded),
          //   value: ref.watch(ConfigOptions.enableDnsRouting),
          //   onChanged: ref.read(ConfigOptions.enableDnsRouting.notifier).update,
          // ),
        ],
      ),
    );
  }
}
