class_name WorldConfig
extends Resource

@export var world_seed: int = 0
@export_group("Chunks")
@export var chunk_size: float = 32.0
@export var chunk_resolution: int = 32
@export var view_distance: int = 5
@export_group("Relevo")
@export var height_scale: float = 32.0
@export var terrain_frequency: float = 0.003
@export var terrain_octaves: int = 5
@export_range(0.1, 1.0, 0.05) var valley_depth: float = 0.6
## Cidade inicial: área perfeitamente plana ao redor do spawn (0, 0) e largura da rampa até o relevo normal.
@export var spawn_flat_radius: float = 110.0
@export var spawn_blend_radius: float = 320.0
@export var terrain_material: Material
@export_group("Relevo (camadas)")
## Campo de elevação contínuo (0..1): planície -> colinas -> serra -> montanha.
## swell_height = quanto o terreno sobe só por estar em área alta (metros).
@export var swell_height: float = 40.0
## Menor = regiões de elevação maiores (1/frequência = tamanho em metros).
@export var swell_frequency: float = 0.0006
## Contraste do campo de elevação (maior = mais planícies e mais montanhas, menos meio-termo).
@export_range(0.8, 2.5, 0.05) var elevation_contrast: float = 1.6
## Deformação das coordenadas (quebra o aspecto de bolhas). 0 desliga.
@export var warp_strength: float = 140.0
@export var warp_frequency: float = 0.0011
## Achatamento em patamares (bom para construir). 0 desliga.
@export_range(0.0, 1.0, 0.05) var terrace_strength: float = 0.15
@export var terrace_step: float = 7.0
## Irregularidade fina do chão.
@export var detail_height: float = 0.7
@export var detail_frequency: float = 0.05
@export_group("Montanhas")
@export var mountain_height: float = 80.0
## Elevação (0..1) em que as montanhas começam a crescer e em que atingem a altura total.
## Quanto maior a distância entre as duas, mais gradual é a subida.
@export_range(0.0, 1.0, 0.01) var mountain_start: float = 0.5
@export_range(0.0, 1.0, 0.01) var mountain_full: float = 0.95
## Variação de intensidade dentro das cordilheiras.
@export var mountain_frequency: float = 0.0025
@export var ridge_frequency: float = 0.003
@export_range(0.005, 0.2, 0.005) var ridge_smoothness: float = 0.08
## Quanto o maciço sobe como um todo (fração da altura das montanhas).
@export_range(0.0, 0.6, 0.05) var mountain_base_lift: float = 0.2
@export_group("Continente")
## Raio do continente em metros. 0 = mundo infinito, sem mar.
@export var world_radius: float = 20000.0
## Largura da transição terra -> mar aberto.
@export var coast_width: float = 1500.0
## Quanto o ruído deforma a costa (metros).
@export var coast_roughness: float = 1200.0
@export var coast_frequency: float = 0.00035
@export var sea_level: float = -5.0
@export var sea_depth: float = 30.0
## Intensidade do frio ao norte e calor ao sul. 0 desliga.
@export_range(0.0, 1.5, 0.05) var latitude_strength: float = 0.8
## Umidade extra perto da costa.
@export_range(0.0, 1.0, 0.05) var coast_wetness: float = 0.3
## Altura da praia acima do nível do mar.
@export var beach_height: float = 2.5
@export var beach_color: Color = Color(0.86, 0.78, 0.56)
@export var ocean_color: Color = Color(0.1, 0.35, 0.5, 0.85)
@export_group("Rios")
## Quantidade de rios que descem até o mar. 0 desliga.
@export_range(0, 12) var river_count: int = 4
@export var river_width_min: float = 5.0
@export var river_width_max: float = 14.0
@export var river_depth: float = 1.6
## Desenha a água dos rios (o relevo do leito continua mesmo desligado).
@export var river_water: bool = false
## Umidade extra perto dos rios.
@export_range(0.0, 1.0, 0.05) var river_wetness: float = 0.35
## Distância mínima entre nascentes (metros).
@export var river_min_spacing: float = 1500.0
@export_group("Bioma")
@export var biomes: Array[BiomeData] = []
@export var moisture_frequency: float = 0.00025
@export var temperature_frequency: float = 0.00018
@export var climate_contrast: float = 1.6
@export var altitude_cooling: float = 0.2
@export_range(0.01, 0.5, 0.01) var biome_softness: float = 0.15
@export_group("Tiers")
## Distâncias do spawn (m) onde começam os tiers 1, 2 e 3 (~14 min de caminhada a 6 m/s entre elas).
@export var tier_distances: PackedFloat32Array = PackedFloat32Array([5000.0, 10000.0, 15000.0])
## Deformação das fronteiras de tier por ruído (m); 0 = anéis perfeitos.
@export var tier_warp: float = 2500.0
@export var tier_noise_frequency: float = 0.0002
## Suavidade da transição entre tiers (em unidades de tier).
@export_range(0.05, 0.6, 0.05) var tier_softness: float = 0.25
@export_group("Objetos")
@export var scatter_rules: Array[ScatterRule] = []
## Raio sem árvores/pedras ao redor do spawn (a cidade inicial).
@export var spawn_clear_radius: float = 120.0
@export_group("Grama")
@export var grass_enabled: bool = true
## Raio da grama em chunks.
@export_range(1, 8) var grass_radius: int = 3
## Tufos por m² perto do jogador (antes do filtro de bioma).
@export_range(0.2, 12.0, 0.1) var grass_density: float = 4.0
## Chunks (raio) com densidade total; além disso a grama usa [member grass_far_density_mult].
@export_range(0, 4) var grass_near_chunks: int = 1
## Fração da densidade nos chunks mais afastados (mais barato, tufos maiores).
@export_range(0.05, 1.0, 0.05) var grass_far_density_mult: float = 0.3
@export_range(0.1, 2.0, 0.05) var grass_height: float = 0.55
@export_range(0.0, 0.5, 0.01) var grass_wind: float = 0.12
@export_range(10.0, 75.0, 1.0) var grass_max_slope_deg: float = 58.0
## Multiplica a cor do bioma (use para clarear/escurecer a grama).
@export var grass_tint: Color = Color(1, 1, 1)
## Altura, densidade e cor da grama por bioma (misturados suavemente nas fronteiras).
@export var grass_styles: Array[GrassStyle] = []
## Cor aplicada onde dois biomas se misturam (multiplica a cor; amarelado = grama seca).
@export var grass_edge_tint: Color = Color(1.0, 0.9, 0.6)
## Multiplicador de altura nas fronteiras entre biomas.
@export_range(0.2, 2.0, 0.05) var grass_edge_height: float = 0.8


## Altura de referência dos biomas por altitude (rocha e neve começam perto dela).
func altitude_scale() -> float:
	return height_scale + swell_height


func has_sea() -> bool:
	return world_radius > 0.0


func world_extent() -> float:
	return world_radius + coast_roughness + chunk_size * 2.0
