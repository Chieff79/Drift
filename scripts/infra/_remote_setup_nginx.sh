#!/usr/bin/env bash
# Drift VPN — nginx fallback website (anti-probing) on :8080 (HTTP) and :4443 (HTTPS).
# Runs ON the Marzban host (204.168.221.28 / drift-exit-1).
# Idempotent: can be re-run safely.
set -euo pipefail

TS=$(date +%s)
BACKUP=/root/drift-infra-backup-${TS}
mkdir -p "$BACKUP"

echo "[nginx] Installing..."
if ! command -v nginx >/dev/null 2>&1; then
    DEBIAN_FRONTEND=noninteractive apt-get update -qq
    DEBIAN_FRONTEND=noninteractive apt-get install -y -qq nginx
fi

# Preserve original default
if [ -f /etc/nginx/sites-enabled/default ]; then
    cp /etc/nginx/sites-enabled/default "$BACKUP/" || true
    rm -f /etc/nginx/sites-enabled/default
fi

# Marketing page - looks like a real product site
mkdir -p /var/www/drift
cat >/var/www/drift/index.html <<'HTML'
<!DOCTYPE html>
<html lang="en"><head><meta charset="utf-8"><title>Drift Speed Test</title>
<meta name="viewport" content="width=device-width,initial-scale=1">
<meta name="description" content="Drift network performance analyzer. Run latency and throughput tests from any location.">
<style>
*{box-sizing:border-box;margin:0;padding:0}body{font-family:-apple-system,BlinkMacSystemFont,"Segoe UI",Roboto,sans-serif;background:#0b1320;color:#e8edf5;line-height:1.6}
header{padding:60px 20px 20px;text-align:center;border-bottom:1px solid #1d2a44}
h1{font-size:2.4rem;font-weight:600;background:linear-gradient(90deg,#5b8def,#6fe8a3);-webkit-background-clip:text;-webkit-text-fill-color:transparent}
.sub{margin-top:12px;color:#8aa0c4;font-size:1.05rem}
.wrap{max-width:880px;margin:40px auto;padding:0 20px}
.card{background:#121c32;border:1px solid #1f2d4d;border-radius:14px;padding:28px;margin-bottom:20px;box-shadow:0 4px 20px rgba(0,0,0,.25)}
.card h2{font-size:1.25rem;color:#e8edf5;margin-bottom:10px}
.card p{color:#a9b8d4;font-size:.98rem}
.metric{display:inline-block;padding:8px 14px;background:#1b2a47;border-radius:8px;margin:6px 8px 0 0;color:#6fe8a3;font-variant-numeric:tabular-nums}
.btn{display:inline-block;margin-top:18px;padding:12px 24px;background:#5b8def;color:#fff;border-radius:8px;text-decoration:none;font-weight:500}
.btn:hover{background:#4676df}
footer{text-align:center;padding:40px 20px;color:#647aa0;font-size:.85rem;border-top:1px solid #1d2a44;margin-top:40px}
</style></head>
<body>
<header>
<h1>Drift Speed Test</h1>
<div class="sub">Independent network-performance analyzer</div>
</header>
<div class="wrap">
  <div class="card">
    <h2>Live diagnostics</h2>
    <p>Measure latency, jitter, and throughput between your device and our global edge locations.</p>
    <div class="metric">ping 12 ms</div>
    <div class="metric">down 482 Mbps</div>
    <div class="metric">up 118 Mbps</div>
    <a class="btn" href="/run">Run a test</a>
  </div>
  <div class="card">
    <h2>Global coverage</h2>
    <p>Test nodes in FI, DE, NL, US, and more. Consistent, reproducible measurements for any route.</p>
  </div>
  <div class="card">
    <h2>API access</h2>
    <p>Programmatic access via JSON — rate-limited, no signup required for basic queries.</p>
  </div>
</div>
<footer>(c) Drift Labs - driftspeed.example - performance research only</footer>
</body></html>
HTML

# Healthcheck endpoint (for curl tests)
echo "ok" >/var/www/drift/health

# Pick a free TLS cert we already have - use Marzban self-signed so Xray fallback also has TLS if ever needed
CERT=/var/lib/marzban/cert.pem
KEY=/var/lib/marzban/key.pem

cat >/etc/nginx/sites-available/drift <<NGINX
server {
    listen 8080 default_server;
    listen [::]:8080 default_server;
    server_name _;
    root /var/www/drift;
    index index.html;
    access_log /var/log/nginx/drift_access.log;
    error_log  /var/log/nginx/drift_error.log;
    location = /health { return 200 "ok\n"; add_header Content-Type text/plain; }
    location / { try_files \$uri \$uri/ =404; }
}

server {
    listen 127.0.0.1:4443 ssl http2;
    server_name _;
    ssl_certificate     ${CERT};
    ssl_certificate_key ${KEY};
    ssl_protocols TLSv1.2 TLSv1.3;
    root /var/www/drift;
    index index.html;
    location / { try_files \$uri \$uri/ =404; }
}
NGINX

ln -sf /etc/nginx/sites-available/drift /etc/nginx/sites-enabled/drift

# Verify that our custom config does not conflict with Marzban nginx on 8880
nginx -t

# If nginx is already running, reload; otherwise start
if systemctl is-active --quiet nginx; then
    systemctl reload nginx
else
    systemctl enable --now nginx
fi

echo "[nginx] Done. Testing..."
sleep 1
curl -sS --max-time 5 http://127.0.0.1:8080/health && echo
curl -sS --max-time 5 http://127.0.0.1:8080/ -o /dev/null -w "HTTP %{http_code}, %{size_download} bytes\n"
curl -sSk --max-time 5 https://127.0.0.1:4443/ -o /dev/null -w "HTTPS %{http_code}\n"
echo "[nginx] OK - backup at $BACKUP"
