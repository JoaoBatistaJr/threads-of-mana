class_name MenuWindow
extends GameWindow

# Janela única do jogo (como no offline): abas Inventário, Criação, Personagem, Mapa, Habilidades,
# Missões e Códex. Cada atalho abre a aba; Q/E trocam de aba. Abas sem conteúdo mostram "Em breve".

signal tab_changed(id: String)

var _tab_bar := HBoxContainer.new()
var _stack := Control.new()
var _tabs: Dictionary = {}      # id -> {"label", "key", "content", "button"}
var _order: Array = []
var current := ""


func _init() -> void:
	super("Menu", Vector2(980, 630))
	theme = UiTheme.make_theme()
	_tab_bar.add_theme_constant_override("separation", 4)
	body.add_child(_tab_bar)
	body.add_child(UiTheme.rule())
	_stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_stack.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_child(_stack)


func add_tab(id: String, label: String, key: String, content: Control = null) -> void:
	if content == null:
		var l := Label.new()
		l.text = "Em breve"
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		l.add_theme_color_override("font_color", UiTheme.MUTED)
		content = l
	content.set_anchors_preset(Control.PRESET_FULL_RECT)
	content.visible = false
	_stack.add_child(content)
	var b := Button.new()
	b.text = "%s [%s]" % [label, key]
	UiTheme.style_tab(b, 15)
	b.pressed.connect(show_tab.bind(id))
	_tab_bar.add_child(b)
	_tabs[id] = {"label": label, "key": key, "content": content, "button": b}
	_order.append(id)


func show_tab(id: String) -> void:
	if not _tabs.has(id):
		return
	current = id
	for k in _tabs:
		_tabs[k]["content"].visible = k == id
		_tabs[k]["button"].button_pressed = k == id
	set_title(_tabs[id]["label"])
	tab_changed.emit(id)


# Atalho de uma aba: abre a janela nela; se já está nela, fecha.
func toggle_tab(id: String) -> void:
	if visible and current == id:
		close()
		return
	show_tab(id)
	if not visible:
		open()


func step(dir: int) -> void:
	if _order.is_empty():
		return
	var i := _order.find(current)
	show_tab(_order[posmod(i + dir, _order.size())])
