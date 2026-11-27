class_name ChunkScatter
extends RefCounted

const MAX_TRIES: int = 6
const EDGE_FACTOR: float = 0.5

static var _far_cache: Dictionary = {}


# Thread-safe: só calcula posições, não cria nós.
static func compute(gen: TerrainGenerator, coord: Vector2i, heights: PackedFloat32Array) -> Array:
	var cfg: WorldConfig = gen.config
	var size: float = float(cfg.chunk_size)
	var res: int = cfg.chunk_resolution
	var step: float = size / res
	var area_factor: float = size * size / 100.0
	var ox: float = coord.x * size
	var oz: float = coord.y * size
	var occupied: Array[Vector3] = []
	var out: Array = []

	for r in _rule_order(cfg.scatter_rules):
		var rule: ScatterRule = cfg.scatter_rules[r]
		if rule == null or not rule.has_scene():
			continue
		if rule.has_anchor():
			_compute_anchored(gen, cfg, r, rule, coord, heights, out)
			continue

		var rng := RandomNumberGenerator.new()
		rng.seed = hash(Vector3i(coord.x, coord.y, r)) ^ gen.seed_value

		var target: float = rule.density * area_factor
		var count: int = int(target)
		if rng.randf() < target - count:
			count += 1

		for i in count:
			var s: float = rng.randf_range(rule.min_scale, rule.max_scale)
			var yaw: float = rng.randf() * TAU
			var pick: int = rng.randi()
			var tilt_dir: float = rng.randf() * TAU
			var tilt_amount: float = rng.randf()
			var stretch: float = 1.0 + rng.randf_range(-1.0, 1.0) * rule.height_variation

			var radius: float = rule.spacing_radius * s
			var margin: float = radius * EDGE_FACTOR
			var span: float = size - 2.0 * margin
			if span <= 0.0:
				continue

			var x: float = 0.0
			var z: float = 0.0
			var found: bool = false
			for t in MAX_TRIES:
				x = ox + margin + rng.randf() * span
				z = oz + margin + rng.randf() * span
				if _is_free(occupied, x, z, radius):
					found = true
					break
			if not found:
				continue

			if Vector2(x, z).length() < cfg.spawn_clear_radius:
				continue
			var h: float = TerrainChunk.sample_height(heights, res, step, x - ox, z - oz)
			if h < rule.min_height or h > rule.max_height:
				continue
			if cfg.has_sea() and h < cfg.sea_level + 0.3:
				continue
			if cfg.has_sea() and gen.is_near_water(x, z, 2.0):
				continue
			if not rule.biomes.has(gen.get_biome(x, z)):
				continue
			var normal: Vector3 = _normal(gen, x, z)
			if rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))) > rule.max_slope_deg:
				continue

			var variant: int = _variant_index(rule, pick)
			if variant < 0 and rule.scene == null:
				continue
			occupied.append(Vector3(x, z, radius))

			var b: Basis = _basis(rule, normal, s, stretch, yaw, tilt_dir, tilt_amount)

			out.append({
				"rule": r,
				"variant": variant,
				"far": rule.far_lod,
				"t": Transform3D(b, Vector3(x - ox, h + rule.y_offset, z - oz)),
			})
	return out


## Regras normais primeiro; regras com âncora depois (precisam das posições das outras).
static func _rule_order(rules: Array) -> Array[int]:
	var order: Array[int] = []
	var later: Array[int] = []
	for r in rules.size():
		var rule: ScatterRule = rules[r]
		if rule != null and rule.has_anchor():
			later.append(r)
		else:
			order.append(r)
	order.append_array(later)
	return order


static func _basis(rule: ScatterRule, normal: Vector3, s: float, stretch: float, yaw: float, tilt_dir: float, tilt_amount: float) -> Basis:
	var up: Vector3 = Vector3.UP.lerp(normal, rule.slope_align).normalized()
	if rule.random_tilt_deg > 0.0:
		var axis := Vector3(cos(tilt_dir), 0.0, sin(tilt_dir))
		up = up.rotated(axis, deg_to_rad(rule.random_tilt_deg) * tilt_amount)
	var b := Basis(Quaternion(Vector3.UP, up))
	if rule.random_yaw:
		b = b * Basis(Vector3.UP, yaw)
	return b * Basis.from_scale(Vector3(s, s * stretch, s))


static func _rule_uses(rule: ScatterRule, scenes: Array[PackedScene]) -> bool:
	for sc in scenes:
		if sc == null:
			continue
		if rule.scene != null and (rule.scene == sc or (sc.resource_path != "" and rule.scene.resource_path == sc.resource_path)):
			return true
		for v in rule.variants:
			if v != null and (v == sc or (sc.resource_path != "" and v.resource_path == sc.resource_path)):
				return true
	return false


