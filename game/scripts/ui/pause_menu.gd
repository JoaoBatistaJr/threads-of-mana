class_name PauseMenu
extends GameWindow

# Menu de pausa dentro do jogo (Esc). O mundo continua rodando (é online).

signal resume
signal settings
signal leave
signal quit_game


func _init() -> void:
	super("Menu", Vector2(300, 0))
	theme = UiTheme.make_theme()
	for item in [["Continuar", resume], ["Configurações", settings], ["Voltar ao menu", leave], ["Sair do jogo", quit_game]]:
		var b := Button.new()
		b.text = item[0]
		b.custom_minimum_size.y = 42
		b.pressed.connect(item[1].emit)
		body.add_child(b)
	closed.connect(resume.emit)
