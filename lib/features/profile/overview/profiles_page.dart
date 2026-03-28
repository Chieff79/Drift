import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/model/failures.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/profile/notifier/profiles_update_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProfilesPage extends HookConsumerWidget {
  const ProfilesPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final asyncProfiles = ref.watch(profilesNotifierProvider);

    ref.listen(profilesNotifierProvider, (_, next) {
      if (next.hasValue && next.value!.isEmpty) {
        context.goNamed('home');
      }
    });

    return Scaffold(
      appBar: AppBar(
        title: Text(t.pages.profiles.title),
        actions: [
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'update':
                  ref.read(foregroundProfilesUpdateNotifierProvider.notifier).trigger();
                case 'sort':
                  ref.read(dialogNotifierProvider.notifier).showSortProfiles();
              }
            },
            itemBuilder: (context) => [
              PopupMenuItem(
                value: 'update',
                child: ListTile(
                  leading: const Icon(Icons.update_rounded),
                  title: Text(t.pages.profiles.updateSubscriptions),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              PopupMenuItem(
                value: 'sort',
                child: ListTile(
                  leading: const Icon(Icons.sort_rounded),
                  title: Text(t.common.sort),
                  dense: true,
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
          const Gap(8),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async => await ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
        label: Text(t.pages.profiles.add),
        icon: const Icon(Icons.add_rounded),
      ),
      body: asyncProfiles.when(
        data: (data) => ListView.separated(
          padding: const EdgeInsets.all(12).copyWith(bottom: 84),
          separatorBuilder: (context, index) => const Gap(12),
          itemBuilder: (context, index) => ProfileTile(profile: data[index]),
          itemCount: data.length,
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (error, stackTrace) => Text(t.presentShortError(error)),
      ),
    );
  }
}
