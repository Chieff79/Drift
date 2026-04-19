Drift VPN - server-side infrastructure scripts
===============================================

These scripts deploy anti-TSPU-AI transports (VLESS+XHTTP, Hysteria2) and
an anti-probing fallback website to the Marzban host.

Target host
-----------
  204.168.221.28  (hostname: drift-exit-1, Hetzner Helsinki)
  root password:  DriftHetzner2024!  (overrideable via DRIFT_MARZBAN_PASS)

Public-facing name `fi.fastpipe-io.uk` resolves to 62.238.13.230 which is a
pure :443 port-forwarder to the Helsinki box. The actual Xray and Marzban run
on 204.168.221.28. Ports above :443 (e.g. :8444, :8443/udp, :8080) are only
reachable via 204.168.221.28 directly until the forwarder is extended.

Top-level orchestrators (run from macOS)
----------------------------------------
  setup_nginx_fallback.sh  - installs nginx, marketing page on :8080.
  setup_xhttp.sh           - adds VLESS+XHTTP+Reality inbound on :8444,
                             extends Reality serverNames for SNI rotation,
                             registers FI XHTTP host in Marzban.
  setup_hysteria.sh        - installs Hysteria2 on :8443/UDP, generates
                             per-user hy2:// subscription files.

Internal helpers
----------------
  _ssh_exec.exp              - expect wrapper for password-auth SSH.
  _scp_upload.exp            - expect wrapper for password-auth SCP.
  _remote_setup_nginx.sh     - deployed to host, sets up nginx + site.
  _remote_setup_xhttp.sh     - deployed to host, patches xray_config.json.
  _remote_add_reality_snis.sh- deployed to host, multi-SNI for Reality.
  _remote_setup_hysteria.sh  - deployed to host, installs & configures hy2.
  _remote_hy2_subscription.sh- deployed to host, writes per-user hy2 subs.

Current Marzban state after deployment
--------------------------------------
  inbounds (via `/api/inbounds`):
    - VLESS_REALITY  tcp  :443   reality (dl.google.com + 3 extra SNIs)
    - VLESS_XHTTP    xhttp :8444 reality (www.microsoft.com)

  Reality #1 key (legacy):
    pbk=BFolChuBHr1s8nRwszhgE8Fj910LaPoG0qXQbQfbLgI  sid=4f41bcdd3f7772e1

  Reality #2 key (new XHTTP):
    pbk=JYouevtQFyq26fL9HFoccMvNNtIZmgVSf12TZs0VaTI  sid=ffd7311ea64a9e50
    (saved on host at /root/drift-infra/xhttp_reality.{priv,pub,sid})

  Hysteria2 password: see /etc/hysteria/password on the host (derived from
  the xray UUID list hash so it's reproducible). Single shared password by
  design - hy2 doesn't multiplex per-user anyway.

Backups
-------
  Every remote script snapshots /var/lib/marzban/xray_config.json to
  /root/drift-infra/xray_config.json.bak-<epoch> before patching.

Env vars recognised by orchestrators
------------------------------------
  DRIFT_MARZBAN_HOST, DRIFT_MARZBAN_PASS,
  DRIFT_MARZBAN_PANEL, DRIFT_MARZBAN_ADMIN, DRIFT_MARZBAN_ADMIN_PASS
