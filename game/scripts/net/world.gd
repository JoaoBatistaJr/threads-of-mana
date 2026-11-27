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
	var tool := HarvestInfo.Tool.HAND   # equipada automaticamente conforme o recurso
	var target := NO_NODE     # recurso sendo coletado (Vector3i: chunk x, chunk z, índice)
	var progress := 0.0       # 0..1 da coleta atual
	var reported := -1        # último estado informado ao cliente (1 = coletando, 0 = nada)

const NO_NODE := Vector3i(0, 0, -1)

signal disconnected(reason: String, can_retry: bool)
signal entered
signal pause_requested
signal leave_allowed(action: String)

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
var _scene: Node                       # world.tscn (gerador, luz, NPCs): editável no Inspector
var _wg: WorldGenerator
var _sw: ServerWorld                   # servidor: recursos do mundo calculados pela seed
var _node_hits: Dictionary = {}        # Vector3i -> coletas restantes (ausente = cheio)
var _node_respawn: Dictionary = {}     # Vector3i -> segundos para voltar

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
const SYNC_BATCH := 200   # recursos esgotados por pacote (3 inteiros cada)
var _closing := false
var _bot_sw: ServerWorld                # só bot de coleta: acha recursos pela mesma seed
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
const COMBAT_SECONDS := 15.0
var _combat_until: Dictionary = {}   # servidor: peer -> msec até sair do combate
var _leave_action := ""              # cliente: o que fazer quando o servidor liberar a saída
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
	_load_world()
	if is_server:
		_loot = LootBags.new(_inv_items)
		_inv_items.logged.connect(func(e: Dictionary) -> void:
			print("[item] %s %s x%d %s -> %s (%s) uid=%s" % [e["op"], e["id"], e["n"], e["from"], e["to"], e["why"], e["uid"]]))
		_sw = ServerWorld.new(_wg.generator)
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
		disconnected.emit("Não foi possível conectar ao servidor", true))
	multiplayer.server_disconnected.connect(func():
		_closing = true
		disconnected.emit("Servidor reiniciando ou conexão perdida", true))
	_rig = CameraRig.new()
	add_child(_rig)
	var layer := CanvasLayer.new()
	_hud = Hud.new()
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


func _name_taken(n: String) -> bool:
	for pl in _players.values():
		if str(pl.display_name).to_lower() == n.to_lower():
			return true
	return false


# Marca o jogador como "em combate" (o combate chama isto ao causar ou sofrer dano).
func mark_combat(id: int) -> void:
	_combat_until[id] = Time.get_ticks_msec() + int(COMBAT_SECONDS * 1000.0)


func _combat_left(id: int) -> int:
	return maxi(0, ceili((_combat_until.get(id, 0) - Time.get_ticks_msec()) / 1000.0))


func _on_peer_disconnected(id: int) -> void:
	if _combat_left(id) > 0:
		print("[server] %d desconectou em combate (%d s restantes)" % [id, _combat_left(id)])
	_combat_until.erase(id)
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
	if _name_taken(n):
		rejected.rpc_id(id, "Já existe um jogador online com o nome \"%s\"." % n, true)
		multiplayer.multiplayer_peer.disconnect_peer(id)
		print("[server] nome em uso '%s' (conexão %d recusada)" % [n, id])
		return
	var p := ServerPlayer.new()
	p.display_name = n
	p.state.terrain = _terrain
	p.state.pos = Vector3(randf_range(-5.0, 5.0), 0.0, randf_range(-5.0, 5.0))
	p.state.pos.y = _terrain.height(p.state.pos.x, p.state.pos.z)   # cidade inicial (spawn em 0,0)
	_players[id] = p
	_inv_items.set_capacity(_owner_of(id), Const.INVENTORY_SLOTS)
	for b in _loot.bags.values():
		loot_state.rpc_id(id, b.id, b.pos, true)
	for other in _players:
		if other != id:
			receive_name.rpc_id(id, other, _players[other].display_name)
	receive_name.rpc(id, n)
	var dead := PackedInt32Array()
	for k in _node_respawn:
		dead.append_array(PackedInt32Array([k.x, k.y, k.z]))
	var start := 0
	while start < dead.size() or start == 0:
		sync_dead.rpc_id(id, dead.slice(start, start + SYNC_BATCH * 3), start == 0)
		start += SYNC_BATCH * 3
		if start >= dead.size():
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
		p.target = NO_NODE
		p.progress = 0.0


