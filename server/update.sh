#!/usr/bin/env bash
# Puxa a última versão do jogo e reinicia o servidor.
set -euo pipefail
APP_DIR=/opt/threads
git -C "$APP_DIR/repo" pull --ff-only
"$APP_DIR/bin/godot" --headless --path "$APP_DIR/repo/game" --import || true
systemctl restart threads-server
systemctl --no-pager status threads-server | head -5
