extends Node

# Mesmo script nos dois lados (RPC exige o mesmo caminho/assinatura).
# Servidor: simulação autoritativa, sem nós, física ou render.
# Cliente: predição local + reconciliação por sequência; interpolação dos outros.

class ServerPlayer extends RefCounted:
	var state := PlayerState.new()
	var queue: Array = []   # [seq, dir, cam_yaw, flags]
	var last_seq := 0
	var ack := 0
	var display_name := ""
	var mode := Const.MODE_COMBAT
	var tool := ResourceNodes.Tool.AXE
	var target := -1          # recurso sendo coletado
	var progress := 0.0       # 0..1 da coleta atual
	var reported := -1        # último alvo informado ao cliente
	var items := [0, 0]       # contagem por tipo de recurso

signal disconnected(reason: String)

var is_server := false
var player_name := ""
var status_url := ""   # servidor: endpoint do status (opcional)
var status_key := ""
var is_bot := false
var bot_gather := false   # teste: bot caminha até as árvores e coleta
var quit_after := 0.0
var sim_loss := 0.0   # debug: fração de pacotes descartados no cliente (teste de rede ruim)

# --- servidor ---
var _players: Dictionary = {}   # peer_id -> ServerPlayer
var _tick := 0
var _status_http: HTTPRequest
var _status_busy := false
var _status_ok := true
var _status_timer := 0.0
var _nodes: Array = []                 # lista gerada (igual nos dois lados)
var _node_hits: Array = []             # coletas restantes por recurso
var _node_respawn: Dictionary = {}     # id -> segundos para voltar

# --- cliente ---
var _local: PlayerState
var _local_ready := false
var _seq := 0
var _pending: Array = []        # inputs ainda não confirmados pelo servidor
var _prev_pos := Vector3.ZERO
var _prev_yaw := 0.0
var _smooth := Vector3.ZERO
var _avatars: Dictionary = {}   # peer_id -> Avatar
var _names: Dictionary = {}     # peer_id -> nome
var _samples: Dictionary = {}   # peer_id -> [[t, pos, yaw], ...]
var _rig: CameraRig
var _label: Label
var _hud_accum := 0.0
var _closing := false
var _node_vis: Dictionary = {}         # id -> Node3D (cliente)
var _node_alive: Dictionary = {}       # id -> bool (cliente)
var _mode := Const.MODE_COMBAT
var _tool := ResourceNodes.Tool.AXE
var _items := [0, 0]
var _gather_progress := 0.0
var _gather_bar: ProgressBar
var dev := false
var _w_sum := 0.0
var _w_max := 0.0
var _w_n := 0
var _run_time := 0.0
var _bot_t := 0.0
var _corr_sum := 0.0
var _corr_max := 0.0
var _corr_n := 0


func _ready() -> void:
	_nodes = ResourceNodes.generate()
	if is_server:
		_node_hits.resize(_nodes.size())
		_node_hits.fill(Const.NODE_HITS)
		multiplayer.peer_connected.connect(_on_peer_connected)
		multiplayer.peer_disconnected.connect(_on_peer_disconnected)
		print("[server] ouvindo, %d ticks/s, snapshot a cada %d ticks" % [
			Engine.physics_ticks_per_second, Const.SNAPSHOT_EVERY])
		if not status_url.is_empty():
			_status_http = HTTPRequest.new()
			_status_http.timeout = 8.0
			_status_http.request_completed.connect(_on_status_done)
			add_child(_status_http)
			_push_status()
			print("[server] enviando status a cada %d s" % int(Const.STATUS_EVERY))
		return

	multiplayer.connected_to_server.connect(func():
		_set_status("Entrando...")
		register.rpc_id(1, player_name)
		if bot_gather:
			set_mode.rpc_id(1, Const.MODE_GATHER, ResourceNodes.Tool.AXE))
	multiplayer.connection_failed.connect(func(): disconnected.emit("Não foi possível conectar ao servidor"))
	multiplayer.server_disconnected.connect(func(): disconnected.emit("Conexão com o servidor perdida"))
	SceneBuilder.build(self)
	_node_vis = SceneBuilder.build_nodes(self, _nodes)
	for n in _nodes:
		_node_alive[n["id"]] = true
	_rig = CameraRig.new()
	add_child(_rig)
	var layer := CanvasLayer.new()
	_label = Label.new()
	_label.position = Vector2(12, 8)
	layer.add_child(_label)
	_gather_bar = ProgressBar.new()
	_gather_bar.show_percentage = false
	_gather_bar.visible = false
	_gather_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gather_bar.offset_left = -130.0
	_gather_bar.offset_right = 130.0
	_gather_bar.offset_top = -90.0
	_gather_bar.offset_bottom = -72.0
	layer.add_child(_gather_bar)
	add_child(layer)
	_set_status("Conectando...")


