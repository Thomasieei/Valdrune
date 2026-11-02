class_name UiIcon
extends Control
## Petites icônes vectorielles de l'interface du royaume (nettes à toutes les résolutions, sans police d'emoji).

var icon := ""
var col := Color(1, 0.85, 0.45)

func setup(ic: String, size_px: float, c := Color(1, 0.85, 0.45)) -> UiIcon:
	icon = ic
	col = c
	custom_minimum_size = Vector2(size_px, size_px)
	size = custom_minimum_size
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	return self

func _draw() -> void:
	var s := size.x * 0.5
	var c := size * 0.5
	match icon:
		"economie", "tresor":
			for k in 3:
				var p := c + Vector2(-0.3 + k * 0.3, 0.35 - k * 0.32) * s
				draw_circle(p, s * 0.42, Color(0.85, 0.6, 0.15))
				draw_circle(p, s * 0.32, Color(1, 0.82, 0.3))
		"population":
			draw_circle(c + Vector2(-0.35, -0.3) * s, s * 0.26, col)
			draw_circle(c + Vector2(0.35, -0.3) * s, s * 0.26, col)
			draw_rect(Rect2(c + Vector2(-0.75, 0.05) * s, Vector2(0.7, 0.7) * s), col)
			draw_rect(Rect2(c + Vector2(0.05, 0.05) * s, Vector2(0.7, 0.7) * s), col)
		"territoire":
			draw_line(c + Vector2(-0.5, 0.85) * s, c + Vector2(-0.5, -0.85) * s, col, s * 0.12)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.45, -0.8) * s, c + Vector2(0.75, -0.5) * s, c + Vector2(-0.45, -0.15) * s]), Color(0.3, 0.5, 0.95))
		"batiments":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, -0.05) * s, c + Vector2(0, -0.8) * s, c + Vector2(0.8, -0.05) * s]), Color(0.75, 0.3, 0.25))
			draw_rect(Rect2(c + Vector2(-0.6, -0.05) * s, Vector2(1.2, 0.85) * s), col)
			draw_rect(Rect2(c + Vector2(-0.15, 0.3) * s, Vector2(0.3, 0.5) * s), Color(0.3, 0.2, 0.12))
		"armee":
			draw_line(c + Vector2(-0.7, 0.7) * s, c + Vector2(0.7, -0.7) * s, Color(0.85, 0.88, 0.95), s * 0.14)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.1, -0.5) * s, c + Vector2(0.65, -0.5) * s, c + Vector2(0.6, 0.2) * s, c + Vector2(0.27, 0.6) * s, c + Vector2(-0.05, 0.2) * s]), Color(0.3, 0.5, 0.95))
		"diplomatie":
			draw_rect(Rect2(c + Vector2(-0.6, -0.75) * s, Vector2(1.2, 1.5) * s), Color(0.95, 0.9, 0.75))
			for k in 4:
				draw_line(c + Vector2(-0.4, -0.45 + k * 0.28) * s, c + Vector2(0.4, -0.45 + k * 0.28) * s, Color(0.4, 0.35, 0.3), 2.0)
			draw_circle(c + Vector2(0.35, 0.6) * s, s * 0.22, Color(0.8, 0.15, 0.15))
		"personnages":
			draw_circle(c + Vector2(0, -0.35) * s, s * 0.35, col)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.75, 0.85) * s, c + Vector2(-0.55, 0.15) * s, c + Vector2(0.55, 0.15) * s, c + Vector2(0.75, 0.85) * s]), col)
		"missions":
			draw_circle(c, s * 0.8, Color(0.95, 0.9, 0.75))
			draw_colored_polygon(PackedVector2Array([c + Vector2(0, -0.7) * s, c + Vector2(0.18, 0) * s, c + Vector2(0, 0.7) * s, c + Vector2(-0.18, 0) * s]), Color(0.8, 0.2, 0.2))
			draw_circle(c, s * 0.1, Color(0.2, 0.2, 0.2))
		"rapports":
			draw_rect(Rect2(c + Vector2(-0.55, -0.8) * s, Vector2(1.1, 1.6) * s), Color(0.95, 0.9, 0.75))
			draw_circle(c + Vector2(-0.55, -0.8) * s + Vector2(0, s * 0.1), s * 0.18, Color(0.85, 0.78, 0.6))
			for k in 4:
				draw_line(c + Vector2(-0.35, -0.45 + k * 0.3) * s, c + Vector2(0.35, -0.45 + k * 0.3) * s, Color(0.4, 0.35, 0.3), 2.0)
		"nourriture":
			draw_circle(c + Vector2(0, 0.15) * s, s * 0.6, Color(0.85, 0.65, 0.3))
			draw_line(c + Vector2(0, -0.45) * s, c + Vector2(0.15, -0.85) * s, Color(0.4, 0.6, 0.2), s * 0.15)
		"bois":
			for k in 2:
				var y := (-0.25 + k * 0.5) * s
				draw_rect(Rect2(c + Vector2(-0.75 * s, y - 0.2 * s), Vector2(1.5, 0.4) * s), Color(0.55, 0.35, 0.18))
				draw_circle(c + Vector2(0.75 * s, y), s * 0.2, Color(0.85, 0.7, 0.45))
		"pierre":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.6) * s, c + Vector2(-0.5, -0.4) * s, c + Vector2(0.2, -0.65) * s, c + Vector2(0.8, -0.1) * s, c + Vector2(0.6, 0.6) * s]), Color(0.6, 0.62, 0.65))
		"minerai":
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.8, 0.6) * s, c + Vector2(-0.5, -0.4) * s, c + Vector2(0.2, -0.65) * s, c + Vector2(0.8, -0.1) * s, c + Vector2(0.6, 0.6) * s]), Color(0.4, 0.38, 0.42))
			draw_circle(c + Vector2(-0.1, 0.0) * s, s * 0.16, Color(0.9, 0.55, 0.3))
			draw_circle(c + Vector2(0.3, 0.25) * s, s * 0.12, Color(0.9, 0.55, 0.3))
		"moral":
			draw_circle(c, s * 0.8, Color(1, 0.82, 0.3))
			draw_circle(c + Vector2(-0.3, -0.2) * s, s * 0.1, Color(0.2, 0.15, 0.1))
			draw_circle(c + Vector2(0.3, -0.2) * s, s * 0.1, Color(0.2, 0.15, 0.1))
			draw_arc(c + Vector2(0, 0.05) * s, s * 0.42, 0.3, PI - 0.3, 12, Color(0.2, 0.15, 0.1), 3.0)
		"soldats":
			draw_line(c + Vector2(0, 0.85) * s, c + Vector2(0, -0.5) * s, Color(0.55, 0.4, 0.25), s * 0.12)
			draw_colored_polygon(PackedVector2Array([c + Vector2(-0.2, -0.45) * s, c + Vector2(0, -0.9) * s, c + Vector2(0.2, -0.45) * s]), Color(0.85, 0.88, 0.95))
