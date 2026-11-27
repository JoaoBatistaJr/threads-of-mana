class_name InventoryPanel
extends PanelContainer

# Janela de inventário (só cliente). Mostra as pilhas enviadas pelo servidor
# (linhas [uid, item_id, quantidade, qualidade]) numa grade de slots. Só exibe; quem muda é o servidor.

const COLUMNS := 6
const SLOT := Vector2(60, 60)

var _grid := GridContainer.new()
var _title := Label.new()


func _init() -> void:
	visible = false
	var box := VBoxContainer.new()
	add_child(box)
	_title.add_theme_font_size_override("font_size", 18)
	box.add_child(_title)
	_grid.columns = COLUMNS
	_grid.add_theme_constant_override("h_separation", 4)
	_grid.add_theme_constant_override("v_separation", 4)
	box.add_child(_grid)
	var hint := Label.new()
	hint.text = "[I] fechar"
	hint.modulate = Color(1, 1, 1, 0.6)
	box.add_child(hint)


func toggle() -> void:
	visible = not visible
	if visible:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		_fit.call_deferred()


func show_rows(rows: Array) -> void:
	for c in _grid.get_children():
		_grid.remove_child(c)
		c.queue_free()
	_title.text = "Inventário  %d/%d" % [rows.size(), Const.INVENTORY_SLOTS]
	for i in Const.INVENTORY_SLOTS:
		_grid.add_child(_make_slot(rows[i] if i < rows.size() else null))
	if visible:
		_fit.call_deferred()


# Encolhe ao conteúdo e cola no canto direito.
func _fit() -> void:
	reset_size()
	position = Vector2(get_viewport_rect().size.x - size.x - 24.0, 90.0)


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
