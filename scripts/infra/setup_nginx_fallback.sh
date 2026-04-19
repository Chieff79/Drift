#!/usr/bin/env bash
# Drift VPN - orchestrator: deploy nginx fallback (anti-probing marketing site)
# to the Marzban host. Usage: ./setup_nginx_fallback.sh
#
# Nginx listens on :8080 (HTTP) externally and 127.0.0.1:4443 (HTTPS, for
# optional Xray fallback). A small marketing page is served at / to look
# like a legitimate speed-test product.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST=${DRIFT_MARZBAN_HOST:-204.168.221.28}
PASS=${DRIFT_MARZBAN_PASS:-DriftHetzner2024!}

echo "[*] Uploading remote script to $HOST ..."
expect -f "$HERE/_scp_upload.exp" "$HOST" "$PASS" \
       "$HERE/_remote_setup_nginx.sh" /root/drift-infra/setup_nginx.sh

echo "[*] Running on host ..."
expect -f "$HERE/_ssh_exec.exp" "$HOST" "$PASS" \
       "mkdir -p /root/drift-infra && bash /root/drift-infra/setup_nginx.sh"

echo "[*] Done. Verify:"
echo "    curl http://${HOST}:8080/ | head -5"
echo "    curl http://${HOST}:8080/health"
