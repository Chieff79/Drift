import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/region.dart';
import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/per_app_proxy/model/per_app_proxy_mode.dart';
import 'package:hiddify/features/per_app_proxy/overview/per_app_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/features/settings/widget/preference_tile.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class RouteOptionsPage extends HookConsumerWidget {
  const RouteOptionsPage({super.key});
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final perAppProxy = ref.watch(Preferences.perAppProxyMode).enabled;
    return Scaffold(
      appBar: AppBar(title: const Text('Маршрутизация')),
      body: ListView(
        children: [
          if (PlatformUtils.isAndroid)
            ListTile(
              title: Text(t.pages.settings.routing.perAppProxy.title),
              subtitle: const Text('Выбрать приложения для туннеля'),
              leading: const Icon(Icons.apps_rounded),
              trailing: Switch(
                value: perAppProxy,
                onChanged: (value) async {
                  final newMode = perAppProxy ? PerAppProxyMode.off : PerAppProxyMode.exclude;
                  await ref.read(Preferences.perAppProxyMode.notifier).update(newMode);
                  if (!perAppProxy && context.mounted) context.goNamed('perAppProxy');
                },
              ),
              onTap: () async {
                if (!perAppProxy) {
                  await ref.read(Preferences.perAppProxyMode.notifier).update(PerAppProxyMode.exclude);
                }
                if (context.mounted) context.goNamed('perAppProxy');
              },
            ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.region),
            preferences: ref.watch(ConfigOptions.region.notifier),
            choices: Region.values,
            title: t.pages.settings.routing.region,
            description: 'Регион для оптимальной маршрутизации',
            showFlag: true,
            icon: Icons.place_rounded,
            presentChoice: (value) => value.present(t),
            onChanged: (val) async {
              await ref.read(ConfigOptions.directDnsAddress.notifier).reset();
              final autoRegion = ref.read(Preferences.autoAppsSelectionRegion);
              final mode = ref.read(Preferences.perAppProxyMode).toAppProxy();
              if (autoRegion != val &&
                  autoRegion != null &&
                  val != Region.other &&
                  mode != null &&
                  PlatformUtils.isAndroid) {
                await ref
                    .read(dialogNotifierProvider.notifier)
                    .showOk(
                      t.pages.settings.routing.perAppProxy.autoSelection.dialog.title,
                      t.pages.settings.routing.perAppProxy.autoSelection.dialog.msg(region: val.name),
                    );
                await ref.read(PerAppProxyProvider(mode).notifier).clearAutoSelected();
              }
            },
          ),
          ChoicePreferenceWidget(
            title: t.pages.settings.routing.balancerStrategy.title,
            description: 'Способ выбора лучшего сервера',
            icon: Icons.balance_rounded,
            selected: ref.watch(ConfigOptions.balancerStrategy),
            preferences: ref.watch(ConfigOptions.balancerStrategy.notifier),
            choices: BalancerStrategy.values,
            presentChoice: (value) => value.present(t),
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.routing.blockAds),
            subtitle: const Text('Блокировать рекламу и трекеры'),
            secondary: const Icon(Icons.block_rounded),
            value: ref.watch(ConfigOptions.blockAds),
            onChanged: ref.read(ConfigOptions.blockAds.notifier).update,
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.home.whitelist.title),
            subtitle: Text(t.pages.home.whitelist.subtitle),
            secondary: const Icon(Icons.shield_outlined),
            value: ref.watch(ConfigOptions.enableRuWhitelist),
            onChanged: ref.read(ConfigOptions.enableRuWhitelist.notifier).update,
          ),
          if (PlatformUtils.isAndroid)
            SwitchListTile.adaptive(
              title: const Text('РФ-приложения без VPN'),
              subtitle: const Text(
                'Сбер, Тинькофф, Яндекс, VK, Госуслуги и др. — напрямую. Банки и маркетплейсы не увидят, что включён туннель',
              ),
              secondary: const Icon(Icons.account_balance_rounded),
              value: ref.watch(ConfigOptions.enableRuAppsBypass),
              onChanged: ref.read(ConfigOptions.enableRuAppsBypass.notifier).update,
            ),
          if (PlatformUtils.isDesktop)
            SwitchListTile.adaptive(
              title: const Text('РФ-процессы без VPN'),
              subtitle: const Text(
                'Клиенты Сбера, Тинькофф, Яндекса, Kaspersky и др. на десктопе — мимо туннеля. Работает через process_name в sing-box',
              ),
              secondary: const Icon(Icons.desktop_windows_rounded),
              value: ref.watch(ConfigOptions.enableRuAppsBypass),
              onChanged: ref.read(ConfigOptions.enableRuAppsBypass.notifier).update,
            ),
          SwitchListTile.adaptive(
            title: const Text('Ротация SNI'),
            subtitle: const Text(
              'Случайный SNI из пула при каждом подключении. Меньше шансов детекта по повторяющемуся отпечатку',
            ),
            secondary: const Icon(Icons.shuffle_rounded),
            value: ref.watch(ConfigOptions.sniRotation),
            onChanged: ref.read(ConfigOptions.sniRotation.notifier).update,
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.routing.bypassLan),
            subtitle: const Text('Не направлять локальный трафик через туннель'),
            secondary: const Icon(Icons.call_split_rounded),
            value: ref.watch(ConfigOptions.bypassLan),
            onChanged: ref.read(ConfigOptions.bypassLan.notifier).update,
          ),
          SwitchListTile.adaptive(
            title: Text(t.pages.settings.routing.resolveDestination),
            subtitle: const Text('Определять IP-адрес назначения'),
            secondary: const Icon(Icons.security_rounded),
            value: ref.watch(ConfigOptions.resolveDestination),
            onChanged: ref.read(ConfigOptions.resolveDestination.notifier).update,
          ),
          ChoicePreferenceWidget(
            selected: ref.watch(ConfigOptions.ipv6Mode),
            preferences: ref.watch(ConfigOptions.ipv6Mode.notifier),
            choices: IPv6Mode.values,
            title: t.pages.settings.routing.ipv6Route,
            description: 'Режим маршрутизации IPv6',
            icon: Icons.looks_6_rounded,
            presentChoice: (value) => value.present(t),
          ),
        ],
      ),
    );
  }
}
