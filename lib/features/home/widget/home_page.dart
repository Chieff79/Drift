import 'package:circle_flags/circle_flags.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:go_router/go_router.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/notifier/real_ip_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'dart:math';
import 'package:hiddify/features/home/widget/globe_widget.dart';
import 'package:hiddify/features/profile/model/profile_entity.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/overview/profiles_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/data/config_option_repository.dart';
import 'package:hiddify/utils/uri_utils.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isConnected = connectionStatus.valueOrNull == const Connected();
    final isConnecting = connectionStatus.valueOrNull?.isSwitching ?? false;

    // Location data for the map
    final realIp = ref.watch(realIpNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    // Use ipInfoNotifier for REAL exit IP country (not intermediate proxy node)
    final vpnIpInfo = ref.watch(ipInfoNotifierProvider);
    final userCountryCode = realIp.valueOrNull?.countryCode;
    // Prefer real IP check country, fall back to proxy node country
    final vpnCountryCode = vpnIpInfo.valueOrNull?.countryCode
        ?? activeProxy.valueOrNull?.ipinfo.countryCode;

    // Globe rotation controlled from here so horizontal drag works with scroll
    final globeLat = useState(0.3);
    final globeLng = useState(0.2);

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/drift_logo.png', height: 24),
            const Gap(8),
            Text(t.common.appTitle),
          ],
        ),
        actions: [
          // ── Mini Telegram free toggle ──
          const _TelegramFreeChip(),
          const Gap(4),
          // ── Mini whitelist toggle ──
          const _WhitelistChip(),
          const Gap(4),
          // ── Profiles / keys drawer ──
          IconButton(
            icon: const Icon(Icons.key_rounded, size: 22),
            tooltip: 'Ключи',
            onPressed: () => _showProfilesDrawer(context, ref),
          ),
        ],
      ),
      body: GestureDetector(
        onHorizontalDragUpdate: (details) {
          // Horizontal swipe rotates the globe (doesn't conflict with vertical scroll)
          final screenW = MediaQuery.of(context).size.width;
          final r = min(screenW, MediaQuery.of(context).size.height) / 2 * 0.85;
          globeLng.value -= details.delta.dx * 1.2 / r;
        },
        child: Stack(
        children: [
          // ── Full-screen interactive 3D globe ────────────────
          Positioned.fill(
            child: GlobeWidget(
              isConnected: isConnected,
              isConnecting: isConnecting,
              userCountryCode: userCountryCode,
              vpnCountryCode: vpnCountryCode,
              viewLatNotifier: globeLat,
              viewLngNotifier: globeLng,
            ),
          ),

          // ── UI content on top of the globe ──────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  MultiSliver(
                    children: [
                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Gap(8),

                            // ── IP Status Card (always visible — shows real or protected IP) ──
                            _IpStatusCard(isConnected: isConnected),

                            const Spacer(),

                            // ── Country selector button ────────────────────
                            _CountrySelector(
                              vpnCountryCode: vpnCountryCode,
                              onTap: () => context.goNamed('countrySelection'),
                            ),

                            const Gap(16),

                            // ── Connection button ───────────────────────────
                            const ConnectionButton(),

                            const Gap(24),

                            // ── City A → City B row ────────────────────────
                            if (isConnected) const _CityRouteRow(),

                            const Gap(8),
                          ],
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
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  IP STATUS CARD
// ══════════════════════════════════════════════════════════════════════════════

class _IpStatusCard extends ConsumerWidget {
  const _IpStatusCard({required this.isConnected});

  final bool isConnected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final isConnecting = connectionStatus.valueOrNull?.isSwitching ?? false;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: AnimatedSwitcher(
        duration: const Duration(milliseconds: 400),
        transitionBuilder: (child, animation) => FadeTransition(
          opacity: animation,
          child: SlideTransition(
            position: Tween<Offset>(begin: const Offset(0, 0.1), end: Offset.zero).animate(animation),
            child: child,
          ),
        ),
        child: isConnected
            ? _ConnectedIpCard(key: const ValueKey('connected'))
            : _DisconnectedIpCard(key: const ValueKey('disconnected'), isConnecting: isConnecting),
      ),
    );
  }
}

// ── Before connection: shows real IP ─────────────────────────────────────────────────

class _DisconnectedIpCard extends ConsumerWidget {
  const _DisconnectedIpCard({super.key, required this.isConnecting});

  final bool isConnecting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final realIp = ref.watch(realIpNotifierProvider);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: theme.colorScheme.surfaceContainer,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: theme.colorScheme.outline.withValues(alpha: .15)),
        boxShadow: [
          BoxShadow(
            color: theme.colorScheme.shadow.withValues(alpha: .06),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          // Country flag
          _IpFlag(
            countryCode: realIp.valueOrNull?.countryCode,
            size: 44,
            loading: realIp.isLoading,
          ),

          const Gap(14),

          // IP details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isConnecting ? 'Подключение...' : 'Ваш IP',
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: .55),
                    letterSpacing: 0.5,
                  ),
                ),
                const Gap(2),
                switch (realIp) {
                  AsyncLoading() => _ShimmerText(width: 120),
                  AsyncData(value: final info?) => Text(
                    info.ip,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      letterSpacing: 0.3,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                  _ => Text(
                    '—',
                    style: theme.textTheme.titleMedium?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .4),
                    ),
                  ),
                },
              ],
            ),
          ),

          // Refresh / status icon
          GestureDetector(
            onTap: () => ref.read(realIpNotifierProvider.notifier).refresh(),
            child: Icon(
              Icons.refresh_rounded,
              size: 20,
              color: theme.colorScheme.primary.withValues(alpha: .7),
            ),
          ),
        ],
      ),
    );
  }
}

