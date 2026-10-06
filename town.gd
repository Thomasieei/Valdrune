extends RefCounted
class_name TownGen
# Bourg organique : les rues suivent les vraies routes qui partent de la ville, des ruelles s'en échappent,
# les maisons s'alignent le long des rues (portes côté rue), une place irrégulière au centre,
# jardins, arbres, lanternes, et chaque habitant a SON coin (pas tous au même endroit).

const PLAZA_R := 10.0
const MAIN_HALF := 2.8
const LANE_HALF := 1.7
const MAX_LEN := 58.0
const PLOT_D := 11.0

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
	# Ville dessinée : une place centrale, et jusqu'à 4 grandes rues droites en croix, alignées sur la route principale.
	# Les routes du monde s'arrêtent aux portes de la ville (au bout des grandes rues) au lieu de la traverser.
	var ang := _main_axis()
	# le sanctuaire d'enchantement entre dans la ville : un quartier à lui, entre deux grandes rues
	for pd in W.POI_DEFS:
		if str(pd.get("kind", "")) != "enchant" or (pd.p as Vector2).distance_to(V) > AVE_LEN + 14.0: continue
		for k2 in 8:
			var q: Vector2 = V + Vector2(cos(ang + PI * 0.25 + k2 * PI * 0.5), sin(ang + PI * 0.25 + k2 * PI * 0.5)) * 42.0
			if W.raw_height(q.x, q.y) > World.WATER_Y + 1.0 and W.river_dist(q.x, q.y) > World.RIVER_W + 8.0:
				pd.p = q; break
	for k in 4:
		var d := Vector2(cos(ang + k * PI * 0.5), sin(ang + k * PI * 0.5))
		var L := PLAZA_R
		while L < AVE_LEN:
			var q: Vector2 = V + d * (L + 2.0)
			if _bad(q, 2.0) or W.raw_height(q.x, q.y) < World.WATER_Y + 0.9: break
			L += 2.0
		if L < PLAZA_R + 16.0: continue
		var pts: Array = []
		var t := 0.0
		while t <= L + 0.01: pts.append(V + d * t); t += 2.0
		_add_street(pts, MAIN_HALF, true)
	bbox = Rect2(V - Vector2(PLAZA_R, PLAZA_R), Vector2(PLAZA_R, PLAZA_R) * 2.0)
	for st in streets:
		for p: Vector2 in st.pts: bbox = bbox.expand(p)
	bbox = bbox.grow(30.0)
	_reroute_roads()

const AVE_LEN := 48.0
# l'axe de la ville suit la route qui part le plus loin du centre
func _main_axis() -> float:
	var best := 0.0; var ang := -PI * 0.5
	for rd in W.roads:
		var pts: Array = rd
		var near := false
		for p: Vector2 in pts:
			if p.distance_to(V) < 8.0: near = true; break
		if not near: continue
		for p: Vector2 in pts:
			var dv := p.distance_to(V)
			if dv > 24.0 and dv < 44.0 and dv > best:
				best = dv; ang = atan2(p.y - V.y, p.x - V.x)
	return ang

# les routes s'arrêtent aux portes : on coupe ce qui traverse la ville et on rejoint la porte la plus proche
func _reroute_roads() -> void:
	if streets.is_empty(): return
	var gates: Array = []
	var Rt := PLAZA_R
	for st in streets:
		gates.append(st.pts[st.pts.size() - 1]); Rt = max(Rt, float(st.len))
	Rt += 3.0
	var link := func(c: Vector2) -> Vector2:
		var order := gates.duplicate()
		order.sort_custom(func(a1, b1): return (a1 as Vector2).distance_to(c) < (b1 as Vector2).distance_to(c))
		for g: Vector2 in order:
			if not W._crosses_water(c, g): return g
		return order[0]      # sinon la porte la plus proche : un pont sera construit sur la traversée
	var out: Array = []
	for rd in W.roads:
		var pts: Array = rd
		var inside_any := false
		for p: Vector2 in pts:
			if p.distance_to(V) <= Rt: inside_any = true; break
		if not inside_any: out.append(pts); continue
		var cur: Array = []
		for i in pts.size():
			var p: Vector2 = pts[i]
			var ins := p.distance_to(V) <= Rt
			if i > 0:
				var pv: Vector2 = pts[i - 1]
				var was := pv.distance_to(V) <= Rt
				if was != ins:
					var c := _circle_cross(pv, p, Rt)
					var g: Vector2 = link.call(c)
					if ins:
						cur.append(c)
						if g != c: cur.append(g)
						if cur.size() >= 2: out.append(cur)
						cur = []
					else:
						if g != c: cur.append(g)
						cur.append(c)
			if not ins: cur.append(p)
		if cur.size() >= 2: out.append(cur)
	W.roads = out
	W._seg_n = -1
	if OS.get_cmdline_user_args().has("shot"): print("REROUTE Rt ", Rt, " gates ", gates, " roads ", out.size())

func _circle_cross(a: Vector2, b: Vector2, r: float) -> Vector2:
	var lo := 0.0; var hi := 1.0
	var a_in := a.distance_to(V) <= r
	for k in 20:
		var m := (lo + hi) * 0.5
		if (a.lerp(b, m).distance_to(V) <= r) == a_in: lo = m
		else: hi = m
	return a.lerp(b, (lo + hi) * 0.5)

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
	_gate_towers(ST)
	_street_signs()
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
	var rad := func(a: float) -> float: return PLAZA_R + 1.2     # place bien ronde
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
	# anneaux de pavés sombres (motif de la place ronde)
	var sr := SurfaceTool.new(); sr.begin(Mesh.PRIMITIVE_TRIANGLES)
	for band: Vector2 in [Vector2(3.3, 3.9), Vector2(PLAZA_R - 0.3, PLAZA_R + 0.3)]:
		for i in 64:
			var a0 := TAU * i / 64; var a1 := TAU * (i + 1) / 64
			var vs: Array = []
			for pr: Vector2 in [Vector2(a0, band.x), Vector2(a1, band.x), Vector2(a1, band.y), Vector2(a0, band.y)]:
				var q: Vector2 = V + Vector2(cos(pr.x), sin(pr.x)) * pr.y
				vs.append([Vector3(q.x, W.height(q.x, q.y) + 0.09, q.y), q * 0.5])
			_tri(sr, vs[0], vs[1], vs[2]); _tri(sr, vs[0], vs[2], vs[3])
	var ri := MeshInstance3D.new(); ri.mesh = sr.commit()
	ri.material_override = _tex_mat("res://assets/village/T_Brick_BaseColor.png", Color(ST.pave).darkened(0.35), 1.0)
	ri.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; W.add_child(ri)
	_fountain()
	W.house_spots.append([V, 2.6])
	# bancs autour de la fontaine
	for k in 4:
		var ab := TAU * k / 4.0 + PI * 0.25
		var bq: Vector2 = V + Vector2(cos(ab), sin(ab)) * 4.6
		_bench(bq, atan2(V.x - bq.x, V.y - bq.y))
	# arbres et massifs au bord de la place (entre les débouchés des rues)
	var FL := [Color("#f08cd8"), Color("#f7e06a"), Color("#c090d8"), Color("#ffffff")]
	for i in 7:
		var a := TAU * i / 7.0 + 0.45
		if street_opening(a): continue
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R - 0.6)
		var w3 := Vector3(q.x, 0, q.y)
		if i % 2 == 0:
			W.place(ST.tree, w3, R.randf() * TAU, 0.55 if W.map_id <= 2 else 0.75); W.blocker(w3, 0.45); npc_used.append(q)
		for k in 3:
			var fc: Color = FL[R.randi() % FL.size()]; fc.a = 0.98
			W._mm("res://assets/forest/Bush_1_A_Color1.gltf", w3 + Vector3(R.randf_range(-1.1, 1.1), 0, R.randf_range(-1.1, 1.1)), R.randf_range(0.5, 0.75), R.randf() * TAU, fc)
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
	return abs(d.dot(ax)) < float(h.get("pw", h.w)) * 0.5 + m and abs(d.dot(az)) < float(h.get("pd", h.d)) * 0.5 + m

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
	if hmax - hmin > (2.8 if d > 9.0 else 1.8): return _no("slope")
	# et dans l'autre sens (une petite maison ne doit pas tomber dans une grande)
	var me := {"c": c, "rot": rot, "w": w, "d": d}
	for o in homes:
		for p: Vector2 in _corners(o.c, o.rot, o.get("pw", o.w), o.get("pd", o.d), 0.0):
			if _inside(p, me, 0.3): return false
	return true

