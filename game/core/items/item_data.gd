## Dados estáticos de um item (Resource). Os valores variáveis (qualidade, durabilidade)
## ficam no slot, ver [ItemInstance].
extends Resource
class_name ItemData

@export var id: String = ""
@export var name_key: String = ""
@export var description_key: String = ""
@export_enum("materials", "tools", "gear", "consumables") var category: String = "materials"
@export var max_stack: int = 99
@export var icon: Texture2D
@export_group("Qualidade e durabilidade")
## Materiais/consumíveis com qualidade. Ferramentas e equipamentos sempre têm.
@export var has_quality: bool = false
## Qualidade (1-100) de itens obtidos sem fabricação (coleta, spawn, starting items).
@export_range(1.0, 100.0) var base_quality: float = 10.0
## Durabilidade máxima. 0 = o item não desgasta.
@export var max_durability: float = 0.0
@export_group("Economia")
## Valor em moedas. 0 = não pode ser vendido a NPCs.
@export var value: int = 0
@export_group("Requisitos")
## Nível mínimo por skill para usar o item: {skill: nível}. Ex.: {"sword": 5}.
@export var skill_requirements: Dictionary = {}
## Atributo mínimo do personagem para usar o item: {atributo: valor}. Ex.: {"strength": 12}.
@export var attribute_requirements: Dictionary = {}


## Quantos itens cabem em um slot.
func get_stack_limit() -> int:
	if category == "tools" or category == "gear":
		return 1
	return max_stack


## True se o item carrega qualidade.
func uses_quality() -> bool:
	return has_quality or category == "tools" or category == "gear"


## True se o item desgasta com o uso.
func uses_durability() -> bool:
	return max_durability > 0.0


## Requisitos não cumpridos, dados os níveis/atributos do personagem ({skill: nível}, {atributo: valor}).
## Função pura: o servidor passa os valores reais; o cliente usa só para exibir.
func unmet_requirements(skill_levels: Dictionary, attributes: Dictionary, base_attribute: int = 10) -> PackedStringArray:
	var out := PackedStringArray()
	for skill in skill_requirements:
		var need: int = int(skill_requirements[skill])
		if int(skill_levels.get(skill, 0)) < need:
			out.append("%s %d" % [tr("skill_" + str(skill)), need])
	for attr in attribute_requirements:
		var need: int = int(attribute_requirements[attr])
		if int(attributes.get(attr, base_attribute)) < need:
			out.append("%s %d" % [tr("attr_" + str(attr)), need])
	return out


func meets_requirements(skill_levels: Dictionary, attributes: Dictionary, base_attribute: int = 10) -> bool:
	return unmet_requirements(skill_levels, attributes, base_attribute).is_empty()
