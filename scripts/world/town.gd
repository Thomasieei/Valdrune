class_name Town
## Le bourg au pied du château : maisons à colombages autour d'une place pavée,
## étals de marché, puits, villageois. Maisons orientées vers la place ou la route.

static var houses: Array = []
static var doors: Array = []    # [position de la porte (Vector2), direction de la façade (Vector2)]   # [centre Vector2, demi-taille Vector2] pour éviter les chevauchements

static func build(parent: Node3D) -> void:
	houses.clear()
	doors.clear()
	var g = Geo.new()
	var rng = RandomNumberGenerator.new()
	rng.seed = 77
	# anneau de maisons autour de la place, façade vers le centre
	var ang = 0.0
	var placed = 0
	for ring in [[24.0, 14], [38.0, 20]]:
		var r: float = ring[0]
		var n: int = ring[1]
		for i in n:
			var a = TAU * i / n + (0.2 if r > 30 else 0.0)
			var p = Layout.TOWN + Vector2(cos(a), sin(a)) * (r + rng.randf_range(-2, 2))
			var w = rng.randf_range(7.0, 10.0)
			var d = rng.randf_range(6.0, 7.5)
			var face = atan2(Layout.TOWN.x - p.x, Layout.TOWN.y - p.y)
			if _try_house(g, p, w, d, face, rng):
				placed += 1
	# quelques maisons le long de la route du sud
	for k in 6:
		var z = 30.0 + k * 13.0
		for side in [-1.0, 1.0]:
			if rng.randf() < 0.35:
				continue
			var rx = 2.0 + (z - 20.0) * 0.32 if z < 48 else 18.0 + (z - 48) * 0.4
			var p = Vector2(rx + side * 13.0, z)
			_try_house(g, p, rng.randf_range(7, 9), rng.randf_range(6, 7), -side * PI / 2.0, rng)
	_market(g)
	_paths(g)
	g.commit(parent, "Bourg")
	Kit.village(parent, "Prop_Well_Cobblestone", Vector3(Layout.TOWN.x, Terrain.height_at(Layout.TOWN.x, Layout.TOWN.y), Layout.TOWN.y), 0.0, 1.6)
	_props(parent, rng)
	_villageois(parent)

