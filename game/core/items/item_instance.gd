## Utilitários para instâncias de item dentro de slots.
##
## Um slot é um [Dictionary]: [code]{"data": ItemData, "amount": int}[/code] e,
## quando o item usa, também [code]"quality"[/code] (1-100), [code]"durability"[/code]
## e [code]"crafter"[/code]. Itens simples guardam só [code]data[/code] e [code]amount[/code].
class_name ItemInstance
extends RefCounted

const MIN_QUALITY: float = 1.0
const MAX_QUALITY: float = 100.0
## Faixas de qualidade: [limite superior exclusivo, chave de tradução, cor].
const TIERS: Array = [
	[20.0, "quality_crude", Color(0.6, 0.6, 0.6)],
	[40.0, "quality_common", Color(0.92, 0.92, 0.92)],
	[60.0, "quality_good", Color(0.4, 0.85, 0.45)],
	[80.0, "quality_fine", Color(0.4, 0.65, 1.0)],
	[95.0, "quality_excellent", Color(0.75, 0.5, 0.95)],
]
const TIER_TOP: String = "quality_masterwork"
const TIER_TOP_COLOR: Color = Color(1.0, 0.65, 0.2)


## Cria um slot. [param quality] e [param durability] negativos usam os padrões do [ItemData].
static func make(data: ItemData, amount: int = 1, quality: float = -1.0, durability: float = -1.0, crafter: String = "") -> Dictionary:
	var e: Dictionary = {"data": data, "amount": amount}
	if data.uses_quality():
		e["quality"] = clampf(quality if quality >= 0.0 else data.base_quality, MIN_QUALITY, MAX_QUALITY)
	if data.uses_durability():
		e["durability"] = clampf(durability if durability >= 0.0 else data.max_durability, 0.0, data.max_durability)
	if crafter != "":
		e["crafter"] = crafter
	return e


## Cópia independente do slot.
static func copy(entry: Dictionary) -> Dictionary:
	return entry.duplicate()


## Qualidade do slot (usa [member ItemData.base_quality] se o slot não tiver).
static func quality_of(entry: Variant) -> float:
	if entry == null or entry.is_empty():
		return 0.0
	return float(entry.get("quality", entry.data.base_quality))


## Durabilidade atual, ou -1 se o item não tem durabilidade.
static func durability_of(entry: Variant) -> float:
	if entry == null or entry.is_empty() or not entry.data.uses_durability():
		return -1.0
	return float(entry.get("durability", entry.data.max_durability))


## True se dois slots podem ser empilhados. Ferramentas/equipamentos exigem a mesma qualidade
## exata; consumíveis e materiais com qualidade empilham dentro da mesma faixa (a qualidade do
## slot vira a média ao juntar). Itens com durabilidade exigem a mesma durabilidade.
static func can_stack(a: Variant, b: Variant) -> bool:
	if a == null or b == null or a.is_empty() or b.is_empty():
		return false
	if a.data.id != b.data.id:
		return false
	if a.data.uses_quality():
		var qa: float = quality_of(a)
		var qb: float = quality_of(b)
		if a.data.get_stack_limit() <= 1:
			if floori(qa) != floori(qb):
				return false
		elif tier_key(qa) != tier_key(qb):
			return false
	if a.data.uses_durability() and not is_equal_approx(durability_of(a), durability_of(b)):
		return false
	return true


## Gasta durabilidade. Retorna true se o item quebrou (chegou a 0).
static func wear(entry: Dictionary, amount: float = 1.0) -> bool:
	if entry.is_empty() or not entry.data.uses_durability():
		return false
	var d: float = maxf(durability_of(entry) - amount, 0.0)
	entry["durability"] = d
	return d <= 0.0


## Chave de tradução da faixa de qualidade (ex.: "quality_good").
static func tier_key(quality: float) -> String:
	for t in TIERS:
		if quality < t[0]:
			return t[1]
	return TIER_TOP


## Cor da faixa de qualidade.
static func tier_color(quality: float) -> Color:
	for t in TIERS:
		if quality < t[0]:
			return t[2]
	return TIER_TOP_COLOR


## Multiplicador de eficácia por qualidade: QL 50 = 1.0, QL 1 = 0.51, QL 100 = 1.5.
static func quality_multiplier(quality: float) -> float:
	return 0.5 + clampf(quality, 0.0, MAX_QUALITY) / 100.0


## Converte o slot para um Dictionary serializável em JSON.
static func to_save(entry: Dictionary) -> Dictionary:
	var d: Dictionary = {"id": entry.data.id, "n": int(entry.amount)}
	if entry.has("quality"):
		d["q"] = snappedf(float(entry["quality"]), 0.01)
	if entry.has("durability"):
		d["d"] = snappedf(float(entry["durability"]), 0.01)
	if str(entry.get("crafter", "")) != "":
		d["c"] = str(entry["crafter"])
	return d


## Reconstrói um slot salvo por [method to_save]. Retorna {} se inválido.
static func from_save(d: Dictionary, item: ItemData) -> Dictionary:
	var n: int = int(d.get("n", 1))
	if item == null or n <= 0:
		return {}
	return make(item, n, float(d.get("q", -1.0)), float(d.get("d", -1.0)), str(d.get("c", "")))
