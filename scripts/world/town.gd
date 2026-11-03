class_name Town
## Le bourg de Valmont au pied du château : construit par BourgPlan (scripts/world/bourg/plan.gd)
## en pièces MegaKit — place du marché, Grand-Rue à trottoirs, rues, venelles, impasse, arrière-cours,
## taverne et maisons visitables. Ce fichier assemble le tout et pose la vie (marché, forge, habitants).

static var houses: Array = []    # [centre Vector2, rayon] : emprises (bâtiments, cours, rues) — pas d'arbres dessus
static var chimneys: Array = []  # sommets de cheminées (fumée)
static var doors: Array = []     # [position de la porte (Vector2), direction de la façade (Vector2)]
static var gardens: Array = []   # [centre, rotation] des potagers clôturés
static var specials := {}        # "auberge" / "forge" / "taverne"… -> [porte Vector2, direction Vector2] (+ données)
static var plan: BourgPlan

static func build(parent: Node3D) -> void:
	houses.clear()
	doors.clear()
	chimneys.clear()
	gardens.clear()
	specials.clear()
	var t0 := Time.get_ticks_msec()
	var root := Node3D.new()
	root.name = "Bourg"
	parent.add_child(root)
	plan = BourgPlan.new()
	plan.build(root)
	var props: Node3D = plan.props
	props.get_parent().remove_child(props)
	parent.add_child(props)   # "BourgDecor" : fusionné par le monde (Batcher)
	var rng := RandomNumberGenerator.new()
	rng.seed = 77
	doors = plan.b.doors
	chimneys = plan.b.chimneys
	for h in plan.built:
		houses.append([h["pos"], Vector2(int(h["w"]), int(h["d"])).length() * Bourg.M * 0.5 + 0.8])
	for r in plan.reserve:
		houses.append(r)
	# lieux nommés (portes) pour la vie du bourg et les tests
	for nm in plan.specials:
		var sp = plan.specials[nm]
		if sp is Dictionary and sp.has("door"):
			var dp: Vector3 = sp["door"]
			specials[nm] = [Vector2(dp.x, dp.z), sp["face"]]
	print("[bourg] lieux : ", plan.specials.keys())
	if specials.has("taverne"):
		specials["auberge"] = specials["taverne"]
	_forge(plan, props)
	_market(plan, props)
	_props(plan, props, rng)
	var pot := Node3D.new()
	pot.name = "Potagers"
	parent.add_child(pot)
	BourgDeco.yards(plan, pot, props, rng)
	BourgDeco.interiors(plan, root, props)
	# maillages : rez-de-chaussée et décor fixe (fusion par matériau), étages des maisons visitables à part
	plan.mk.commit(root, "Maisons")
	for nm in plan.mk_up:
		var up: Node3D = (plan.mk_up[nm] as MK).commit(root, "Etage_" + nm)
		BourgDeco.visit_zone(plan, root, nm, up)
	plan.geo.commit(root, "Sols", 2)
	_smoke(parent)
	_villageois(parent, rng)
	print("[bourg] %d maisons, %d portes, %d triangles (+%d détails), %d ms" % [plan.built.size(), doors.size(), plan.mk.tris, plan.mk.det.tris, Time.get_ticks_msec() - t0])

