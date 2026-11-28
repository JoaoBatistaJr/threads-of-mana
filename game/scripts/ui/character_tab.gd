class_name CharacterTab
extends HBoxContainer

# Aba Personagem: à esquerda atributos e pontos livres; à direita nível, XP e status somados.
# "(+n)" em verde = bônus de equipamento. Pedidos de gastar/redistribuir vão ao servidor.

signal spend(attr: String)
signal reset

const GREEN := Color(0.45, 0.85, 0.45)
const ATTR_COLORS := {"strength": Color(0.85, 0.25, 0.25), "agility": Color(0.4, 0.8, 0.4), "vitality": Color(0.9, 0.3, 0.45),
	"intelligence": Color(0.3, 0.6, 0.95), "wisdom": Color(0.65, 0.4, 0.9), "luck": Color(0.3, 0.8, 0.5)}

var _left := VBoxContainer.new()
var _right := VBoxContainer.new()


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var lp := _panel(_left, 340)
	add_child(lp)
	var rp := _panel(_right, 0)
	rp.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(rp)
	show_progress(PlayerProgress.new())


func _panel(inner: Control, min_w: int) -> PanelContainer:
	var pc := PanelContainer.new()
	pc.custom_minimum_size = Vector2(min_w, 0)
	pc.add_theme_stylebox_override("panel", UiTheme.inner_panel(14))
	inner.add_theme_constant_override("separation", 6)
	pc.add_child(inner)
	return pc


func _clear(box: Control) -> void:
	for c in box.get_children():
		box.remove_child(c)
		c.queue_free()


func _title(text: String, size := 20) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_override("font", UiTheme.title_font())
	l.add_theme_font_size_override("font_size", size)
	return l


func _bonus(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_color_override("font_color", GREEN)
	return l


func show_progress(p: PlayerProgress) -> void:
	_clear(_left)
	_clear(_right)
	# --- esquerda: atributos
	_left.add_child(UiTheme.section_title("Atributos"))
	var free := Label.new()
	free.text = "Pontos livres: %d" % p.free_points
	free.add_theme_color_override("font_color", UiTheme.GOLD if p.free_points > 0 else UiTheme.MUTED)
	_left.add_child(free)
	for a in PlayerProgress.ATTRIBUTES:
		var slot := PanelContainer.new()
		slot.add_theme_stylebox_override("panel", UiTheme.slot_box())
		slot.custom_minimum_size = Vector2(0, 46)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		slot.add_child(row)
		var ic := ColorRect.new()
		ic.color = ATTR_COLORS[a]
		ic.custom_minimum_size = Vector2(26, 26)
		ic.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(ic)
		var n := Label.new()
		n.text = StatCalc.ATTR_NAMES[a]
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var v := Label.new()
		v.text = str(p.attribute(a))
		v.add_theme_color_override("font_color", UiTheme.GOLD)
		v.add_theme_font_size_override("font_size", 18)
		row.add_child(v)
		var gb := int(p.gear_attrs.get(a, 0))
		if gb != 0:
			row.add_child(_bonus("(%s%d)" % ["+" if gb > 0 else "", gb]))
		var b := Button.new()
		b.text = "+"
		b.focus_mode = Control.FOCUS_NONE
		b.disabled = p.free_points < 1
		b.pressed.connect(func(): spend.emit(a))
		row.add_child(b)
		_left.add_child(slot)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_left.add_child(spacer)
	var rb := Button.new()
	rb.text = "Redistribuir pontos"
	rb.focus_mode = Control.FOCUS_NONE
	rb.pressed.connect(func(): reset.emit())
	_left.add_child(rb)

	# --- direita: nível, XP e status
	_right.add_child(UiTheme.section_title("Personagem"))
	var lv := Label.new()
	lv.text = "Nível %d" % p.level
	lv.add_theme_font_override("font", UiTheme.title_font())
	lv.add_theme_font_size_override("font_size", 30)
	lv.add_theme_color_override("font_color", UiTheme.GOLD)
	_right.add_child(lv)
	var need := PlayerProgress.char_xp_for_next(p.level)
	var bar := ProgressBar.new()
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(0, 14)
	bar.max_value = 1.0
	bar.value = clampf(p.xp / need, 0.0, 1.0) if p.level < PlayerProgress.MAX_CHAR_LEVEL else 1.0
	_right.add_child(bar)
	var xp := Label.new()
	xp.text = "%d / %d XP" % [roundi(p.xp), roundi(need)] if p.level < PlayerProgress.MAX_CHAR_LEVEL else "Nível máximo"
	xp.add_theme_color_override("font_color", UiTheme.MUTED)
	_right.add_child(xp)
	_right.add_child(UiTheme.section_title("Status", 17))
	var total := StatCalc.compute(p, true)
	var base := StatCalc.compute(p, false)
	for r in StatCalc.ROWS:
		var key: String = r[0]
		var row := HBoxContainer.new()
		var n := Label.new()
		n.text = r[1]
		n.add_theme_color_override("font_color", UiTheme.MUTED)
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(n)
		var diff: float = total[key] - base[key]
		var val := Label.new()
		val.text = StatCalc.fmt(total[key], r[2])
		row.add_child(val)
		if absf(diff) > 0.0001:
			row.add_child(_bonus(" (%s)" % StatCalc.fmt(diff, r[2], true)))
		_right.add_child(row)
