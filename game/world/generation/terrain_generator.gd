class_name TerrainGenerator
extends RefCounted

const RIVER_STEP: float = 160.0
const RIVER_GRID: float = 128.0
const RIVER_UPHILL: float = 0.03
const NO_RIVER: Vector4 = Vector4(1.0e9, 0.0, 0.0, 0.0)
## Peso mínimo de um bioma fora do seu tier. Evita buracos quando nenhum bioma permitido serve ao clima.
const TIER_FLOOR: float = 0.02

var config: WorldConfig
var seed_value: int

var _height_noise: FastNoiseLite
var _mountain_mask: FastNoiseLite
var _ridge_noise: FastNoiseLite
var _swell_noise: FastNoiseLite
var _warp_x: FastNoiseLite
var _warp_z: FastNoiseLite
var _detail_noise: FastNoiseLite
var _moisture_noise: FastNoiseLite
var _temperature_noise: FastNoiseLite
var _coast_noise: FastNoiseLite
var _tier_noise: FastNoiseLite
var _river_noise: FastNoiseLite
var _biomes: Array[BiomeData] = []

var _river_active: bool = false
var _rv_pts := PackedVector2Array()
var _rv_perp := PackedVector2Array()
var _rv_wl := PackedFloat32Array()
var _rv_w := PackedFloat32Array()
var _seg_i := PackedInt32Array()
var _river_cells: Dictionary = {}
var _river_chunks: Dictionary = {}

var _heap_cost := PackedFloat32Array()
var _heap_id := PackedInt32Array()
var _pop_cost: float = 0.0


func _init(p_config: WorldConfig) -> void:
	config = p_config
	seed_value = config.world_seed if config.world_seed != 0 else randi()

	_height_noise = FastNoiseLite.new()
	_height_noise.seed = seed_value
	_height_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_height_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_height_noise.fractal_octaves = config.terrain_octaves
	_height_noise.frequency = config.terrain_frequency

	_mountain_mask = _make_noise(seed_value + 3, config.mountain_frequency)
	_ridge_noise = _make_noise(seed_value + 4, config.ridge_frequency)
	_ridge_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_ridge_noise.fractal_octaves = 4

	_swell_noise = _make_noise(seed_value + 7, config.swell_frequency)
	_swell_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_swell_noise.fractal_octaves = 4
	_warp_x = _make_noise(seed_value + 8, config.warp_frequency)
	_warp_z = _make_noise(seed_value + 9, config.warp_frequency)
	_detail_noise = _make_noise(seed_value + 10, config.detail_frequency)

	_coast_noise = _make_noise(seed_value + 5, config.coast_frequency)
	_coast_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_coast_noise.fractal_octaves = 3

	_river_noise = _make_noise(seed_value + 6, 0.004)

	_tier_noise = _make_noise(seed_value + 11, config.tier_noise_frequency)
	_tier_noise.fractal_type = FastNoiseLite.FRACTAL_FBM
	_tier_noise.fractal_octaves = 2

	_moisture_noise = _make_noise(seed_value + 1, config.moisture_frequency)
	_temperature_noise = _make_noise(seed_value + 2, config.temperature_frequency)

	_biomes = config.biomes.duplicate()
	if _biomes.is_empty():
		_biomes = _default_biomes()

	_build_rivers()


# ---------------------------------------------------------------- Relevo

func get_island_mask(x: float, z: float) -> float:
	var radius: float = config.world_radius
	if radius <= 0.0:
		return 1.0
	var d: float = Vector2(x, z).length() + _coast_noise.get_noise_2d(x, z) * config.coast_roughness
	var t: float = (d - (radius - config.coast_width)) / maxf(config.coast_width, 1.0)
	return 1.0 - smoothstep(0.0, 1.0, t)


func get_height(x: float, z: float) -> float:
	var h: float = _base_height(x, z)
	if _river_active:
		h = _apply_river(x, z, h)
	return h


