#!/usr/bin/env bash
# Drift VPN - extend Reality serverNames to enable client-side SNI rotation.
# Reality dest stays dl.google.com, but serverNames contains multiple entries.
# Xray accepts any entry from serverNames as valid SNI for the Reality handshake,
# and the dest host is still used for the fallback TLS terminator, so traffic looks
# like a connection to that SNI while actually being proxied to dl.google.com.
set -euo pipefail

XRAY_JSON=/var/lib/marzban/xray_config.json
TS=$(date +%s)
cp "$XRAY_JSON" /root/drift-infra/xray_config.json.bak-${TS}

python3 - "$XRAY_JSON" <<'PY'
import json, sys, os
path = sys.argv[1]
cfg = json.load(open(path))
target = None
for ib in cfg["inbounds"]:
    if ib.get("tag") == "VLESS_REALITY":
        target = ib; break
if target is None:
    print("VLESS_REALITY not found"); sys.exit(1)
rs = target["streamSettings"]["realitySettings"]
want = ["dl.google.com","www.microsoft.com","www.icloud.com","www.cloudflare.com"]
rs["serverNames"] = want
tmp = path + ".tmp"
json.dump(cfg, open(tmp,"w"), indent=4)
os.replace(tmp, path)
print("serverNames ->", rs["serverNames"])
PY

docker exec marzban xray -test -c /var/lib/marzban/xray_config.json | tail -3
docker restart marzban
sleep 6
ss -tlnp | grep -E ':(443|8444) ' | head -4
echo "[sni] done"
