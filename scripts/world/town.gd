class_name Town
## Le bourg au pied du château : maisons à colombages autour d'une place pavée,
## étals de marché, puits, villageois. Maisons orientées vers la place ou la route.

static var houses: Array = []
static var chimneys: Array = []   # sommets de cheminées (fumée)
static var doors: Array = []    # [position de la porte (Vector2), direction de la façade (Vector2)]   # [centre Vector2, demi-taille Vector2] pour éviter les chevauchements

static var gardens: Array = []   # [centre, rotation] des potagers clôturés
static var specials := {}        # "auberge" / "forge" -> [porte Vector2, direction Vector2]

static func build(parent: Node3D) -> void:
	houses.clear()
	doors.clear()
	chimneys.clear()
	gardens.clear()
	specials.clear()
	var g = Geo.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	# 0) l'église du bourg, face à la place (repère visible de loin)
	var ca := deg_to_rad(128.0)
	var cp: Vector2 = Layout.TOWN + Vector2(cos(ca), sin(ca)) * 31.0
	var crot := atan2(Layout.TOWN.x - cp.x, Layout.TOWN.y - cp.y)
	_church(g, cp, crot)
	houses.append([cp, 13.5])
	# 1) la place : un anneau régulier de maisons tournées vers le centre
	for i in 14:
		var a = TAU * i / 14.0 + 0.13
		var p = Layout.TOWN + Vector2(cos(a), sin(a)) * (21.5 + rng.randf_range(-0.5, 0.5))
		var face = atan2(Layout.TOWN.x - p.x, Layout.TOWN.y - p.y)
		_try_house(g, p, rng.randf_range(8.0, 10.0), rng.randf_range(6.5, 7.5), face, rng)
	# 2) des rues : maisons alignées face à la route, potager clôturé derrière
	var r0: Array = Layout.ROADS[0]["pts"]
	_street(g, r0, float(Layout.ROADS[0]["w"]), rng, func(q: Vector2): return q.y > -64.0 and q.y < 112.0, 10.5)
	_street(g, Layout.ROADS[1]["pts"], float(Layout.ROADS[1]["w"]), rng, func(q: Vector2): return true, 10.5)
	_street(g, Layout.ROADS[2]["pts"], float(Layout.ROADS[2]["w"]), rng, func(q: Vector2): return true, 10.5)
	# 3) second anneau, plus lâche : on remplit les trous entre les rues
	for i in 18:
		var a = TAU * i / 18.0 + 0.3
		var p = Layout.TOWN + Vector2(cos(a), sin(a)) * (41.0 + rng.randf_range(-2.0, 2.0))
		var face = atan2(Layout.TOWN.x - p.x, Layout.TOWN.y - p.y)
		if _try_house(g, p, rng.randf_range(7.5, 9.0), rng.randf_range(6.0, 7.0), face, rng):
			var gc: Vector2 = p - Vector2(sin(face), cos(face)) * 8.5
			if _free_for(gc, 5.0):
				gardens.append([gc, face])
				houses.append([gc, 4.6])
	print("[bourg] maisons+potagers=%d potagers=%d portes=%d" % [houses.size(), gardens.size(), doors.size()])
	_market(g)
	_paths(g)
	_smithy(g)
	g.commit(parent, "Bourg")
	Kit.village(parent, "Prop_Well_Cobblestone", Vector3(Layout.TOWN.x, Terrain.height_at(Layout.TOWN.x, Layout.TOWN.y), Layout.TOWN.y), 0.0, 1.6)
	_props(parent, rng)
	var pot := Node3D.new()
	pot.name = "Potagers"
	parent.add_child(pot)
	for gd in gardens:
		_garden(pot, gd[0], gd[1], rng)
	_smoke(parent)
	_villageois(parent, rng)

## Maisons le long d'une route, des deux côtés, à intervalles réguliers (avec un peu de variation)
static func _street(g: Geo, pts: Array, rw: float, rng: RandomNumberGenerator, keep: Callable, spacing: float) -> void:
	var acc := spacing * 0.5
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var seg := b.distance_to(a)
		var dir := (b - a) / seg
		var n := Vector2(-dir.y, dir.x)
		var t := acc
		while t < seg:
			var q := a + dir * t
			if keep.call(q):
				for side in [-1.0, 1.0]:
					if rng.randf() < 0.18:
						continue
					var w := rng.randf_range(7.5, 9.5)
					var d := rng.randf_range(6.0, 7.2)
					var c: Vector2 = q + n * side * (rw + 2.6 + d * 0.5)
					var face := atan2(-n.x * side, -n.y * side)
					if _try_house(g, c, w, d, face, rng):
						var gc: Vector2 = c + n * side * (d * 0.5 + 5.0)
						if rng.randf() < 0.7 and _free_for(gc, 5.0):
							gardens.append([gc, face])
							houses.append([gc, 4.6])
			t += spacing + rng.randf_range(-1.5, 1.5)
		acc = t - seg