func _base_height(x: float, z: float) -> float:
	var dist := Vector2(x, z).length()
	var flat := smoothstep(config.spawn_flat_radius, config.spawn_blend_radius, dist)
	var land_mask: float = get_island_mask(x, z)
	var inland: float = smoothstep(0.25, 0.85, land_mask)

	var wx: float = x
	var wz: float = z
	if config.warp_strength > 0.0:
		wx += _warp_x.get_noise_2d(x, z) * config.warp_strength
		wz += _warp_z.get_noise_2d(x, z) * config.warp_strength

	# Elevação contínua 0..1: costa baixa -> interior alto. Tudo deriva dela,
	# então planície, colinas, serra e montanha se conectam sem saltos.
	var e: float = clampf(_swell_noise.get_noise_2d(wx, wz) * config.elevation_contrast * 0.5 + 0.5, 0.0, 1.0)
	e *= inland

	# 1) subida larga do terreno com a elevação
	var h: float = e * config.swell_height

	# 2) colinas: mais fortes em áreas altas, nunca zeradas
	var n: float = _height_noise.get_noise_2d(wx, wz)
	n *= lerpf(config.valley_depth, 1.0, smoothstep(-0.15, 0.15, n))
	var hill_k: float = lerpf(0.55, 1.0, smoothstep(0.0, 0.7, e))
	h += n * config.height_scale * hill_k * lerpf(0.5, 1.0, inland)

	# 3) fator de montanha: sobe devagar entre mountain_start e mountain_full
	var mf: float = smoothstep(config.mountain_start, maxf(config.mountain_full, config.mountain_start + 0.01), e)
	mf *= mf

	# 4) patamares fora das montanhas
	if config.terrace_strength > 0.0:
		var q: float = h / config.terrace_step
		var f: float = q - floorf(q)
		var terraced: float = (floorf(q) + smoothstep(0.3, 0.7, f)) * config.terrace_step
		h = lerpf(h, terraced, config.terrace_strength * (1.0 - mf) * inland)

	# 5) serra e picos
	if mf > 0.0:
		var rn: float = _ridge_noise.get_noise_2d(wx, wz)
		var s: float = config.ridge_smoothness
		var ridge: float = maxf(0.0, (1.0 - sqrt(rn * rn + s)) / (1.0 - sqrt(s)))
		var amp: float = lerpf(0.7, 1.0, _mountain_mask.get_noise_2d(wx, wz) * 0.5 + 0.5)
		h += mf * (pow(ridge, 1.5) * amp + config.mountain_base_lift) * config.mountain_height

	# 6) detalhe fino
	h += _detail_noise.get_noise_2d(x, z) * config.detail_height * (1.0 - mf * 0.5)

	var land: float = h * flat
	if config.has_sea():
		return lerpf(-config.sea_depth, land, land_mask)
	return land


# ---------------------------------------------------------------- Tiers

## Tier contínuo: 0 no spawn, +1 a cada distância de [member WorldConfig.tier_distances].
## A distância é deformada por ruído (fronteiras orgânicas), sem deformar a cidade inicial.
func get_tier_f(x: float, z: float) -> float:
	var dists: PackedFloat32Array = config.tier_distances
	var d: float = Vector2(x, z).length()
	if dists.is_empty():
		return 0.0
	var fade: float = smoothstep(config.spawn_blend_radius, maxf(dists[0], config.spawn_blend_radius + 1.0), d)
	d = maxf(d + _tier_noise.get_noise_2d(x, z) * config.tier_warp * fade, 0.0)
	var lo: float = 0.0
	for i in dists.size():
		if d < dists[i]:
			return float(i) + (d - lo) / maxf(dists[i] - lo, 1.0)
		lo = dists[i]
	return float(dists.size()) + minf((d - lo) / maxf(lo * 0.5, 1.0), 0.99)


