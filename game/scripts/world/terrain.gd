class_name Terrain
extends RefCounted

# Altura do chão e bioma: tudo vem do TerrainGenerator (mesma seed no servidor e no cliente).
# Nada do terreno trafega pela rede.

var gen: TerrainGenerator
var half_size := 20000.0   # limite de movimento (borda do continente)


func _init(p_gen: TerrainGenerator) -> void:
	gen = p_gen
	var cfg := gen.config
	half_size = (cfg.world_radius - 50.0) if cfg.has_sea() else 1.0e6


func height(x: float, z: float) -> float:
	return gen.get_height(x, z)


func biome_at(x: float, z: float) -> String:
	return gen.get_biome(x, z)
