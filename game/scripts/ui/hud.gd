class_name Hud
extends Control

# HUD fixo (só cliente): status, hotbar, minimapa, rastreador de missão e chat.
# Só exibe o que recebe; nunca decide nada.

const HOTBAR_SLOTS := 5
const CHANNELS := ["Geral", "Grupo", "Guilda", "Sistema"]

var mini_sampler := Callable()   # sem minimapa: mantido só por compatibilidade

var _level := Label.new()
var _name := Label.new()
var _hp := ProgressBar.new()
var _hp_text := Label.new()
var _mp := ProgressBar.new()
var _mp_text := Label.new()
var _slots: Array[Panel] = []
var _pos := Vector3.ZERO
var _yaw := 0.0
var _quest := PanelContainer.new()
var _quest_title := Label.new()
var _quest_lines := VBoxContainer.new()
var _logs: Dictionary = {}
var _tab_btns: Dictionary = {}
var _channel := "Geral"
var _fps := Label.new()


func _init() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	theme = UiTheme.make_theme()
	_build_status()
	_build_hotbar()
	_build_quest()
	_build_chat()
	_fps.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_fps.offset_top = 6
	_fps.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_fps.add_theme_color_override("font_outline_color", Color.BLACK)
	_fps.add_theme_constant_override("outline_size", 4)
	add_child(_fps)


# ------------------------------- API -------------------------------

func set_identity(player_name: String, level: int) -> void:
	_name.text = player_name
	_level.text = str(level)


func set_stats(hp: float, hp_max: float, en: float, en_max: float) -> void:
	_set_bar(_hp, _hp_text, hp, hp_max)
	_set_bar(_mp, _mp_text, en, en_max)


func set_player(pos: Vector3, yaw: float) -> void:
	_pos = pos
	_yaw = yaw


# Item de atalho: id do item ("" limpa o slot).
func set_hotbar_item(i: int, item_id: String) -> void:
	if i < 0 or i >= _slots.size():
		return
	var slot := _slots[i]
	var old := slot.get_node_or_null("item")
	if old != null:
		slot.remove_child(old)
		old.queue_free()
	if item_id.is_empty():
		return
	var item := ItemRegistry.get_item(item_id)
	var c: Control
	if item != null and item.icon != null:
		var tex := TextureRect.new()
		tex.texture = item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.offset_left = 6
		tex.offset_top = 6
		tex.offset_right = -6
		tex.offset_bottom = -6
		c = tex
	else:
		var l := Label.new()
		l.text = ItemRegistry.display_name(item_id)
		l.add_theme_font_size_override("font_size", 11)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		c = l
	c.name = "item"
	c.set_anchors_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	slot.add_child(c)


# Rastreador de missão. title vazio esconde.
func set_quest(title: String, lines: Array = []) -> void:
	_quest.visible = not title.is_empty()
	_quest_title.text = title
	for c in _quest_lines.get_children():
		_quest_lines.remove_child(c)
		c.queue_free()
	for line in lines:
		var l := Label.new()
		l.text = "◆ " + str(line)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		l.custom_minimum_size = Vector2(220, 0)
		_quest_lines.add_child(l)


func add_chat(channel: String, text: String) -> void:
	var log_: RichTextLabel = _logs.get(channel)
	if log_ == null:
		return
	log_.append_text(text + "\n")


# ------------------------------ status ------------------------------

func _build_status() -> void:
	var plate := PanelContainer.new()
	plate.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plate.position = Vector2(14, 12)
	add_child(plate)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	plate.add_child(row)

	var badge := PanelContainer.new()
	var bsb := UiTheme.box(Color(0.02, 0.05, 0.11), UiTheme.GOLD, 2, 32)
	bsb.set_content_margin_all(0)
	badge.add_theme_stylebox_override("panel", bsb)
	badge.custom_minimum_size = Vector2(60, 60)
	badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_child(badge)
	_level.text = "1"
	_level.add_theme_font_override("font", UiTheme.title_font())
	_level.add_theme_font_size_override("font_size", 28)
	_level.add_theme_color_override("font_color", UiTheme.GOLD)
	_level.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_level.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	badge.add_child(_level)

	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 3)
	row.add_child(col)
	_name.add_theme_font_override("font", UiTheme.title_font())
	_name.add_theme_font_size_override("font_size", 17)
	col.add_child(_name)
	col.add_child(_make_bar(_hp, _hp_text, UiTheme.HP))
	col.add_child(_make_bar(_mp, _mp_text, UiTheme.MP))
	set_stats(100, 100, 100, 100)


