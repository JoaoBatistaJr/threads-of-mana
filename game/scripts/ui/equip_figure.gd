class_name EquipFigure
extends Control

# Silhueta do personagem no painel de equipamento (placeholder até o modelo existir).

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := Vector2(size.x * 0.5, size.y)
	draw_circle(Vector2(c.x, size.y * 0.55), size.x * 0.5, Color(UiTheme.ACCENT, 0.06))
	var col := Color(0.55, 0.65, 0.8, 0.35)
	draw_circle(Vector2(c.x, 34), 22, col)
	draw_rect(Rect2(c.x - 34, 62, 68, 96), col)
	draw_rect(Rect2(c.x - 30, 160, 26, 90), col)
	draw_rect(Rect2(c.x + 4, 160, 26, 90), col)
	draw_rect(Rect2(c.x - 54, 64, 18, 84), col)
	draw_rect(Rect2(c.x + 36, 64, 18, 84), col)
