class_name TerrainChunk
extends StaticBody3D

static var _fallback_material: StandardMaterial3D

var coord: Vector2i
var scattered: bool = false
var placements: Array = []
var placements_state: int = 0 # 0 = sem, 1 = calculando, 2 = pronto

var _heights := PackedFloat32Array()
var _res: int = 0
var _step: float = 1.0
var _mesh: ArrayMesh
var _mesh_instance: MeshInstance3D
var _water_instance: MeshInstance3D
var _collision: CollisionShape3D
var _far_root: Node3D
var _far_stale: bool = false
## 0 = sem grama, 1 = calculando, 2 = pronta.
var grass_state: int = 0
## Nível de detalhe com que a grama atual foi gerada (0 = perto, 1 = longe).
var grass_lod: int = 0
## True quando o nível de detalhe atual não serve mais e a grama deve ser regerada.
var grass_stale: bool = false
var _grass_instance: MultiMeshInstance3D


static func _get_fallback() -> StandardMaterial3D:
	if _fallback_material == null:
		_fallback_material = StandardMaterial3D.new()
		_fallback_material.vertex_color_use_as_albedo = true
		_fallback_material.roughness = 1.0
	return _fallback_material


static func sample_height(heights: PackedFloat32Array, res: int, step: float, lx: float, lz: float) -> float:
	var fx: float = clampf(lx / step, 0.0, res - 0.0001)
	var fz: float = clampf(lz / step, 0.0, res - 0.0001)
	var ix: int = int(fx)
	var iz: int = int(fz)
	var tx: float = fx - ix
	var tz: float = fz - iz
	var row: int = res + 1
	var ha: float = heights[iz * row + ix]
	var hb: float = heights[iz * row + ix + 1]
	var hc: float = heights[(iz + 1) * row + ix]
	var hd: float = heights[(iz + 1) * row + ix + 1]
	if tx + tz <= 1.0:
		return ha + (hb - ha) * tx + (hc - ha) * tz
	return hd + (hc - hd) * (1.0 - tx) + (hb - hd) * (1.0 - tz)


# Thread-safe: só calcula dados, não toca na árvore nem em servidores.
static func compute(gen: TerrainGenerator, p_coord: Vector2i, out: Dictionary) -> void:
	var res: int = gen.config.chunk_resolution
	var size: float = float(gen.config.chunk_size)
	var step: float = size / res
	var ox: float = p_coord.x * size
	var oz: float = p_coord.y * size

	var n: int = res + 3
	var row: int = res + 1
	var hs := PackedFloat32Array()
	hs.resize(n * n)
	for iz in n:
		for ix in n:
			hs[iz * n + ix] = gen.get_height(ox + (ix - 1) * step, oz + (iz - 1) * step)

	var count: int = row * row
	var heights := PackedFloat32Array()
	heights.resize(count)
	var vertices := PackedVector3Array()
	vertices.resize(count)
	var normals := PackedVector3Array()
	normals.resize(count)
	var colors := PackedColorArray()
	colors.resize(count)
	var custom := PackedFloat32Array()
	custom.resize(count * 4)

	for iz in row:
		for ix in row:
			var i: int = iz * row + ix
			var h: float = hs[(iz + 1) * n + ix + 1]
			heights[i] = h
			var dx: float = hs[(iz + 1) * n + ix] - hs[(iz + 1) * n + ix + 2]
			var dz: float = hs[iz * n + ix + 1] - hs[(iz + 2) * n + ix + 1]
			var w := gen.get_weights(ox + ix * step, oz + iz * step, h)
			var layers: Color = gen.layers_from_weights(w)
			vertices[i] = Vector3(ix * step, h, iz * step)
			normals[i] = Vector3(dx, 2.0 * step, dz).normalized()
			colors[i] = gen.color_from_weights(w)
			custom[i * 4] = layers.r
			custom[i * 4 + 1] = layers.g
			custom[i * 4 + 2] = layers.b
			custom[i * 4 + 3] = layers.a

	var indices := PackedInt32Array()
	indices.resize(res * res * 6)
	var k: int = 0
	for iz in res:
		for ix in res:
			var a: int = iz * row + ix
			var b: int = a + 1
			var c: int = a + row
			var d: int = c + 1
			indices[k] = a
			indices[k + 1] = b
			indices[k + 2] = c
			indices[k + 3] = b
			indices[k + 4] = d
			indices[k + 5] = c
			k += 6

	out["heights"] = heights
	out["vertices"] = vertices
	out["normals"] = normals
	out["colors"] = colors
	out["custom"] = custom
	out["indices"] = indices
	if gen.config.river_water:
		gen.river_mesh(p_coord, out)