func _make_bar(bar: ProgressBar, text: Label, color: Color) -> Control:
	bar.show_percentage = false
	bar.custom_minimum_size = Vector2(240, 20)
	bar.add_theme_stylebox_override("fill", UiTheme.bar_style(color))
	bar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.set_anchors_preset(Control.PRESET_FULL_RECT)
	text.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", 12)
	text.add_theme_color_override("font_outline_color", Color.BLACK)
	text.add_theme_constant_override("outline_size", 4)
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	bar.add_child(text)
	return bar


func _set_bar(bar: ProgressBar, text: Label, v: float, v_max: float) -> void:
	bar.max_value = maxf(v_max, 1.0)
	bar.value = clampf(v, 0.0, bar.max_value)
	text.text = "%d / %d" % [roundi(v), roundi(v_max)]


# ------------------------------ hotbar ------------------------------

func _build_hotbar() -> void:
	var holder := PanelContainer.new()
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	holder.grow_horizontal = Control.GROW_DIRECTION_BOTH
	holder.grow_vertical = Control.GROW_DIRECTION_BEGIN
	holder.offset_bottom = -10
	add_child(holder)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	holder.add_child(row)
	for i in HOTBAR_SLOTS:
		var s := Panel.new()
		s.custom_minimum_size = Vector2(62, 62)
		s.mouse_filter = Control.MOUSE_FILTER_IGNORE
		s.add_theme_stylebox_override("panel", UiTheme.slot_box(UiTheme.BORDER))
		var n := Label.new()
		n.text = str(i + 1)
		n.position = Vector2(5, 2)
		n.add_theme_font_size_override("font_size", 13)
		n.add_theme_color_override("font_color", UiTheme.GOLD)
		n.mouse_filter = Control.MOUSE_FILTER_IGNORE
		n.z_index = 1
		s.add_child(n)
		row.add_child(s)
		_slots.append(s)


func _process(_delta: float) -> void:
	_fps.visible = bool(Settings.get_value("show_fps"))
	if _fps.visible:
		_fps.text = "%d FPS" % Engine.get_frames_per_second()


# ------------------------------ missão ------------------------------

func _build_quest() -> void:
	_quest.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_quest.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_quest.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	_quest.offset_right = -16
	_quest.offset_top = 14
	_quest.visible = false
	add_child(_quest)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	_quest.add_child(col)
	_quest_title.add_theme_font_override("font", UiTheme.title_font())
	_quest_title.add_theme_font_size_override("font_size", 16)
	_quest_title.add_theme_color_override("font_color", UiTheme.GOLD)
	col.add_child(_quest_title)
	col.add_child(_quest_lines)


# ------------------------------- chat -------------------------------

func _build_chat() -> void:
	var box := PanelContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN
	box.offset_left = 14
	box.offset_bottom = -14
	box.custom_minimum_size = Vector2(380, 190)
	add_child(box)
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 6)
	box.add_child(col)

	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	col.add_child(tabs)
	var stack := Control.new()
	stack.size_flags_vertical = Control.SIZE_EXPAND_FILL
	stack.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(stack)

	for ch in CHANNELS:
		var b := Button.new()
		b.text = ch
		b.toggle_mode = true
		b.focus_mode = Control.FOCUS_NONE
		b.add_theme_font_size_override("font_size", 12)
		b.pressed.connect(_select_channel.bind(ch))
		tabs.add_child(b)
		_tab_btns[ch] = b
		var rt := RichTextLabel.new()
		rt.bbcode_enabled = false
		rt.scroll_following = true
		rt.set_anchors_preset(Control.PRESET_FULL_RECT)
		rt.mouse_filter = Control.MOUSE_FILTER_IGNORE
		rt.visible = false
		stack.add_child(rt)
		_logs[ch] = rt

	var input := LineEdit.new()
	input.placeholder_text = "Chat em breve"
	input.editable = false
	input.focus_mode = Control.FOCUS_NONE
	input.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_child(input)
	_select_channel("Geral")


func _select_channel(ch: String) -> void:
	_channel = ch
	for k in _logs:
		_logs[k].visible = (k == ch)
		_tab_btns[k].button_pressed = (k == ch)
