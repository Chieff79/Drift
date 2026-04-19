# Установка Drift на роутер с OpenWRT

Техническое руководство для пользователей, которые администрируют OpenWRT самостоятельно. Все команды — от root через SSH или из LuCI. Конфигурационные фрагменты — готовые к использованию.

> Нужен более простой путь? Смотрите [инструкцию для Keenetic](router-setup-keenetic.md) — там всё через web-интерфейс в несколько кликов.

![screenshot](img/openwrt-hero.png)

---

## Что это даст

- Защищённое соединение для всей домашней сети через один WireGuard-тоннель на роутере.
- Никаких клиентских приложений на самих устройствах — телефоны, Smart TV, принтеры и умные колонки ходят через Drift «прозрачно».
- Гибкая маршрутизация: можно отправлять в тоннель **только часть устройств** по MAC, **только часть подсетей**, или **только часть назначений** (domain / IP-префикс) через `mwan3` или `pbr` (policy-based routing).
- Весь функционал остаётся на устройстве под вашим полным контролем.

---

## Требования

| Компонент | Минимум | Рекомендуется |
|-----------|---------|---------------|
| OpenWRT | 22.03 | 23.05 или 24.10 |
| Свободная flash | 8 МБ | 16 МБ |
| RAM | 128 МБ | 256+ МБ |
| CPU | одно ядро 800 МГц | двухъядерный ARMv8 с crypto-расширениями |
| Пакеты | `wireguard-tools`, `luci-proto-wireguard`, `kmod-wireguard` (обычно встроен в ядро) | плюс `mwan3` или `pbr` для policy routing, `qrencode` для экспорта конфига |

Если `kmod-wireguard` отсутствует, проверьте, собран ли он в ваше ядро: `lsmod | grep wireguard`. На x86/ARM-сборках модуль идёт как built-in и не виден в `opkg`.

---

## Шаг 1. Получить конфиг у Drift support

