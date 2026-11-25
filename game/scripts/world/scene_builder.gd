class_name SceneBuilder
extends RefCounted

# Mundo visual mínimo (só cliente): céu, luz, névoa e o visual dos recursos. O chão é o TerrainView.

static var _m: Dictionary = {}


static func build(parent: Node) -> void:
	var env := WorldEnvironment.new()
	env.environment = Environment.new()
	env.environment.background_mode = Environment.BG_COLOR
	env.environment.background_color = Color(0.55, 0.7, 0.9)
	env.environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.environment.ambient_light_color = Color(0.55, 0.55, 0.55)
	env.environment.fog_enabled = true
	env.environment.fog_light_color = Color(0.62, 0.74, 0.9)
	env.environment.fog_density = 0.0025
	parent.add_child(env)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-55.0, 30.0, 0.0)
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 120.0
	parent.add_child(sun)


# Visual de um recurso (tipo + bioma), com a base em y = 0 local.
static func node_visual(kind: int, biome: int) -> Node3D:
	if _m.is_empty():
		_init_meshes()
	var root := Node3D.new()
	match kind:
		ResourceNodes.Type.TREE:
			_add(root, _m["trunk"], Vector3(0, 1.0, 0))
			if biome == Terrain.Biome.HIGHLAND:
				_add(root, _m["pine"], Vector3(0, 2.8, 0))
			elif biome == Terrain.Biome.FOREST:
				_add(root, _m["crown_forest"], Vector3(0, 3.0, 0))
			else:
				_add(root, _m["crown_meadow"], Vector3(0, 2.8, 0))
		ResourceNodes.Type.ROCK:
			_add(root, _m["rock"], Vector3(0, 0.45, 0), Vector3(1.0, 0.6, 0.9))
		ResourceNodes.Type.HERB:
			_add(root, _m["herb"], Vector3(0, 0.15, 0), Vector3(1.0, 0.5, 1.0))
			_add(root, _m["flower"], Vector3(0.1, 0.38, 0.05))
		ResourceNodes.Type.ORE:
			_add(root, _m["ore"], Vector3(0, 0.6, 0), Vector3(1.0, 0.75, 0.9))
			_add(root, _m["vein"], Vector3(0.45, 0.75, 0.2))
			_add(root, _m["vein"], Vector3(-0.3, 0.55, -0.4))
	return root


static func _add(parent: Node3D, mesh: Mesh, pos: Vector3, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.position = pos
	mi.scale = scl
	parent.add_child(mi)


static func _init_meshes() -> void:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.3
	trunk.height = 2.0
	trunk.material = _mat(Color(0.4, 0.28, 0.18))
	_m["trunk"] = trunk
	_m["crown_meadow"] = _sphere(1.2, Color(0.34, 0.58, 0.22))
	_m["crown_forest"] = _sphere(1.4, Color(0.10, 0.36, 0.15))
	var pine := CylinderMesh.new()
	pine.top_radius = 0.0
	pine.bottom_radius = 1.1
	pine.height = 3.4
	pine.material = _mat(Color(0.14, 0.34, 0.28))
	_m["pine"] = pine
	_m["rock"] = _sphere(0.9, Color(0.5, 0.5, 0.52))
	_m["herb"] = _sphere(0.45, Color(0.35, 0.72, 0.30))
	_m["flower"] = _sphere(0.12, Color(0.75, 0.3, 0.85))
	_m["ore"] = _sphere(0.9, Color(0.30, 0.30, 0.35))
	_m["vein"] = _sphere(0.16, Color(0.95, 0.55, 0.2))


static func _sphere(r: float, c: Color) -> SphereMesh:
	var m := SphereMesh.new()
	m.radius = r
	m.height = r * 2.0
	m.material = _mat(c)
	return m


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
