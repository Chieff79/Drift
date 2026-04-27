import 'dart:async';
import 'dart:io';
import 'dart:math';

import 'package:hiddify/core/preferences/general_preferences.dart';
import 'package:hiddify/features/connection/notifier/connection_notifier.dart';
import 'package:hiddify/features/decoy_traffic/data/decoy_targets.dart';
import 'package:hiddify/hiddifycore/init_signal.dart';
import 'package:hiddify/utils/utils.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'decoy_traffic_notifier.g.dart';

/// Генератор фонового decoy-трафика.
///
/// Когда VPN активен и `Preferences.useDecoyTraffic = true`, периодически
/// (с рандомным джиттером) делает HEAD-запросы к легитимным доменам через
/// VPN-туннель. Цель — чтобы наблюдатель (DPI оператора, ТСПУ) видел поток
/// похожий на обычный browsing с разнообразными SNI/User-Agent, а не
/// одиночный Reality-flow в течение часа.
///
/// **Важно:** запускается ТОЛЬКО когда VPN connected, иначе раскрывает
/// реальный IP при запросах к decoy-доменам.
///
/// Параметры подобраны так, чтобы:
/// - Не нагружать батарею: ~30-60 запросов/час, HEAD-метод (минимум payload).
/// - Не быть предсказуемыми: рандомный jitter интервала, рандомный target,
///   рандомный User-Agent.
/// - Не съедать мобильный трафик пользователя: <100 KB/сутки в среднем.
@Riverpod(keepAlive: true)
class DecoyTrafficNotifier extends _$DecoyTrafficNotifier with AppLogger {
  Timer? _scheduleTimer;
  final Random _rng = Random();

  // Случайный интервал между запросами — критически важен для маскировки.
  // Регулярный 60s-таймер сам по себе — паттерн.
  static const _minIntervalSeconds = 45;
  static const _maxIntervalSeconds = 180;

  // Стартовая задержка после подключения — чтобы decoy не палился синхронно
  // с моментом activation VPN.
  static const _startupMinSeconds = 20;
  static const _startupMaxSeconds = 90;

  static const _requestTimeout = Duration(seconds: 8);

  @override
  Future<void> build() async {
    ref.watch(coreRestartSignalProvider);
    final isConnected = await ref
        .watch(serviceRunningProvider.future)
        .catchError((_) => false);
    final useDecoy = ref.watch(Preferences.useDecoyTraffic);

    ref.onDispose(() {
      _scheduleTimer?.cancel();
    });

    if (!isConnected || !useDecoy) {
      _scheduleTimer?.cancel();
      return;
    }

    final startupDelay = Duration(
      seconds: _startupMinSeconds +
          _rng.nextInt(_startupMaxSeconds - _startupMinSeconds),
    );
    loggy.debug('Decoy traffic: starting in ${startupDelay.inSeconds}s');
    _scheduleTimer = Timer(startupDelay, _scheduleNext);
  }

  void _scheduleNext() {
    if (_scheduleTimer != null && !_scheduleTimer!.isActive) {
      _scheduleTimer = null;
    }
    _fireOne();
    final next = Duration(
      seconds: _minIntervalSeconds +
          _rng.nextInt(_maxIntervalSeconds - _minIntervalSeconds),
    );
    _scheduleTimer = Timer(next, _scheduleNext);
  }

  Future<void> _fireOne() async {
    final url = DecoyTargets.urls[_rng.nextInt(DecoyTargets.urls.length)];
    final ua = DecoyTargets.userAgents[_rng.nextInt(DecoyTargets.userAgents.length)];

    HttpClient? client;
    try {
      client = HttpClient()
        ..connectionTimeout = _requestTimeout
        ..idleTimeout = const Duration(seconds: 5);
      // Без findProxy → идёт через системный proxy → через VPN.
      client.badCertificateCallback = (_, _, _) => false;

      final uri = Uri.parse(url);
      final request = await client.headUrl(uri).timeout(_requestTimeout);
      request.headers.set(HttpHeaders.userAgentHeader, ua);
      request.headers.set(HttpHeaders.acceptHeader,
          'text/html,application/xhtml+xml,application/xml;q=0.9,*/*;q=0.8');
      request.headers.set(HttpHeaders.acceptLanguageHeader, 'en-US,en;q=0.9');

      final response = await request.close().timeout(_requestTimeout);
      // Сливаем тело (на случай если HEAD вернёт payload), не задерживая поток.
      await response.drain<void>().timeout(const Duration(seconds: 3),
          onTimeout: () => null);

      loggy.debug('Decoy → $uri.host (${response.statusCode})');
    } catch (e) {
      // Decoy-запрос не должен мешать пользователю. Логируем только в debug.
      loggy.debug('Decoy request failed (silent): $e');
    } finally {
      client?.close(force: true);
    }
  }
}
