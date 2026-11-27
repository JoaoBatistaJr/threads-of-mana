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
	var gathering := false    # coleta ligada (tecla E); só continua se houver recurso ao alcance
	var tool := ResourceNodes.Tool.AXE   # equipada automaticamente conforme o recurso
	var target := -1          # recurso sendo coletado
	var progress := 0.0       # 0..1 da coleta atual
	var reported := -1        # último alvo informado ao cliente

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
var _terrain: Terrain
var _nodes: Array = []                 # servidor: gerada; cliente: recebida no registro
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
const SYNC_BATCH := 60   # recursos por pacote (pequeno, para túneis UDP)
var _closing := false
var _view: TerrainView
var _node_chunks: Dictionary = {}      # Vector2i -> [ids] (cliente)
var _node_vis: Dictionary = {}         # id -> Node3D, só dos chunks carregados (cliente)
var _node_alive: Dictionary = {}       # id -> bool (cliente)
var _notice_text := ""
var _notice_until := 0
var _loot: LootBags                  # servidor
var _bag_vis: Dictionary = {}        # cliente: id -> Node3D
var _bag_pos: Dictionary = {}
var _loot_id := -1                   # cliente: bolsa aberta
var _loot_panel: LootPanel
var _inv_panel: InventoryPanel
var _hud: Hud
var _inv: Array = []   # cliente: linhas [uid, item_id, quantidade, qualidade]
var _inv_items := ItemService.new()   # servidor: todas as instâncias de item (uid único, anti-dupe)
var _tool_name := "—"
var _want_gather := false
var _bot_gather_t := 0.0
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
	_terrain = Terrain.new(Const.ZONE_SEED, Const.ZONE_HALF)
	if is_server:
		_loot = LootBags.new(_inv_items)
		_inv_items.logged.connect(func(e: Dictionary) -> void:
			print("[item] %s %s x%d %s -> %s (%s) uid=%s" % [e["op"], e["id"], e["n"], e["from"], e["to"], e["why"], e["uid"]]))
		ResourceNodes.load_defs()
		_nodes = ResourceNodes.generate(_terrain)
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
		register.rpc_id(1, player_name, Const.PROTOCOL)
		)
	multiplayer.connection_failed.connect(func():
		_closing = true
		disconnected.emit("Não foi possível conectar ao servidor"))
	multiplayer.server_disconnected.connect(func():
		_closing = true
		disconnected.emit("Conexão com o servidor perdida"))
	SceneBuilder.build(self)
	_view = TerrainView.new()
	_view.terrain = _terrain
	_view.chunk_loaded.connect(_on_chunk_loaded)
	_view.chunk_unloaded.connect(_on_chunk_unloaded)
	add_child(_view)
	_rig = CameraRig.new()
	add_child(_rig)
	var layer := CanvasLayer.new()
	_hud = Hud.new()
	_hud.mini_sampler = _mini_color
	_hud.set_identity(player_name, 1)
	layer.add_child(_hud)
	_label = Label.new()
	_label.position = Vector2(12, 120)
	_label.visible = dev
	layer.add_child(_label)
	_gather_bar = ProgressBar.new()
	_gather_bar.show_percentage = false
	_gather_bar.visible = false
	_gather_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_gather_bar.offset_left = -130.0
	_gather_bar.offset_right = 130.0
	_gather_bar.offset_top = -120.0
	_gather_bar.offset_bottom = -102.0
	layer.add_child(_gather_bar)
	_loot_panel = LootPanel.new()
	_loot_panel.take.connect(func(uid: String): loot_take.rpc_id(1, _loot_id, uid))
	_loot_panel.take_all.connect(func(): loot_take_all.rpc_id(1, _loot_id))
	_loot_panel.closed.connect(func(): _loot_id = -1)
	layer.add_child(_loot_panel)
	_inv_panel = InventoryPanel.new()
	_inv_panel.theme = UiTheme.make_theme()
	layer.add_child(_inv_panel)
	_inv_panel.show_rows([])
	add_child(layer)
	_set_status("Conectando...")


# ============================ SERVIDOR ============================

