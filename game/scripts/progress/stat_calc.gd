class_name StatCalc
extends RefCounted

# Status finais = base + atributos + equipamento (mesmas fórmulas do StatsComponent offline).
# Puro: servidor e cliente chamam com o mesmo PlayerProgress. compute(p, false) ignora o equipamento,
# então "(+x)" na UI = compute(p, true) - compute(p, false).

const BASE_HEALTH := 100.0
const HEALTH_PER_VIT := 8.0
const BASE_STAMINA := 100.0
const STAMINA_PER_VIT := 4.0
const BASE_SLOTS := 36
const STR_PER_SLOT := 2.0
const DAMAGE_PER_POINT := 0.02
const ATTACK_SPEED_PER_AGI := 0.015
const DODGE_PER_AGI := 0.005
const MOVE_PER_AGI := 0.005
const XP_PER_WIS := 0.01
const BASE_CRIT := 0.05
const CRIT_PER_LUCK := 0.005
const DROP_PER_LUCK := 0.01

const ATTR_NAMES := {"strength": "Força", "agility": "Agilidade", "vitality": "Vitalidade",
	"intelligence": "Inteligência", "wisdom": "Sabedoria", "luck": "Sorte"}

# [chave, rótulo, formato] — formato: int, mult (x1.00), pct (0.0%)
const ROWS := [
	["max_health", "Vida máxima", "int"],
	["max_stamina", "Energia máxima", "int"],
	["defense", "Defesa", "int"],
	["damage_mult", "Dano", "mult"],
	["attack_speed", "Vel. de ataque", "mult"],
	["dodge_chance", "Esquiva", "pct"],
	["crit_chance", "Crítico", "pct"],
	["move_speed", "Vel. de movimento", "mult"],
	["inventory_slots", "Espaços de inventário", "int"],
	["xp_mult", "Ganho de XP", "mult"],
	["drop_luck", "Sorte de drops", "mult"],
]


static func attr_total(p: PlayerProgress, attr: String, gear := true) -> int:
	return p.attribute(attr) + (int(p.gear_attrs.get(attr, 0)) if gear else 0)


static func compute(p: PlayerProgress, gear := true) -> Dictionary:
	var d := func(a: String) -> float: return float(attr_total(p, a, gear) - PlayerProgress.BASE_ATTRIBUTE)
	var x := func(k: String) -> float: return float(p.gear_stats.get(k, 0.0)) if gear else 0.0
	var v := {}
	v["max_health"] = BASE_HEALTH + HEALTH_PER_VIT * d.call("vitality") + x.call("max_health")
	v["max_stamina"] = BASE_STAMINA + STAMINA_PER_VIT * d.call("vitality") + x.call("max_stamina")
	v["inventory_slots"] = clampf(floorf(BASE_SLOTS + d.call("strength") / STR_PER_SLOT + x.call("inventory_slots")), 20.0, 60.0)
	v["defense"] = (p.gear_defense if gear else 0.0) + x.call("defense")
	v["damage_mult"] = 1.0 + DAMAGE_PER_POINT * d.call("strength") + x.call("damage_mult") / 100.0
	v["move_speed"] = maxf(0.3, 1.0 + MOVE_PER_AGI * d.call("agility") + x.call("move_speed") / 100.0)
	v["attack_speed"] = maxf(0.3, 1.0 + ATTACK_SPEED_PER_AGI * d.call("agility"))
	v["dodge_chance"] = clampf(DODGE_PER_AGI * d.call("agility") + x.call("dodge_chance") / 100.0, 0.0, 0.4)
	v["crit_chance"] = clampf(BASE_CRIT + CRIT_PER_LUCK * d.call("luck") + x.call("crit_chance") / 100.0, 0.0, 1.0)
	v["xp_mult"] = 1.0 + XP_PER_WIS * d.call("wisdom")
	v["drop_luck"] = 1.0 + DROP_PER_LUCK * d.call("luck")
	return v


static func fmt(value: float, kind: String, signed := false) -> String:
	var sign_s := "+" if signed and value >= 0.0 else ""
	match kind:
		"mult":
			return "%s%s%.2f" % ["" if signed else "x", sign_s, value]
		"pct":
			return "%s%.1f%%" % [sign_s, value * 100.0]
	return "%s%d" % [sign_s, roundi(value)]
