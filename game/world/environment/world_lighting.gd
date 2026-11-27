class_name WorldLighting
extends Node

## Ciclo dia/noite + céu procedural (gradiente, sol, lua, estrelas, nuvens).
## Adicione um Node "WorldLighting" na cena do mundo com este script.

const DEFAULT_MOOD: String = "res://resources/world/world_mood.tres"

## Clima visual (cor, luz, céu). Vazio = carrega res://resources/world/world_mood.tres.
@export var mood: WorldMood
@export_range(0.0, 24.0, 0.01) var time_of_day: float = 10.0
## Duração do dia em minutos reais. 0 = tempo parado.
@export var day_length_minutes: float = 20.0
@export_range(0.0, 360.0) var sun_azimuth_deg: float = 35.0
@export_range(10.0, 89.0) var max_sun_elevation_deg: float = 65.0
@export var sun_energy: float = 1.3
@export var moon_energy: float = 0.12
@export var shadow_distance: float = 150.0:
	set(v):
		shadow_distance = v
		_apply_static()
@export var enable_ssao: bool = true:
	set(v):
		enable_ssao = v
		_apply_static()
@export var enable_glow: bool = true:
	set(v):
		enable_glow = v
		_apply_static()
@export var disable_fog: bool = true
## Densidade da névoa quando ligada (painel de debug). A cor segue o horizonte do céu.
@export_range(0.0, 0.01, 0.0001) var fog_density: float = 0.0009

@export_group("Céu")
@export_range(0.0, 1.0, 0.01) var cloud_cover: float = 0.45
@export var cloud_scale: float = 1.6
@export var cloud_speed: float = 0.012
@export_range(0.0, 2.0, 0.05) var star_brightness: float = 1.0
## Cor abaixo do horizonte (combine com a cor do oceano).
@export var ground_color: Color = Color(0.22, 0.45, 0.62)

const SKY_SHADER: String = """
shader_type sky;

uniform vec3 sun_dir = vec3(0.0, 1.0, 0.0);
uniform vec3 moon_dir = vec3(0.0, -1.0, 0.0);
uniform float day : hint_range(0.0, 1.0) = 1.0;
uniform float twilight : hint_range(0.0, 1.0) = 0.0;
uniform float sky_angle = 0.0;

uniform vec3 zenith_day : source_color = vec3(0.16, 0.38, 0.78);
uniform vec3 horizon_day : source_color = vec3(0.60, 0.77, 0.92);
uniform vec3 zenith_night : source_color = vec3(0.005, 0.01, 0.04);
uniform vec3 horizon_night : source_color = vec3(0.03, 0.05, 0.10);
uniform vec3 twilight_color : source_color = vec3(1.0, 0.5, 0.2);
uniform vec3 ground_color : source_color = vec3(0.22, 0.45, 0.62);

uniform float star_brightness = 1.0;
uniform float cloud_cover : hint_range(0.0, 1.0) = 0.45;
uniform float cloud_scale = 1.6;
uniform float cloud_speed = 0.012;
uniform float cloud_softness = 0.25;
uniform float cloud_brightness = 1.0;

float hash21(vec2 p) {
	p = fract(p * vec2(123.34, 456.21));
	p += dot(p, p + 45.32);
	return fract(p.x * p.y);
}

float hash31(vec3 p) {
	p = fract(p * 0.1031);
	p += dot(p, p.zyx + 31.32);
	return fract((p.x + p.y) * p.z);
}

float vnoise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	vec2 u = f * f * (3.0 - 2.0 * f);
	float a = hash21(i);
	float b = hash21(i + vec2(1.0, 0.0));
	float c = hash21(i + vec2(0.0, 1.0));
	float d = hash21(i + vec2(1.0, 1.0));
	return mix(mix(a, b, u.x), mix(c, d, u.x), u.y);
}

float fbm(vec2 p) {
	float a = 0.5;
	float s = 0.0;
	for (int i = 0; i < 5; i++) {
		s += a * vnoise(p);
		p = p * 2.03 + vec2(17.1, 9.2);
		a *= 0.5;
	}
	return s;
}

float stars(vec3 d) {
	vec3 axis = normalize(vec3(0.3, 0.8, 0.5));
	float c = cos(sky_angle);
	float s = sin(sky_angle);
	vec3 r = d * c + cross(axis, d) * s + axis * dot(axis, d) * (1.0 - c);
	vec3 p = r * 140.0;
	vec3 ip = floor(p);
	vec3 fp = fract(p) - 0.5;
	float h = hash31(ip);
	float on = step(0.992, h);
	float size = mix(0.12, 0.32, hash31(ip + 7.7));
	float tw = 0.7 + 0.3 * sin(TIME * (2.0 + 6.0 * hash31(ip + 3.3)) + h * 50.0);
	return on * smoothstep(size, 0.0, length(fp)) * tw;
}

void sky() {
	vec3 d = EYEDIR;
	float h = d.y;
	float sun_d = dot(d, sun_dir);
	float moon_d = dot(d, moon_dir);
	float glow_side = pow(max(sun_d, 0.0), 3.0);

	vec3 zenith = mix(zenith_night, zenith_day, day);
	vec3 horizon = mix(horizon_night, horizon_day, day);
	horizon = mix(horizon, twilight_color, twilight * (0.3 + 0.7 * glow_side));

	vec3 col = mix(horizon, zenith, pow(max(h, 0.0), 0.45));

	vec3 ground = ground_color * mix(0.10, 1.0, day);
	float below = smoothstep(0.0, -0.18, h);
	col = mix(col, mix(horizon, ground, 0.65), below);

	float above = 1.0 - below;

	// estrelas
	float star_alpha = (1.0 - day) * (1.0 - day) * smoothstep(-0.02, 0.2, h) * star_brightness;
	col += vec3(0.9, 0.95, 1.0) * stars(d) * star_alpha * 1.6;

	// sol
	float sun_vis = smoothstep(-0.03, 0.04, sun_dir.y) * above;
	float sun_disc = smoothstep(0.99945, 0.9996, sun_d);
	float sun_halo = pow(max(sun_d, 0.0), 220.0) * 1.2 + pow(max(sun_d, 0.0), 22.0) * 0.22;
	col += vec3(1.0, 0.93, 0.78) * (sun_disc * 7.0 + sun_halo) * sun_vis;

	// lua
	float moon_vis = smoothstep(-0.03, 0.05, moon_dir.y) * above * (1.0 - day);
	float moon_disc = smoothstep(0.99962, 0.99975, moon_d);
	float moon_halo = pow(max(moon_d, 0.0), 120.0) * 0.25;
	col += vec3(0.82, 0.88, 1.0) * (moon_disc * 3.2 + moon_halo) * moon_vis;

	// nuvens
	if (h > 0.0) {
		vec2 uv = d.xz / (h + 0.12);
		uv = uv * cloud_scale + vec2(TIME * cloud_speed, TIME * cloud_speed * 0.4);
		float n = fbm(uv);
		float thr = mix(0.78, 0.36, cloud_cover);
		float dens = smoothstep(thr, thr + cloud_softness, n);
		float fade = smoothstep(0.02, 0.22, h);
		float n2 = fbm(uv + sun_dir.xz * 0.15);
		float shade = clamp((n - n2) * 2.6 + 0.55, 0.0, 1.0);
		vec3 lit = mix(vec3(0.55, 0.58, 0.66), vec3(1.0), shade);
		vec3 cloud_col = lit * mix(vec3(0.06, 0.08, 0.14), vec3(1.0), day);
		cloud_col = mix(cloud_col, twilight_color * mix(0.7, 1.2, shade), twilight * 0.55 * (0.4 + 0.6 * glow_side));
		cloud_col *= cloud_brightness;
		col = mix(col, cloud_col, dens * fade * 0.95);
	}

	COLOR = col;
}
"""