func _on_peer_connected(id: int) -> void:
	print("[server] conexão %d (aguardando registro)" % id)
	var enet := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	if enet != null:
		var pp := enet.get_peer(id)
		if pp != null:
			pp.set_timeout(32, 10000, 60000)   # tolera travadas longas do cliente (ms)


func _on_peer_disconnected(id: int) -> void:
	var p: ServerPlayer = _players.get(id)
	_players.erase(id)
	_inv_items.destroy_owner(_owner_of(id), "desconexão")
	_inv_items.capacity.erase(_owner_of(id))
	print("[server] -%d '%s' (total %d)" % [id, p.display_name if p else "?", _players.size()])
	if p:
		receive_name.rpc(id, "")
	_push_status()


# O jogador só entra na simulação depois de se registrar com um nome válido.
@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func register(requested_name: String, protocol: int) -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	if _players.has(id):
		return
	if protocol != Const.PROTOCOL:
		kicked.rpc_id(id, "Versão do jogo incompatível. Atualize pelo launcher.")
		multiplayer.multiplayer_peer.disconnect_peer(id)
		return
	var n := CharacterStore.clean(requested_name)
	if n.is_empty():
		n = "Jogador%d" % (id % 1000)
	var p := ServerPlayer.new()
	p.display_name = n
	p.state.terrain = _terrain
	p.state.pos = Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
	p.state.pos.y = _terrain.height(p.state.pos.x, p.state.pos.z)
	_players[id] = p
	_inv_items.set_capacity(_owner_of(id), Const.INVENTORY_SLOTS)
	for b in _loot.bags.values():
		loot_state.rpc_id(id, b.id, b.pos, true)
	for other in _players:
		if other != id:
			receive_name.rpc_id(id, other, _players[other].display_name)
	receive_name.rpc(id, n)
	var dead := PackedInt32Array()
	for nid in _node_respawn:
		dead.append(nid)
	var total := _nodes.size()
	var start := 0
	while start < total or start == 0:
		var types := PackedByteArray()
		var biomes := PackedByteArray()
		var xz := PackedVector2Array()
		for i in range(start, mini(start + SYNC_BATCH, total)):
			var node: Dictionary = _nodes[i]
			types.append(node["type"])
			biomes.append(node["biome"])
			xz.append(Vector2(node["pos"].x, node["pos"].z))
		var last := start + SYNC_BATCH >= total
		sync_world.rpc_id(id, start, total, types, biomes, xz, dead if last else PackedInt32Array())
		start += SYNC_BATCH
		if last:
			break
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
func interact(on: bool) -> void:
	if not is_server:
		return
	var p: ServerPlayer = _players.get(multiplayer.get_remote_sender_id())
	if p == null:
		return
	p.gathering = on
	if not on:
		p.target = -1
		p.progress = 0.0


# Coleta: com a tecla E ligada, o servidor escolhe o recurso mais próximo ao alcance, "equipa" a
# ferramenta certa e coleta sozinho (3 coletas por recurso). Sem recurso ao alcance, desliga.
func _server_gather(id: int, p: ServerPlayer) -> void:
	var best := -1
	if p.gathering:
		var best_d := Const.GATHER_RANGE
		for n in _nodes:
			var nid: int = n["id"]
			if _node_hits[nid] <= 0:
				continue
			var d: float = Vector2(n["pos"].x - p.state.pos.x, n["pos"].z - p.state.pos.z).length()
			if d <= best_d:
				best_d = d
				best = nid
		if best < 0:
			p.gathering = false
	if best != p.target:
		p.target = best
		p.progress = 0.0
	if best >= 0:
		p.tool = ResourceNodes.TOOL_FOR[_nodes[best]["type"]]
		p.progress += Const.DT / Const.GATHER_TIME
		if p.progress >= 1.0:
			p.progress = 0.0
			_server_collect(id, _nodes[best]["type"])
			_node_hits[best] -= 1
			if _node_hits[best] <= 0:
				_node_respawn[best] = Const.NODE_RESPAWN
				node_state.rpc(best, false)
	if _tick % Const.SNAPSHOT_EVERY == 0 and (best >= 0 or p.reported != -1):
		gather_progress.rpc_id(id, best, p.progress, p.tool)
		p.reported = best