func _place_houses() -> void:
	homes = []
	# 1) autour de la place, entre les débouchés des rues, façades vers le centre
	var a := 0.0
	while a < TAU - 0.05:
		var w: int = 6
		var rp := PLAZA_R + 1.6 + 5.6
		var am := a + (w * 0.5 + 0.4) / rp
		var c: Vector2 = V + Vector2(cos(am), sin(am)) * rp
		var to_c := (V - c).normalized()
		var rot := atan2(to_c.x, to_c.y)
		if _fp_ok(c, rot, w, 8.0):
			_add_home(c, rot, w, -1, 0.0, 0.0, true)
			a += (w + 0.6) / rp
		else: a += 0.06
	# 2) le long des rues, des deux côtés
	for si in streets.size():
		var st: Dictionary = streets[si]
		for side: float in [-1.0, 1.0]:
			var s := PLAZA_R + 7.0 if st.main else 2.5
			while s < float(st.len) - 2.0:
				var w: int = 6
				var pw: float = w + 2.0
				var pa: Array = point_at(st, s + pw * 0.5); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
				var nr := Vector2(-tg.y, tg.x) * side
				# chaque maison a sa parcelle : cour devant, jardin derrière, murets ou haies autour
				var c: Vector2 = p + nr * (float(st.half) + 1.0 + PLOT_D * 0.5)
				var rot := atan2(-nr.x, -nr.y)
				if _fp_ok(c, rot, pw, PLOT_D):
					_add_home(c, rot, w, si, s + pw * 0.5, side, false, true)
					s += pw + 1.0
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
		if not _fp_ok(q, rot, w + 2.0, PLOT_D): continue
		# l'accès à la rue ne doit pas traverser une maison
		var front: Vector2 = q + to * (PLOT_D * 0.5 + 0.6)
		var ok := true
		for t in 6:
			var pp: Vector2 = front.lerp(best, t / 5.0)
			for h in homes:
				if _inside(pp, h, 0.3): ok = false; break
			if not ok: break
		if not ok: continue
		_add_home(q, rot, w, -1, 0.0, 0.0, false, true)
		homes[homes.size() - 1]["path_to"] = best
		made += 1

func _add_home(c: Vector2, rot: float, w: int, si: int, s: float, side: float, plaza: bool, plot := false, kind := "house") -> void:
	var az := Vector2(sin(rot), cos(rot))
	var ldx := -w * 0.5 + 1 + int(w / 4) * 2
	var ax := Vector2(cos(rot), -sin(rot))
	var hc: Vector2 = c - az * ((PLOT_D - 8.0) * 0.5) if plot else c    # dans sa parcelle, la maison recule : grande cour devant
	var door: Vector2 = hc + az * (4.0 + 0.35) + ax * ldx
	var out: Vector2 = hc + az * (4.0 + 1.9) + ax * ldx
	var hm := {"c": c, "rot": rot, "w": w, "d": 8.0, "street": si, "s": s, "side": side, "door": door, "out": out, "plaza": plaza, "used": false, "kind": kind,
		"fl": (3 if homes.size() % 2 == 0 else 2) if plaza else (2 if s < 32.0 else 1 + homes.size() % 2)}
	hm["hc"] = hc
	if plot: hm["pw"] = w + 2.0; hm["pd"] = PLOT_D; hm["plot"] = true
	homes.append(hm)

func _build_houses() -> void:
	_assign_services()
	var paths: Array = []
	var hi := 0
	for h in homes:
		W.house(h.hc, h.rot, h.w, h.fl, "brick" if hi % 3 == 0 else "plaster", true); hi += 1
		if h.get("plot", false): paths.append(_build_plot(h))
	# allées de terre : de la porte jusqu'à la rue
	var sf := SurfaceTool.new(); sf.begin(Mesh.PRIMITIVE_TRIANGLES)
	for pr in paths:
		var a: Vector2 = pr[0]; var b: Vector2 = pr[1]
		var L := a.distance_to(b)
		if L < 0.5: continue
		var dir := (b - a) / L; var nr := Vector2(-dir.y, dir.x) * 0.65
		var n := int(L / 1.0) + 1
		for k in n:
			var p0 := a.lerp(b, float(k) / n); var p1 := a.lerp(b, float(k + 1) / n)
			var vs: Array = []
			for q: Vector2 in [p0 - nr, p0 + nr, p1 + nr, p1 - nr]: vs.append([Vector3(q.x, W.height(q.x, q.y) + 0.05, q.y), q * 0.5])
			_tri(sf, vs[0], vs[1], vs[2]); _tri(sf, vs[0], vs[2], vs[3])
	var mi := MeshInstance3D.new(); mi.mesh = sf.commit(); mi.material_override = _dirt_mat()
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; W.add_child(mi)