static func _free_for(p: Vector2, rad: float) -> bool:
	if Layout.road_dist(p) < rad - 0.5 or Layout.river_dist(p) < Layout.RIVER_W + rad + 2.0 or Layout.in_fields(p, 2.0):
		return false
	if Layout.in_castle(p, 22.0) or p.distance_to(Layout.TOWN) < 17.0:
		return false
	for k in houses.size() - 1:   # la dernière maison est celle du potager : on la longe
		var h: Array = houses[k]
		if (h[0] as Vector2).distance_to(p) < rad + (h[1] as float):
			return false
	var own: Array = houses[houses.size() - 1]
	return (own[0] as Vector2).distance_to(p) > (own[1] as float) * 0.5 + rad * 0.6

static func _try_house(g: Geo, p: Vector2, w: float, d: float, rot: float, rng: RandomNumberGenerator) -> bool:
	var rad = Vector2(w, d).length() * 0.5 + 1.2
	if Layout.road_dist(p) < rad - 2.4 or p.distance_to(Layout.TOWN) < 17.0:
		return false
	if Layout.river_dist(p) < Layout.RIVER_W + rad + 3.0 or Layout.in_castle(p, 25.0):
		return false
	if absf(p.x - Layout.GATE.x) < 16.0 and p.y < Layout.GATE.y + 30.0:
		return false
	if Layout.in_fields(p, 3.0) or p.distance_to(Layout.MINE) < 26.0 or p.distance_to(Layout.LUMBER) < 15.0 or p.distance_to(Layout.PORTAL) < 35.0 or p.distance_to(Layout.FARM) < 22.0:
		return false
	for z in Spawner.ZONES:
		if p.distance_to(z["pos"]) < float(z["r"]) + 12.0:
			return false
	for h in houses:
		if (h[0] as Vector2).distance_to(p) < rad + (h[1] as float):
			return false
	# pas de maison sur une pente trop forte
	var hs := []
	for o in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]:
		hs.append(Terrain.height_at(p.x + o.x * 0.5, p.y + o.y * 0.5))
	if hs.max() - hs.min() > 2.2:
		return false
	houses.append([p, rad])
	var roofs = ["tuile", "tuile", "chaume", "ardoise"]
	var walls = ["crepi", "crepi", "crepi", "pierre_base"]
	house(g, p, w, d, rot, 2 if rng.randf() < 0.6 else 1, roofs[rng.randi() % roofs.size()], rng, walls[rng.randi() % walls.size()])
	return true

## Église : nef de pierre, toit d'ardoise pentu, clocher à flèche, portail en arc, rosace, contreforts
static func _church(g: Geo, p: Vector2, rot: float) -> void:
	var b := Basis(Vector3.UP, rot)
	var y := Terrain.height_at(p.x, p.y) + 0.2
	var c3 := Vector3(p.x, y, p.y)
	var w := 9.0
	var d := 18.0
	g.box("pierre_base", c3 + Vector3(0, -0.4, 0), Vector3(w + 1.0, 1.2, d + 1.0), rot, true)
	g.box("pierre_claire", c3 + Vector3(0, 4.0, 0), Vector3(w, 8.0, d), rot, true)
	g.gable_roof("ardoise", c3 + Vector3(0, 8.0, 0), d * 0.5 + 0.6, w * 0.5 + 0.8, 6.5, rot + PI * 0.5, "pierre_claire")
	for k in 4:
		for s in [-1.0, 1.0]:
			var q: Vector3 = c3 + b * Vector3(s * (w * 0.5 + 0.4), 0, -d * 0.5 + 2.5 + k * 4.4)
			g.box("pierre_base", q + Vector3(0, 2.6, 0), Vector3(0.9, 5.2, 1.0), rot, false)
			var qw: Vector3 = c3 + b * Vector3(s * (w * 0.5 + 0.05), 0, -d * 0.5 + 4.7 + k * 4.4)
			if k < 3:
				g.box("vitre", qw + Vector3(0, 4.6, 0), Vector3(0.08, 3.0, 1.1), rot, false)
	# clocher sur la façade
	var tq: Vector3 = c3 + b * Vector3(0, 0, d * 0.5 + 1.8)
	g.box("pierre_claire", tq + Vector3(0, 8.0, 0), Vector3(4.2, 16.0, 4.2), rot, true)
	g.box("pierre_base", tq + Vector3(0, 16.2, 0), Vector3(4.6, 0.5, 4.6), rot, false)
	g.cone("ardoise", tq, 3.0, tq.y + 16.4, 9.0, 8)
	g.box("or", tq + Vector3(0, 26.0, 0), Vector3(0.18, 1.6, 0.18), rot, false)
	g.box("or", tq + Vector3(0, 26.3, 0), Vector3(0.9, 0.16, 0.16), rot, false)
	for s in [-1.0, 1.0]:
		g.box("fenetre_sombre", tq + b * Vector3(s * 2.12, 13.0, 0), Vector3(0.06, 2.4, 1.2), rot, false)
	var fq: Vector3 = c3 + b * Vector3(0, 0, d * 0.5 + 3.95)
	g.box("fenetre_sombre", fq + Vector3(0, 9.5, 0), Vector3(1.6, 1.6, 0.06), rot, false)
	g.box("bois_sombre", fq + Vector3(0, 1.5, 0), Vector3(2.0, 3.0, 0.1), rot, false)
	g.box("pierre_base", fq + Vector3(0, 3.2, 0.05), Vector3(2.8, 0.5, 0.2), rot, false)
	g.stairs("pierre_base", fq + Vector3(0, -0.2, 0), rot, 3.6, 0.2, 0.5, 2)

