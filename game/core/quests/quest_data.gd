## Definição de uma missão (Resource). Guardar em res://resources/quests/ e arrastar para
## [member NpcData.quests] do NPC que a oferece e recebe a entrega.
extends Resource
class_name QuestData

@export var id: String = ""
## Chaves de tradução do título e da descrição.
@export var title_key: String = ""
@export var desc_key: String = ""
## Id do NPC que dá e recebe a missão (para o rastreador: "Voltar para X"; nome em "npc_<id>").
@export var giver_id: String = ""
@export var objectives: Array[QuestObjective] = []

@export_group("Requisitos")
## Missão que precisa estar concluída antes (id). Vazio = nenhuma.
@export var requires_quest: String = ""
## Nível de personagem mínimo.
@export var min_character_level: int = 1
## {skill: nível mínimo}.
@export var requires_skills: Dictionary = {}

@export_group("Recompensas")
@export var reward_coins: int = 0
## {id_do_item: quantidade}.
@export var reward_items: Dictionary = {}
## XP de personagem. Missões NÃO dão XP de skill de vida: elas só treinam usando ferramentas ou coletando.
@export var reward_character_xp: float = 0.0
