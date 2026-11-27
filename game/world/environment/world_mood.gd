## Clima visual do mundo (Resource): correção de cor, luz, céu e névoa. Lido por [WorldLighting]
## e [WorldFog]. Se nenhum for atribuído, eles carregam res://resources/world/world_mood.tres.
## Para um mundo mais claro, aumente saturação, energia do sol e ambiente; para mais sombrio, o oposto.
extends Resource
class_name WorldMood

@export_group("Correção de cor")
## 1 = cores originais; menor = dessaturado.
@export_range(0.0, 1.5, 0.01) var saturation: float = 0.8
@export_range(0.5, 1.5, 0.01) var contrast: float = 1.08
@export_range(0.5, 1.5, 0.01) var brightness: float = 0.97
@export_range(0.5, 1.5, 0.01) var exposure: float = 0.95

@export_group("Luz")
@export_range(0.0, 2.0, 0.01) var sun_energy_mult: float = 0.85
@export_range(0.0, 2.0, 0.01) var ambient_energy_mult: float = 0.9
## Cor do sol rente ao horizonte.
@export var sun_color_low: Color = Color(0.95, 0.66, 0.48)
## Cor do sol a pino.
@export var sun_color_high: Color = Color(0.86, 0.91, 0.98)

@export_group("Céu")
@export var sky_zenith_day: Color = Color(0.20, 0.28, 0.40)
@export var sky_horizon_day: Color = Color(0.50, 0.57, 0.63)
@export var sky_twilight: Color = Color(0.85, 0.48, 0.32)
@export_range(0.0, 1.0, 0.01) var cloud_cover: float = 0.62
@export_range(0.2, 1.5, 0.01) var cloud_brightness: float = 0.8

@export_group("Névoa")
@export var fog_day: Color = Color(0.50, 0.56, 0.60)
@export var fog_night: Color = Color(0.03, 0.04, 0.07)
## Onde a névoa começa e termina, como fração da distância de visão.
@export_range(0.1, 0.9, 0.05) var fog_begin_ratio: float = 0.3
@export_range(0.5, 1.0, 0.05) var fog_end_ratio: float = 0.92
