class_name SceneBuilder
extends RefCounted

# Mundo visual mínimo (só cliente): céu, luz, chão plano e pilares de referência.

static func build(parent: Node) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.shadow_enabled = true
	parent.add_child(sun)

	var plane := PlaneMesh.new()
	plane.size = Vector2.ONE * Const.WORLD_HALF_SIZE * 2.0
	plane.material = _mat(Color(0.3, 0.5, 0.3))
	var ground := MeshInstance3D.new()
	ground.mesh = plane
	parent.add_child(ground)

	var box := BoxMesh.new()
	box.size = Vector3(1.0, 3.0, 1.0)
	box.material = _mat(Color(0.45, 0.35, 0.3))
	for x in range(-80, 81, 20):
		for z in range(-80, 81, 20):
			var pillar := MeshInstance3D.new()
			pillar.mesh = box
			pillar.position = Vector3(x, 1.5, z)
			parent.add_child(pillar)


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
