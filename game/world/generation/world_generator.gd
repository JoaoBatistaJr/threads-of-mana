class_name WorldGenerator
extends Node3D

enum Work { COLLISION, SCATTER, FAR, DROP_FAR, DROP_SCATTER, DROP_COLLISION, DROP_PLACEMENTS, DROP_GRASS }

@export var config: WorldConfig
## Servidor (sem tela): só calcula altura/bioma/colocações, não cria malhas nem objetos. Definido pelo código.
var headless: bool = false
## Colisão do terreno. O online decide o movimento pela altura do terreno, então fica desligada.
@export var collision_enabled: bool = true

@export_group("Raios (em chunks)")
@export_range(1, 12) var object_distance: int = 6
@export_range(1, 12) var collision_distance: int = 6
@export_range(1, 40) var far_object_distance: int = 10
@export_range(0, 4) var unload_margin: int = 1

@export_group("Desempenho")
@export_range(1, 8) var max_jobs: int = 3
@export_range(0.5, 12.0, 0.5) var frame_budget_ms: float = 3.0
@export_range(0.1, 2.0, 0.1) var resort_interval: float = 0.3

const SYNC_RADIUS: int = 2
## Altura (m) acima do chão em que o jogador nasce.
const SPAWN_LIFT: float = 1.5
## Raio padrão (m) em que uma entidade amassa a grama.
const GRASS_ACTOR_RADIUS: float = 1.1

var generator: TerrainGenerator
var chunks: Dictionary = {}

var _pending: Array[Vector2i] = []
var _jobs: Dictionary = {}
var _work: Array = []
var _work_i: int = 0
var _plc_list: Array = []
var _grass_list: Array = []
var _dirty: bool = true
var _center: Vector2i = Vector2i(1 << 20, 1 << 20)
var _resort_left: float = 0.0


func _ready() -> void:
	add_to_group("world_generator")
	if config == null:
		config = WorldConfig.new()
	generator = TerrainGenerator.new(config)
	print("Seed do mundo: ", generator.seed_value)
	if headless:
		set_process(false)
		return

	if config.has_sea():
		var ocean := Ocean.new()
		add_child(ocean)
		ocean.setup(config)

	_update_chunks(Vector2i.ZERO)

	var vd: int = config.view_distance
	for dz in range(-SYNC_RADIUS, SYNC_RADIUS + 1):
		for dx in range(-SYNC_RADIUS, SYNC_RADIUS + 1):
			var d2: int = dx * dx + dz * dz
			if d2 > SYNC_RADIUS * SYNC_RADIUS or d2 > vd * vd:
				continue
			var coord := Vector2i(dx, dz)
			if chunks.has(coord):
				continue
			_pending.erase(coord)
			var data := {}
			TerrainChunk.compute(generator, coord, data)
			data["placements"] = ChunkScatter.compute(generator, coord, data["heights"])
			var chunk := _add_chunk(coord, data)
			if collision_enabled:
				chunk.enable_collision()
			chunk.scatter(generator)
			chunk.build_far(config)
			var gr: int = _grass_radius()
			if gr > 0 and d2 <= gr * gr:
				var lod: int = _grass_lod(d2, null)
				chunk.apply_grass(GrassScatter.compute(generator, coord, data["heights"], lod), config, lod)


func _process(delta: float) -> void:
	var player := get_tree().get_first_node_in_group("players") as Node3D
	if player != null:
		var c := _world_to_chunk(player.global_position)
		if c != _center:
			_update_chunks(c)

	_resort_left -= delta
	if _resort_left <= 0.0 and _pending.size() > 1:
		_resort_left = resort_interval
		_sort_pending()

	_update_grass_actors()
	_start_jobs()
	_do_work()


func _exit_tree() -> void:
	for job in _jobs.values():
		WorkerThreadPool.wait_for_task_completion(job["id"])


func get_height(x: float, z: float) -> float:
	return generator.get_height(x, z)


func get_biome(x: float, z: float) -> String:
	return generator.get_biome(x, z)


## Tier (0 = cidade inicial) do ponto. Use para mobs, loot e qualidade.
func get_tier(x: float, z: float) -> int:
	return generator.get_tier(x, z)


## Ponto de nascimento e de renascimento do jogador: centro da cidade inicial, sobre o chão.
func get_spawn_point() -> Vector3:
	return Vector3(0.0, generator.get_height(0.0, 0.0) + SPAWN_LIFT, 0.0)


