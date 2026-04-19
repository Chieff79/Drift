package com.drift.vpn.constant

/**
 * Список package_name российских приложений, которые должны ходить мимо VPN.
 * Синхронизировать с: lib/features/per_app_proxy/model/russian_apps.dart
 */
object RussianApps {
    val packageNames: List<String> = listOf(
        // Банки
        "ru.sberbankmobile",
        "ru.sberbank.android",
        "ru.sberbank.sberbusinessonline",
        "com.idamob.tinkoff.android",
        "com.idamobile.android.tinkoff.business",
        "ru.vtb24.mobilebanking.android",
        "ru.alfabank.mobile.android",
        "ru.raiffeisen.mobile.new",
        "ru.psbank.pbm",
        "ru.rosbank.android",
        "com.openbank.mobile",
        "ru.gazprombank.android.mobilebank.app",
        "ru.mkb.mobile",
        "ru.rshb.mbank",
        "ru.uralsib.mobile",
        "ru.akbars.mobile",
        "ru.qiwi.client.android",

        // Госуслуги и госсервисы
        "ru.rostelecom.zapusk",
        "ru.gosuslugi.pgu",
        "ru.mos.app",
        "ru.mos.zdorovie",
        "ru.fns.lknpa",
        "ru.fssprus.mobileapp",
        "ru.pfr.mobile",

        // Маркетплейсы и e-commerce
        "ru.ozon.app.android",
        "com.wildberries.ru",
        "ru.yandex.market",
        "com.aliexpress.buyer",
        "ru.sbermegamarket.client",
        "ru.lamoda.lite",
        "ru.mvideo.mobile",
        "ru.dns_shop.dnsshop",

        // Такси, доставка, еда
        "ru.yandex.taxi",
        "ru.yandex.eda",
        "ru.yandex.market.beru",
        "ru.citymobil",
        "ru.deliveryclub",
        "ru.samokat.androidclient",
        "com.vkusvill.app",
        "ru.pyaterochka.app",
        "ru.perekrestok.app",

        // Соцсети и мессенджеры (RU)
        "com.vkontakte.android",
        "ru.ok.android",
        "ru.tinkoff.messenger",
        "one.mesh.im",
        "ru.mail.mailapp",

        // Операторы связи
        "ru.mts.mymts",
        "ru.megafon.mlk",
        "ru.beeline.services",
        "ru.tele2.mytele2",
        "ru.yota.android",

        // Медиа и стриминги (RU)
        "ru.kinopoisk",
        "com.rutube.app",
        "ru.ivi.client",
        "ru.start.androidmobile",
        "ru.more.play",

        // Транспорт
        "ru.rzd.pass",
        "ru.aeroflot",
        "ru.s7.android",
        "ru.yandex.metro",

        // Прочие критичные
        "ru.yandex.searchplugin",
        "com.yandex.browser",
        "ru.yandex.money.android",
        "ru.sberbank.spasibo",
        "ru.tsbank.app"
    )
}
