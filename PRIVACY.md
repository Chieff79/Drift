# Privacy Policy — Drift

**Last updated: 19 April 2026**

## Overview

Drift ("we", "our", "the app") is an internet acceleration and secure network service operated by **DriftWay LLC** (a limited liability partnership registered in the Republic of Kazakhstan, Astana Hub resident). This policy explains, in plain language, what information we handle and how.

Our guiding principle is **zero personally identifiable information (zero-PII)**: we cannot reveal what we never collect.

## Data We Do NOT Collect

We do **not** collect, store, or process:

- Your full name, date of birth, home address, passport or ID document data
- Phone numbers
- Email addresses
- Browsing history, visited websites, or DNS queries tied to your identity
- Traffic content (payloads of your tunneled connection)
- Your originating IP address in any persistent log
- Device fingerprints, advertising identifiers (IDFA / AAID), or behavioural profiles
- Payment card details (billing is handled by third-party processors — we only receive a subscription status flag)
- Location data (GPS, cell, Wi-Fi triangulation)

We do **not** sell, rent, or trade any information to third parties, and we do **not** require account registration with personal details.

## Data We Do Collect (minimal, and only when needed)

### 1. Telegram identifier for subscription billing

To link your subscription to your device we store a **Telegram user ID** (a numeric identifier issued by Telegram) and a subscription tier/expiry date. No Telegram username, phone number, display name, or profile photo is retrieved or stored.

This identifier is the sole piece of data that could, in combination with information held by Telegram, be considered indirectly identifying. It is used exclusively for:

- verifying an active subscription,
- issuing a secure network configuration file,
- customer support when you reach out to us and reference the ID yourself.

### 2. Anonymous crash and diagnostic reports (opt-in)

If you enable diagnostics in **Settings → Analytics**, we collect anonymous reports via Sentry to improve stability. Each report contains:

- application version and platform (iOS, Android, macOS, Windows, Linux)
- anonymised stack traces
- non-identifying device class (e.g. "arm64, Android 14")

No IP address, device ID, user content, or connection metadata is attached. You can disable this at any time.

### 3. Ephemeral operational counters

Our secure servers keep short-lived, aggregate counters (total bytes per node, number of active tunnels) for capacity planning and abuse prevention. These counters are **not tied to any user identifier** and are rotated within 24 hours.

## Secure Network / Tunneled Connection

Drift establishes an encrypted tunneled connection between your device and our edge nodes (Netherlands, Kazakhstan, United States, additional locations as announced). Within that tunneled connection:

- Traffic content is **not logged**.
- Destination hostnames are **not logged** against your identifier.
- Temporary connection metadata (session start timestamp, node identifier) may remain in volatile memory for up to 24 hours strictly for abuse prevention (DDoS, spam) and is never cross-referenced with any subscription identifier beyond that window.

## Third-Party Services

- **Cloudflare WARP** — if you enable the optional WARP front-end, Cloudflare's [privacy policy](https://www.cloudflare.com/privacypolicy/) applies to the portion of the path handled by Cloudflare.
- **Apple TestFlight / App Store / Google Play** — governed by their respective privacy policies.
- **Sentry** — anonymous crash telemetry only, when opted in.
- **Payment processors** — handle card / wallet data directly; we only receive an opaque subscription-active flag.

## Children

Drift is not directed at children under 13 (or 16 in applicable jurisdictions). We do not knowingly process any data from minors.

## Your Rights

Because we hold almost no data about you, most statutory rights (access, portability, erasure under GDPR/Kazakhstan Law No. 94-V) reduce in practice to: **provide your Telegram ID and we will delete the subscription record**. Anonymous crash reports cannot be matched to an individual and therefore cannot be individually deleted.

## Data Retention

| Data | Retention |
|------|-----------|
| Telegram ID + subscription status | While subscription is active + 30 days |
| Anonymous crash reports | 90 days |
| Operational counters | Up to 24 hours |

## Security

All tunneled traffic uses modern authenticated encryption (ChaCha20-Poly1305, AES-GCM). Configuration files issued to users are bound to a single account identifier and can be rotated on request.

## Changes to This Policy

We may update this policy. The "Last updated" date above will always reflect the current version. Material changes will be announced in the app.

## Contact

Privacy questions and data requests:

- Email: `support@{domain}` (domain announced at app launch — check the in-app About screen for the current address)
- Telegram: [@driftvpn](https://t.me/driftvpn)

Controller of record: **DriftWay LLC**, Astana Hub, Republic of Kazakhstan (registration in progress at the time of this version).
