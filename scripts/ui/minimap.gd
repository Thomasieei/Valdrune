class_name Minimap
extends Control
## Mini-carte du royaume (fond calculé une fois) : relief, rivière, routes, château, bourg, camps,
## soldats déployés et souverain. Toucher la carte choisit un point (garder, patrouille, assaut).

signal picked(world_xz: Vector2)
static var _tex: ImageTexture
var marks: Array = []        # points choisis (ronde) à afficher
const RES := 160

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	if _tex == null:
		_tex = ImageTexture.create_from_image(_render())

static func _render() -> Image:
	var img := Image.create(RES, RES, false, Image.FORMAT_RGB8)
	var half := Layout.HALF
	for j in RES:
		for i in RES:
			var x := -half + (i + 0.5) * (2.0 * half / RES)
			var z := -half + (j + 0.5) * (2.0 * half / RES)
			var p := Vector2(x, z)
			var h := Terrain.height_at(x, z)
			var c := Color(0.32, 0.45, 0.24).lerp(Color(0.55, 0.52, 0.42), clampf((h - 8.0) / 30.0, 0, 1))
			c = c.lerp(Color(0.92, 0.94, 0.97), clampf((h - 45.0) / 15.0, 0, 1))
			if Layout.in_fields(p, 0.0):
				c = Color(0.72, 0.62, 0.32)
			if Layout.road_dist(p) < 1.5:
				c = Color(0.78, 0.68, 0.5)
			if h < Layout.WATER + 0.2 or Layout.river_dist(p) < Layout.RIVER_W:
				c = Color(0.25, 0.48, 0.72)
			if Layout.in_castle(p, 0.0):
				c = Color(0.6, 0.6, 0.62)
			img.set_pixel(i, j, c)
	return img

func w2m(p: Vector3) -> Vector2:
	return (Vector2(p.x, p.z) + Vector2.ONE * Layout.HALF) / (2.0 * Layout.HALF) * size

func m2w(v: Vector2) -> Vector2:
	return v / size * (2.0 * Layout.HALF) - Vector2.ONE * Layout.HALF

func _process(_d: float) -> void:
	if visible and Engine.get_process_frames() % 10 == 0:
		queue_redraw()

func _draw() -> void:
	draw_texture_rect(_tex, Rect2(Vector2.ZERO, size), false)
	draw_rect(Rect2(Vector2.ZERO, size), Color(1.0, 0.85, 0.5), false, 2.0)
	var f := get_theme_default_font()
	# bourg, château, portail
	draw_circle(w2m(Vector3(Layout.TOWN.x, 0, Layout.TOWN.y)), 6.0, Color(0.95, 0.85, 0.6))
	draw_string_outline(f, w2m(Vector3(Layout.TOWN.x + 8, 0, Layout.TOWN.y)), "Bourg", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, 4, Color.BLACK)
	draw_string(f, w2m(Vector3(Layout.TOWN.x + 8, 0, Layout.TOWN.y)), "Bourg", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, Color.WHITE)
	# camps ennemis encore debout
	for z in Spawner.ZONES:
		var gid: String = z["id"]
		if Spawner.group_of(gid) != gid:
			continue
		var sp := Spawner.by_id(gid)
		if sp and sp.liberated:
			continue
		var q := w2m(Vector3(z["pos"].x, 0, z["pos"].y))
		draw_circle(q, 5.0, Color(0.85, 0.15, 0.1))
		draw_arc(q, 7.0, 0, TAU, 16, Color(1, 0.6, 0.4), 1.5)
	# donjons
	for d in Dungeons.active():
		var q2 := w2m(d["pos3"])
		draw_circle(q2, 6.0, Color(0.7, 0.3, 1.0))
		draw_arc(q2, 9.0 + sin(Time.get_ticks_msec() / 200.0) * 2.0, 0, TAU, 16, Color(0.9, 0.7, 1.0), 2.0)
	# ronde en cours de tracé
	for i in marks.size():
		var mq := w2m(marks[i])
		draw_circle(mq, 5.0, Color(1, 0.9, 0.3))
		if i > 0:
			draw_line(w2m(marks[i - 1]), mq, Color(1, 0.9, 0.3), 2.0)
	# soldats déployés
	for s in Army.alive():
		draw_circle(w2m(s.global_position), 3.0, Color(0.4, 0.7, 1.0))
	for s in Escort.members:
		if is_instance_valid(s):
			draw_circle(w2m(s.global_position), 3.0, Color(0.6, 0.9, 1.0))
	# postes de garde, bandes errantes, embuscade en cours
	if Frontier.inst:
		for post in Frontier.inst.posts:
			var pq := w2m(post["pos"])
			draw_rect(Rect2(pq - Vector2(3, 3), Vector2(6, 6)), Color(0.45, 0.7, 1.0))
		for bq in Frontier.band_positions():
			draw_circle(w2m(Vector3(bq.x, 0, bq.y)), 3.5, Color(1.0, 0.45, 0.2))
		if Frontier.raid_active():
			var rq := w2m(Frontier.inst.raid["at"])
			draw_circle(rq, 7.0, Color(1.0, 0.3, 0.1))
			draw_arc(rq, 10.0 + sin(Time.get_ticks_msec() / 150.0) * 3.0, 0, TAU, 20, Color(1, 0.8, 0.3), 2.5)
			draw_string_outline(f, rq + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, 4, Color.BLACK)
			draw_string(f, rq + Vector2(-4, 5), "!", HORIZONTAL_ALIGNMENT_LEFT, -1, 16, Color.WHITE)
	# souverain
	var p := Combat.player
	if p:
		var c := w2m(p.global_position)
		var fwd: Vector3 = p.forward()
		var dir := Vector2(fwd.x, fwd.z).normalized()
		var sd := Vector2(-dir.y, dir.x)
		draw_colored_polygon(PackedVector2Array([c + dir * 9.0, c - dir * 5.0 + sd * 5.0, c - dir * 5.0 - sd * 5.0]), Color.WHITE)

func _gui_input(e: InputEvent) -> void:
	if (e is InputEventMouseButton and e.pressed) or (e is InputEventScreenTouch and e.pressed):
		var w := m2w(e.position)
		picked.emit(w)
		accept_event()