# Coleta: com a tecla E ligada, o servidor escolhe o recurso mais próximo ao alcance, "equipa" a
# ferramenta certa (pela skill do recurso) e coleta sozinho. Sem recurso ao alcance, desliga.
func _server_gather(id: int, p: ServerPlayer) -> void:
	var best := NO_NODE
	var best_node := {}
	if p.gathering:
		var best_d := Const.GATHER_RANGE
		for n in _sw.nodes_near(p.state.pos, Const.GATHER_RANGE):
			if _node_respawn.has(n["key"]) or n["dist"] > best_d:
				continue
			best_d = n["dist"]
			best = n["key"]
			best_node = n
		if best == NO_NODE:
			p.gathering = false
	if best != p.target:
		p.target = best
		p.progress = 0.0
	if best != NO_NODE:
		var info: HarvestInfo = best_node["info"]
		p.tool = info.tool
		p.progress += Const.DT / info.gather_seconds
		if p.progress >= 1.0:
			p.progress = 0.0
			_server_collect(id, info, best_node["pos"])
			var left: int = int(_node_hits.get(best, info.hits)) - 1
			_node_hits[best] = left
			if left <= 0:
				_node_hits.erase(best)
				_node_respawn[best] = info.respawn_seconds
				node_state.rpc(best.x, best.y, best.z, false)
	var state := 1 if best != NO_NODE else 0
	if _tick % Const.SNAPSHOT_EVERY == 0 and (state == 1 or p.reported != 0):
		gather_progress.rpc_id(id, state, p.progress, p.tool)
		p.reported = state


func _owner_of(id: int) -> String:
	return "player:%d" % id


# Sorteia os drops do recurso (cena editada no Inspector) e cria os itens direto no inventário.
func _server_collect(id: int, info: HarvestInfo, pos: Vector3) -> void:
	var full := false
	for d in info.active_drops(pos):
		if randf() > d.chance:
			continue
		var amount := randi_range(d.min_amount, d.max_amount)
		var q: float = info.quality if d.item.uses_quality() else -1.0
		var r := _inv_items.mint(d.item, amount, _owner_of(id), "coleta:" + info.id, q)
		if int(r.left) > 0:
			full = true
			_loot_drop(id, d.item, int(r.left), q, "coleta:" + info.id)
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
	for k in _node_respawn.keys():
		_node_respawn[k] -= Const.DT
		if _node_respawn[k] <= 0.0:
			_node_respawn.erase(k)
			node_state.rpc(k.x, k.y, k.z, true)


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

# Recursos esgotados no momento (o resto do mundo o cliente gera pela seed).
@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func sync_dead(triples: PackedInt32Array, first: bool) -> void:
	if is_server:
		return
	if first:
		WorldChanges.clear()
	for i in range(0, triples.size() - 2, 3):
		WorldChanges.removed[Vector3i(triples[i], triples[i + 1], triples[i + 2])] = true
	_refresh_all_nodes()


# Pedido de saída (voltar ao menu / sair do jogo): o servidor recusa se o jogador estiver em combate.
@rpc("any_peer", "call_remote", "reliable", Const.CH_RELIABLE)
func leave_request() -> void:
	if not is_server:
		return
	var id := multiplayer.get_remote_sender_id()
	var left := _combat_left(id)
	leave_reply.rpc_id(id, left == 0, left)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func leave_reply(ok: bool, seconds_left: int) -> void:
	if is_server:
		return
	if ok:
		leave_allowed.emit(_leave_action)
	else:
		notice("Você está em combate. Aguarde %d s para sair." % seconds_left)