## Forge : appentis ouvert sur la Rue de l'Est (foyer, enclume, établi, râtelier)
static func _forge(p: BourgPlan, props: Node3D) -> void:
	var r1: Array = Layout.ROADS[1]["pts"]
	var a: Vector2 = r1[1]
	var e: Vector2 = r1[2]
	var dir := (e - a).normalized()
	var n := Vector2(-dir.y, dir.x)   # vers le sud
	var c: Vector2 = a + dir * 7.8 + n * (4.4 + 3.2)
	var face := -n
	var rot := atan2(face.x, face.y)
	var b := Basis(Vector3.UP, rot)
	var y := Terrain.height_at(c.x, c.y) + 0.05
	var c3 := Vector3(c.x, y, c.y)
	var tint := {"MI_WoodTrim": Bourg.WOOD[2], "MI_WoodTrim_Wear": Bourg.WOOD[2], "MI_RoundTiles": Bourg.TILES[4]}
	# poteaux et toit de tuiles
	for cx in [-2.6, 0.0, 2.6]:
		for cz in [-2.0, 2.0]:
			p.mk.add("Corner_Exterior_Wood", Transform3D(b, c3 + b * Vector3(cx, 0, cz)), tint)
	p.mk.add("Roof_RoundTiles_4x6", Transform3D(b * Basis(Vector3.UP, PI / 2.0), c3 + Vector3(0, 3.0, 0)), tint)
	# mur du fond en pierre
	for k in 3:
		p.mk.add("Wall_UnevenBrick_Straight", Transform3D(b * Basis(Vector3.UP, PI), c3 + b * Vector3(-2.0 + k * 2.0, 0, -2.0)), tint)
	p.mk.col_box(Transform3D(b, c3 + b * Vector3(0, 1.5, -2.15)), Vector3(6.0, 3.0, 0.3))
	p.geo.obox("dallage", Transform3D(b, c3 + Vector3(0, -0.05, 0)), Vector3(6.4, 0.2, 4.6), false)
	# foyer de pierre, hotte, enclume, établi
	p.geo.box("pierre_base", c3 + b * Vector3(-1.6, 0.55, -1.2), Vector3(1.8, 1.1, 1.4), rot, true)
	p.geo.box("fenetre_sombre", c3 + b * Vector3(-1.6, 1.12, -1.2), Vector3(1.2, 0.06, 0.9), rot, false)
	p.geo.box("pierre_base", c3 + b * Vector3(-1.6, 2.2, -1.5), Vector3(1.4, 1.6, 0.8), rot, false)
	p.geo.box("fer", c3 + b * Vector3(0.6, 0.45, 0.2), Vector3(0.45, 0.9, 0.45), rot, true)
	p.geo.box("fer", c3 + b * Vector3(0.6, 0.98, 0.2), Vector3(1.0, 0.2, 0.4), rot, false)
	Kit.dungeon(props, "Table_Small", c3 + b * Vector3(2.0, 0, -1.2), rot, 1.0)
	Kit.dungeon(props, "WeaponRack_Big", c3 + b * Vector3(2.4, 0, 0.6), rot - PI / 2.0, 1.0)
	Kit.dungeon(props, "Barrel_Open", c3 + b * Vector3(-0.2, 0, -1.5), 0.0, 1.0)
	Kit.dungeon(props, "Sword", c3 + b * Vector3(2.0, 0.85, -1.2), rot, 1.0)
	Kit.dungeon(props, "Shield", c3 + b * Vector3(1.2, 0, -1.85), rot, 1.0)
	Kit.village(props, "Wall_Prop_Sign_1", c3 + b * Vector3(-3.2, 2.4, 2.1), rot, 1.2)
	p.boxes.append([c, Vector2(3.2, 2.4), rot])
	houses.append([c, 4.0])
	specials["forge"] = [c + face * 2.4, face]
	specials["forge_feu"] = c3 + b * Vector3(-1.6, 1.2, -1.2)
	specials["forgeron"] = c3 + b * Vector3(0.6, 0.0, 1.1)
	specials["forge_rot"] = rot

## Marché : 4 étals rayés autour du puits (les marchands se placent derrière, cf. Talk), bancs, lanternes
static func _market(p: BourgPlan, props: Node3D) -> void:
	var c := Layout.TOWN
	for i in 4:
		var a := TAU * i / 4.0 + PI / 4.0
		var q := c + Vector2(cos(a), sin(a)) * 9.0
		var face := (c - q).normalized()
		Kit.place(props, "res://assets/village2/mdvl_village_stall_01.glb", Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.08, q.y), atan2(face.x, face.y), 1.25)
		# marchandises sur l'étal
		var goods: Array = [["Bread", "Bread_Half", "Bowl_Full"], ["Jar_Full", "Bottle", "Jug"], ["Potion_Red", "Potion_Blue", "Potion_Green"], ["Carrot", "Potato", "Meat"]][i]
		var side := Vector2(face.y, -face.x)
		for k in 3:
			var g: Vector2 = q + face * 0.25 + side * (k - 1) * 0.55
			Kit.dungeon(props, goods[k], Vector3(g.x, Terrain.height_at(q.x, q.y) + 1.0, g.y), rot_of(face) + k, 1.0)
		var bq: Vector2 = q - face * 1.6 + side * 1.4
		Kit.dungeon(props, ["Barrel_Closed", "Bag", "Barrel_Open", "Bag"][i], Vector3(bq.x, Terrain.height_at(bq.x, bq.y) + 0.08, bq.y), a, 1.0)
	Kit.village(props, "Prop_Well_Cobblestone", Vector3(c.x, Terrain.height_at(c.x, c.y) + 0.08, c.y), 0.0, 1.6)
	p.boxes.append([c, Vector2(2.0, 2.0), 0.0])

static func rot_of(face: Vector2) -> float:
	return atan2(face.x, face.y)