static func _try_house(g: Geo, p: Vector2, w: float, d: float, rot: float, rng: RandomNumberGenerator) -> bool:
	var rad = Vector2(w, d).length() * 0.5 + 1.5
	if Layout.road_dist(p) < rad - 1.0 or p.distance_to(Layout.TOWN) < 18.0:
		return false
	if Layout.river_dist(p) < Layout.RIVER_W + rad + 3.0 or Layout.in_castle(p, 25.0):
		return false
	if absf(p.x - Layout.GATE.x) < 16.0 and p.y < Layout.GATE.y + 58.0:
		return false
	for h in houses:
		if (h[0] as Vector2).distance_to(p) < rad + (h[1] as float):
			return false
	houses.append([p, rad])
	var roofs = ["tuile", "tuile", "chaume", "ardoise"]
	house(g, p, w, d, rot, 2 if rng.randf() < 0.65 else 1, roofs[rng.randi() % roofs.size()], rng)
	return true

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
	g.box(wall_mat, Vector3(p.x, y0 + fh * floors * 0.5, p.y), Vector3(w, fh * floors, d), rot, true)
	# colombages : poteaux d'angle, sablières, croix de Saint-André
	for c in corners:
		var q: Vector3 = c3 + b * Vector3(c.x * 0.5, 0, c.y * 0.5)
		g.box("bois_sombre", Vector3(q.x, y0 + fh * floors * 0.5, q.z), Vector3(0.32, fh * floors, 0.32), rot, false)
	for f in floors + 1:
		var yy = y0 + f * fh - (0.12 if f == floors else 0.0)
		for s in [-1.0, 1.0]:
			var q: Vector3 = c3 + b * Vector3(0, 0, s * (d * 0.5 + 0.03))
			g.box("bois_sombre", Vector3(q.x, yy, q.z), Vector3(w + 0.1, 0.24, 0.12), rot, false)
			var q2: Vector3 = c3 + b * Vector3(s * (w * 0.5 + 0.03), 0, 0)
			g.box("bois_sombre", Vector3(q2.x, yy, q2.z), Vector3(0.12, 0.24, d + 0.1), rot, false)
	# poteaux intermédiaires + fenêtres sur la façade et l'arrière
	var bays = int(w / 2.6)
	for f in floors:
		var yc = y0 + f * fh + fh * 0.55
		for k in bays + 1:
			var x = -w * 0.5 + k * w / bays
			for s in [-1.0, 1.0]:
				var q: Vector3 = c3 + b * Vector3(x, 0, s * (d * 0.5 + 0.04))
				g.box("bois_sombre", Vector3(q.x, y0 + f * fh + fh * 0.5, q.z), Vector3(0.18, fh, 0.1), rot, false)
		for k in bays:
			var x = -w * 0.5 + (k + 0.5) * w / bays
			for s in [-1.0, 1.0]:
				if f == 0 and s > 0 and k == bays / 2:
					continue   # emplacement de la porte
				var q: Vector3 = c3 + b * Vector3(x, 0, s * (d * 0.5 + 0.06))
				g.box("fenetre_sombre", Vector3(q.x, yc, q.z), Vector3(0.9, 1.1, 0.08), rot, false)
				var qs: Vector3 = c3 + b * Vector3(x - 0.75, 0, s * (d * 0.5 + 0.1))
				g.box("vert_volet", Vector3(qs.x, yc, qs.z), Vector3(0.5, 1.15, 0.06), rot, false)
				qs = c3 + b * Vector3(x + 0.75, 0, s * (d * 0.5 + 0.1))
				g.box("vert_volet", Vector3(qs.x, yc, qs.z), Vector3(0.5, 1.15, 0.06), rot, false)
				var ql: Vector3 = c3 + b * Vector3(x, 0, s * (d * 0.5 + 0.12))
				g.box("bois", Vector3(ql.x, yc - 0.65, ql.z), Vector3(1.2, 0.12, 0.25), rot, false)
	# porte
	var xd = -w * 0.5 + (bays / 2 + 0.5) * w / bays
	var qd: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.06)
	g.box("bois", Vector3(qd.x, y0 + 1.15, qd.z), Vector3(1.3, 2.3, 0.1), rot, false)
	var qf: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.1)
	g.box("bois_sombre", Vector3(qf.x, y0 + 2.4, qf.z), Vector3(1.7, 0.22, 0.14), rot, false)
	doors.append([Vector2(qd.x, qd.z), Vector2(sin(rot), cos(rot))])
	# marche devant la porte
	var qs2: Vector3 = c3 + b * Vector3(xd, 0, d * 0.5 + 0.6)
	g.box("pierre_base", Vector3(qs2.x, y0 - 0.12, qs2.z), Vector3(1.8, 0.3, 1.0), rot, false)
	# toit à deux pans (faîtage parallèle à la façade), débord
	var rh = d * 0.55
	g.gable_roof(roof, Vector3(p.x, top, p.y), w * 0.5 + 0.6, d * 0.5 + 0.7, rh, rot, wall_mat)
	# cheminée
	var qc: Vector3 = c3 + b * Vector3(w * 0.3, 0, -d * 0.18)
	g.box("pierre_base", Vector3(qc.x, top + rh * 0.6, qc.z), Vector3(0.8, rh * 1.4, 0.8), rot, false)

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
	for h in houses:
		var p: Vector2 = h[0]
		if rng.randf() < 0.5:
			var o = Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * (h[1] + 0.5)
			var q = p + o
			if Layout.road_dist(q) > 1.5:
				var k: String = ["Prop_Barrel_1", "Prop_Crate_1", "Prop_Barrel_2", "Prop_Hay_1"][rng.randi() % 4]
				Kit.village(root, k, Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), rng.randf() * TAU, 1.2)
	for i in 4:
		var a = TAU * i / 4.0
		var q = Layout.TOWN + Vector2(cos(a), sin(a)) * 15.0
		Kit.village(root, "Prop_Lamp_Street", Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), -a, 1.3)
	Kit.village(root, "Prop_Cart_1_Barrels", Vector3(Layout.TOWN.x + 6, Terrain.height_at(6, -32), -32), 0.6, 1.3)

static func _villageois(parent: Node3D) -> void:
	var c = Layout.TOWN
	var specs = [
		[Vector2(3, 2), "Idle_Talking", {"outfit": "paysan_h", "beard": true}],
		[Vector2(4.2, 3.0), "Idle", {"female": true, "outfit": "paysan_f", "hair": "Hair_Buns"}],
		[Vector2(-6, -4), "b/Idle_FoldArms", {"outfit": "paysan_h", "hair": "Hair_Buzzed"}],
		[Vector2(-8, 6.5), "Idle_Talking", {"female": true, "outfit": "paysan_f", "hair": "Hair_Long"}],
		[Vector2(7.5, -7.5), "Idle", {"outfit": "paysan_h", "hair": "Hair_SimpleParted", "tint": Color(0.8, 0.9, 1.0)}],
	]
	for s in specs:
		var v = Villager.new()
		v.spec = s[2]
		v.anim_name = s[1]
		var o: Vector2 = s[0]
		var p = c + o
		v.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		v.rotation.y = atan2(-o.x, -o.y) + randf_range(-0.6, 0.6)
		parent.add_child(v)
	# deux passants qui circulent entre la place, la porte du château et la route
	var w1 = Villager.new()
	w1.spec = {"outfit": "paysan_h", "beard": true, "tint": Color(1.0, 0.9, 0.8)}
	w1.path = [Vector2(2, -12), Vector2(1, -40), Vector2(0, -62), Vector2(1, -40)]
	parent.add_child(w1)
	var w2 = Villager.new()
	w2.spec = {"female": true, "outfit": "paysan_f", "hair": "Hair_Buns"}
	w2.path = [Vector2(10, -18), Vector2(40, -14), Vector2(70, -8), Vector2(40, -14)]
	parent.add_child(w2)

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