## Raio (m) da cidade inicial plana.
func get_town_radius() -> float:
	return config.spawn_flat_radius


func _world_to_chunk(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / config.chunk_size), floori(pos.z / config.chunk_size))


func _in_world(coord: Vector2i) -> bool:
	if not config.has_sea():
		return true
	var center := (Vector2(coord) + Vector2(0.5, 0.5)) * config.chunk_size
	return center.length() <= config.world_extent()


func _plc_radius() -> int:
	return maxi(object_distance, far_object_distance)


## Envia ao shader a posição dos nós do grupo "grass_actors" (jogador, mobs) mais perto da câmera.
## Para um nó amassar a grama: add_to_group("grass_actors"); raio opcional em set_meta("grass_radius", 1.1).
func _update_grass_actors() -> void:
	if not config.grass_enabled:
		return
	var cam := get_viewport().get_camera_3d()
	var origin: Vector3 = cam.global_position if cam != null else Vector3.ZERO
	var nodes: Array = []
	for n in get_tree().get_nodes_in_group("grass_actors"):
		if n is Node3D and (n as Node3D).is_visible_in_tree():
			nodes.append(n)
	if nodes.size() > GrassScatter.MAX_ACTORS:
		nodes.sort_custom(func(a: Node3D, b: Node3D) -> bool:
			return a.global_position.distance_squared_to(origin) < b.global_position.distance_squared_to(origin))
	var out: Array = []
	for n in nodes.slice(0, GrassScatter.MAX_ACTORS):
		var p: Vector3 = (n as Node3D).global_position
		out.append(Vector4(p.x, p.y, p.z, float(n.get_meta("grass_radius", GRASS_ACTOR_RADIUS))))
	GrassScatter.set_actors(out)


## Nível de detalhe da grama para um chunk a [param d2] (distância² em chunks). Com histerese:
## um chunk que já é "perto" só vira "longe" um chunk depois, evitando regerar ao ir e voltar.
func _grass_lod(d2: int, chunk: TerrainChunk) -> int:
	var near: int = config.grass_near_chunks
	if chunk != null and chunk.grass_state == 2 and chunk.grass_lod == 0:
		return 0 if d2 <= (near + 1) * (near + 1) else 1
	return 0 if d2 <= near * near else 1


func _grass_radius() -> int:
	return config.grass_radius if config.grass_enabled else 0


func _scan_radius() -> int:
	return maxi(maxi(maxi(collision_distance, object_distance), far_object_distance), _grass_radius()) + unload_margin


func _update_chunks(center: Vector2i) -> void:
	_center = center
	_dirty = true
	var vd: int = config.view_distance
	_pending.clear()
	for dz in range(-vd, vd + 1):
		for dx in range(-vd, vd + 1):
			if dx * dx + dz * dz <= vd * vd:
				var coord := center + Vector2i(dx, dz)
				if not _in_world(coord):
					continue
				if not chunks.has(coord) and not _jobs.has(Vector3i(coord.x, coord.y, 0)):
					_pending.append(coord)

	var unload: int = vd + unload_margin
	var scan: int = _scan_radius()
	for key in chunks.keys():
		var k: Vector2i = key
		var d2: int = (k - center).length_squared()
		if d2 > unload * unload:
			chunks[k].queue_free()
			chunks.erase(k)
		elif d2 > scan * scan:
			(chunks[k] as TerrainChunk).release_all()

	_sort_pending()


func _sort_pending() -> void:
	var fwd := _camera_forward()
	var keyed: Array = []
	for coord in _pending:
		keyed.append([_score(coord, fwd), coord])
	keyed.sort_custom(func(a: Array, b: Array) -> bool: return a[0] < b[0])
	_pending.clear()
	for entry in keyed:
		_pending.append(entry[1])


func _score(coord: Vector2i, fwd: Vector2) -> float:
	var off := Vector2(coord - _center)
	var d: float = off.length()
	if d < 0.001:
		return 0.0
	return d * (1.0 - 0.5 * off.dot(fwd) / d)


func _camera_forward() -> Vector2:
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return Vector2.ZERO
	var f: Vector3 = -cam.global_transform.basis.z
	var v := Vector2(f.x, f.z)
	return v.normalized() if v.length_squared() > 0.0001 else Vector2.ZERO


