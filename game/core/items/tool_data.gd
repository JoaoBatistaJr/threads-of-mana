## Item de mão: ferramenta e/ou arma. O mesmo item pode servir para coletar e para lutar
## (ex.: faca). O que é vestido (armadura, acessórios, escudo) é [GearData].
extends ItemData
class_name ToolData

## Slot de ferramenta onde o item fica equipado. "weapon" é para armas que não são ferramentas.
@export_enum("axe", "pickaxe", "shovel", "hoe", "sickle", "knife", "weapon", "other") var tool_type: String = "other"
@export var tier: int = 0
@export var action_interval: float = 1.0
## Skill de coleta/uso utilitário que esta ferramenta treina (ex.: "woodcutting").
@export var related_skill: String = ""
## Skills extras treinadas ao usar o item, como proporção do XP da ação: {skill: razão}.
## Só vale ao coletar. Ex.: machado = {"axe": 0.5}: cada golpe na árvore dá XP de lenhador e metade disso em machado.
## Ao lutar, só a skill da arma ([method combat_skill]) recebe XP.
@export var bonus_skills: Dictionary = {}

@export_group("Combate")
## Skill de combate treinada ao atacar com o item (ex.: "dagger"). Vazio = não é arma.
@export var weapon_skill: String = ""
@export var base_damage: float = 1.0
@export var damage_type: String = "physical"
@export var combat_efficiency: float = 1.0
## Alcance do ataque em metros. 0 = automático (ver [method effective_range]).
@export var attack_range: float = 0.0

@export_group("Combate (variação)")
## Somados ao padrão do tipo de arma (ver [constant PROFILES]).
@export var accuracy_bonus: float = 0.0
@export var crit_bonus: float = 0.0
## 0 = usa o do tipo de arma.
@export var crit_multiplier: float = 0.0
## Variação do dano a cada golpe (0.15 = ±15%). -1 = usa o do tipo de arma.
@export var damage_variance: float = -1.0

@export_group("Habilidades")
## Velocidade de carga das habilidades por ataque básico. 0 = padrão do tipo da arma
## (ver [constant CHARGE_BY_SKILL]); menor = arma mais pesada.
@export var ability_charge_mult: float = 0.0

@export_group("Mãos")
## Mãos que a arma ocupa (1 ou 2). 0 = automático pelo tipo (lança e arco usam 2; as demais usam 1). Armas "combat": 1 mão = pistola, 2 mãos = rifle.
@export_range(0, 2) var hands: int = 0
## Pode ser usada na mão secundária junto de outra arma (adagas, espadas curtas...). Adagas e
## armas de fogo leves já podem por padrão.
@export var dual_wield: bool = false

@export_group("Munição")
## Item gasto a cada tiro (ex.: flecha, munição de pistola). Vazio = não gasta munição.
@export var ammo_item: ItemData
@export var ammo_per_shot: int = 1

@export_group("Mão")
@export var held_scene: PackedScene
@export var held_offset: Vector3 = Vector3.ZERO
@export var held_rotation_deg: Vector3 = Vector3.ZERO
@export var held_scale: float = 1.0
## Posição quando a arma está guardada (costas/cintura), relativa ao osso de guarda.
@export var sheath_offset: Vector3 = Vector3(0.0, 0.05, -0.18)
@export var sheath_rotation_deg: Vector3 = Vector3(0.0, 0.0, 55.0)


## Perfil de combate por tipo de arma: precisão, chance de crítico extra, multiplicador de
## crítico e variação do dano.
const PROFILES: Dictionary = {
	"sword": {"acc": 0.0, "crit": 0.03, "mult": 1.75, "var": 0.12},
	"axe": {"acc": -0.03, "crit": 0.02, "mult": 2.0, "var": 0.18},
	"dagger": {"acc": 0.05, "crit": 0.10, "mult": 1.6, "var": 0.10},
	"spear": {"acc": 0.03, "crit": 0.03, "mult": 1.7, "var": 0.12},
	"mace": {"acc": -0.05, "crit": 0.0, "mult": 1.75, "var": 0.22},
	"bow": {"acc": 0.0, "crit": 0.05, "mult": 1.8, "var": 0.15},
	"combat": {"acc": 0.05, "crit": 0.05, "mult": 1.8, "var": 0.08},
}
const DEFAULT_PROFILE: Dictionary = {"acc": 0.0, "crit": 0.02, "mult": 1.75, "var": 0.15}


