class_name HarvestInfo
extends RefCounted

# Dados de coleta lidos de uma cena de recurso (os exports do HarvestableNode). Só o servidor usa.

enum Tool { AXE, PICKAXE, SICKLE, HAND }
const TOOL_NAMES := ["Machado", "Picareta", "Foice", "Mãos"]
const TOOL_BY_SKILL := {"woodcutting": Tool.AXE, "mining": Tool.PICKAXE, "harvesting": Tool.SICKLE}

var id := ""
var hits := 3
var gather_seconds := 1.5
var respawn_seconds := 120.0
var drops: Array = []
var fruit_drops: Array = []
var fruit_chance := 0.4
var skill := ""
var level := 0
var quality := 20.0
var hand := false
var xp := 10.0
var skill_for_xp := ""
var extra_xp: Dictionary = {}
var tool := Tool.HAND


static func from_scene(scene: PackedScene) -> HarvestInfo:
	if scene == null:
		return null
	var inst := scene.instantiate()
	var node := inst as HarvestableNode
	if node == null:
		inst.free()
		return null
	var info := HarvestInfo.new()
	info.id = scene.resource_path.get_file().get_basename()
	info.hits = maxi(1, node.health)
	info.gather_seconds = maxf(0.2, node.gather_seconds)
	info.respawn_seconds = maxf(1.0, node.respawn_seconds)
	info.drops = node.drops.duplicate()
	info.fruit_drops = node.fruit_drops.duplicate()
	info.fruit_chance = node.fruit_chance
	info.skill = node.required_skill
	info.level = node.required_level
	info.quality = node.node_quality
	info.hand = node.hand_pickup
	info.extra_xp = node.extra_xp_grants.duplicate()
	# Coleta à mão sem skill treina Colheita (hand_xp).
	if node.hand_pickup and node.required_skill.is_empty():
		info.skill_for_xp = "harvesting"
		info.xp = node.hand_xp
	else:
		info.skill_for_xp = node.required_skill
		info.xp = node.xp
	info.tool = TOOL_BY_SKILL.get(node.required_skill, Tool.HAND)
	inst.free()
	return info


# Sorteio único e determinístico (pela posição) de dar frutos.
func bears_fruit(pos: Vector3) -> bool:
	if fruit_drops.is_empty():
		return false
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(roundi(pos.x * 10.0), roundi(pos.y * 10.0), roundi(pos.z * 10.0)))
	return rng.randf() < fruit_chance


func active_drops(pos: Vector3) -> Array:
	var out: Array = []
	for d in drops:
		if d != null and d.item != null:
			out.append(d)
	if bears_fruit(pos):
		for d in fruit_drops:
			if d != null and d.item != null:
				out.append(d)
	return out
