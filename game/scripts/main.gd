extends Node

# Uso:
#   Servidor: godot --headless -- --server [--port=7777]
#   Cliente:  godot -- [--address=127.0.0.1] [--port=7777]

const WorldScript := preload("res://scripts/world.gd")

func _ready() -> void:
	var args := _parse_args()
	var port := int(args.get("port", Const.DEFAULT_PORT))
	var is_server := args.has("server") or OS.has_feature("dedicated_server")

	var peer := ENetMultiplayerPeer.new()
	var err: Error
	if is_server:
		err = peer.create_server(port, Const.MAX_CLIENTS)
	else:
		err = peer.create_client(str(args.get("address", Const.DEFAULT_ADDRESS)), port)
	if err != OK:
		push_error("Falha ao iniciar rede: %s" % error_string(err))
		get_tree().quit(1)
		return

	multiplayer.multiplayer_peer = peer

	var world := WorldScript.new()
	world.name = "World" # mesmo caminho em servidor e cliente (necessário p/ RPC)
	world.is_server = is_server
	world.is_bot = args.has("bot")
	world.quit_after = float(args.get("quit-after", 0.0))
	world.sim_loss = float(args.get("loss", 0.0))
	add_child(world)


func _parse_args() -> Dictionary:
	var out := {}
	for a in OS.get_cmdline_args() + OS.get_cmdline_user_args():
		var s := a.trim_prefix("--")
		var kv := s.split("=", true, 1)
		out[kv[0]] = kv[1] if kv.size() > 1 else true
	return out
