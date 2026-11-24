class_name SceneBuilder
extends RefCounted

# Mundo visual mínimo (só cliente): céu, luz, névoa e o visual dos recursos. O chão é o TerrainView.

static var _trunk: CylinderMesh
static var _crown: SphereMesh
static var _rock: SphereMesh


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


# Visual de um recurso (árvore ou pedra), com a base em y = 0 local.
static func node_visual(kind: int) -> Node3D:
	if _trunk == null:
		_trunk = CylinderMesh.new()
		_trunk.top_radius = 0.25
		_trunk.bottom_radius = 0.3
		_trunk.height = 2.0
		_trunk.material = _mat(Color(0.4, 0.28, 0.18))
		_crown = SphereMesh.new()
		_crown.radius = 1.3
		_crown.height = 2.6
		_crown.material = _mat(Color(0.15, 0.42, 0.18))
		_rock = SphereMesh.new()
		_rock.radius = 0.9
		_rock.height = 1.8
		_rock.material = _mat(Color(0.5, 0.5, 0.52))
	var root := Node3D.new()
	if kind == ResourceNodes.Type.TREE:
		var t := MeshInstance3D.new()
		t.mesh = _trunk
		t.position.y = 1.0
		root.add_child(t)
		var c := MeshInstance3D.new()
		c.mesh = _crown
		c.position.y = 3.0
		root.add_child(c)
	else:
		var r := MeshInstance3D.new()
		r.mesh = _rock
		r.scale = Vector3(1.0, 0.6, 0.9)
		r.position.y = 0.45
		root.add_child(r)
	return root


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
