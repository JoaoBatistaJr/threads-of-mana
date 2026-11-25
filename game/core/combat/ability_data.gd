## Habilidade de arma (Resource). Guardar em res://resources/abilities/. Fica disponível para
## qualquer arma cuja [member ToolData.weapon_skill] seja igual a [member weapon_skill] e
## destrava no nível [member required_level] dessa skill.
extends Resource
class_name AbilityData

const DIR: String = "res://resources/abilities"

static var _all: Array[AbilityData] = []
static var _scanned: bool = false

@export var id: String = ""
@export var weapon_skill: String = ""
@export var required_level: int = 1
## Referência de "peso" da habilidade: segundos de ataque contínuo para encher a barra de
## energia. Só vale quando [member charge_attacks] é 0.
@export var cooldown: float = 8.0
## Ataques básicos necessários para encher a barra (estilo Xenoblade). 0 = automático a partir
## de [member cooldown]. A barra só carrega enquanto o jogador ataca.
@export var charge_attacks: float = 0.0
## Segundos após o uso até a barra voltar a carregar.
@export var recovery_time: float = 1.5
## Em que postura ela aparece: "" = sempre; "dual" = com duas armas do mesmo tipo; "shield" = com escudo.
@export var stance: String = ""
## Habilidades com o mesmo grupo ocupam o mesmo lugar (ex.: corte diagonal com uma adaga e
## corte em X com duas). Vale a que combina com a postura atual.
@export var variant_group: String = ""

@export_group("Dano")
## Multiplica o dano de cada golpe.
@export var damage_mult: float = 1.0
## Número de golpes seguidos.
@export var hits: int = 1
## Multiplica o alcance da arma.
@export var range_mult: float = 1.0
## Fração da defesa do alvo ignorada (0 a 1).
@export_range(0.0, 1.0, 0.05) var armor_pierce: float = 0.0
## Se > 0, atinge também os inimigos a esse raio (m) do alvo.
@export var cleave_radius: float = 0.0

@export_group("Precisão")
## Dano extra (fração: 1.0 = +100%) se o alvo estiver com pouca vida.
@export var execute_bonus: float = 0.0
@export_range(0.05, 0.9, 0.05) var execute_threshold: float = 0.35
@export var always_hit: bool = false
@export var hit_bonus: float = 0.0
@export var guaranteed_crit: bool = false
@export var crit_bonus: float = 0.0

@export_group("Efeitos")
## Sangramento total = dano causado x este valor, ao longo de [member bleed_time].
@export var bleed_ratio: float = 0.0
@export var bleed_time: float = 0.0
@export var stun_time: float = 0.0
## Fração de lentidão (0 a 0.9) por [member slow_time] segundos.
@export_range(0.0, 0.9, 0.05) var slow_amount: float = 0.0
@export var slow_time: float = 0.0
@export var knockback: float = 0.0
## Reduz o dano que o alvo causa (fração) por [member weaken_time] segundos.
@export_range(0.0, 0.9, 0.05) var weaken_amount: float = 0.0
@export var weaken_time: float = 0.0


## Duração média de um ataque básico, usada para converter [member cooldown] em ataques.
const ATTACK_SECONDS: float = 1.2


## Ataques básicos para encher a barra desta habilidade.
func attacks_to_charge() -> float:
	return charge_attacks if charge_attacks > 0.0 else maxf(2.0, cooldown / ATTACK_SECONDS)


func name_key() -> String:
	return "ability_" + id


func desc_key() -> String:
	return "ability_%s_desc" % id


func display_name() -> String:
	return tr(name_key())


## Habilidades de [param skill] para a postura [param stance] ("", "dual" ou "shield"): uma por
## grupo (a variante da postura, ou a comum), ordenadas por nível exigido.
static func for_stance(skill: String, stance: String) -> Array[AbilityData]:
	_scan()
	var picked: Dictionary = {}
	for a in _all:
		if a.weapon_skill != skill:
			continue
		if a.stance != "" and a.stance != stance:
			continue
		var key: String = a.variant_group if a.variant_group != "" else a.id
		var current: AbilityData = picked.get(key)
		if current == null or (a.stance == stance and current.stance != stance):
			picked[key] = a
	var out: Array[AbilityData] = []
	for a in picked.values():
		out.append(a)
	out.sort_custom(func(a, b):
		if a.required_level != b.required_level:
			return a.required_level < b.required_level
		return a.id < b.id)
	return out


## Todas as habilidades de [param skill] (inclusive variantes), por nível, grupo e postura.
static func all_for_skill(skill: String) -> Array[AbilityData]:
	_scan()
	var out: Array[AbilityData] = []
	for a in _all:
		if a.weapon_skill == skill:
			out.append(a)
	out.sort_custom(func(a, b):
		if a.required_level != b.required_level:
			return a.required_level < b.required_level
		if a.stance != b.stance:
			return a.stance < b.stance
		return a.id < b.id)
	return out


## Chave do grupo de variantes.
func group_key() -> String:
	return variant_group if variant_group != "" else id


static func _scan() -> void:
	if _scanned:
		return
	_scanned = true
	for f in DirAccess.get_files_at(DIR):
		var name: String = f.trim_suffix(".remap")
		if name.ends_with(".tres"):
			var res := load("%s/%s" % [DIR, name]) as AbilityData
			if res != null and res.id != "":
				_all.append(res)
