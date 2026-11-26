#!/usr/bin/env bash
# Ativa a atualização automática (a cada 2 minutos). Uso: sudo bash install-auto-update.sh
set -euo pipefail
[ "$(id -u)" -eq 0 ] || { echo "rode com sudo"; exit 1; }
APP=/opt/threads

cat > /etc/systemd/system/threads-update.service <<UNIT
[Unit]
Description=Threads of Mana: atualizar servidor se houver versão nova
After=network-online.target

[Service]
Type=oneshot
ExecStart=/usr/bin/env bash $APP/repo/server/auto-update.sh
UNIT

cat > /etc/systemd/system/threads-update.timer <<UNIT
[Unit]
Description=Verifica atualizações do servidor a cada 2 minutos

[Timer]
OnBootSec=2min
OnUnitActiveSec=2min
Unit=threads-update.service

[Install]
WantedBy=timers.target
UNIT

systemctl daemon-reload
systemctl enable --now threads-update.timer
echo "OK. Atualização automática ativa. Ver: journalctl -u threads-update -n 20"
