class_name ResourceNodes
extends RefCounted

# Recursos do mundo (árvores e pedras). Só o SERVIDOR gera a lista (semente + terreno) e a envia
# ao cliente no registro; o estado (disponível/esgotado) também é do servidor.

enum Type { TREE, ROCK }
enum Tool { AXE, PICKAXE }

const TREES := 350
const ROCKS := 120
const CITY_CLEAR := 60.0        # sem recursos perto do centro (cidade inicial)
const AREA_FRACTION := 0.72     # evita a cordilheira da borda
const MIN_GAP := 4.0
const MAX_SLOPE := 0.7
const FOREST_MIN := 0.1         # ruído mínimo para nascer árvore (cria bosques)
const ROCK_MIN := 0.3           # idem para pedras (cria afloramentos)

const ITEM_NAMES := ["Madeira", "Pedra"]
const TOOL_NAMES := ["Machado", "Picareta"]


# Cada recurso: {id, type, pos}. A ferramenta necessária tem o mesmo índice do tipo.
static func generate(t: Terrain) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed_value
	var area := t.half_size * AREA_FRACTION
	var out: Array = []
	for kind in [Type.TREE, Type.ROCK]:
		var target := TREES if kind == Type.TREE else ROCKS
		var count := 0
		var attempts := 0
		while count < target and attempts < target * 80:
			attempts += 1
			var x := rng.randf_range(-area, area)
			var z := rng.randf_range(-area, area)
			if sqrt(x * x + z * z) < CITY_CLEAR:
				continue
			if kind == Type.TREE and t.forest.get_noise_2d(x, z) < FOREST_MIN:
				continue
			if kind == Type.ROCK and t.rocks.get_noise_2d(x, z) < ROCK_MIN:
				continue
			if t.slope(x, z) > MAX_SLOPE:
				continue
			var ok := true
			for n in out:
				if Vector2(n["pos"].x - x, n["pos"].z - z).length() < MIN_GAP:
					ok = false
					break
			if ok:
				out.append({"id": out.size(), "type": kind, "pos": Vector3(x, t.height(x, z), z)})
				count += 1
	return out