# --- Jobs em thread ---

func _start_jobs() -> void:
	while _jobs.size() < max_jobs and not _plc_list.is_empty():
		var obj = _plc_list.pop_front()
		if not is_instance_valid(obj):
			continue
		var chunk := obj as TerrainChunk
		if chunk.is_queued_for_deletion() or chunk.placements_state != 0:
			continue
		chunk.placements_state = 1
		var data := {}
		var id: int = WorkerThreadPool.add_task(_placements_job.bind(chunk.coord, chunk.get_heights(), data))
		_jobs[Vector3i(chunk.coord.x, chunk.coord.y, 1)] = {"id": id, "data": data, "chunk": chunk}

	# Grama perto do jogador tem prioridade sobre o terreno distante (mas deixa 1 vaga para o terreno).
	var grass_slots: int = max_jobs if (_pending.is_empty() or max_jobs < 2) else max_jobs - 1
	while _jobs.size() < grass_slots and not _grass_list.is_empty():
		var gobj = _grass_list.pop_front()
		if not is_instance_valid(gobj):
			continue
		var gchunk := gobj as TerrainChunk
		var needs_grass: bool = gchunk.grass_state == 0 or (gchunk.grass_state == 2 and gchunk.grass_stale)
		if gchunk.is_queued_for_deletion() or not needs_grass:
			continue
		gchunk.grass_state = 1
		var gdata := {}
		var glod: int = _grass_lod((gchunk.coord - _center).length_squared(), null)
		var gid: int = WorkerThreadPool.add_task(_grass_job.bind(gchunk.coord, gchunk.get_heights(), glod, gdata))
		_jobs[Vector3i(gchunk.coord.x, gchunk.coord.y, 2)] = {"id": gid, "data": gdata, "chunk": gchunk, "lod": glod}

	var plc_r: int = _plc_radius()
	while _jobs.size() < max_jobs and not _pending.is_empty():
		var coord: Vector2i = _pending.pop_front()
		var key := Vector3i(coord.x, coord.y, 0)
		if chunks.has(coord) or _jobs.has(key):
			continue
		var with_plc: bool = (coord - _center).length_squared() <= plc_r * plc_r
		var data := {}
		var id: int = WorkerThreadPool.add_task(_terrain_job.bind(coord, data, with_plc))
		_jobs[key] = {"id": id, "data": data}


func _terrain_job(coord: Vector2i, data: Dictionary, with_plc: bool) -> void:
	TerrainChunk.compute(generator, coord, data)
	if with_plc:
		data["placements"] = ChunkScatter.compute(generator, coord, data["heights"])


func _placements_job(coord: Vector2i, heights: PackedFloat32Array, data: Dictionary) -> void:
	data["placements"] = ChunkScatter.compute(generator, coord, heights)


func _grass_job(coord: Vector2i, heights: PackedFloat32Array, lod: int, data: Dictionary) -> void:
	data["grass"] = GrassScatter.compute(generator, coord, heights, lod)


func _finish_one_job() -> bool:
	var vd: int = config.view_distance
	for key in _jobs.keys():
		var k: Vector3i = key
		var job: Dictionary = _jobs[k]
		if not WorkerThreadPool.is_task_completed(job["id"]):
			continue
		WorkerThreadPool.wait_for_task_completion(job["id"])
		_jobs.erase(k)
		var coord := Vector2i(k.x, k.y)
		if k.z == 0:
			if not chunks.has(coord) and (coord - _center).length_squared() <= vd * vd:
				_add_chunk(coord, job["data"])
		elif k.z == 1:
			var obj = job["chunk"]
			if is_instance_valid(obj) and not (obj as TerrainChunk).is_queued_for_deletion():
				var chunk := obj as TerrainChunk
				chunk.placements = job["data"]["placements"]
				chunk.placements_state = 2
		else:
			var gobj = job["chunk"]
			if is_instance_valid(gobj) and not (gobj as TerrainChunk).is_queued_for_deletion():
				var gchunk := gobj as TerrainChunk
				if gchunk.grass_state == 1:
					gchunk.apply_grass(job["data"]["grass"], config, int(job["lod"]))
		_dirty = true
		return true
	return false


func _add_chunk(coord: Vector2i, data: Dictionary) -> TerrainChunk:
	var chunk := TerrainChunk.new()
	add_child(chunk)
	chunk.apply(generator, coord, data)
	chunks[coord] = chunk
	_dirty = true
	return chunk


