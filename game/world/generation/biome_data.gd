class_name BiomeData
extends Resource

enum Ground { GRASS, SAND, SNOW, MUD, ROCK }

@export var id: String = "biome"
@export var color: Color = Color.WHITE
@export var ground: Ground = Ground.GRASS
@export_group("Faixas (-1 a 1)")
@export var temperature: Vector2 = Vector2(-1.0, 1.0)
@export var moisture: Vector2 = Vector2(-1.0, 1.0)
@export var altitude: Vector2 = Vector2(-1.0, 1.0)
@export_group("Progressão")
## Primeiro tier (0 = perto do spawn) em que o bioma pode aparecer.
@export_range(0, 3) var tier_min: int = 0
## Último tier em que o bioma pode aparecer.
@export_range(0, 3) var tier_max: int = 3
