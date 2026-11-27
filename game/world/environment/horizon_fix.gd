class_name HorizonFix
extends Node

@export var ocean: MeshInstance3D
@export var ocean_size: float = 20000.0
@export var follow_camera: bool = true
@export var match_sky_ground: bool = true
@export_range(0.0, 1.0, 0.05) var ground_darken: float = 0.0


func _ready() -> void:
	process_priority = 100
	if ocean != null and ocean.mesh is PlaneMesh:
		(ocean.mesh as PlaneMesh).size = Vector2(ocean_size, ocean_size)


func _process(_delta: float) -> void:
	if follow_camera and ocean != null:
		var cam := get_viewport().get_camera_3d()
		if cam != null:
			var p: Vector3 = cam.global_position
			ocean.global_position = Vector3(p.x, ocean.global_position.y, p.z)
	if match_sky_ground:
		_sync_sky()


func _sync_sky() -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	for n in scene.find_children("*", "WorldEnvironment", true, false):
		var env := (n as WorldEnvironment).environment
		if env == null or env.sky == null:
			continue
		var mat := env.sky.sky_material as ProceduralSkyMaterial
		if mat == null:
			continue
		var c: Color = mat.sky_horizon_color.darkened(ground_darken)
		mat.ground_horizon_color = c
		mat.ground_bottom_color = c
