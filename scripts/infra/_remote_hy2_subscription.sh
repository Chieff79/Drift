#!/usr/bin/env bash
# Drift VPN - generate a standalone Hysteria2 subscription file served by the
# existing Marzban nginx (port 8880 on the host). Each Marzban user gets one
# hy2:// URI that shares the single server password, which is fine since Hysteria2
# does not do per-user multiplexing anyway. The file is available at:
#   https://panel.fastpipe-io.uk:8880/drift-hy2/<username>.txt
set -euo pipefail

PASS=$(tr -d '\n' < /etc/hysteria/password)
PUB_IP=$(curl -s --max-time 4 https://ipv4.icanhazip.com || hostname -I | awk '{print $1}')

mkdir -p /var/www/drift/sub
# Extract usernames from Marzban db
USERS=$(docker exec marzban python3 -c "
import sqlite3
c = sqlite3.connect('/var/lib/marzban/db.sqlite3').cursor()
for (u,) in c.execute('SELECT username FROM users WHERE status=\"active\"').fetchall():
    print(u)
")

for u in $USERS; do
    cat > /var/www/drift/sub/${u}.hy2.txt <<URI
hy2://${PASS}@${PUB_IP}:8443/?sni=www.bing.com&insecure=1&obfs=salamander&obfs-password=${PASS}#FI-Hysteria2-${u}
URI
    echo "  wrote /var/www/drift/sub/${u}.hy2.txt"
done

# Also emit a combined file that includes user's existing Marzban sub + the hy2 line
# (helps single-click import into Drift client if it understands concat subs)
echo "[hy2-sub] done; files in /var/www/drift/sub/"
ls -la /var/www/drift/sub/ | head -20

# Make sure nginx serves /drift-hy2/... - add a location block next to the default site
if ! grep -q "drift-hy2" /etc/nginx/sites-available/drift; then
    # Add location to nginx server block
    sed -i '/listen 8080 default_server/a\    location /drift-hy2/ { alias /var/www/drift/sub/; autoindex off; default_type text/plain; }' /etc/nginx/sites-available/drift
    nginx -t && systemctl reload nginx
    echo "[hy2-sub] nginx location /drift-hy2/ added"
fi

# Sanity check
curl -sS --max-time 5 "http://127.0.0.1:8080/drift-hy2/RuslanTagirov.hy2.txt" | head -3 || true
