class_name LootBags
extends RefCounted

# Bolsas de loot (servidor). Uma bolsa = 1 entidade leve + uma lista de itens no ItemService
# (dono "loot:<id>"). Sem item solto no chão: o jogador abre a bolsa e pega o que quiser.

const RANGE := 3.5            # m: alcance para abrir/pegar
const CAPACITY := 20          # pilhas por bolsa
const LIFETIME := 120.0       # s até a bolsa sumir
const OWNER_ONLY := 60.0      # s em que só o dono pode abrir

class Bag extends RefCounted:
	var id := 0
	var pos := Vector3.ZERO
	var owner_peer := 0
	var age := 0.0

var svc: ItemService
var bags: Dictionary = {}   # id -> Bag
var _next := 1


func _init(p_svc: ItemService) -> void:
	svc = p_svc


static func owner_key(id: int) -> String:
	return "loot:%d" % id


## Bolsa do dono perto de [param pos] (reaproveita para não criar uma por coleta) ou uma nova.
func bag_for(owner_peer: int, pos: Vector3) -> Bag:
	for b in bags.values():
		if b.owner_peer == owner_peer and b.pos.distance_to(pos) < RANGE and \
				svc.owned_by(owner_key(b.id)).size() < CAPACITY:
			return b
	var bag := Bag.new()
	bag.id = _next
	_next += 1
	bag.pos = pos
	bag.owner_peer = owner_peer
	bags[bag.id] = bag
	svc.set_capacity(owner_key(bag.id), CAPACITY)
	return bag


func can_open(bag: Bag, peer: int, pos: Vector3) -> bool:
	if bag == null or bag.pos.distance_to(pos) > RANGE:
		return false
	return bag.owner_peer == peer or bag.age >= OWNER_ONLY


## Bolsa mais próxima que [param peer] pode abrir (ou null).
func nearest_for(peer: int, pos: Vector3) -> Bag:
	var best: Bag = null
	var best_d := RANGE + 1.0
	for b in bags.values():
		var d: float = b.pos.distance_to(pos)
		if d < best_d and can_open(b, peer, pos):
			best = b
			best_d = d
	return best


## Avança o tempo; retorna os ids removidos (expiraram ou ficaram vazias).
func tick(dt: float) -> Array:
	var gone: Array = []
	for id in bags.keys():
		var b: Bag = bags[id]
		b.age += dt
		var empty := svc.owned_by(owner_key(id)).is_empty()
		if b.age >= LIFETIME or empty:
			svc.destroy_owner(owner_key(id), "bolsa expirou" if not empty else "bolsa vazia")
			svc.capacity.erase(owner_key(id))
			bags.erase(id)
			gone.append(id)
	return gone


func rows(id: int) -> Array:
	var out: Array = []
	for e in svc.owned_by(owner_key(id)):
		out.append([e.uid, e.data.id, e.amount, snappedf(float(e.get("quality", 0.0)), 0.1)])
	return out
