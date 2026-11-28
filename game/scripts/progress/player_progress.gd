class_name PlayerProgress
extends RefCounted

# Progressão de um jogador: skills (XP por uso, nível 0-99), nível do personagem e atributos.
# Mesmas regras do offline (SkillComponent + CharacterProgression), sem nós. Servidor = verdade;
# o cliente guarda uma cópia (from_dict) só para exibir.

const MAX_SKILL := 99
const BASE_XP := 40.0
const GROWTH := [[8, 1.6], [20, 1.3], [50, 1.12], [99, 1.05]]
const ATTRIBUTES: Array[String] = ["strength", "agility", "vitality", "intelligence", "wisdom", "luck"]
const MAX_CHAR_LEVEL := 100
const POINTS_PER_LEVEL := 5
const BASE_ATTRIBUTE := 5
const BONUS_PER_POINT := 0.01
const XP_BASE := 100.0
const XP_EXPONENT := 1.6

static var _table := PackedFloat64Array()

var skills: Dictionary = {}          # id -> xp total (float)
var level := 1
var xp := 0.0
var free_points := 0
var allocated: Dictionary = {}       # atributo -> pontos
# Bônus de equipamento (preenchido pelo servidor quando o equipamento existir).
var gear_attrs: Dictionary = {}      # atributo -> bônus
var gear_stats: Dictionary = {}      # stat -> bônus (max_health, crit_chance...)
var gear_defense := 0.0


func _init() -> void:
	for a in ATTRIBUTES:
		allocated[a] = 0


# ---- tabela de skills ----

static func xp_for_level(lvl: int) -> float:
	_ensure_table()
	return _table[clampi(lvl, 0, MAX_SKILL) + 1]


static func level_for_xp(total: float) -> int:
	_ensure_table()
	var l := 0
	while l < MAX_SKILL and total >= _table[l + 2]:
		l += 1
	return l


static func _ensure_table() -> void:
	if _table.size() > 0:
		return
	_table.resize(MAX_SKILL + 2)
	var cost := BASE_XP
	var total := 0.0
	for l in range(1, MAX_SKILL + 1):
		if l > 1:
			cost *= _growth(l)
		total += cost
		_table[l + 1] = roundf(total)


static func _growth(l: int) -> float:
	for step in GROWTH:
		if l <= int(step[0]):
			return float(step[1])
	return 1.05


static func char_xp_for_next(from_level: int) -> float:
	return floorf(XP_BASE * pow(float(from_level), XP_EXPONENT))


# ---- skills ----

func skill_xp(id: String) -> float:
	return float(skills.get(id, 0.0))


func skill_level(id: String) -> int:
	return level_for_xp(skill_xp(id))


func skill_progress(id: String) -> float:
	var l := skill_level(id)
	if l >= MAX_SKILL:
		return 1.0
	var lo := xp_for_level(l)
	return clampf((skill_xp(id) - lo) / (xp_for_level(l + 1) - lo), 0.0, 1.0)


# Retorna o novo nível se subiu, senão 0.
func add_skill_xp(id: String, amount: float) -> int:
	if amount <= 0.0 or id.is_empty():
		return 0
	var old := skill_level(id)
	skills[id] = skill_xp(id) + amount
	var now := skill_level(id)
	return now if now > old else 0


# Soma dos modificadores (passivos) das perks já desbloqueadas da skill: yield_mult, quality_bonus...
func modifier(id: String, key: String) -> float:
	var l := skill_level(id)
	var sum := 0.0
	for perk in PerkDb.perks_of(id):
		if int(perk["level"]) <= l:
			sum += float(perk["mods"].get(key, 0.0))
	return sum


# ---- personagem ----

func attribute(attr: String) -> int:
	return BASE_ATTRIBUTE + int(allocated.get(attr, 0))


func attribute_mult(attr: String) -> float:
	return 1.0 + float(attribute(attr) - BASE_ATTRIBUTE) * BONUS_PER_POINT


# Retorna true se subiu de nível.
func add_char_xp(amount: float) -> bool:
	if amount <= 0.0 or level >= MAX_CHAR_LEVEL:
		return false
	xp += amount
	var leveled := false
	while level < MAX_CHAR_LEVEL and xp >= char_xp_for_next(level):
		xp -= char_xp_for_next(level)
		level += 1
		free_points += POINTS_PER_LEVEL
		leveled = true
	if level >= MAX_CHAR_LEVEL:
		xp = 0.0
	return leveled


func spend_point(attr: String) -> bool:
	if not ATTRIBUTES.has(attr) or free_points < 1:
		return false
	allocated[attr] = int(allocated[attr]) + 1
	free_points -= 1
	return true


func reset_points() -> void:
	for a in ATTRIBUTES:
		free_points += int(allocated[a])
		allocated[a] = 0


# ---- rede / save ----

func to_dict() -> Dictionary:
	var s := {}
	for id in skills:
		s[id] = snappedf(skills[id], 0.1)
	return {"skills": s, "level": level, "xp": snappedf(xp, 0.1), "free": free_points, "alloc": allocated.duplicate(),
		"gattr": gear_attrs.duplicate(), "gstat": gear_stats.duplicate(), "gdef": gear_defense}


func from_dict(d: Dictionary) -> void:
	skills = d.get("skills", {}).duplicate()
	level = int(d.get("level", 1))
	xp = float(d.get("xp", 0.0))
	free_points = int(d.get("free", 0))
	gear_attrs = d.get("gattr", {}).duplicate()
	gear_stats = d.get("gstat", {}).duplicate()
	gear_defense = float(d.get("gdef", 0.0))
	var a: Dictionary = d.get("alloc", {})
	for k in ATTRIBUTES:
		allocated[k] = int(a.get(k, 0))