## Objetos que nascem ao redor (anchor_min_radius..anchor_max_radius) de objetos de outras regras
## já colocados neste chunk (ex.: pedras soltas perto das pedras mineráveis).
static func _compute_anchored(gen: TerrainGenerator, cfg: WorldConfig, r: int, rule: ScatterRule, coord: Vector2i, heights: PackedFloat32Array, out: Array) -> void:
	var size: float = float(cfg.chunk_size)
	var res: int = cfg.chunk_resolution
	var step: float = size / res
	var ox: float = coord.x * size
	var oz: float = coord.y * size
	var anchors: Array[Vector2] = []
	for p in out:
		var other: ScatterRule = cfg.scatter_rules[p["rule"]]
		if other != null and other != rule and _rule_uses(other, rule.anchor_scenes):
			var at: Transform3D = p["t"]
			anchors.append(Vector2(at.origin.x + ox, at.origin.z + oz))
	if anchors.is_empty():
		return

	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, r)) ^ gen.seed_value
	var local: Array[Vector3] = []
	for a in anchors:
		for k in rule.per_anchor:
			var roll: float = rng.randf()
			var s: float = rng.randf_range(rule.min_scale, rule.max_scale)
			var ang: float = rng.randf() * TAU
			var dist: float = rng.randf_range(rule.anchor_min_radius, rule.anchor_max_radius)
			var yaw: float = rng.randf() * TAU
			var pick: int = rng.randi()
			var tilt_dir: float = rng.randf() * TAU
			var tilt_amount: float = rng.randf()
			var stretch: float = 1.0 + rng.randf_range(-1.0, 1.0) * rule.height_variation
			if roll > rule.anchor_chance:
				continue
			var x: float = a.x + cos(ang) * dist
			var z: float = a.y + sin(ang) * dist
			if x < ox + 0.3 or x > ox + size - 0.3 or z < oz + 0.3 or z > oz + size - 0.3:
				continue
			var radius: float = rule.spacing_radius * s
			if not _is_free(local, x, z, radius):
				continue
			if Vector2(x, z).length() < cfg.spawn_clear_radius:
				continue
			var h: float = TerrainChunk.sample_height(heights, res, step, x - ox, z - oz)
			if h < rule.min_height or h > rule.max_height:
				continue
			if cfg.has_sea() and (h < cfg.sea_level + 0.3 or gen.is_near_water(x, z, 2.0)):
				continue
			var normal: Vector3 = _normal(gen, x, z)
			if rad_to_deg(acos(clampf(normal.y, -1.0, 1.0))) > rule.max_slope_deg:
				continue
			var variant: int = _variant_index(rule, pick)
			if variant < 0 and rule.scene == null:
				continue
			local.append(Vector3(x, z, radius))
			var b: Basis = _basis(rule, normal, s, stretch, yaw, tilt_dir, tilt_amount)
			out.append({
				"rule": r,
				"variant": variant,
				"far": rule.far_lod,
				"t": Transform3D(b, Vector3(x - ox, h + rule.y_offset, z - oz)),
			})


# Main thread: instancia as cenas completas (perto do player).
static func populate(chunk: TerrainChunk, gen: TerrainGenerator) -> void:
	var rules: Array = gen.config.scatter_rules
	for pi in chunk.placements.size():
		var p: Dictionary = chunk.placements[pi]
		if WorldChanges.is_removed(chunk.coord, pi):
			continue
		var ri: int = p["rule"]
		if ri >= rules.size():
			continue
		var rule: ScatterRule = rules[ri]
		if rule == null:
			continue
		var vi: int = p["variant"]
		var packed: PackedScene = rule.scene if vi < 0 else rule.variants[vi]
		if packed == null:
			continue
		var inst: Node = packed.instantiate()
		if not inst is Node3D:
			inst.queue_free()
			continue
		var node := inst as Node3D
		chunk.add_child(node)
		node.transform = p["t"]
		node.set_meta("plc", Vector3i(chunk.coord.x, chunk.coord.y, pi))
		var hp: int = WorldChanges.health_of(chunk.coord, pi)
		if hp >= 0 and "health" in node:
			node.set("health", hp)
		if rule.camera_fade:
			CameraFade.apply(node, 1.2, 3.5)


# Meshes da cena (com transform relativo à raiz) para o MultiMesh distante.
static func far_parts(rule: ScatterRule, variant: int) -> Array:
	var packed: PackedScene = rule.scene if variant < 0 else rule.variants[variant]
	if packed == null:
		return []
	var key: int = packed.get_instance_id()
	if _far_cache.has(key):
		return _far_cache[key]
	var parts: Array = []
	var inst: Node = packed.instantiate()
	_collect_parts(inst, Transform3D.IDENTITY, parts)
	inst.free()
	_far_cache[key] = parts
	return parts


static func _collect_parts(node: Node, acc: Transform3D, out: Array) -> void:
	for c in node.get_children():
		var t: Transform3D = acc
		if c is Node3D:
			var n3 := c as Node3D
			if not n3.visible:
				continue
			t = acc * n3.transform
		if c is MeshInstance3D:
			var mi := c as MeshInstance3D
			if mi.mesh != null:
				out.append({"mesh": mi.mesh, "xform": t})
		_collect_parts(c, t, out)


static func _variant_index(rule: ScatterRule, pick: int) -> int:
	if rule.variants.is_empty():
		return -1
	var v: int = pick % rule.variants.size()
	return v if rule.variants[v] != null else -1


static func _is_free(occupied: Array[Vector3], x: float, z: float, radius: float) -> bool:
	for o in occupied:
		var dx: float = o.x - x
		var dz: float = o.y - z
		var min_d: float = o.z + radius
		if dx * dx + dz * dz < min_d * min_d:
			return false
	return true


static func _normal(gen: TerrainGenerator, x: float, z: float) -> Vector3:
	var e: float = 1.0
	var dx: float = gen.get_height(x - e, z) - gen.get_height(x + e, z)
	var dz: float = gen.get_height(x, z - e) - gen.get_height(x, z + e)
	return Vector3(dx, 2.0 * e, dz).normalized()
