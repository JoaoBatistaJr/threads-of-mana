class_name WorldChanges
extends RefCounted

# Estado dos recursos do mundo visto pelo CLIENTE: quais posições do scatter estão esgotadas.
# Chave = Vector3i(chunk.x, chunk.y, índice da colocação). O servidor é quem decide; aqui só espelha.

static var removed: Dictionary = {}


static func key(coord: Vector2i, pi: int) -> Vector3i:
	return Vector3i(coord.x, coord.y, pi)


static func is_removed(coord: Vector2i, pi: int) -> bool:
	return removed.has(Vector3i(coord.x, coord.y, pi))


static func health_of(_coord: Vector2i, _pi: int) -> int:
	return -1


static func clear() -> void:
	removed.clear()
