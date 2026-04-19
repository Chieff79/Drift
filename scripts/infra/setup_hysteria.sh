#!/usr/bin/env bash
# Drift VPN - orchestrator: install and configure Hysteria2 server on UDP :8443
# (does not conflict with Marzban's TCP :8443 uvicorn). Masquerades as
# https://www.bing.com. Generates per-user hy2:// subscription files served
# by the drift nginx at /drift-hy2/<username>.hy2.txt.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST=${DRIFT_MARZBAN_HOST:-204.168.221.28}
PASS=${DRIFT_MARZBAN_PASS:-DriftHetzner2024!}

echo "[*] Uploading remote scripts ..."
expect -f "$HERE/_scp_upload.exp" "$HOST" "$PASS" \
       "$HERE/_remote_setup_hysteria.sh"    /root/drift-infra/setup_hysteria.sh
expect -f "$HERE/_scp_upload.exp" "$HOST" "$PASS" \
       "$HERE/_remote_hy2_subscription.sh"  /root/drift-infra/hy2_subscription.sh

echo "[*] Installing Hysteria2 on $HOST ..."
expect -f "$HERE/_ssh_exec.exp" "$HOST" "$PASS" \
       "mkdir -p /root/drift-infra && bash /root/drift-infra/setup_hysteria.sh"

echo "[*] Generating per-user hy2 subscription files ..."
expect -f "$HERE/_ssh_exec.exp" "$HOST" "$PASS" \
       "bash /root/drift-infra/hy2_subscription.sh"

echo "[*] Hysteria2 deployed. Per-user subs:"
echo "    http://${HOST}:8080/drift-hy2/<username>.hy2.txt"