# ============================ SERVIDOR ============================

func _on_peer_connected(id: int) -> void:
	print("[server] conexão %d (aguardando registro)" % id)


func _on_peer_disconnected(id: int) -> void:
	var p: ServerPlayer = _players.get(id)
	_players.erase(id)
	print("[server] -%d '%s' (total %d)" % [id, p.display_name if p else "?", _players.size()])
	if p:
		receive_name.rpc(id, "")
	_push_status()


# O jogador só entra na simulação depois de se registrar com um nome válido.
@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func register(requested_name: String) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if _players.has(id):
		return
	var n := CharacterStore.clean(requested_name)
	if n.is_empty():
		n = "Jogador%d" % (id % 1000)
	var p := ServerPlayer.new()
	p.display_name = n
	p.state.pos = Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
	_players[id] = p
	for other in _players:
		if other != id:
			receive_name.rpc_id(id, other, _players[other].display_name)
	receive_name.rpc(id, n)
	var dead := PackedInt32Array()
	for nid in _node_respawn:
		dead.append(nid)
	sync_nodes.rpc_id(id, dead)
	print("[server] +%d '%s' (total %d)" % [id, n, _players.size()])
	_push_status()


# flags: bit0 = correr, bit1 = pular
@rpc("any_peer", "call_remote", "unreliable_ordered", Const.CH_INPUT)
func submit_input(seq: int, dir: Vector2, cam_yaw: float, flags: int) -> void:
	if not is_server:
		return
	var p: ServerPlayer = _players.get(multiplayer.get_remote_sender_id())
	if p == null or seq <= p.last_seq or not dir.is_finite() or not is_finite(cam_yaw):
		return
	p.last_seq = seq
	p.queue.append([seq, dir.limit_length(1.0), cam_yaw, flags])
	if p.queue.size() > Const.MAX_QUEUE:
		p.queue = p.queue.slice(-Const.QUEUE_KEEP)


@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func set_mode(mode: int, tool: int) -> void:
	if not is_server:
		return
	var p: ServerPlayer = _players.get(multiplayer.get_remote_sender_id())
	if p == null or mode < 0 or mode > 1 or tool < 0 or tool > 1:
		return
	p.mode = mode
	p.tool = tool
	p.target = -1
	p.progress = 0.0


func _server_gather(id: int, p: ServerPlayer) -> void:
	var best := -1
	if p.mode == Const.MODE_GATHER:
		var best_d := Const.GATHER_RANGE
		for n in _nodes:
			var nid: int = n["id"]
			if n["type"] != p.tool or _node_hits[nid] <= 0:
				continue
			var d: float = Vector2(n["pos"].x - p.state.pos.x, n["pos"].z - p.state.pos.z).length()
			if d <= best_d:
				best_d = d
				best = nid
	if best != p.target:
		p.target = best
		p.progress = 0.0
	if best >= 0:
		p.progress += Const.DT / Const.GATHER_TIME
		if p.progress >= 1.0:
			p.progress = 0.0
			var kind: int = _nodes[best]["type"]
			p.items[kind] += 1
			gained.rpc_id(id, kind, p.items[kind])
			_node_hits[best] -= 1
			if _node_hits[best] <= 0:
				_node_respawn[best] = Const.NODE_RESPAWN
				node_state.rpc(best, false)
	if _tick % Const.SNAPSHOT_EVERY == 0 and (best >= 0 or p.reported != -1):
		gather_progress.rpc_id(id, best, p.progress)
		p.reported = best


