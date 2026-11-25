## Definição de um tipo de recurso do mundo (árvore, pedra...). Dados puros: servidor e cliente leem o mesmo .tres.
## A cena visual (modelo, textura, animação) fica separada e aponta para este id.
class_name ResourceDef
extends Resource

@export var id: String = ""
@export var name_key: String = ""
## Ferramenta usada (índice de ResourceNodes.Tool).
@export_enum("AXE", "PICKAXE", "SICKLE") var tool: int = 0
@export var drops: Array[HarvestDrop] = []
## Golpes até esgotar e segundos para reaparecer.
@export var hits: int = 3
@export var respawn_seconds: float = 30.0
@export var gather_seconds: float = 2.0
## Skill (profissão) exigida e nível mínimo. Vazio = sem requisito.
@export var required_skill: String = ""
@export var required_level: int = 0
## Qualidade do recurso; vira a qualidade dos itens coletados.
@export_range(1.0, 100.0) var node_quality: float = 20.0