## Tier inteiro (0 .. tier_distances.size()) do ponto. Use para mobs, loot e qualidade.
func get_tier(x: float, z: float) -> int:
	return clampi(floori(get_tier_f(x, z)), 0, config.tier_distances.size())


## Peso (TIER_FLOOR..1) do bioma [param bd] no tier contínuo [param tf].
func _tier_member(tf: float, bd: BiomeData) -> float:
	var s: float = config.tier_softness
	var top: int = config.tier_distances.size()
	var lo: float = 1.0 if bd.tier_min <= 0 else smoothstep(float(bd.tier_min) - s, float(bd.tier_min) + s, tf)
	var hi: float = 1.0 if bd.tier_max >= top else 1.0 - smoothstep(float(bd.tier_max + 1) - s, float(bd.tier_max + 1) + s, tf)
	return lerpf(TIER_FLOOR, 1.0, lo * hi)


# ---------------------------------------------------------------- Clima

func get_moisture(x: float, z: float) -> float:
	var m: float = _moisture_noise.get_noise_2d(x, z) * config.climate_contrast
	if config.has_sea():
		var coast: float = smoothstep(0.45, 1.0, Vector2(x, z).length() / config.world_radius)
		m += coast * config.coast_wetness
	if _river_active:
		var rv: Vector4 = _river_at(x, z)
		m += config.river_wetness * (1.0 - smoothstep(0.0, 160.0, rv.x))
	return clampf(m, -1.0, 1.0)


func get_temperature(x: float, z: float) -> float:
	var t: float = _temperature_noise.get_noise_2d(x, z) * config.climate_contrast
	if config.has_sea():
		t += clampf(z / config.world_radius, -1.0, 1.0) * config.latitude_strength
	return clampf(t, -1.0, 1.0)


func get_biome(x: float, z: float) -> String:
	var w := get_weights(x, z, get_height(x, z))
	var best: int = _biomes.size() - 1
	var best_w: float = 0.0001
	for i in w.size():
		if w[i] > best_w:
			best_w = w[i]
			best = i
	if best >= _biomes.size():
		return "beach"
	return _biomes[best].id


func get_color(x: float, z: float, height: float) -> Color:
	return color_from_weights(get_weights(x, z, height))


func get_slope_deg(x: float, z: float) -> float:
	var e: float = 1.0
	var dx: float = get_height(x + e, z) - get_height(x - e, z)
	var dz: float = get_height(x, z + e) - get_height(x, z - e)
	return rad_to_deg(atan(sqrt(dx * dx + dz * dz) / (2.0 * e)))


# Último elemento = margem/praia (peso calculado, não é um BiomeData).
func get_weights(x: float, z: float, height: float) -> PackedFloat32Array:
	var a: float = height / config.altitude_scale()
	var t: float = get_temperature(x, z) - maxf(a, 0.0) * config.altitude_cooling
	var m: float = get_moisture(x, z)
	var s: float = config.biome_softness
	var tf: float = get_tier_f(x, z)
	var count: int = _biomes.size()
	var w := PackedFloat32Array()
	w.resize(count + 1)
	var total: float = 0.0
	for i in count:
		var bd: BiomeData = _biomes[i]
		w[i] = _member(t, bd.temperature, s) * _member(m, bd.moisture, s) * _member(a, bd.altitude, s) * _tier_member(tf, bd)
		total += w[i]
	w[count] = _beach_weight(x, z, height, total)
	return w


func _beach_weight(x: float, z: float, height: float, others: float) -> float:
	if not config.has_sea():
		return 0.0
	var f: float = 1.0 - smoothstep(config.sea_level + 0.5, config.sea_level + config.beach_height, height)
	if _river_active:
		var rv: Vector4 = _river_at(x, z)
		var bank: float = maxf(12.0, rv.z * 2.5)
		f = maxf(f, 1.0 - smoothstep(rv.z, rv.z + bank, rv.x))
	f = minf(f, 0.98)
	if f <= 0.001:
		return 0.0
	return f / (1.0 - f) * maxf(others, 0.05)


