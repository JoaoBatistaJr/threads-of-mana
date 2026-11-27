class_name TitleScreen
extends Control

# Tela inicial: status do servidor, login (em breve) e entrada como convidado.

signal guest_requested
signal settings_requested
signal quit_requested

var _srv := Label.new()
var _msg := Label.new()
var _http := HTTPRequest.new()
var _timer := Timer.new()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = UiTheme.make_theme()

	var bg := TextureRect.new()
	bg.texture = load("res://assets/ui/bg.jpg")
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	add_child(bg)
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.04, 0.09, 0.62)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var col := VBoxContainer.new()
	col.custom_minimum_size.x = 360
	col.add_theme_constant_override("separation", 14)
	center.add_child(col)

	var title := Label.new()
	title.text = "Threads of Mana"
	title.add_theme_font_override("font", UiTheme.title_font())
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", UiTheme.GOLD)
	title.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.8))
	title.add_theme_constant_override("outline_size", 8)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(title)
	var sub := Label.new()
	sub.text = "Pré-Alpha"
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(sub)
	col.add_child(_gap(10))

	var srv := PanelContainer.new()
	_srv.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_srv.text = "%s · consultando…" % Const.SERVER_NAME
	srv.add_child(_srv)
	col.add_child(srv)

	var login := PanelContainer.new()
	col.add_child(login)
	var lv := VBoxContainer.new()
	lv.add_theme_constant_override("separation", 8)
	login.add_child(lv)
	for ph in ["Usuário", "Senha"]:
		var le := LineEdit.new()
		le.placeholder_text = ph
		le.secret = (ph == "Senha")
		le.editable = false
		le.focus_mode = Control.FOCUS_NONE
		lv.add_child(le)
	var enter := Button.new()
	enter.text = "Entrar"
	enter.disabled = true
	enter.tooltip_text = "Contas chegam em breve"
	lv.add_child(enter)
	var soon := Label.new()
	soon.text = "Login com conta em breve."
	soon.add_theme_color_override("font_color", UiTheme.MUTED)
	soon.add_theme_font_size_override("font_size", 12)
	soon.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lv.add_child(soon)

	var guest := Button.new()
	guest.text = "Jogar como convidado"
	guest.custom_minimum_size.y = 48
	guest.add_theme_font_size_override("font_size", 18)
	guest.pressed.connect(guest_requested.emit)
	col.add_child(guest)

	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	col.add_child(row)
	var cfg := Button.new()
	cfg.text = "Configurações"
	cfg.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cfg.pressed.connect(settings_requested.emit)
	row.add_child(cfg)
	var quit := Button.new()
	quit.text = "Sair"
	quit.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quit.pressed.connect(quit_requested.emit)
	row.add_child(quit)

	_msg.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_msg.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_msg.add_theme_color_override("font_color", Color(0.85, 0.54, 0.54))
	col.add_child(_msg)

	add_child(_http)
	_http.request_completed.connect(_on_status)
	_timer.wait_time = 15.0
	_timer.autostart = true
	_timer.timeout.connect(_refresh)
	add_child(_timer)
	_refresh()


func set_message(text: String) -> void:
	_msg.text = text


func _gap(h: float) -> Control:
	var c := Control.new()
	c.custom_minimum_size.y = h
	return c


func _refresh() -> void:
	if _http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_http.request(Const.STATUS_URL, ["Cache-Control: no-cache"])


func _on_status(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var d = null
	if result == OK and code == 200:
		d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		_srv.text = "%s · indisponível" % Const.SERVER_NAME
		_srv.add_theme_color_override("font_color", UiTheme.MUTED)
	elif bool(d.get("online", false)):
		_srv.text = "%s · Online · %d/%d jogadores" % [Const.SERVER_NAME, int(d.get("players", 0)), int(d.get("max", 0))]
		_srv.add_theme_color_override("font_color", Color(0.56, 0.78, 0.60))
	else:
		_srv.text = "%s · Offline" % Const.SERVER_NAME
		_srv.add_theme_color_override("font_color", Color(0.85, 0.54, 0.54))
