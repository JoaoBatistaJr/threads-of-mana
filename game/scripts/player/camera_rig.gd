class_name CameraRig
extends Node3D

# Câmera orbital em 3ª pessoa. Clique = captura o mouse, Esc = solta, roda = zoom.
# Posicione este nó na cabeça do jogador; `yaw` é enviado ao servidor.

const SENSITIVITY := 0.003

var yaw := 0.0
var pitch := -0.35
var distance := 6.0
var camera := Camera3D.new()


func _ready() -> void:
	add_child(camera)
	camera.current = true
	camera.position.z = distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY
		pitch = clampf(pitch - event.relative.y * SENSITIVITY, -1.3, 0.6)
	elif event is InputEventMouseButton and event.pressed:
		match event.button_index:
			MOUSE_BUTTON_LEFT:
				Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			MOUSE_BUTTON_WHEEL_UP:
				distance = clampf(distance - 0.5, 2.0, 15.0)
			MOUSE_BUTTON_WHEEL_DOWN:
				distance = clampf(distance + 0.5, 2.0, 15.0)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _process(_delta: float) -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	camera.position.z = distance