func color_from_weights(w: PackedFloat32Array) -> Color:
	var count: int = _biomes.size()
	var total: float = 0.0
	var r: float = 0.0
	var g: float = 0.0
	var b: float = 0.0
	for i in w.size():
		var c: Color = _biomes[i].color if i < count else config.beach_color
		total += w[i]
		r += c.r * w[i]
		g += c.g * w[i]
		b += c.b * w[i]
	if total <= 0.0001:
		return _biomes[count - 1].color
	return Color(r / total, g / total, b / total)


func layers_from_weights(w: PackedFloat32Array) -> Color:
	var count: int = _biomes.size()
	var out: Array[float] = [0.0, 0.0, 0.0, 0.0]
	var total: float = 0.0
	for v in w:
		total += v
	if total <= 0.0001:
		var fallback: int = _biomes[count - 1].ground
		if fallback < 4:
			out[fallback] = 1.0
		return Color(out[0], out[1], out[2], out[3])
	for i in w.size():
		var layer: int = _biomes[i].ground if i < count else int(BiomeData.Ground.SAND)
		if layer < 4:
			out[layer] += w[i] / total
	return Color(out[0], out[1], out[2], out[3])


# ---------------------------------------------------------------- Rios

func is_near_water(x: float, z: float, margin: float) -> bool:
	if not _river_active:
		return false
	var rv: Vector4 = _river_at(x, z)
	return rv.x < rv.z + margin


# Vector4(distância ao eixo, nível da água, meia-largura, 0)
func _river_at(x: float, z: float) -> Vector4:
	var key := Vector2i(floori(x / RIVER_GRID), floori(z / RIVER_GRID))
	if not _river_cells.has(key):
		return NO_RIVER
	var list: PackedInt32Array = _river_cells[key]
	var p := Vector2(x, z)
	var best_d2: float = INF
	var best_i: int = -1
	var best_t: float = 0.0
	for si in list:
		var i: int = _seg_i[si]
		var a: Vector2 = _rv_pts[i]
		var ab: Vector2 = _rv_pts[i + 1] - a
		var t: float = clampf((p - a).dot(ab) / maxf(ab.length_squared(), 0.0001), 0.0, 1.0)
		var d2: float = (a + ab * t - p).length_squared()
		if d2 < best_d2:
			best_d2 = d2
			best_i = i
			best_t = t
	if best_i < 0:
		return NO_RIVER
	return Vector4(
		sqrt(best_d2),
		lerpf(_rv_wl[best_i], _rv_wl[best_i + 1], best_t),
		lerpf(_rv_w[best_i], _rv_w[best_i + 1], best_t),
		0.0)


func _apply_river(x: float, z: float, h: float) -> float:
	var rv: Vector4 = _river_at(x, z)
	var w: float = rv.z
	var bank: float = maxf(12.0, w * 2.5)
	var reach: float = w + bank * 2.0
	if rv.x >= reach:
		return h
	var wl: float = rv.y
	var bed: float = minf(wl - config.river_depth, h)
	var raised: float = h
	if wl > config.sea_level + 0.05:
		raised = maxf(h, wl + 0.4)
	var carved: float = lerpf(bed, raised, smoothstep(w, w + bank, rv.x))
	return lerpf(carved, h, smoothstep(w + bank, reach, rv.x))