func _owner_of(id: int) -> String:
	return "player:%d" % id


# Sorteia os drops do tipo de recurso e cria os itens direto no inventário (sem item solto no chão).
func _server_collect(id: int, type: int) -> void:
	var def := ResourceNodes.def_for(type)
	if def == null:
		return
	var full := false
	for d in def.drops:
		if d == null or d.item == null or randf() > d.chance:
			continue
		var amount := randi_range(d.min_amount, d.max_amount)
		var q := def.node_quality if d.item.uses_quality() else -1.0
		var r := _inv_items.mint(d.item, amount, _owner_of(id), "coleta:" + def.id, q)
		if int(r.left) > 0:
			full = true
			_loot_drop(id, d.item, int(r.left), q, "coleta:" + def.id)
	_send_inventory(id)
	if full:
		notice.rpc_id(id, "Inventário cheio: o excedente foi para uma bolsa [F]")


# Excedente que não coube no inventário vai para uma bolsa perto do jogador (nunca item solto no chão).
func _loot_drop(peer: int, item: ItemData, amount: int, quality: float, why: String) -> void:
	var p: ServerPlayer = _players[peer]
	var existed := _loot.bags.size()
	var bag := _loot.bag_for(peer, p.state.pos)
	var r := _inv_items.mint(item, amount, LootBags.owner_key(bag.id), why, quality)
	if int(r.left) > 0:
		push_warning("bolsa cheia: %d x %s descartados" % [int(r.left), item.id])
	for other in _players:
		if _players[other].state.pos.distance_to(bag.pos) <= Const.INTEREST_RADIUS:
			loot_state.rpc_id(other, bag.id, bag.pos, true)


func _loot_tick() -> void:
	for gid in _loot.tick(Const.DT):
		loot_state.rpc(gid, Vector3.ZERO, false)


@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func loot_open() -> void:
	if not is_server:
		return
	var peer := multiplayer.get_remote_sender_id()
	var p: ServerPlayer = _players.get(peer)
	if p == null:
		return
	var bag := _loot.nearest_for(peer, p.state.pos)
	if bag != null:
		loot_view.rpc_id(peer, bag.id, _loot.rows(bag.id))


@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func loot_take(bag_id: int, uid: String) -> void:
	_loot_take(multiplayer.get_remote_sender_id(), bag_id, uid)


@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func loot_take_all(bag_id: int) -> void:
	_loot_take(multiplayer.get_remote_sender_id(), bag_id, "")


func _loot_take(peer: int, bag_id: int, uid: String) -> void:
	if not is_server:
		return
	var p: ServerPlayer = _players.get(peer)
	var bag: LootBags.Bag = _loot.bags.get(bag_id)
	if p == null or not _loot.can_open(bag, peer, p.state.pos):
		return
	var from := LootBags.owner_key(bag_id)
	if uid != "":
		_inv_items.move(uid, from, _owner_of(peer), "loot:%d" % bag_id)
	else:
		for e in _inv_items.owned_by(from):
			_inv_items.move(e.uid, from, _owner_of(peer), "loot:%d" % bag_id)
	_send_inventory(peer)
	loot_view.rpc_id(peer, bag_id, _loot.rows(bag_id))


func _send_inventory(id: int) -> void:
	var rows: Array = []
	for e in _inv_items.owned_by(_owner_of(id)):
		rows.append([e.uid, e.data.id, e.amount, snappedf(float(e.get("quality", 0.0)), 0.1)])
	inv_sync.rpc_id(id, rows)


func _server_nodes_tick() -> void:
	for nid in _node_respawn.keys():
		_node_respawn[nid] -= Const.DT
		if _node_respawn[nid] <= 0.0:
			_node_respawn.erase(nid)
			_node_hits[nid] = Const.NODE_HITS
			node_state.rpc(nid, true)


func _server_tick() -> void:
	_tick += 1
	_inv_items.set_tick(_tick)
	_loot_tick()
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


