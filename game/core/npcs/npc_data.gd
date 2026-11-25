## Dados de um NPC de profissão (Resource): quem é, o que cria e o que vende.
## Guardar em res://resources/npcs/.
extends Resource
class_name NpcData

@export var id: String = ""
## Chave de tradução do nome (ex.: "npc_ferreiro").
@export var name_key: String = ""
## Skill da profissão (ex.: "smithing"); aparece como subtítulo do NPC.
@export var profession: String = ""
## Cor da cápsula placeholder (até existir o modelo do NPC).
@export var color: Color = Color(0.8, 0.7, 0.5)

@export_group("Criação")
## Receitas avançadas que o NPC fabrica para o jogador (exigem os ingredientes e os níveis de skill).
@export var recipes: Array[RecipeData] = []

@export_group("Missões")
## Missões que o NPC oferece e recebe (entrega).
@export var quests: Array[QuestData] = []

@export_group("Loja")
## Itens à venda. O preço vem de [member ItemData.value] x [member shop_markup].
## Só entram à venda itens prontos (não materiais) com tier até [member max_shop_tier]: o jogador
## precisa craftar o resto.
@export var shop_items: Array[ItemData] = []
## Maior tier de item que o NPC vende.
@export var max_shop_tier: int = 1
## Itens extras (ids) que o NPC compra do jogador, além dos ligados às suas receitas e loja.
@export var extra_trade_ids: PackedStringArray = []
@export_range(0.5, 5.0, 0.05) var shop_markup: float = 1.5
## Fração de [member ItemData.value] que o NPC paga ao comprar itens do jogador.
@export_range(0.0, 1.0, 0.05) var buy_ratio: float = 0.4
## Moedas que o NPC tem para comprar itens do jogador (e o teto de reabastecimento).
@export var max_coins: int = 500
## Moedas que o NPC recupera por minuto até [member max_coins].
@export var coin_regen_per_minute: float = 20.0


## Nome próprio do NPC (chave "npc_<id>_person"); sem tradução, usa o nome do cargo.
func person_name() -> String:
	var key: String = "npc_%s_person" % id
	var t: String = tr(key)
	return t if t != key else tr(name_key)


## Cargo/profissão exibido abaixo do nome (ex.: "Ferreiro").
func role_title() -> String:
	return tr(name_key)


## Fala de apresentação (chave "npc_<id>_greeting"); vazio se não existir.
func greeting() -> String:
	var key: String = "npc_%s_greeting" % id
	var t: String = tr(key)
	return t if t != key else ""


func has_crafting() -> bool:
	return not recipes.is_empty()


func has_quests() -> bool:
	return not quests.is_empty()


func has_shop() -> bool:
	return shop_items.any(func(i): return can_sell_to_player(i))


var _trade_ids: Dictionary = {}


## True se o item é da área deste NPC: resultado ou ingrediente das suas receitas, item da
## loja ou listado em [member extra_trade_ids]. O NPC só compra itens assim.
func deals_in(item: ItemData) -> bool:
	if item == null:
		return false
	if _trade_ids.is_empty():
		for r in recipes:
			if r == null:
				continue
			if r.result_item != null:
				_trade_ids[r.result_item.id] = true
			for id in r.required_item_ids:
				_trade_ids[id] = true
		for it in shop_items:
			if it != null:
				_trade_ids[it.id] = true
		for id in extra_trade_ids:
			_trade_ids[id] = true
		_trade_ids["_built"] = true
	return _trade_ids.has(item.id)


## True se o NPC vende o item: pronto (não material) e de tier até [member max_shop_tier].
func can_sell_to_player(item: ItemData) -> bool:
	if item == null or item.category == "materials":
		return false
	var tier = item.get("tier")
	return (int(tier) if tier != null else 0) <= max_shop_tier


## Preço (moedas) para o jogador comprar 1 unidade.
func buy_price(item: ItemData) -> int:
	return maxi(1, roundi(item.value * shop_markup))


## Valor (moedas) que o NPC paga por 1 unidade do jogador. 0 = não compra.
func sell_price(item: ItemData) -> int:
	if item.value <= 0 or not deals_in(item):
		return 0
	return maxi(1, roundi(item.value * buy_ratio))
