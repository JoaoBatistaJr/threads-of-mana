class_name PlayerState
extends RefCounted

# Estado + regra de movimento compartilhados por servidor (autoridade) e cliente (predição).
# pos.y = pés. O chão é a função de altura do Terrain.

var pos := Vector3.ZERO
var vel := Vector3.ZERO
var yaw := 0.0   # direção em que o corpo está virado
var terrain: Terrain


func step(dir: Vector2, cam_yaw: float, sprint: bool, jump: bool) -> void:
	var dt := Const.DT
	var wish := Vector3(dir.x, 0.0, dir.y).rotated(Vector3.UP, cam_yaw)
	var speed := Const.RUN_SPEED if sprint else Const.WALK_SPEED
	var g0 := terrain.height(pos.x, pos.z)
	var on_floor := pos.y <= g0 + 0.05 and vel.y <= 0.001
	var accel := Const.GROUND_ACCEL if on_floor else Const.AIR_ACCEL

	var h := Vector3(vel.x, 0.0, vel.z).move_toward(wish * speed, accel * dt)
	vel.x = h.x
	vel.z = h.z

	# deslocamento horizontal, limitado pela borda e (no chão) pela inclinação
	var lim := terrain.half_size - 1.0
	var np := Vector2(clampf(pos.x + vel.x * dt, -lim, lim), clampf(pos.z + vel.z * dt, -lim, lim))
	var cur := Vector2(pos.x, pos.z)
	if on_floor:
		var chosen := cur
		for cand: Vector2 in [np, Vector2(np.x, cur.y), Vector2(cur.x, np.y)]:
			var dist: float = cand.distance_to(cur)
			if dist < 0.0001 or terrain.height(cand.x, cand.y) - pos.y <= dist * Const.MAX_SLOPE + 0.02:
				chosen = cand
				break
		if chosen == cur:
			vel.x = 0.0
			vel.z = 0.0
		np = chosen
	pos.x = np.x
	pos.z = np.y

	var g := terrain.height(pos.x, pos.z)
	if on_floor and jump:
		vel.y = Const.JUMP_VELOCITY - Const.GRAVITY * dt
		pos.y += vel.y * dt
	elif on_floor and pos.y - g <= Const.SNAP_DOWN:
		pos.y = g          # acompanha o relevo (subida e descida)
		vel.y = 0.0
	else:
		vel.y -= Const.GRAVITY * dt
		pos.y += vel.y * dt
		if pos.y <= g:
			pos.y = g
			vel.y = 0.0

	if wish.length_squared() > 0.0001:
		yaw = lerp_angle(yaw, atan2(-wish.x, -wish.z), 1.0 - exp(-Const.TURN_RATE * dt))


func copy() -> PlayerState:
	var s := PlayerState.new()
	s.pos = pos
	s.vel = vel
	s.yaw = yaw
	s.terrain = terrain
	return s
