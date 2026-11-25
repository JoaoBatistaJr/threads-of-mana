## Equipamento vestido (armadura, acessório, escudo). Bônus de atributo e stats extras vão em
## [member bonus_attributes] e [member stats]; a descrição vem de [member ItemData.description_key].
extends ItemData
class_name GearData

## Chaves de [member stats] mostradas como porcentagem.
const PERCENT_STATS: Array[String] = ["move_speed", "crit_chance", "block_chance"]

@export_enum("head", "neck", "chest", "hands", "waist", "legs", "feet", "back", "mount", "bracelet", "ring", "earring", "trinket", "main_hand", "off_hand") var gear_slot: String = "chest"
@export var defense: float = 0.0
@export_group("Bônus")
## Bônus de atributo ao vestir: {atributo: valor}. Ex.: {"strength": 1, "luck": 2}.
@export var bonus_attributes: Dictionary = {}
## Stats extras ao vestir: {stat: valor}. Chaves: max_health, max_stamina, inventory_slots (espaços de inventário),
## move_speed (%), crit_chance (%), block_chance (%) e resist_<tipo de dano> (%).
@export var stats: Dictionary = {}


@export_group("Visual no corpo")
## Cena com a roupa/armadura (glTF). Vazio = sem visual.
@export var visual_scene: PackedScene
## Nomes exatos das malhas da cena que este item veste (ex.: "Male_Ranger_Body"). Vazio = todas.
@export var visual_parts: PackedStringArray = PackedStringArray()
## Malhas do corpo base escondidas ao vestir (trecho do nome). Vazio = padrão do slot (EquipmentVisual.slot_hides).
@export var hide_base_parts: PackedStringArray = PackedStringArray()
## Se preenchido, a cena inteira é presa a este osso (escudo, mochila) em vez de vestida no esqueleto.
@export var attach_bone: StringName = &""
@export var attach_offset: Vector3 = Vector3.ZERO
@export var attach_rotation_deg: Vector3 = Vector3.ZERO
@export var attach_scale: float = 1.0
## Encaixe automático (só com [member attach_bone] e offset/rotação zerados): tamanho em metros
## do modelo no corpo (altura da mochila, largura da coroa, do colar, da armadura...). Posição,
## escala e rotação saem do slot e da forma do modelo. 0 = usa attach_offset/rotação/escala à mão.
@export var attach_fit_size: float = 0.0
## Ajuste fino do encaixe automático: deslocamento (m, espaço do osso: Y cima, Z frente) e giro (graus).
@export var attach_fit_offset: Vector3 = Vector3.ZERO
@export var attach_fit_yaw_deg: float = 0.0


func _init() -> void:
	category = "gear"


## Linhas de texto para o tooltip: defesa, atributos e stats ("Defesa: 4", "+1 Força", "Resistência a Corte: +5%").
func stat_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if defense > 0.0:
		lines.append("%s: %d" % [tr("ui_defense"), roundi(defense)])
	for attr in bonus_attributes:
		lines.append("%+d %s" % [int(bonus_attributes[attr]), tr("attr_" + str(attr))])
	for key in stats:
		var value: float = float(stats[key])
		var name_text: String
		var k: String = str(key)
		if k.begins_with("resist_"):
			name_text = tr("stat_resist") % tr("damage_" + k.substr(7))
		else:
			name_text = tr("stat_" + k)
		var suffix: String = "%" if (k.begins_with("resist_") or PERCENT_STATS.has(k)) else ""
		lines.append("%s: %+d%s" % [name_text, roundi(value), suffix])
	return lines
