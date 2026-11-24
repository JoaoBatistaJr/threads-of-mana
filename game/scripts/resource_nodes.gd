class_name ResourceNodes
extends RefCounted

# Recursos do mundo (árvores e pedras). Gerados de forma determinística a partir de uma semente:
# servidor e cliente chegam nas mesmas posições sem trocar a lista pela rede.
# O ESTADO (disponível/esgotado) é do servidor; o cliente só recebe as mudanças.

enum Type { TREE, ROCK }
enum Tool { AXE, PICKAXE }

const SEED := 20261124
const TREES := 60
const ROCKS := 40
const AREA := 70.0
const MIN_SPAWN_DIST := 8.0
const MIN_GAP := 4.0

const ITEM_NAMES := ["Madeira", "Pedra"]
const TOOL_NAMES := ["Machado", "Picareta"]


# Cada recurso: {id, type, pos}. A ferramenta necessária tem o mesmo índice do tipo.
static func generate() -> Array:
	var rng := RandomNumberGenerator.new()
	rng.seed = SEED
	var kinds: Array = []
	for i in TREES:
		kinds.append(Type.TREE)
	for i in ROCKS:
		kinds.append(Type.ROCK)
	var out: Array = []
	var tries := 0
	for kind in kinds:
		while tries < 20000:
			tries += 1
			var p := Vector3(rng.randf_range(-AREA, AREA), 0.0, rng.randf_range(-AREA, AREA))
			if p.length() < MIN_SPAWN_DIST:
				continue
			var ok := true
			for n in out:
				if n["pos"].distance_to(p) < MIN_GAP:
					ok = false
					break
			if ok:
				out.append({"id": out.size(), "type": kind, "pos": p})
				break
	return out
