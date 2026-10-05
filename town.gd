extends RefCounted
class_name TownGen
# Bourg organique : les rues suivent les vraies routes qui partent de la ville, des ruelles s'en échappent,
# les maisons s'alignent le long des rues (portes côté rue), une place irrégulière au centre,
# jardins, arbres, lanternes, et chaque habitant a SON coin (pas tous au même endroit).

const PLAZA_R := 8.5
const MAIN_HALF := 2.6
const LANE_HALF := 1.7
const MAX_LEN := 58.0

var W: Node
var V := Vector2.ZERO
var streets: Array = []      # {pts: Array[Vector2], half, main, len, cum: Array[float]}
var homes: Array = []        # {c, rot, w, d, fl, street, s, side, door, out, big, used}
var npc_used: Array = []     # positions déjà prises par des PNJ
var entrances: Array = []    # {p, dir}
var R := RandomNumberGenerator.new()
var bbox := Rect2()

# ================= PLAN (avant le relief) =================
func plan(world: Node) -> void:
	W = world; V = W.village; R.seed = 7000 + W.map_id * 13
	streets = []
	var dirs: Array = []
	for rd in W.roads:
		var pts: Array = rd
		if pts.size() < 2: continue
		# point de la route le plus proche du centre
		var best_i := -1; var best_t := 0.0; var bd := 1e9
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]; var ab := b - a
			var t: float = clamp((V - a).dot(ab) / max(0.0001, ab.length_squared()), 0.0, 1.0)
			var d := V.distance_to(a + ab * t)
			if d < bd: bd = d; best_i = i; best_t = t
		if bd > 5.0: continue
		var a0: Vector2 = pts[best_i]; var b0: Vector2 = pts[best_i + 1]
		var cp: Vector2 = a0.lerp(b0, best_t)
		var fwd: Array = [V, cp]; for k in range(best_i + 1, pts.size()): fwd.append(pts[k])
		var bwd: Array = [V, cp]; for k in range(best_i, -1, -1): bwd.append(pts[k])
		for cand in [fwd, bwd]: _try_main(_clean(cand), dirs)
	# routes qui bifurquent d'une grande rue : elles deviennent aussi des rues du bourg
	for rd in W.roads:
		var pts2: Array = rd
		for vi in pts2.size():
			var vtx: Vector2 = pts2[vi]
			var dv := vtx.distance_to(V)
			if dv < PLAZA_R + 4.0 or dv > 42.0: continue
			var on_main := false
			for st in streets:
				if W.poly_dist(vtx, st.pts) < 1.5: on_main = true; break
			if not on_main: continue
			for dir_i: int in [1, -1]:
				var path: Array = [vtx]
				var k: int = vi + dir_i
				while k >= 0 and k < pts2.size(): path.append(pts2[k]); k += dir_i
				if path.size() < 2: continue
				var rs := _resample(_clean(path), 2.0)
				if rs.size() < 4: continue
				# la branche doit s'écarter des rues existantes
				var away := true
				for st in streets:
					if W.poly_dist(rs[3], st.pts) < 4.0: away = false; break
				if not away: continue
				var out: Array = []; var L := 0.0
				for i in rs.size():
					if i > 0: L += (rs[i - 1] as Vector2).distance_to(rs[i])
					if L > MAX_LEN - dv * 0.5 or (i > 1 and _bad(rs[i])): break
					out.append(rs[i])
				if out.size() >= 6: _add_street(out, MAIN_HALF, true)
	# ruelles qui partent des grandes rues
	var mains := streets.duplicate()
	var side := 1.0
	for st in mains:
		for s0: float in [17.0, 27.0, 38.0, 49.0]:
			if s0 > float(st.len) - 8.0: continue
			side = -side
			_try_lane(st, s0, side)
	# boîte englobante (accélère town_dist)
	bbox = Rect2(V - Vector2(PLAZA_R, PLAZA_R), Vector2(PLAZA_R, PLAZA_R) * 2.0)
	for st in streets:
		for p: Vector2 in st.pts: bbox = bbox.expand(p)
	bbox = bbox.grow(30.0)

func _clean(a: Array) -> Array:
	var out: Array = []
	for p: Vector2 in a:
		if out.is_empty() or (out[out.size() - 1] as Vector2).distance_to(p) > 0.5: out.append(p)
	return out

func _resample(pts: Array, step: float) -> Array:
	var out: Array = [pts[0]]
	var carry := 0.0
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]; var L := a.distance_to(b)
		var s := step - carry
		while s <= L:
			out.append(a.lerp(b, s / L)); s += step
		carry = L - (s - step)
	if (out[out.size() - 1] as Vector2).distance_to(pts[pts.size() - 1]) > 0.8: out.append(pts[pts.size() - 1])
	return out

