class_name MainMenu
extends Control

# Tela inicial: 3 slots de personagem (nome). Criar, jogar e apagar.
# Emite play_requested(nome); quem conecta ao servidor é o main.gd.

signal play_requested(player_name: String)

const BG := Color("#0b1424")
const PANEL := Color("#17305a")
const PANEL_DARK := Color("#101c30")
const ACCENT := Color("#7b2d30")
const ACCENT_HOVER := Color("#8f383b")
const SECONDARY := Color("#28456f")
const TEXT := Color("#e9f1fa")
const MUTED := Color("#8fa6c1")
const DANGER := Color("#d98a8a")

var _slots: Array = []
var _row: HBoxContainer
var _status: Label
var _overlay: Control
var _overlay_title: Label
var _name_edit: LineEdit
var _error: Label
var _creating_slot := -1
var _delete_armed := -1
var _message := ""


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = _make_theme()
	_slots = CharacterStore.load_slots()

	var bg := ColorRect.new()
	bg.color = BG
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.alignment = BoxContainer.ALIGNMENT_CENTER
	root.add_theme_constant_override("separation", 28)
	add_child(root)

	var title := Label.new()
	title.text = "Threads of Mana"
	title.add_theme_font_size_override("font_size", 56)
	title.add_theme_color_override("font_color", TEXT)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(title)

	var sub := Label.new()
	sub.text = "Escolha seu personagem"
	sub.add_theme_color_override("font_color", MUTED)
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(sub)

	_row = HBoxContainer.new()
	_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_row.add_theme_constant_override("separation", 20)
	root.add_child(_row)

	_status = Label.new()
	_status.add_theme_color_override("font_color", MUTED)
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	root.add_child(_status)

	_status.text = _message
	_build_overlay()
	_refresh()


func set_message(text: String) -> void:
	_message = text
	if _status:
		_status.text = text


func _input(event: InputEvent) -> void:
	if _overlay.visible and event.is_action_pressed("ui_cancel"):
		_close_overlay()
		get_viewport().set_input_as_handled()


# ============================ SLOTS ============================

func _refresh() -> void:
	for c in _row.get_children():
		c.queue_free()
	for i in Const.SLOT_COUNT:
		_row.add_child(_make_card(i))


func _make_card(i: int) -> Control:
	var char_name: String = _slots[i]
	var filled := char_name != ""

	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(240, 320)
	card.add_theme_stylebox_override("panel", _box(PANEL_DARK, 12, 2, PANEL))

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 16)
	card.add_child(margin)

	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	var head := Label.new()
	head.text = "SLOT %d" % (i + 1)
	head.add_theme_color_override("font_color", MUTED)
	head.add_theme_font_size_override("font_size", 14)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	v.add_child(head)

	# silhueta de cápsula (cor derivada do nome)
	var cap_holder := CenterContainer.new()
	cap_holder.size_flags_vertical = Control.SIZE_EXPAND_FILL
	v.add_child(cap_holder)
	var cap := Panel.new()
	cap.custom_minimum_size = Vector2(64, 120)
	var cap_color := Color.from_hsv(float(char_name.hash() % 360) / 360.0, 0.65, 0.95) if filled \
		else Color(1, 1, 1, 0.06)
	cap.add_theme_stylebox_override("panel", _box(cap_color, 32, 0, cap_color))
	cap_holder.add_child(cap)

	var name_label := Label.new()
	name_label.text = char_name if filled else "Vazio"
	name_label.add_theme_font_size_override("font_size", 22)
	name_label.add_theme_color_override("font_color", TEXT if filled else MUTED)
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_label.clip_text = true
	v.add_child(name_label)

	if filled:
		var play := _button("Jogar", true)
		play.pressed.connect(_on_play.bind(i))
		v.add_child(play)
		var del := _button("Confirmar?" if _delete_armed == i else "Apagar", false)
		del.pressed.connect(_on_delete.bind(i))
		v.add_child(del)
	else:
		var create := _button("Criar personagem", true)
		create.pressed.connect(_open_overlay.bind(i))
		v.add_child(create)
		var spacer := Control.new() # mantém a altura igual à dos slots preenchidos
		spacer.custom_minimum_size.y = 40
		v.add_child(spacer)
	return card


