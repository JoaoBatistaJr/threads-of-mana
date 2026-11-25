## Criaturas de um ou mais biomas. Os ids são os de [BiomeData.id] (snow, rock, desert, meadow, forest).
class_name SpawnTable
extends Resource

@export var biome_ids: PackedStringArray = PackedStringArray()
@export var entries: Array[SpawnEntry] = []


## Sorteia uma entrada válida para o tier (ponderada). Null se nenhuma servir.
func pick(rng: RandomNumberGenerator, tier: int) -> SpawnEntry:
	var total: float = 0.0
	for e in entries:
		if e != null and e.valid_for_tier(tier):
			total += e.weight
	if total <= 0.0:
		return null
	var roll: float = rng.randf() * total
	for e in entries:
		if e == null or not e.valid_for_tier(tier):
			continue
		roll -= e.weight
		if roll <= 0.0:
			return e
	return null