У поддержки Drift (Telegram [@driftvpn](https://t.me/driftvpn)) запросите файл `drift-openwrt.conf` — это стандартный `wg-quick` конфиг:

```ini
[Interface]
PrivateKey = <base64-private-key>
Address    = 10.10.0.42/32
DNS        = 1.1.1.1, 1.0.0.1

[Peer]
PublicKey           = <base64-server-public-key>
PresharedKey        = <base64-psk>
AllowedIPs          = 0.0.0.0/0, ::/0
Endpoint            = nl-edge-01.drift-vpn.example:51820
PersistentKeepalive = 25
```

Конфиг доступен на тарифе **Premium+** и привязан к вашей подписке.

---

## Шаг 2. Установка пакетов

По SSH:

```bash
opkg update
opkg install wireguard-tools luci-proto-wireguard
# опционально, для policy routing:
opkg install mwan3 luci-app-mwan3
# или альтернатива, если mwan3 тяжёл:
opkg install pbr luci-app-pbr
```

Перезапустите LuCI, чтобы появился новый proto:

```bash
/etc/init.d/rpcd restart
/etc/init.d/uhttpd restart
```

---

## Шаг 3а. Импорт конфига через LuCI

1. Откройте **Network → Interfaces → Add new interface**.
2. Name: `drift`. Protocol: **WireGuard VPN**. Нажмите *Create interface*.
3. На вкладке **General Settings**:
   - Private Key: из `[Interface] PrivateKey`.
   - Listen Port: оставьте пустым (клиентская сторона).
   - IP Addresses: адрес из `[Interface] Address`, например `10.10.0.42/32`.
4. На вкладке **Peers** → *Add peer*:
   - Public Key — из `[Peer] PublicKey`.
   - Preshared Key (если есть).
   - Allowed IPs — `0.0.0.0/0` и `::/0`.
   - Route Allowed IPs — **выключите** (мы пропишем маршрутизацию сами через firewall/mwan3, чтобы избежать конфликтов).
   - Endpoint Host / Port — из `[Peer] Endpoint`.
   - Persistent Keep Alive — 25.
5. На вкладке **Firewall Settings** выберите зону `wan` или создайте новую `drift` (рекомендуется, см. Шаг 4).
6. Save & Apply.

![screenshot](img/openwrt-step-3.png)

---

## Шаг 3б. Импорт конфига через `/etc/config/network` (альтернатива)

Если не хочется ковыряться в LuCI, то же самое текстом:

```bash
# /etc/config/network
config interface 'drift'
    option proto 'wireguard'
    option private_key '<base64-private-key>'
    list addresses '10.10.0.42/32'
    option mtu '1380'

config wireguard_drift
    option public_key '<base64-server-public-key>'
    option preshared_key '<base64-psk>'
    list allowed_ips '0.0.0.0/0'
    list allowed_ips '::/0'
    option endpoint_host 'nl-edge-01.drift-vpn.example'
    option endpoint_port '51820'
    option persistent_keepalive '25'
    option route_allowed_ips '0'
```

Применить:

```bash
uci commit network
/etc/init.d/network reload
```

Проверить интерфейс:

```bash
ifstatus drift
wg show drift
```

В выводе `wg show` должен быть свежий `latest handshake` через несколько секунд.

---

## Шаг 4. Firewall zone и masquerade

Добавьте отдельную зону `drift` и разрешите forwarding из `lan` в неё:

```bash
# /etc/config/firewall
config zone
    option name 'drift'
    option input 'REJECT'
    option output 'ACCEPT'
    option forward 'REJECT'
    option masq '1'
    option mtu_fix '1'
    list network 'drift'

config forwarding
    option src 'lan'
    option dest 'drift'
```

Применить:

```bash
/etc/init.d/firewall restart
```

Что это делает:
- `masq = 1` — NAT исходящего трафика через WireGuard-интерфейс, без этого ответы от серверов Drift не вернутся к устройствам LAN.
- `mtu_fix = 1` — clamp MSS для TCP, предотвращает проблему «сайт не открывается, пока не сделаешь ping большим пакетом».
- `input = REJECT` — из тоннеля никто не может достучаться до сервисов роутера.

> Не добавляйте `drift` в ту же зону, что и `wan` — тогда сломаются правила для вашего провайдера.

---

## Шаг 5. Policy-based routing (выбор, какие устройства идут через Drift)

Есть два популярных подхода. Выберите один.

### Вариант A — `pbr` (проще)

Пакет `pbr` (policy-based routing) даёт UI в LuCI и работает поверх `ip rule` / `nft`.

Пример правил в `/etc/config/pbr`:

```bash
config policy
    option name 'Phone_Alice_via_Drift'
    option src_addr '192.168.1.120'
    option interface 'drift'

config policy
    option name 'LivingRoomTV_via_Drift'
    option src_mac 'aa:bb:cc:dd:ee:ff'
    option interface 'drift'

config policy
    option name 'Work_NAS_via_WAN'
    option src_addr '192.168.1.10'
    option interface 'wan'
```

Активировать:

```bash
/etc/init.d/pbr restart
```

Устройства, не попавшие ни под одно правило, идут через основной WAN (default route).

### Вариант B — `mwan3` (сложнее, но мощнее)

`mwan3` позволяет делать load-balance между WAN и Drift, а также health-check endpoint'ов.

Фрагмент `/etc/config/mwan3`:

```bash
config interface 'wan'
    option enabled '1'
    list track_ip '1.1.1.1'
    option reliability '1'
    option family 'ipv4'

config interface 'drift'
    option enabled '1'
    list track_ip '10.10.0.1'
    option reliability '1'
    option family 'ipv4'

config member 'wan_only'
    option interface 'wan'
    option metric '1'

config member 'drift_only'
    option interface 'drift'
    option metric '1'

config policy 'prefer_drift'
    list use_member 'drift_only'
    list use_member 'wan_only'

config rule 'lan_to_drift'
    option src_ip '192.168.1.0/24'
    option dest_ip '0.0.0.0/0'
    option use_policy 'prefer_drift'
```

Применить:

```bash
/etc/init.d/mwan3 restart
```

> Если у вас одновременно стоят `pbr` и `mwan3` — они будут конкурировать за `ip rule`. Оставьте только один.

---

## Проверка, что всё работает

Со стороны роутера:

```bash
# Поднят ли интерфейс, есть ли handshake
wg show drift

# Маршрут через Drift
ip route show dev drift

# Видно ли, что трафик идёт
cat /proc/net/dev | grep drift
```

Со стороны клиента в LAN:

```bash
# Ожидаемый внешний IP — Drift edge node, а не ваш провайдер
curl https://ipinfo.io/ip
```

---

## Диагностика

```bash
# Логи WireGuard и сетевого стека
logread -e wireguard
logread -e mwan3
logread -e pbr

# Детали handshake
wg show drift latest-handshakes

# Проверить MTU (если большие файлы рвутся)
ping -M do -s 1352 nl-edge-01.drift-vpn.example   # подберите максимальный проходящий размер, затем MTU = size + 28
```

Частые проблемы:

- **`latest handshake = 0 seconds ago` не появляется никогда** — неверный PrivateKey или заблокированный UDP 51820 у провайдера. Попросите поддержку перенести endpoint на TCP 443 (если доступно).
- **Сайты открываются, но очень медленно, ssh-сессии обрываются** — проблема MTU. Установите `option mtu '1280'` у интерфейса `drift` и перезапустите сеть.
- **DNS resolves, но сайты не грузятся** — забыли `masq = 1` в firewall zone.
- **IPv6 течёт мимо тоннеля** — либо добавьте `::/0` в `allowed_ips`, либо полностью выключите IPv6 на LAN (`option ipv6 'disabled'` в zone lan).
- **Устройство LAN не видит интернет после включения политики** — проверьте, что нужная зона имеет `forward` на `drift` и `masq = 1`.

---

## Хранение и обновление конфига

- Ключи храните в `/etc/config/network` (root-only, 0600). Не коммитьте их в git репозиториев OpenWRT-сборок.
- При ротации ключей поддержка Drift пришлёт новый файл — замените `private_key` и `public_key` пира, сделайте `/etc/init.d/network reload`. Даунтайм — секунды.
- Для резервного копирования: `sysupgrade -b /tmp/backup-$(date +%F).tar.gz` — архив включает WireGuard-секреты, храните его в защищённом месте.

---

## Поддержка

Сложные сценарии (несколько одновременных тоннелей, балансировка, DNS-split по домену) — пишите в Telegram [@driftvpn](https://t.me/driftvpn). Приложите вывод `wg show`, `ip route`, `logread | tail -200` и описание того, что должно работать.
