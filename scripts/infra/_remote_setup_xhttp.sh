#!/usr/bin/env bash
# Drift VPN - add VLESS+XHTTP+Reality inbound on :8444 TCP, SNI www.microsoft.com.
# Runs on Marzban host. Does NOT touch existing VLESS_REALITY inbound on :443.
set -euo pipefail

XRAY_JSON=/var/lib/marzban/xray_config.json
TS=$(date +%s)
BACKUP=/root/drift-infra/xray_config.json.bak-${TS}

cp "$XRAY_JSON" "$BACKUP"
echo "[xhttp] backup -> $BACKUP"

# Generate a fresh Reality x25519 keypair (the new inbound uses its own key).
# Run inside the marzban container (xray binary available there).
KEYS=$(docker exec marzban xray x25519 2>/dev/null)
PRIV=$(echo "$KEYS" | awk -F': ' '/Private key/ {print $2}')
PUB=$(echo "$KEYS" | awk -F': ' '/Public key/ {print $2}')
if [ -z "$PRIV" ] || [ -z "$PUB" ]; then
    echo "[xhttp] Failed to generate Reality keys"; exit 1
fi
SID=$(openssl rand -hex 8)
echo "[xhttp] PUB=$PUB"
echo "[xhttp] SID=$SID"
echo "$PRIV" >/root/drift-infra/xhttp_reality.priv
echo "$PUB"  >/root/drift-infra/xhttp_reality.pub
echo "$SID"  >/root/drift-infra/xhttp_reality.sid

# Patch xray_config.json atomically with python (preserve existing inbound,
# copy client UUIDs so the same Marzban users authenticate on both inbounds).
python3 - "$XRAY_JSON" "$PRIV" "$SID" <<'PYEOF'
import json, sys, os
path, priv, sid = sys.argv[1], sys.argv[2], sys.argv[3]
with open(path) as f:
    cfg = json.load(f)

# Find existing reality inbound to copy clients
existing = next((ib for ib in cfg["inbounds"] if ib.get("tag") == "VLESS_REALITY"), None)
if existing is None:
    print("VLESS_REALITY inbound not found", file=sys.stderr); sys.exit(1)
clients = [{"id": c["id"], "email": c.get("email", c["id"][:8])} for c in existing["settings"]["clients"]]
# XHTTP doesn't support xtls-rprx-vision flow; remove flow.

# Skip if already present
if any(ib.get("tag") == "VLESS_XHTTP" for ib in cfg["inbounds"]):
    print("VLESS_XHTTP already present - updating in place")
    cfg["inbounds"] = [ib for ib in cfg["inbounds"] if ib.get("tag") != "VLESS_XHTTP"]

xhttp = {
    "tag": "VLESS_XHTTP",
    "listen": "0.0.0.0",
    "port": 8444,
    "protocol": "vless",
    "settings": {
        "clients": clients,
        "decryption": "none"
    },
    "streamSettings": {
        "network": "xhttp",
        "xhttpSettings": {
            "host": "www.microsoft.com",
            "path": "/drift",
            "mode": "auto"
        },
        "security": "reality",
        "realitySettings": {
            "show": False,
            "dest": "www.microsoft.com:443",
            "xver": 0,
            "serverNames": ["www.microsoft.com"],
            "privateKey": priv,
            "shortIds": [sid]
        }
    },
    "sniffing": {"enabled": True, "destOverride": ["http", "tls"]}
}
cfg["inbounds"].append(xhttp)

tmp = path + ".tmp"
with open(tmp, "w") as f:
    json.dump(cfg, f, indent=4)
os.replace(tmp, path)
print("patched OK - inbounds:", [i["tag"] for i in cfg["inbounds"]])
PYEOF

# Validate config using the xray binary inside the container
if ! docker exec marzban xray -test -c /var/lib/marzban/xray_config.json 2>&1 | tail -5; then
    echo "[xhttp] xray -test FAILED - restoring backup"
    cp "$BACKUP" "$XRAY_JSON"
    exit 1
fi

# Restart Marzban to pick up new inbound (auto-detect compose v1/v2)
cd /opt/marzban
if docker compose version >/dev/null 2>&1; then
    DC="docker compose"
else
    DC="docker-compose"
fi
$DC restart
sleep 6
$DC ps

echo "[xhttp] waiting for xray to listen on 8444..."
for i in $(seq 1 20); do
    if ss -tlnp 2>/dev/null | grep -q ':8444'; then
        echo "[xhttp] port 8444 UP"; break
    fi
    sleep 1
done

# Verify old Reality still works
curl --resolve dl.google.com:443:127.0.0.1 -o /dev/null -sI --max-time 5 \
     -w "[reality-check] HTTP %{http_code}\n" https://dl.google.com/ || true

echo "[xhttp] DONE - PUB=$(cat /root/drift-infra/xhttp_reality.pub) SID=$(cat /root/drift-infra/xhttp_reality.sid)"