func _bad(p: Vector2, extra := 0.0) -> bool:
	if abs(p.x) > 98.0 or abs(p.y) > 98.0: return true
	if W.river_dist(p.x, p.y) < World.RIVER_W + 3.0 + extra: return true
	for lk in W.LAKES:
		if p.distance_to(lk[0]) < lk[1] + 3.0 + extra: return true
	for g in W.MAP.gates:
		if p.distance_to(g.pos) < 18.0: return true
	for pd in W.POI_DEFS:
		var pm: float = {"arena": 11.0, "tower_inf": 10.0, "enchant": 4.0, "shrine": 4.0, "camp": 12.0, "lair": 14.0}.get(pd.get("kind", ""), 4.0)
		if p.distance_to(pd.p) < pd.r + pm + extra: return true
	if W.BAY != null and p.distance_to(W.BAY) < 30.0 + extra: return true
	return false

func _try_main(pts: Array, dirs: Array) -> void:
	if pts.size() < 2: return
	var rs := _resample(pts, 2.0)
	if rs.size() < 3: return
	var d0: Vector2 = ((rs[2] as Vector2) - V).normalized()
	for d in dirs:
		if (d as Vector2).dot(d0) > 0.9: return     # même direction qu'une rue existante
	var out: Array = []; var L := 0.0
	for i in rs.size():
		var p: Vector2 = rs[i]
		if i > 0: L += (rs[i - 1] as Vector2).distance_to(p)
		if L > MAX_LEN or (L > PLAZA_R and _bad(p)): break
		out.append(p)
	if L < 14.0 or out.size() < 6: return
	dirs.append(d0)
	_add_street(out, MAIN_HALF, true)

func _add_street(pts: Array, half: float, main: bool) -> void:
	var cum: Array = [0.0]
	for i in range(1, pts.size()): cum.append(float(cum[i - 1]) + (pts[i - 1] as Vector2).distance_to(pts[i]))
	streets.append({"pts": pts, "half": half, "main": main, "len": cum[cum.size() - 1], "cum": cum})

func point_at(st: Dictionary, s: float) -> Array:
	var pts: Array = st.pts; var cum: Array = st.cum
	s = clamp(s, 0.0, float(st.len))
	for i in range(1, pts.size()):
		if float(cum[i]) >= s:
			var a: Vector2 = pts[i - 1]; var b: Vector2 = pts[i]
			var seg: float = float(cum[i]) - float(cum[i - 1])
			var t: float = (s - float(cum[i - 1])) / max(0.001, seg)
			var tg := (b - a).normalized()
			return [a.lerp(b, t), tg]
	var n: int = pts.size()
	return [pts[n - 1], ((pts[n - 1] as Vector2) - (pts[n - 2] as Vector2)).normalized()]

func _try_lane(st: Dictionary, s0: float, side: float) -> void:
	var pa: Array = point_at(st, s0); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
	var nrm := Vector2(-tg.y, tg.x) * side
	var dir := nrm.rotated(R.randf_range(-0.35, 0.35))
	var p0 := p + nrm * (float(st.half) - 0.2)
	var p1 := p0 + dir * 13.0
	var p2 := p1 + dir.rotated(R.randf_range(-0.7, 0.7)) * 14.0
	var curve: Array = []
	for k in 13:
		var t := k / 12.0
		curve.append(p0.lerp(p1, t).lerp(p1.lerp(p2, t), t))
	var out: Array = []
	for i in curve.size():
		var q: Vector2 = curve[i]
		if _bad(q, 1.0): break
		if i > 2:
			var clash := false
			for o in streets:
				var need: float = float(o.half) + LANE_HALF + 5.0
				if o == st: need = float(o.half) + LANE_HALF + 2.0 if i > 5 else 0.0
				if W.poly_dist(q, o.pts) < need: clash = true; break
			if q.distance_to(V) < PLAZA_R + 6.0: clash = true
			if clash: break
		out.append(q)
	if out.size() >= 6: _add_street(_resample(out, 2.0), LANE_HALF, false)

# distance au bourg (0 = dans une rue ou sur la place)
func town_dist(x: float, z: float) -> float:
	var p := Vector2(x, z)
	if not bbox.has_point(p): return 99.0
	var d := p.distance_to(V) - PLAZA_R
	for st in streets: d = min(d, W.poly_dist(p, st.pts) - float(st.half))
	return max(d, 0.0)

# ================= CONSTRUCTION (après le relief) =================
func build(ST: Dictionary, tname: String) -> void:
	_streets_mesh(ST)
	_plaza(ST, tname)
	_place_houses()
	_build_houses()
	_entrances(ST)
	_lanterns()
	_edge_stones()
	_greenery(ST)

