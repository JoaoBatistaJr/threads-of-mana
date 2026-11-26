#!/usr/bin/env bash
# Verifica o GitHub; se houver commit novo na main, atualiza e reinicia o servidor.
set -euo pipefail
APP=/opt/threads
git -C "$APP/repo" fetch -q origin main
if [ "$(git -C "$APP/repo" rev-parse HEAD)" != "$(git -C "$APP/repo" rev-parse origin/main)" ]; then
  echo "[auto-update] versão nova encontrada, atualizando..."
  bash "$APP/repo/server/update.sh"
fi
