class_name Carte
extends Control

# Mini-carte tournante + GPS : la grille est lue une fois dans la ville, le trajet suit les rues (A*).

const X0 := -430.0
const Z0 := -330.0
const CELL := 5.0
const W := 120
const H := 86
const RAYON := 110.0

var ville: Node3D
var sel := -1
var _tex: ImageTexture
var _astar: AStarGrid2D
var _route := PackedVector2Array()
var _t_route := 0.0
var _t_dessin := 0.0

func construire(v: Node3D) -> void:
	ville = v
	var etat := v.get_world_3d().direct_space_state
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8)
	_astar = AStarGrid2D.new()
	_astar.region = Rect2i(0, 0, W, H)
	_astar.cell_size = Vector2.ONE
	_astar.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	_astar.update()
	for gz in H:
		for gx in W:
			var x := X0 + (gx + 0.5) * CELL
			var z := Z0 + (gz + 0.5) * CELL
			var r := etat.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -5, z)))
			var col := Color(0.0, 0.0, 0.0, 0.0)
			if not r.is_empty():
				if float(r["position"].y) > 3.0:
					col = Color(0.4, 0.48, 0.72, 0.95)
					_astar.set_point_solid(Vector2i(gx, gz), true)
				else:
					col = Color(0.13, 0.22, 0.38, 0.9)
			img.set_pixel(gx, gz, col)
	_tex = ImageTexture.create_from_image(img)
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var sh := Shader.new()
	sh.code = "shader_type canvas_item; void fragment() { float d = length(UV - vec2(0.5)); COLOR.a *= 1.0 - smoothstep(0.485, 0.5, d); }"
	var mat := ShaderMaterial.new()
	mat.shader = sh
	material = mat

func cibles() -> Array:
	return ville.cibles_gps() if ville else []

func cycler() -> void:
	var n := cibles().size()
	sel += 1
	if sel >= n:
		sel = -1
	_t_route = 0.0

func cible_actuelle() -> Dictionary:
	if sel == -1:
		var g: Dictionary = ville.missions.guide_mission() if ville.missions else {}
		return g
	var l := cibles()
	return l[sel] if sel < l.size() else {}

func _cell(p: Vector2) -> Vector2i:
	return Vector2i(clampi(int((p.x - X0) / CELL), 0, W - 1), clampi(int((p.y - Z0) / CELL), 0, H - 1))

func _libre(c: Vector2i) -> Vector2i:
	if not _astar.is_point_solid(c):
		return c
	for r in range(1, 6):
		for dz in range(-r, r + 1):
			for dx in range(-r, r + 1):
				var q := Vector2i(c.x + dx, c.y + dz)
				if _astar.is_in_boundsv(q) and not _astar.is_point_solid(q):
					return q
	return c

func _maj_route() -> void:
	var t := cible_actuelle()
	_route = PackedVector2Array()
	if t.is_empty():
		return
	var pj: Vector3 = ville.joueur.global_position
	var dest: Vector3 = t["pos"]
	var ids := _astar.get_id_path(_libre(_cell(Vector2(pj.x, pj.z))), _libre(_cell(Vector2(dest.x, dest.z))))
	if ids.size() < 2:
		_route = PackedVector2Array([Vector2(pj.x, pj.z), Vector2(dest.x, dest.z)])
		return
	_route.append(Vector2(pj.x, pj.z))
	for k in range(1, ids.size(), 1):
		var id: Vector2i = ids[k]
		_route.append(Vector2(X0 + (id.x + 0.5) * CELL, Z0 + (id.y + 0.5) * CELL))
	_route.append(Vector2(dest.x, dest.z))

func _process(dt: float) -> void:
	if not visible or ville == null or _tex == null:
		return
	_t_route -= dt
	if _t_route <= 0.0:
		_t_route = 1.0
		_maj_route()
	_t_dessin -= dt
	if _t_dessin <= 0.0:
		_t_dessin = 0.1
		queue_redraw()

func _draw() -> void:
	if ville == null or _tex == null or ville.joueur == null:
		return
	var j: Node3D = ville.joueur
	var R := size.x / 2.0
	var c := size / 2.0
	var ech := size.x / (2.0 * RAYON)
	var pp := Vector2(j.global_position.x, j.global_position.z)
	var l: float = j.camera_lacet
	var phi := -PI / 2.0 - atan2(-cos(l), -sin(l))
	draw_circle(c, R, Color(0.02, 0.04, 0.08, 0.9))
	draw_set_transform(c, phi, Vector2.ONE)
	draw_texture_rect(_tex, Rect2((Vector2(X0, Z0) - pp) * ech, Vector2(W * CELL, H * CELL) * ech), false)
	if _route.size() > 1:
		var pts := PackedVector2Array()
		for p in _route:
			pts.append((p - pp) * ech)
		draw_polyline(pts, Color(0.3, 1.0, 0.55, 0.95), 4.0, true)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)
	var cur := cible_actuelle()
	var liste := cibles()
	if sel == -1 and not cur.is_empty():
		liste = liste + [cur]
	for t in liste:
		var wp: Vector3 = t["pos"]
		var r := ((Vector2(wp.x, wp.z) - pp) * ech).rotated(phi)
		var bord := r.length() > R - 9.0
		if bord:
			r = r.normalized() * (R - 9.0)
		var col: Color = t["col"]
		var actif := (not cur.is_empty() and cur["nom"] == t["nom"])
		draw_circle(c + r, 6.0 if actif else 4.0, col)
		if actif:
			draw_arc(c + r, 9.0, 0, TAU, 20, Color(1, 1, 1, 0.9), 2.0, true)
	var bm: Monstre = ville.boss_evt
	if bm != null and is_instance_valid(bm) and not bm.mort:
		var rb := ((Vector2(bm.global_position.x, bm.global_position.z) - pp) * ech).rotated(phi)
		if rb.length() > R - 9.0:
			rb = rb.normalized() * (R - 9.0)
		draw_circle(c + rb, 5.0, Color(1.0, 0.25, 0.3))
	draw_colored_polygon(PackedVector2Array([c + Vector2(0, -11), c + Vector2(8, 9), c + Vector2(0, 5), c + Vector2(-8, 9)]), Color(1, 1, 1))
	draw_arc(c, R * 0.965, 0, TAU, 56, Color(0.5, 0.85, 1.0, 0.95), 4.0, true)