## Potager clôturé : butte de terre labourée, rangs de choux et de plants de tomates, clôture de planches,
## portillon côté maison, arrosoir et caisse de récolte (modèles Low Poly Farm Lite)
static func _garden(root: Node3D, c: Vector2, rot: float, rng: RandomNumberGenerator) -> void:
	var b := Basis(Vector3.UP, rot)
	var y := Terrain.height_at(c.x, c.y)
	var c3 := Vector3(c.x, y, c.y)
	Kit.farm(root, "Mud", c3 + Vector3(0, -0.06, 0), rot, 1.0)
	# rangs de cultures
	for r in 4:
		var z := -1.35 + r * 0.9
		var kind := "Cabbage" if (r + int(c.x)) % 3 != 0 else "TomatoPlant"
		for k in 5:
			var x := -1.5 + k * 0.75 + rng.randf_range(-0.08, 0.08)
			var q: Vector3 = c3 + b * Vector3(x, 0.1, z)
			Kit.farm(root, kind, q, rot + rng.randf_range(-0.6, 0.6), rng.randf_range(0.85, 1.1) * (1.0 if kind == "Cabbage" else 1.15))
	# clôture : 3 travées par côté (1,7 m), portillon laissé ouvert côté maison
	var hl := 2.6
	for side in 4:
		var a := rot + side * PI / 2.0
		var nb := Basis(Vector3.UP, a)
		for k in 3:
			if side == 2 and k == 1:
				continue
			var q: Vector3 = c3 + nb * Vector3(-1.725 + k * 1.725, 0, hl)
			Kit.farm(root, "Fence", Vector3(q.x, Terrain.height_at(q.x, q.z), q.z), a, 1.0)
	var t: Vector3 = c3 + b * Vector3(hl + 0.6, 0, -1.2)
	Kit.farm(root, "WateringCan", Vector3(t.x, Terrain.height_at(t.x, t.z) + 0.2, t.z), rng.randf() * TAU, 1.0)
	var t2: Vector3 = c3 + b * Vector3(hl + 0.7, 0, 0.4)
	Kit.farm(root, "Box", Vector3(t2.x, Terrain.height_at(t2.x, t2.z), t2.z), rot + 0.3, 1.0)

## Forge du bourg : abri à poteaux, foyer, enclume, établi
static func _smithy(g: Geo) -> void:
	if not specials.has("forge"):
		return
	var dpos: Vector2 = specials["forge"][0]
	var dd: Vector2 = specials["forge"][1]
	var side := Vector2(dd.y, -dd.x)
	var c: Vector2 = dpos + dd * 4.5 + side * 2.5
	var rot := atan2(dd.x, dd.y)
	var b := Basis(Vector3.UP, rot)
	var y := Terrain.height_at(c.x, c.y)
	var c3 := Vector3(c.x, y, c.y)
	for cx in [-2.0, 2.0]:
		for cz in [-1.6, 1.6]:
			var q: Vector3 = c3 + b * Vector3(cx, 0, cz)
			g.box("bois_sombre", Vector3(q.x, y + 1.4, q.z), Vector3(0.25, 2.8, 0.25), rot, true)
	g.box("tuile", c3 + b * Vector3(0, 2.95, 0), Vector3(4.8, 0.2, 4.0), rot, false)
	g.box("pierre_base", c3 + b * Vector3(-1.2, 0.55, -1.0), Vector3(1.6, 1.1, 1.2), rot, true)
	g.box("fenetre_sombre", c3 + b * Vector3(-1.2, 1.12, -1.0), Vector3(1.1, 0.06, 0.8), rot, false)
	g.box("fenetre_sombre", c3 + b * Vector3(0.9, 0.45, 0.3), Vector3(0.5, 0.9, 0.5), rot, true)
	g.box("fenetre_sombre", c3 + b * Vector3(0.9, 0.98, 0.3), Vector3(1.1, 0.2, 0.42), rot, false)
	specials["forge_feu"] = c3 + b * Vector3(-1.2, 1.2, -1.0)
	specials["forgeron"] = c3 + b * Vector3(0.9, 0.0, 1.2)
	specials["forge_rot"] = rot

