import 'package:flutter/material.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ReportProblemPage extends HookConsumerWidget {
  const ReportProblemPage({super.key});

  static const _categories = [
    'Не подключается',
    'Низкая скорость',
    'Обрывы соединения',
    'Приложение зависает',
    'Другое',
  ];

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final descriptionController = useTextEditingController();
    final selectedCategory = useState<String>(_categories.first);
    final isSending = useState(false);

    final appInfo = ref.watch(appInfoProvider);
    final connectionStatus = ref.watch(connectionNotifierProvider);

    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Сообщить о проблеме')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // Category dropdown
          Text(
            'Категория проблемы',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          DropdownButtonFormField<String>(
            value: selectedCategory.value,
            decoration: const InputDecoration(
              border: OutlineInputBorder(),
              contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 14),
            ),
            items: _categories
                .map((cat) => DropdownMenuItem(value: cat, child: Text(cat)))
                .toList(),
            onChanged: (value) {
              if (value != null) selectedCategory.value = value;
            },
          ),
          const Gap(20),

          // Description field
          Text(
            'Описание проблемы',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          TextField(
            controller: descriptionController,
            maxLines: 6,
            decoration: const InputDecoration(
              hintText: 'Опишите проблему...',
              border: OutlineInputBorder(),
              alignLabelWithHint: true,
            ),
          ),
          const Gap(20),

          // Device info card (auto-collected)
          Text(
            'Информация об устройстве',
            style: theme.textTheme.titleSmall?.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const Gap(8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _InfoRow(
                    icon: Icons.phone_android_rounded,
                    label: 'Платформа',
                    value: appInfo.when(
                      data: (info) => '${info.operatingSystem} ${info.operatingSystemVersion}',
                      loading: () => '...',
                      error: (_, __) => 'Неизвестно',
                    ),
                  ),
                  const Gap(8),
                  _InfoRow(
                    icon: Icons.info_outline_rounded,
                    label: 'Версия приложения',
                    value: appInfo.when(
                      data: (info) => 'v${info.version} (${info.buildNumber})',
                      loading: () => '...',
                      error: (_, __) => 'Неизвестно',
                    ),
                  ),
                  const Gap(8),
                  _InfoRow(
                    icon: Icons.wifi_rounded,
                    label: 'Статус VPN',
                    value: connectionStatus.when(
                      data: (status) => status.isConnected
                          ? 'Подключено'
                          : status.isSwitching
                              ? 'Подключение...'
                              : 'Отключено',
                      loading: () => '...',
                      error: (_, __) => 'Ошибка',
                    ),
                  ),
                ],
              ),
            ),
          ),
          const Gap(12),

          // Logs link
          ListTile(
            leading: const Icon(Icons.description_rounded),
            title: const Text('Просмотреть логи'),
            subtitle: const Text('Открыть страницу логов приложения'),
            trailing: const Icon(Icons.chevron_right_rounded),
            onTap: () => context.goNamed('logs'),
          ),
          const Gap(20),

          // Send button
          FilledButton.icon(
            onPressed: isSending.value
                ? null
                : () {
                    if (descriptionController.text.trim().isEmpty) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Пожалуйста, опишите проблему'),
                        ),
                      );
                      return;
                    }
                    isSending.value = true;
                    // Simulate sending
                    Future.delayed(const Duration(milliseconds: 800), () {
                      isSending.value = false;
                      descriptionController.clear();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Отчёт отправлен. Спасибо!'),
                        ),
                      );
                    });
                  },
            icon: isSending.value
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.send_rounded),
            label: const Text('Отправить'),
          ),
        ],
      ),
    );
  }
}

class _InfoRow extends StatelessWidget {
  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Row(
      children: [
        Icon(icon, size: 18, color: theme.colorScheme.onSurfaceVariant),
        const Gap(8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurfaceVariant,
          ),
        ),
        Expanded(
          child: Text(
            value,
            style: theme.textTheme.bodySmall?.copyWith(
              fontWeight: FontWeight.w600,
            ),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}