# Fita de água do chunk (thread-safe). Cada segmento pertence ao chunk do seu ponto médio.
func river_mesh(coord: Vector2i, out: Dictionary) -> void:
	if not _river_active or not _river_chunks.has(coord):
		return
	var list: PackedInt32Array = _river_chunks[coord]
	var size: float = float(config.chunk_size)
	var ox: float = coord.x * size
	var oz: float = coord.y * size
	var verts := PackedVector3Array()
	var idx := PackedInt32Array()
	var sea: float = config.sea_level + 0.05
	for si in list:
		var i: int = _seg_i[si]
		if _rv_wl[i] <= sea and _rv_wl[i + 1] <= sea:
			continue
		var a: Vector2 = _rv_pts[i]
		var b: Vector2 = _rv_pts[i + 1]
		var pa: Vector2 = _rv_perp[i] * (_rv_w[i] * 1.15)
		var pb: Vector2 = _rv_perp[i + 1] * (_rv_w[i + 1] * 1.15)
		var base: int = verts.size()
		verts.append(Vector3(a.x + pa.x - ox, _rv_wl[i], a.y + pa.y - oz))
		verts.append(Vector3(a.x - pa.x - ox, _rv_wl[i], a.y - pa.y - oz))
		verts.append(Vector3(b.x + pb.x - ox, _rv_wl[i + 1], b.y + pb.y - oz))
		verts.append(Vector3(b.x - pb.x - ox, _rv_wl[i + 1], b.y - pb.y - oz))
		idx.append(base)
		idx.append(base + 2)
		idx.append(base + 1)
		idx.append(base + 1)
		idx.append(base + 2)
		idx.append(base + 3)
	if not verts.is_empty():
		out["water_v"] = verts
		out["water_i"] = idx


func _build_rivers() -> void:
	if not config.has_sea() or config.river_count <= 0:
		return

	var ext: float = config.world_radius + config.coast_roughness
	var n: int = int(ceil(ext * 2.0 / RIVER_STEP)) + 1
	var count: int = n * n

	var hs := PackedFloat32Array()
	hs.resize(count)
	var valid := PackedByteArray()
	valid.resize(count)
	for j in n:
		for i in n:
			var px: float = -ext + i * RIVER_STEP
			var pz: float = -ext + j * RIVER_STEP
			var idx: int = j * n + i
			hs[idx] = _base_height(px, pz)
			valid[idx] = 1 if (px * px + pz * pz) <= ext * ext else 0

	# Dijkstra reverso a partir do mar: cada célula aponta para a próxima rio abaixo.
	var dist := PackedFloat32Array()
	dist.resize(count)
	dist.fill(INF)
	var parent := PackedInt32Array()
	parent.resize(count)
	parent.fill(-1)
	_heap_cost.clear()
	_heap_id.clear()

	var sea_h: float = config.sea_level + 0.5
	for idx in count:
		if valid[idx] == 1 and hs[idx] <= sea_h:
			dist[idx] = 0.0
			_heap_push(0.0, idx)

	var dirs: Array[Vector2i] = [
		Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1),
		Vector2i(1, 1), Vector2i(1, -1), Vector2i(-1, 1), Vector2i(-1, -1)]
	while _heap_id.size() > 0:
		var u: int = _heap_pop()
		var cu: float = _pop_cost
		if cu > dist[u]:
			continue
		var ux: int = u % n
		var uy: int = floori(float(u) / float(n))
		for d in dirs:
			var vx: int = ux + d.x
			var vy: int = uy + d.y
			if vx < 0 or vy < 0 or vx >= n or vy >= n:
				continue
			var v: int = vy * n + vx
			if valid[v] == 0:
				continue
			var step: float = RIVER_STEP * (1.4142 if (d.x != 0 and d.y != 0) else 1.0)
			var rise: float = maxf(0.0, hs[u] - hs[v])
			var cost: float = step * (1.0 + RIVER_UPHILL * rise * rise)
			var wx: float = -ext + vx * RIVER_STEP
			var wz: float = -ext + vy * RIVER_STEP
			if wx * wx + wz * wz < 350.0 * 350.0:
				cost *= 6.0
			var nc: float = cu + cost
			if nc < dist[v]:
				dist[v] = nc
				parent[v] = u
				_heap_push(nc, v)

	# Nascentes.
	var rng := RandomNumberGenerator.new()
	rng.seed = seed_value + 777
	var sources: Array[Vector2] = []
	var made: int = 0
	var tries: int = 0
	while made < config.river_count and tries < 800:
		tries += 1
		var ang: float = rng.randf() * TAU
		var rad: float = rng.randf_range(0.2, 0.75) * config.world_radius
		var p := Vector2(cos(ang), sin(ang)) * rad
		var ci: int = clampi(roundi((p.x + ext) / RIVER_STEP), 0, n - 1)
		var cj: int = clampi(roundi((p.y + ext) / RIVER_STEP), 0, n - 1)
		var cell: int = cj * n + ci
		if valid[cell] == 0 or is_inf(dist[cell]) or parent[cell] == -1:
			continue
		var h: float = hs[cell]
		if h < config.sea_level + 6.0 or h > config.altitude_scale() * 0.9:
			continue
		var too_close: bool = false
		for s in sources:
			if s.distance_to(p) < config.river_min_spacing:
				too_close = true
				break
		if too_close:
			continue
		var cells := PackedVector2Array()
		var cur: int = cell
		var guard: int = 0
		while cur != -1 and guard < count:
			cells.append(Vector2(-ext + (cur % n) * RIVER_STEP, -ext + floori(float(cur) / float(n)) * RIVER_STEP))
			cur = parent[cur]
			guard += 1
		if cells.size() < 12:
			continue
		sources.append(p)
		_add_river(cells, made)
		made += 1

	_river_active = _seg_i.size() > 0
	print("Rios gerados: ", made)


