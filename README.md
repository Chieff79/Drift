# Drift

**Fast, safe, cross-platform internet accelerator.**

Drift is a multi-platform secure network client for iOS, Android, macOS, Windows and Linux. One tap builds an encrypted tunneled connection between your device and the nearest edge node, so streaming is smooth, public Wi-Fi is trustworthy, and travelling feels like home.

Built with **Flutter** on top of **[sing-box](https://github.com/SagerNet/sing-box)**, derived from the open-source hiddify-next codebase. Distributed by **DriftWay LLC** (Astana Hub, Kazakhstan).

![hero](docs/img/hero-screenshot.png)

---

## Why Drift

- **One tap.** No configuration, no manual routing. Open the app, press connect.
- **Real encryption.** ChaCha20-Poly1305 / AES-GCM — the same primitives used by banks and enterprise messengers.
- **Auto-selects the nearest node** by live latency. Always the fastest path available.
- **Split routing.** Send streaming and browsing through Drift, keep banking apps on your regular network.
- **Desktop TUN mode.** One toggle protects every app on the system.
- **Zero-PII.** We don't collect your name, email, phone or address. Just a Telegram ID for your subscription — nothing else. See [PRIVACY.md](PRIVACY.md).

---

## Screenshots

| Home | Nodes | Speed Test | Settings |
|------|-------|------------|----------|
| ![home](docs/img/screenshot-home.png) | ![nodes](docs/img/screenshot-nodes.png) | ![speedtest](docs/img/screenshot-speedtest.png) | ![settings](docs/img/screenshot-settings.png) |

---

## Supported platforms

| Platform | Minimum version | Distribution |
|----------|-----------------|--------------|
| iOS / iPadOS | 14.0 | App Store, TestFlight |
| Android | 8.0 (API 26) | Google Play, APK sideload, AAB |
| macOS | 12.0 (Monterey) | DMG, PKG, App Store |
| Windows | 10 (1809+) | MSIX, portable EXE |
| Linux | Ubuntu 22.04+, Fedora 38+ | DEB, RPM, AppImage, Flatpak |
| Router | KeeneticOS 3.7+, OpenWRT 22.03+ | WireGuard config export (Premium+) |

A single account is shared across all platforms.

---

## Install on a router (protect every device at home)

Running Drift on the router means **no client software on phones, Smart TVs, consoles or smart speakers** — all of them are already on a protected connection the moment they join your Wi-Fi.

- [Keenetic step-by-step (RU)](docs/router-setup-keenetic.md) — web-based, no SSH.
- [OpenWRT step-by-step (RU)](docs/router-setup-openwrt.md) — LuCI or CLI, with policy-based routing examples.

---

## Store listings

Copy-ready text for App Store Connect and Google Play Console:

- [Russian listing](docs/store-listing-ru.md)
- [English listing](docs/store-listing-en.md)

---

## Build from source (developers)

Drift is a Flutter application. Exact toolchain versions are pinned — see [CLAUDE.md](CLAUDE.md) for the full contributor guide.

```bash
flutter pub get
dart run build_runner build --delete-conflicting-outputs
dart run slang
flutter run -t lib/main.dart                # development build
flutter run -t lib/main_prod.dart           # production build (needs SENTRY_DSN)
```

Release artefacts for every platform are produced by GitHub Actions (`.github/workflows/build.yml`) — do not run `make *-release` locally unless you are debugging the CI pipeline.

Detailed architecture notes (state management, database migrations, sing-box bridge, build system) live in [CLAUDE.md](CLAUDE.md).

---

## Community and support

- **Telegram channel & support**: [@driftvpn](https://t.me/driftvpn) — release notes, tips, live help.
- **Issues**: use GitHub Issues for reproducible bugs. Do not post private configuration files.
- **Press and partnerships**: `support@{domain}` (current address on the in-app About screen).

---

## Legal

- [Privacy Policy](PRIVACY.md)
- [Terms of Service](TERMS.md)
- [License](LICENSE.md)

Copyright © DriftWay LLC and Drift contributors.
