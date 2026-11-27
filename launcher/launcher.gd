extends Control

# Fluxo: lê server.json do repositório (endereço do servidor) -> consulta a última release ->
# compara com version.txt local -> baixa game-windows.zip se mudou -> extrai -> libera "Jogar".
# Args opcionais (testes): --cfg=URL --api=URL --dir=PASTA --exe=ARQUIVO --auto

const REPO := "JoaoBatistaJr/threads-of-mana"
const ASSET_WINDOWS := "game-windows.zip"
const ASSET_LINUX := "game-linux.zip"
const EXE_WINDOWS := "Game.exe"
const EXE_LINUX := "Game.x86_64"
const STATUS_URL := "https://threads-status.joaojuniorsantos2008.workers.dev/"
const NEWS_URL := "https://joaobatistajr.github.io/threads-of-mana/news.json"
const STATUS_EVERY := 20.0
# Padrão usado se server.json não puder ser lido
const SERVER_ADDRESS := "stallion-calculated.tun.ply.gg"
const SERVER_PORT := 12569

var _api_url := "https://api.github.com/repos/%s/releases/latest" % REPO
var _cfg_url := "https://raw.githubusercontent.com/%s/main/server.json" % REPO
var _server_address := SERVER_ADDRESS
var _server_port := SERVER_PORT
var _install_dir := ""
var _linux := OS.get_name() == "Linux"
var _asset_name := ASSET_LINUX if _linux else ASSET_WINDOWS
var _exe := EXE_LINUX if _linux else EXE_WINDOWS
var _auto := false
var _status_url := STATUS_URL
var _news_url := NEWS_URL

var _cfg: HTTPRequest
var _api: HTTPRequest
var _dl: HTTPRequest
var _status: Label
var _silent := false   # verificação periódica de nova versão (sem mexer na tela se nada mudou)
const RECHECK_EVERY := 90.0
var _bar: ProgressBar
var _play: Button
var _news_http: HTTPRequest
var _srv_http: HTTPRequest
var _srv_dot: Panel
var _srv_state: Label
var _srv_count: Label
var _srv_bar: ProgressBar
var _version_label: Label
var _news_box: VBoxContainer
var _zip_path := ""
var _pending_tag := ""


func _ready() -> void:
	# Pasta fixa por usuário (Windows: %APPDATA%\ThreadsOfMana\game, Linux: ~/.local/share/ThreadsOfMana/game),
	# independente de onde o launcher foi extraído.
	_install_dir = ProjectSettings.globalize_path("user://game") if OS.has_feature("editor") \
		else OS.get_data_dir().path_join("ThreadsOfMana").path_join("game")
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		match kv[0]:
			"cfg": _cfg_url = kv[1]
			"api": _api_url = kv[1]
			"dir": _install_dir = kv[1]
			"exe": _exe = kv[1]
			"auto": _auto = true
			"status": _status_url = kv[1]
			"news": _news_url = kv[1]
	_zip_path = _install_dir.get_base_dir().path_join("game_update.zip")
	DirAccess.make_dir_recursive_absolute(_install_dir)

	_build_ui()
	_cfg = HTTPRequest.new()
	_api = HTTPRequest.new()
	_dl = HTTPRequest.new()
	add_child(_cfg)
	add_child(_api)
	add_child(_dl)
	_cfg.request_completed.connect(_on_config)
	_api.request_completed.connect(_on_release)
	_dl.request_completed.connect(_on_downloaded)

	_news_http = HTTPRequest.new()
	_srv_http = HTTPRequest.new()
	add_child(_news_http)
	add_child(_srv_http)
	_news_http.request_completed.connect(_on_news)
	_srv_http.request_completed.connect(_on_server_status)
	_news_http.request(_news_url, ["User-Agent: ThreadsLauncher", "Cache-Control: no-cache"])
	_refresh_server()
	var t := Timer.new()
	t.wait_time = STATUS_EVERY
	t.autostart = true
	t.timeout.connect(_refresh_server)
	add_child(t)
	var rc := Timer.new()
	rc.wait_time = RECHECK_EVERY
	rc.autostart = true
	rc.timeout.connect(_recheck)
	add_child(rc)
	_version_label.text = "Versão instalada: %s" % (_local_version() if _local_version() != "" else "—")

	_set_status("Verificando atualizações...")
	if _cfg.request(_cfg_url, ["User-Agent: ThreadsLauncher", "Cache-Control: no-cache"]) != OK:
		_check_release()