## Maison à colombages. rot : direction de la façade (porte) en angle Y.
static func house(g: Geo, p: Vector2, w: float, d: float, rot: float, floors: int, roof: String, rng: RandomNumberGenerator, wall_mat := "crepi") -> void:
	var b = Basis(Vector3.UP, rot)
	var corners = [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d)]
	var hmin = INF
	var hmax = -INF
	for c in corners:
		var q: Vector3 = b * Vector3(c.x * 0.5, 0, c.y * 0.5)
		var hh = Terrain.height_at(p.x + q.x, p.y + q.z)
		hmin = minf(hmin, hh)
		hmax = maxf(hmax, hh)
	var y0 = hmax + 0.25
	var c3 = Vector3(p.x, 0, p.y)
	# soubassement en pierre (rattrape la pente)
	g.box("pierre_base", Vector3(p.x, (hmin - 0.5 + y0) * 0.5, p.y), Vector3(w + 0.3, y0 - hmin + 0.5, d + 0.3), rot, true)
	var fh = 3.0
	var top = y0 + fh * floors
	# encorbellement : l'étage déborde de 30 cm sur la rue et sur l'arrière
	var jet := 0.3 if floors > 1 else 0.0
	for f in floors:
		var df: float = d + (2.0 * jet if f > 0 else 0.0)
		g.box(wall_mat, Vector3(p.x, y0 + fh * f + fh * 0.5, p.y), Vector3(w, fh, df), rot, true if f == 0 else false)
		# sablière basse / haute de chaque niveau, poteaux d'angle
		for s in [-1.0, 1.0]:
			var q: Vector3 = c3 + b * Vector3(0, 0, s * (df * 0.5 + 0.03))
			g.box("bois_sombre", Vector3(q.x, y0 + f * fh + 0.1, q.z), Vector3(w + 0.1, 0.24, 0.14), rot, false)
			g.box("bois_sombre", Vector3(q.x, y0 + (f + 1) * fh - 0.12, q.z), Vector3(w + 0.1, 0.24, 0.14), rot, false)
			var q2: Vector3 = c3 + b * Vector3(s * (w * 0.5 + 0.03), 0, 0)
			g.box("bois_sombre", Vector3(q2.x, y0 + f * fh + 0.1, q2.z), Vector3(0.14, 0.24, df + 0.1), rot, false)
			g.box("bois_sombre", Vector3(q2.x, y0 + (f + 1) * fh - 0.12, q2.z), Vector3(0.14, 0.24, df + 0.1), rot, false)
			for sx in [-1.0, 1.0]:
				var qc: Vector3 = c3 + b * Vector3(sx * w * 0.5, 0, s * df * 0.5)
				g.box("bois_sombre", Vector3(qc.x, y0 + f * fh + fh * 0.5, qc.z), Vector3(0.3, fh, 0.3), rot, false)
		if f > 0:
			# corbeaux sous le débord
			for k in int(w / 1.6) + 1:
				for s in [-1.0, 1.0]:
					var qk: Vector3 = c3 + b * Vector3(-w * 0.5 + 0.3 + k * (w - 0.6) / maxf(1.0, int(w / 1.6)), 0, s * (d * 0.5 + jet * 0.5))
					g.box("bois_sombre", Vector3(qk.x, y0 + f * fh - 0.12, qk.z), Vector3(0.16, 0.22, jet + 0.2), rot, false)
	# poteaux intermédiaires, croix de Saint-André à l'étage, fenêtres
	var bays = int(w / 2.6)
	for f in floors:
		var df: float = d + (2.0 * jet if f > 0 else 0.0)
		var yc = y0 + f * fh + fh * 0.55
		for k in bays + 1:
			var x = -w * 0.5 + k * w / bays
			for s in [-1.0, 1.0]:
				var q: Vector3 = c3 + b * Vector3(x, 0, s * (df * 0.5 + 0.04))
				g.box("bois_sombre", Vector3(q.x, y0 + f * fh + fh * 0.5, q.z), Vector3(0.18, fh, 0.1), rot, false)
		for k in bays:
			var x = -w * 0.5 + (k + 0.5) * w / bays
			var bw: float = w / bays
			for s in [-1.0, 1.0]:
				if f == 0 and s > 0 and k == bays / 2:
					continue   # emplacement de la porte
				var q: Vector3 = c3 + b * Vector3(x, 0, s * (df * 0.5 + 0.06))
				g.box("fenetre_sombre", Vector3(q.x, yc, q.z), Vector3(0.9, 1.1, 0.08), rot, false)
				var qs: Vector3 = c3 + b * Vector3(x - 0.75, 0, s * (df * 0.5 + 0.1))
				g.box("vert_volet", Vector3(qs.x, yc, qs.z), Vector3(0.5, 1.15, 0.06), rot, false)
				qs = c3 + b * Vector3(x + 0.75, 0, s * (df * 0.5 + 0.1))
				g.box("vert_volet", Vector3(qs.x, yc, qs.z), Vector3(0.5, 1.15, 0.06), rot, false)
				var ql: Vector3 = c3 + b * Vector3(x, 0, s * (df * 0.5 + 0.12))
				g.box("bois", Vector3(ql.x, yc - 0.65, ql.z), Vector3(1.2, 0.12, 0.25), rot, false)
				if s > 0 and (k + int(p.x)) % 2 == 0:
					var qf2: Vector3 = c3 + b * Vector3(x, 0, s * (df * 0.5 + 0.2))
					g.box("bois_sombre", Vector3(qf2.x, yc - 0.5, qf2.z), Vector3(1.1, 0.22, 0.26), rot, false)
					for fl in 4:
						var qq: Vector3 = c3 + b * Vector3(x - 0.42 + fl * 0.28, 0, s * (df * 0.5 + 0.2))
						g.box(["tissu_rouge", "tissu_blanc", "vert_volet", "tissu_rouge"][(fl + k) % 4], Vector3(qq.x, yc - 0.3, qq.z), Vector3(0.2, 0.16, 0.2), rot + fl, false)
				# allège en croix sous la fenêtre de l'étage
				if f > 0:
					var qb: Vector3 = c3 + b * Vector3(x, 0, s * (df * 0.5 + 0.05))
					for sg in [-1.0, 1.0]:
						var tb := Transform3D(b * Basis(Vector3.BACK, sg * 0.62), Vector3(qb.x, y0 + f * fh + 0.62, qb.z))
						g.obox("bois_sombre", tb, Vector3(minf(bw - 0.3, 1.6), 0.12, 0.08), false)
	# porte
	var xd = -w * 0.5 + (bays / 2 + 0.5) * w / bays
	var qd: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.06)
	g.box("bois", Vector3(qd.x, y0 + 1.15, qd.z), Vector3(1.3, 2.3, 0.1), rot, false)
	var qf: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.1)
	g.box("bois_sombre", Vector3(qf.x, y0 + 2.4, qf.z), Vector3(1.7, 0.22, 0.14), rot, false)
	doors.append([Vector2(qd.x, qd.z), Vector2(sin(rot), cos(rot))])
	if p.distance_to(Layout.TOWN) < 30.0:
		if not specials.has("auberge") and p.x < Layout.TOWN.x and p.y > Layout.TOWN.y:
			specials["auberge"] = [Vector2(qd.x, qd.z), Vector2(sin(rot), cos(rot))]
		elif not specials.has("forge") and p.x > Layout.TOWN.x + 8.0 and p.y < Layout.TOWN.y:
			specials["forge"] = [Vector2(qd.x, qd.z), Vector2(sin(rot), cos(rot))]
	# marche devant la porte
	var qs2: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.6)
	g.box("pierre_base", Vector3(qs2.x, y0 - 0.12, qs2.z), Vector3(1.8, 0.3, 1.0), rot, false)
	# toit à deux pans (faîtage parallèle à la façade), débord
	var rh = d * 0.72
	g.gable_roof(roof, Vector3(p.x, top, p.y), w * 0.5 + 0.6, d * 0.5 + jet + 0.75, rh, rot, wall_mat)
	# cheminée
	var qc: Vector3 = c3 + b * Vector3(w * 0.3, 0, -d * 0.18)
	g.box("pierre_base", Vector3(qc.x, top + rh * 0.6, qc.z), Vector3(0.8, rh * 1.4, 0.8), rot, false)
	chimneys.append(Vector3(qc.x, top + rh * 1.3 + 0.1, qc.z))

