## Moldura ornamentada desenhada em código: filete interno dourado e cantos com losango.
## Use [method FantasyTheme.add_frame]; ignora o mouse e desenha por cima do painel pai.
extends Control
class_name OrnateFrame

## Distância (px) entre a área de conteúdo do painel e a borda externa dele.
var reach: float = 12.0
## Recuo do filete em relação à borda externa.
var inset: float = 6.0

const LINE: Color = Color(0.35, 0.78, 1.0, 0.45)
const CORNER: Color = Color(0.5, 0.85, 1.0, 0.95)
const DARK: Color = Color(0.02, 0.05, 0.1, 1.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _draw() -> void:
	var r := Rect2(Vector2.ZERO, size).grow(reach - inset)
	draw_rect(r, LINE, false, 1.0)
	var arm: float = 26.0
	var corners: Array = [
		[r.position, Vector2(1, 0), Vector2(0, 1)],
		[Vector2(r.end.x, r.position.y), Vector2(-1, 0), Vector2(0, 1)],
		[Vector2(r.position.x, r.end.y), Vector2(1, 0), Vector2(0, -1)],
		[r.end, Vector2(-1, 0), Vector2(0, -1)],
	]
	for c in corners:
		var p: Vector2 = c[0]
		draw_line(p, p + c[1] * arm, CORNER, 2.0)
		draw_line(p, p + c[2] * arm, CORNER, 2.0)
		var d: float = 5.0
		var diamond := PackedVector2Array([p + Vector2(0, -d), p + Vector2(d, 0), p + Vector2(0, d), p + Vector2(-d, 0)])
		draw_colored_polygon(diamond, CORNER)
		draw_polyline(PackedVector2Array([diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]]), DARK, 1.0)
