## Névoa em profundidade que acompanha a distância de visão atual (muda em tempo real com as Opções).
## A cor segue o clima ([WorldMood]) e a hora do dia ([WorldLighting]).
class_name WorldFog
extends WorldEnvironment

const DEFAULT_MOOD: String = "res://resources/world/world_mood.tres"

@export var config: WorldConfig
@export var mood: WorldMood
@export var fog_color: Color = Color(0.72, 0.82, 0.9)
@export_range(0.1, 0.9, 0.05) var begin_ratio: float = 0.4
@export_range(0.5, 1.0, 0.05) var end_ratio: float = 0.95

var _applied_view: float = -1.0
var _wg: WorldGenerator
var _lighting: WorldLighting


func _ready() -> void:
	if config == null:
		config = WorldConfig.new()
	if mood == null and ResourceLoader.exists(DEFAULT_MOOD):
		mood = load(DEFAULT_MOOD) as WorldMood
	if environment == null:
		environment = Environment.new()
	environment.fog_enabled = true
	environment.fog_mode = Environment.FOG_MODE_DEPTH
	environment.fog_light_color = fog_color
	environment.fog_depth_curve = 1.0
	environment.fog_density = 1.0
	_refresh(true)
	_update_color()


func _process(_delta: float) -> void:
	_refresh(false)
	_update_color()


func _refresh(force: bool) -> void:
	if _wg == null or not is_instance_valid(_wg):
		_wg = get_tree().get_first_node_in_group("world_generator") as WorldGenerator
	var cfg: WorldConfig = config
	if _wg != null and _wg.config != null:
		cfg = _wg.config
	var view: float = cfg.view_distance * cfg.chunk_size
	if not force and is_equal_approx(view, _applied_view):
		return
	_applied_view = view
	var begin: float = mood.fog_begin_ratio if mood != null else begin_ratio
	var end: float = mood.fog_end_ratio if mood != null else end_ratio
	environment.fog_depth_begin = view * begin
	environment.fog_depth_end = view * end


## Cor da névoa: escura à noite, avermelhada de leve no crepúsculo.
func _update_color() -> void:
	if mood == null:
		return
	if _lighting == null or not is_instance_valid(_lighting):
		_lighting = get_tree().get_first_node_in_group("world_lighting") as WorldLighting
	var day: float = 1.0
	var twilight: float = 0.0
	if _lighting != null:
		day = _lighting.day_factor
		twilight = _lighting.twilight_factor
	var color: Color = mood.fog_night.lerp(mood.fog_day, day)
	environment.fog_light_color = color.lerp(mood.sky_twilight, twilight * 0.25)
