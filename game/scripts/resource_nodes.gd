class_name ResourceNodes
extends RefCounted

# Recursos do mundo. Só o SERVIDOR gera a lista (semente + terreno + bioma) e a envia ao cliente
# no registro; o estado (disponível/esgotado) também é do servidor.

enum Type { TREE, ROCK, HERB, ORE }
enum Tool { AXE, PICKAXE, SICKLE }

const ITEM_NAMES := ["Madeira", "Pedra", "Erva", "Minério"]
const TOOL_NAMES := ["Machado", "Picareta", "Foice"]
const TOOL_FOR := [Tool.AXE, Tool.PICKAXE, Tool.SICKLE, Tool.PICKAXE]   # por tipo de recurso

const TARGETS := [350, 100, 160, 25]
# chance de nascer por bioma: [campina, floresta, serra]
const WEIGHTS := [[0.12, 1.0, 0.30], [0.15, 0.10, 1.0], [1.0, 0.50, 0.10], [0.0, 0.0, 1.0]]
const MIN_GAP := [4.0, 4.0, 2.5, 14.0]
const MAX_SLOPE := [0.7, 0.7, 0.7, 1.0]
const CITY_CLEAR := 60.0        # sem recursos perto do centro (cidade inicial)
const AREA_FRACTION := 0.72     # evita a cordilheira da borda


# Cada recurso: {id, type, biome, pos}.
static func generate(t: Terrain) -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = t.seed_value
	var area := t.half_size * AREA_FRACTION
	var out: Array = []
	for kind in 4:
		var count := 0
		var attempts := 0
		var gap: float = MIN_GAP[kind]
		while count < TARGETS[kind] and attempts < TARGETS[kind] * 150:
			attempts += 1
			var x := rng.randf_range(-area, area)
			var z := rng.randf_range(-area, area)
			if sqrt(x * x + z * z) < CITY_CLEAR:
				continue
			var biome := t.biome_at(x, z)
			var dens := clampf((t.density.get_noise_2d(x, z) + 0.3) / 0.9, 0.0, 1.0)
			if rng.randf() > WEIGHTS[kind][biome] * (0.25 + 0.75 * dens):
				continue
			if t.slope(x, z) > MAX_SLOPE[kind]:
				continue
			var ok := true
			for n in out:
				if Vector2(n["pos"].x - x, n["pos"].z - z).length() < gap:
					ok = false
					break
			if ok:
				out.append({"id": out.size(), "type": kind, "biome": biome, "pos": Vector3(x, t.height(x, z), z)})
				count += 1
	return out
