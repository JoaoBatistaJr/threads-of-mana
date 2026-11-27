## NPC de profissão. Dados (receitas, loja, missões) vêm do [NpcData] arrastado no Inspector.
## Visual: cápsula placeholder + nome/cargo (troque pelo modelo quando houver). A interação é do servidor.
class_name Npc
extends Node3D

@export var data: NpcData

const HEIGHT: float = 1.8
const RADIUS: float = 0.4
const LABEL_NEAR: float = 12.0
const LABEL_MAX_SCALE: float = 2.0
const LABEL_RANGE: float = 70.0

var _scaled_labels: Array = []


func _ready() -> void:
	add_to_group("npcs")
	if DisplayServer.get_name() == "headless":
		return   # servidor: só a posição e os dados importam
	_build()


func _process(_delta: float) -> void:
	if _scaled_labels.is_empty():
		return
	var cam := get_viewport().get_camera_3d()
	if cam == null:
		return
	var k: float = clampf(cam.global_position.distance_to(global_position) / LABEL_NEAR, 1.0, LABEL_MAX_SCALE)
	for entry in _scaled_labels:
		var label: Label3D = entry[0]
		label.scale = Vector3.ONE * k
		label.position.y = HEIGHT + float(entry[1]) * k


func _build() -> void:
	var model := Node3D.new()
	model.name = "Model"
	add_child(model)
	var mesh := MeshInstance3D.new()
	var cm := CapsuleMesh.new()
	cm.radius = RADIUS
	cm.height = HEIGHT
	var mat := StandardMaterial3D.new()
	mat.albedo_color = data.color if data != null else Color.WHITE
	cm.material = mat
	mesh.mesh = cm
	mesh.position.y = HEIGHT * 0.5
	model.add_child(mesh)
	if data == null:
		return
	var name_label := _make_label(data.person_name(), 72, 20, Color(0.95, 1.0, 0.9))
	name_label.position.y = HEIGHT + 0.85
	add_child(name_label)
	_scaled_labels.append([name_label, 0.85])
	if data.role_title() != data.person_name():
		var role_label := _make_label(data.role_title(), 48, 14, Color(0.72, 0.88, 1.0))
		role_label.position.y = HEIGHT + 0.45
		add_child(role_label)
		_scaled_labels.append([role_label, 0.45])


func _make_label(text: String, font_size: int, outline: int, color: Color) -> Label3D:
	var label := Label3D.new()
	label.text = text
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 50
	label.outline_render_priority = 49
	label.pixel_size = 0.005
	label.font_size = font_size
	label.outline_size = outline
	label.modulate = color
	label.visibility_range_end = LABEL_RANGE
	return label
