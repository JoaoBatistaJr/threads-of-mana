class_name LootPanel
extends PanelContainer

# Janela de loot (só cliente). Mostra as linhas [uid, item_id, qtd, qualidade] recebidas do servidor
# e avisa o que o jogador quer pegar; quem decide é o servidor.

signal take(uid: String)
signal take_all
signal closed

var _list := VBoxContainer.new()
var _title := Label.new()


func _init() -> void:
	visible = false
	set_anchors_preset(Control.PRESET_CENTER)
	custom_minimum_size = Vector2(340, 0)
	var box := VBoxContainer.new()
	add_child(box)
	_title.text = "Bolsa"
	_title.add_theme_font_size_override("font_size", 20)
	box.add_child(_title)
	box.add_child(_list)
	var row := HBoxContainer.new()
	box.add_child(row)
	var all := Button.new()
	all.text = "Pegar tudo"
	all.pressed.connect(func(): take_all.emit())
	row.add_child(all)
	var close := Button.new()
	close.text = "Fechar [F]"
	close.pressed.connect(close_panel)
	row.add_child(close)


func show_rows(rows: Array) -> void:
	for c in _list.get_children():
		_list.remove_child(c)
		c.queue_free()
	if rows.is_empty():
		close_panel()
		return
	for r in rows:
		var b := Button.new()
		var q: String = "" if float(r[3]) <= 0.0 else "  (QL %d)" % roundi(float(r[3]))
		b.text = "%s x%d%s" % [ItemRegistry.display_name(r[1]), int(r[2]), q]
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		var uid: String = r[0]
		b.pressed.connect(func(): take.emit(uid))
		_list.add_child(b)
	if not visible:
		visible = true
		position = (get_viewport_rect().size - size) * 0.5
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_panel() -> void:
	if visible:
		visible = false
		closed.emit()
