## Habilidade especial de criatura (Resource). Guardar em res://resources/mobs/abilities/ e
## arrastar para [member MobData.abilities]. Um gatilho decide QUANDO ela acontece na luta e a
## ação decide O QUE acontece; o [MobAbilityRunner] executa, sem código por mob.
extends Resource
class_name MobAbility

enum Trigger { COMBAT_START, HEALTH_BELOW, EVERY_SECONDS, ON_HIT_TAKEN, ALLY_DIED, TARGET_LOW_HEALTH }
enum Kind { ATTACK, AREA, CHARGE, SUMMON, CALL_ALLIES, BUFF_SELF, HEAL_SELF }
enum Center { SELF, TARGET }

## Id único; o nome vem da chave "mob_ability_<id>".
@export var id: String = ""

@export_group("Gatilho")
@export var trigger: Trigger = Trigger.EVERY_SECONDS
## Fração (0 a 1): vida do mob (HEALTH_BELOW) ou do alvo (TARGET_LOW_HEALTH).
@export_range(0.0, 1.0, 0.05) var threshold: float = 0.5
## Intervalo de EVERY_SECONDS; nos demais gatilhos é o tempo mínimo entre usos.
@export var cooldown: float = 10.0
## Chance de usar (EVERY_SECONDS a cada intervalo; ON_HIT_TAKEN a cada golpe recebido).
@export_range(0.0, 1.0, 0.05) var chance: float = 1.0
## Só uma vez por luta (volta a valer quando o mob desiste e retorna).
@export var once_per_fight: bool = false
## Só usa com o alvo entre estas distâncias (0 = sem limite). Vale para ATTACK, AREA e CHARGE.
@export var min_range: float = 0.0
@export var max_range: float = 0.0
## Raio em que mobs do mesmo tipo contam para ALLY_DIED.
@export var ally_radius: float = 20.0

@export_group("Ação")
@export var kind: Kind = Kind.ATTACK
## Tempo de preparo antes de agir; o mob fica parado e pode ser atordoado (cancela).
@export var telegraph_time: float = 0.0
## AREA/CHARGE: onde a área é centrada (no mob ou na posição do alvo no início do preparo).
@export var center: Center = Center.TARGET
## AREA/CHARGE: raio da área. Com preparo > 0 aparece uma marca vermelha no chão.
@export var radius: float = 3.0

@export_group("Dano")
## Multiplica o dano de ataque do mob.
@export var damage_mult: float = 1.0
@export var hits: int = 1
@export var knockback: float = 0.0

@export_group("Estados no alvo")
@export var stun_time: float = 0.0
@export_range(0.0, 0.9, 0.05) var slow_amount: float = 0.0
@export var slow_time: float = 0.0
## Sangramento total = dano causado x este valor, ao longo de [member bleed_time].
@export var bleed_ratio: float = 0.0
@export var bleed_time: float = 0.0
@export_range(0.0, 0.9, 0.05) var weaken_amount: float = 0.0
@export var weaken_time: float = 0.0

@export_group("Invocação")
@export var summon_mob: MobData
@export var summon_count: int = 2
@export var summon_radius: float = 6.0
## Máximo de invocados vivos desta habilidade.
@export var summon_limit: int = 4
## CALL_ALLIES (e SUMMON com [member alert_allies]): raio em que mobs do mesmo tipo entram na luta.
@export var call_radius: float = 25.0
## SUMMON: os mobs do mesmo tipo que já estão por perto também entram na luta.
@export var alert_allies: bool = true

@export_group("Reforço e cura")
@export_enum("damage", "speed", "defense") var buff_stat: String = "damage"
@export var buff_amount: float = 0.3
@export var buff_time: float = 10.0
## HEAL_SELF: fração da vida máxima recuperada.
@export_range(0.0, 1.0, 0.05) var heal_fraction: float = 0.2


func name_key() -> String:
	return "mob_ability_" + id