func _tex_mat(tex: String, tint: Color, uvk: float) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(tex); m.albedo_color = tint; m.roughness = 1.0
	m.uv1_scale = Vector3(uvk, uvk, 1.0); m.texture_repeat = true
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _streets_mesh(ST: Dictionary) -> void:
	var cob := SurfaceTool.new(); cob.begin(Mesh.PRIMITIVE_TRIANGLES)
	var dirt := SurfaceTool.new(); dirt.begin(Mesh.PRIMITIVE_TRIANGLES)
	for st in streets:
		var sf: SurfaceTool = cob if st.main else dirt
		var pts: Array = _resample(st.pts, 1.0)
		var hw: float = float(st.half) + (0.3 if st.main else 0.1)
		var s := 0.0
		var rows: Array = []
		for i in pts.size():
			var p: Vector2 = pts[i]
			if i > 0: s += (pts[i - 1] as Vector2).distance_to(p)
			var a: Vector2 = pts[max(0, i - 1)]; var b: Vector2 = pts[min(pts.size() - 1, i + 1)]
			var tg := (b - a).normalized(); var nr := Vector2(-tg.y, tg.x)
			var row: Array = []
			for k in 5:
				var u := -1.0 + k * 0.5
				var q := p + nr * hw * u
				row.append([Vector3(q.x, W.height(q.x, q.y) + 0.06, q.y), Vector2((u + 1.0) * hw * 0.5, s * 0.5)])
			rows.append(row)
		for i in rows.size() - 1:
			for k in 4:
				var A: Array = rows[i][k]; var B: Array = rows[i][k + 1]; var C: Array = rows[i + 1][k + 1]; var D: Array = rows[i + 1][k]
				_tri(sf, A, B, C); _tri(sf, A, C, D)
	for pair in [[cob, _tex_mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color(ST.pave).lightened(0.25), 1.0)], [dirt, _dirt_mat()]]:
		var mi := MeshInstance3D.new(); mi.mesh = (pair[0] as SurfaceTool).commit(); mi.material_override = pair[1]
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; W.add_child(mi)

# triangle toujours tourné vers le ciel (sinon la face est vue de dos et paraît noire)
func _tri(sf: SurfaceTool, A: Array, B: Array, C: Array) -> void:
	var a: Vector3 = A[0]; var b: Vector3 = B[0]; var c: Vector3 = C[0]
	if Vector2(b.x - a.x, b.z - a.z).cross(Vector2(c.x - a.x, c.z - a.z)) < 0.0:
		var t := B; B = C; C = t
	for v in [A, B, C]:
		sf.set_normal(Vector3.UP); sf.set_uv(v[1]); sf.add_vertex(v[0])

func _dirt_mat() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png")
	m.albedo_color = Color("#a0805a"); m.roughness = 1.0; m.uv1_scale = Vector3(0.35, 0.35, 1.0); m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

func _plaza(ST: Dictionary, tname: String) -> void:
	var sf := SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segs := 48; var rings := 5
	var rad := func(a: float) -> float: return PLAZA_R + 1.0 + sin(a * 3.0 + 1.3) * 0.9 + sin(a * 5.0) * 0.5
	var P := func(a: float, f: float) -> Vector3:
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * rad.call(a) * f
		return Vector3(q.x, W.height(q.x, q.y) + 0.07, q.y)
	for i in segs:
		var a0 := TAU * i / segs; var a1 := TAU * (i + 1) / segs
		for r in rings:
			var f0 := float(r) / rings; var f1 := float(r + 1) / rings
			var vs: Array = []
			for v: Vector3 in [P.call(a0, f0), P.call(a1, f0), P.call(a1, f1), P.call(a0, f1)]: vs.append([v, Vector2(v.x, v.z) * 0.5])
			_tri(sf, vs[0], vs[1], vs[2]); _tri(sf, vs[0], vs[2], vs[3])
	var mi := MeshInstance3D.new(); mi.mesh = sf.commit()
	mi.material_override = _tex_mat("res://assets/village/T_Brick_BaseColor.png", Color(ST.pave).lightened(0.2), 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; W.add_child(mi)
	# bordure de pierres
	for i in 36:
		var a := TAU * i / 36.0
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (rad.call(a) + 0.35)
		if _on_street(q, 0.6): continue
		W._mm("res://assets/forest/Rock_1_A_Color1.gltf", Vector3(q.x, 0, q.y), R.randf_range(0.18, 0.26), R.randf() * TAU, Color("#c8c4bc"))
	W.building("res://assets/hex/building_well_blue.gltf", V, 0.0, 3.0, 2.2)
	W.house_spots.append([V, 2.0])
	# arbres et massifs au bord de la place (entre les débouchés des rues)
	var FL := [Color("#f08cd8"), Color("#f7e06a"), Color("#c090d8"), Color("#ffffff")]
	for i in 7:
		var a := TAU * i / 7.0 + 0.45
		if street_opening(a): continue
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R - 0.6)
		var w3 := Vector3(q.x, 0, q.y)
		if i % 2 == 0:
			W.place(ST.tree, w3, R.randf() * TAU, 0.55 if W.map_id <= 2 else 0.75); W.blocker(w3, 0.45); npc_used.append(q)
		for k in 6:
			var fc: Color = FL[R.randi() % FL.size()]; fc.a = 0.98
			W._mm("res://assets/forest/Bush_1_A_Color1.gltf", w3 + Vector3(R.randf_range(-1.1, 1.1), 0, R.randf_range(-1.1, 1.1)), R.randf_range(0.5, 0.75), R.randf() * TAU, fc)
	# tonneaux et caisses autour du puits
	for k in 3:
		var a2 := TAU * k / 3.0 + 0.6
		var q2 := V + Vector2(cos(a2), sin(a2)) * 3.0
		W.place("res://assets/hex/" + ["barrel.gltf", "crate_A_big.gltf", "sack.gltf"][k], Vector3(q2.x, 0, q2.y), a2, 3.2)
	W.label(tname, Vector3(V.x, W.height(V.x, V.y) + 11.0, V.y), Color("#ffe2a0"), 90)

