class_name UiTheme
extends RefCounted

# Visual único da UI (azul-marinho + dourado, como no offline). Tudo sai daqui.

const BG := Color(0.075, 0.098, 0.141, 0.94)
const BG_DEEP := Color(0.055, 0.073, 0.106, 0.92)
const BORDER := Color(0.20, 0.25, 0.33)
const BORDER_DIM := Color(0.16, 0.20, 0.27)
const ACCENT := Color(0.18, 0.43, 0.72)
const SLOT := Color(0.09, 0.115, 0.16, 0.92)
const GOLD := Color(0.95, 0.76, 0.30)
const TEXT := Color(0.90, 0.93, 0.97)
const MUTED := Color(0.55, 0.62, 0.74)
const HP := Color(0.75, 0.18, 0.16)
const MP := Color(0.18, 0.56, 0.88)

static var _serif: SystemFont
static var _theme: Theme


static func title_font() -> Font:
	if _serif == null:
		_serif = SystemFont.new()
		_serif.font_names = PackedStringArray(["Georgia", "Palatino Linotype", "Book Antiqua", "DejaVu Serif", "serif"])
		_serif.font_weight = 700
	return _serif


static func box(bg: Color, border: Color, border_w := 1, radius := 4) -> StyleBoxFlat:
	var sb := StyleBoxFlat.new()
	sb.bg_color = bg
	sb.border_color = border
	sb.set_border_width_all(border_w)
	sb.set_corner_radius_all(radius)
	return sb


static func panel_box() -> StyleBoxFlat:
	var sb := box(BG, BORDER, 1, 4)
	sb.set_content_margin_all(10)
	sb.shadow_color = Color(0, 0, 0, 0.35)
	sb.shadow_size = 6
	return sb


static func slot_box(border := BORDER_DIM) -> StyleBoxFlat:
	return box(SLOT, border, 1, 3)


# Theme aplicado na raiz da UI; os filhos herdam.
static func make_theme() -> Theme:
	if _theme != null:
		return _theme
	var t := Theme.new()
	t.set_default_font_size(14)
	t.set_color("font_color", "Label", TEXT)
	t.set_stylebox("panel", "PanelContainer", panel_box())

	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		var border := BORDER_DIM
		var bg := Color(0.105, 0.13, 0.18, 0.95)
		match state:
			"hover":
				border = BORDER
				bg = Color(0.15, 0.18, 0.25, 0.95)
			"pressed":
				border = ACCENT
				bg = ACCENT
			"focus":
				border = ACCENT
			"disabled":
				bg = Color(0.07, 0.085, 0.12, 0.8)
		var sb := box(bg, border, 1, 4)
		sb.content_margin_left = 12
		sb.content_margin_right = 12
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		t.set_stylebox(state, "Button", sb)
	t.set_color("font_color", "Button", TEXT)
	t.set_color("font_hover_color", "Button", Color.WHITE)
	t.set_color("font_pressed_color", "Button", Color.WHITE)
	t.set_color("font_disabled_color", "Button", MUTED)

	var le := box(Color(0.05, 0.065, 0.095, 0.9), BORDER_DIM, 1, 4)
	le.set_content_margin_all(6)
	t.set_stylebox("normal", "LineEdit", le)
	t.set_stylebox("read_only", "LineEdit", le)
	t.set_stylebox("focus", "LineEdit", box(Color(0.05, 0.065, 0.095, 0.95), ACCENT, 1, 4))
	t.set_color("font_color", "LineEdit", TEXT)
	t.set_color("font_placeholder_color", "LineEdit", MUTED)

	t.set_stylebox("background", "ProgressBar", box(Color(0.04, 0.05, 0.08, 0.9), BORDER_DIM, 1, 3))
	t.set_stylebox("fill", "ProgressBar", box(ACCENT, ACCENT, 0, 3))

	var tip := box(BG, BORDER, 1, 4)
	tip.set_content_margin_all(8)
	t.set_stylebox("panel", "TooltipPanel", tip)
	t.set_color("font_color", "TooltipLabel", TEXT)
	_theme = t
	return t


static func bar_style(color: Color) -> StyleBoxFlat:
	return box(color, color.lightened(0.25), 1, 3)
