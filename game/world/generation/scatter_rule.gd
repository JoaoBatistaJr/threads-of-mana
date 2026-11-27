class_name ScatterRule
extends Resource

@export var scene: PackedScene
@export var variants: Array[PackedScene] = []
@export var biomes: PackedStringArray = ["meadow", "forest"]
@export_range(0.0, 20.0, 0.05) var density: float = 1.0
@export var min_scale: float = 1.0
@export var max_scale: float = 1.0
@export_range(0.0, 0.5, 0.01) var height_variation: float = 0.0
@export var max_slope_deg: float = 30.0
@export var min_height: float = -1000.0
@export var max_height: float = 1000.0
@export var y_offset: float = 0.0
@export var random_yaw: bool = true
@export_group("Inclinação")
@export_range(0.0, 1.0, 0.05) var slope_align: float = 0.5
@export_range(0.0, 30.0, 0.5) var random_tilt_deg: float = 4.0
@export_group("Espaçamento")
@export_range(0.0, 10.0, 0.1) var spacing_radius: float = 1.0
@export_group("Câmera")
@export var camera_fade: bool = false
@export_group("Horizonte")
@export var far_lod: bool = false
@export_group("Âncora (nasce perto de outros objetos)")
## Cenas de outras regras perto das quais este objeto nasce (ex.: pedras mineráveis). Vazio = regra normal por densidade.
## Com âncora, [member density] e [member biomes] são ignorados: valem o bioma e o terreno da âncora.
@export var anchor_scenes: Array[PackedScene] = []
## Chance de cada tentativa por âncora.
@export_range(0.0, 1.0, 0.05) var anchor_chance: float = 0.6
## Tentativas por âncora.
@export_range(1, 8) var per_anchor: int = 2
@export_range(0.5, 12.0, 0.1) var anchor_min_radius: float = 1.8
@export_range(0.5, 20.0, 0.1) var anchor_max_radius: float = 3.8


func has_scene() -> bool:
	return scene != null or not variants.is_empty()


func has_anchor() -> bool:
	return not anchor_scenes.is_empty()


func pick_scene(r: int) -> PackedScene:
	if variants.is_empty():
		return scene
	var v: PackedScene = variants[r % variants.size()]
	return v if v != null else scene