// ── After connection: shows protected IP ───────────────────────────────────────────────────

class _ConnectedIpCard extends ConsumerWidget {
  const _ConnectedIpCard({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    // Use real IP info (from ipapi.co etc.) for accurate exit country
    final vpnIpInfo = ref.watch(ipInfoNotifierProvider);

    // Prefer real IP check data, fall back to proxy node data
    final vpnIp = vpnIpInfo.valueOrNull?.ip
        ?? activeProxy.valueOrNull?.ipinfo.ip ?? '';
    final countryCode = vpnIpInfo.valueOrNull?.countryCode
        ?? activeProxy.valueOrNull?.ipinfo.countryCode ?? '';
    // Protocol info hidden for clean UI

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            const Color(0xFF1A4A9B).withValues(alpha: .15),
            const Color(0xFF30D158).withValues(alpha: .08),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: const Color(0xFF30D158).withValues(alpha: .3)),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF30D158).withValues(alpha: .1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        children: [
          _IpFlag(
                countryCode: countryCode.isEmpty ? null : countryCode,
                size: 44,
                loading: activeProxy.isLoading,
              ),

          const Gap(14),

          // Protected IP details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'Защищённый IP',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: const Color(0xFF30D158),
                        letterSpacing: 0.5,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const Gap(6),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                      decoration: BoxDecoration(
                        color: const Color(0xFF30D158).withValues(alpha: .15),
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Защищено',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: const Color(0xFF30D158),
                          fontSize: 10,
                        ),
                      ),
                    ),
                  ],
                ),
                const Gap(2),
                vpnIp.isNotEmpty
                    ? Text(
                        vpnIp,
                        style: theme.textTheme.titleMedium?.copyWith(
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                        textDirection: TextDirection.ltr,
                      )
                    : _ShimmerText(width: 120),
              ],
            ),
          ),

          Icon(
            Icons.shield_rounded,
            size: 20,
            color: const Color(0xFF30D158).withValues(alpha: .8),
          ),
        ],
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  CITY A → CITY B ROW
// ══════════════════════════════════════════════════════════════════════════════

class _CityRouteRow extends ConsumerWidget {
  const _CityRouteRow();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final realIp = ref.watch(realIpNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final vpnIpInfo = ref.watch(ipInfoNotifierProvider);

    final fromCountry = realIp.valueOrNull?.countryCode ?? '';
    // Prefer real exit IP country over proxy node country
    final toCountry = vpnIpInfo.valueOrNull?.countryCode
        ?? activeProxy.valueOrNull?.ipinfo.countryCode ?? '';

    if (fromCountry.isEmpty && toCountry.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // From location
          _LocationChip(
            countryCode: fromCountry,
            label: _countryName(fromCountry),
            isSource: true,
          ),

          // Arrow with animated dots
          Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  _animatedDot(theme, 0),
                  const Gap(4),
                  Icon(
                    Icons.arrow_forward_rounded,
                    size: 18,
                    color: theme.colorScheme.primary,
                  ),
                  const Gap(4),
                  _animatedDot(theme, 1),
                ],
              ),
            ),
          ),

          // To location (VPN)
          _LocationChip(
            countryCode: toCountry,
            label: _countryName(toCountry),
            isSource: false,
          ),
        ],
      ),
    );
  }

  Widget _animatedDot(ThemeData theme, int index) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.3, end: 1.0),
      duration: Duration(milliseconds: 800 + index * 200),
      builder: (context, value, child) => Opacity(
        opacity: value,
        child: Container(
          width: 4,
          height: 4,
          decoration: BoxDecoration(
            color: theme.colorScheme.primary,
            shape: BoxShape.circle,
          ),
        ),
      ),
    );
  }

  String _countryName(String code) {
    const names = {
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
    };
    return names[code.toUpperCase()] ?? code;
  }
}

