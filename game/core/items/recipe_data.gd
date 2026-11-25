## Receita de fabricação (Resource).
extends Resource
class_name RecipeData

@export var id: String = ""
@export var result_item: ItemData
@export var result_amount: int = 1
@export var required_item_ids: Array[String] = []
@export var required_item_amounts: Array[int] = []
## Skill principal: define a qualidade do resultado e é exigida em [member required_level].
@export var related_skill: String = ""
## Nível mínimo em [member related_skill] para fabricar.
@export var required_level: int = 1
## XP concedido a [member related_skill] quando [member xp_grants] está vazio.
@export var xp_reward: float = 10.0
## XP concedido por skill ao fabricar: {skill: xp}. Vazio = usa related_skill/xp_reward.
## Ex. poção: {"alchemy": 12, "herbalism": 4, "healing": 4}.
@export var xp_grants: Dictionary = {}
## Requisitos extras de skill: {skill: nível}. Somam-se a related_skill/required_level.
@export var skill_requirements: Dictionary = {}
## 0 = descoberta ao obter um ingrediente; maior que 0 = descoberta ao fabricar um ingrediente.
@export var tier: int = 0
@export var station_type: String = "hand"

@export_group("Criação por NPC")
## Nível mínimo do NPC para fabricar esta receita (o nível sobe com as missões entregues a ele).
@export var npc_level: int = 1
## Taxa em moedas cobrada pelo NPC por unidade fabricada.
@export var craft_fee: int = 0


## {item_id: quantidade} dos ingredientes.
func get_required_items() -> Dictionary:
	var dict := {}
	for i in required_item_ids.size():
		dict[required_item_ids[i]] = required_item_amounts[i]
	return dict


## XP final por skill: {skill: xp}.
func get_xp_grants() -> Dictionary:
	if not xp_grants.is_empty():
		return xp_grants
	if related_skill != "":
		return {related_skill: xp_reward}
	return {}


## Todos os requisitos de skill: {skill: nível}.
func get_skill_requirements() -> Dictionary:
	var out: Dictionary = skill_requirements.duplicate()
	if related_skill != "" and required_level > 1:
		out[related_skill] = maxi(int(out.get(related_skill, 1)), required_level)
	return out