# parcelle : muret de pierres sèches ou haie, ouverte devant la porte, et une cour vivante
func _build_plot(h: Dictionary) -> Array:
	var rot: float = h.rot; var c: Vector2 = h.c
	var ax := Vector2(cos(rot), -sin(rot)); var az := Vector2(sin(rot), cos(rot))
	var hx: float = float(h.pw) * 0.5; var hz: float = float(h.pd) * 0.5
	var ldx: float = -float(h.w) * 0.5 + 1 + int(h.w / 4) * 2
	var hedge := false
	var hedge_col := Color(1, 1, 1) if W.map_id != 3 else Color(0.9, 0.85, 0.55)
	var piece := func(lx: float, lz: float, side_rot: float) -> void:
		var q: Vector2 = c + ax * lx + az * lz
		if _on_street(q, 0.2): return
		var r := rot + side_rot
		if hedge:
			for k in 2:
				var hq: Vector2 = q + Vector2(cos(r), -sin(r)) * (-0.5 + k)
				W._mm("res://assets/forest/Bush_1_E_Color1.gltf", Vector3(hq.x, 0, hq.y), R.randf_range(0.75, 0.95), R.randf() * TAU, hedge_col)
		else:
			var y: float = W.height(q.x, q.y) - 0.08
			W._mm_xf(World._V + "Wall_UnevenBrick_Straight.gltf", Transform3D(Basis(Vector3.UP, r).scaled(Vector3(1.0, 0.24, 0.8)), Vector3(q.x, y, q.y)))
		W.box_blocker(Vector3(q.x, 0, q.y), Vector3(2.0, 0.9, 0.45), r)
		W.plot_walls.append([q - Vector2(cos(r), -sin(r)), q + Vector2(cos(r), -sin(r))])
	# côtés et fond
	var nx := int(round(hx * 2.0 / 2.0)); var nz := int(round(hz * 2.0 / 2.0))
	for i in nx:
		var lx := -hx + 1.0 + i * 2.0
		piece.call(lx, -hz, PI)
		if abs(lx - ldx) > 1.9: piece.call(lx, hz, 0.0)      # devant : on laisse le passage vers la porte
	for i in nz:
		var lz := -hz + 1.0 + i * 2.0
		piece.call(hx, lz, PI * 0.5); piece.call(-hx, lz, -PI * 0.5)
	if h.kind != "house":
		_service_yard(h, c, ax, az, hx, hz, ldx)
		var gate0: Vector2 = c + ax * ldx + az * hz
		return [h.out, gate0 + az * 0.8]
	# la cour : sobre — deux bacs à fleurs de part et d'autre de l'allée, ou un arbre, selon la maison
	var FLW := [Color("#f08cd8"), Color("#f7e06a"), Color("#ffffff")] if W.map_id != 3 else [Color("#ffb070"), Color("#f7e06a")]
	if int(abs(c.x * 3.0 + c.y * 7.0)) % 3 == 0:
		var tq: Vector2 = c + ax * (hx - 1.3) * (1.0 if ldx < 0 else -1.0) + az * (hz - 1.4)
		W.place(World.TOWN_STYLE.get(W.map_id, World.TOWN_STYLE[1]).tree, Vector3(tq.x, 0, tq.y), rot, 0.55); W.blocker(Vector3(tq.x, 0, tq.y), 0.4)
	else:
		for sd: float in [-1.0, 1.0]:
			var fq: Vector2 = c + ax * (ldx + sd * 1.3) + az * (hz - 0.8)
			for k in 2:
				var fc: Color = FLW[(k + int(sd)) % FLW.size()]; fc.a = 0.98
				W._mm("res://assets/forest/Bush_1_A_Color1.gltf", Vector3(fq.x + k * 0.35 - 0.15, 0, fq.y), 0.5, rot, fc)
	# allée : porte → portail → bord de la rue
	var gate: Vector2 = c + ax * ldx + az * hz
	var road_pt: Vector2 = gate + az * 0.8
	if h.has("path_to"): road_pt = h.path_to
	return [h.out, road_pt]


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
		if not st.main: continue      # ruelles : pas de bordures (plus sobre)
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
			s += R.randf_range(2.2, 3.4)

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
		if roll < 0.12: W.place("res://assets/hex/" + ["barrel.gltf", "crate_A_big.gltf", "sack.gltf"][R.randi() % 3], Vector3(sidep.x, 0, sidep.y), R.randf() * TAU, 3.0)
		elif roll < 0.3:
			for k in 4:
				var fc: Color = FL[R.randi() % FL.size()]; fc.a = 0.98
				W._mm(F + "Bush_1_A_Color1.gltf", Vector3(sidep.x + R.randf_range(-0.5, 0.5), 0, sidep.y + R.randf_range(-0.4, 0.4)), R.randf_range(0.5, 0.7), R.randf() * TAU, fc)
	# arbres et jardins dans les trous entre les maisons et derrière
	var veg := ["chou", "carotte", "citrouille", "salade", "tomate"] if W.map_id != 3 else ["pasteque", "melon", "poivron"]
	var placed := 0
	for i in 900:
		if placed > 14: break
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
		if td < 7.0: continue
		if roll >= 0.45: continue
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
		var a := TAU * float(k * 7 % 24) / 24.0 + 0.13    # répartis en couronne
		var q: Vector2 = V + Vector2(cos(a), sin(a)) * (PLAZA_R - 2.6)
		if street_opening(a) or not _free_npc(q, 4.2) or q.distance_to(V) < 3.5: continue
		npc_used.append(q)
		var to_c := (V - q).normalized(); var yaw := atan2(to_c.x, to_c.y)
		var f := Vector3(to_c.x, 0, to_c.y); var sd := Vector3(cos(yaw), 0, -sin(yaw))
		var p3 := Vector3(q.x, 0, q.y)
		W.place("res://assets/dungeon/table_medium_decorated_A.gltf", p3, yaw, 0.85); W.blocker(p3, 0.9)
		awning(q - to_c * 0.3, yaw, 3.6, 2.6, [Color("#b0352a"), Color("#2f6fb0"), Color("#3c7a3a")][made % 3], Color("#f0e6d0"))
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


