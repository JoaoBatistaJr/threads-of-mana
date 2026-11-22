extends Control

# Fluxo: consulta a última release no GitHub -> compara com version.txt local ->
# baixa game-windows.zip se mudou -> extrai -> libera "Jogar".
# Args opcionais (testes): --api=URL --dir=PASTA --exe=ARQUIVO --auto

const REPO := "OWNER/REPO"            # usuario/repositorio no GitHub
const ASSET_NAME := "game-windows.zip"
const GAME_EXE := "Game.exe"
const SERVER_ADDRESS := "127.0.0.1"   # IP/domínio do servidor de jogo
const SERVER_PORT := 7777

var _api_url := "https://api.github.com/repos/%s/releases/latest" % REPO
var _install_dir := ""
var _exe := GAME_EXE
var _auto := false

var _api: HTTPRequest
var _dl: HTTPRequest
var _status: Label
var _bar: ProgressBar
var _play: Button
var _zip_path := ""
var _pending_tag := ""


func _ready() -> void:
	_install_dir = ProjectSettings.globalize_path("user://game") if OS.has_feature("editor") \
		else OS.get_executable_path().get_base_dir().path_join("game")
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		match kv[0]:
			"api": _api_url = kv[1]
			"dir": _install_dir = kv[1]
			"exe": _exe = kv[1]
			"auto": _auto = true
	_zip_path = _install_dir.get_base_dir().path_join("game_update.zip")
	DirAccess.make_dir_recursive_absolute(_install_dir)

	_build_ui()
	_api = HTTPRequest.new()
	_dl = HTTPRequest.new()
	add_child(_api)
	add_child(_dl)
	_api.request_completed.connect(_on_release)
	_dl.request_completed.connect(_on_downloaded)

	_set_status("Verificando atualizações...")
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
	if result != OK or code != 200:
		_offline("Sem conexão com o servidor de atualização")
		return
	var data = JSON.parse_string(body.get_string_from_utf8())
	if typeof(data) != TYPE_DICTIONARY:
		_offline("Resposta inválida de atualização")
		return

	var tag := str(data.get("tag_name", ""))
	var url := ""
	for asset in data.get("assets", []):
		if asset.get("name", "") == ASSET_NAME:
			url = str(asset.get("browser_download_url", ""))
	if tag.is_empty() or url.is_empty():
		_offline("Release sem %s" % ASSET_NAME)
		return

	if tag == _local_version() and FileAccess.file_exists(_game_path()):
		_ready_to_play("Atualizado (%s)" % tag)
		return

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
	var f := FileAccess.open(_install_dir.path_join("version.txt"), FileAccess.WRITE)
	f.store_string(_pending_tag)
	f.close()
	_bar.value = 100
	_ready_to_play("Atualizado (%s)" % _pending_tag)


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
	var pid := OS.create_process(_game_path(), ["--", "--address=%s" % SERVER_ADDRESS, "--port=%d" % SERVER_PORT])
	if pid <= 0:
		_set_status("Não foi possível abrir o jogo")
		return
	get_tree().quit()


func _set_status(text: String, log := true) -> void:
	_status.text = text
	if log:
		print("[launcher] ", text)


func _build_ui() -> void:
	var bg := ColorRect.new()
	bg.color = Color("#0b1424")
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 24
	box.offset_right = -24
	box.offset_top = 24
	box.offset_bottom = -24
	box.add_theme_constant_override("separation", 14)
	add_child(box)

	var title := Label.new()
	title.text = "Threads of Mana"
	title.add_theme_font_size_override("font_size", 28)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(title)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_status.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_status)

	_bar = ProgressBar.new()
	_bar.custom_minimum_size.y = 18
	_bar.show_percentage = false
	box.add_child(_bar)

	_play = Button.new()
	_play.text = "Jogar"
	_play.disabled = true
	_play.custom_minimum_size.y = 44
	_play.pressed.connect(_on_play)
	box.add_child(_play)