var _light: DirectionalLight3D
var _world_env: WorldEnvironment
var _env: Environment
var _sky_mat: ShaderMaterial
## Fatores do ciclo atuais (0..1), lidos pelo [WorldFog].
var day_factor: float = 1.0
var twilight_factor: float = 0.0


func _ready() -> void:
	add_to_group("world_lighting")
	if mood == null and ResourceLoader.exists(DEFAULT_MOOD):
		mood = load(DEFAULT_MOOD) as WorldMood
	_find_or_create()
	_setup_sky()
	_apply_mood()
	_apply_static()
	RenderingServer.directional_shadow_atlas_set_size(4096, true)
	_update()


func _process(delta: float) -> void:
	if day_length_minutes > 0.0:
		time_of_day = fposmod(time_of_day + delta * 24.0 / (day_length_minutes * 60.0), 24.0)
	_update()


func set_time(hours: float) -> void:
	time_of_day = fposmod(hours, 24.0)
	_update()


# ---------------------------------------------------------------- Setup

func _find_or_create() -> void:
	var root := get_tree().root
	for l in root.find_children("*", "DirectionalLight3D", true, false):
		if l.get_viewport() == get_viewport():
			_light = l
			break
	if _light == null:
		_light = DirectionalLight3D.new()
		_light.name = "Sun"
		add_child(_light)

	for w in root.find_children("*", "WorldEnvironment", true, false):
		if w.get_viewport() == get_viewport():
			_world_env = w
			break
	if _world_env == null:
		_world_env = WorldEnvironment.new()
		_world_env.name = "WorldEnvironment"
		add_child(_world_env)
	if _world_env.environment == null:
		_world_env.environment = Environment.new()
	_env = _world_env.environment

	if disable_fog and _env.fog_mode != Environment.FOG_MODE_DEPTH:
		_env.fog_enabled = false
	_env.fog_sky_affect = 0.0
	_env.fog_light_energy = 1.0
	_light.shadow_enabled = true
	_light.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS
	_light.directional_shadow_blend_splits = true