# ================= LIEUX DE SERVICE : chacun a SON endroit, reconnaissable de loin =================
var artisan_si := -1
func _assign_services() -> void:
	var taken: Array = []
	var dist := func(h) -> float: return (h.c as Vector2).distance_to(V)
	var take := func(h: Dictionary, kind: String) -> void: h.kind = kind; taken.append(h)
	# hôtel des ventes : la plus grande maison de la place
	var best = null
	for h in homes:
		if h.plaza and (best == null or dist.call(h) < dist.call(best)): best = h
	if best != null: take.call(best, "auction")
	# rue des artisans : la plus longue grande rue ; forge, scierie et tannerie côte à côte
	var bl := 0.0
	for si in streets.size():
		if streets[si].main and float(streets[si].len) > bl: bl = float(streets[si].len); artisan_si = si
	var by_s := func(a1, b1) -> bool: return float(a1.s) < float(b1.s)
	for side: float in [1.0, -1.0]:
		var row: Array = homes.filter(func(h): return h.get("plot", false) and h.street == artisan_si and float(h.side) == side and not h in taken)
		row.sort_custom(by_s)
		var kinds := ["forge", "sawmill", "tannery"] if side > 0.0 else ["inn"]
		for k in kinds:
			if service(k).is_empty() and not row.is_empty(): take.call(row.pop_front(), k)
	# ce qui manque encore (petites villes) : n'importe quelle parcelle, la plus proche de la place
	for k in ["forge", "inn", "sawmill", "tannery"]:
		if not service(k).is_empty(): continue
		var cand: Array = homes.filter(func(h): return h.get("plot", false) and not h in taken)
		cand.sort_custom(func(a1, b1): return dist.call(a1) < dist.call(b1))
		if not cand.is_empty(): take.call(cand[0], k)
	# mercenaires : au bout d'une autre grande rue, près d'une porte
	var far = null
	for h in homes:
		if h in taken or not h.get("plot", false) or h.street < 0: continue
		if h.street == artisan_si and streets.size() > 1: continue
		if far == null or dist.call(h) > dist.call(far): far = h
	if far != null: take.call(far, "mercs")
	for h in homes:
		if h.kind == "inn": h.fl = 3; h.w = max(int(h.w), 6)
		if h.kind == "auction": h.fl = 3

# noms des rues : on sait toujours où on est
const STREET_NAMES := ["Grand-Rue", "Rue du Marché", "Rue des Gardes", "Rue du Moulin"]
func _street_signs() -> void:
	var k := 0
	for si in streets.size():
		var st: Dictionary = streets[si]
		if not st.main: continue
		var nm: String = "Rue des Artisans" if si == artisan_si else STREET_NAMES[k % STREET_NAMES.size()]
		if si != artisan_si: k += 1
		var pa: Array = point_at(st, PLAZA_R + 5.0); var p: Vector2 = pa[0]; var tg: Vector2 = pa[1]
		var q: Vector2 = p + Vector2(-tg.y, tg.x) * (float(st.half) + 0.6)
		var y: float = W.height(q.x, q.y)
		# poteau et planche
		var root := Node3D.new(); root.position = Vector3(q.x, y, q.y); root.rotation.y = atan2(tg.x, tg.y); W.add_child(root)
		var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#5a3d26")
		var po := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.09; cm.height = 2.6; po.mesh = cm; po.position.y = 1.3; po.material_override = wood; root.add_child(po)
		var pl := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.6, 0.42, 0.08); pl.mesh = bm; pl.position = Vector3(0, 2.35, 0); pl.material_override = wood; root.add_child(pl)
		W.blocker(Vector3(q.x, 0, q.y), 0.2)
		var l: Label3D = W.label(nm, Vector3(q.x, y + 3.1, q.y), Color("#ffe9b8"), 36)
		l.pixel_size = 0.0075

func service(kind: String) -> Dictionary:
	for h in homes:
		if h.kind == kind: return h
	return {}

# place du PNJ devant son lieu (dans la cour, face à la rue)
func service_slot(kind: String) -> Array:
	var h := service(kind)
	if h.is_empty(): return door_slot(12.0, 40.0)
	h.used = true
	var fwd: Vector2 = ((h.out as Vector2) - (h.door as Vector2)).normalized()
	var ax := Vector2(cos(h.rot), -sin(h.rot))
	var q: Vector2 = (h.out as Vector2) + fwd * 0.6 + ax * (1.6 if kind == "forge" else 0.0)
	npc_used.append(q)
	return [Vector3(q.x, 0, q.y), atan2(fwd.x, fwd.y), h]

func _service_yard(h: Dictionary, c: Vector2, ax: Vector2, az: Vector2, hx: float, hz: float, ldx: float) -> void:
	var at := func(lx: float, lz: float) -> Vector3:
		var q: Vector2 = c + ax * lx + az * lz; return Vector3(q.x, 0, q.y)
	var rot: float = h.rot
	var DG := "res://assets/dungeon/"; var H := "res://assets/hex/"
	var side: float = 1.0 if ldx <= 0.0 else -1.0       # le côté libre de la cour (loin de l'allée)
	match h.kind:
		"forge":
			# atelier ouvert façon Albion : dallage de pierres, charpente au toit de tuiles, foyer rougeoyant, enclume
			var sw: float = clamp(hx - abs(ldx) - 1.2, 2.6, 4.4)
			var lx0: float = side * (hx - 0.3 - sw * 0.5)
			var lz0: float = hz - 1.55
			var yc: Vector2 = c + ax * lx0 + az * lz0
			_flagstones(yc, sw * 0.5 + 0.5, 1.9, rot)
			_shelter(yc, rot, sw, 2.7)
			var fp: Vector3 = at.call(lx0 + side * (sw * 0.5 - 0.7), lz0 - 0.6)
			_hearth(fp, rot); W.blocker(fp, 0.6)
			var an: Vector3 = at.call(lx0 - side * 0.5, lz0 + 0.2)
			_anvil(an, rot); W.blocker(an, 0.45)
			W.place(DG + "barrel_large.gltf", at.call(lx0 - side * (sw * 0.5 - 0.4), lz0 - 0.7), 0.0, 0.42)
			W.place(H + "weaponrack.gltf", at.call(-side * (hx - 0.9), hz - 1.6), rot, 4.2)
			W.label("FORGE", at.call(0, 0) + Vector3(0, W.height(c.x, c.y) + 8.5, 0), Color("#ffb070"), 52)
		"inn":
			# terrasse : tables, tonneaux, lanternes sous un auvent rayé
			for k in 2:
				var tq: Vector3 = at.call(side * (hx - 1.3 - k * 2.2), hz - 1.5)
				W.place(DG + "table_medium_decorated_A.gltf", tq, rot, 0.8); W.blocker(tq, 0.8)
				W.place(H + "barrel.gltf", tq + Vector3(0.9, 0, 0.9).rotated(Vector3.UP, rot), rot, 2.4)
			awning(c + ax * side * (hx - 2.4) + az * (hz - 1.5), rot, 4.6, 2.6, Color("#b0352a"), Color("#f0e6d0"))
			for k in 2:
				var lq: Vector3 = at.call(ldx + (1.4 if k == 0 else -1.4), hz - 0.6)
				W.place("res://assets/halloween/lantern_standing.gltf", lq, 0.0, 1.4); W.blocker(lq, 0.25)
				W._light(lq + Vector3(0, W.height(lq.x, lq.z) + 2.2, 0), Color("#ffbf66"), 2.0, 2.4)
			W.label("AUBERGE", at.call(0, 0) + Vector3(0, W.height(c.x, c.y) + 12.5, 0), Color("#ffd27a"), 52)
		"mercs":
			# camp d'entraînement : tente, râteliers, bannière
			W.place(H + "tent.gltf", at.call(side * (hx - 1.6), hz - 1.6), rot + PI, 2.6); W.blocker(at.call(side * (hx - 1.6), hz - 1.6), 1.0)
			W.place(H + "weaponrack.gltf", at.call(-side * (hx - 0.9), hz - 1.4), rot, 4.4)
			W.place(DG + "banner_patternA_red.gltf", at.call(ldx + 1.5, hz - 0.5), rot, 1.2)
			W.place(DG + "crates_stacked.gltf", at.call(-side * (hx - 0.9), hz - 2.6), rot, 0.8)
			W.label("MERCENAIRES", at.call(0, 0) + Vector3(0, W.height(c.x, c.y) + 8.5, 0), Color("#ffb07a"), 46)

		"tannery":
			# séchoirs à peaux, cuves de tannage, ballots de cuir
			for k in 2:
				var rq: Vector3 = at.call(side * (hx - 1.4 - k * 2.6), hz - 1.6)
				_hide_rack(rq, rot); W.box_blocker(rq, Vector3(2.0, 1.8, 0.4), rot)
			for k in 2:
				var tq: Vector3 = at.call(-side * (hx - 1.0), hz - 1.4 - k * 1.3)
				W.place(DG + "barrel_large.gltf", tq, 0.0, 0.5); W.blocker(tq, 0.5)
			W.place(H + "sack.gltf", at.call(side * (hx - 1.0), hz - 3.2), rot, 2.8)
			W.label("TANNERIE", at.call(0, 0) + Vector3(0, W.height(c.x, c.y) + 8.5, 0), Color("#e0b07a"), 46)
		"sawmill":
			# grumes empilées, chevalet de sciage, copeaux
			for k in 2:
				var lq: Vector3 = at.call(side * (hx - 1.6 - k * 2.4), hz - 1.8)
				W.place(H + "resource_lumber.gltf", lq, rot + k * 0.4, 1.6); W.blocker(lq, 0.9)
			var sq: Vector3 = at.call(-side * (hx - 1.4), hz - 1.6)
			_sawhorse(sq, rot); W.box_blocker(sq, Vector3(2.2, 1.0, 0.7), rot)
			W.place(DG + "crates_stacked.gltf", at.call(-side * (hx - 0.9), hz - 3.0), rot, 0.7)
			W.label("SCIERIE", at.call(0, 0) + Vector3(0, W.height(c.x, c.y) + 8.5, 0), Color("#b8e07a"), 46)

