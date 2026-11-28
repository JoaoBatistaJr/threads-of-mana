class_name CameraRig
extends Node3D

# Câmera orbital em 3ª pessoa. Clique = captura o mouse, Esc = solta, roda = zoom.
# Posicione este nó na cabeça do jogador; `yaw` é enviado ao servidor.

const SENSITIVITY := 0.003

var yaw := 0.0
var pitch := -0.35
var distance := 6.0
var camera := Camera3D.new()
var ground := Callable()   # (x: float, z: float) -> altura do chão; a câmera nunca entra no terreno
var _dist := 6.0


func _ready() -> void:
	add_child(camera)
	camera.current = true
	camera.position.z = distance


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * SENSITIVITY * float(Settings.get_value("sens"))
		pitch = clampf(pitch - event.relative.y * SENSITIVITY * float(Settings.get_value("sens")), -1.3, 0.6)
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


func _process(delta: float) -> void:
	rotation = Vector3(pitch, yaw, 0.0)
	var want := distance
	if ground.is_valid():
		# recua a câmera até ficar acima do chão (olhando para cima ela passaria por baixo)
		var back := global_transform.basis.z
		var steps := 12
		for i in steps + 1:
			var d := distance * (1.0 - float(i) / steps)
			var p := global_position + back * d
			if p.y >= float(ground.call(p.x, p.z)) + 0.4:
				want = d
				break
			want = 0.3
	_dist = want if want < _dist else lerpf(_dist, want, 1.0 - exp(-8.0 * delta))
	camera.position.z = _dist