## Lanternes, enseignes, bancs, tonneaux, charrettes, lampadaires
static func _props(p: BourgPlan, root: Node3D, rng: RandomNumberGenerator) -> void:
	# lampadaires aux coins de la place et le long de la Grand-Rue
	for q in [Vector2(-15.5, -33.5), Vector2(15.5, -33.5), Vector2(-15.5, -7.5), Vector2(15.5, -7.5)]:
		Kit.village(root, "Prop_Lamp_Street", Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.1, q.y), atan2(-q.x, -(q.y + 20.0)), 1.3)
	for h in p.built:
		var face: Vector2 = h["face"]
		var dp: Vector3 = h["door"]
		var xl := Vector2(face.y, -face.x)
		var rot := atan2(face.x, face.y)
		var y0: float = h["y0"]
		var dq := Vector2(dp.x, dp.z)
		# lanterne murale à côté de la porte (une maison sur deux), enseigne pour les boutiques
		if h.get("shop", false) or h.has("name"):
			var sq: Vector2 = dq + xl * 1.35 + face * 0.15
			Kit.village(root, "Wall_Prop_Sign_1", Vector3(sq.x, y0 + 2.75, sq.y), rot, 1.25)
		if rng.randf() < 0.5:
			var lq: Vector2 = dq - xl * 1.25 + face * 0.12
			Kit.village(root, "Wall_Prop_Lamp", Vector3(lq.x, y0 + 2.2, lq.y), rot, 1.1)
		# devant la porte : tonneau, caisse, banc, pots de fleurs (pas sur la place pour ne pas l'encombrer)
		if rng.randf() < 0.55:
			var s2 := -1.0 if rng.randf() < 0.5 else 1.0
			var q: Vector2 = dq + face * 0.55 + xl * s2 * rng.randf_range(1.6, 2.3)
			var kind: String = ["Prop_Barrel_1", "Prop_Crate_1", "Bench", "flowers", "Barrel_Closed", "Prop_Barrel_1_Open", "Bucket"][rng.randi() % 7]
			var y := Terrain.height_at(q.x, q.y) + 0.14
			if kind == "flowers":
				Kit.nature(root, "flowers", Vector3(q.x, y, q.y), rng.randf() * TAU, 0.9)
			elif kind.begins_with("Prop_"):
				Kit.village(root, kind, Vector3(q.x, y, q.y), rng.randf() * TAU, 1.1)
			else:
				Kit.dungeon(root, kind, Vector3(q.x, y, q.y), rot + (PI if kind == "Bench" else rng.randf() * TAU), 1.0)
		# lierre sur certains murs
		if rng.randf() < 0.25:
			var vq: Vector2 = dq + xl * (rng.randf_range(-2.5, 2.5)) + face * 0.12
			p.mk.add(["Prop_Vine1", "Prop_Vine2", "Prop_Vine5"][rng.randi() % 3], Transform3D(Basis(Vector3.UP, rot), Vector3(vq.x, y0 + 2.9, vq.y)))
	# lampadaires le long des rues (tous les ~16 m, en alternance)
	var streets: Array = [Layout.ROADS[0]["pts"].slice(1, 7)]
	for k in BourgPlan.STREETS:
		streets.append(BourgPlan.STREETS[k]["pts"])
	for pts in streets:
		var acc := 8.0
		var sd := 1.0
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var e: Vector2 = pts[i + 1]
			var L := a.distance_to(e)
			var dir := (e - a) / L
			var n := Vector2(-dir.y, dir.x)
			while acc < L:
				var w: float = 3.6 if pts.size() > 3 and pts[0] == Layout.ROADS[0]["pts"][1] else 2.4
				var q: Vector2 = a + dir * acc + n * sd * (w + 0.9)
				if not p._in_square(q, 1.0) and Layout.river_dist(q) > Layout.RIVER_W + 2.0 and q.y > -64.0:
					Kit.village(root, "Prop_Lamp_Street", Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.14, q.y), atan2(-n.x * sd, -n.y * sd), 1.3)
				acc += 16.0
				sd = -sd
			acc -= L
	# charrettes et bancs sur la place
	Kit.village(root, "Prop_Cart_1_Barrels", Vector3(-12.0, Terrain.height_at(-12, -30) + 0.1, -30.0), 0.5, 1.3)
	Kit.village(root, "Prop_Cart_1_Hay", Vector3(13.0, Terrain.height_at(13, -9) + 0.1, -9.0), -2.4, 1.3)
	for q in [Vector2(-9, -12), Vector2(9, -28), Vector2(-9, -28)]:
		Kit.dungeon(root, "Bench", Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.1, q.y), atan2(-q.x, -(q.y + 20.0)), 1.0)
	# puits de l'impasse
	if p.specials.has("puits_impasse"):
		var w: Vector2 = p.specials["puits_impasse"]
		Kit.village(root, "Prop_Well_1", Vector3(w.x, Terrain.height_at(w.x, w.y), w.y), 0.4, 1.4)
		p.boxes.append([w, Vector2(1.6, 1.6), 0.0])