func _add_river(raw: PackedVector2Array, river_index: int) -> void:
	var pts := PackedVector2Array(raw)
	# meandro suave
	for k in range(1, pts.size() - 1):
		var dir: Vector2 = (raw[k + 1] - raw[k - 1]).normalized()
		var perp := Vector2(-dir.y, dir.x)
		pts[k] = raw[k] + perp * _river_noise.get_noise_2d(raw[k].x, raw[k].y) * 60.0
	pts = _chaikin(_chaikin(pts))

	var m: int = pts.size()
	var base: int = _rv_pts.size()
	var prev: float = INF
	for k in m:
		var a: Vector2 = pts[maxi(k - 1, 0)]
		var b: Vector2 = pts[mini(k + 1, m - 1)]
		var dir: Vector2 = (b - a).normalized()
		var h: float = _base_height(pts[k].x, pts[k].y)
		var wl: float = maxf(config.sea_level, minf(prev, h - 0.8))
		prev = wl
		var along: float = float(k) / float(m - 1)
		_rv_pts.append(pts[k])
		_rv_perp.append(Vector2(-dir.y, dir.x))
		_rv_wl.append(wl)
		_rv_w.append(lerpf(config.river_width_min, config.river_width_max, along))

	var infl: float = config.river_width_max + 2.0 * maxf(12.0, config.river_width_max * 2.5) + 8.0
	for k in m - 1:
		var si: int = _seg_i.size()
		_seg_i.append(base + k)
		var a: Vector2 = pts[k]
		var b: Vector2 = pts[k + 1]
		var mn := Vector2(minf(a.x, b.x), minf(a.y, b.y)) - Vector2(infl, infl)
		var mx := Vector2(maxf(a.x, b.x), maxf(a.y, b.y)) + Vector2(infl, infl)
		for cx in range(floori(mn.x / RIVER_GRID), floori(mx.x / RIVER_GRID) + 1):
			for cz in range(floori(mn.y / RIVER_GRID), floori(mx.y / RIVER_GRID) + 1):
				var key := Vector2i(cx, cz)
				var arr: PackedInt32Array = _river_cells.get(key, PackedInt32Array())
				arr.append(si)
				_river_cells[key] = arr
		var mid: Vector2 = (a + b) * 0.5
		var ck := Vector2i(floori(mid.x / config.chunk_size), floori(mid.y / config.chunk_size))
		var carr: PackedInt32Array = _river_chunks.get(ck, PackedInt32Array())
		carr.append(si)
		_river_chunks[ck] = carr


