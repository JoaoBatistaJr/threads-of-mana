class_name ItemService
extends RefCounted

# Registro único de TODAS as instâncias de item do servidor (anti-dupe).
# Regras: só o servidor cria (mint); cada instância tem um uid único e um único dono;
# mover/dividir/juntar/destruir são operações atômicas (sem await) e todas vão para o log.
# Entrada = Dictionary compatível com ItemInstance: {uid, data, amount, quality?, durability?, crafter?, owner}.
# Donos: "player:<id>", "loot:<id>", "world".

signal logged(entry: Dictionary)

const LOG_KEEP := 5000

var items: Dictionary = {}        # uid -> entrada
var capacity: Dictionary = {}     # dono -> máx. de pilhas (ausente = ilimitado)
var log: Array = []               # anel em memória; o persistente vem pelo sinal [signal logged]
var _tick := 0


func set_tick(t: int) -> void:
	_tick = t


func set_capacity(owner: String, slots: int) -> void:
	capacity[owner] = slots


# ---------------------------------------------------------------- criação

## Cria itens para [param owner]. Junta em pilhas existentes e abre novas até acabar a capacidade.
## Retorna {"added": int, "left": int, "uids": Array}. O que não coube NÃO é criado.
func mint(data: ItemData, amount: int, owner: String, why: String, quality: float = -1.0, durability: float = -1.0, crafter: String = "") -> Dictionary:
	var res := {"added": 0, "left": amount, "uids": []}
	if data == null or amount <= 0:
		return res
	var limit := data.get_stack_limit()
	var proto := ItemInstance.make(data, 1, quality, durability, crafter)
	var left := amount
	for uid in _owned_uids(owner):
		if left <= 0:
			break
		var e: Dictionary = items[uid]
		if e.amount < limit and ItemInstance.can_stack(e, proto):
			var put := mini(limit - e.amount, left)
			e.amount += put
			left -= put
			res.uids.append(uid)
			_log("mint+", uid, data.id, put, "", owner, why)
	while left > 0 and _has_room(owner):
		var n := mini(limit, left)
		var e := ItemInstance.make(data, n, quality, durability, crafter)
		e["uid"] = _new_uid()
		e["owner"] = owner
		items[e.uid] = e
		left -= n
		res.uids.append(e.uid)
		_log("mint", e.uid, data.id, n, "", owner, why)
	res.added = amount - left
	res.left = left
	return res


# ---------------------------------------------------------------- mover

## Move [param amount] (0 = tudo) da pilha [param uid] de [param from_owner] para [param to_owner].
## Valida dono e capacidade; qualquer falha não altera nada.
func move(uid: String, from_owner: String, to_owner: String, why: String, amount: int = 0) -> bool:
	var e: Dictionary = items.get(uid, {})
	if e.is_empty() or e.owner != from_owner or from_owner == to_owner:
		return false
	var n: int = e.amount if amount <= 0 else amount
	if n > e.amount:
		return false
	var data: ItemData = e.data
	var limit := data.get_stack_limit()
	# 1) quanto cabe juntando em pilhas existentes do destino
	var merge_room := 0
	for u in _owned_uids(to_owner):
		var t: Dictionary = items[u]
		if t.amount < limit and ItemInstance.can_stack(t, e):
			merge_room += limit - t.amount
	# 2) se sobra, precisa de uma pilha nova no destino
	var needs_new := n > merge_room
	if needs_new and not _has_room(to_owner):
		return false
	var left := n
	for u in _owned_uids(to_owner):
		if left <= 0:
			break
		var t: Dictionary = items[u]
		if t.amount < limit and ItemInstance.can_stack(t, e):
			var put := mini(limit - t.amount, left)
			t.amount += put
			left -= put
	var absorbed := n - left
	if absorbed > 0:
		e.amount -= absorbed
		_log("move", uid, data.id, absorbed, from_owner, to_owner, why)
	if left > 0:
		if left == e.amount:
			e.owner = to_owner                      # a própria pilha troca de dono (uid preservado)
			_log("move", uid, data.id, left, from_owner, to_owner, why)
			return true
		var ne := e.duplicate()
		ne.uid = _new_uid()
		ne.amount = left
		ne.owner = to_owner
		items[ne.uid] = ne
		e.amount -= left
		_log("split", ne.uid, data.id, left, from_owner, to_owner, why)
	if e.amount <= 0:
		items.erase(uid)
	return true