## Habitants : aux portes, dans les cours, sur la place, à la taverne, à la forge ; passants et enfants
static func _villageois(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.TOWN
	var hair_m := ["Hair_Buzzed", "Hair_SimpleParted", "Hair_Buzzed"]
	var hair_f := ["Hair_Long", "Hair_Buns"]
	var spec_of := func(fem: bool) -> Dictionary:
		var tints := [Color.WHITE, Color(1.0, 0.9, 0.8), Color(0.85, 0.9, 1.0), Color(0.9, 1.0, 0.85)]
		return {"female": fem, "outfit": "paysan_f" if fem else "paysan_h", "hair": (hair_f if fem else hair_m)[rng.randi() % 2], "beard": not fem and rng.randf() < 0.4, "tint": tints[rng.randi() % 4]}
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
		v.position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)
		v.rotation.y = atan2(-o.x, -o.y) + randf_range(-0.6, 0.6)
		parent.add_child(v)
	# devant une porte sur trois : on discute, on balaie, on se repose
	var acts := ["Idle_Talking", "Interact", "b/Idle_FoldArms", "Idle", "b/Idle_Lantern"]
	for i in range(0, doors.size(), 5):
		var dp: Vector2 = doors[i][0]
		var dd: Vector2 = doors[i][1]
		var q: Vector2 = dp + dd * 1.4 + Vector2(dd.y, -dd.x) * rng.randf_range(-0.8, 0.8)
		var v = Villager.new()
		v.spec = spec_of.call(rng.randf() < 0.5)
		v.anim_name = acts[rng.randi() % acts.size()]
		v.position = Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.14, q.y)
		v.rotation.y = atan2(dd.x, dd.y) + rng.randf_range(-0.5, 0.5)
		parent.add_child(v)
	# jardiniers
	for i in range(0, gardens.size(), 2):
		var gc: Vector2 = gardens[i][0]
		var v = Villager.new()
		v.spec = spec_of.call(rng.randf() < 0.4)
		v.anim_name = "b/Farm_Harvest"
		v.position = Vector3(gc.x, Terrain.height_at(gc.x, gc.y), gc.y)
		v.rotation.y = rng.randf() * TAU
		parent.add_child(v)
	# la taverne : tavernier au comptoir, clients attablés
	for t in BourgDeco.patrons:
		var v = Villager.new()
		v.spec = spec_of.call(bool(t[2]))
		v.anim_name = t[1]
		v.position = t[0]
		v.rotation.y = t[3]
		parent.add_child(v)
		if t.size() > 4:
			v.set_meta("talk", t[4])
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
		[Vector2(2, -12), Vector2(1, -40), Vector2(0.5, -58), Vector2(1, -40)],
		[Vector2(10, -18), Vector2(30, -14.5), Vector2(46, -11), Vector2(30, -14.5)],
		[Vector2(-10, -21), Vector2(-40, -18.5), Vector2(-70, -12.5), Vector2(-40, -18.5)],
		[Vector2(2, -2), Vector2(6, 20), Vector2(16, 44), Vector2(6, 20)],
		[Vector2(4, 14.5), Vector2(-20, 15.5), Vector2(-45, 12), Vector2(-60, 2), Vector2(-45, 12), Vector2(-20, 15.5)],
		[Vector2(-58, -18), Vector2(-57.5, -38), Vector2(-55, -55), Vector2(-57.5, -38)],
		[Vector2(36.6, -13), Vector2(36.2, -34), Vector2(35.4, -52), Vector2(36.2, -34)],
		[Vector2(11, 30.5), Vector2(22, 28.5), Vector2(33, 26.5), Vector2(22, 28.5)],
		[Vector2(-14, -32), Vector2(14, -32), Vector2(14, -9), Vector2(-14, -9)],
	]
	for i in routes.size():
		var w = Villager.new()
		w.spec = spec_of.call(i % 2 == 1)
		w.path = routes[i]
		w.speed = rng.randf_range(1.1, 1.5)
		parent.add_child(w)
	# enfants qui courent autour du puits
	for k in 3:
		var kid = Villager.new()
		kid.spec = spec_of.call(k == 1)
		var pts := []
		for j in 8:
			var a := TAU * (j + k * 2.7) / 8.0
			pts.append(c + Vector2(cos(a), sin(a)) * (4.0 + k * 0.7))
		kid.path = pts
		kid.speed = 2.2
		parent.add_child(kid)
		kid.scale = Vector3.ONE * 0.66
		kid.set_meta("enfant", true)

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
