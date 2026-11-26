#!/usr/bin/env bash
# Menu gráfico do servidor (Linux Mint). Uso:
#   bash mana.sh                    abre o menu
#   bash mana.sh --instalar-atalho  cria o ícone "Servidor Mana" na área de trabalho e no menu
set -u
APP=/opt/threads
DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [ "${1:-}" = "--instalar-atalho" ]; then
  mkdir -p "$HOME/.local/share/applications" "$HOME/Área de trabalho" "$HOME/Desktop"
  F="$HOME/.local/share/applications/servidor-mana.desktop"
  cat > "$F" <<DESK
[Desktop Entry]
Type=Application
Name=Servidor Mana
Comment=Atualizar, reiniciar e ver o servidor de Threads of Mana
Exec=bash "$DIR/mana.sh"
Icon=network-server
Terminal=false
Categories=Utility;
DESK
  chmod +x "$F"
  for d in "$HOME/Área de trabalho" "$HOME/Desktop"; do [ -d "$d" ] && cp "$F" "$d/" && chmod +x "$d/servidor-mana.desktop"; done
  zenity --info --text="Atalho 'Servidor Mana' criado (menu e área de trabalho)." 2>/dev/null || echo "Atalho criado."
  exit 0
fi

run_root() { pkexec bash -c "$1" 2>&1; }

while true; do
  OP=$(zenity --list --title="Servidor Mana" --text="O que deseja fazer?" \
    --column="Ação" "Ver estado" "Atualizar jogo (baixa a versão nova e reinicia)" "Reiniciar servidor" "Ativar atualização automática" "Ver últimos logs" "Sair" \
    --width=460 --height=330 2>/dev/null) || exit 0
  case "$OP" in
    "Ver estado")
      zenity --info --width=460 --text="$(systemctl is-active threads-server | sed 's/^/Servidor: /')\n$(systemctl is-active playit | sed 's/^/Túnel (playit): /')\n\n$(journalctl -u threads-server --no-pager -n 40 | grep -E '\+|\-[0-9]' | tail -4)" ;;
    "Atualizar"*)
      OUT=$(run_root "bash $APP/repo/server/update.sh")
      zenity --text-info --title="Atualização" --width=560 --height=320 <<<"$OUT" ;;
    "Reiniciar servidor")
      run_root "systemctl restart threads-server" >/dev/null
      zenity --info --text="Servidor reiniciado." ;;
    "Ativar atualização automática")
      OUT=$(run_root "bash $APP/repo/server/install-auto-update.sh")
      zenity --info --width=460 --text="$OUT" ;;
    "Ver últimos logs")
      journalctl -u threads-server --no-pager -n 60 | zenity --text-info --title="Logs do servidor" --width=760 --height=480 ;;
    *) exit 0 ;;
  esac
done
