extends Control
## Mini-carte (en haut à droite) : rues, maisons, habitants exclus, ennemis en rouge, joueur en flèche. Nord en haut.
var main
const SZ := 238.0
const PX := 1.6        # pixels par mètre
var _t := 0.0
func _ready() -> void:
	mouse_filter = MOUSE_FILTER_IGNORE; clip_contents = true
	anchor_left = 1; anchor_right = 1; offset_left = -SZ - 12; offset_right = -12; offset_top = 12; offset_bottom = 12 + SZ
func _process(dt: float) -> void:
	_t += dt
	if _t > 0.1: _t = 0; queue_redraw()
func _w2m(p: Vector2, c: Vector2) -> Vector2: return (p - c) * PX + Vector2(SZ, SZ) * 0.5
func _rect(c: Vector2, sz: Vector2, ang: float, ctr: Vector2, col: Color) -> void:
	var h := sz * 0.5; var pts := PackedVector2Array()
	for v in [Vector2(-h.x, -h.y), Vector2(h.x, -h.y), Vector2(h.x, h.y), Vector2(-h.x, h.y)]:
		pts.append(_w2m(c + v.rotated(-ang), ctr))
	draw_colored_polygon(pts, col)
func _draw() -> void:
	var p: Vector3 = main.player.global_position
	var ctr := Vector2(p.x, p.z)
	draw_rect(Rect2(Vector2.ZERO, Vector2(SZ, SZ)), Color(0.2, 0.32, 0.16, 0.85))
	for ci in main.town.map_circles: draw_circle(_w2m(ci[0], ctr), ci[1] * PX, ci[2])
	for r in main.town.map_rects: _rect(r[0], r[1], 0.0, ctr, r[2])
	for h in main.town.map_houses: _rect(h[0], h[1], h[2], ctr, Color(0.55, 0.3, 0.25))
	for a in main.actors:
		if a.team == 1 and a.state != "dead": draw_circle(_w2m(Vector2(a.global_position.x, a.global_position.z), ctr), 3.5, Color(1, 0.2, 0.2))
		elif a != main.player and a.state != "dead": draw_circle(_w2m(Vector2(a.global_position.x, a.global_position.z), ctr), 3.0, Color(0.4, 0.8, 1))
	var c := Vector2(SZ, SZ) * 0.5; var r: float = main.player.rotation.y
	var f := Vector2(sin(r), cos(r))
	draw_colored_polygon(PackedVector2Array([c + f * 9, c + f.rotated(2.5) * 7, c + f.rotated(-2.5) * 7]), Color(1, 0.9, 0.3))
	draw_rect(Rect2(Vector2.ZERO, Vector2(SZ, SZ)), Color(0.95, 0.75, 0.3), false, 3)
	draw_string(get_theme_default_font(), Vector2(SZ * 0.5 - 5, 18), "N", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