# Interest management: cada jogador recebe só ele mesmo + os mais próximos (até SNAPSHOT_MAX_OTHERS,
# dentro de INTEREST_RADIUS). Mantém o pacote abaixo do MTU e evita o custo crescer com N².
func _broadcast_snapshot() -> void:
	if _players.is_empty():
		return
	var r2 := Const.INTEREST_RADIUS * Const.INTEREST_RADIUS
	for me in _players:
		var mp: ServerPlayer = _players[me]
		var near: Array = []   # [dist², id]
		for id in _players:
			if id == me:
				continue
			var d := Vector2(_players[id].state.pos.x - mp.state.pos.x, _players[id].state.pos.z - mp.state.pos.z).length_squared()
			if d <= r2:
				near.append([d, id])
		near.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
		var ids := PackedInt32Array([me])
		var pos := PackedVector3Array([mp.state.pos])
		var vel := PackedVector3Array([mp.state.vel])
		var yaws := PackedFloat32Array([mp.state.yaw])
		var acks := PackedInt32Array([mp.ack])
		for k in mini(near.size(), Const.SNAPSHOT_MAX_OTHERS):
			var id: int = near[k][1]
			var p: ServerPlayer = _players[id]
			ids.append(id)
			pos.append(p.state.pos)
			vel.append(p.state.vel)
			yaws.append(p.state.yaw)
			acks.append(p.ack)
		receive_snapshot.rpc_id(me, ids, pos, vel, yaws, acks)


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
func sync_world(start: int, total: int, types: PackedByteArray, biomes: PackedByteArray, xz: PackedVector2Array, dead: PackedInt32Array) -> void:
	if is_server:
		return
	if start == 0:
		for nid in _node_vis.keys():
			_node_vis[nid].queue_free()
		_node_vis.clear()
		_node_chunks.clear()
		_node_alive.clear()
		_nodes.clear()
	for i in types.size():
		var pos := Vector3(xz[i].x, _terrain.height(xz[i].x, xz[i].y), xz[i].y)
		var nid_new := start + i
		_nodes.append({"id": nid_new, "type": types[i], "biome": biomes[i], "pos": pos})
		_node_alive[nid_new] = true
		var key := TerrainView.key_of(pos.x, pos.z)
		if not _node_chunks.has(key):
			_node_chunks[key] = []
		_node_chunks[key].append(nid_new)
	for nid in dead:
		_node_alive[nid] = false
	if start + types.size() >= total:
		for key in _view.loaded_chunks():
			_on_chunk_loaded(key)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func kicked(reason: String) -> void:
	if not is_server:
		_closing = true
		disconnected.emit(reason)


func _on_chunk_loaded(key: Vector2i) -> void:
	for nid in _node_chunks.get(key, []):
		if _node_vis.has(nid):
			continue
		var n: Dictionary = _nodes[nid]
		var v := SceneBuilder.node_visual(n["type"], n["biome"])
		v.position = n["pos"]
		v.visible = _node_alive.get(nid, true)
		add_child(v)
		_node_vis[nid] = v


func _on_chunk_unloaded(key: Vector2i) -> void:
	for nid in _node_chunks.get(key, []):
		if _node_vis.has(nid):
			_node_vis[nid].queue_free()
			_node_vis.erase(nid)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func node_state(nid: int, alive: bool) -> void:
	if is_server:
		return
	_set_node_alive(nid, alive)


@rpc("authority", "call_remote", "unreliable_ordered", Const.CH_SNAPSHOT)
func gather_progress(nid: int, progress: float, tool: int) -> void:
	if is_server:
		return
	if nid >= 0:
		_tool_name = ResourceNodes.TOOL_NAMES[clampi(tool, 0, 2)]
	else:
		_want_gather = false
	_gather_progress = progress if nid >= 0 else 0.0
	_gather_bar.visible = nid >= 0
	_gather_bar.value = _gather_progress * 100.0


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func inv_sync(rows: Array) -> void:
	if is_server:
		return
	_inv = rows
	_inv_panel.show_rows(rows)
	_update_hud()


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func loot_state(id: int, pos: Vector3, alive: bool) -> void:
	if is_server:
		return
	if not alive:
		_bag_pos.erase(id)
		if _bag_vis.has(id):
			_bag_vis[id].queue_free()
			_bag_vis.erase(id)
		if _loot_id == id:
			_loot_panel.close_panel()
		return
	_bag_pos[id] = pos
	if _bag_vis.has(id):
		return
	var n := Node3D.new()
	var m := MeshInstance3D.new()
	var box := BoxMesh.new()
	box.size = Vector3(0.55, 0.4, 0.45)
	m.mesh = box
	m.position.y = 0.2
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.55, 0.36, 0.18)
	m.material_override = mat
	n.add_child(m)
	var l := Label3D.new()
	l.text = "Bolsa"
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.position.y = 0.85
	l.pixel_size = 0.006
	l.no_depth_test = true
	n.add_child(l)
	add_child(n)
	n.position = pos
	_bag_vis[id] = n


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func loot_view(id: int, rows: Array) -> void:
	if is_server:
		return
	_loot_id = id
	_loot_panel.show_rows(rows)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func notice(text: String) -> void:
	if is_server:
		return
	_notice_text = text
	_notice_until = Time.get_ticks_msec() + 3000
	if _hud != null:
		_hud.add_chat("Sistema", text)
	_update_hud()


