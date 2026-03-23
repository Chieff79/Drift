import 'package:circle_flags/circle_flags.dart';
import 'package:dartx/dartx.dart';
import 'package:flutter/material.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/app_info/app_info_provider.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/home/notifier/real_ip_notifier.dart';
import 'package:hiddify/features/home/widget/connection_button.dart';
import 'package:hiddify/features/home/widget/globe_widget.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/profile/widget/profile_tile.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:sliver_tools/sliver_tools.dart';

class HomePage extends HookConsumerWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final t = ref.watch(translationsProvider).requireValue;
    final activeProfile = ref.watch(activeProfileProvider);
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

    return Scaffold(
      appBar: AppBar(
        title: Row(
          children: [
            Image.asset('assets/images/drift_logo.png', height: 24),
            const Gap(8),
            Text.rich(
              TextSpan(
                children: [
                  TextSpan(text: t.common.appTitle),
                  const TextSpan(text: ' '),
                  const WidgetSpan(child: AppVersionLabel(), alignment: PlaceholderAlignment.middle),
                ],
              ),
            ),
          ],
        ),
        actions: [
          Semantics(
            key: const ValueKey('profile_quick_settings'),
            label: t.pages.home.quickSettings,
            child: IconButton(
              icon: Icon(Icons.tune_rounded, color: theme.colorScheme.primary),
              onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showQuickSettings(),
            ),
          ),
          const Gap(8),
          Semantics(
            key: const ValueKey('profile_add_button'),
            label: t.pages.profiles.add,
            child: IconButton(
              icon: Icon(Icons.add_rounded, color: theme.colorScheme.primary),
              onPressed: () => ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile(),
            ),
          ),
          const Gap(8),
        ],
      ),
      body: Stack(
        children: [
          // ── Full-screen interactive map background ─────────────
          Positioned.fill(
            child: GlobeWidget(
              isConnected: isConnected,
              isConnecting: isConnecting,
              userCountryCode: userCountryCode,
              vpnCountryCode: vpnCountryCode,
            ),
          ),

          // ── UI content on top of the map ──────────────────────
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: CustomScrollView(
                slivers: [
                  MultiSliver(
                    children: [
                      // Profile tile at top
                      switch (activeProfile) {
                        AsyncData(value: final profile?) => ProfileTile(
                          profile: profile,
                          isMain: true,
                          margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                          color: theme.colorScheme.surfaceContainer,
                        ),
                        _ => const Text(''),
                      },

                      SliverFillRemaining(
                        hasScrollBody: false,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Gap(8),

                            // ── IP Status Card (disconnected only — shows real IP) ──
                            if (!isConnected) _IpStatusCard(isConnected: false),

                            const Spacer(),

                            // ── Connection button ───────────────────────────
                            const ConnectionButton(),

                            const Gap(24),

                            // ── City A → City B row ────────────────────────
                            if (isConnected) const _CityRouteRow(),

                            const Gap(12),

                            // ── VPN IP (compact, at bottom) ─────────────────
                            if (isConnected) const _CompactVpnIpBar(),

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

// ── BEFORE VPN: shows real IP ─────────────────────────────────────────────────

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
                if (realIp.valueOrNull?.org != null) ...[
                  const Gap(2),
                  Text(
                    realIp.value!.org!,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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

// ── AFTER VPN: shows VPN IP ───────────────────────────────────────────────────

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
    final org = vpnIpInfo.valueOrNull?.org
        ?? activeProxy.valueOrNull?.ipinfo.org ?? '';
    final tagDisplay = activeProxy.valueOrNull?.tagDisplay ?? '';

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

          // VPN IP details
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      'VPN IP',
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
                if (tagDisplay.isNotEmpty || org.isNotEmpty) ...[
                  const Gap(2),
                  Text(
                    [if (tagDisplay.isNotEmpty) tagDisplay, if (org.isNotEmpty) org].join(' · '),
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: .5),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
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
            isSource ? Icons.person_pin_circle_outlined : Icons.vpn_lock_rounded,
            size: 28,
            color: isSource ? theme.colorScheme.onSurface.withValues(alpha: .4) : theme.colorScheme.primary,
          ),
        const Gap(4),
        Text(
          label.isNotEmpty ? label : (isSource ? 'Вы' : 'VPN'),
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
//  COMPACT VPN IP BAR (bottom)
// ══════════════════════════════════════════════════════════════════════════════

class _CompactVpnIpBar extends ConsumerWidget {
  const _CompactVpnIpBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final vpnIpInfo = ref.watch(ipInfoNotifierProvider);

    final vpnIp = vpnIpInfo.valueOrNull?.ip
        ?? activeProxy.valueOrNull?.ipinfo.ip ?? '';
    final countryCode = vpnIpInfo.valueOrNull?.countryCode
        ?? activeProxy.valueOrNull?.ipinfo.countryCode ?? '';
    final tagDisplay = activeProxy.valueOrNull?.tagDisplay ?? '';

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: const Color(0xFF30D158).withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: const Color(0xFF30D158).withValues(alpha: 0.2)),
        ),
        child: Row(
          children: [
            Icon(Icons.shield_rounded, size: 14,
                color: const Color(0xFF30D158).withValues(alpha: 0.7)),
            const Gap(6),
            Text(
              'VPN IP',
              style: theme.textTheme.labelSmall?.copyWith(
                color: const Color(0xFF30D158),
                fontWeight: FontWeight.w600,
                fontSize: 10,
              ),
            ),
            const Gap(8),
            if (countryCode.isNotEmpty) ...[
              SizedBox(
                width: 16, height: 16,
                child: CircleFlag(countryCode.toLowerCase(), size: 16),
              ),
              const Gap(6),
            ],
            Expanded(
              child: Text(
                vpnIp.isNotEmpty ? vpnIp : '—',
                style: theme.textTheme.bodySmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  letterSpacing: 0.2,
                ),
                textDirection: TextDirection.ltr,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            if (tagDisplay.isNotEmpty) ...[
              const Gap(6),
              Text(
                tagDisplay,
                style: theme.textTheme.labelSmall?.copyWith(
                  color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  fontSize: 9,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ],
        ),
      ),
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
//  APP VERSION LABEL (unchanged from original)
// ══════════════════════════════════════════════════════════════════════════════

class AppVersionLabel extends HookConsumerWidget {
  const AppVersionLabel({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final theme = Theme.of(context);
    final version = ref.watch(appInfoProvider).requireValue.presentVersion;
    if (version.isBlank) return const SizedBox();

    return Semantics(
      label: t.common.version,
      button: false,
      child: Container(
        decoration: BoxDecoration(
          color: theme.colorScheme.secondaryContainer,
          borderRadius: BorderRadius.circular(4),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 1),
        child: Text(
          version,
          textDirection: TextDirection.ltr,
          style: theme.textTheme.bodySmall?.copyWith(color: theme.colorScheme.onSecondaryContainer),
        ),
      ),
    );
  }
}
