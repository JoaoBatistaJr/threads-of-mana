## Grama procedural: tufos de lâminas (malha própria, sem textura) espalhados por chunk via MultiMesh.
## [method compute] roda em thread (só dados); [method tuft_mesh] e [method material] rodam na thread principal.
class_name GrassScatter
extends RefCounted

## Células por lado do mapa de clima do chunk (um [method TerrainGenerator.get_weights] por ponto).
const GRID: int = 8
## Lâminas por tufo (1 triângulo cada).
const BLADES: int = 8
## Floats por ponto do mapa de estilo: altura, densidade, borda, r, g, b.
const STYLE_STRIDE: int = 6
const BLADE_WIDTH: float = 0.11
## Floats por instância no buffer do MultiMesh: 12 (transform) + 4 (cor).
const STRIDE: int = 16
## Máximo de entidades que amassam a grama ao mesmo tempo (igual ao array do shader).
const MAX_ACTORS: int = 8

const SHADER_CODE: String = """
shader_type spatial;
render_mode cull_disabled, specular_disabled, diffuse_lambert;

uniform float wind_strength = 0.12;
uniform float wind_speed = 1.2;
uniform float wind_scale = 0.35;
uniform float fade_start = 70.0;
uniform float fade_end = 110.0;
uniform vec3 base_tint = vec3(0.4, 0.54, 0.34);
uniform vec3 tip_tint = vec3(0.95, 1.1, 0.68);
uniform float tip_boost = 1.0;
uniform vec4 actors[8];
uniform int actor_count = 0;
uniform float push_strength = 0.55;
uniform float flatten = 0.35;

void vertex() {
	vec3 w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float d = distance(w, CAMERA_POSITION_WORLD);
	float s = 1.0 - smoothstep(fade_start, fade_end, d);
	VERTEX *= s;
	w = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float t = TIME * wind_speed;
	float gust = sin(w.x * wind_scale + t) * 0.6
		+ sin(w.z * wind_scale * 0.8 + t * 1.3) * 0.4
		+ sin((w.x + w.z) * wind_scale * 2.1 + t * 2.3) * 0.2;
	float h = UV.y;
	vec3 off = vec3(gust, 0.0, gust * 0.6) * wind_strength * h * h;
	for (int i = 0; i < 8; i++) {
		if (i >= actor_count) {
			break;
		}
		vec3 d = w - actors[i].xyz;
		float dist = length(d.xz);
		float k = (1.0 - smoothstep(0.0, actors[i].w, dist)) * (1.0 - smoothstep(1.2, 3.0, abs(d.y)));
		vec2 dir = dist > 0.001 ? d.xz / dist : vec2(1.0, 0.0);
		off.xz += dir * k * push_strength * h;
		off.y -= k * flatten * h;
	}
	VERTEX += (inverse(MODEL_MATRIX) * vec4(off, 0.0)).xyz;
}

void fragment() {
	vec3 grad = mix(base_tint, tip_tint * tip_boost, UV.y);
	ALBEDO = COLOR.rgb * grad;
	ROUGHNESS = 1.0;
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	BACKLIGHT = ALBEDO * 0.3;
}
"""

static var _mesh: ArrayMesh
static var _material: ShaderMaterial


