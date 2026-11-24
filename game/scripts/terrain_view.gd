class_name TerrainView
extends Node3D

# Renderiza o terreno em chunks ao redor do jogador (só cliente). Cria poucos chunks por quadro
# e descarta os distantes. Avisa quando um chunk entra/sai para o mundo criar/remover os recursos dele.

signal chunk_loaded(key: Vector2i)
signal chunk_unloaded(key: Vector2i)

var terrain: Terrain
var _chunks: Dictionary = {}   # Vector2i -> MeshInstance3D
var _mat := StandardMaterial3D.new()


func _init() -> void:
	_mat.vertex_color_use_as_albedo = true
	_mat.roughness = 1.0


func loaded_chunks() -> Array:
	return _chunks.keys()


static func key_of(x: float, z: float) -> Vector2i:
	return Vector2i(floori(x / Const.CHUNK_SIZE), floori(z / Const.CHUNK_SIZE))


func update(center: Vector3) -> void:
	var c := key_of(center.x, center.z)
	var lim := int(terrain.half_size / Const.CHUNK_SIZE)
	for key in _chunks.keys():
		if maxi(absi(key.x - c.x), absi(key.y - c.y)) > Const.VIEW_CHUNKS + 1:
			_chunks[key].queue_free()
			_chunks.erase(key)
			chunk_unloaded.emit(key)
	var wanted: Array = []
	for dx in range(-Const.VIEW_CHUNKS, Const.VIEW_CHUNKS + 1):
		for dz in range(-Const.VIEW_CHUNKS, Const.VIEW_CHUNKS + 1):
			var k := Vector2i(c.x + dx, c.y + dz)
			if k.x < -lim or k.x >= lim or k.y < -lim or k.y >= lim or _chunks.has(k):
				continue
			wanted.append(k)
	wanted.sort_custom(func(a: Vector2i, b: Vector2i) -> bool:
		return (a - c).length_squared() < (b - c).length_squared())
	for i in mini(Const.CHUNKS_PER_FRAME, wanted.size()):
		_build(wanted[i])


func _build(key: Vector2i) -> void:
	var cells := Const.CHUNK_CELLS
	var step := Const.CHUNK_SIZE / float(cells)
	var ox := key.x * Const.CHUNK_SIZE
	var oz := key.y * Const.CHUNK_SIZE
	var n := cells + 1
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var cols := PackedColorArray()
	verts.resize(n * n)
	norms.resize(n * n)
	cols.resize(n * n)
	for i in n:
		for j in n:
			var x := ox + i * step
			var z := oz + j * step
			var h := terrain.height(x, z)
			var hx := terrain.height(x + 1.0, z) - terrain.height(x - 1.0, z)
			var hz := terrain.height(x, z + 1.0) - terrain.height(x, z - 1.0)
			var nrm := Vector3(-hx, 2.0, -hz).normalized()
			var idx := i * n + j
			verts[idx] = Vector3(x, h, z)
			norms[idx] = nrm
			cols[idx] = _color(h, nrm.y, x, z)
	var indices := PackedInt32Array()
	for i in cells:
		for j in cells:
			var a := i * n + j
			var b := (i + 1) * n + j
			indices.append_array([a, b, a + 1, b, b + 1, a + 1])
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_COLOR] = cols
	arrays[Mesh.ARRAY_INDEX] = indices
	var mesh := ArrayMesh.new()
	mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	mesh.surface_set_material(0, _mat)
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	add_child(mi)
	_chunks[key] = mi
	chunk_loaded.emit(key)


func _color(h: float, ny: float, x: float, z: float) -> Color:
	var grass := Color(0.30, 0.50, 0.27).lerp(Color(0.40, 0.58, 0.30), clampf(h / 28.0, 0.0, 1.0))
	grass = grass.darkened(0.06 * sin(x * 0.7) * cos(z * 0.6))
	var rock := Color(0.46, 0.45, 0.44)
	var t := smoothstep(0.80, 0.62, ny)   # íngreme -> pedra
	var c := grass.lerp(rock, t)
	if h > 50.0:
		c = c.lerp(Color(0.92, 0.94, 0.97), smoothstep(50.0, 75.0, h))
	return c
