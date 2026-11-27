class_name SettingsWindow
extends GameWindow

# Janela de configurações (título, jogo e menu de pausa). Aplica e salva a cada mudança.

const FPS_CAPS := [0, 30, 60, 120, 144, 240]
const SCALES := [0.5, 0.75, 1.0]

var _tabs := HBoxContainer.new()
var _page := VBoxContainer.new()
var _tab_btns: Array[Button] = []
var _cur := 0


func _init() -> void:
	super("Configurações", Vector2(520, 420))
	theme = UiTheme.make_theme()
	_tabs.add_theme_constant_override("separation", 6)
	body.add_child(_tabs)
	_page.add_theme_constant_override("separation", 12)
	_page.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(_page)
	var names := ["Vídeo", "Áudio", "Jogo", "Controles"]
	for i in names.size():
		var b := Button.new()
		b.text = names[i]
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_show_tab.bind(i))
		_tabs.add_child(b)
		_tab_btns.append(b)
	var foot := HBoxContainer.new()
	var reset := Button.new()
	reset.text = "Restaurar padrão"
	reset.pressed.connect(func():
		Settings.reset()
		_show_tab(_cur))
	foot.add_child(reset)
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	foot.add_child(sp)
	var ok := Button.new()
	ok.text = "Fechar"
	ok.pressed.connect(close)
	foot.add_child(ok)
	body.add_child(foot)
	_show_tab(0)


func open() -> void:
	_show_tab(_cur)
	super.open()


func _show_tab(i: int) -> void:
	_cur = i
	for k in _tab_btns.size():
		_tab_btns[k].button_pressed = (k == i)
	for c in _page.get_children():
		_page.remove_child(c)
		c.queue_free()
	match i:
		0:
			_choice("Modo de tela", ["Janela", "Tela cheia"], 1 if Settings.get_value("fullscreen") else 0,
				func(v): Settings.set_value("fullscreen", v == 1))
			_toggle("Sincronia vertical (VSync)", "vsync")
			_choice("Limite de FPS", ["Ilimitado", "30", "60", "120", "144", "240"],
				maxi(FPS_CAPS.find(int(Settings.get_value("fps_cap"))), 0),
				func(v): Settings.set_value("fps_cap", FPS_CAPS[v]))
			_choice("Escala de renderização 3D", ["50%", "75%", "100%"],
				maxi(SCALES.find(float(Settings.get_value("scale3d"))), 2),
				func(v): Settings.set_value("scale3d", SCALES[v]))
			_note("F11 alterna entre janela e tela cheia.")
		1:
			_slider("Volume geral", "vol_master", 0.0, 1.0)
			_slider("Música", "vol_music", 0.0, 1.0)
			_slider("Efeitos", "vol_sfx", 0.0, 1.0)
		2:
			_slider("Sensibilidade da câmera", "sens", 0.3, 2.5)
			_toggle("Mostrar FPS", "show_fps")
			_choice("Idioma", ["Português (Brasil)"], 0, func(_v): pass)
		3:
			for row in [["Andar", "W A S D"], ["Correr", "Shift"], ["Pular", "Espaço"], ["Câmera", "Mouse (clique para capturar)"],
					["Coletar", "E"], ["Inventário", "I"], ["Abrir bolsa", "F"], ["Soltar o mouse / menu", "Esc"],
					["Tela cheia", "F11"], ["Depuração", "F3"]]:
				var r := HBoxContainer.new()
				var a := Label.new()
				a.text = row[0]
				a.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				r.add_child(a)
				var b := Label.new()
				b.text = row[1]
				b.add_theme_color_override("font_color", UiTheme.GOLD)
				r.add_child(b)
				_page.add_child(r)
			_note("Remapear teclas virá numa próxima versão.")
	_fit.call_deferred()


func _row(label: String, control: Control) -> void:
	var r := HBoxContainer.new()
	var l := Label.new()
	l.text = label
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	r.add_child(l)
	r.add_child(control)
	_page.add_child(r)


func _toggle(label: String, key: String) -> void:
	var c := CheckButton.new()
	c.button_pressed = bool(Settings.get_value(key))
	c.focus_mode = Control.FOCUS_NONE
	c.toggled.connect(func(on): Settings.set_value(key, on))
	_row(label, c)


func _choice(label: String, items: Array, selected: int, on_pick: Callable) -> void:
	var o := OptionButton.new()
	for it in items:
		o.add_item(str(it))
	o.select(selected)
	o.focus_mode = Control.FOCUS_NONE
	o.item_selected.connect(func(i): on_pick.call(i))
	_row(label, o)


func _slider(label: String, key: String, lo: float, hi: float) -> void:
	var box := HBoxContainer.new()
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = 0.01
	s.value = float(Settings.get_value(key))
	s.custom_minimum_size = Vector2(200, 24)
	s.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	s.focus_mode = Control.FOCUS_NONE
	var val := Label.new()
	val.custom_minimum_size.x = 48
	val.text = "%d%%" % roundi(s.value * 100.0)
	s.value_changed.connect(func(v):
		val.text = "%d%%" % roundi(v * 100.0)
		Settings.set_value(key, v))
	box.add_child(s)
	box.add_child(val)
	_row(label, box)


func _note(text: String) -> void:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	_page.add_child(l)
