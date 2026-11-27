## Recurso coletável (árvore, pedra, arbusto). No online o servidor é quem coleta: lê estes campos
## da cena (Inspector) e sorteia os drops. Aqui só ficam os dados e o visual.
extends StaticBody3D
class_name HarvestableNode

## Coletas (golpes) até o recurso esgotar.
@export var health: int = 3
## Segundos por coleta (cada coleta sorteia os drops).
@export var gather_seconds: float = 1.5
## Segundos até o recurso voltar depois de esgotado.
@export var respawn_seconds: float = 120.0
## Informativo (o jogador atravessa objetos não sólidos).
@export var solid: bool = true
@export var slow_factor: float = 0.6
@export var drops: Array[HarvestDrop] = []
## Skill (profissão) exigida; define a ferramenta: woodcutting=machado, mining=picareta, harvesting=foice.
@export var required_skill: String = ""
@export var required_level: int = 0
## Qualidade do recurso; entra no cálculo da qualidade dos drops.
@export_range(1.0, 100.0) var node_quality: float = 20.0
@export var extra_xp_grants: Dictionary = {}
@export_group("Frutos")
@export var fruit_drops: Array[HarvestDrop] = []
## Chance de ESTE recurso dar frutos (fixa pela posição).
@export_range(0.0, 1.0, 0.05) var fruit_chance: float = 0.4
@export_group("Coleta à mão")
## Permite colher sem ferramenta (arbustos, itens do chão).
@export var hand_pickup: bool = false
@export var hand_cooldown: float = 1.5
@export var hand_xp: float = 2.0


func _ready() -> void:
	# O movimento é decidido pelo servidor (altura do terreno): corpos de colisão não servem aqui.
	for c in get_children():
		if c is CollisionShape3D:
			c.queue_free()
	collision_layer = 0
	collision_mask = 0
