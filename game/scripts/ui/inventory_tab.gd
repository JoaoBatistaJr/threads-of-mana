class_name InventoryTab
extends HBoxContainer

# Aba Inventário (só cliente): à esquerda o equipamento (slots do offline; o servidor ainda não
# equipa nada), à direita os itens com filtros e rodapé. Só exibe; quem muda é o servidor.

const COLUMNS := 8
const SLOT := Vector2(58, 58)
const FILTERS := [["all", "Todos"], ["materials", "Materiais"], ["tools", "Ferramentas"], ["gear", "Equipamento"], ["consumables", "Consumíveis"]]
const COL_LEFT := [["back", "Capa"], ["chest", "Peito"], ["legs", "Calças"], ["feet", "Botas"]]
const COL_RIGHT := [["mount", "Montaria"], ["main_hand", "Arma"], ["off_hand", "Escudo"], ["hands", "Luvas"]]
const BOTTOM := [["bracelet_1", "Brac. 1"], ["bracelet_2", "Brac. 2"], ["neck", "Colar"], ["waist", "Cinto"]]
const SMALL := ["Anel", "Anel", "Anel", "Anel", "Anel", "Brinco", "Brinco"]

var _grid := GridContainer.new()
var _filter := "all"
var _filter_btns: Dictionary = {}
var _rows: Array = []
var _bar := ProgressBar.new()
var _bar_text := Label.new()
var _coins := Label.new()


func _init() -> void:
	add_theme_constant_override("separation", 10)
	var left := PanelContainer.new()
	left.add_theme_stylebox_override("panel", UiTheme.inner_panel(12))
	left.add_child(_build_equipment())
	add_child(left)

	var right := PanelContainer.new()
	right.add_theme_stylebox_override("panel", UiTheme.inner_panel(12))
	right.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	add_child(right)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	right.add_child(box)
	box.add_child(UiTheme.section_title("Inventário"))
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	for f in FILTERS:
		var b := Button.new()
		b.text = f[1]
		UiTheme.style_tab(b, 13)
		b.pressed.connect(_set_filter.bind(f[0]))
		tabs.add_child(b)
		_filter_btns[f[0]] = b
	box.add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 5)
	_grid.add_theme_constant_override("v_separation", 5)
	scroll.add_child(_grid)
	box.add_child(_build_footer())
	_set_filter("all")


func _build_equipment() -> Control:
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 6)
	root.add_child(UiTheme.section_title("Equipamento"))
	var area := Control.new()
	area.custom_minimum_size = Vector2(330, 388)
	root.add_child(area)
	var figure := EquipFigure.new()
	figure.position = Vector2(72, 40)
	figure.size = Vector2(186, 250)
	area.add_child(figure)
	area.add_child(_eq_slot("Elmo", Vector2(137, 0), 54))
	for i in COL_LEFT.size():
		area.add_child(_eq_slot(COL_LEFT[i][1], Vector2(4, 50 + i * 66), 54))
		area.add_child(_eq_slot(COL_RIGHT[i][1], Vector2(272, 50 + i * 66), 54))
	for i in SMALL.size():
		area.add_child(_eq_slot(SMALL[i], Vector2(16 + i * 44, 306), 38))
	for i in BOTTOM.size():
		area.add_child(_eq_slot(BOTTOM[i][1], Vector2(10 + i * 78, 344), 42))
	return root


func _eq_slot(label: String, pos: Vector2, s: float) -> Control:
	var p := Panel.new()
	p.position = pos
	p.size = Vector2(s, s)
	p.add_theme_stylebox_override("panel", UiTheme.slot_box())
	p.tooltip_text = label
	var l := Label.new()
	l.text = label
	l.add_theme_font_size_override("font_size", 10)
	l.add_theme_color_override("font_color", UiTheme.MUTED)
	l.set_anchors_preset(Control.PRESET_FULL_RECT)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	p.add_child(l)
	return p


func _build_footer() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	_bar.show_percentage = false
	_bar.custom_minimum_size = Vector2(0, 12)
	_bar.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_bar.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	_bar_text.add_theme_font_size_override("font_size", 13)
	row.add_child(_bar_text)
	row.add_child(_bar)
	var coin := Label.new()
	coin.text = "●"
	coin.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(coin)
	_coins.text = "0"
	_coins.add_theme_color_override("font_color", UiTheme.GOLD)
	row.add_child(_coins)
	return row


func _set_filter(f: String) -> void:
	_filter = f
	for k in _filter_btns:
		_filter_btns[k].button_pressed = k == f
	_rebuild()


func show_rows(rows: Array) -> void:
	_rows = rows
	_bar.max_value = Const.INVENTORY_SLOTS
	_bar.value = rows.size()
	_bar_text.text = "%d / %d" % [rows.size(), Const.INVENTORY_SLOTS]
	_rebuild()


func _rebuild() -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	var shown := 0
	for r in _rows:
		var item := ItemRegistry.get_item(r[1])
		if _filter == "all" or (item != null and item.category == _filter):
			_grid.add_child(_make_slot(r))
			shown += 1
	for i in maxi(Const.INVENTORY_SLOTS - shown, 0):
		_grid.add_child(_make_slot(null))


func _make_slot(row: Variant) -> Control:
	var slot := Panel.new()
	slot.custom_minimum_size = SLOT
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.1, 0.12, 0.17, 0.9)
	sb.set_border_width_all(2)
	sb.set_corner_radius_all(4)
	sb.border_color = Color(0.25, 0.28, 0.36)
	slot.add_theme_stylebox_override("panel", sb)
	if row == null:
		return slot
	var id: String = row[1]
	var amount := int(row[2])
	var quality := float(row[3])
	var item := ItemRegistry.get_item(id)
	if quality > 0.0:
		sb.border_color = ItemInstance.tier_color(quality)
	var tip := "%s\nQuantidade: %d" % [ItemRegistry.display_name(id), amount]
	if quality > 0.0:
		tip += "\nQualidade: %d (%s)" % [roundi(quality), tr(ItemInstance.tier_key(quality))]
	if item != null and item.description_key != "" and tr(item.description_key) != item.description_key:
		tip += "\n\n" + tr(item.description_key)
	slot.tooltip_text = tip
	if item != null and item.icon != null:
		var tex := TextureRect.new()
		tex.texture = item.icon
		tex.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tex.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		tex.set_anchors_preset(Control.PRESET_FULL_RECT)
		tex.offset_left = 4
		tex.offset_top = 4
		tex.offset_right = -4
		tex.offset_bottom = -4
		tex.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(tex)
	else:
		var name_l := Label.new()
		name_l.text = ItemRegistry.display_name(id)
		name_l.add_theme_font_size_override("font_size", 11)
		name_l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		name_l.set_anchors_preset(Control.PRESET_FULL_RECT)
		name_l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		name_l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		name_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(name_l)
	if amount > 1:
		var qty := Label.new()
		qty.text = str(amount)
		qty.add_theme_font_size_override("font_size", 13)
		qty.add_theme_color_override("font_outline_color", Color.BLACK)
		qty.add_theme_constant_override("outline_size", 4)
		qty.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
		qty.grow_horizontal = Control.GROW_DIRECTION_BEGIN
		qty.grow_vertical = Control.GROW_DIRECTION_BEGIN
		qty.offset_right = -4
		qty.offset_bottom = -2
		qty.mouse_filter = Control.MOUSE_FILTER_IGNORE
		slot.add_child(qty)
	return slot