class _LocationChip extends StatelessWidget {
  const _LocationChip({
    required this.countryCode,
    required this.label,
    required this.isSource,
  });

  final String countryCode;
  final String label;
  final bool isSource;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Column(
      children: [
        if (countryCode.isNotEmpty)
          SizedBox(
            width: 32,
            height: 32,
            child: CircleFlag(
              countryCode.toLowerCase(),
              size: 24,
            ),
          )
        else
          Icon(
            isSource ? Icons.person_pin_circle_outlined : Icons.shield_rounded,
            size: 28,
            color: isSource ? theme.colorScheme.onSurface.withValues(alpha: .4) : theme.colorScheme.primary,
          ),
        const Gap(4),
        Text(
          label.isNotEmpty ? label : (isSource ? 'Вы' : 'Drift'),
          style: theme.textTheme.labelSmall?.copyWith(
            color: isSource
                ? theme.colorScheme.onSurface.withValues(alpha: .6)
                : theme.colorScheme.primary,
            fontWeight: isSource ? FontWeight.normal : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  HELPERS
// ══════════════════════════════════════════════════════════════════════════════

class _IpFlag extends StatelessWidget {
  const _IpFlag({this.countryCode, required this.size, this.loading = false});

  final String? countryCode;
  final double size;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    if (loading) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: .08),
          shape: BoxShape.circle,
        ),
      );
    }
    if (countryCode == null || countryCode!.isEmpty) {
      return Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: theme.colorScheme.onSurface.withValues(alpha: .08),
          shape: BoxShape.circle,
        ),
        child: Icon(
          Icons.public_outlined,
          size: size * 0.55,
          color: theme.colorScheme.onSurface.withValues(alpha: .4),
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: CircleFlag(countryCode!.toLowerCase(), size: size),
    );
  }
}

class _ShimmerText extends StatelessWidget {
  const _ShimmerText({required this.width});

