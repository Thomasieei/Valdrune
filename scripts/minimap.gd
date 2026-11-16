class_name Minimap
extends Control
## Mini-carte circulaire orientée comme la caméra.

const R := 82.0
const RANGE := 55.0
var main

func _process(_d: float) -> void:
	queue_redraw()

func _to_map(p: Vector3) -> Vector2:
	var h: Vector3 = main.hero.global_position
	var d := Vector2(p.x - h.x, p.z - h.z)
	var yaw: float = main.yaw
	# avant de la caméra = haut de la carte
	var rx := d.x * cos(yaw) - d.y * sin(yaw)
	var ry := d.x * sin(yaw) + d.y * cos(yaw)
	return Vector2(rx, ry) / RANGE * R

func _dot(p: Vector3, col: Color, r: float, clamp_edge := false) -> void:
	var m := _to_map(p)
	if m.length() > R - 4.0:
		if not clamp_edge:
			return
		m = m.normalized() * (R - 6.0)
	draw_circle(Vector2(R, R) + m, r, col)

func _draw() -> void:
	if main == null or main.hero == null:
		return
	var c := Vector2(R, R)
	draw_circle(c, R, Color(0.02, 0.03, 0.09, 0.72))
	draw_arc(c, R, 0, TAU, 64, Color(0.45, 0.4, 1.0, 0.8), 2.0)
	draw_arc(c, R * 0.5, 0, TAU, 48, Color(0.45, 0.4, 1.0, 0.18), 1.0)
	var dom: float = main.hero.domain_r() / RANGE * R
	draw_arc(c, minf(dom, R - 2), 0, TAU, 48, Color(0.6, 0.3, 1.0, 0.35), 1.5)
	if main.zone == "city":
		if main.gate:
			_dot(main.gate_pos, Color(0.3, 0.6, 1.0), 6.0, true)
		for e in main.elite_camps:
			if str(e["state"]) == "guarded":
				_dot(e["pos"], Color(1.0, 0.75, 0.2), 4.5, false)
		if main.merchant:
			_dot(main.merchant.global_position, Color(0.4, 1.0, 0.5), 4.0, true)
	elif main.zone == "dungeon" and main.dungeon:
		_dot(main.dungeon.next_target(), Color(1, 0.3, 0.3), 5.0, true)
	for m in main.mobs:
		var mm := m as Mob
		if mm.dead or not mm.visible:
			continue
		var col := Color(1, 0.25, 0.2)
		var r := 2.6
		if mm.is_shadow:
			col = Color(0.65, 0.35, 1.0)
		elif mm.team == 2:
			col = Color(0.35, 0.65, 1.0)
		elif mm.boss:
			r = 5.0
		elif mm.elite:
			col = Color(1, 0.6, 0.1)
			r = 3.4
		_dot(mm.global_position, col, r)
	# le héros : flèche au centre
	var fw: Vector3 = main.hero.forward()
	var dv := _to_map(main.hero.global_position + fw * 10.0).normalized()
	var pv := Vector2(-dv.y, dv.x)
	var tip := c + dv * 9.0
	var l := c - dv * 5.0 + pv * 6.0
	var rr := c - dv * 5.0 - pv * 6.0
	draw_colored_polygon(PackedVector2Array([tip, l, rr]), Color(1, 1, 1))