func _on_play(i: int) -> void:
	set_message("Conectando...")
	play_requested.emit(_slots[i])


func _on_delete(i: int) -> void:
	if _delete_armed != i:
		_delete_armed = i   # primeiro clique arma, segundo confirma
		_refresh()
		return
	_delete_armed = -1
	_slots[i] = ""
	CharacterStore.save_slots(_slots)
	_refresh()


# ============================ CRIAÇÃO ============================

func _build_overlay() -> void:
	_overlay = Control.new()
	_overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.visible = false
	add_child(_overlay)

	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.65)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(dim)   # bloqueia cliques no fundo

	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_overlay.add_child(center)

	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", _box(PANEL, 12, 2, SECONDARY))
	center.add_child(panel)

	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)

	var v := VBoxContainer.new()
	v.custom_minimum_size.x = 340
	v.add_theme_constant_override("separation", 12)
	margin.add_child(v)

	_overlay_title = Label.new()
	_overlay_title.add_theme_font_size_override("font_size", 24)
	v.add_child(_overlay_title)

	_name_edit = LineEdit.new()
	_name_edit.placeholder_text = "Nome (%d a %d caracteres)" % [Const.NAME_MIN, Const.NAME_MAX]
	_name_edit.max_length = Const.NAME_MAX
	_name_edit.text_submitted.connect(func(_t): _confirm_create())
	v.add_child(_name_edit)

	_error = Label.new()
	_error.add_theme_color_override("font_color", DANGER)
	_error.add_theme_font_size_override("font_size", 14)
	_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(_error)

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 10)
	v.add_child(buttons)
	var ok := _button("Criar", true)
	ok.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	ok.pressed.connect(_confirm_create)
	buttons.add_child(ok)
	var cancel := _button("Cancelar", false)
	cancel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	cancel.pressed.connect(_close_overlay)
	buttons.add_child(cancel)


func _open_overlay(slot: int) -> void:
	_creating_slot = slot
	_delete_armed = -1
	_overlay_title.text = "Novo personagem — Slot %d" % (slot + 1)
	_name_edit.text = ""
	_error.text = ""
	_overlay.visible = true
	_name_edit.grab_focus()


func _close_overlay() -> void:
	_overlay.visible = false
	_creating_slot = -1


func _confirm_create() -> void:
	var n := CharacterStore.clean(_name_edit.text)
	if n == "":
		_error.text = "Nome inválido: use %d a %d caracteres (letras, números, espaço, - e _)." % [
			Const.NAME_MIN, Const.NAME_MAX]
		return
	for s in _slots:
		if str(s).to_lower() == n.to_lower():
			_error.text = "Você já tem um personagem com esse nome."
			return
	_slots[_creating_slot] = n
	CharacterStore.save_slots(_slots)
	_close_overlay()
	_refresh()


# ============================ ESTILO ============================

func _box(color: Color, radius: int, border: int, border_color: Color) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = color
	sb.set_corner_radius_all(radius)
	sb.set_border_width_all(border)
	sb.border_color = border_color
	return sb


func _button(text: String, primary: bool) -> Button:
	var b := Button.new()
	b.text = text
	b.custom_minimum_size.y = 40
	var base := ACCENT if primary else SECONDARY
	b.add_theme_stylebox_override("normal", _box(base, 8, 0, base))
	b.add_theme_stylebox_override("hover", _box(base.lightened(0.15), 8, 0, base))
	b.add_theme_stylebox_override("pressed", _box(base.darkened(0.2), 8, 0, base))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", TEXT)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	return b


func _make_theme() -> Theme:
	var t := Theme.new()
	t.default_font_size = 18
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("normal", "LineEdit", _box(Color("#060b14"), 6, 1, Color("#2a4166")))
	t.set_stylebox("focus", "LineEdit", _box(Color("#060b14"), 6, 2, Color("#8fb8d9")))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)
	return t