# dallage irrégulier (MultiMesh : très léger)
func _flagstones(c: Vector2, rx: float, rz: float, rot: float) -> void:
	var ax := Vector2(cos(rot), -sin(rot)); var az := Vector2(sin(rot), cos(rot))
	var cm := CylinderMesh.new(); cm.top_radius = 0.5; cm.bottom_radius = 0.52; cm.height = 0.1; cm.radial_segments = 7; cm.rings = 1
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = true; mm.mesh = cm
	var pts: Array = []
	var x := -rx
	while x <= rx:
		var z := -rz
		while z <= rz:
			pts.append(Vector2(x + R.randf_range(-0.15, 0.15), z + R.randf_range(-0.15, 0.15))); z += 0.95
		x += 0.95
	mm.instance_count = pts.size()
	for i in pts.size():
		var l: Vector2 = pts[i]; var q: Vector2 = c + ax * l.x + az * l.y
		var sc := R.randf_range(0.8, 1.0)
		mm.set_instance_transform(i, Transform3D(Basis(Vector3.UP, R.randf() * TAU).scaled(Vector3(sc, 1.0, sc * R.randf_range(0.8, 1.0))), Vector3(q.x, W.height(q.x, q.y) + 0.04, q.y)))
		mm.set_instance_color(i, Color("#b9ad98").darkened(R.randf_range(0.0, 0.22)))
	var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.roughness = 0.95
	var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = mat; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; W.add_child(mi)

# charpente ouverte : 4 poteaux, sablières, toit de tuiles en appentis
func _shelter(c: Vector2, rot: float, w: float, d: float, h := 2.9) -> void:
	var root := Node3D.new(); root.position = Vector3(c.x, W.height(c.x, c.y), c.y); root.rotation.y = rot; W.add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_texture = load("res://assets/village/T_WoodTrim_BaseColor.png"); wood.albedo_color = Color("#a07a58"); wood.roughness = 0.9
	wood.uv1_triplanar = true; wood.uv1_scale = Vector3(0.8, 0.8, 0.8)
	var tile := StandardMaterial3D.new(); tile.albedo_texture = load("res://assets/village/T_RoundTiles_BaseColor.png"); tile.albedo_color = Color(W._roof_tint) if W.get("_roof_tint") != null else Color.WHITE; tile.roughness = 0.85
	tile.uv1_triplanar = true; tile.uv1_scale = Vector3(0.5, 0.5, 0.5); tile.cull_mode = BaseMaterial3D.CULL_DISABLED
	var box := func(sz: Vector3, pos: Vector3, m: Material, rx := 0.0) -> void:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm; mi.position = pos; mi.rotation.x = rx; mi.material_override = m; root.add_child(mi)
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph: float = h + (0.45 if sz < 0 else 0.0)
			box.call(Vector3(0.24, ph, 0.24), Vector3(sx * (w * 0.5 - 0.15), ph * 0.5, sz * (d * 0.5 - 0.15)), wood)
			var pq := c + Vector2(cos(rot), -sin(rot)) * sx * (w * 0.5 - 0.15) + Vector2(sin(rot), cos(rot)) * sz * (d * 0.5 - 0.15)
			W.blocker(Vector3(pq.x, 0, pq.y), 0.2)
	box.call(Vector3(w, 0.2, 0.22), Vector3(0, h + 0.45, -(d * 0.5 - 0.15)), wood)
	box.call(Vector3(w, 0.2, 0.22), Vector3(0, h, d * 0.5 - 0.15), wood)
	var slope := atan2(0.45, d)
	box.call(Vector3(w + 0.7, 0.14, d + 0.8), Vector3(0, h + 0.33, 0), tile, slope)