## Velocidade com que os ataques básicos carregam as habilidades, por skill de combate
## (armas pesadas carregam mais devagar).
const CHARGE_BY_SKILL: Dictionary = {"sword": 1.0, "axe": 0.85, "dagger": 1.25, "mace": 0.7, "spear": 0.9, "bow": 0.9, "pistol": 1.1, "rifle": 0.85}

## Mãos por tipo de arma e tipos que podem ser usados nas duas mãos (quando de 1 mão).
const HANDS_BY_TYPE: Dictionary = {"spear": 2, "bow": 2}
const DUAL_TYPES: Array[String] = ["dagger", "combat"]


func _init() -> void:
	category = "tools"


## True se cada ataque gasta munição do inventário.
func uses_ammo() -> bool:
	return ammo_item != null and ammo_per_shot > 0


## True se o item pode ser usado para atacar.
func is_weapon() -> bool:
	return weapon_skill != ""


## XP das [member bonus_skills] para uma ação que rendeu [param base_xp]: {skill: xp}.
func bonus_grants(base_xp: float) -> Dictionary:
	var out: Dictionary = {}
	for skill in bonus_skills:
		out[str(skill)] = base_xp * float(bonus_skills[skill])
	return out


## Alcance real do ataque: [member attack_range] se definido; senão estimado pela arma
## (corpo a corpo 3,5 m; lança 4,5 m; arco 18 m; armas de fogo 22 m; energia 25 m).
func effective_range() -> float:
	if attack_range > 0.0:
		return attack_range
	if damage_type == "energy":
		return 25.0
	match weapon_skill:
		"bow":
			return 18.0
		"combat":
			return 22.0
		"spear":
			return 4.5
	return 3.5


func _profile() -> Dictionary:
	return PROFILES.get(weapon_skill, DEFAULT_PROFILE)


## Bônus de chance de acerto desta arma.
func hit_bonus() -> float:
	return float(_profile().acc) + accuracy_bonus


## Bônus de chance de crítico desta arma.
func crit_chance_bonus() -> float:
	return float(_profile().crit) + crit_bonus


func crit_mult() -> float:
	return crit_multiplier if crit_multiplier > 0.0 else float(_profile().mult)


func variance() -> float:
	return damage_variance if damage_variance >= 0.0 else float(_profile()["var"])


## Arma "pura" (só combate): equipa nas mãos. Ferramentas com skill de arma (machado...) vão para a hotbar.
func is_pure_weapon() -> bool:
	return tool_type == "weapon" and weapon_skill != ""


## Mãos ocupadas (1 ou 2).
func hand_count() -> int:
	if hands > 0:
		return hands
	return int(HANDS_BY_TYPE.get(weapon_skill, 1))


## True se pode ir na mão secundária.
func can_dual_wield() -> bool:
	return hand_count() == 1 and (dual_wield or DUAL_TYPES.has(weapon_skill))


## Velocidade de carga das habilidades (1.0 = normal).
func charge_rate() -> float:
	if ability_charge_mult > 0.0:
		return ability_charge_mult
	return float(CHARGE_BY_SKILL.get(combat_skill(), 1.0))


## Skill de combate treinada e usada nas habilidades. Armas à distância "combat" (fogo, energia
## ou outra) usam pela quantidade de mãos: 1 mão = "pistol", 2 mãos = "rifle".
## Não existe skill de combate geral.
func combat_skill() -> String:
	if weapon_skill == "combat":
		return "rifle" if hand_count() >= 2 else "pistol"
	return weapon_skill