func _server_nodes_tick() -> void:
	for nid in _node_respawn.keys():
		_node_respawn[nid] -= Const.DT
		if _node_respawn[nid] <= 0.0:
			_node_respawn.erase(nid)
			_node_hits[nid] = Const.NODE_HITS
			node_state.rpc(nid, true)


func _server_tick() -> void:
	_tick += 1
	_status_timer += Const.DT
	if _status_timer >= Const.STATUS_EVERY:
		_status_timer = 0.0
		_push_status()
	for id in _players:
		var p: ServerPlayer = _players[id]
		var n := 2 if p.queue.size() > 3 else 1   # recupera atraso de rede sem acelerar demais
		for i in n:
			if p.queue.is_empty():
				break
			var inp: Array = p.queue.pop_front()
			p.state.step(inp[1], inp[2], (inp[3] & 1) != 0, (inp[3] & 2) != 0)
			p.ack = inp[0]
		_server_gather(id, p)
	_server_nodes_tick()
	if _tick % Const.SNAPSHOT_EVERY == 0:
		_broadcast_snapshot()


# Envia {players, max} ao endpoint do site; se parar de enviar, o site mostra Offline.
func _push_status() -> void:
	if _status_http == null or _status_busy:
		return
	var body := JSON.stringify({"players": _players.size(), "max": Const.MAX_CLIENTS})
	var headers := ["Content-Type: application/json", "Authorization: Bearer " + status_key]
	if _status_http.request(status_url, headers, HTTPClient.METHOD_POST, body) == OK:
		_status_busy = true


func _on_status_done(result: int, code: int, _h: PackedStringArray, _b: PackedByteArray) -> void:
	_status_busy = false
	var ok := result == OK and code == 200
	if ok != _status_ok:   # só registra quando muda, para não poluir o log
		print("[server] status do site: %s" % ("ok" if ok else "FALHOU (resultado %d, http %d)" % [result, code]))
	_status_ok = ok


func _broadcast_snapshot() -> void:
	if _players.is_empty():
		return
	var ids := PackedInt32Array()
	var pos := PackedVector3Array()
	var vel := PackedVector3Array()
	var yaws := PackedFloat32Array()
	var acks := PackedInt32Array()
	for id in _players:
		var p: ServerPlayer = _players[id]
		ids.append(id)
		pos.append(p.state.pos)
		vel.append(p.state.vel)
		yaws.append(p.state.yaw)
		acks.append(p.ack)
	receive_snapshot.rpc(ids, pos, vel, yaws, acks)


# ============================ CLIENTE ============================

@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func receive_name(id: int, n: String) -> void:
	if is_server:
		return
	if n.is_empty():
		_names.erase(id)
		return
	_names[id] = n
	if _avatars.has(id):
		_avatars[id].set_display_name(n)

@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func sync_nodes(dead: PackedInt32Array) -> void:
	if is_server:
		return
	for nid in dead:
		_set_node_alive(nid, false)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func node_state(nid: int, alive: bool) -> void:
	if is_server:
		return
	_set_node_alive(nid, alive)


@rpc("authority", "call_remote", "unreliable_ordered", Const.CH_SNAPSHOT)
func gather_progress(nid: int, progress: float) -> void:
	if is_server:
		return
	_gather_progress = progress if nid >= 0 else 0.0
	_gather_bar.visible = nid >= 0
	_gather_bar.value = _gather_progress * 100.0


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func gained(kind: int, total: int) -> void:
	if is_server or kind < 0 or kind > 1:
		return
	_items[kind] = total
	_update_hud()


func _set_node_alive(nid: int, alive: bool) -> void:
	_node_alive[nid] = alive
	if _node_vis.has(nid):
		_node_vis[nid].visible = alive


