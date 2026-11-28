class_name SkillsTab
extends HBoxContainer

# Aba Habilidades: categorias à esquerda; à direita as skills da categoria com nível, XP e perks (dica).

const GATHERING := ["woodcutting", "mining", "harvesting", "tilling"]
const CATEGORIES := ["Coleta", "Ofícios", "Combate"]

var _cats := VBoxContainer.new()
var _list := VBoxContainer.new()
var _group := "Coleta"
var _prog := PlayerProgress.new()


func _init() -> void:
	add_theme_constant_override("separation", 10)
	_cats.custom_minimum_size = Vector2(170, 0)
	_cats.add_theme_constant_override("separation", 6)
	add_child(_cats)
	for g in CATEGORIES:
		var b := Button.new()
		b.text = g
		UiTheme.style_tab(b, 17)
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.pressed.connect(func(): _pick(g))
		_cats.add_child(b)
	var pc := PanelContainer.new()
	pc.add_theme_stylebox_override("panel", UiTheme.inner_panel(14))
	pc.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(pc)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	pc.add_child(scroll)
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_list.add_theme_constant_override("separation", 8)
	scroll.add_child(_list)
	_rebuild()


static func category_of(id: String) -> String:
	if GATHERING.has(id):
		return "Coleta"
	return "Combate" if PerkDb.skills_in("combat").has(id) else "Ofícios"


func show_progress(p: PlayerProgress) -> void:
	_prog = p
	_rebuild()


func _pick(g: String) -> void:
	_group = g
	_rebuild()


func _rebuild() -> void:
	for b in _cats.get_children():
		(b as Button).button_pressed = b.text == _group
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	_list.add_child(UiTheme.section_title(_group))
	for g in PerkDb.groups():
		for id in PerkDb.skills_in(g):
			if category_of(id) == _group:
				_list.add_child(_row(id))


func _row(id: String) -> Control:
	var lvl := _prog.skill_level(id)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	var top := HBoxContainer.new()
	var n := Label.new()
	n.text = PerkDb.skill_name(id)
	n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	top.add_child(n)
	var lv := Label.new()
	lv.text = "Nv %d" % lvl
	lv.add_theme_color_override("font_color", UiTheme.GOLD)
	top.add_child(lv)
	box.add_child(top)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 12)
	bar.max_value = 1.0
	bar.value = _prog.skill_progress(id)
	box.add_child(bar)
	var sub := Label.new()
	sub.add_theme_font_size_override("font_size", 11)
	sub.add_theme_color_override("font_color", UiTheme.MUTED)
	sub.text = "%d / %d XP" % [roundi(_prog.skill_xp(id)), roundi(PlayerProgress.xp_for_level(lvl + 1))] if lvl < PlayerProgress.MAX_SKILL else "Nível máximo"
	box.add_child(sub)
	var lines: PackedStringArray = [PerkDb.skill_name(id)]
	for perk in PerkDb.perks_of(id):
		lines.append("%s Nv %d: %s" % ["✔" if lvl >= int(perk["level"]) else "·", perk["level"], PerkDb.describe(perk["mods"])])
	box.tooltip_text = "\n".join(lines)
	box.mouse_filter = Control.MOUSE_FILTER_PASS
	return box
