class_name Avatar
extends Node3D

# Cápsula sem textura + "nariz" indicando a frente (-Z) + id flutuando.

func setup(id: int) -> void:
	var color := Color.from_hsv(fmod(id * 0.61803, 1.0), 0.65, 0.95)

	var capsule := CapsuleMesh.new()
	capsule.radius = 0.4
	capsule.height = 1.8
	capsule.material = _mat(color)
	var body := MeshInstance3D.new()
	body.mesh = capsule
	body.position.y = 0.9
	add_child(body)

	var sphere := SphereMesh.new()
	sphere.radius = 0.12
	sphere.height = 0.24
	sphere.material = _mat(Color.WHITE)
	var nose := MeshInstance3D.new()
	nose.mesh = sphere
	nose.position = Vector3(0.0, 1.45, -0.38)
	add_child(nose)

	var label := Label3D.new()
	label.text = str(id)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.pixel_size = 0.008
	label.font_size = 48
	label.position.y = 2.2
	add_child(label)


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
