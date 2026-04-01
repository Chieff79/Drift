import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/router/go_router/helper/active_breakpoint_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/singbox/model/singbox_config_enum.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hiddify/features/settings/notifier/reset_tunnel/reset_tunnel_notifier.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

enum ConfigOptionSection {
  warp,
  fragment;

  static final _warpKey = GlobalKey(debugLabel: "warp-section-key");
  static final _fragmentKey = GlobalKey(debugLabel: "fragment-section-key");

  GlobalKey get key => switch (this) {
    ConfigOptionSection.warp => _warpKey,
    ConfigOptionSection.fragment => _fragmentKey,
  };
}

class SettingsPage extends HookConsumerWidget {
  SettingsPage({super.key, String? section})
    : section = section != null ? ConfigOptionSection.values.byName(section) : null;

  final ConfigOptionSection? section;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    // final scrollController = useScrollController();

    // useMemoized(
    //   () {
    //     if (section != null) {
    //       WidgetsBinding.instance.addPostFrameCallback(
    //         (_) {
    //           final box = section!.key.currentContext?.findRenderObject() as RenderBox?;

    //           final offset = box?.localToGlobal(Offset.zero);
    //           if (offset == null) return;
    //           final height = scrollController.offset + offset.dy - MediaQueryData.fromView(View.of(context)).padding.top - kToolbarHeight;
    //           scrollController.animateTo(
    //             height,
    //             duration: const Duration(milliseconds: 500),
    //             curve: Curves.decelerate,
    //           );
    //         },
    //       );
    //     }
    //   },
    // );

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.settings.title),
        actions: [
          MenuAnchor(
            menuChildren: <Widget>[
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromClipboard();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.clipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(dialogNotifierProvider.notifier)
                        .showConfirmation(
                          title: t.common.msg.import.confirm,
                          message: t.dialogs.confirmation.settings.import.msg,
                        )
                        .then((shouldImport) async {
                          if (shouldImport) {
                            await ref.read(configOptionNotifierProvider.notifier).importFromJsonFile();
                          }
                        }),
                    child: Text(t.pages.settings.options.import.file),
                  ),
                ],
                child: Text(t.common.import),
              ),
              SubmenuButton(
                menuChildren: <Widget>[
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonClipboard(),
                    child: Text(t.pages.settings.options.export.anonymousToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(),
                    child: Text(t.pages.settings.options.export.anonymousToFile),
                  ),
                  const PopupMenuDivider(),
                  MenuItemButton(
                    onPressed: () async => await ref
                        .read(configOptionNotifierProvider.notifier)
                        .exportJsonClipboard(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToClipboard),
                  ),
                  MenuItemButton(
                    onPressed: () async =>
                        await ref.read(configOptionNotifierProvider.notifier).exportJsonFile(excludePrivate: false),
                    child: Text(t.pages.settings.options.export.allToFile),
                  ),
                ],
                child: Text(t.common.export),
              ),
              const PopupMenuDivider(),
              MenuItemButton(
                child: Text(t.pages.settings.options.reset),
                onPressed: () async => await ref.read(configOptionNotifierProvider.notifier).resetOption(),
              ),
            ],
            builder: (context, controller, child) => IconButton(
              onPressed: () {
                if (controller.isOpen) {
                  controller.close();
                } else {
                  controller.open();
                }
              },
              icon: const Icon(Icons.more_vert_rounded),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: ListView(
        children: [
          // TipCard(message: t.settings.experimentalMsg),
          SettingsSection(
            title: 'Основные',
            icon: Icons.layers_rounded,
            subtitle: 'Язык, тема, уведомления',
            namedLocation: context.namedLocation('general'),
          ),
          SettingsSection(
            title: 'Маршрутизация',
            icon: Icons.route_rounded,
            subtitle: 'Блокировка рекламы, обход локальной сети',
            namedLocation: context.namedLocation('routeOptions'),
          ),
          if (PlatformUtils.isAndroid)
            Material(
              child: ListTile(
                leading: const Icon(Icons.call_split_rounded),
                title: const Text('Split Tunneling'),
                subtitle: const Text('Выбрать приложения для туннеля'),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => context.goNamed('perAppProxy'),
              ),
            ),
          SettingsSection(
            title: 'DNS',
            icon: Icons.dns_rounded,
            subtitle: 'Серверы имён, защита от утечек',
            namedLocation: context.namedLocation('dnsOptions'),
          ),
          SettingsSection(
            title: 'Подключение',
            icon: Icons.input_rounded,
            subtitle: 'Режим работы, порты',
            namedLocation: context.namedLocation('inboundOptions'),
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.shield_rounded),
            title: const Text('Kill Switch'),
            subtitle: const Text('Блокировать трафик если защита отключена'),
            value: ref.watch(ConfigOptions.strictRoute),
            onChanged: (value) async {
              await ref.read(ConfigOptions.strictRoute.notifier).update(value);
            },
          ),
          SwitchListTile.adaptive(
            secondary: const Icon(Icons.cloud_rounded),
            title: const Text('WARP'),
            subtitle: Text(ref.watch(ConfigOptions.warpDetourMode).presentExplain(t)),
            value: ref.watch(ConfigOptions.enableWarp),
            onChanged: (value) async {
              await ref.read(ConfigOptions.enableWarp.notifier).update(value);
            },
          ),
          const Divider(height: 1, indent: 16, endIndent: 16),
          SettingsSection(
            title: 'Обход блокировок',
            icon: Icons.content_cut_rounded,
            subtitle: 'Фрагментация, маскировка трафика',
            namedLocation: context.namedLocation('tlsTricks'),
          ),
          SettingsSection(
            title: 'Cloudflare WARP',
            icon: Icons.cloud_rounded,
            subtitle: 'Дополнительный туннель шифрования',
            namedLocation: context.namedLocation('warpOptions'),
          ),
          if (PlatformUtils.isIOS)
            Material(
              child: ListTile(
                title: Text(t.pages.settings.resetTunnel),
                leading: const Icon(Icons.autorenew_rounded),
                onTap: () async {
                  await ref.read(resetTunnelNotifierProvider.notifier).run();
                },
              ),
            ),
          ListTile(
            leading: const Icon(Icons.bar_chart_rounded),
            title: const Text('Статистика'),
            subtitle: const Text('Использование трафика и скорость'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.goNamed('stats'),
          ),
          ListTile(
            leading: const Icon(Icons.bug_report_rounded),
            title: const Text('Сообщить о проблеме'),
            subtitle: const Text('Отправить отчёт разработчику'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.goNamed('reportProblem'),
          ),
          const Divider(height: 1),
          ListTile(
            leading: const Icon(Icons.restore_rounded, color: Colors.orange),
            title: const Text('Сбросить настройки'),
            subtitle: const Text('Вернуть все параметры к стандартным значениям'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () async {
              final confirmed = await showDialog<bool>(
                context: context,
                builder: (ctx) => AlertDialog(
                  title: const Text('Сбросить настройки?'),
                  content: const Text(
                    'Все параметры будут возвращены к стандартным значениям. '
                    'Это может помочь, если подключение перестало работать после '
                    'изменения настроек.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Отмена'),
                    ),
                    FilledButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Сбросить'),
                    ),
                  ],
                ),
              );
              if (confirmed == true) {
                await ref.read(configOptionNotifierProvider.notifier).resetOption();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Настройки сброшены. Переподключитесь.'),
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                }
              }
            },
          ),
          if (Breakpoint(context).isMobile()) ...[
            SettingsSection(
              title: t.pages.logs.title,
              icon: Icons.description_rounded,
              namedLocation: context.namedLocation('logs'),
            ),
            SettingsSection(
              title: t.pages.about.title,
              icon: Icons.info_rounded,
              namedLocation: context.namedLocation('about'),
            ),
          ],
        ],
      ),
    );
  }
}

class SettingsSection extends HookConsumerWidget {
  const SettingsSection({
    super.key,
    required this.title,
    required this.icon,
    required this.namedLocation,
    this.subtitle,
  });

  final String title;
  final IconData icon;
  final String namedLocation;
  final String? subtitle;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: subtitle != null ? Text(subtitle!) : null,
      trailing: const Icon(Icons.chevron_right_rounded),
      onTap: () => context.go(namedLocation),
    );
  }
}
