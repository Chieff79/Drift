import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:gap/gap.dart';
import 'package:hiddify/core/localization/translations.dart';
import 'package:hiddify/core/router/bottom_sheets/bottom_sheets_notifier.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/core/widget/animated_text.dart';
import 'package:hiddify/features/connection/model/connection_status.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/profile/notifier/active_profile_notifier.dart';
import 'package:hiddify/features/proxy/active/active_proxy_notifier.dart';
import 'package:hiddify/features/settings/notifier/config_option/config_option_notifier.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ConnectionButton extends HookConsumerWidget {
  const ConnectionButton({super.key});

  static const _idleColor = Color(0xFF1A4A9B);
  static const _connectingColor = Color(0xFFB9A847);
  static const _connectedColor = Color(0xFF30D158);
  static const _reconnectColor = Color(0xFF26A69A);
  static const _errorColor = Color(0xFFE53935);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(translationsProvider).requireValue;
    final connectionStatus = ref.watch(connectionNotifierProvider);
    final activeProxy = ref.watch(activeProxyNotifierProvider);
    final delay = activeProxy.valueOrNull?.urlTestDelay ?? 0;
    final requiresReconnect = ref.watch(configOptionNotifierProvider).valueOrNull;

    final isConnecting = connectionStatus.valueOrNull is Connecting ||
        (connectionStatus.valueOrNull is Connected && (delay <= 0 || delay >= 65000));

    final elapsedSeconds = useState(0);
    final timerRef = useRef<Timer?>(null);

    useEffect(() {
      if (isConnecting) {
        elapsedSeconds.value = 0;
        timerRef.value = Timer.periodic(const Duration(seconds: 1), (_) {
          elapsedSeconds.value++;
        });
      } else {
        timerRef.value?.cancel();
        timerRef.value = null;
        elapsedSeconds.value = 0;
      }
      return () => timerRef.value?.cancel();
    }, [isConnecting]);

    final buttonColor = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => _reconnectColor,
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => _connectingColor,
      AsyncData(value: Connected()) => _connectedColor,
      AsyncData(value: Connecting()) => _connectingColor,
      AsyncData(value: Disconnecting()) => _connectingColor,
      AsyncData(value: Disconnected()) => _idleColor,
      AsyncError() => _errorColor,
      _ => _idleColor,
    };

    final isConnected = connectionStatus.valueOrNull == const Connected();

    final connectingLabel = '${t.connection.connecting} ${elapsedSeconds.value}с';

    final label = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => t.connection.reconnect,
      AsyncData(value: Connected()) when delay <= 0 || delay >= 65000 => connectingLabel,
      AsyncData(value: Connecting()) => connectingLabel,
      AsyncData(value: final status) => status.present(t),
      _ => "",
    };

    final onTap = switch (connectionStatus) {
      AsyncData(value: Connected()) when requiresReconnect == true => () async {
        final activeProfile = await ref.read(activeProfileProvider.future);
        return await ref.read(connectionNotifierProvider.notifier).reconnect(activeProfile);
      },
      AsyncData(value: Disconnected()) || AsyncError() => () async {
        if (ref.read(activeProfileProvider).valueOrNull == null) {
          await ref.read(dialogNotifierProvider.notifier).showNoActiveProfile();
          ref.read(bottomSheetsNotifierProvider.notifier).showAddProfile();
        }
        if (await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
          return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
        }
      },
      AsyncData(value: Connected()) => () async {
        if (requiresReconnect == true &&
            await ref.read(dialogNotifierProvider.notifier).showExperimentalFeatureNotice()) {
          return await ref
              .read(connectionNotifierProvider.notifier)
              .reconnect(await ref.read(activeProfileProvider.future));
        }
        return await ref.read(connectionNotifierProvider.notifier).toggleConnection();
      },
      _ => () {},
    };

    final enabled = switch (connectionStatus) {
      AsyncData(value: Connected()) || AsyncData(value: Disconnected()) || AsyncError() => true,
      _ => false,
    };

    return _DriftConnectionButton(
      onTap: onTap,
      enabled: enabled,
      label: label,
      buttonColor: buttonColor,
      isConnected: isConnected,
    );
  }
}

class _DriftConnectionButton extends StatelessWidget {
  const _DriftConnectionButton({
    required this.onTap,
    required this.enabled,
    required this.label,
    required this.buttonColor,
    required this.isConnected,
  });

  final VoidCallback onTap;
  final bool enabled;
  final String label;
  final Color buttonColor;
  final bool isConnected;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Semantics(
          button: true,
          enabled: enabled,
          label: label,
          child: TweenAnimationBuilder<Color?>(
            tween: ColorTween(end: buttonColor),
            duration: const Duration(milliseconds: 350),
            builder: (context, color, _) {
              final c = color ?? buttonColor;
              return Container(
                width: 148,
                height: 148,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      blurRadius: 24,
                      spreadRadius: 2,
                      color: c.withValues(alpha: .35),
                    ),
                  ],
                ),
                child: Material(
                  key: const ValueKey("home_connection_button"),
                  shape: CircleBorder(
                    side: BorderSide(
                      color: c.withValues(alpha: .3),
                      width: 3,
                    ),
                  ),
                  color: c.withValues(alpha: .12),
                  child: InkWell(
                    customBorder: const CircleBorder(),
                    onTap: onTap,
                    child: Center(
                      child: Icon(
                        isConnected ? Icons.power_settings_new_rounded : Icons.power_settings_new_rounded,
                        size: 56,
                        color: c,
                      ),
                    ),
                  ),
                ),
              );
            },
          ).animate(target: enabled ? 0 : 1).blurXY(end: 1).scaleXY(end: .88, curve: Curves.easeIn),
        ),
        const Gap(16),
        ExcludeSemantics(
          child: AnimatedText(
            label,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ),
      ],
    );
  }
}