# foyer de forge : socle de pierre, braises qui rougeoient, fumée
func _hearth(p: Vector3, rot: float) -> void:
	var y: float = W.height(p.x, p.z)
	var root := Node3D.new(); root.position = Vector3(p.x, y, p.z); root.rotation.y = rot; W.add_child(root)
	var stone := StandardMaterial3D.new(); stone.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png"); stone.albedo_color = Color("#9a8c7c"); stone.uv1_triplanar = true; stone.uv1_scale = Vector3(0.9, 0.9, 0.9)
	var coal := StandardMaterial3D.new(); coal.albedo_color = Color("#ff7a20"); coal.emission_enabled = true; coal.emission = Color("#ff5a10"); coal.emission_energy_multiplier = 2.5
	var c1 := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.6; cm.bottom_radius = 0.7; cm.height = 0.8; cm.radial_segments = 10; c1.mesh = cm; c1.position = Vector3(0, 0.4, 0); c1.material_override = stone; root.add_child(c1)
	var c2 := MeshInstance3D.new(); var em := CylinderMesh.new(); em.top_radius = 0.45; em.bottom_radius = 0.45; em.height = 0.06; em.radial_segments = 10; c2.mesh = em; c2.position = Vector3(0, 0.81, 0); c2.material_override = coal; root.add_child(c2)
	W._light(Vector3(p.x, y + 1.3, p.z), Color("#ff7a20"), 3.0, 3.4)
	W._smoke(Vector3(p.x, y + 1.0, p.z))

# séchoir : deux poteaux, une perche, des peaux tendues
func _hide_rack(p: Vector3, rot: float) -> void:
	var root := Node3D.new(); root.position = Vector3(p.x, W.height(p.x, p.z), p.z); root.rotation.y = rot; W.add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#5a3d26"); wood.roughness = 0.95
	var hmat := StandardMaterial3D.new(); hmat.albedo_color = Color("#a8743e"); hmat.roughness = 1.0; hmat.cull_mode = BaseMaterial3D.CULL_DISABLED
	for sx: float in [-1.0, 1.0]:
		var po := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.06; cm.bottom_radius = 0.08; cm.height = 1.9
		po.mesh = cm; po.position = Vector3(sx * 0.95, 0.95, 0); po.material_override = wood; root.add_child(po)
	var bar := MeshInstance3D.new(); var bc := CylinderMesh.new(); bc.top_radius = 0.05; bc.bottom_radius = 0.05; bc.height = 2.0
	bar.mesh = bc; bar.rotation.z = PI * 0.5; bar.position = Vector3(0, 1.8, 0); bar.material_override = wood; root.add_child(bar)
	for k in 3:
		var hm := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(0.5, 1.0); hm.mesh = pm
		hm.rotation.x = PI * 0.5; hm.position = Vector3(-0.6 + k * 0.6, 1.25, 0.02 * (k - 1)); hm.scale = Vector3(1.0 + 0.15 * (k % 2), 1, 1)
		var m2: StandardMaterial3D = hmat.duplicate(); m2.albedo_color = hmat.albedo_color.darkened(0.12 * k); hm.material_override = m2; root.add_child(hm)

# chevalet de sciage avec une bûche et une scie
func _sawhorse(p: Vector3, rot: float) -> void:
	var root := Node3D.new(); root.position = Vector3(p.x, W.height(p.x, p.z), p.z); root.rotation.y = rot; W.add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#6a4a2e"); wood.roughness = 0.95
	var bark := StandardMaterial3D.new(); bark.albedo_color = Color("#8a6440"); bark.roughness = 1.0
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color("#b8bcc4"); steel.metallic = 0.8; steel.roughness = 0.35
	for sx: float in [-0.8, 0.8]:
		for sz: float in [-1.0, 1.0]:
			var leg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.08, 0.9, 0.08); leg.mesh = bm
			leg.position = Vector3(sx, 0.42, sz * 0.18); leg.rotation.x = sz * 0.35; leg.material_override = wood; root.add_child(leg)
	var lg := MeshInstance3D.new(); var lc := CylinderMesh.new(); lc.top_radius = 0.22; lc.bottom_radius = 0.24; lc.height = 2.3
	lg.mesh = lc; lg.rotation.z = PI * 0.5; lg.position = Vector3(0, 1.0, 0); lg.material_override = bark; root.add_child(lg)
	var saw := MeshInstance3D.new(); var sb := BoxMesh.new(); sb.size = Vector3(0.03, 0.25, 0.9); saw.mesh = sb
	saw.position = Vector3(0.3, 1.2, 0); saw.rotation.x = 0.3; saw.material_override = steel; root.add_child(saw)