static func _market(g: Geo) -> void:
	var c = Layout.TOWN
	for i in 4:
		var a = TAU * i / 4.0 + PI / 4.0
		var p = c + Vector2(cos(a), sin(a)) * 9.0
		var rot = -a + PI / 2.0
		var y = Terrain.height_at(p.x, p.y)
		var b = Basis(Vector3.UP, rot)
		var c3 = Vector3(p.x, y, p.y)
		for cx in [-1.4, 1.4]:
			for cz in [-0.9, 0.9]:
				var q: Vector3 = c3 + b * Vector3(cx, 0, cz)
				g.box("bois_sombre", Vector3(q.x, y + 1.25, q.z), Vector3(0.14, 2.5 + (0.4 if cz < 0 else 0.0), 0.14), rot, false)
		g.box("bois", Vector3(p.x, y + 0.9, p.y), Vector3(3.0, 0.12, 1.4), rot, false)
		g.box("bois", c3 + b * Vector3(0, 0.45, 0), Vector3(2.8, 0.9, 1.2), rot, true)
		# auvent rayé
		for k in 6:
			var m = "tissu_rouge" if k % 2 == 0 else "tissu_blanc"
			if i % 2 == 1:
				m = "bleu_royal" if k % 2 == 0 else "tissu_blanc"
			var q: Vector3 = c3 + b * Vector3(-1.5 + 0.25 + k * 0.5, 2.75, 0)
			g.obox(m, Transform3D(b * Basis(Vector3.RIGHT, 0.22), q), Vector3(0.5, 0.05, 2.3), false)
		# marchandises
		for k in 5:
			var q: Vector3 = c3 + b * Vector3(-1.1 + k * 0.55, 0.98, 0.2)
			g.box(["or", "tissu_rouge", "cuivre", "vert_volet", "tuile"][(k + i) % 5], q, Vector3(0.35, 0.16, 0.35), rot, false)

