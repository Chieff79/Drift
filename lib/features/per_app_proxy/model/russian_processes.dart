/// Список process-name российских приложений/процессов, которые должны ходить
/// в интернет мимо VPN-туннеля на десктопе.
///
/// Контекст: на Android bypass реализован через VpnService.Builder.addDisallowedApplication(),
/// но на macOS/Windows/Linux его нет. Sing-box поддерживает роутинг по имени процесса
/// через `route.rules[].process_name`. Этот список используется для построения
/// правила `SingboxRule(processNames: RussianProcesses.names, outbound: RuleOutbound.bypass)`,
/// которое прокидывает трафик RU-процессов напрямую, минуя туннель.
///
/// Формат sing-box:
/// - На Windows sing-box ожидает имя исполняемого файла с расширением `.exe`
/// - На macOS/Linux — имя бинаря без расширения (basename)
/// Включаем оба варианта, чтобы один и тот же список работал на всех ОС.
///
/// См. зеркало для Android: [RussianApps.packageNames].
class RussianProcesses {
  const RussianProcesses._();

  /// Имена процессов основных RU-приложений (~30 шт).
  /// Для Windows (.exe) и macOS/Linux (без расширения) — оба варианта.
  static const List<String> names = [
    // Банки — Windows клиенты / Electron-приложения
    'SberbankOnline.exe',
    'SberbankOnline',
    'SberBusiness.exe',
    'SberBusiness',
    'Tinkoff.exe',
    'Tinkoff',
    'TinkoffBusiness.exe',
    'TinkoffBusiness',
    'VTB.exe',
    'VTB',
    'AlfaBank.exe',
    'AlfaBank',
    'Gazprombank.exe',
    'Gazprombank',

    // Яндекс-экосистема
    'browser.exe', // Yandex Browser (Windows)
    'yandex-browser',
    'yandex-browser-stable',
    'YandexBrowser.exe',
    'YandexBrowser',
    'YandexDisk.exe',
    'YandexDisk',
    'YandexMusic.exe',
    'YandexMusic',

    // VK / Mail.ru экосистема
    'VKMessenger.exe',
    'VKMessenger',
    'VKMusic.exe',
    'VKMusic',
    'Mail.Ru.Agent.exe',
    'MailRuAgent',

    // Маркетплейсы и e-commerce (desktop-клиенты или Electron)
    'Ozon.exe',
    'Ozon',
    'Wildberries.exe',
    'Wildberries',

    // Мессенджеры RU (desktop)
    'TamTam.exe',
    'TamTam',
    'ICQ.exe',
    'ICQ',

    // Антивирусы / сервисы
    'Kaspersky.exe',
    'kaspersky',
    'avp.exe', // Kaspersky AV
    'DrWeb.exe',
    'drweb',

    // Госуслуги / 1С / корпоративное
    '1cv8.exe',
    '1cv8',
    'Gosuslugi.exe',
    'Gosuslugi',
  ];
}