# Main thread.
func apply(gen: TerrainGenerator, p_coord: Vector2i, data: Dictionary) -> void:
	coord = p_coord
	var size: float = float(gen.config.chunk_size)
	_res = gen.config.chunk_resolution
	_step = size / _res
	position = Vector3(coord.x * size, 0.0, coord.y * size)
	_heights = data["heights"]
	if data.has("placements"):
		placements = data["placements"]
		placements_state = 2

	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = data["vertices"]
	arrays[Mesh.ARRAY_NORMAL] = data["normals"]
	arrays[Mesh.ARRAY_COLOR] = data["colors"]
	arrays[Mesh.ARRAY_CUSTOM0] = data["custom"]
	arrays[Mesh.ARRAY_INDEX] = data["indices"]
	var flags: int = Mesh.ARRAY_CUSTOM_RGBA_FLOAT << Mesh.ARRAY_FORMAT_CUSTOM0_SHIFT

	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays, [], {}, flags)

	_mesh_instance = MeshInstance3D.new()
	_mesh_instance.mesh = _mesh
	_mesh_instance.material_override = gen.config.terrain_material if gen.config.terrain_material != null else _get_fallback()
	add_child(_mesh_instance)

	if data.has("water_v"):
		var wv: PackedVector3Array = data["water_v"]
		var wn := PackedVector3Array()
		wn.resize(wv.size())
		wn.fill(Vector3.UP)
		var warrays := []
		warrays.resize(Mesh.ARRAY_MAX)
		warrays[Mesh.ARRAY_VERTEX] = wv
		warrays[Mesh.ARRAY_NORMAL] = wn
		warrays[Mesh.ARRAY_INDEX] = data["water_i"]
		var wmesh := ArrayMesh.new()
		wmesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, warrays)
		_water_instance = MeshInstance3D.new()
		_water_instance.mesh = wmesh
		_water_instance.material_override = Ocean.shared_material(gen.config)
		_water_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_water_instance)


func get_heights() -> PackedFloat32Array:
	return _heights


func get_surface_height(lx: float, lz: float) -> float:
	return sample_height(_heights, _res, _step, lx, lz)


# --- Colisão ---

func has_collision() -> bool:
	return _collision != null


func enable_collision() -> void:
	if _collision != null or _mesh == null:
		return
	_collision = CollisionShape3D.new()
	_collision.shape = _mesh.create_trimesh_shape()
	add_child(_collision)


func disable_collision() -> void:
	if _collision == null:
		return
	_collision.queue_free()
	_collision = null


# --- Objetos perto (cenas completas) ---

func scatter(gen: TerrainGenerator) -> void:
	if scattered or placements_state != 2:
		return
	scattered = true
	ChunkScatter.populate(self, gen)
	if _far_root != null:
		_far_root.visible = false


func clear_scatter() -> void:
	if not scattered:
		return
	scattered = false
	for c in get_children():
		if c != _mesh_instance and c != _collision and c != _far_root and c != _water_instance and c != _grass_instance:
			c.queue_free()
	if _far_stale:
		_far_stale = false
		clear_far()
		var gen_node := get_parent()
		if gen_node != null:
			gen_node.set("_dirty", true)
	if _far_root != null:
		_far_root.visible = true


# --- Objetos longe (MultiMesh) ---

func has_far() -> bool:
	return _far_root != null


func build_far(cfg: WorldConfig) -> void:
	if _far_root != null or placements_state != 2:
		return
	var groups := {}
	for pi in placements.size():
		var p: Dictionary = placements[pi]
		if not p["far"] or WorldChanges.is_removed(coord, pi):
			continue
		var key := Vector2i(p["rule"], p["variant"])
		if not groups.has(key):
			groups[key] = []
		groups[key].append(p["t"])
	if groups.is_empty():
		return

	_far_root = Node3D.new()
	_far_root.visible = not scattered
	add_child(_far_root)

	for key in groups:
		var k: Vector2i = key
		if k.x >= cfg.scatter_rules.size():
			continue
		var rule: ScatterRule = cfg.scatter_rules[k.x]
		if rule == null:
			continue
		var list: Array = groups[k]
		for part in ChunkScatter.far_parts(rule, k.y):
			var xf: Transform3D = part["xform"]
			var mm := MultiMesh.new()
			mm.transform_format = MultiMesh.TRANSFORM_3D
			mm.mesh = part["mesh"]
			mm.instance_count = list.size()
			for i in list.size():
				var t: Transform3D = list[i]
				mm.set_instance_transform(i, t * xf)
			var mmi := MultiMeshInstance3D.new()
			mmi.multimesh = mm
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			_far_root.add_child(mmi)


func clear_far() -> void:
	if _far_root == null:
		return
	_far_root.queue_free()
	_far_root = null


# --- Grama ---

## Cria ou atualiza a grama do chunk a partir do resultado de [method GrassScatter.compute].
## Se já existe grama, ela é trocada no mesmo frame (sem sumir enquanto a nova é gerada).
func apply_grass(data: Dictionary, cfg: WorldConfig, lod: int = 0) -> void:
	grass_state = 2
	grass_lod = lod
	grass_stale = false
	if data.is_empty():
		if _grass_instance != null:
			_grass_instance.queue_free()
			_grass_instance = null
		return
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_colors = true
	mm.mesh = GrassScatter.tuft_mesh()
	mm.instance_count = int(data["count"])
	mm.buffer = data["buffer"]
	if _grass_instance == null:
		_grass_instance = MultiMeshInstance3D.new()
		_grass_instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_grass_instance)
	_grass_instance.multimesh = mm
	_grass_instance.material_override = GrassScatter.material(cfg)
	# Caixa de visibilidade explícita: sem ela o chunk some ao girar a câmera (culling errado).
	var size: float = float(cfg.chunk_size)
	var y0: float = float(data.get("min_y", -50.0)) - 1.0
	var y1: float = float(data.get("max_y", 200.0)) + 2.5
	_grass_instance.custom_aabb = AABB(Vector3(-1.0, y0, -1.0), Vector3(size + 2.0, y1 - y0, size + 2.0))


func clear_grass() -> void:
	grass_state = 0
	grass_stale = false
	if _grass_instance != null:
		_grass_instance.queue_free()
		_grass_instance = null


# --- Mudanças no mundo / descarga ---

func on_placement_removed() -> void:
	_far_stale = true


func free_placements() -> void:
	placements = []
	placements_state = 0


func release_all() -> void:
	clear_scatter()
	clear_far()
	clear_grass()
	disable_collision()
	free_placements()