# ---------------------------------------------------------------- destruir

## Remove [param amount] do item [param item_id] do dono (crafting, consumo, venda). Atômico: tudo ou nada.
func consume(owner: String, item_id: String, amount: int, why: String) -> bool:
	if count_of(owner, item_id) < amount or amount <= 0:
		return false
	var left := amount
	for uid in _owned_uids(owner):
		var e: Dictionary = items[uid]
		if e.data.id != item_id:
			continue
		var take := mini(e.amount, left)
		e.amount -= take
		left -= take
		_log("destroy", uid, item_id, take, owner, "", why)
		if e.amount <= 0:
			items.erase(uid)
		if left <= 0:
			break
	return true


## Destrói uma pilha inteira (ex.: bolsa expirada). Retorna false se o dono não confere.
func destroy(uid: String, owner: String, why: String) -> bool:
	var e: Dictionary = items.get(uid, {})
	if e.is_empty() or e.owner != owner:
		return false
	_log("destroy", uid, e.data.id, e.amount, owner, "", why)
	items.erase(uid)
	return true


## Destrói tudo de um dono (bolsa/corpo que sumiu). Retorna quantas pilhas.
func destroy_owner(owner: String, why: String) -> int:
	var n := 0
	for uid in _owned_uids(owner):
		if destroy(uid, owner, why):
			n += 1
	return n


# ---------------------------------------------------------------- consulta

func owned_by(owner: String) -> Array:
	var out: Array = []
	for uid in _owned_uids(owner):
		out.append(items[uid])
	return out


func count_of(owner: String, item_id: String) -> int:
	var c := 0
	for uid in _owned_uids(owner):
		var e: Dictionary = items[uid]
		if e.data.id == item_id:
			c += e.amount
	return c


func total_of(item_id: String) -> int:
	var c := 0
	for e in items.values():
		if e.data.id == item_id:
			c += e.amount
	return c


## Verificação de integridade: uid coerente, dono presente, quantidade válida, capacidade respeitada.
func check() -> PackedStringArray:
	var errs := PackedStringArray()
	var per_owner := {}
	for uid in items:
		var e: Dictionary = items[uid]
		if e.uid != uid:
			errs.append("uid divergente " + uid)
		if str(e.get("owner", "")) == "":
			errs.append("sem dono " + uid)
		if e.amount <= 0 or e.amount > e.data.get_stack_limit():
			errs.append("quantidade inválida %s (%d)" % [uid, e.amount])
		per_owner[e.owner] = int(per_owner.get(e.owner, 0)) + 1
	for o in capacity:
		if int(per_owner.get(o, 0)) > int(capacity[o]):
			errs.append("capacidade excedida em " + o)
	return errs


# ---------------------------------------------------------------- interno

func _owned_uids(owner: String) -> Array:
	var out: Array = []
	for uid in items:
		if items[uid].owner == owner:
			out.append(uid)
	return out


func _has_room(owner: String) -> bool:
	if not capacity.has(owner):
		return true
	var n := 0
	for uid in items:
		if items[uid].owner == owner:
			n += 1
	return n < int(capacity[owner])


func _new_uid() -> String:
	var uid := ""
	while uid == "" or items.has(uid):
		uid = Crypto.new().generate_random_bytes(12).hex_encode()
	return uid


func _log(op: String, uid: String, item_id: String, n: int, from_o: String, to_o: String, why: String) -> void:
	var entry := {"tick": _tick, "op": op, "uid": uid, "id": item_id, "n": n, "from": from_o, "to": to_o, "why": why}
	log.append(entry)
	if log.size() > LOG_KEEP:
		log = log.slice(log.size() - LOG_KEEP)
	logged.emit(entry)