func _on_street(q: Vector2, margin: float) -> bool:
	for st in streets:
		if W.poly_dist(q, st.pts) < float(st.half) + margin: return true
	return false

func street_opening(a: float) -> bool:
	var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R + 2.0)
	return _on_street(q, 1.5)

# ——— emprise des maisons ———
func _corners(c: Vector2, rot: float, w: float, d: float, m: float) -> Array:
	var ax := Vector2(cos(rot), -sin(rot)); var az := Vector2(sin(rot), cos(rot))
	var hw := w * 0.5 + m; var hd := d * 0.5 + m
	var out: Array = []
	for sx: float in [-1.0, -0.5, 0.0, 0.5, 1.0]:
		for sz: float in [-1.0, -0.5, 0.0, 0.5, 1.0]: out.append(c + ax * hw * sx + az * hd * sz)
	return out

func _inside(p: Vector2, h: Dictionary, m: float) -> bool:
	var rot: float = h.rot
	var ax := Vector2(cos(rot), -sin(rot)); var az := Vector2(sin(rot), cos(rot))
	var d := p - (h.c as Vector2)
	return abs(d.dot(ax)) < float(h.w) * 0.5 + m and abs(d.dot(az)) < float(h.d) * 0.5 + m

var why := {}
func _no(k: String) -> bool:
	why[k] = int(why.get(k, 0)) + 1; return false
func _fp_ok(c: Vector2, rot: float, w: float, d: float) -> bool:
	var pts := _corners(c, rot, w, d, 0.4)
	var hmin := 1e9; var hmax := -1e9
	for p: Vector2 in pts:
		if _bad(p): return _no("bad")
		if p.distance_to(V) < PLAZA_R + 0.9: return _no("plaza")
		if _on_street(p, 0.25): return _no("street")
		if not W.walkable(p.x, p.y) or W.raw_height(p.x, p.y) < World.WATER_Y + 0.8: return _no("walk")
		var h: float = W.height(p.x, p.y); hmin = min(hmin, h); hmax = max(hmax, h)
		for o in homes:
			if _inside(p, o, 0.3): return _no("home")
		if W.near_house(p, 0.2): return _no("near_house")
	if hmax - hmin > 1.8: return _no("slope")
	# et dans l'autre sens (une petite maison ne doit pas tomber dans une grande)
	var me := {"c": c, "rot": rot, "w": w, "d": d}
	for o in homes:
		for p: Vector2 in _corners(o.c, o.rot, o.w, o.d, 0.0):
			if _inside(p, me, 0.3): return false
	return true

func _place_houses() -> void:
	homes = []
	# 1) autour de la place, entre les débouchés des rues, façades vers le centre
	var a := 0.0
	while a < TAU - 0.05:
		var w: int = 6 if R.randf() < 0.6 else 4
		var rp := PLAZA_R + 1.6 + 4.0
		var am := a + (w * 0.5 + 0.4) / rp
		var c: Vector2 = V + Vector2(cos(am), sin(am)) * rp
		var to_c := (V - c).normalized()
		var rot := atan2(to_c.x, to_c.y)
		if _fp_ok(c, rot, w, 8.0):
			_add_home(c, rot, w, -1, 0.0, 0.0, true)
			a += (w + R.randf_range(0.6, 1.4)) / rp
		else: a += 0.06
	# 2) le long des rues, des deux côtés
	for si in streets.size():
		var st: Dictionary = streets[si]
		for side: float in [-1.0, 1.0]:
			var s := PLAZA_R + 2.0 if st.main else 2.5
			while s < float(st.len) - 2.0:
				var w: int = [4, 6, 6][R.randi() % 3] if st.main else [4, 4, 6][R.randi() % 3]
				var pa: Array = point_at(st, s + w * 0.5); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
				var nr := Vector2(-tg.y, tg.x) * side
				var c: Vector2 = p + nr * (float(st.half) + 0.9 + 4.0)
				var rot := atan2(-nr.x, -nr.y)
				if _fp_ok(c, rot, w, 8.0):
					_add_home(c, rot, w, si, s + w * 0.5, side, false)
					var gap := R.randf_range(0.5, 1.6)
					if R.randf() < 0.18: gap = R.randf_range(3.5, 6.0)     # un jardin, une venelle
					s += w + gap
				else: s += 1.0

