class_name GameWindow
extends PanelContainer

# Janela base: título serifado, botão X, arrastável pela barra de título.
# O conteúdo vai em `body`. O jogo não pausa enquanto ela está aberta.

signal closed

var body := VBoxContainer.new()
var _title := Label.new()
var _bar := HBoxContainer.new()
var _close := Button.new()
var _drag := false
var _drag_off := Vector2.ZERO
var _placed := false


func _init(p_title := "", p_min := Vector2.ZERO) -> void:
	visible = false
	custom_minimum_size = p_min
	var root := VBoxContainer.new()
	root.add_theme_constant_override("separation", 8)
	add_child(root)

	_bar.mouse_filter = Control.MOUSE_FILTER_STOP
	_bar.mouse_default_cursor_shape = Control.CURSOR_MOVE
	_bar.gui_input.connect(_on_bar_input)
	root.add_child(_bar)
	_title.text = p_title
	_title.add_theme_font_override("font", UiTheme.title_font())
	_title.add_theme_font_size_override("font_size", 22)
	_title.add_theme_color_override("font_color", UiTheme.GOLD)
	_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_title.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_bar.add_child(_title)
	_close.text = "X"
	_close.focus_mode = Control.FOCUS_NONE
	_close.pressed.connect(close)
	_bar.add_child(_close)

	var line := ColorRect.new()
	line.color = UiTheme.BORDER_DIM
	line.custom_minimum_size = Vector2(0, 1)
	root.add_child(line)

	body.size_flags_vertical = Control.SIZE_EXPAND_FILL
	root.add_child(body)


func set_title(t: String) -> void:
	_title.text = t


func toggle() -> void:
	if visible:
		close()
	else:
		open()


func open() -> void:
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	move_to_front()
	_fit.call_deferred()


func close() -> void:
	if not visible:
		return
	visible = false
	closed.emit()


# Encolhe ao conteúdo; só posiciona na primeira abertura (depois lembra onde o jogador deixou).
func _fit() -> void:
	reset_size()
	if not _placed:
		_placed = true
		var vp := get_viewport_rect().size
		position = ((vp - size) * 0.5).round()
	_clamp()


func place_at(p: Vector2) -> void:
	_placed = true
	position = p


func _clamp() -> void:
	var vp := get_viewport_rect().size
	position = Vector2(
		clampf(position.x, 0.0, maxf(0.0, vp.x - size.x)),
		clampf(position.y, 0.0, maxf(0.0, vp.y - size.y)))


func _on_bar_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.button_index == MOUSE_BUTTON_LEFT:
		_drag = e.pressed
		_drag_off = get_global_mouse_position() - global_position
		if e.pressed:
			move_to_front()
	elif e is InputEventMouseMotion and _drag:
		position = get_global_mouse_position() - _drag_off
		_clamp()


func _gui_input(e: InputEvent) -> void:
	if e is InputEventMouseButton and e.pressed:
		move_to_front()
