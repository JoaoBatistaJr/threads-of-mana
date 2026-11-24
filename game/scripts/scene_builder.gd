class_name SceneBuilder
extends RefCounted

# Mundo visual mínimo (só cliente): céu, luz e chão plano.

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


# Cria o visual de cada recurso; retorna id -> Node3D (para esconder quando esgotado).
static func build_nodes(parent: Node, nodes: Array) -> Dictionary:
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.25
	trunk.bottom_radius = 0.3
	trunk.height = 2.0
	trunk.material = _mat(Color(0.4, 0.28, 0.18))
	var crown := SphereMesh.new()
	crown.radius = 1.3
	crown.height = 2.6
	crown.material = _mat(Color(0.15, 0.42, 0.18))
	var rock := SphereMesh.new()
	rock.radius = 0.9
	rock.height = 1.8
	rock.material = _mat(Color(0.5, 0.5, 0.52))

	var vis := {}
	for n in nodes:
		var root := Node3D.new()
		root.position = n["pos"]
		if n["type"] == ResourceNodes.Type.TREE:
			var t := MeshInstance3D.new()
			t.mesh = trunk
			t.position.y = 1.0
			root.add_child(t)
			var c := MeshInstance3D.new()
			c.mesh = crown
			c.position.y = 3.0
			root.add_child(c)
		else:
			var r := MeshInstance3D.new()
			r.mesh = rock
			r.scale = Vector3(1.0, 0.6, 0.9)
			r.position.y = 0.45
			root.add_child(r)
		parent.add_child(root)
		vis[n["id"]] = root
	return vis


static func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