func _chaikin(pts: PackedVector2Array) -> PackedVector2Array:
	var out := PackedVector2Array()
	if pts.size() < 3:
		return pts
	out.append(pts[0])
	for i in pts.size() - 1:
		out.append(pts[i].lerp(pts[i + 1], 0.25))
		out.append(pts[i].lerp(pts[i + 1], 0.75))
	out.append(pts[pts.size() - 1])
	return out


func _heap_push(c: float, id: int) -> void:
	_heap_cost.append(c)
	_heap_id.append(id)
	var i: int = _heap_cost.size() - 1
	while i > 0:
		var p: int = (i - 1) >> 1
		if _heap_cost[p] <= _heap_cost[i]:
			break
		_heap_swap(i, p)
		i = p


func _heap_pop() -> int:
	var top_id: int = _heap_id[0]
	_pop_cost = _heap_cost[0]
	var last: int = _heap_cost.size() - 1
	_heap_cost[0] = _heap_cost[last]
	_heap_id[0] = _heap_id[last]
	_heap_cost.resize(last)
	_heap_id.resize(last)
	var i: int = 0
	while true:
		var l: int = 2 * i + 1
		var r: int = l + 1
		var m: int = i
		if l < last and _heap_cost[l] < _heap_cost[m]:
			m = l
		if r < last and _heap_cost[r] < _heap_cost[m]:
			m = r
		if m == i:
			break
		_heap_swap(i, m)
		i = m
	return top_id


func _heap_swap(a: int, b: int) -> void:
	var tc: float = _heap_cost[a]
	_heap_cost[a] = _heap_cost[b]
	_heap_cost[b] = tc
	var ti: int = _heap_id[a]
	_heap_id[a] = _heap_id[b]
	_heap_id[b] = ti


# ---------------------------------------------------------------- Utilidades

func _member(v: float, r: Vector2, s: float) -> float:
	var lo: float = 1.0 if r.x <= -1.0 else smoothstep(r.x - s, r.x + s, v)
	var hi: float = 1.0 if r.y >= 1.0 else 1.0 - smoothstep(r.y - s, r.y + s, v)
	return lo * hi


func _make_noise(p_seed: int, freq: float) -> FastNoiseLite:
	var n := FastNoiseLite.new()
	n.seed = p_seed
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	n.frequency = freq
	return n


func _default_biomes() -> Array[BiomeData]:
	var list: Array[BiomeData] = []
	list.append(_biome("snow", Color(0.9, 0.93, 0.95), Vector2(-1, -0.3), Vector2(-1, 1), Vector2(0.9, 1), BiomeData.Ground.SNOW))
	list.append(_biome("rock", Color(0.5, 0.5, 0.52), Vector2(-0.3, 1), Vector2(-1, 1), Vector2(0.9, 1), BiomeData.Ground.ROCK))
	list.append(_biome("desert", Color(0.85, 0.75, 0.45), Vector2(0.3, 1), Vector2(-1, -0.15), Vector2(-1, 0.9), BiomeData.Ground.SAND))
	list.append(_biome("meadow", Color(0.45, 0.7, 0.3), Vector2(-1, 1), Vector2(-1, 0.1), Vector2(-1, 0.9), BiomeData.Ground.GRASS))
	list.append(_biome("forest", Color(0.2, 0.48, 0.22), Vector2(-1, 1), Vector2(-0.1, 1), Vector2(-1, 0.9), BiomeData.Ground.GRASS))
	return list


func _biome(p_id: String, p_color: Color, t: Vector2, m: Vector2, a: Vector2, g: BiomeData.Ground) -> BiomeData:
	var b := BiomeData.new()
	b.id = p_id
	b.color = p_color
	b.ground = g
	b.temperature = t
	b.moisture = m
	b.altitude = a
	return b
