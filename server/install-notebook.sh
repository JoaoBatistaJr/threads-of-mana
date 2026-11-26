#!/usr/bin/env bash
# Servidor dedicado em notebook Linux (Mint/Ubuntu/Debian, x86_64). Uso:
#   sudo bash install-notebook.sh
# Instala o Godot, prepara o serviço (inicia com o notebook, reinicia se travar),
# impede suspensão ao fechar a tampa e desliga a economia de energia do Wi-Fi.
set -euo pipefail

[ "$(id -u)" -eq 0 ] || { echo "rode com sudo"; exit 1; }
[ "$(uname -m)" = "x86_64" ] || { echo "este script é para x86_64"; exit 1; }

GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
APP_DIR=/opt/threads
REPO_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PORT="${PORT:-7777}"
ENV_FILE=/etc/threads/server.env

apt-get update -y
apt-get install -y git unzip curl ca-certificates libfontconfig1

# --- Godot (sem tela) ---
mkdir -p "$APP_DIR/bin"
if [ ! -x "$APP_DIR/bin/godot" ]; then
  curl -fsSL -o /tmp/godot.zip \
    "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip"
  unzip -oq /tmp/godot.zip -d "$APP_DIR/bin"
  mv "$APP_DIR/bin/Godot_v${GODOT_VERSION}-stable_linux.x86_64" "$APP_DIR/bin/godot"
  chmod +x "$APP_DIR/bin/godot"
fi

# --- repositório usado pelo serviço (cópia própria, separada da sua pasta) ---
if [ ! -d "$APP_DIR/repo/.git" ]; then
  git clone "$(git -C "$REPO_DIR" remote get-url origin)" "$APP_DIR/repo"
fi
"$APP_DIR/bin/godot" --headless --path "$APP_DIR/repo/game" --import || true

# --- segredos do status (ficam só neste arquivo, nunca no repositório) ---
mkdir -p /etc/threads
if [ ! -f "$ENV_FILE" ]; then
  read -rp "URL do status (a mesma do --status-url do seu PC): " STATUS_URL
  read -rsp "Senha do status (a mesma do --status-key; não aparece ao digitar): " STATUS_KEY; echo
  printf 'STATUS_URL=%s\nSTATUS_KEY=%s\n' "$STATUS_URL" "$STATUS_KEY" > "$ENV_FILE"
  chmod 600 "$ENV_FILE"
fi

# --- serviço ---
cat > /etc/systemd/system/threads-server.service <<UNIT
[Unit]
Description=Threads of Mana game server
After=network-online.target
Wants=network-online.target

[Service]
EnvironmentFile=$ENV_FILE
ExecStart=$APP_DIR/bin/godot --headless --path $APP_DIR/repo/game -- --server --port=$PORT --status-url=\${STATUS_URL} --status-key=\${STATUS_KEY}
Restart=always
RestartSec=3

[Install]
WantedBy=multi-user.target
UNIT

# --- notebook como servidor: não suspender, não desligar o Wi-Fi ---
mkdir -p /etc/systemd/logind.conf.d
cat > /etc/systemd/logind.conf.d/threads-lid.conf <<CONF
[Login]
HandleLidSwitch=ignore
HandleLidSwitchExternalPower=ignore
HandleLidSwitchDocked=ignore
CONF
systemctl mask sleep.target suspend.target hibernate.target hybrid-sleep.target >/dev/null
mkdir -p /etc/NetworkManager/conf.d
printf '[connection]\nwifi.powersave = 2\n' > /etc/NetworkManager/conf.d/threads-wifi-powersave.conf

systemctl daemon-reload
systemctl enable --now threads-server
systemctl restart systemd-logind || true
echo
echo "OK. Servidor ativo. Ver log:   journalctl -u threads-server -f"
echo "Atualizar versão:              sudo bash $APP_DIR/repo/server/update.sh"
