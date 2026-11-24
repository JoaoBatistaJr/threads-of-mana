# Threads of Mana

- `game/` jogo (Godot 4.7) · `launcher/` auto-update · `site/` página · `server/` scripts da VM
- Dev no editor: Debug > Customize Run Instances > 2-3 instâncias; instância 1 com Launch Arguments `--server`; as demais com `--name=Fulano --address=127.0.0.1` (pula o menu)
- Servidor headless: `godot --headless --path game -- --server --port=7777`
- Bots de carga/teste: `godot --headless --path game -- --bot --quit-after=30 [--loss=0.15]`
- Release: `git tag v0.1.0 && git push origin v0.1.0`