# ================= REMPARTS : une enceinte de pierre autour du bourg, des tours aux portes =================
const WALL_H := 2.7
const WALL_T := 0.9
func _ramparts(ST: Dictionary) -> void:
	# 1) rayon de l'enceinte dans chaque direction : au-delà des maisons et des rues
	var N := 180
	var raw: Array = []; raw.resize(N); raw.fill(PLAZA_R + 16.0)
	var put := func(q: Vector2, m: float) -> void:
		var d := q - V
		var i := int(round(fposmod(atan2(d.y, d.x), TAU) / TAU * N)) % N
		var r := d.length() + m
		for k in range(-1, 2):
			var j := (i + k + N) % N
			raw[j] = max(float(raw[j]), r)
	for h in homes:
		for q: Vector2 in _corners(h.c, h.rot, float(h.get("pw", h.w)), float(h.get("pd", h.d)), 0.0): put.call(q, 3.5)
	for st in streets:
		for q: Vector2 in st.pts: put.call(q, float(st.half) + 3.0)
	for e in entrances: put.call(e.p, 0.4)
	# lissage : enceinte arrondie, sans pics
	var rr: Array = []; rr.resize(N)
	for i in N:
		var mx := 0.0
		for k in range(-6, 7): mx = max(mx, float(raw[(i + k + N) % N]))
		rr[i] = mx
	var sm: Array = []; sm.resize(N)
	for i in N:
		var t := 0.0
		for k in range(-5, 6): t += float(rr[(i + k + N) % N])
		sm[i] = max(t / 11.0, float(raw[i]))
	# 2) le tracé, tous les 2 m
	var ring: Array = []
	for i in N:
		var a := TAU * i / N
		ring.append(V + Vector2(cos(a), sin(a)) * float(sm[i]))
	ring.append(ring[0])
	var pts: Array = _resample(ring, 2.0)
	# 3) où peut-on bâtir ? (pas sur l'eau, les rues, les routes, devant les portes)
	var ok: Array = []
	for q: Vector2 in pts:
		var good: bool = W.walkable(q.x, q.y) and W.height(q.x, q.y) > World.WATER_Y + 0.25 and not W.on_bridge(q.x, q.y)
		good = good and not _on_street(q, 1.4) and W.road_dist(q.x, q.y) > 4.0 and not W.near_house(q, 0.8) and W.slope(q.x, q.y) < 1.2
		if good:
			for e in entrances:
				if W.seg_dist(q, e.p - (e.dir as Vector2) * 3.0, e.p + (e.dir as Vector2) * 40.0) < float(e.st.half) + 2.2: good = false; break
		if good:
			for h in homes:
				if _inside(q, h, 0.8): good = false; break
		ok.append(good)
	# 4) on retire les bouts de mur trop courts (moins de 3 pierres)
	var n := pts.size()
	var i0 := 0
	while i0 < n:
		if not ok[i0]: i0 += 1; continue
		var i1 := i0
		while i1 < n and ok[i1]: i1 += 1
		if i1 - i0 < 5:
			for k in range(i0, i1): ok[k] = false
		i0 = i1
	# 5) maçonnerie : blocs + créneaux en MultiMesh, tours aux extrémités et régulièrement
	var tint: Color = {1: Color("#d4cfc4"), 2: Color("#b8b8a8"), 3: Color("#e2c99c"), 4: Color("#8c8c94")}.get(int(W.map_id), Color("#d4cfc4"))
	var mat := StandardMaterial3D.new(); mat.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png"); mat.albedo_color = tint; mat.roughness = 0.95
	mat.uv1_triplanar = true; mat.uv1_world_triplanar = true; mat.uv1_scale = Vector3(0.45, 0.45, 0.45); mat.texture_repeat = true
	var cap := StandardMaterial3D.new(); cap.albedo_texture = mat.albedo_texture; cap.albedo_color = tint.darkened(0.15); cap.roughness = 0.95
	cap.uv1_triplanar = true; cap.uv1_world_triplanar = true; cap.uv1_scale = Vector3(0.9, 0.9, 0.9); cap.texture_repeat = true
	var blocks: Array = []; var merlons: Array = []; var towers: Array = []
	var run := 0
	# hauteur du chemin de ronde lissée (sinon le haut du mur fait des marches)
	var gy: Array = []
	for q: Vector2 in pts: gy.append(W.height(q.x, q.y))
	var ty: Array = []
	for k in n:
		var t := 0.0; var c2 := 0
		for j in range(max(0, k - 2), min(n, k + 3)): t += float(gy[j]); c2 += 1
		ty.append(t / c2)
	for k in n:
		if not ok[k]: run = 0; continue
		var q: Vector2 = pts[k]
		var nx: Vector2 = pts[min(k + 1, n - 1)]; var pv: Vector2 = pts[max(k - 1, 0)]
		var tg := (nx - pv).normalized()
		var rot := atan2(tg.x, tg.y) + PI * 0.5
		var y: float = max(float(ty[k]), float(gy[k]) - 0.3)
		# le mur suit le sol : on l'enfonce un peu du côté le plus bas
		var y0: float = min(float(gy[k]), min(W.height(q.x + tg.x, q.y + tg.y), W.height(q.x - tg.x, q.y - tg.y))) - 0.6
		var hh: float = y + WALL_H - y0
		blocks.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(2.15, hh, WALL_T)), Vector3(q.x, y0 + hh * 0.5, q.y)))
		var ax := Vector3(cos(rot), 0, -sin(rot))
		for m: float in [-0.55, 0.55]:
			var mp: Vector3 = Vector3(q.x, y + WALL_H + 0.25, q.y) + ax * m
			merlons.append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3(0.6, 0.5, WALL_T + 0.06)), mp))
		W.box_blocker(Vector3(q.x, 0, q.y), Vector3(2.1, WALL_H + 0.4, WALL_T + 0.1), rot)
		W.house_spots.append([q, 1.1])
		var first: bool = k == 0 or not ok[k - 1]
		var last: bool = k == n - 1 or not ok[k + 1]
		if first or last or run % 12 == 6: towers.append(q)
		run += 1
	for pair in [[blocks, mat], [merlons, cap]]:
		var arr: Array = pair[0]
		if arr.is_empty(): continue
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; var bm := BoxMesh.new(); mm.mesh = bm
		mm.instance_count = arr.size()
		for j in arr.size(): mm.set_instance_transform(j, arr[j])
		var mi := MultiMeshInstance3D.new(); mi.multimesh = mm; mi.material_override = pair[1]
		mi.visibility_range_end = 140.0; W.add_child(mi)
	var roof_col: Color = {1: Color("#3d5f9a"), 2: Color("#8a3a2e"), 3: Color("#b0603a"), 4: Color("#4a4a5a")}.get(int(W.map_id), Color("#3d5f9a"))
	for q: Vector2 in towers: _tower(q, mat, cap, roof_col, ST)
	wall_pts = []
	for k in n:
		if ok[k]: wall_pts.append(pts[k])

var wall_pts: Array = []
# entrées de la ville : deux tours de garde de part et d'autre de chaque grande rue (plus sobre qu'une enceinte trouée)
func _gate_towers(ST: Dictionary) -> void:
	var tint: Color = {1: Color("#d4cfc4"), 2: Color("#b8b8a8"), 3: Color("#e2c99c"), 4: Color("#8c8c94")}.get(int(W.map_id), Color("#d4cfc4"))
	var mat := StandardMaterial3D.new(); mat.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png"); mat.albedo_color = tint; mat.roughness = 0.95
	mat.uv1_triplanar = true; mat.uv1_world_triplanar = true; mat.uv1_scale = Vector3(0.45, 0.45, 0.45)
	var cap := mat.duplicate(); cap.albedo_color = tint.darkened(0.15)
	var roof_col: Color = {1: Color("#3d5f9a"), 2: Color("#8a3a2e"), 3: Color("#b0603a"), 4: Color("#4a4a5a")}.get(int(W.map_id), Color("#3d5f9a"))
	for e in entrances:
		if float(e.st.len) < 30.0: continue
		var tg: Vector2 = e.dir; var nr := Vector2(-tg.y, tg.x)
		for sd: float in [-1.0, 1.0]:
			var q: Vector2 = (e.p as Vector2) + nr * sd * (float(e.st.half) + 4.6) + tg * 1.0
			if _bad(q) or not W.walkable(q.x, q.y) or W.road_dist(q.x, q.y) < 2.5: continue
			_tower(q, mat, cap, roof_col, ST)
# tour ronde : fût de pierre, couronne crénelée, toit conique et bannière
func _tower(q: Vector2, mat: Material, cap: Material, roof_col: Color, ST: Dictionary) -> void:
	var y: float = W.height(q.x, q.y)
	var root := Node3D.new(); root.position = Vector3(q.x, y, q.y); W.add_child(root)
	var cyl := func(rt: float, rb: float, h: float, yy: float, m: Material, segs := 16) -> void:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = segs
		mi.mesh = cm; mi.position = Vector3(0, yy, 0); mi.material_override = m; root.add_child(mi)
	cyl.call(1.45, 1.6, 5.2, 1.9, mat)            # fût (enfoncé de 0,7 m)
	cyl.call(1.75, 1.5, 0.45, 4.7, cap)           # mâchicoulis
	for k in 8:
		var a := TAU * k / 8.0
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.55, 0.55, 0.35); mi.mesh = bm
		mi.position = Vector3(cos(a) * 1.55, 5.2, sin(a) * 1.55); mi.rotation.y = -a + PI * 0.5; mi.material_override = cap; root.add_child(mi)
	var rm := StandardMaterial3D.new(); rm.albedo_color = roof_col; rm.roughness = 0.8
	cyl.call(0.0, 1.85, 2.4, 6.4, rm, 12)          # toit conique
	var fl := MeshInstance3D.new(); var pm := BoxMesh.new(); pm.size = Vector3(0.04, 0.5, 0.75); fl.mesh = pm
	var fm := StandardMaterial3D.new(); fm.albedo_color = roof_col.lightened(0.25); fl.material_override = fm; fl.position = Vector3(0, 8.0, 0.38); root.add_child(fl)
	var pole := MeshInstance3D.new(); var pc := CylinderMesh.new(); pc.top_radius = 0.03; pc.bottom_radius = 0.03; pc.height = 1.2; pole.mesh = pc
	pole.position = Vector3(0, 7.9, 0); root.add_child(pole)
	W.blocker(Vector3(q.x, 0, q.y), 1.55, 5.0)
	W.house_spots.append([q, 2.0])

