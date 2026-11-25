## Uma criatura possível numa [SpawnTable], com peso, faixa de tier e tamanho do grupo.
class_name SpawnEntry
extends Resource

@export var mob: MobData
## Chance relativa de ser sorteada entre as entradas válidas do tier.
@export_range(0.0, 100.0, 0.1) var weight: float = 1.0
@export_range(0, 3) var tier_min: int = 0
@export_range(0, 3) var tier_max: int = 3
@export_range(1, 12) var group_min: int = 1
@export_range(1, 12) var group_max: int = 1
## Somado ao nível do tier (ex.: -1 para criaturas fracas, +2 para alfas).
@export var level_bonus: int = 0


func valid_for_tier(tier: int) -> bool:
	return mob != null and weight > 0.0 and tier >= tier_min and tier <= tier_max