# maisons de seconde ligne : un peu en retrait, chacune avec un accès dégagé vers la rue la plus proche
func _infill(n: int) -> void:
	var made := 0
	for k in 600:
		if made >= n: break
		var q := Vector2(R.randf_range(bbox.position.x + 20, bbox.end.x - 20), R.randf_range(bbox.position.y + 20, bbox.end.y - 20))
		var td := town_dist(q.x, q.y)
		if td < 6.0 or td > 13.0: continue
		# point de rue le plus proche
		var best := Vector2.ZERO; var bd := 1e9; var bsi := -1
		for si in streets.size():
			for p: Vector2 in streets[si].pts:
				if p.distance_to(q) < bd: bd = p.distance_to(q); best = p; bsi = si
		var to := (best - q).normalized()
		var rot := atan2(to.x, to.y)
		var w: int = 4 if R.randf() < 0.6 else 6
		if not _fp_ok(q, rot, w, 8.0): continue
		# l'accès à la rue ne doit pas traverser une maison
		var front: Vector2 = q + to * 4.6
		var ok := true
		for t in 6:
			var pp: Vector2 = front.lerp(best, t / 5.0)
			for h in homes:
				if _inside(pp, h, 0.3): ok = false; break
			if not ok: break
		if not ok: continue
		_add_home(q, rot, w, -1, 0.0, 0.0, false)
		made += 1

func _add_home(c: Vector2, rot: float, w: int, si: int, s: float, side: float, plaza: bool) -> void:
	var az := Vector2(sin(rot), cos(rot))
	var ldx := -w * 0.5 + 1 + int(w / 4) * 2
	var ax := Vector2(cos(rot), -sin(rot))
	var door: Vector2 = c + az * (4.0 + 0.35) + ax * ldx
	var out: Vector2 = c + az * (4.0 + 1.9) + ax * ldx
	homes.append({"c": c, "rot": rot, "w": w, "d": 8.0, "street": si, "s": s, "side": side, "door": door, "out": out, "plaza": plaza, "used": false,
		"fl": 1 + (R.randi() % 3 if plaza or (si >= 0 and streets[si].main and s < 30.0) else R.randi() % 2)})

func _build_houses() -> void:
	_infill(10)
	for h in homes:
		W.house(h.c, h.rot, h.w, h.fl, "plaster" if R.randf() < 0.55 else "brick", true)

# ——— entrées de la ville : piliers, bannières, lanternes, gardes ———
func _entrances(ST: Dictionary) -> void:
	entrances = []
	var gi := 0
	for st in streets:
		if not st.main: continue
		var pa: Array = point_at(st, float(st.len) - 1.0); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
		var nr := Vector2(-tg.y, tg.x)
		entrances.append({"p": p, "dir": tg, "st": st})
		for sd: float in [-1.0, 1.0]:
			var q: Vector2 = p + nr * sd * (float(st.half) + 1.0)
			var rot := atan2(tg.x, tg.y)
			W.place("res://assets/halloween/lantern_standing.gltf", Vector3(q.x, 0, q.y), rot, 1.7); W.blocker(Vector3(q.x, 0, q.y), 0.3)
			W._light(Vector3(q.x, W.height(q.x, q.y) + 2.6, q.y), Color("#ffbf66"), 2.0, 2.4)
			var bq: Vector2 = q + nr * sd * 3.0 - tg * 0.4
			W.place("res://assets/dungeon/" + str(ST.banner) + ".gltf", Vector3(bq.x, 0, bq.y), rot + PI * 0.5, 1.0)
			# murets de pierre qui partent des piliers
			for k in 3:
				var wq: Vector2 = q + nr * sd * (1.6 + k * 2.0)
				if _bad(wq) or not W.walkable(wq.x, wq.y): break
				var wr := atan2(nr.x, nr.y) + PI * 0.5
				var y: float = W.height(wq.x, wq.y) - 0.1
				W._mm_xf(World._V + "Wall_UnevenBrick_Straight.gltf", Transform3D(Basis(Vector3.UP, wr).scaled(Vector3(1.0, 0.45, 1.0)), Vector3(wq.x, y, wq.y)))
				W.box_blocker(Vector3(wq.x, 0, wq.y), Vector3(2.05, 1.6, 0.5), wr)
			# gardes (seulement aux grandes entrées, un de chaque côté)
			if float(st.len) < 34.0: continue
			var gq: Vector2 = p + nr * sd * (float(st.half) - 0.9) - tg * 1.2
			W.npc_spots.append({"id": "garde_%d_%d" % [W.map_id, gi], "model": "Knight", "name": World.GUARD_NAMES[(gi + W.map_id * 3) % World.GUARD_NAMES.size()], "role": "Garde de la ville", "pos": Vector3(gq.x, 0, gq.y), "act": "guard", "yaw": atan2(tg.x, tg.y)})
			npc_used.append(gq); gi += 1

