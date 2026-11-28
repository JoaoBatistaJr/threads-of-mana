class_name WindowBadge
extends Control

# Medalhão redondo ao lado do título da janela (anel dourado + losango), desenhado em código.

func _init() -> void:
	custom_minimum_size = Vector2(46, 46)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var c := size * 0.5
	draw_circle(c, 22.0, Color(0.03, 0.06, 0.12))
	draw_arc(c, 21.0, 0.0, TAU, 40, UiTheme.GOLD, 2.0, true)
	draw_arc(c, 16.0, 0.0, TAU, 32, Color(UiTheme.ACCENT, 0.4), 1.0, true)
	var d := 8.0
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -d), c + Vector2(d, 0), c + Vector2(0, d), c + Vector2(-d, 0)]), UiTheme.GOLD)
