import 'package:flutter/material.dart';
import 'package:hiddify/core/router/dialog/dialog_notifier.dart';
import 'package:hiddify/features/proxy/active/ip_widget.dart';
import 'package:hiddify/gen/fonts.gen.dart';
import 'package:hiddify/hiddifycore/generated/v2/hcore/hcore.pb.dart';
import 'package:hiddify/utils/custom_loggers.dart';
import 'package:hiddify/utils/platform_utils.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';

class ProxyTile extends HookConsumerWidget with PresLogger {
  const ProxyTile(this.proxy, {super.key, required this.selected, required this.onTap});

  final OutboundInfo proxy;
  final bool selected;
  final GestureTapCallback? onTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final theme = Theme.of(context);

    return ListTile(
      // shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      title: Text(
        proxy.tagDisplay,
        overflow: TextOverflow.ellipsis,
        style: PlatformUtils.isWindows ? const TextStyle(fontFamily: FontFamily.emoji) : null,
      ),
      leading: IPCountryFlag(
        countryCode: proxy.ipinfo.countryCode,
        organization: proxy.ipinfo.org,
        size: 40,
        padding: const EdgeInsetsDirectional.only(end: 8),
      ),
      subtitle: Text.rich(
        TextSpan(
          text: proxy.type,
          children: [
            if (proxy.isGroup)
              TextSpan(
                text: ' (${proxy.groupSelectedTagDisplay.trim()})',
                style: Theme.of(context).textTheme.bodySmall,
              ),
          ],
        ),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: proxy.urlTestDelay != 0
          ? _DelayIndicator(
              delay: proxy.urlTestDelay,
              hasDownload: proxy.download > 0,
              theme: theme,
            )
          : proxy.download > 0
              ? Text("⬩", style: theme.textTheme.bodySmall)
              : null,

      selected: selected,
      selectedTileColor: theme.colorScheme.primaryContainer,
      onTap: onTap,
      onLongPress: () async => await ref.read(dialogNotifierProvider.notifier).showProxyInfo(outboundInfo: proxy),
      horizontalTitleGap: 4,
    );
  }

}

class _DelayIndicator extends StatelessWidget {
  const _DelayIndicator({
    required this.delay,
    required this.hasDownload,
    required this.theme,
  });

  final int delay;
  final bool hasDownload;
  final ThemeData theme;

  @override
  Widget build(BuildContext context) {
    final isTimeout = delay > 65000;
    final isDark = theme.brightness == Brightness.dark;

    final color = _delayColor(isDark);
    final label = _delayLabel(isTimeout);
    final barFraction = _barFraction(isTimeout);

    final delayText = isTimeout ? "×" : "$delay ms";

    return Container(
      width: 72,
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(8),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            color.withValues(alpha: isDark ? 0.15 : 0.08),
            color.withValues(alpha: isDark ? 0.05 : 0.02),
          ],
        ),
        border: Border.all(
          color: color.withValues(alpha: 0.2),
          width: 0.5,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Delay text row with status dot
          Row(
            mainAxisSize: MainAxisSize.min,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Status dot
              Container(
                width: 6,
                height: 6,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isTimeout ? Colors.grey : color,
                  boxShadow: isTimeout
                      ? null
                      : [
                          BoxShadow(
                            color: color.withValues(alpha: 0.4),
                            blurRadius: 3,
                            spreadRadius: 0.5,
                          ),
                        ],
                ),
              ),
              const SizedBox(width: 4),
              // Delay number
              Flexible(
                child: Text(
                  delayText,
                  style: TextStyle(
                    color: color,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    height: 1.2,
                  ),
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 3),
          // Status label
          Text(
            label,
            style: TextStyle(
              color: color.withValues(alpha: 0.8),
              fontSize: 8,
              fontWeight: FontWeight.w500,
              height: 1.0,
            ),
          ),
          const SizedBox(height: 3),
          // Progress bar
          ClipRRect(
            borderRadius: BorderRadius.circular(1.5),
            child: SizedBox(
              height: 3,
              width: 56,
              child: Stack(
                children: [
                  // Background track
                  Container(
                    color: color.withValues(alpha: isDark ? 0.15 : 0.1),
                  ),
                  // Filled portion
                  FractionallySizedBox(
                    widthFactor: barFraction,
                    child: Container(
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(1.5),
                        gradient: LinearGradient(
                          colors: [
                            color,
                            color.withValues(alpha: 0.7),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
          // Download indicator
          if (hasDownload) ...[
            const SizedBox(height: 1),
            Text("⬩", style: TextStyle(fontSize: 8, color: theme.textTheme.bodySmall?.color)),
          ],
        ],
      ),
    );
  }

  Color _delayColor(bool isDark) {
    if (delay > 65000) return Colors.grey;
    if (isDark) {
      return switch (delay) {
        < 300 => Colors.lightGreenAccent,
        < 800 => Colors.lightGreen,
        < 1500 => Colors.orange,
        _ => Colors.redAccent,
      };
    }
    return switch (delay) {
      < 300 => Colors.green,
      < 800 => Colors.lightGreen.shade700,
      < 1500 => Colors.deepOrangeAccent,
      _ => Colors.red,
    };
  }

  String _delayLabel(bool isTimeout) {
    if (isTimeout) return "Таймаут";
    return switch (delay) {
      < 300 => "Быстрый",
      < 800 => "Хороший",
      < 1500 => "Средний",
      _ => "Медленный",
    };
  }

  double _barFraction(bool isTimeout) {
    if (isTimeout) return 0.0;
    return switch (delay) {
      < 300 => 1.0,
      < 800 => 0.75,
      < 1500 => 0.5,
      _ => 0.25,
    };
  }
}
