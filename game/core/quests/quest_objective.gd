## Um objetivo de missão (Resource): coletar itens, derrotar inimigos ou alcançar nível de skill.
## Guardar dentro do [QuestData] (sub-recurso).
extends Resource
class_name QuestObjective

enum Type { COLLECT, KILL, SKILL_LEVEL }

@export var type: Type = Type.COLLECT
## COLLECT: id do item. KILL: id do inimigo. SKILL_LEVEL: id da skill.
@export var target: String = ""
## COLLECT/KILL: quantidade. SKILL_LEVEL: nível exigido.
@export var amount: int = 1
## COLLECT: remove os itens do inventário ao entregar a missão.
@export var consume: bool = true


## Nome legível do alvo.
func target_name() -> String:
	match type:
		Type.COLLECT:
			var item: ItemData = ItemRegistry.get_item(target)
			return tr(item.name_key) if item != null else tr("item_" + target)
		Type.KILL:
			return tr("entity_mob_" + target)
		_:
			return tr("skill_" + target)


## Texto do objetivo sem o progresso (ex.: "Coletar Tronco").
func describe() -> String:
	match type:
		Type.COLLECT:
			return tr("quest_obj_collect") % target_name()
		Type.KILL:
			return tr("quest_obj_kill") % target_name()
		_:
			return tr("quest_obj_skill") % [target_name(), amount]