@rpc("authority", "call_remote", "unreliable_ordered", Const.CH_SNAPSHOT)
func receive_snapshot(ids: PackedInt32Array, pos: PackedVector3Array, vel: PackedVector3Array,
		yaws: PackedFloat32Array, acks: PackedInt32Array) -> void:
	if is_server or randf() < sim_loss:
		return
	var now := Time.get_ticks_usec() / 1000000.0
	var me := multiplayer.get_unique_id()
	var present := {}
	for i in ids.size():
		var id := ids[i]
		present[id] = true
		if id == me:
			_reconcile(me, pos[i], vel[i], yaws[i], acks[i])
			continue
		if not _avatars.has(id):
			_spawn_avatar(id, pos[i])
		var buf: Array = _samples[id]
		buf.append([now, pos[i], yaws[i]])
		if buf.size() > 30:
			buf.pop_front()

	for id in _avatars.keys():
		if id != me and not present.has(id):
			_avatars[id].queue_free()
			_avatars.erase(id)
			_samples.erase(id)
			_names.erase(id)


func _reconcile(me: int, pos: Vector3, vel: Vector3, yaw: float, ack: int) -> void:
	var s := PlayerState.new()
	s.pos = pos
	s.vel = vel
	s.yaw = yaw
	if not _local_ready:
		_local = s
		_prev_pos = pos
		_prev_yaw = yaw
		_local_ready = true
		_spawn_avatar(me, pos)
		_set_status("Conectado")
		return

	while not _pending.is_empty() and _pending[0][0] <= ack:
		_pending.pop_front()
	for inp in _pending:
		s.step(inp[1], inp[2], (inp[3] & 1) != 0, (inp[3] & 2) != 0)

	var err := s.pos - _local.pos
	_corr_sum += err.length()
	_corr_max = maxf(_corr_max, err.length())
	_corr_n += 1
	_w_sum += err.length()
	_w_max = maxf(_w_max, err.length())
	_w_n += 1
	_smooth = Vector3.ZERO if err.length() > Const.SNAP_DISTANCE else _smooth - err
	_local = s


func _unhandled_input(event: InputEvent) -> void:
	if is_server or is_bot or not _local_ready:
		return
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_R:
				_mode = Const.MODE_GATHER if _mode == Const.MODE_COMBAT else Const.MODE_COMBAT
			KEY_1:
				_tool = ResourceNodes.Tool.AXE
			KEY_2:
				_tool = ResourceNodes.Tool.PICKAXE
			_:
				return
		set_mode.rpc_id(1, _mode, _tool)
		_update_hud()


func _update_hud() -> void:
	if _label == null or not _local_ready:
		return
	var mode_txt := "COLETA (%s)" % ResourceNodes.TOOL_NAMES[_tool] if _mode == Const.MODE_GATHER else "COMBATE"
	_label.text = "Jogadores: %d | FPS: %d\nModo: %s   [R] alternar · [1] machado · [2] picareta\nMadeira: %d   Pedra: %d\nWASD mover · Shift correr · Espaço pular · clique = mouse, Esc = soltar" % [
		_avatars.size(), Engine.get_frames_per_second(), mode_txt, _items[0], _items[1]]


func _client_tick() -> void:
	if _closing or not _local_ready:
		return
	var inp := _gather_input()
	_seq += 1
	_prev_pos = _local.pos
	_prev_yaw = _local.yaw
	_local.step(inp[0], inp[1], (inp[2] & 1) != 0, (inp[2] & 2) != 0)
	_pending.append([_seq, inp[0], inp[1], inp[2]])
	if _pending.size() > 120:
		_pending.pop_front()
	if randf() >= sim_loss:
		submit_input.rpc_id(1, _seq, inp[0], inp[1], inp[2])


# retorna [dir: Vector2, cam_yaw: float, flags: int]
func _gather_input() -> Array:
	if is_bot and bot_gather:
		var me_pos := _local.pos
		var best := -1
		var best_d := INF
		for n in _nodes:
			if n["type"] != ResourceNodes.Type.TREE or not _node_alive.get(n["id"], true):
				continue
			var d: float = Vector2(n["pos"].x - me_pos.x, n["pos"].z - me_pos.z).length()
			if d < best_d:
				best_d = d
				best = n["id"]
		if best < 0 or best_d < 1.5:
			return [Vector2.ZERO, 0.0, 0]
		var to: Vector3 = _nodes[best]["pos"] - me_pos
		return [Vector2(to.x, to.z).normalized(), 0.0, 1]
	if is_bot:
		_bot_t += Const.DT
		var t := _bot_t
		var bf := 0
		if fmod(t, 6.0) > 3.0:
			bf |= 1
		if fmod(t, 2.5) < 0.1:
			bf |= 2
		return [Vector2(sin(t * 0.5), -cos(t * 0.3)).limit_length(1.0), t * 0.4, bf]

	var x := int(Input.is_physical_key_pressed(KEY_D)) - int(Input.is_physical_key_pressed(KEY_A))
	var y := int(Input.is_physical_key_pressed(KEY_S)) - int(Input.is_physical_key_pressed(KEY_W))
	var flags := 0
	if Input.is_physical_key_pressed(KEY_SHIFT):
		flags |= 1
	if Input.is_physical_key_pressed(KEY_SPACE):
		flags |= 2
	return [Vector2(x, y).limit_length(1.0), _rig.yaw, flags]