func _on_config(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	if result == OK and code == 200:
		var data = JSON.parse_string(body.get_string_from_utf8())
		if typeof(data) == TYPE_DICTIONARY and str(data.get("address", "")) != "" and int(data.get("port", 0)) > 0:
			_server_address = str(data["address"])
			_server_port = int(data["port"])
			print("[launcher] servidor: %s:%d" % [_server_address, _server_port])
	_check_release()


# Com o launcher aberto: se saiu versão nova, baixa e instala sozinho.
func _recheck() -> void:
	if _dl.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED \
			or _api.get_http_client_status() != HTTPClient.STATUS_DISCONNECTED:
		return
	_silent = true
	if _api.request(_api_url, ["User-Agent: ThreadsLauncher", "Accept: application/vnd.github+json"]) != OK:
		_silent = false


func _check_release() -> void:
	var err := _api.request(_api_url, ["User-Agent: ThreadsLauncher", "Accept: application/vnd.github+json"])
	if err != OK:
		_offline("Falha ao iniciar a verificação")


func _process(_d: float) -> void:
	if _dl.get_http_client_status() == HTTPClient.STATUS_BODY:
		var total := _dl.get_body_size()
		var got := _dl.get_downloaded_bytes()
		if total > 0:
			_bar.value = 100.0 * got / total
			_set_status("Baixando %s  (%.1f / %.1f MB)" % [_pending_tag, got / 1048576.0, total / 1048576.0], false)


func _on_release(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var quiet := _silent
	_silent = false
	if result != OK or code != 200:
		if not quiet:
			_offline("Sem conexão com o servidor de atualização")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		if not quiet:
			_offline("Resposta inválida de atualização")
		return

	var tag := str(data.get("tag_name", ""))
	var url := ""
	for asset in data.get("assets", []):
		if asset.get("name", "") == _asset_name:
			url = str(asset.get("browser_download_url", ""))
	if tag.is_empty() or url.is_empty():
		if not quiet:
			_offline("Release sem %s" % _asset_name)
		return

	if tag == _local_version() and FileAccess.file_exists(_game_path()):
		if not quiet:
			_ready_to_play("Atualizado (%s)" % tag)
		return

	if quiet:
		_auto = false
		_play.disabled = true
		_set_status("Nova atualização %s encontrada, baixando..." % tag)
	_pending_tag = tag
	_dl.download_file = _zip_path
	if _dl.request(url) != OK:
		_offline("Falha ao iniciar o download")


func _on_downloaded(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	if result != OK or code != 200:
		DirAccess.remove_absolute(_zip_path)
		_offline("Falha no download (HTTP %d)" % code)
		return
	_set_status("Instalando %s..." % _pending_tag)
	var err := _extract(_zip_path, _install_dir)
	DirAccess.remove_absolute(_zip_path)
	if err != OK:
		_offline("Falha ao extrair a atualização")
		return
	_make_executable()
	var f := FileAccess.open(_install_dir.path_join("version.txt"), FileAccess.WRITE)
	f.store_string(_pending_tag)
	f.close()
	_bar.value = 100
	_version_label.text = "Versão instalada: %s" % _pending_tag
	_ready_to_play("Atualizado (%s)" % _pending_tag)


# ZIPReader não preserva permissões: no Linux o jogo precisa receber o bit de execução.
func _make_executable() -> void:
	if not _linux or not FileAccess.file_exists(_game_path()):
		return
	var perms := FileAccess.UNIX_READ_OWNER | FileAccess.UNIX_WRITE_OWNER | FileAccess.UNIX_EXECUTE_OWNER \
		| FileAccess.UNIX_READ_GROUP | FileAccess.UNIX_EXECUTE_GROUP \
		| FileAccess.UNIX_READ_OTHER | FileAccess.UNIX_EXECUTE_OTHER
	FileAccess.set_unix_permissions(_game_path(), perms)


func _extract(zip_file: String, dest: String) -> Error:
	var zip := ZIPReader.new()
	var err := zip.open(zip_file)
	if err != OK:
		return err
	for entry in zip.get_files():
		if ".." in entry or entry.begins_with("/"):
			continue # proteção contra zip-slip
		var target := dest.path_join(entry)
		if entry.ends_with("/"):
			DirAccess.make_dir_recursive_absolute(target)
			continue
		DirAccess.make_dir_recursive_absolute(target.get_base_dir())
		var f := FileAccess.open(target, FileAccess.WRITE)
		if f == null:
			zip.close()
			return ERR_FILE_CANT_WRITE
		f.store_buffer(zip.read_file(entry))
		f.close()
	zip.close()
	return OK


func _local_version() -> String:
	var p := _install_dir.path_join("version.txt")
	return FileAccess.get_file_as_string(p).strip_edges() if FileAccess.file_exists(p) else ""


func _game_path() -> String:
	return _exe if _exe.is_absolute_path() else _install_dir.path_join(_exe)


func _offline(msg: String) -> void:
	if FileAccess.file_exists(_game_path()):
		_ready_to_play("%s — jogando com a versão instalada (%s)" % [msg, _local_version()])
	else:
		_set_status("%s. Verifique sua internet e reabra o launcher." % msg)


func _ready_to_play(msg: String) -> void:
	_set_status(msg)
	_play.disabled = false
	if _auto:
		_on_play()


func _on_play() -> void:
	var pid := OS.create_process(_game_path(), ["--", "--address=%s" % _server_address, "--port=%d" % _server_port])
	if pid <= 0:
		_set_status("Não foi possível abrir o jogo")
		return
	get_tree().quit()


func _set_status(text: String, log := true) -> void:
	_status.text = text
	if log:
		print("[launcher] ", text)


# ============================ INTERFACE ============================

const C_GOLD := Color("#c9a25a")
const C_GOLD_DIM := Color("#8a6f3c")
const C_NAVY := Color("#0e1b33")
const C_CARD := Color(0.063, 0.11, 0.188, 0.94)
const C_TEXT := Color("#b9c7d9")
const C_HEAD := Color("#e9f1fa")
const C_MUTED := Color("#8fa6c1")
const C_INK := Color("#1a2f5c")

var _f_title: Font = load("res://fonts/UnifrakturCook-Bold.ttf")
var _f_head: Font = load("res://fonts/IMFeENrm28P.ttf")
var _f_body: Font = load("res://fonts/Almendra-Regular.ttf")
var _f_bold: Font = load("res://fonts/Almendra-Bold.ttf")


func _box(bg: Color, border: Color, radius := 8, bw := 1) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(bw)
	sb.set_corner_radius_all(radius)
	return sb


func _label(text: String, font: Font, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", font)
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	return l


func _margin(node: Control, l: int, t: int, r: int, b: int) -> MarginContainer:
	var m := MarginContainer.new()
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	m.add_child(node)
	return m


func _card(title: String, content: Control) -> PanelContainer:
	var p := PanelContainer.new()
	p.add_theme_stylebox_override("panel", _box(C_CARD, C_GOLD_DIM, 8))
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 0)
	var head := PanelContainer.new()
	var hs := _box(Color("#1a3052"), Color(0, 0, 0, 0), 7)
	hs.corner_radius_bottom_left = 0
	hs.corner_radius_bottom_right = 0
	head.add_theme_stylebox_override("panel", hs)
	head.add_child(_margin(_label(title, _f_head, 20, C_HEAD), 14, 6, 14, 6))
	v.add_child(head)
	v.add_child(_margin(content, 14, 12, 14, 12))
	p.add_child(v)
	return p


func _build_ui() -> void:
	var bg := TextureRect.new()
	bg.texture = load("res://img/bg.jpg")
	bg.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	bg.stretch_mode = TextureRect.STRETCH_SCALE
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	var shade := ColorRect.new()
	shade.color = Color(0.02, 0.04, 0.09, 0.45)
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(shade)

	var root := VBoxContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.offset_left = 22
	root.offset_right = -22
	root.offset_top = 14
	root.offset_bottom = -16
	root.add_theme_constant_override("separation", 12)
	add_child(root)

	# título
	var plate := PanelContainer.new()
	plate.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var ps := _box(Color(0.043, 0.086, 0.173, 0.94), C_GOLD_DIM, 40, 2)
	plate.add_theme_stylebox_override("panel", ps)
	plate.add_child(_margin(_label("Threads of Mana", _f_title, 46, Color("#dfe9f6")), 48, 2, 48, 8))
	root.add_child(plate)

	# corpo
	var body := HBoxContainer.new()
	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	root.add_child(body)

	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 230
	left.add_theme_constant_override("separation", 12)
	body.add_child(left)

	var srv := VBoxContainer.new()
	srv.add_theme_constant_override("separation", 6)
	var row := HBoxContainer.new()
	row.add_child(_label("Mana-1", _f_head, 20, C_HEAD))
	var sp := Control.new()
	sp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(sp)
	_srv_dot = Panel.new()
	_srv_dot.custom_minimum_size = Vector2(10, 10)
	_srv_dot.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_set_dot(C_MUTED)
	row.add_child(_srv_dot)
	_srv_state = _label(" Verificando…", _f_body, 15, C_MUTED)
	row.add_child(_srv_state)
	srv.add_child(row)
	_srv_count = _label("—", _f_body, 15, C_MUTED)
	srv.add_child(_srv_count)
	_srv_bar = ProgressBar.new()
	_srv_bar.custom_minimum_size.y = 9
	_srv_bar.show_percentage = false
	_srv_bar.add_theme_stylebox_override("background", _box(Color("#060b14"), C_GOLD_DIM, 5))
	_srv_bar.add_theme_stylebox_override("fill", _box(Color("#5f9f6b"), Color(0, 0, 0, 0), 5, 0))
	srv.add_child(_srv_bar)
	left.add_child(_card("Servidor", srv))

	var info := VBoxContainer.new()
	info.add_theme_constant_override("separation", 4)
	_version_label = _label("", _f_body, 15, C_TEXT)
	info.add_child(_version_label)
	info.add_child(_label("Pré-Alpha aberto", _f_body, 15, Color("#e08a90")))
	info.add_child(_label("Jogue sem conta por enquanto", _f_body, 14, C_MUTED))
	left.add_child(_card("Jogo", info))

	# notícias (pergaminho)
	var paper := PanelContainer.new()
	paper.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var tex := StyleBoxTexture.new()
	tex.texture = load("res://img/parchment.jpg")
	paper.add_theme_stylebox_override("panel", tex)
	var pv := VBoxContainer.new()
	pv.add_theme_constant_override("separation", 4)
	pv.add_child(_label("Notícias", _f_head, 30, C_INK))
	var line := ColorRect.new()
	line.color = Color("#8f7b4b")
	line.custom_minimum_size = Vector2(150, 1)
	line.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	pv.add_child(line)
	_news_box = VBoxContainer.new()
	_news_box.add_theme_constant_override("separation", 0)
	pv.add_child(_news_box)
	_news_box.add_child(_label("Carregando…", _f_body, 16, Color("#4a3d27")))
	paper.add_child(_margin(pv, 24, 14, 24, 14))
	body.add_child(paper)

	# rodapé: status + progresso + jogar
	var foot := PanelContainer.new()
	foot.add_theme_stylebox_override("panel", _box(Color(0.043, 0.086, 0.173, 0.94), C_GOLD_DIM, 10))
	var fh := HBoxContainer.new()
	fh.add_theme_constant_override("separation", 18)
	var fl := VBoxContainer.new()
	fl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	fl.alignment = BoxContainer.ALIGNMENT_CENTER
	fl.add_theme_constant_override("separation", 8)
	_status = _label("", _f_body, 16, C_HEAD)
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	fl.add_child(_status)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 12
	_bar.show_percentage = false
	_bar.add_theme_stylebox_override("background", _box(Color("#060b14"), C_GOLD_DIM, 6))
	_bar.add_theme_stylebox_override("fill", _box(Color("#4a7fc0"), Color(0, 0, 0, 0), 6, 0))
	fl.add_child(_bar)
	fh.add_child(fl)

	_play = Button.new()
	_play.text = "Jogar"
	_play.disabled = true
	_play.custom_minimum_size = Vector2(210, 58)
	_play.add_theme_font_override("font", _f_head)
	_play.add_theme_font_size_override("font_size", 28)
	_play.add_theme_color_override("font_color", Color.WHITE)
	_play.add_theme_color_override("font_disabled_color", Color(1, 1, 1, 0.4))
	_play.add_theme_stylebox_override("normal", _box(Color("#8a2f36"), Color("#d6727a"), 8))
	_play.add_theme_stylebox_override("hover", _box(Color("#a23b43"), Color("#e08a90"), 8))
	_play.add_theme_stylebox_override("pressed", _box(Color("#6f2429"), Color("#d6727a"), 8))
	_play.add_theme_stylebox_override("disabled", _box(Color("#3a2a33"), Color("#5a4a52"), 8))
	_play.pressed.connect(_on_play)
	fh.add_child(_play)
	foot.add_child(_margin(fh, 18, 12, 14, 12))
	root.add_child(foot)


func _on_news(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var list = null
	if result == OK and code == 200:
		list = JSON.parse_string(body.get_string_from_utf8())
	for c in _news_box.get_children():
		c.queue_free()
	if typeof(list) != TYPE_ARRAY or list.is_empty():
		_news_box.add_child(_label("Sem notícias no momento.", _f_body, 16, Color("#4a3d27")))
		return
	var shown := 0
	for n in list:
		if typeof(n) != TYPE_DICTIONARY or shown >= 5:
			continue
		shown += 1
		var tag := str(n.get("tag", "")).to_upper()
		var color := Color("#3d4d6c")
		if tag == "EVENTO":
			color = Color("#8a2f36")
		elif tag == "NOVO":
			color = Color("#2f5f9a")
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var chip := PanelContainer.new()
		chip.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		chip.add_theme_stylebox_override("panel", _box(color, Color(1, 1, 1, 0.2), 4))
		chip.add_child(_margin(_label(tag, _f_bold, 12, Color.WHITE), 8, 1, 8, 1))
		row.add_child(chip)
		var t := _label(str(n.get("title", "")), _f_head, 19, C_INK)
		t.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		t.clip_text = true
		t.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		row.add_child(t)
		row.add_child(_label(str(n.get("date", "")), _f_body, 13, Color("#5e4e32")))
		_news_box.add_child(_margin(row, 0, 9, 0, 9))
		var sep := ColorRect.new()
		sep.color = Color(0.56, 0.48, 0.29, 0.55)
		sep.custom_minimum_size.y = 1
		_news_box.add_child(sep)


func _set_dot(c: Color) -> void:
	_srv_dot.add_theme_stylebox_override("panel", _box(c, Color(0, 0, 0, 0), 5, 0))


func _refresh_server() -> void:
	if _srv_http.get_http_client_status() == HTTPClient.STATUS_DISCONNECTED:
		_srv_http.request(_status_url, ["User-Agent: ThreadsLauncher", "Cache-Control: no-cache"])


func _on_server_status(result: int, code: int, _h: PackedStringArray, body: PackedByteArray) -> void:
	var d = null
	if result == OK and code == 200:
		d = JSON.parse_string(body.get_string_from_utf8())
	if typeof(d) != TYPE_DICTIONARY:
		_set_dot(C_MUTED)
		_srv_state.text = " Indisponível"
		_srv_state.add_theme_color_override("font_color", C_MUTED)
		_srv_count.text = "Não foi possível consultar"
		_srv_bar.value = 0
		return
	var online := bool(d.get("online", false))
	var players := int(d.get("players", 0))
	var mx := maxi(int(d.get("max", 0)), 1)
	var col := Color("#8fc79a") if online else Color("#d98a8a")
	_set_dot(col)
	_srv_state.text = " Online" if online else " Offline"
	_srv_state.add_theme_color_override("font_color", col)
	_srv_count.text = "%d / %d jogadores" % [players, mx] if online else "Servidor desligado no momento"
	_srv_bar.value = 100.0 * players / mx if online else 0.0
