class_name PlayerState
extends RefCounted

# Estado + regra de movimento compartilhados por servidor (autoridade) e cliente (predição).
# pos.y = pés. Chão plano em y = 0.

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0   # direção em que o corpo está virado


func step(dir: Vector2, cam_yaw: float, sprint: bool, jump: bool) -> void:
	var dt := Const.DT
	var wish := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, cam_yaw)
	var speed := Const.RUN_SPEED if sprint else Const.WALK_SPEED
	var on_floor := pos.y <= 0.001
	var accel := Const.GROUND_ACCEL if on_floor else Const.AIR_ACCEL

	var h := Vector3(vel.x, 0.0, vel.z).move_toward(wish * speed, accel * dt)
	vel.x = h.x
	vel.z = h.z

	if on_floor:
		vel.y = Const.JUMP_VELOCITY if jump else 0.0
	vel.y -= Const.GRAVITY * dt

	pos += vel * dt
	if pos.y < 0.0:
		pos.y = 0.0
		vel.y = 0.0
	pos.x = clampf(pos.x, -Const.WORLD_HALF_SIZE, Const.WORLD_HALF_SIZE)
	pos.z = clampf(pos.z, -Const.WORLD_HALF_SIZE, Const.WORLD_HALF_SIZE)

	if wish.length_squared() > 0.0001:
		yaw = lerp_angle(yaw, atan2(-wish.x, -wish.z), 1.0 - exp(-Const.TURN_RATE * dt))


func copy() -> PlayerState:
	var s := PlayerState.new()
	s.pos = pos
	s.vel = vel
	s.yaw = yaw
	return s