func _spawn_avatar(id: int, pos: Vector3) -> void:
	var av := Avatar.new()
	av.setup(id, _names.get(id, "..."))
	av.position = pos
	add_child(av)
	_avatars[id] = av
	_samples[id] = []


func _render_clients(delta: float) -> void:
	if _closing:
		return
	var rt := Time.get_ticks_usec() / 1000000.0 - Const.INTERP_DELAY
	var me := multiplayer.get_unique_id() if _local_ready else -1

	if _local_ready:
		var frac := Engine.get_physics_interpolation_fraction()
		_smooth = _smooth.lerp(Vector3.ZERO, 1.0 - exp(-Const.SMOOTH_RATE * delta))
		var av: Avatar = _avatars[me]
		av.position = _prev_pos.lerp(_local.pos, frac) + _smooth
		av.rotation.y = lerp_angle(_prev_yaw, _local.yaw, frac)
		_rig.position = av.position + Vector3(0.0, 1.6, 0.0)

	for id in _avatars:
		if id == me:
			continue
		var r := _interp(_samples[id], rt)
		var av: Avatar = _avatars[id]
		av.position = r[0]
		av.rotation.y = r[1]

	_hud_accum += delta
	if _hud_accum > 0.5 and _local_ready:
		_hud_accum = 0.0
		_update_hud()
		if dev:
			_label.text += "\ncorreção média %.3f m · máx %.3f m (%d snaps)" % [
				_w_sum / maxi(_w_n, 1), _w_max, _w_n]
			_w_sum = 0.0
			_w_max = 0.0
			_w_n = 0


# retorna [pos: Vector3, yaw: float] interpolados no tempo rt
func _interp(buf: Array, rt: float) -> Array:
	if buf.size() == 1 or rt <= buf[0][0]:
		return [buf[0][1], buf[0][2]]
	for i in range(buf.size() - 1):
		var a: Array = buf[i]
		var b: Array = buf[i + 1]
		if rt <= b[0]:
			var t: float = (rt - a[0]) / maxf(b[0] - a[0], 0.0001)
			return [a[1].lerp(b[1], t), lerp_angle(a[2], b[2], t)]
	var last: Array = buf[-1]
	return [last[1], last[2]]


func _set_status(text: String) -> void:
	if _label:
		_label.text = text


func _print_bot_stats() -> void:
	if _corr_n > 0:
		print("[bot] pos=%s correções=%d erro_médio=%.4f erro_máx=%.4f" % [
			str(_local.pos) if _local_ready else "?", _corr_n, _corr_sum / _corr_n, _corr_max])
	else:
		print("[bot] nenhuma correção recebida (local pronto=%s)" % _local_ready)
	print("[bot] coletado: madeira=%d pedra=%d" % [_items[0], _items[1]])


func _disconnect_and_quit() -> void:
	_closing = true
	if multiplayer.multiplayer_peer:
		multiplayer.multiplayer_peer.close()
	get_tree().quit()


func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and not is_server:
		_disconnect_and_quit()


# ============================ LOOP ============================

func _physics_process(_delta: float) -> void:
	if is_server:
		_server_tick()
	else:
		_client_tick()


func _process(delta: float) -> void:
	if quit_after > 0.0:
		_run_time += delta
		if _run_time >= quit_after:
			if is_bot:
				_print_bot_stats()
			_disconnect_and_quit()
			return
	if not is_server:
		_render_clients(delta)