func request_leave(action: String) -> void:
	_leave_action = action
	if _local_ready and multiplayer.has_multiplayer_peer():
		leave_request.rpc_id(1)
	else:
		leave_allowed.emit(action)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func rejected(reason: String, retry: bool) -> void:
	if not is_server:
		_closing = true
		disconnected.emit(reason, retry)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func kicked(reason: String) -> void:
	if not is_server:
		_closing = true
		disconnected.emit(reason, false)


@rpc("authority", "call_remote", "reliable", Const.CH_RELIABLE)
func node_state(cx: int, cz: int, pi: int, alive: bool) -> void:
	if is_server:
		return
	var key := Vector3i(cx, cz, pi)
	if alive:
		WorldChanges.removed.erase(key)
	else:
		WorldChanges.removed[key] = true
	_refresh_node(key)


@rpc("authority", "call_remote", "unreliable_ordered", Const.CH_SNAPSHOT)
func gather_progress(active: int, progress: float, tool: int) -> void:
	if is_server:
		return
	if active > 0:
		_tool_name = HarvestInfo.TOOL_NAMES[clampi(tool, 0, 3)]
	else:
		_want_gather = false
	_gather_progress = progress if active > 0 else 0.0
	_gather_bar.visible = active > 0
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


# Mantém os objetos do mundo (cliente) iguais ao que o servidor decidiu: esgotado some, voltou reaparece.
func _refresh_node(key: Vector3i) -> void:
	if _wg == null:
		return
	var chunk: TerrainChunk = _wg.chunks.get(Vector2i(key.x, key.y))
	if chunk == null or not chunk.scattered:
		return   # o chunk consulta WorldChanges ao carregar
	var gone := WorldChanges.removed.has(key)
	for c in chunk.get_children():
		if c.has_meta("plc") and c.get_meta("plc") == key:
			if gone:
				c.queue_free()
			return
	if not gone:
		chunk.clear_scatter()
		chunk.scatter(_wg.generator)


func _refresh_all_nodes() -> void:
	if _wg == null:
		return
	for chunk in _wg.chunks.values():
		if (chunk as TerrainChunk).scattered:
			(chunk as TerrainChunk).clear_scatter()
			(chunk as TerrainChunk).scatter(_wg.generator)


# Mundo (world.tscn): o servidor só usa o gerador (altura, bioma, colocações); o cliente desenha.
func _load_world() -> void:
	var packed := load("res://world/world.tscn") as PackedScene
	_scene = packed.instantiate()
	_wg = _scene.get_node("WorldGenerator") as WorldGenerator
	_wg.headless = is_server
	add_child(_scene)
	if _wg.config.world_seed == 0:
		push_error("WorldConfig.world_seed = 0: servidor e clientes gerariam mundos diferentes. Defina uma seed fixa.")
	_terrain = Terrain.new(_wg.generator)


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
		entered.emit()
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
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE:
		if _loot_panel.visible:
			_loot_panel.close_panel()
		elif _inv_panel.visible:
			_inv_panel.toggle()
		else:
			pause_requested.emit()
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


func _update_hud() -> void:
	if _label == null or not _local_ready:
		return
	var biome: String = _terrain.biome_at(_local.pos.x, _local.pos.z)
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
		if _bot_sw == null:
			_bot_sw = ServerWorld.new(_wg.generator)
		var best := {}
		var best_d := INF
		for n in _bot_sw.nodes_near(me_pos, 170.0):
			if WorldChanges.removed.has(n["key"]):
				continue
			if n["dist"] < best_d:
				best_d = n["dist"]
				best = n
		if best.is_empty() or best_d < 1.5:
			return [Vector2.ZERO, 0.0, 0]
		var to: Vector3 = best["pos"] - me_pos
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
	av.add_to_group("grass_actors")
	if id == multiplayer.get_unique_id():
		av.add_to_group("players")   # o gerador de mundo segue este nó
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