# enclume : socle, table et bigorne
func _anvil(p: Vector3, rot: float) -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color("#3a3d44"); m.metallic = 0.7; m.roughness = 0.45
	var root := Node3D.new(); root.position = Vector3(p.x, W.height(p.x, p.z), p.z); root.rotation.y = rot; W.add_child(root)
	var parts := [[Vector3(0.45, 0.5, 0.45), Vector3(0, 0.25, 0)], [Vector3(0.95, 0.2, 0.38), Vector3(0, 0.6, 0)], [Vector3(0.3, 0.12, 0.3), Vector3(0, 0.75, 0)]]
	for pt in parts:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = pt[0]; mi.mesh = bm; mi.position = pt[1]; mi.material_override = m; root.add_child(mi)
	var horn := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.1; cm.height = 0.4; horn.mesh = cm
	horn.rotation.z = -PI * 0.5; horn.position = Vector3(0.65, 0.62, 0); horn.material_override = m; root.add_child(horn)
	var stump: Node3D = load("res://assets/hex/resource_lumber.gltf").instantiate(); stump.scale = Vector3.ONE * 0.8; stump.position = Vector3(-0.9, 0, 0.3); root.add_child(stump)

# fontaine ronde au centre de la place : bassin, eau, colonne et vasque
func _fountain() -> void:
	var stone := StandardMaterial3D.new(); stone.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png")
	stone.albedo_color = Color("#d8d2c4"); stone.roughness = 0.95; stone.uv1_scale = Vector3(2.0, 0.6, 1.0)
	var water := StandardMaterial3D.new(); water.albedo_color = Color(0.25, 0.6, 0.85, 0.85); water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	water.roughness = 0.08; water.metallic = 0.2; water.emission_enabled = true; water.emission = Color(0.08, 0.22, 0.32)
	var y0: float = W.height(V.x, V.y)
	var root := Node3D.new(); root.position = Vector3(V.x, y0, V.y); W.add_child(root)
	var cyl := func(rt: float, rb: float, h: float, y: float, m: Material) -> void:
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = 32
		mi.mesh = cm; mi.position = Vector3(0, y, 0); mi.material_override = m; root.add_child(mi)
	cyl.call(2.6, 2.75, 0.3, 0.05, stone)      # marche
	cyl.call(2.25, 2.3, 0.7, 0.45, stone)      # bassin
	cyl.call(2.05, 2.05, 0.06, 0.78, water)    # eau
	cyl.call(0.32, 0.42, 1.7, 1.2, stone)      # colonne
	cyl.call(0.95, 0.35, 0.3, 2.1, stone)      # vasque
	cyl.call(0.85, 0.85, 0.05, 2.24, water)
	cyl.call(0.12, 0.2, 0.6, 2.5, stone)
	var sp := GPUParticles3D.new(); sp.amount = 40; sp.lifetime = 0.9; sp.position = Vector3(0, 2.8, 0)
	var pm := ParticleProcessMaterial.new(); pm.direction = Vector3(0, 1, 0); pm.spread = 35.0; pm.initial_velocity_min = 1.6; pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, -6, 0); pm.scale_min = 0.6; pm.scale_max = 1.0; sp.process_material = pm
	var dm := SphereMesh.new(); dm.radius = 0.05; dm.height = 0.1; var dmat := StandardMaterial3D.new(); dmat.albedo_color = Color(0.75, 0.9, 1.0); dmat.emission_enabled = true; dmat.emission = Color(0.3, 0.5, 0.6)
	dm.material = dmat; sp.draw_pass_1 = dm; root.add_child(sp)
	W.blocker(Vector3(V.x, 0, V.y), 2.6)

# banc de bois sur pieds de pierre
func _bench(q: Vector2, rot: float) -> void:
	var root := Node3D.new(); root.position = Vector3(q.x, W.height(q.x, q.y), q.y); root.rotation.y = rot; W.add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#7a5232"); wood.roughness = 0.9
	var st := StandardMaterial3D.new(); st.albedo_color = Color("#a8a296")
	for pt in [[Vector3(1.8, 0.1, 0.5), Vector3(0, 0.48, 0), wood], [Vector3(0.25, 0.45, 0.45), Vector3(-0.7, 0.22, 0), st], [Vector3(0.25, 0.45, 0.45), Vector3(0.7, 0.22, 0), st]]:
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = pt[0]; mi.mesh = bm; mi.position = pt[1]; mi.material_override = pt[2]; root.add_child(mi)
	W.box_blocker(Vector3(q.x, 0, q.y), Vector3(1.8, 0.6, 0.5), rot)
	npc_used.append(q)

# auvent : 4 poteaux et une toile rayée légèrement inclinée
static var _awn_mats := {}
func awning(c: Vector2, rot: float, w: float, d: float, c1: Color, c2: Color, h := 2.4) -> void:
	var root := Node3D.new(); root.position = Vector3(c.x, W.height(c.x, c.y), c.y); root.rotation.y = rot; W.add_child(root)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#4a3322")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var post := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.07; cm.bottom_radius = 0.08; cm.height = h + (0.3 if sz < 0 else 0.0)
			post.mesh = cm; post.position = Vector3(sx * (w * 0.5 - 0.15), cm.height * 0.5, sz * (d * 0.5 - 0.15)); post.material_override = wood; root.add_child(post)
	var n := 6
	for i in n:
		var col: Color = c1 if i % 2 == 0 else c2
		var key := col.to_html()
		if not _awn_mats.has(key):
			var mm := StandardMaterial3D.new(); mm.albedo_color = col; mm.roughness = 0.9; mm.cull_mode = BaseMaterial3D.CULL_DISABLED; _awn_mats[key] = mm
		var st := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w / n, 0.05, d + 0.3); st.mesh = bm
		st.position = Vector3(-w * 0.5 + (i + 0.5) * w / n, h + 0.15, 0); st.rotation.x = -0.14; st.material_override = _awn_mats[key]; root.add_child(st)
