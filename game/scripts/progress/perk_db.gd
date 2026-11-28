class_name PerkDb
extends RefCounted

# Lê as perks (SkillPerk .tres) de res://resources/skills/<grupo>/. A skill de cada perk vem do
# próprio recurso; o grupo (pasta) separa "vida" de "combate" na janela de skills.

const ROOT := "res://resources/skills"

static var _loaded := false
static var _by_skill: Dictionary = {}   # id -> [{level, mods, kind, title}] ordenado por nível
static var _group: Dictionary = {}      # id -> nome da pasta


static func perks_of(skill: String) -> Array:
	_ensure()
	return _by_skill.get(skill, [])


static func skills_in(group: String) -> Array:
	_ensure()
	var out: Array = []
	for id in _group:
		if _group[id] == group:
			out.append(id)
	out.sort()
	return out


static func groups() -> Array:
	_ensure()
	var out: Array = []
	for g in _group.values():
		if not out.has(g):
			out.append(g)
	out.sort()
	return out


static func skill_name(id: String) -> String:
	var k := "skill_" + id
	var t := TranslationServer.translate(k)
	return id.capitalize() if t == k else t


static func _ensure() -> void:
	if _loaded:
		return
	_loaded = true
	var dir := DirAccess.open(ROOT)
	if dir == null:
		return
	for g in dir.get_directories():
		_scan(ROOT.path_join(g), g)
	for id in _by_skill:
		_by_skill[id].sort_custom(func(a, b): return a["level"] < b["level"])
	print("[skills] %d skills, %d perks" % [_by_skill.size(), _count()])


static func _count() -> int:
	var n := 0
	for id in _by_skill:
		n += _by_skill[id].size()
	return n


static func _scan(path: String, group: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for f in dir.get_files():
		var name := f.trim_suffix(".remap")
		if not (name.ends_with(".tres") or name.ends_with(".res")):
			continue
		var perk := load(path.path_join(name)) as SkillPerk
		if perk == null or perk.skill.is_empty():
			continue
		if not _by_skill.has(perk.skill):
			_by_skill[perk.skill] = []
			_group[perk.skill] = group
		_by_skill[perk.skill].append({"level": perk.level, "mods": perk.modifiers.duplicate(), "kind": perk.kind})


# "+5% rendimento de coleta, +2 de qualidade" a partir dos modificadores.
static func describe(mods: Dictionary) -> String:
	var parts: PackedStringArray = []
	for key in mods:
		var v := float(mods[key])
		var k := "perk_mod_" + str(key)
		var label := TranslationServer.translate(k)
		if label == k:
			label = str(key).replace("_", " ")
		var pct := str(key).ends_with("_mult") or str(key).ends_with("_chance")
		var num := v * 100.0 if pct else v
		var txt := str(roundi(num)) if is_equal_approx(num, roundf(num)) else "%.1f" % num
		parts.append("+%s%s %s" % [txt, "%" if pct else "", label])
	return ", ".join(parts)
