class_name Terrain
extends RefCounted

# Altura do chão: função determinística (semente + ruído) usada pelo servidor (colisão/autoridade),
# pelo cliente (predição) e pelo renderizador de chunks. Nada do terreno trafega pela rede.

const CITY_RADIUS := 40.0     # área plana no centro (cidade inicial)
const CITY_BLEND := 70.0      # transição até o relevo normal
const CITY_HEIGHT := 4.0
const AMPLITUDE := 26.0
const WALL_START := 0.80      # fração do raio onde sobe a cordilheira que cerca a região
const WALL_END := 0.97
const WALL_HEIGHT := 90.0

var seed_value := 0
var half_size := 512.0
var forest := FastNoiseLite.new()   # manchas de floresta (usado na geração de recursos)
var rocks := FastNoiseLite.new()    # manchas de pedra
var _hills := FastNoiseLite.new()
var _detail := FastNoiseLite.new()


func _init(p_seed: int, p_half: float) -> void:
	seed_value = p_seed
	half_size = p_half
	_hills.seed = p_seed
	_hills.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_hills.frequency = 0.0035
	_hills.fractal_type = FastNoiseLite.FRACTAL_FBM
	_hills.fractal_octaves = 4
	_detail.seed = p_seed + 1
	_detail.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	_detail.frequency = 0.03
	forest.seed = p_seed + 2
	forest.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	forest.frequency = 0.012
	rocks.seed = p_seed + 3
	rocks.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	rocks.frequency = 0.015


func height(x: float, z: float) -> float:
	var h := (_hills.get_noise_2d(x, z) * 0.5 + 0.5) * AMPLITUDE + _detail.get_noise_2d(x, z) * 1.2
	var d := sqrt(x * x + z * z)
	h = lerpf(CITY_HEIGHT, h, smoothstep(CITY_RADIUS, CITY_RADIUS + CITY_BLEND, d))
	var edge := maxf(absf(x), absf(z)) / half_size
	return h + smoothstep(WALL_START, WALL_END, edge) * WALL_HEIGHT


# Inclinação (tangente do ângulo) em um ponto.
func slope(x: float, z: float) -> float:
	var dx := (height(x + 1.0, z) - height(x - 1.0, z)) * 0.5
	var dz := (height(x, z + 1.0) - height(x, z - 1.0)) * 0.5
	return sqrt(dx * dx + dz * dz)
