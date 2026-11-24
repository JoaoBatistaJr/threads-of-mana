extends Node

# Uso:
#   Servidor: godot --headless -- --server [--port=7777] [--status-url=URL --status-key=SENHA]
#   Cliente:  godot -- [--address=127.0.0.1] [--port=7777] [--name=Nome]   (--name pula o menu)
#   Bot:      godot --headless -- --bot [--quit-after=30] [--loss=0.15]

const WorldScript := preload("res://scripts/world.gd")

var _args := {}
var _address := Const.DEFAULT_ADDRESS
var _port := Const.DEFAULT_PORT
var _menu: MainMenu
var _world: Node


func _ready() -> void:
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
		_show_menu("Falha ao iniciar rede: %s" % error_string(err))
		return
	multiplayer.multiplayer_peer = peer
	_spawn_world(false, player_name)
	_world.disconnected.connect(_on_disconnected)


func _spawn_world(is_server: bool, player_name := "") -> void:
	_world = WorldScript.new()
	_world.name = "World" # mesmo caminho em servidor e cliente (necessário p/ RPC)
	_world.is_server = is_server
	_world.player_name = player_name
	_world.is_bot = _args.has("bot")
	_world.quit_after = float(_args.get("quit-after", 0.0))
	_world.sim_loss = float(_args.get("loss", 0.0))
	_world.status_url = str(_args.get("status-url", ""))
	_world.status_key = str(_args.get("status-key", ""))
	add_child(_world)


func _on_disconnected(reason: String) -> void:
	if _world:
		_world.queue_free()
		_world = null
	multiplayer.multiplayer_peer = null
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_show_menu(reason)


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
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out
