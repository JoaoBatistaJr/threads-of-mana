class_name Avatar
extends Node3D

# Cápsula sem textura + "nariz" indicando a frente (-Z) + nome flutuando.

var _label: Label3D


func setup(id: int, display_name: String) -> void:
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

	_label = Label3D.new()
	_label.text = display_name
	_label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_label.pixel_size = 0.008
	_label.font_size = 48
	_label.outline_size = 12
	_label.position.y = 2.2
	add_child(_label)


func set_display_name(n: String) -> void:
	_label.text = n


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m