# "Tronco 3 · Pedra 1": soma por item (as pilhas ficam só no servidor).
func _inventory_text() -> String:
	var totals := {}
	for r in _inv:
		totals[r[1]] = int(totals.get(r[1], 0)) + int(r[2])
	if totals.is_empty():
		return "Inventário vazio"
	var parts: Array = []
	for id in totals:
		parts.append("%s %d" % [ItemRegistry.display_name(id), totals[id]])
	return " · ".join(parts)


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
	s.terrain = _terrain
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F3:
		_label.visible = not _label.visible
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_I:
		_inv_panel.toggle()
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F:
		if _loot_panel.visible:
			_loot_panel.close_panel()
		else:
			loot_open.rpc_id(1)
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E:
		_want_gather = not _want_gather
		interact.rpc_id(1, _want_gather)
		_update_hud()


func _mini_color(x: float, z: float) -> Color:
	var base: Color = [Color(0.46, 0.68, 0.30), Color(0.20, 0.42, 0.20), Color(0.52, 0.52, 0.56)][_terrain.biome_at(x, z)]
	var h := _terrain.height(x, z)
	return base.lightened(clampf((h - 6.0) / 90.0 * 0.35 - 0.05, -0.12, 0.3))


func _update_hud() -> void:
	if _label == null or not _local_ready:
		return
	var biome: String = Terrain.BIOME_NAMES[_terrain.biome_at(_local.pos.x, _local.pos.z)]
	var near_bag := false
	for bid in _bag_pos:
		if _bag_pos[bid].distance_to(_local.pos) <= LootBags.RANGE:
			near_bag = true
	var inv := _inventory_text()
	if Time.get_ticks_msec() < _notice_until:
		inv += "   [" + _notice_text + "]"
	var tip := "   [F] abrir bolsa" if near_bag else ""
	_label.text = "Jogadores: %d | FPS: %d | Bioma: %s\nFerramenta (automática): %s   [E] coletar perto de árvore, pedra, erva ou minério%s\n%s\n[I] inventário · WASD mover · Shift correr · Espaço pular · clique = mouse, Esc = soltar" % [
		_avatars.size(), Engine.get_frames_per_second(), biome, _tool_name, tip, inv]


func _client_tick() -> void:
	if _closing or not _local_ready or not multiplayer.has_multiplayer_peer():
		return
	if bot_gather:
		_bot_gather_t += Const.DT
		if _bot_gather_t >= 1.0:
			_bot_gather_t = 0.0
			interact.rpc_id(1, true)
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
			if not _node_alive.get(n["id"], true):
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
	if _closing or not multiplayer.has_multiplayer_peer():
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
		_view.update(av.position)
		_hud.set_player(av.position, av.rotation.y)

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
	print("[bot] inventário: ", _inventory_text())


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
	if delta > 0.5:
		print("[%s] TRAVADA %.2f s (quadro) pos=%s" % ["server" if is_server else "client", delta, str(_local.pos) if (not is_server and _local_ready) else "-"])
	if quit_after > 0.0:
		_run_time += delta
		if _run_time >= quit_after:
			if is_bot:
				_print_bot_stats()
			_disconnect_and_quit()
			return
	if not is_server:
		_render_clients(delta)
