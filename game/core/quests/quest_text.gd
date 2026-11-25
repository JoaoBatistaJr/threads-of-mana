## Monta o texto (BBCode) de uma missão para as janelas de NPC e do menu.
class_name QuestText

const C_GOLD: String = "#ffd659"
const C_DIM: String = "#9eadcc"
const C_OK: String = "#73f259"
const C_BAD: String = "#f26e6e"


## Descrição + objetivos com progresso + recompensas.
static func body(q: QuestData, comp) -> String:
	var t: String = "[color=%s]%s[/color]\n\n" % [C_DIM, TranslationServer.translate(q.desc_key)]
	t += "[b]%s[/b]\n" % TranslationServer.translate("quest_objectives")
	for i in q.objectives.size():
		t += objective_line(q, i, comp, true) + "\n"
	t += "\n[b]%s[/b]\n%s" % [TranslationServer.translate("quest_rewards"), rewards(q)]
	return t


## Uma linha de objetivo: "Coletar Tronco  3/5" (verde quando completo).
static func objective_line(q: QuestData, i: int, comp, bullet: bool = false) -> String:
	var o: QuestObjective = q.objectives[i]
	var cur: int = comp.objective_current(q, i) if comp.is_active(q.id) or comp.is_completed(q.id) else 0
	if comp.is_completed(q.id):
		cur = o.amount
	var done: bool = cur >= o.amount
	var color: String = C_OK if done else "#ffffff"
	var text: String = o.describe()
	if o.type != QuestObjective.Type.SKILL_LEVEL:
		text += "  %d/%d" % [cur, o.amount]
	elif done:
		text += "  OK"
	return "[color=%s]%s%s[/color]" % [color, "- " if bullet else "", text]


## Lista de recompensas em texto.
static func rewards(q: QuestData) -> String:
	var parts: PackedStringArray = []
	if q.reward_character_xp > 0.0:
		parts.append("[color=%s]%d XP %s[/color]" % [C_GOLD, int(q.reward_character_xp), TranslationServer.translate("quest_character")])
	if q.reward_coins > 0:
		parts.append("[color=%s]%d %s[/color]" % [C_GOLD, q.reward_coins, TranslationServer.translate("item_coin")])
	for id in q.reward_items:
		var item: ItemData = ItemRegistry.get_item(str(id))
		var nm: String = TranslationServer.translate(item.name_key) if item != null else str(id)
		parts.append("%dx %s" % [int(q.reward_items[id]), nm])
	return "\n".join(parts) if not parts.is_empty() else "-"
