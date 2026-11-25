## Entrada de drop de um mob: item, chance e quantidade. Usada em [member MobData.drops].
extends Resource
class_name MobDrop

## Id do item (ex.: "pele"). Deve existir em res://resources/items.
@export var item_id: String = ""
@export_range(0.0, 1.0, 0.01) var chance: float = 1.0
@export var min_amount: int = 1
@export var max_amount: int = 1


## Sorteia o drop. [param luck_mult] multiplica a chance (stat drop_luck). Retorna a quantidade (0 = nada).
func roll(luck_mult: float = 1.0) -> int:
	if item_id == "":
		return 0
	if randf() >= clampf(chance * luck_mult, 0.0, 1.0):
		return 0
	return randi_range(min_amount, maxi(min_amount, max_amount))