func _edge_stones() -> void:
	for st in streets:
		var s := 1.0
		var hw: float = float(st.half) + (0.45 if st.main else 0.25)
		while s < float(st.len):
			var pa: Array = point_at(st, s); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
			for sd: float in [-1.0, 1.0]:
				var q: Vector2 = p + Vector2(-tg.y, tg.x) * sd * hw
				if q.distance_to(V) < PLAZA_R + 1.5 or _on_street(q, 0.1): continue
				var hit := false
				for h in homes:
					if _inside(q, h, 0.1) or q.distance_to(h.out) < 1.1: hit = true; break
				if hit: continue
				W._mm("res://assets/forest/Rock_1_A_Color1.gltf", Vector3(q.x, 0, q.y), R.randf_range(0.3, 0.42) if st.main else R.randf_range(0.22, 0.32), R.randf() * TAU, Color("#c8c4bc"))
			s += R.randf_range(1.2, 2.2) if st.main else R.randf_range(2.0, 3.5)

func _lanterns() -> void:
	var n := 0
	for st in streets:
		if not st.main: continue
		var s := 8.0; var side := 1.0
		while s < float(st.len) - 6.0:
			var pa: Array = point_at(st, s); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
			var q: Vector2 = p + Vector2(-tg.y, tg.x) * side * (float(st.half) + 0.2)
			var ok := true
			for h in homes:
				if _inside(q, h, 0.4) or q.distance_to(h.out) < 1.6: ok = false; break
			if ok:
				W.place("res://assets/halloween/lantern_standing.gltf", Vector3(q.x, 0, q.y), 0.0, 1.5); W.blocker(Vector3(q.x, 0, q.y), 0.25)
				W._light(Vector3(q.x, W.height(q.x, q.y) + 2.4, q.y), Color("#ffbf66"), 2.0, 2.4); n += 1
			s += 15.0; side = -side

