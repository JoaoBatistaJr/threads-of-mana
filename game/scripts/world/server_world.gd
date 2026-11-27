class_name ServerWorld
extends RefCounted

# Mundo do ponto de vista do SERVIDOR: sem malhas nem nós. Recalcula (pela seed) as mesmas colocações
# que o cliente desenha e responde "quais recursos existem perto de X". Ids = Vector3i(chunk.x, chunk.y, índice).

const CACHE_MAX := 256

var generator: TerrainGenerator
var config: WorldConfig
var _plc: Dictionary = {}       # Vector2i -> Array (colocações)
var _order: Array[Vector2i] = []
var _infos: Dictionary = {}     # "rule:variant" -> HarvestInfo | null


func _init(p_gen: TerrainGenerator) -> void:
	generator = p_gen
	config = p_gen.config


func chunk_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / config.chunk_size), floori(z / config.chunk_size))


func placements(coord: Vector2i) -> Array:
	if _plc.has(coord):
		return _plc[coord]
	var res: int = config.chunk_resolution
	var size: float = float(config.chunk_size)
	var step: float = size / res
	var ox: float = coord.x * size
	var oz: float = coord.y * size
	var row := res + 1
	var heights := PackedFloat32Array()
	heights.resize(row * row)
	for iz in row:
		for ix in row:
			heights[iz * row + ix] = generator.get_height(ox + ix * step, oz + iz * step)
	var out: Array = ChunkScatter.compute(generator, coord, heights)
	_plc[coord] = out
	_order.append(coord)
	if _order.size() > CACHE_MAX:
		_plc.erase(_order.pop_front())
	return out


func info_of(p: Dictionary) -> HarvestInfo:
	var ri: int = p["rule"]
	var vi: int = p["variant"]
	var k := "%d:%d" % [ri, vi]
	if _infos.has(k):
		return _infos[k]
	var rule: ScatterRule = config.scatter_rules[ri] if ri < config.scatter_rules.size() else null
	var scene: PackedScene = null
	if rule != null:
		scene = rule.scene if vi < 0 else rule.variants[vi]
	var info := HarvestInfo.from_scene(scene)
	_infos[k] = info
	return info


func position_of(coord: Vector2i, p: Dictionary) -> Vector3:
	var size: float = float(config.chunk_size)
	return Vector3(coord.x * size, 0.0, coord.y * size) + (p["t"] as Transform3D).origin


# Recursos coletáveis num raio (plano XZ). Cada item: {key: Vector3i, pos: Vector3, info: HarvestInfo, dist: float}.
func nodes_near(pos: Vector3, radius: float) -> Array:
	var out: Array = []
	var lo := chunk_of(pos.x - radius, pos.z - radius)
	var hi := chunk_of(pos.x + radius, pos.z + radius)
	for cz in range(lo.y, hi.y + 1):
		for cx in range(lo.x, hi.x + 1):
			var coord := Vector2i(cx, cz)
			var list := placements(coord)
			for pi in list.size():
				var p_world := position_of(coord, list[pi])
				var d := Vector2(p_world.x - pos.x, p_world.z - pos.z).length()
				if d > radius:
					continue
				var info := info_of(list[pi])
				if info == null:
					continue
				out.append({"key": Vector3i(cx, cz, pi), "pos": p_world, "info": info, "dist": d})
	return out


func node_at(key: Vector3i) -> Dictionary:
	var coord := Vector2i(key.x, key.y)
	var list := placements(coord)
	if key.z < 0 or key.z >= list.size():
		return {}
	var info := info_of(list[key.z])
	if info == null:
		return {}
	return {"key": key, "pos": position_of(coord, list[key.z]), "info": info}
