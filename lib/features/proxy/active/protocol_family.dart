/// Семейства протоколов для умной авто-ротации.
///
/// Разделение трафика по категориям нужно, чтобы при потере связи переключаться
/// сначала на relay той же категории (близкий профиль трафика), а потом — между
/// категориями по убыванию stealth-приоритета.
///
/// Тег outbound'а в Marzban формируется ботом ([drift-bot/src/services/vpn_config.py])
/// или вручную в панели. Классификация — по подстрокам в теге (case-insensitive).
enum ProtocolFamily {
  /// VLESS+Reality через российские облака (Selectel/Yandex/MTS).
  /// ASN российских хостеров не режется ТСПУ → ключ для "мёртвых зон".
  ruCloudReality,

  /// Hysteria2 / TUIC поверх UDP с salamander-обфускацией.
  /// Альтернативный транспорт когда TCP/443 деградирует.
  hysteria2,

  /// VLESS+Reality+XHTTP — поведенческая маскировка под HTTP/2.
  xhttp,

  /// Прямой VLESS+Reality на иностранный exit (Hetzner FI/US/MD, без relay).
  euDirect,

  /// Не удалось определить — обрабатывается как euDirect (fallback).
  unknown;

  /// Приоритет внутри fallback-цепочки: чем меньше число — тем раньше пробуем.
  /// RU-cloud первым: при ТСПУ-блокировке только он стабильно работает в РФ.
  int get fallbackOrder => switch (this) {
        ruCloudReality => 0,
        hysteria2 => 1,
        xhttp => 2,
        euDirect => 3,
        unknown => 4,
      };
}

/// Определяет семейство по тегу outbound'а.
///
/// Бот (`drift-bot`) формирует теги вида `"RU Selectel (USERNAME)"`, `"FI Hysteria2"`
/// и т.д. Если в Marzban теги изменятся — обновить эвристику здесь.
ProtocolFamily detectProtocolFamily(String tag, {String? outboundType}) {
  final lower = tag.toLowerCase();

  // Hysteria2 (тип может прийти из core напрямую — приоритет над тегом)
  if (outboundType != null) {
    final t = outboundType.toLowerCase();
    if (t.contains('hysteria') || t == 'tuic') return ProtocolFamily.hysteria2;
  }
  if (lower.contains('hysteria') || lower.contains('hy2') || lower.contains('tuic')) {
    return ProtocolFamily.hysteria2;
  }

  // XHTTP transport (поведенческий маскинг)
  if (lower.contains('xhttp')) return ProtocolFamily.xhttp;

  // Российские облака — приоритет №1 для anti-ТСПУ
  if (lower.contains('selectel') ||
      lower.contains('yandex') ||
      lower.contains('mts') ||
      lower.contains('vk cloud') ||
      lower.contains('cloud.ru')) {
    return ProtocolFamily.ruCloudReality;
  }

  // RU Stealth (старое имя для FI exit с fragment) — тоже считаем за ru-cloud-like
  // т.к. это российский маршрут даже если выходим через FI.
  if (lower.startsWith('ru ') || lower.contains('stealth')) {
    return ProtocolFamily.ruCloudReality;
  }

  // FI/US/EU прямые exit'ы
  if (lower.contains('fi ') ||
      lower.contains('us ') ||
      lower.contains('eu ') ||
      lower.contains('turbo') ||
      lower.contains('direct')) {
    return ProtocolFamily.euDirect;
  }

  return ProtocolFamily.unknown;
}