# --- Trabalho na thread principal, com orçamento por frame ---

func _do_work() -> void:
	var start: int = Time.get_ticks_usec()
	var budget: int = int(frame_budget_ms * 1000.0)
	while _step():
		if Time.get_ticks_usec() - start >= budget:
			break


func _step() -> bool:
	if _finish_one_job():
		return true
	if _dirty:
		_rebuild_work()
	while _work_i < _work.size():
		var item: Array = _work[_work_i]
		_work_i += 1
		var obj = item[2]
		if not is_instance_valid(obj):
			continue
		var chunk := obj as TerrainChunk
		if chunk.is_queued_for_deletion():
			continue
		_execute(item[1], chunk)
		return true
	return false


func _execute(kind: int, chunk: TerrainChunk) -> void:
	match kind:
		Work.COLLISION:
			chunk.enable_collision()
		Work.SCATTER:
			chunk.scatter(generator)
		Work.FAR:
			chunk.build_far(config)
		Work.DROP_FAR:
			chunk.clear_far()
		Work.DROP_SCATTER:
			chunk.clear_scatter()
		Work.DROP_COLLISION:
			chunk.disable_collision()
		Work.DROP_PLACEMENTS:
			chunk.free_placements()
		Work.DROP_GRASS:
			chunk.clear_grass()


func _rebuild_work() -> void:
	_dirty = false
	_work.clear()
	_work_i = 0
	_plc_list.clear()
	_grass_list.clear()

	var col_r: int = collision_distance
	var obj_r: int = object_distance
	var far_r: int = far_object_distance
	var plc_r: int = _plc_radius()
	var m: int = unload_margin
	var scan: int = _scan_radius()

	var col: Array = []
	var sc: Array = []
	var far: Array = []
	var plc: Array = []
	var grs: Array = []
	var drops: Array = []
	var gr: int = _grass_radius()

	for dz in range(-scan, scan + 1):
		for dx in range(-scan, scan + 1):
			var chunk: TerrainChunk = chunks.get(_center + Vector2i(dx, dz))
			if chunk == null:
				continue
			var d2: int = dx * dx + dz * dz
			var has_data: bool = chunk.placements_state == 2

			if collision_enabled and d2 <= col_r * col_r and not chunk.has_collision():
				col.append([d2, Work.COLLISION, chunk])
			if d2 <= plc_r * plc_r and chunk.placements_state == 0:
				plc.append([d2, chunk])
			if gr > 0 and d2 <= gr * gr:
				if chunk.grass_state == 2:
					chunk.grass_stale = chunk.grass_lod != _grass_lod(d2, chunk)
				if chunk.grass_state == 0 or (chunk.grass_state == 2 and chunk.grass_stale):
					grs.append([d2, chunk])
			if chunk.grass_state != 0 and (gr == 0 or d2 > (gr + m) * (gr + m)):
				drops.append([d2, Work.DROP_GRASS, chunk])
			if has_data and d2 <= obj_r * obj_r and not chunk.scattered:
				sc.append([d2, Work.SCATTER, chunk])
			if has_data and d2 <= far_r * far_r and not chunk.has_far():
				far.append([d2, Work.FAR, chunk])

			if d2 > (far_r + m) * (far_r + m) and chunk.has_far():
				drops.append([d2, Work.DROP_FAR, chunk])
			if d2 > (obj_r + m) * (obj_r + m) and chunk.scattered:
				drops.append([d2, Work.DROP_SCATTER, chunk])
			if d2 > (col_r + m) * (col_r + m) and chunk.has_collision():
				drops.append([d2, Work.DROP_COLLISION, chunk])
			if has_data and d2 > (plc_r + m) * (plc_r + m) and not chunk.scattered and not chunk.has_far():
				drops.append([d2, Work.DROP_PLACEMENTS, chunk])

	var by_dist := func(a: Array, b: Array) -> bool: return a[0] < b[0]
	col.sort_custom(by_dist)
	sc.sort_custom(by_dist)
	far.sort_custom(by_dist)
	plc.sort_custom(by_dist)
	grs.sort_custom(by_dist)

	_work = col + sc + far + drops
	for entry in plc:
		_plc_list.append(entry[1])
	for entry in grs:
		_grass_list.append(entry[1])
