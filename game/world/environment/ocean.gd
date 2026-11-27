class_name Ocean
extends MeshInstance3D

const SIZE: float = 16000.0
const SNAP: float = 64.0

static var _shared: StandardMaterial3D

var _config: WorldConfig


static func shared_material(config: WorldConfig) -> StandardMaterial3D:
	if _shared == null:
		_shared = StandardMaterial3D.new()
		_shared.albedo_color = config.ocean_color
		_shared.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		_shared.roughness = 0.12
		_shared.metallic_specular = 0.8
		_shared.cull_mode = BaseMaterial3D.CULL_DISABLED
	return _shared


func setup(config: WorldConfig) -> void:
	_config = config
	var plane := PlaneMesh.new()
	plane.size = Vector2(SIZE, SIZE)
	mesh = plane
	material_override = shared_material(config)
	cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	position = Vector3(0.0, config.sea_level, 0.0)


func _process(_delta: float) -> void:
	if _config == null:
		return
	var player := get_tree().get_first_node_in_group("players") as Node3D
	if player == null:
		return
	position = Vector3(
		snappedf(player.global_position.x, SNAP),
		_config.sea_level,
		snappedf(player.global_position.z, SNAP))