static func _props(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var root = Node3D.new()
	root.name = "BourgDecor"
	parent.add_child(root)
	# devant chaque maison : massifs, tonneaux, caisses, bois de chauffage, banc
	for dr in doors:
		var dp: Vector2 = dr[0]
		var dd: Vector2 = dr[1]
		var side := Vector2(dd.y, -dd.x)
		var rot := atan2(dd.x, dd.y)
		for s2 in [-1.0, 1.0]:
			var q: Vector2 = dp + dd * 0.6 + side * s2 * rng.randf_range(2.0, 3.2)
			if Layout.road_dist(q) > 0.8:
				var kind: String = ["bush", "flowers", "bush", "Prop_Barrel_1", "Prop_Crate_1", "FirewoodStack", "Bench", "Prop_Hay_1"][rng.randi() % 8]
				var y := Terrain.height_at(q.x, q.y)
				if kind in ["bush", "flowers"]:
					Kit.nature(root, kind, Vector3(q.x, y, q.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
				elif kind in ["FirewoodStack", "Bench"]:
					Kit.dungeon(root, kind, Vector3(q.x, y, q.y), rot + (PI if kind == "Bench" else 0.0), 1.0)
				else:
					Kit.village(root, kind, Vector3(q.x, y, q.y), rng.randf() * TAU, 1.2)
	# arbres d'alignement le long des rues et dans les potagers
	for gd in gardens:
		var c: Vector2 = gd[0]
		var o := Vector2(cos(gd[1]), -sin(gd[1])) * 4.4
		if rng.randf() < 0.5:
			Kit.nature(root, "oak", Vector3(c.x + o.x, Terrain.height_at(c.x + o.x, c.y + o.y), c.y + o.y), rng.randf() * TAU, rng.randf_range(0.75, 0.95) * Kit.S_TREE)
	for r in [0, 1, 2]:
		var pts: Array = Layout.ROADS[r]["pts"]
		var rw: float = Layout.ROADS[r]["w"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var b: Vector2 = pts[i + 1]
			var n := Vector2(-(b - a).y, (b - a).x).normalized()
			var cnt := int(a.distance_to(b) / 15.0)
			for k in cnt:
				var q: Vector2 = a.lerp(b, (k + 0.5) / maxf(1.0, cnt)) + n * (1.0 if k % 2 == 0 else -1.0) * (rw + 1.6)
				if q.distance_to(Layout.TOWN) < 17.0 or Layout.in_castle(q, 22.0) or Layout.river_dist(q) < Layout.RIVER_W + 3.0 or Layout.in_fields(q, 1.0):
					continue
				var free := true
				for h in houses:
					if (h[0] as Vector2).distance_to(q) < (h[1] as float) + 0.8:
						free = false
						break
				if free and (r == 0 and q.y > -66.0 or r > 0) and q.distance_to(Layout.TOWN) < 140.0:
					var sk: String = ["oak", "bush", "oak", "pine"][rng.randi() % 4]
					Kit.nature(root, sk, Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), rng.randf() * TAU, rng.randf_range(0.8, 1.05) * (1.0 if sk == "bush" else Kit.S_TREE * 0.85))
	# lanterne murale à côté de chaque porte
	for i in range(0, doors.size(), 2):
		var dp: Vector2 = doors[i][0]
		var dd: Vector2 = doors[i][1]
		var sd := Vector2(dd.y, -dd.x)
		var lq: Vector2 = dp + sd * 1.2 + dd * 0.12
		Kit.village(root, "Wall_Prop_Lamp", Vector3(lq.x, Terrain.height_at(dp.x, dp.y) + 2.3, lq.y), atan2(dd.x, dd.y), 1.1)
	# bosquets entre les maisons : le bourg vit au milieu des arbres
	var trees: Array = []
	for k in 900:
		if trees.size() >= 75:
			break
		var a := rng.randf() * TAU
		var r := rng.randf_range(24.0, 100.0)
		var q: Vector2 = Layout.TOWN + Vector2(cos(a), sin(a)) * r
		if Layout.road_dist(q) < 3.2 or Layout.river_dist(q) < Layout.RIVER_W + 3.0 or Layout.in_fields(q, 3.0) or Layout.in_castle(q, 20.0):
			continue
		if absf(q.x - Layout.GATE.x) < 14.0 and q.y < Layout.GATE.y + 55.0:
			continue
		var ok := true
		for h in houses:
			if (h[0] as Vector2).distance_to(q) < (h[1] as float) + 1.6:
				ok = false
				break
		if ok:
			for t in trees:
				if (t as Vector2).distance_to(q) < 6.5:
					ok = false
					break
		if not ok:
			continue
		trees.append(q)
		var kind: String = ["oak", "oak", "pine", "oak", "pine_sapling", "oak_sapling"][rng.randi() % 6]
		Kit.nature(root, kind, Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), rng.randf() * TAU, rng.randf_range(0.8, 1.15) * Kit.S_TREE)
		if rng.randf() < 0.6:
			var bq: Vector2 = q + Vector2(rng.randf_range(-2.5, 2.5), rng.randf_range(-2.5, 2.5))
			if Layout.road_dist(bq) > 1.5:
				Kit.nature(root, ["bush", "fern", "flowers"][rng.randi() % 3], Vector3(bq.x, Terrain.height_at(bq.x, bq.y), bq.y), rng.randf() * TAU, rng.randf_range(0.8, 1.2))
	# lampadaires : autour de la place et le long de la grande rue
	for i in 4:
		var a = TAU * i / 4.0
		var q = Layout.TOWN + Vector2(cos(a), sin(a)) * 15.0
		Kit.village(root, "Prop_Lamp_Street", Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), -a, 1.3)
	for z in [-50.0, -36.0, 4.0, 18.0, 34.0]:
		var x := Layout.poly_point_x(Layout.ROADS[0]["pts"], z) + 5.2
		Kit.village(root, "Prop_Lamp_Street", Vector3(x, Terrain.height_at(x, z), z), PI / 2.0, 1.3)
	Kit.village(root, "Prop_Cart_1_Barrels", Vector3(10.5, Terrain.height_at(10.5, -46), -46), 0.2, 1.3)
	# auberge : enseigne, tables et bancs en terrasse
	if specials.has("auberge"):
		var dp: Vector2 = specials["auberge"][0]
		var dd: Vector2 = specials["auberge"][1]
		var rot := atan2(dd.x, dd.y)
		var side := Vector2(dd.y, -dd.x)
		Kit.village(root, "Wall_Prop_Sign_1", Vector3(dp.x + side.x * 1.4, Terrain.height_at(dp.x, dp.y) + 2.6, dp.y + side.y * 1.4), rot, 1.3)
		for k in 2:
			var t: Vector2 = dp + dd * 3.6 + side * (k * 3.6 - 1.8)
			var ty := Terrain.height_at(t.x, t.y)
			Kit.dungeon(root, "Table_Big", Vector3(t.x, ty, t.y), rot, 1.0)
			Kit.dungeon(root, "Bench", Vector3(t.x + dd.x * 1.1, ty, t.y + dd.y * 1.1), rot + PI, 1.0)
			Kit.dungeon(root, "Bench", Vector3(t.x - dd.x * 1.1, ty, t.y - dd.y * 1.1), rot, 1.0)
			Kit.dungeon(root, "Mug", Vector3(t.x, ty + 0.82, t.y), 0.3, 1.0)
	if specials.has("forge"):
		var wr: Vector3 = specials["forge_feu"]
		var rr: float = specials["forge_rot"]
		Kit.dungeon(root, "WeaponRack_Small", wr + Basis(Vector3.UP, rr) * Vector3(1.8, -1.2, -1.4), rr, 1.0)

## Habitants : à leur porte, dans leur potager, sur la place, à l'auberge, à la forge ; passants et enfants
## Fumée lente au-dessus d'une cheminée sur trois (peu de particules : coût minime)
static func _smoke(parent: Node3D) -> void:
	for i in range(0, chimneys.size(), 3):
		var sm := FX.particles("smoke_02", 5, 4.5, [Color(0.75, 0.75, 0.78, 0.35), Color(0.6, 0.6, 0.65, 0.0)], 1.4, false, false)
		sm.direction = Vector3(0.2, 1, 0)
		sm.spread = 10.0
		sm.initial_velocity_min = 0.5
		sm.initial_velocity_max = 0.9
		sm.gravity = Vector3(0.15, 0.05, 0)
		parent.add_child(sm)
		sm.global_position = chimneys[i]
		sm.emitting = true

static func _villageois(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.TOWN
	var hair_m := ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Buzzed"]
	var hair_f := ["Hair_Long", "Hair_Buns"]
	var spec_of := func(fem: bool) -> Dictionary:
		var tints := [Color.WHITE, Color(1.0, 0.9, 0.8), Color(0.85, 0.9, 1.0), Color(0.9, 1.0, 0.85)]
		return {"female": fem, "outfit": "paysan_f" if fem else "paysan_h", "hair": (hair_f if fem else hair_m)[rng.randi() % 2], "beard": not fem and rng.randf() < 0.4, "tint": tints[rng.randi() % 4]}
	# sur la place
	var specs = [
		[Vector2(3, 2), "Idle_Talking", false], [Vector2(4.2, 3.0), "Idle", true],
		[Vector2(-6, -4), "b/Idle_FoldArms", false], [Vector2(-8, 6.5), "Idle_Talking", true],
		[Vector2(-7, 7.6), "Idle_Talking", false], [Vector2(7.5, -7.5), "Idle", false],
	]
	for sp in specs:
		var v = Villager.new()
		v.spec = spec_of.call(sp[2])
		v.anim_name = sp[1]
		var o: Vector2 = sp[0]
		var p = c + o
		v.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		v.rotation.y = atan2(-o.x, -o.y) + randf_range(-0.6, 0.6)
		parent.add_child(v)
	# devant une porte sur deux : on discute, on balaie, on se repose
	var acts := ["Idle_Talking", "Interact", "b/Idle_FoldArms", "Idle", "b/Idle_Lantern"]
	for i in range(0, doors.size(), 3):
		var dp: Vector2 = doors[i][0]
		var dd: Vector2 = doors[i][1]
		var q: Vector2 = dp + dd * 1.6 + Vector2(dd.y, -dd.x) * rng.randf_range(-1.0, 1.0)
		var v = Villager.new()
		v.spec = spec_of.call(rng.randf() < 0.5)
		v.anim_name = acts[rng.randi() % acts.size()]
		v.position = Vector3(q.x, Terrain.height_at(q.x, q.y), q.y)
		v.rotation.y = atan2(dd.x, dd.y) + rng.randf_range(-0.5, 0.5)
		parent.add_child(v)
	# jardiniers
	for i in range(0, gardens.size(), 3):
		var gc: Vector2 = gardens[i][0]
		var v = Villager.new()
		v.spec = spec_of.call(rng.randf() < 0.4)
		v.anim_name = "b/Farm_Harvest"
		v.position = Vector3(gc.x, Terrain.height_at(gc.x, gc.y), gc.y)
		v.rotation.y = rng.randf() * TAU
		parent.add_child(v)
	# clients attablés à l'auberge
	if specials.has("auberge"):
		var dp: Vector2 = specials["auberge"][0]
		var dd: Vector2 = specials["auberge"][1]
		var side := Vector2(dd.y, -dd.x)
		for k in 3:
			var t: Vector2 = dp + dd * 3.6 + side * ((k % 2) * 3.6 - 1.8) + dd * (1.15 if k < 2 else -1.15)
			var v = Villager.new()
			v.spec = spec_of.call(k == 2)
			v.anim_name = "Sitting_Talking" if k != 1 else "Sitting_Idle"
			v.position = Vector3(t.x, Terrain.height_at(t.x, t.y) + 0.05, t.y)
			v.rotation.y = atan2(-dd.x, -dd.y) if k < 2 else atan2(dd.x, dd.y)
			parent.add_child(v)
	# le forgeron
	if specials.has("forgeron"):
		var fp: Vector3 = specials["forgeron"]
		var v = Villager.new()
		v.spec = {"outfit": "paysan_h", "beard": true, "hair": "Hair_Buzzed", "tint": Color(0.55, 0.45, 0.4)}
		v.anim_name = "b/Sword_Regular_A"
		v.position = fp
		v.rotation.y = float(specials["forge_rot"]) + PI
		parent.add_child(v)
		v.set_meta("forge", true)
		var fire := FX.particles("fire_01", 10, 0.6, [Color(1, 0.8, 0.4, 0.9), Color(1, 0.3, 0.1, 0)], 0.5, false)
		fire.direction = Vector3.UP
		fire.initial_velocity_min = 0.4
		fire.initial_velocity_max = 0.9
		fire.gravity = Vector3.ZERO
		parent.add_child(fire)
		fire.global_position = specials["forge_feu"]
		fire.emitting = true
	# passants le long des rues
	var routes := [
		[Vector2(2, -12), Vector2(1, -40), Vector2(0, -62), Vector2(1, -40)],
		[Vector2(10, -18), Vector2(40, -14), Vector2(70, -8), Vector2(40, -14)],
		[Vector2(-6, -22), Vector2(-40, -18), Vector2(-75, -12), Vector2(-40, -18)],
		[Vector2(4, 0), Vector2(8, 22), Vector2(18, 46), Vector2(8, 22)],
		[Vector2(-30, -20), Vector2(-60, -14), Vector2(-90, -10), Vector2(-60, -14)],
		[Vector2(28, 80), Vector2(26, 100), Vector2(28, 80), Vector2(22, 60)],
	]
	for i in routes.size():
		var w = Villager.new()
		w.spec = spec_of.call(i % 2 == 1)
		w.path = routes[i]
		w.speed = rng.randf_range(1.1, 1.5)
		parent.add_child(w)
	# enfants qui courent autour de la place
	for k in 3:
		var kid = Villager.new()
		kid.spec = spec_of.call(k == 1)
		var pts := []
		for j in 8:
			var a := TAU * (j + k * 2.7) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * (11.5 + k * 0.8))
		kid.path = pts
		kid.speed = 2.2
		parent.add_child(kid)
		kid.scale = Vector3.ONE * 0.66
		kid.set_meta("enfant", true)

## Sentier de terre battue de chaque porte jusqu'à la route ou la place la plus proche.
static func _paths(g: Geo) -> void:
	for d in doors:
		var start: Vector2 = d[0] + d[1] * 1.2
		var best := Vector2.INF
		var bd := INF
		for r in Layout.ROADS:
			var pts: Array = r["pts"]
			for i in pts.size() - 1:
				var a: Vector2 = pts[i]
				var b: Vector2 = pts[i + 1]
				var ab := b - a
				var t := clampf((start - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
				var q := a + ab * t
				var dist := start.distance_to(q) - float(r["w"])
				if dist < bd:
					bd = dist
					best = q + (start - q).normalized() * (float(r["w"]) - 0.4)
		var sq := Layout.TOWN + (start - Layout.TOWN).normalized() * 13.6
		if start.distance_to(sq) < bd:
			bd = start.distance_to(sq)
			best = sq
		if bd > 45.0 or bd < 0.5:
			continue
		# léger détour en S pour un tracé naturel
		var steps := int(ceil(start.distance_to(best) / 1.5))
		var prev := start
		for k in range(1, steps + 1):
			var t := float(k) / steps
			var p := start.lerp(best, t)
			var side := Vector2(-(best - start).y, (best - start).x).normalized()
			p += side * sin(t * PI) * minf(2.0, bd * 0.08)
			var dir := (p - prev).normalized()
			var n := Vector2(-dir.y, dir.x) * 0.75
			var a0 := Vector3(prev.x - n.x, Terrain.height_at(prev.x - n.x, prev.y - n.y) + 0.07, prev.y - n.y)
			var a1 := Vector3(prev.x + n.x, Terrain.height_at(prev.x + n.x, prev.y + n.y) + 0.07, prev.y + n.y)
			var b1 := Vector3(p.x + n.x, Terrain.height_at(p.x + n.x, p.y + n.y) + 0.07, p.y + n.y)
			var b0 := Vector3(p.x - n.x, Terrain.height_at(p.x - n.x, p.y - n.y) + 0.07, p.y - n.y)
			g.quad("terre", a0, a1, b1, b0, 1)
			g.quad("terre", b0, b1, a1, a0, 1)
			prev = p