# ——— verdure : arbres entre les maisons, jardins à l'arrière, fleurs devant les portes, tonneaux ———
func _greenery(ST: Dictionary) -> void:
	var F := "res://assets/forest/"
	var FL := [Color("#f08cd8"), Color("#f7e06a"), Color("#c090d8"), Color("#ffffff"), Color("#ff8a7a")]
	if W.map_id == 3: FL = [Color("#ffb070"), Color("#f7e06a"), Color("#ffffff")]
	if W.map_id == 4: FL = [Color("#9a7ac0"), Color("#c0c0d0"), Color("#7a9a8a")]
	# devant les portes
	for h in homes:
		var az := Vector2(sin(h.rot), cos(h.rot)); var ax := Vector2(cos(h.rot), -sin(h.rot))
		var roll := R.randf()
		var sidep: Vector2 = (h.door as Vector2) + az * 0.6 + ax * (1.3 if R.randf() < 0.5 else -1.3)
		if _on_street(sidep, 0.2): continue
		if roll < 0.3: W.place("res://assets/hex/" + ["barrel.gltf", "crate_A_big.gltf", "sack.gltf"][R.randi() % 3], Vector3(sidep.x, 0, sidep.y), R.randf() * TAU, 3.0)
		elif roll < 0.6:
			for k in 4:
				var fc: Color = FL[R.randi() % FL.size()]; fc.a = 0.98
				W._mm(F + "Bush_1_A_Color1.gltf", Vector3(sidep.x + R.randf_range(-0.5, 0.5), 0, sidep.y + R.randf_range(-0.4, 0.4)), R.randf_range(0.5, 0.7), R.randf() * TAU, fc)
	# arbres et jardins dans les trous entre les maisons et derrière
	var veg := ["chou", "carotte", "citrouille", "salade", "tomate"] if W.map_id != 3 else ["pasteque", "melon", "poivron"]
	var placed := 0
	for i in 900:
		if placed > 46: break
		var q := Vector2(R.randf_range(bbox.position.x, bbox.end.x), R.randf_range(bbox.position.y, bbox.end.y))
		var td := town_dist(q.x, q.y)
		if td < 1.2 or td > 16.0: continue
		if q.distance_to(V) < PLAZA_R + 2.0 or _bad(q) or not W.walkable(q.x, q.y) or W.road_dist(q.x, q.y) < 3.4: continue
		var nearb := false
		for b in W.bridges:
			if W.seg_dist(q, b.a, b.b) < 7.0: nearb = true
		if nearb: continue
		var hit := false
		for h in homes:
			if _inside(q, h, 1.2) or q.distance_to(h.out) < 2.2: hit = true; break
		if hit or W.near_house(q, 0.8): continue
		var w3 := Vector3(q.x, 0, q.y)
		var roll := R.randf()
		if roll < 0.45:
			W.place(ST.tree, w3, R.randf() * TAU, R.randf_range(0.6, 0.9) if W.map_id <= 2 else R.randf_range(0.8, 1.0)); W.blocker(w3, 0.5); W.house_spots.append([q, 1.6])
			for k in 3: W._mm(F + ["Grass_1_C_Color1.gltf", "Bush_1_E_Color1.gltf"][k % 2], w3 + Vector3(R.randf_range(-1.4, 1.4), 0, R.randf_range(-1.4, 1.4)), R.randf_range(0.7, 1.1), R.randf() * TAU)
		elif roll < 0.62:
			# petit potager
			for k in 6:
				var v := Crops.food_model(veg[R.randi() % veg.size()], 0.5)
				var vx := q.x + (k % 3) * 0.8; var vz := q.y + int(k / 3) * 0.8
				v.position = Vector3(vx, W.height(vx, vz) + 0.05, vz); v.rotation.y = R.randf() * TAU; W.add_child(v)
			W.house_spots.append([q + Vector2(0.8, 0.4), 1.6])
		elif roll < 0.72: W.place("res://assets/hex/building_grain.gltf", w3, R.randf() * TAU, 1.1); W.blocker(w3, 0.8); W.house_spots.append([q, 1.3])
		else:
			for k in 6:
				var fc: Color = FL[R.randi() % FL.size()]; fc.a = 0.98
				W._mm(F + ("Bush_1_A_Color1.gltf" if k % 3 else "Grass_1_C_Color1.gltf"), w3 + Vector3(R.randf_range(-1.2, 1.2), 0, R.randf_range(-1.2, 1.2)), R.randf_range(0.55, 0.85), R.randf() * TAU, fc)
		placed += 1

# ================= PLACES DES PNJ =================
func _free_npc(p: Vector2, r := 4.0) -> bool:
	for q: Vector2 in npc_used:
		if q.distance_to(p) < r: return false
	return true

# sur la place, au bord, en évitant les rues ; regarde le centre
func plaza_slot(a_pref: float) -> Array:
	for k in 64:
		var a := a_pref + (k / 2) * 0.13 * (1.0 if k % 2 == 0 else -1.0)
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R - 2.2)
		if street_opening(a) or not _free_npc(q, 4.5): continue
		npc_used.append(q)
		var to_c := (V - q).normalized()
		return [Vector3(q.x, 0, q.y), atan2(to_c.x, to_c.y), a]
	var q2 := V + Vector2(cos(a_pref), sin(a_pref)) * 4.0
	npc_used.append(q2)
	return [Vector3(q2.x, 0, q2.y), 0.0, a_pref]

# devant la porte d'une maison, à une distance donnée du centre ; regarde la rue
func door_slot(dmin: float, dmax: float, avoid_street := -2) -> Array:
	var best = null; var bd := 1e9
	var mid := (dmin + dmax) * 0.5
	for h in homes:
		if h.used: continue
		if avoid_street >= -1 and h.street == avoid_street: continue
		var d: float = (h.out as Vector2).distance_to(V)
		if d < dmin or d > dmax or not _free_npc(h.out, 7.0): continue
		var score: float = abs(d - mid) + R.randf() * 3.0
		if score < bd: bd = score; best = h
	if best == null:
		for h in homes:
			if not h.used and _free_npc(h.out, 5.0): best = h; break
	if best == null: return plaza_slot(R.randf() * TAU)
	best.used = true
	var q: Vector2 = (best.out as Vector2)
	npc_used.append(q)
	var fwd: Vector2 = (best.out as Vector2) - (best.door as Vector2)
	return [Vector3(q.x, 0, q.y), atan2(fwd.x, fwd.y), best]

