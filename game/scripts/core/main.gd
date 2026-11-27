extends Node

# Uso:
#   Servidor: godot --headless -- --server [--port=7777] [--status-url=URL --status-key=SENHA]
#   Cliente:  godot -- [--address=127.0.0.1] [--port=7777] [--name=Nome]   (--name pula o menu)
#   Bot:      godot --headless -- --bot [--quit-after=30] [--loss=0.15] [--bot-gather]

const WorldScript := preload("res://scripts/net/world.gd")

var _args := {}
var _address := Const.DEFAULT_ADDRESS
var _port := Const.DEFAULT_PORT
var _menu: MainMenu
var _world: Node
var _last_name := ""
var _was_in_game := false
var _retry := 0
var _retry_gen := 0
var _reco: CanvasLayer
var _reco_label: Label
const RETRY_MAX := 40
const RETRY_WAIT := 3.0


func _ready() -> void:
	TranslationServer.set_locale("pt_BR")   # idioma do jogo (por enquanto fixo)
	_args = _parse_args()
	_address = str(_args.get("address", Const.DEFAULT_ADDRESS))
	_port = int(_args.get("port", Const.DEFAULT_PORT))

	if _args.has("server") or OS.has_feature("dedicated_server"):
		_start_server()
	elif _args.has("bot"):
		_join("Bot%d" % (randi() % 1000))
	elif _args.has("name"):
		_join(str(_args["name"]))
	else:
		_show_menu("")


func _start_server() -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_server(_port, Const.MAX_CLIENTS)
	if err != OK:
		push_error("Falha ao iniciar servidor: %s" % error_string(err))
		get_tree().quit(1)
		return
	multiplayer.multiplayer_peer = peer
	_spawn_world(true)


func _join(player_name: String) -> void:
	var peer := ENetMultiplayerPeer.new()
	var err := peer.create_client(_address, _port)
	if err != OK:
		_give_up("Falha ao iniciar rede: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	_last_name = player_name
	_spawn_world(false, player_name)
	_world.disconnected.connect(_on_disconnected)
	_world.entered.connect(_on_entered)


func _spawn_world(is_server: bool, player_name := "") -> void:
	_world = WorldScript.new()
	_world.name = "World" # mesmo caminho em servidor e cliente (necessário p/ RPC)
	_world.is_server = is_server
	_world.player_name = player_name
	_world.is_bot = _args.has("bot")
	_world.bot_gather = _args.has("bot-gather")
	_world.dev = _args.has("dev")
	_world.quit_after = float(_args.get("quit-after", 0.0))
	_world.sim_loss = float(_args.get("loss", 0.0))
	_world.status_url = str(_args.get("status-url", ""))
	_world.status_key = str(_args.get("status-key", ""))
	add_child(_world)


func _on_entered() -> void:
	_was_in_game = true
	_retry = 0
	_end_reconnect()


func _on_disconnected(reason: String, can_retry: bool) -> void:
	if _world:
		_world.queue_free()
		_world = null
	multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	# caiu no meio do jogo (servidor reiniciando/atualizando): tenta voltar sozinho
	if can_retry and _was_in_game and _retry < RETRY_MAX:
		_retry += 1
		_show_reconnect("%s\nReconectando... (%d/%d)" % [reason, _retry, RETRY_MAX])
		get_tree().create_timer(RETRY_WAIT).timeout.connect(_retry_join.bind(_retry_gen))
		return
	_give_up(reason)


func _retry_join(gen: int) -> void:
	if gen != _retry_gen or _reco == null or _world != null:
		return
	_join(_last_name)


func _give_up(reason: String) -> void:
	_retry_gen += 1
	_retry = 0
	_was_in_game = false
	_end_reconnect()
	_show_menu(reason)


func _show_reconnect(text: String) -> void:
	if _reco == null:
		_reco = CanvasLayer.new()
		_reco.layer = 100
		var shade := ColorRect.new()
		shade.color = Color(0.02, 0.04, 0.09, 0.85)
		shade.set_anchors_preset(Control.PRESET_FULL_RECT)
		_reco.add_child(shade)
		var box := VBoxContainer.new()
		box.set_anchors_preset(Control.PRESET_CENTER)
		box.grow_horizontal = Control.GROW_DIRECTION_BOTH
		box.grow_vertical = Control.GROW_DIRECTION_BOTH
		box.add_theme_constant_override("separation", 14)
		_reco_label = Label.new()
		_reco_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_reco_label.add_theme_font_size_override("font_size", 22)
		box.add_child(_reco_label)
		var cancel := Button.new()
		cancel.text = "Cancelar"
		cancel.pressed.connect(func(): _give_up("Reconexão cancelada"))
		box.add_child(cancel)
		_reco.add_child(box)
		add_child(_reco)
	_reco_label.text = text


func _end_reconnect() -> void:
	if _reco != null:
		_reco.queue_free()
		_reco = null


func _show_menu(message: String) -> void:
	_menu = MainMenu.new()
	_menu.name = "MainMenu"
	_menu.play_requested.connect(_on_play_requested)
	add_child(_menu)
	if message == "":
		message = "Servidor: %s" % Const.SERVER_NAME
		if _args.has("dev"):
			message += "  (%s:%d)" % [_address, _port]   # endereço só com --dev
	_menu.set_message(message)


func _on_play_requested(player_name: String) -> void:
	_menu.queue_free()
	_menu = null
	_join(player_name)


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		if kv.size() > 1:
			out[kv[0]] = kv[1]
		else:
			out[kv[0]] = true
	return out
