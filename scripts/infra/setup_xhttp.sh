#!/usr/bin/env bash
# Drift VPN - orchestrator: add VLESS+XHTTP+Reality inbound on :8444 TCP to
# the Marzban host. Runs in parallel with the existing :443 Reality inbound
# without touching it. Also registers a named host in Marzban via the API
# and adds multi-SNI support to the original Reality inbound.
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
HOST=${DRIFT_MARZBAN_HOST:-204.168.221.28}
PASS=${DRIFT_MARZBAN_PASS:-DriftHetzner2024!}
PANEL=${DRIFT_MARZBAN_PANEL:-https://panel.fastpipe-io.uk:8880}
ADMIN_USER=${DRIFT_MARZBAN_ADMIN:-admin}
ADMIN_PASS=${DRIFT_MARZBAN_ADMIN_PASS:-DriftAdmin2024}

echo "[*] Uploading remote scripts ..."
expect -f "$HERE/_scp_upload.exp" "$HOST" "$PASS" \
       "$HERE/_remote_setup_xhttp.sh" /root/drift-infra/setup_xhttp.sh
expect -f "$HERE/_scp_upload.exp" "$HOST" "$PASS" \
       "$HERE/_remote_add_reality_snis.sh" /root/drift-infra/add_reality_snis.sh

echo "[*] Installing XHTTP inbound on $HOST ..."
expect -f "$HERE/_ssh_exec.exp" "$HOST" "$PASS" \
       "mkdir -p /root/drift-infra && bash /root/drift-infra/setup_xhttp.sh"

echo "[*] Extending Reality serverNames ..."
expect -f "$HERE/_ssh_exec.exp" "$HOST" "$PASS" \
       "bash /root/drift-infra/add_reality_snis.sh"

echo "[*] Registering FI XHTTP host in Marzban panel ..."
python3 - "$PANEL" "$ADMIN_USER" "$ADMIN_PASS" "$HOST" <<'PY'
import urllib.request, urllib.parse, ssl, json, sys
panel, user, pw, host = sys.argv[1:5]
ctx = ssl.create_default_context(); ctx.check_hostname=False; ctx.verify_mode=ssl.CERT_NONE
def auth():
    data = urllib.parse.urlencode({'username':user,'password':pw}).encode()
    r = urllib.request.urlopen(urllib.request.Request(f'{panel}/api/admin/token',data=data,method='POST'),timeout=15,context=ctx)
    return json.loads(r.read().decode())['access_token']
tok = auth()
def req(path, method='GET', body=None):
    h = {'Authorization':f'Bearer {tok}'}
    d = None
    if body is not None: h['Content-Type']='application/json'; d=json.dumps(body).encode()
    return urllib.request.urlopen(urllib.request.Request(f'{panel}{path}',headers=h,method=method,data=d),timeout=15,context=ctx).read().decode()
hosts = json.loads(req('/api/hosts'))
entry = {
    "remark": "\U0001F1EB\U0001F1EE FI XHTTP ({USERNAME})",
    "address": host, "port": 8444,
    "sni": "www.microsoft.com", "host": "www.microsoft.com",
    "path": "/drift", "security": "inbound_default",
    "alpn": "", "fingerprint": "chrome",
    "allowinsecure": False, "is_disabled": False,
    "mux_enable": False, "fragment_setting": "",
    "noise_setting": "", "random_user_agent": True,
    "use_sni_as_host": False
}
xhttp = [h for h in hosts.get('VLESS_XHTTP',[]) if 'FI XHTTP' in h.get('remark','')]
xhttp.append(entry) if not xhttp else None
hosts['VLESS_XHTTP'] = xhttp or [entry]
print(req('/api/hosts', method='PUT', body=hosts)[:100])
PY

echo "[*] XHTTP inbound deployed. Verify:"
echo "    - external port open:   nc -zv $HOST 8444"
echo "    - Marzban inbound list: curl -sk '$PANEL/api/inbounds' -H 'Authorization: Bearer <TOKEN>'"