## Thread-safe. Retorna {"buffer": PackedFloat32Array, "count": int, "min_y"/"max_y": limites de altura} (vazio se não há grama no chunk).
## Mesma seed e mesmo chunk = mesma grama.
## [param lod]: 0 = perto (densidade total), 1 = longe (menos tufos, maiores).
static func compute(gen: TerrainGenerator, coord: Vector2i, heights: PackedFloat32Array, lod: int = 0) -> Dictionary:
	var cfg: WorldConfig = gen.config
	var size: float = float(cfg.chunk_size)
	var res: int = cfg.chunk_resolution
	var step: float = size / res
	var ox: float = coord.x * size
	var oz: float = coord.y * size

	var g: int = GRID
	var gs: float = size / g
	var n: int = g + 1
	var gw := PackedFloat32Array()
	gw.resize(n * n)
	var gc := PackedColorArray()
	gc.resize(n * n)
	var ids: PackedStringArray = _biome_ids(cfg)
	var styles: Array = []
	for id in ids:
		var found: GrassStyle = null
		for st in cfg.grass_styles:
			if st != null and st.biome == id:
				found = st
				break
		styles.append(found)
	var gst := PackedFloat32Array()
	gst.resize(n * n * STYLE_STRIDE)
	var best: float = 0.0
	for j in n:
		for i in n:
			var h: float = TerrainChunk.sample_height(heights, res, step, i * gs, j * gs)
			var w := gen.get_weights(ox + i * gs, oz + j * gs, h)
			var gr: float = gen.layers_from_weights(w).r
			gw[j * n + i] = gr
			gc[j * n + i] = gen.color_from_weights(w)
			best = maxf(best, gr)
			var sv: PackedFloat32Array = _style_at(w, styles)
			for q in STYLE_STRIDE:
				gst[(j * n + i) * STYLE_STRIDE + q] = sv[q]
	if best < 0.05:
		return {}

	var density: float = cfg.grass_density * (1.0 if lod == 0 else cfg.grass_far_density_mult)
	var cells: int = maxi(1, int(size * sqrt(density)))
	var noise := FastNoiseLite.new()
	noise.seed = gen.seed_value
	noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	noise.frequency = 0.045
	var far_scale: float = 1.0 if lod == 0 else 1.35
	var cell: float = size / cells
	var rng := RandomNumberGenerator.new()
	rng.seed = hash(Vector3i(coord.x, coord.y, 7919)) ^ gen.seed_value
	var min_ny: float = cos(deg_to_rad(cfg.grass_max_slope_deg))
	var sea_h: float = cfg.sea_level + 0.4

	var buf := PackedFloat32Array()
	var count: int = 0
	var min_y: float = INF
	var max_y: float = -INF
	for cz in cells:
		for cx in cells:
			var lx: float = (cx + rng.randf()) * cell
			var lz: float = (cz + rng.randf()) * cell
			var r_keep: float = rng.randf()
			var yaw: float = rng.randf() * TAU
			var r_h: float = rng.randf()
			var r_w: float = rng.randf()
			var r_v: float = rng.randf()

			var fx: float = lx / gs
			var fz: float = lz / gs
			var ix: int = mini(int(fx), g - 1)
			var iz: int = mini(int(fz), g - 1)
			var tx: float = fx - ix
			var tz: float = fz - iz
			var i00: int = iz * n + ix
			var wv: float = lerpf(lerpf(gw[i00], gw[i00 + 1], tx), lerpf(gw[i00 + n], gw[i00 + n + 1], tx), tz)
			var patch: float = noise.get_noise_2d(ox + lx, oz + lz) * 0.5 + 0.5
			var hm: float = _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 0)
			var dm: float = _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 1)
			var ed: float = _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 2)
			if r_keep >= smoothstep(0.0, 0.4, wv) * lerpf(0.8, 1.0, patch) * dm:
				continue

			var h: float = TerrainChunk.sample_height(heights, res, step, lx, lz)
			if cfg.has_sea() and h < sea_h:
				continue
			var dx: float = TerrainChunk.sample_height(heights, res, step, lx + 0.5, lz) - TerrainChunk.sample_height(heights, res, step, lx - 0.5, lz)
			var dz: float = TerrainChunk.sample_height(heights, res, step, lx, lz + 0.5) - TerrainChunk.sample_height(heights, res, step, lx, lz - 0.5)
			if 1.0 / sqrt(dx * dx + 1.0 + dz * dz) < min_ny:
				continue

			var top: Color = gc[i00].lerp(gc[i00 + 1], tx)
			var bot: Color = gc[i00 + n].lerp(gc[i00 + n + 1], tx)
			var col: Color = top.lerp(bot, tz) * cfg.grass_tint
			col = Color(col.r * _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 3), col.g * _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 4), col.b * _bilerp(gst, STYLE_STRIDE, n, ix, iz, tx, tz, 5))
			col = col.lerp(Color(col.r * cfg.grass_edge_tint.r, col.g * cfg.grass_edge_tint.g, col.b * cfg.grass_edge_tint.b), ed)
			var v: float = (0.82 + r_v * 0.36) * lerpf(0.9, 1.1, patch)
			col = Color(col.r * v * (1.0 + (r_h - 0.5) * 0.16), col.g * v, col.b * v, 1.0)

			var sh: float = cfg.grass_height * hm * lerpf(1.0, cfg.grass_edge_height, ed) * lerpf(0.7, 1.35, r_h) * lerpf(0.75, 1.3, patch) * (1.0 if lod == 0 else 1.15)
			var sw: float = lerpf(0.85, 1.25, r_w) * far_scale
			var b := Basis(Vector3.UP, yaw) * Basis.from_scale(Vector3(sw, sh, sw))
			var o := Vector3(lx, h - 0.03, lz)
			min_y = minf(min_y, h)
			max_y = maxf(max_y, h)
			buf.append_array(PackedFloat32Array([
				b.x.x, b.y.x, b.z.x, o.x,
				b.x.y, b.y.y, b.z.y, o.y,
				b.x.z, b.y.z, b.z.z, o.z,
				col.r, col.g, col.b, col.a]))
			count += 1
	if count == 0:
		return {}
	return {"buffer": buf, "count": count, "min_y": min_y, "max_y": max_y}


static func _biome_ids(cfg: WorldConfig) -> PackedStringArray:
	var out := PackedStringArray()
	if cfg.biomes.is_empty():
		return PackedStringArray(["snow", "rock", "desert", "meadow", "forest"])
	for b in cfg.biomes:
		out.append(b.id)
	return out


