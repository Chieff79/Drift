#!/usr/bin/env bash
# Drift VPN - install & configure Hysteria2 server on :8443/UDP.
# Masquerade: https://www.bing.com. Systemd-managed.
# Password: single strong shared password written to /etc/hysteria/password.
set -euo pipefail

CONF=/etc/hysteria/config.yaml
PWFILE=/etc/hysteria/password
UNIT=/etc/systemd/system/hysteria-server.service

# 1) Install hysteria2 if missing
if ! command -v hysteria >/dev/null 2>&1; then
    echo "[hy2] installing..."
    bash <(curl -fsSL https://get.hy2.sh/) 2>&1 | tail -10
else
    echo "[hy2] already installed: $(hysteria version | head -1)"
fi

mkdir -p /etc/hysteria

# 2) Shared password (deterministic from UUID list so same across restarts)
if [ ! -s "$PWFILE" ]; then
    # Derive from Marzban xray UUIDs so it is reproducible but not stored in plain admin state
    UUIDS=$(python3 -c "import json;print(','.join(c['id'] for c in json.load(open('/var/lib/marzban/xray_config.json'))['inbounds'][0]['settings']['clients']))")
    PASS=$(echo -n "drift-hy2-$UUIDS" | sha256sum | awk '{print $1}' | head -c 32)
    echo "$PASS" > "$PWFILE"
    chmod 600 "$PWFILE"
fi
PASS=$(tr -d '\n' < "$PWFILE")
echo "[hy2] password set (length=${#PASS})"

# 3) TLS cert - reuse Marzban self-signed (Hysteria2 requires TLS).
#    Clients will set insecure=true since it is self-signed. Acceptable for
#    our ТСПУ-bypass scenario where SNI masquerade is the real obfuscation.
CERT=/var/lib/marzban/cert.pem
KEY=/var/lib/marzban/key.pem

# 4) Write config
cat >"$CONF" <<YAML
listen: :8443

tls:
  cert: ${CERT}
  key: ${KEY}

auth:
  type: password
  password: ${PASS}

masquerade:
  type: proxy
  proxy:
    url: https://www.bing.com
    rewriteHost: true

quic:
  initStreamReceiveWindow: 8388608
  maxStreamReceiveWindow: 8388608
  initConnReceiveWindow: 20971520
  maxConnReceiveWindow: 20971520

bandwidth:
  up: 1 gbps
  down: 1 gbps

log:
  level: info
YAML

# 5) systemd unit (hy2 installer usually ships one at /etc/systemd/system/hysteria-server.service;
#    write our own to force our config path and restart policy).
cat >"$UNIT" <<'UNITFILE'
[Unit]
Description=Hysteria2 Server (Drift VPN)
After=network.target

[Service]
Type=simple
ExecStart=/usr/local/bin/hysteria server -c /etc/hysteria/config.yaml
Restart=always
RestartSec=3
LimitNOFILE=1048576
AmbientCapabilities=CAP_NET_BIND_SERVICE
CapabilityBoundingSet=CAP_NET_BIND_SERVICE

[Install]
WantedBy=multi-user.target
UNITFILE

# Stop any previously-installed default service variant
systemctl daemon-reload
systemctl disable --now hysteria-server@config 2>/dev/null || true
systemctl disable --now hysteria 2>/dev/null || true

systemctl enable --now hysteria-server

sleep 2
if systemctl is-active --quiet hysteria-server; then
    echo "[hy2] service is active"
else
    echo "[hy2] service FAILED"
    journalctl -u hysteria-server --no-pager -n 30
    exit 1
fi

# 6) Confirm UDP port
ss -ulnp 2>/dev/null | grep -E ':8443' | head -5 || echo "[hy2] WARN: no UDP listener seen (may still be fine)"

# 7) Export connection info
UUID_FIRST=$(python3 -c "import json;print(json.load(open('/var/lib/marzban/xray_config.json'))['inbounds'][0]['settings']['clients'][0]['id'])")
PUB_IP=$(curl -s --max-time 4 https://ipv4.icanhazip.com || hostname -I | awk '{print $1}')
echo "[hy2] password=${PASS}"
echo "[hy2] example URI: hy2://${PASS}@${PUB_IP}:8443/?sni=www.bing.com&insecure=1#FI-Hysteria2"
