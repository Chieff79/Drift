/// Цели для decoy-трафика — легитимные домены, выбранные так, чтобы:
/// - Перекрываться с Reality SNI-пулами (Adobe, Nvidia, GitHub, Intel) — добавляет
///   реализма, т.к. трафик к этим доменам уже ожидаем при работе Reality.
/// - Быть популярными у обычных пользователей (Microsoft Updates, Apple, Google CDN).
/// - Поддерживать HEAD/GET без логина и без значительного payload.
/// - НЕ быть "censorship-tagged" (избегаем google search, twitter, telegram, etc.).
///
/// Если ТСПУ начнёт классифицировать конкретный домен как "VPN decoy" — добавить
/// сюда новые, отсортировать по популярности в РФ.
class DecoyTargets {
  /// Используются как HEAD-цели: минимум полезной нагрузки, но реальный TLS-handshake
  /// и HTTP request-line — этого достаточно, чтобы трафик-классификатор увидел
  /// "обычный browsing" вместо "single-flow VPN tunnel".
  static const List<String> urls = [
    // Microsoft (обновления, телеметрия, store)
    'https://www.microsoft.com/',
    'https://update.microsoft.com/',
    'https://www.bing.com/',
    'https://outlook.live.com/',

    // Apple (App Store, iCloud, Software Update)
    'https://www.apple.com/',
    'https://www.icloud.com/',
    'https://swcdn.apple.com/',

    // Google CDN (gstatic — cdn для миллионов сайтов; не google search)
    'https://www.gstatic.com/',
    'https://fonts.gstatic.com/',
    'https://ajax.googleapis.com/',

    // Adobe (синхронизирован с Reality SNI пулом — естественный трафик)
    'https://www.adobe.com/',
    'https://helpx.adobe.com/',

    // Nvidia (синхронизирован с Reality SNI пулом)
    'https://www.nvidia.com/',
    'https://developer.nvidia.com/',

    // GitHub (CDN-ассеты, синхронизирован с SNI пулом)
    'https://github.com/',
    'https://avatars.githubusercontent.com/',

    // Cloudflare (cdnjs — реально загружается тысячами сайтов)
    'https://cdnjs.cloudflare.com/',
    'https://www.cloudflare.com/',

    // Intel (синхронизирован с SNI пулом)
    'https://www.intel.com/',
  ];

  /// User-Agent ротация — подделываем разные клиенты, чтобы flow-fingerprint
  /// не палился как "тот же клиент шлёт идентичные запросы".
  static const List<String> userAgents = [
    // Современные браузеры desktop
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Safari/537.36',
    'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Safari/605.1.15',
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64; rv:122.0) Gecko/20100101 Firefox/122.0',

    // Mobile
    'Mozilla/5.0 (iPhone; CPU iPhone OS 17_2 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.2 Mobile/15E148 Safari/604.1',
    'Mozilla/5.0 (Linux; Android 14; SM-S921B) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121.0.0.0 Mobile Safari/537.36',

    // Системные клиенты (обновления — реальный сетевой шум)
    'CFNetwork/1410.0.3 Darwin/22.6.0',
    'Microsoft-WNS/10.0.22621',
  ];
}