static func _bilerp(arr: PackedFloat32Array, stride: int, n: int, ix: int, iz: int, tx: float, tz: float, k: int) -> float:
	var i00: int = (iz * n + ix) * stride + k
	var top: float = lerpf(arr[i00], arr[i00 + stride], tx)
	var bot: float = lerpf(arr[i00 + n * stride], arr[i00 + (n + 1) * stride], tx)
	return lerpf(top, bot, tz)


## Mistura os estilos dos biomas pelos pesos [param w]; "borda" sobe onde nenhum bioma domina.
static func _style_at(w: PackedFloat32Array, styles: Array) -> PackedFloat32Array:
	var out := PackedFloat32Array()
	out.resize(STYLE_STRIDE)
	var total: float = 0.0
	for x in w:
		total += x
	var h: float = 0.0
	var d: float = 0.0
	var r: float = 0.0
	var gg: float = 0.0
	var b: float = 0.0
	var used: float = 0.0
	var top_w: float = 0.0
	if total > 0.0001:
		for k in w.size():
			var wk: float = w[k] / total
			top_w = maxf(top_w, wk)
			if k < styles.size() and styles[k] != null:
				var st: GrassStyle = styles[k]
				h += wk * st.height_mult
				d += wk * st.density_mult
				r += wk * st.tint.r
				gg += wk * st.tint.g
				b += wk * st.tint.b
				used += wk
	var rest: float = 1.0 - used
	out[0] = h + rest
	out[1] = d + rest
	out[2] = clampf((1.0 - top_w) * 2.0, 0.0, 1.0)
	out[3] = r + rest
	out[4] = gg + rest
	out[5] = b + rest
	return out


## Malha de um tufo (compartilhada): [constant BLADES] lâminas de 3 triângulos, altura 1.
## UV.y = 0 na base e 1 na ponta (usado pelo vento e pelo degradê).
static func tuft_mesh() -> ArrayMesh:
	if _mesh != null:
		return _mesh
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	var verts := PackedVector3Array()
	var norms := PackedVector3Array()
	var uvs := PackedVector2Array()
	var idx := PackedInt32Array()
	for b in BLADES:
		var a: float = b * TAU / BLADES + rng.randf_range(-0.4, 0.4)
		var r: float = rng.randf_range(0.04, 0.3)
		var base := Vector3(cos(a) * r, 0.0, sin(a) * r)
		var yaw: float = rng.randf() * TAU
		var dir := Vector3(cos(yaw), 0.0, sin(yaw))
		var side: Vector3 = dir * 0.5 * BLADE_WIDTH
		var lean: Vector3 = Vector3(-dir.z, 0.0, dir.x) * rng.randf_range(0.05, 0.3)
		var height: float = rng.randf_range(0.7, 1.0)
		var i0: int = verts.size()
		verts.append(base - side)
		verts.append(base + side)
		verts.append(base + lean + Vector3.UP * height)
		for uv_y in [0.0, 0.0, 1.0]:
			uvs.append(Vector2(0.0, uv_y))
			norms.append(Vector3.UP)
		idx.append_array(PackedInt32Array([i0, i0 + 1, i0 + 2]))
	var arrays := []
	arrays.resize(Mesh.ARRAY_MAX)
	arrays[Mesh.ARRAY_VERTEX] = verts
	arrays[Mesh.ARRAY_NORMAL] = norms
	arrays[Mesh.ARRAY_TEX_UV] = uvs
	arrays[Mesh.ARRAY_INDEX] = idx
	_mesh = ArrayMesh.new()
	_mesh.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arrays)
	return _mesh


static func _ensure_material() -> ShaderMaterial:
	if _material == null:
		var sh := Shader.new()
		sh.code = SHADER_CODE
		_material = ShaderMaterial.new()
		_material.shader = sh
	return _material


## Define quem amassa a grama: cada item é Vector4(x, y, z, raio). Máximo [constant MAX_ACTORS].
static func set_actors(actors: Array) -> void:
	var m: ShaderMaterial = _ensure_material()
	var packed := PackedVector4Array()
	packed.resize(MAX_ACTORS)
	var n: int = mini(actors.size(), MAX_ACTORS)
	for i in n:
		packed[i] = actors[i]
	m.set_shader_parameter("actors", packed)
	m.set_shader_parameter("actor_count", n)


## Material compartilhado da grama; atualiza vento e distância de fade a cada chamada.
static func material(cfg: WorldConfig) -> ShaderMaterial:
	_ensure_material()
	var fade_end: float = fade_distance(cfg)
	_material.set_shader_parameter("wind_strength", cfg.grass_wind)
	_material.set_shader_parameter("fade_end", fade_end)
	_material.set_shader_parameter("fade_start", fade_end * 0.65)
	return _material


## Distância (m) em que a grama some por completo.
static func fade_distance(cfg: WorldConfig) -> float:
	return cfg.chunk_size * (cfg.grass_radius + 0.5)