  final double width;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      width: width,
      height: 18,
      decoration: BoxDecoration(
        color: theme.colorScheme.onSurface.withValues(alpha: .1),
        borderRadius: BorderRadius.circular(4),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  COUNTRY SELECTOR (tap to choose server country)
// ══════════════════════════════════════════════════════════════════════════════

class _CountrySelector extends StatelessWidget {
  const _CountrySelector({this.vpnCountryCode, required this.onTap});

  final String? vpnCountryCode;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final code = vpnCountryCode ?? '';
    final name = _countryName(code);

    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: BoxDecoration(
          color: theme.colorScheme.surfaceContainer.withValues(alpha: 0.9),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: theme.colorScheme.outline.withValues(alpha: .2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (code.isNotEmpty)
              SizedBox(
                width: 28,
                height: 28,
                child: CircleFlag(code.toLowerCase(), size: 28),
              )
            else
              Icon(
                Icons.public_rounded,
                size: 28,
                color: theme.colorScheme.primary,
              ),
            const Gap(10),
            Text(
              name.isNotEmpty ? name : 'Выбрать страну',
              style: theme.textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w600,
              ),
            ),
            const Gap(6),
            Icon(
              Icons.expand_more_rounded,
              size: 20,
              color: theme.colorScheme.onSurface.withValues(alpha: .5),
            ),
          ],
        ),
      ),
    );
  }

  String _countryName(String code) {
    const names = {
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
    };
    return names[code.toUpperCase()] ?? '';
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  TELEGRAM FREE TOGGLE (AppBar chip)
// ══════════════════════════════════════════════════════════════════════════════

/// One-tap toggle that activates the free "Telegram Free" VPN profile.
/// When enabled: adds/finds the Telegram Free profile, selects it, connects.
/// When disabled: disconnects VPN.
class _TelegramFreeChip extends StatelessWidget {
  const _TelegramFreeChip();

  /// MTProto proxy on RU relay — accessible from Russia directly
  static const _proxyUrl =
      'tg://proxy?server=72.56.238.148&port=3128&secret=ee8363d3edf5689818e06be38f4619f8ad74672e636f6d';

  @override
  Widget build(BuildContext context) {
    const tgColor = Color(0xFF2AABEE); // Telegram blue

    return GestureDetector(
      onTap: () => _openProxy(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: tgColor.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: tgColor.withValues(alpha: 0.4)),
        ),
        child: const Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.send_rounded, size: 13, color: tgColor),
            Gap(4),
            Text(
              'Telegram',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: tgColor,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _openProxy(BuildContext context) async {
    final uri = Uri.parse(_proxyUrl);
    final launched = await UriUtils.tryLaunch(uri);
    if (!launched && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Установите Telegram для добавления прокси')),
      );
    }
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  WHITELIST MINI TOGGLE (AppBar chip)
// ══════════════════════════════════════════════════════════════════════════════

class _WhitelistChip extends ConsumerWidget {
  const _WhitelistChip();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(ConfigOptions.enableRuWhitelist);
    final theme = Theme.of(context);

    return GestureDetector(
      onTap: () => ref.read(ConfigOptions.enableRuWhitelist.notifier).update(!enabled),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 250),
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        decoration: BoxDecoration(
          color: enabled
              ? const Color(0xFF30D158).withValues(alpha: 0.15)
              : theme.colorScheme.surfaceContainerHighest.withValues(alpha: 0.5),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: enabled
                ? const Color(0xFF30D158).withValues(alpha: 0.4)
                : theme.colorScheme.outline.withValues(alpha: 0.2),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              enabled ? Icons.shield_rounded : Icons.shield_outlined,
              size: 14,
              color: enabled ? const Color(0xFF30D158) : theme.colorScheme.onSurface.withValues(alpha: 0.5),
            ),
            const Gap(4),
            Text(
              ref.watch(translationsProvider).requireValue.pages.home.whitelist.badge,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: enabled ? const Color(0xFF30D158) : theme.colorScheme.onSurface.withValues(alpha: 0.5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ══════════════════════════════════════════════════════════════════════════════
//  PROFILES DRAWER (slide-up menu with keys)
// ══════════════════════════════════════════════════════════════════════════════

void _showProfilesDrawer(BuildContext context, WidgetRef ref) {
  showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) => const _ProfilesSheet(),
  );
}

class _ProfilesSheet extends ConsumerWidget {
  const _ProfilesSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final ak = t.pages.home.accessKeys;
    final profiles = ref.watch(profilesNotifierProvider);
    final activeProfile = ref.watch(activeProfileProvider);

    return DraggableScrollableSheet(
      initialChildSize: 0.45,
      minChildSize: 0.3,
      maxChildSize: 0.8,
      builder: (context, scrollController) => Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.surface,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            // ── Handle bar ──
            Padding(
              padding: const EdgeInsets.only(top: 12, bottom: 8),
              child: Container(
                width: 40, height: 4,
                decoration: BoxDecoration(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            // ── Header ──
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.key_rounded, size: 20, color: theme.colorScheme.primary),
                  const Gap(10),
                  Text(ak.title, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700)),
                  const Spacer(),
                  // Add key button
                  IconButton(
                    icon: Icon(Icons.add_circle_outline_rounded, color: theme.colorScheme.primary),
                    tooltip: ak.addKey,
                    onPressed: () {
                      Navigator.of(context).pop();
                      ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
                    },
                  ),
                  // Refresh all button
                  IconButton(
                    icon: Icon(Icons.refresh_rounded, color: theme.colorScheme.primary),
                    tooltip: ak.refreshAll,
                    onPressed: () {
                      ref.invalidate(profilesNotifierProvider);
                    },
                  ),
                ],
              ),
            ),
            const Divider(height: 1),
            // ── Profile list ──
            Expanded(
              child: profiles.when(
                data: (list) {
                  if (list.isEmpty) {
                    return Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(Icons.vpn_key_off_rounded, size: 48, color: theme.colorScheme.onSurface.withValues(alpha: 0.2)),
                          const Gap(12),
                          Text(ak.empty, style: theme.textTheme.bodyLarge?.copyWith(color: theme.colorScheme.onSurface.withValues(alpha: 0.5))),
                          const Gap(8),
                          TextButton.icon(
                            icon: const Icon(Icons.add_link_rounded),
                            label: Text(ak.addSubscription),
                            onPressed: () {
                              Navigator.of(context).pop();
                              ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
                            },
                          ),
                        ],
                      ),
                    );
                  }

                  final activeId = activeProfile.valueOrNull?.id;

                  return ListView.builder(
                    controller: scrollController,
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: list.length,
                    itemBuilder: (context, index) {
                      final profile = list[index];
                      final isActive = profile.id == activeId;

                      return Dismissible(
                        key: ValueKey(profile.id),
                        direction: DismissDirection.endToStart,
                        confirmDismiss: (_) async {
                          return await showDialog<bool>(
                            context: context,
                            builder: (ctx) => AlertDialog(
                              title: Text(ak.deleteTitle),
                              content: Text(ak.deleteConfirm(name: profile.name)),
                              actions: [
                                TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
                                TextButton(
                                  onPressed: () => Navigator.pop(ctx, true),
                                  child: Text(t.common.delete, style: TextStyle(color: theme.colorScheme.error)),
                                ),
                              ],
                            ),
                          ) ?? false;
                        },
                        onDismissed: (_) {
                          ref.read(profilesNotifierProvider.notifier).deleteProfile(profile);
                        },
                        background: Container(
                          alignment: Alignment.centerRight,
                          padding: const EdgeInsets.only(right: 24),
                          margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.error.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(Icons.delete_outline_rounded, color: theme.colorScheme.error),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
                          child: Material(
                            color: isActive
                                ? theme.colorScheme.primaryContainer.withValues(alpha: 0.5)
                                : theme.colorScheme.surfaceContainer,
                            borderRadius: BorderRadius.circular(14),
                            child: InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () async {
                                await ref.read(profilesNotifierProvider.notifier).selectActiveProfile(profile.id);
                                if (context.mounted) Navigator.of(context).pop();
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  children: [
                                    // Active indicator
                                    Container(
                                      width: 8, height: 8,
                                      decoration: BoxDecoration(
                                        color: isActive ? const Color(0xFF30D158) : Colors.transparent,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: isActive
                                              ? const Color(0xFF30D158)
                                              : theme.colorScheme.outline.withValues(alpha: 0.3),
                                          width: 1.5,
                                        ),
                                      ),
                                    ),
                                    const Gap(12),
                                    // Profile info
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            profile.name,
                                            style: theme.textTheme.bodyMedium?.copyWith(
                                              fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                                            ),
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                          if (profile is RemoteProfileEntity) ...[
                                            const Gap(2),
                                            Text(
                                              _formatLastUpdate(profile.lastUpdate, ak),
                                              style: theme.textTheme.labelSmall?.copyWith(
                                                color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                    ),
                                    // Rename button
                                    IconButton(
                                      icon: Icon(Icons.edit_outlined, size: 18,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final controller = TextEditingController(text: profile.name);
                                        final newName = await showDialog<String>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(ak.renameTitle),
                                            content: TextField(
                                              controller: controller,
                                              autofocus: true,
                                              decoration: InputDecoration(
                                                labelText: ak.nameLabel,
                                                border: const OutlineInputBorder(),
                                              ),
                                              onSubmitted: (v) => Navigator.pop(ctx, v.trim()),
                                            ),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx), child: Text(t.common.cancel)),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, controller.text.trim()),
                                                child: Text(t.common.save),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (newName != null && newName.isNotEmpty && newName != profile.name) {
                                          await ref.read(profilesNotifierProvider.notifier).renameProfile(profile.id, newName);
                                        }
                                      },
                                    ),
                                    // Delete button
                                    IconButton(
                                      icon: Icon(Icons.delete_outline_rounded, size: 18,
                                        color: theme.colorScheme.onSurface.withValues(alpha: 0.3)),
                                      constraints: const BoxConstraints(minWidth: 32, minHeight: 32),
                                      padding: EdgeInsets.zero,
                                      onPressed: () async {
                                        final confirm = await showDialog<bool>(
                                          context: context,
                                          builder: (ctx) => AlertDialog(
                                            title: Text(ak.deleteTitle),
                                            content: Text(ak.deleteConfirm(name: profile.name)),
                                            actions: [
                                              TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text(t.common.cancel)),
                                              TextButton(
                                                onPressed: () => Navigator.pop(ctx, true),
                                                child: Text(t.common.delete, style: TextStyle(color: theme.colorScheme.error)),
                                              ),
                                            ],
                                          ),
                                        );
                                        if (confirm == true) {
                                          await ref.read(profilesNotifierProvider.notifier).deleteProfile(profile);
                                        }
                                      },
                                    ),
                                    // Check icon
                                    if (isActive)
                                      Icon(Icons.check_circle_rounded, color: const Color(0xFF30D158), size: 20),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
                error: (e, _) => Center(child: Text(ak.errorLoading)),
                loading: () => const Center(child: CircularProgressIndicator()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _formatLastUpdate(DateTime dt, TranslationsPagesHomeAccessKeysEn ak) {
    final diff = DateTime.now().difference(dt);
    if (diff.inMinutes < 1) return ak.justNow;
    if (diff.inMinutes < 60) return ak.minutesAgo(n: diff.inMinutes);
    if (diff.inHours < 24) return ak.hoursAgo(n: diff.inHours);
    return ak.daysAgo(n: diff.inDays);
  }
}

