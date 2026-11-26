## Modelo da tocha na mão: cabo, pano e a chama (Vfx "torch").
## A cena torch_held.tscn só carrega este script.
extends Node3D

const HANDLE_LENGTH: float = 0.45
const HEAD_LENGTH: float = 0.12

var _flame: Node3D


func _ready() -> void:
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.32, 0.2, 0.1)
	wood.roughness = 1.0
	var cloth := StandardMaterial3D.new()
	cloth.albedo_color = Color(0.15, 0.1, 0.07)
	cloth.roughness = 1.0

	var handle := MeshInstance3D.new()
	var handle_mesh := CylinderMesh.new()
	handle_mesh.top_radius = 0.022
	handle_mesh.bottom_radius = 0.028
	handle_mesh.height = HANDLE_LENGTH
	handle.mesh = handle_mesh
	handle.material_override = wood
	handle.position = Vector3(0.0, HANDLE_LENGTH * 0.5, 0.0)
	add_child(handle)

	var head := MeshInstance3D.new()
	var head_mesh := CylinderMesh.new()
	head_mesh.top_radius = 0.045
	head_mesh.bottom_radius = 0.028
	head_mesh.height = HEAD_LENGTH
	head.mesh = head_mesh
	head.material_override = cloth
	head.position = Vector3(0.0, HANDLE_LENGTH + HEAD_LENGTH * 0.5, 0.0)
	add_child(head)

	var vfx := get_node_or_null("/root/Vfx")   # efeito só existe no cliente (autoload ainda não trazido)
	if vfx != null:
		_flame = vfx.call("attach", "torch", self, {"offset": Vector3(0.0, HANDLE_LENGTH + HEAD_LENGTH, 0.0)})
