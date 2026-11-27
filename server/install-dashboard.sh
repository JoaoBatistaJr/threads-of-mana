#!/usr/bin/env bash
# Instala o painel do servidor. Uso: sudo bash install-dashboard.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "rode com sudo"; exit 1; }
APP=/opt/threads
mkdir -p /etc/threads
[ -s /etc/threads/dashboard.token ] || head -c 18 /dev/urandom | base64 | tr '+/' 'ab' > /etc/threads/dashboard.token
chmod 644 /etc/threads/dashboard.token
cat > /etc/systemd/system/threads-dashboard.service <<UNIT
[Unit]
Description=Threads of Mana: painel do servidor
After=network-online.target

[Service]
ExecStart=/usr/bin/python3 $APP/repo/server/dashboard.py
Restart=always
RestartSec=2

[Install]
WantedBy=multi-user.target
UNIT
systemctl daemon-reload
systemctl enable --now threads-dashboard
systemctl restart threads-dashboard
IP=$(hostname -I | awk '{print $1}')
echo "Painel: http://$IP:8787/#$(cat /etc/threads/dashboard.token)"