func _setup_sky() -> void:
	var shader := Shader.new()
	shader.code = SKY_SHADER
	_sky_mat = ShaderMaterial.new()
	_sky_mat.shader = shader

	var sky := Sky.new()
	sky.sky_material = _sky_mat
	sky.process_mode = Sky.PROCESS_MODE_REALTIME
	sky.radiance_size = Sky.RADIANCE_SIZE_32

	_env.background_mode = Environment.BG_SKY
	_env.sky = sky
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	_env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	_env.tonemap_mode = Environment.TONE_MAPPER_FILMIC


## Aplica o [WorldMood]: correção de cor, exposição e cores fixas do céu.
func _apply_mood() -> void:
	if mood == null or _env == null:
		push_warning("WorldLighting: WorldMood não encontrado (res://resources/world/world_mood.tres).")
		return
	print("[WorldLighting] clima aplicado: ", mood.resource_path)
	_env.adjustment_enabled = true
	_env.adjustment_saturation = mood.saturation
	_env.adjustment_contrast = mood.contrast
	_env.adjustment_brightness = mood.brightness
	_env.tonemap_exposure = mood.exposure
	_sky_mat.set_shader_parameter("zenith_day", mood.sky_zenith_day)
	_sky_mat.set_shader_parameter("horizon_day", mood.sky_horizon_day)
	_sky_mat.set_shader_parameter("twilight_color", mood.sky_twilight)
	_sky_mat.set_shader_parameter("cloud_brightness", mood.cloud_brightness)


func _apply_static() -> void:
	if _light != null:
		_light.directional_shadow_max_distance = shadow_distance
	if _env != null:
		_env.ssao_enabled = enable_ssao
		_env.glow_enabled = enable_glow


# ---------------------------------------------------------------- Frame

func _sun_direction() -> Vector3:
	var h: float = sin((time_of_day - 6.0) / 24.0 * TAU)
	var el: float = h * deg_to_rad(max_sun_elevation_deg)
	var phi: float = deg_to_rad(sun_azimuth_deg) + (time_of_day - 12.0) / 6.0 * (PI * 0.5)
	return Vector3(cos(el) * sin(phi), sin(el), cos(el) * cos(phi)).normalized()


func _update() -> void:
	if _light == null or _sky_mat == null:
		return
	var sun_dir: Vector3 = _sun_direction()
	var s: float = sun_dir.y
	var day: float = smoothstep(-0.12, 0.25, s)
	var twilight: float = exp(-pow(s / 0.16, 2.0))
	day_factor = day
	twilight_factor = twilight
	var sun_mult: float = mood.sun_energy_mult if mood != null else 1.0
	var ambient_mult: float = mood.ambient_energy_mult if mood != null else 1.0
	var sun_low: Color = mood.sun_color_low if mood != null else Color(1.0, 0.62, 0.38)
	var sun_high: Color = mood.sun_color_high if mood != null else Color(1.0, 0.97, 0.9)
	var clouds: float = mood.cloud_cover if mood != null else cloud_cover

	var to_light: Vector3
	var energy: float
	var color: Color
	if s > -0.03:
		to_light = sun_dir
		energy = sun_energy * sun_mult * smoothstep(-0.03, 0.15, s)
		color = sun_low.lerp(sun_high, smoothstep(0.0, 0.45, s))
	else:
		to_light = -sun_dir
		energy = moon_energy * smoothstep(-0.03, -0.2, s)
		color = Color(0.62, 0.72, 1.0)

	_light.global_transform = Transform3D(Basis.looking_at(-to_light, Vector3.UP), _light.global_position)
	_light.light_energy = energy
	_light.light_color = color
	_light.visible = energy > 0.001

	_env.ambient_light_energy = lerpf(0.6, 1.0, day) * ambient_mult

	if _env.fog_enabled and _env.fog_mode != Environment.FOG_MODE_DEPTH:
		var horizon: Color = Color(0.03, 0.05, 0.10).lerp(Color(0.60, 0.77, 0.92), day)
		horizon = horizon.lerp(Color(1.0, 0.5, 0.2), twilight * 0.3)
		_env.fog_light_color = horizon
		_env.fog_density = fog_density
		_env.fog_sky_affect = 0.0

	_sky_mat.set_shader_parameter("sun_dir", sun_dir)
	_sky_mat.set_shader_parameter("moon_dir", -sun_dir)
	_sky_mat.set_shader_parameter("day", day)
	_sky_mat.set_shader_parameter("twilight", twilight)
	_sky_mat.set_shader_parameter("sky_angle", time_of_day / 24.0 * TAU)
	_sky_mat.set_shader_parameter("cloud_cover", clouds)
	_sky_mat.set_shader_parameter("cloud_scale", cloud_scale)
	_sky_mat.set_shader_parameter("cloud_speed", cloud_speed)
	_sky_mat.set_shader_parameter("star_brightness", star_brightness)
	_sky_mat.set_shader_parameter("ground_color", ground_color)