# promenade le long d'une rue (et retour)
func street_walk(si: int, s0: float, s1: float) -> Array:
	var st: Dictionary = streets[clamp(si, 0, streets.size() - 1)]
	var out: Array = []
	var s := s0
	while s <= s1:
		var pa: Array = point_at(st, s); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
		out.append(p + Vector2(-tg.y, tg.x) * 0.8); s += 6.0
	var back := out.duplicate(); back.reverse()
	return out + back.slice(1)

# habitants : de leur porte à la place, puis chez le voisin
func residents(n: int) -> void:
	var cand := homes.filter(func(h): return h.street >= 0 and not h.used)
	if cand.size() < 2: return
	for i in n:
		var a: Dictionary = cand[R.randi() % cand.size()]; var b: Dictionary = cand[R.randi() % cand.size()]
		if a == b: continue
		var path: Array = [a.door, a.out]
		var sa: Dictionary = streets[a.street]; var sb: Dictionary = streets[b.street]
		var s := float(a.s)
		while s > PLAZA_R + 1.0:
			var pa: Array = point_at(sa, s); path.append(pa[0]); s -= 7.0
		path.append(V + ((path[path.size() - 1] as Vector2) - V).normalized() * (PLAZA_R - 3.0))
		var sb_pts: Array = []
		s = PLAZA_R + 1.0
		while s < float(b.s):
			var pb: Array = point_at(sb, s); sb_pts.append(pb[0]); s += 7.0
		if not sb_pts.is_empty(): path.append(V + ((sb_pts[0] as Vector2) - V).normalized() * (PLAZA_R - 3.0))
		path += sb_pts
		path.append(b.out); path.append(b.door)
		var back := path.duplicate(); back.reverse()
		var full: Array = path + back.slice(1, back.size() - 1)
		var di := [0, path.size() - 1]
		var k: int = i + int(W.map_id) * 3
		W.npc_spots.append({"id": "habitant_%d_%d" % [W.map_id, i], "model": ["Rogue", "Ranger", "Barbarian", "Mage", "Knight"][k % 5], "name": World.RESIDENT_NAMES[k % World.RESIDENT_NAMES.size()],
			"role": World.RESIDENT_ROLES[k % World.RESIDENT_ROLES.size()], "pos": Vector3((a.out as Vector2).x, 0, (a.out as Vector2).y), "act": "villager", "path": full, "doors": di, "start": 1})


# étals de marché sans marchand (fruits et légumes du pack), dans les coins libres de la place
func market(n: int) -> void:
	var veg := ["pomme", "carotte", "chou", "citrouille", "tomate", "poire", "mais"] if W.map_id != 3 else ["pasteque", "melon", "figue", "citron", "poivron"]
	var made := 0
	for k in 24:
		if made >= n: break
		var a := R.randf() * TAU
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R - 2.6)
		if street_opening(a) or not _free_npc(q, 4.2) or q.distance_to(V) < 3.5: continue
		npc_used.append(q)
		var to_c := (V - q).normalized(); var yaw := atan2(to_c.x, to_c.y)
		var f := Vector3(to_c.x, 0, to_c.y); var sd := Vector3(cos(yaw), 0, -sin(yaw))
		var p3 := Vector3(q.x, 0, q.y)
		W.place("res://assets/dungeon/table_medium_decorated_A.gltf", p3, yaw, 0.85); W.blocker(p3, 0.9)
		for j in 2:
			var cq: Vector3 = p3 + sd * (1.5 if j == 0 else -1.5) - f * 0.3
			var crate: Node3D = load("res://assets/food/crate.glb").instantiate(); crate.scale = Vector3.ONE * 1.5
			for mi in crate.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).material_override = Crops.pix_mat()
			crate.position = Vector3(cq.x, W.height(cq.x, cq.z), cq.z); crate.rotation.y = yaw; W.add_child(crate)
			var kind: String = veg[R.randi() % veg.size()]
			for v in 4:
				var fm := Crops.food_model(kind, 0.3)
				fm.position = Vector3(cq.x + R.randf_range(-0.28, 0.28), W.height(cq.x, cq.z) + 0.75, cq.z + R.randf_range(-0.28, 0.28)); fm.rotation.y = R.randf() * TAU
				W.add_child(fm)
		W.place("res://assets/hex/sack.gltf", p3 - f * 1.2 + sd * 0.6, yaw, 2.6)
		made += 1
	# une charrette près de la place
	for k in 12:
		var a2 := R.randf() * TAU
		var q2: Vector2 = V + Vector2(cos(a2), sin(a2)) * (PLAZA_R - 1.4)
		if street_opening(a2) or not _free_npc(q2, 3.5): continue
		W.place(World._V + "Prop_Wagon.gltf", Vector3(q2.x, 0, q2.y), a2 + PI * 0.5, 0.9); W.blocker(Vector3(q2.x, 0, q2.y), 1.1)
		npc_used.append(q2); break
