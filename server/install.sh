#!/usr/bin/env bash
# Ubuntu (Oracle Cloud Always Free, x86_64 ou ARM). Uso: sudo bash install.sh <url-do-repo-git>
set -euo pipefail

REPO_URL="${1:?uso: install.sh <url-do-repo-git>}"
GODOT_VERSION="${GODOT_VERSION:-4.7.2}"
APP_DIR=/opt/threads
PORT="${PORT:-7777}"

apt-get update -y && apt-get install -y git unzip curl ca-certificates

case "$(uname -m)" in
  x86_64)  ARCH=linux.x86_64 ;;
  aarch64) ARCH=linux.arm64 ;;
  *) echo "arquitetura não suportada"; exit 1 ;;
esac

mkdir -p "$APP_DIR/bin"
curl -fsSL -o /tmp/godot.zip \
  "https://github.com/godotengine/godot-builds/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_${ARCH}.zip"
unzip -oq /tmp/godot.zip -d "$APP_DIR/bin"
mv "$APP_DIR/bin/Godot_v${GODOT_VERSION}-stable_${ARCH}" "$APP_DIR/bin/godot"
chmod +x "$APP_DIR/bin/godot"

[ -d "$APP_DIR/repo/.git" ] || git clone "$REPO_URL" "$APP_DIR/repo"
"$APP_DIR/bin/godot" --headless --path "$APP_DIR/repo/game" --import || true

cat > /etc/systemd/system/threads-server.service <<EOF
[Unit]
Description=Threads of Mana game server
After=network-online.target

[Service]
ExecStart=$APP_DIR/bin/godot --headless --path $APP_DIR/repo/game -- --server --port=$PORT
Restart=always
RestartSec=3
User=root

[Install]
WantedBy=multi-user.target
EOF

# libera UDP no firewall da VM (também libere UDP $PORT na Security List da Oracle)
iptables -I INPUT -p udp --dport "$PORT" -j ACCEPT || true

systemctl daemon-reload
systemctl enable --now threads-server
echo "OK. Atualizar servidor: sudo bash $APP_DIR/repo/server/update.sh"
