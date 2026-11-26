#!/usr/bin/env bash
# Puxa a última versão do jogo e reinicia o servidor (notebook ou VPS).
set -euo pipefail
APP_DIR=/opt/threads
git -C "$APP_DIR/repo" pull --ff-only
# duas passadas: a 1ª registra class_name novos, a 2ª compila os scripts que os usam
"$APP_DIR/bin/godot" --headless --path "$APP_DIR/repo/game" --import || true
"$APP_DIR/bin/godot" --headless --path "$APP_DIR/repo/game" --import || true
systemctl restart threads-server
systemctl --no-pager status threads-server | head -5
