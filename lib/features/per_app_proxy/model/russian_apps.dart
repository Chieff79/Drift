/// Список package_name российских приложений, которые должны ходить в интернет
/// мимо VPN-туннеля.
///
/// Контекст: с 15.04.2026 крупные RU-сервисы (Сбер, Яндекс, VK, Ozon, WB и др.)
/// обязаны детектить VPN на уровне клиентского SDK через
/// `NetworkCapabilities.hasTransport(TRANSPORT_VPN)` и ограничивать доступ.
/// Единственный способ обойти это — исключить такие приложения из VPN-туннеля
/// через Android VpnService.Builder.addDisallowedApplication(), тогда внутри
/// процесса приложения `VpnTransportInfo` не будет активен.
///
/// Список дублируется в Kotlin: android/app/src/main/kotlin/com/drift/vpn/constant/RussianApps.kt
/// При изменениях — синхронизировать обе стороны.
class RussianApps {
  const RussianApps._();

  /// Package names основных RU-приложений. Группировано по категориям.
  static const List<String> packageNames = [
    // Банки
    'ru.sberbankmobile',
    'ru.sberbank.android',
    'ru.sberbank.sberbusinessonline',
    'ru.sberbank_sbbol',
    'com.idamob.tinkoff.android',
    'com.idamobile.android.tinkoff.business',
    'ru.vtb24.mobilebanking.android',
    'ru.alfabank.mobile.android',
    'ru.raiffeisen.mobile.new',
    'ru.raiffeisennews',
    'ru.psbank.pbm',
    'ru.rosbank.android',
    'ru.rosbank.android.beta',
    'com.openbank.mobile',
    'ru.gazprombank.android.mobilebank.app',
    'ru.mkb.mobile',
    'ru.rshb.mbank',
    'ru.rshb.dbo',
    'ru.rshb.dboul',
    'ru.uralsib.mobile',
    'ru.akbars.mobile',
    'ru.qiwi.client.android',
    'ru.sovcomcard.halva.v1',
    'ru.letobank.Prometheus',
    'ru.ozon.fintech.finance',
    'ru.ozon.fintech.sme',

    // Платёжные системы (НСПК/ЦБ)
    'ru.nspk.mirpay',
    'ru.nspk.sbpay',
    'ru.sbp.sberbank',

    // Госуслуги и госсервисы
    'ru.rostel',
    'ru.rostelecom.zapusk',
    'ru.gosuslugi.pgu',
    'ru.gosuslugi.pos',
    'ru.gosuslugi.migrant',
    'ru.mos.app',
    'ru.mos.zdorovie',
    'ru.fns.lknpa',
    'ru.fns.lkfl',
    'ru.fssprus.mobileapp',
    'ru.pfr.mobile',
    'ru.gibdd.wanted',
    'ru.oneme.app',

    // Маркетплейсы и e-commerce
    'ru.ozon.app.android',
    'com.wildberries.ru',
    'ru.yandex.market',
    'ru.beru.android',
    'com.aliexpress.buyer',
    'com.alibaba.aliexpresshd',
    'ru.sbermegamarket.client',
    'ru.megamarket.marketplace',
    'ru.lamoda.lite',
    'com.lamoda.lite',
    'ru.mvideo.mobile',
    'ru.filit.mvideo.b2c',
    'ru.dns_shop.dnsshop',
    'ru.dns.shop.android',
    'ru.detmir.dmbonus',
    'com.avito.android',
    'ru.x5.chizhik',
    'ru.joom.clientapp',
    'ru.drom.auto',
    'ru.auto.ara',

    // Такси, доставка, еда
    'ru.yandex.taxi',
    'ru.yandex.taximeter',
    'ru.yandex.eda',
    'ru.foodfox.client',
    'com.yandex.lavka',
    'ru.yandex.market.beru',
    'ru.citymobil',
    'ru.deliveryclub',
    'ru.instamart',
    'ru.samokat.androidclient',
    'ru.sbcs.store',
    'com.vkusvill.app',
    'ru.pyaterochka.app',
    'ru.perekrestok.app',
    'ru.magnit',
    'com.icemobile.lenta',

    // Соцсети и мессенджеры (RU)
    'com.vkontakte.android',
    'com.vk.im',
    'com.vk.tv',
    'com.vk.music',
    'com.vk.dating',
    'ru.ok.android',
    'ru.tinkoff.messenger',
    'one.mesh.im',
    'ru.mail.mailapp',

    // Операторы связи
    'ru.mts.mymts',
    'ru.megafon.mlk',
    'ru.beeline.services',
    'ru.tele2.mytele2',
    'ru.yota.android',

    // Медиа и стриминги (RU)
    'ru.kinopoisk',
    'com.rutube.app',
    'ru.ivi.client',
    'ru.start.androidmobile',
    'ru.more.play',
    'com.zen.yandex',
    'com.yandex.zenkit',
    'ru.yandex.mobile.music',
    'ru.mts.mtstv',
    'ru.kion.mobileapp',
    'tv.smartbox.client',

    // Транспорт
    'ru.rzd.pass',
    'ru.aeroflot',
    'ru.s7.android',
    'ru.yandex.metro',

    // Навигация/карты
    'ru.dublgis.dgismobile',
    'ru.yandex.yandexmaps',
    'ru.yandex.yandexnavi',

    // Антивирусы и безопасность
    'com.kms.free',
    'com.kaspersky.security.cloud',
    'com.kaspersky.kes',
    'com.drweb',

    // Работа/вакансии
    'ru.hh.android',
    'ru.superjob.api.app',
    'ru.hh.applicant.android',

    // Недвижимость
    'ru.cian.main',
    'ru.domofond.app',

    // Прочие критичные
    'ru.yandex.searchplugin',
    'com.yandex.browser',
    'ru.yandex.money.android',
    'ru.sberbank.spasibo',
    'ru.tsbank.app',
    'ru.rambler.news',
    'com.avito.avitoscript',
  ];
}
