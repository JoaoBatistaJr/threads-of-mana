## Consumível com efeito ao usar (poção, bandagem, comida). O efeito é aplicado pelo servidor.
extends ItemData
class_name ConsumableData

@export_group("Efeito")
## Vida restaurada na hora.
@export var heal: float = 0.0
## Vida restaurada aos poucos: total ao longo de [member regen_seconds].
@export var regen_total: float = 0.0
@export var regen_seconds: float = 0.0
## Energia (stamina) restaurada na hora.
@export var restore_stamina: float = 0.0
## Buff temporário ao usar: {stat: valor} por [member buff_seconds] segundos
## (ex.: {"max_health": 20.0}, {"move_speed": 10.0} em %, {"attr_strength": 2}).
@export var buff_mods: Dictionary = {}
@export var buff_seconds: float = 0.0
## Letra mostrada no ícone do buff (vazio = inicial do nome).
@export var buff_glyph: String = ""
## Remove todos os sangramentos ativos.
@export var stops_bleed: bool = false



func _init() -> void:
	category = "consumables"


## Linhas de efeito para tooltips.
func effect_lines() -> PackedStringArray:
	var lines := PackedStringArray()
	if heal > 0.0:
		lines.append("+%d vida" % roundi(heal))
	if regen_total > 0.0:
		lines.append("+%d vida em %ds" % [roundi(regen_total), roundi(regen_seconds)])
	if restore_stamina > 0.0:
		lines.append("+%d energia" % roundi(restore_stamina))
	if buff_seconds > 0.0 and not buff_mods.is_empty():
		for k in buff_mods:
			lines.append("%+d %s (%ds)" % [roundi(float(buff_mods[k])), str(k).trim_prefix("attr_"), roundi(buff_seconds)])
	if stops_bleed:
		lines.append("Estanca sangramento")
	return lines
