extends StaticBody3D
class_name CraftingStation

## Tipo de bancada (campfire, forge, workbench...). O servidor usa para validar receitas.
@export var station_type: String = "workbench"


func get_station_type() -> String:
	return station_type


func _ready() -> void:
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	collision_layer = 0
	collision_mask = 0
