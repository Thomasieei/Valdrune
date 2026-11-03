class_name BourgDeco
## Décor du bourg : arrière-cours (potagers, bûchers, linge, remises) et intérieurs meublés des
## maisons visitables (taverne du Sanglier Doré, échoppe de l'apothicaire, maison de Mathis).

static var patrons: Array = []   # [position Vector3, animation, femme ?, rotation, talk?] posés par Town
static var furn: Node3D           # mobilier (fusionné avec le décor du bourg, avec collisions)

# ---------------------------------------------------------------- arrière-cours

static func yards(p: BourgPlan, pot: Node3D, props: Node3D, rng: RandomNumberGenerator) -> void:
	patrons.clear()
	var n_garden := 0
	for y in p.yards:
		var c: Vector2 = y["c"]
		var face: Vector2 = y["face"]
		var hw: float = y["hw"]
		var depth: float = y["depth"]
		var rot := atan2(face.x, face.y)
		var xl := Vector2(face.y, -face.x)
		# clôture de planches : fond et côtés, portillon au fond
		var nx := int(round(hw))
		var back: Vector2 = c - face * depth * 0.5
		for i in nx:
			if i == nx / 2:
				continue
			var q: Vector2 = back + xl * (-hw + Bourg.M * (i + 0.5))
			_fence(p, q, rot + PI / 2.0 + PI / 2.0)
		var nz := int(floor(depth / 2.0))
		for s in [-1.0, 1.0]:
			for j in nz:
				var q: Vector2 = c + xl * s * hw - face * (depth * 0.5 - Bourg.M * (j + 0.5))
				_fence(p, q, rot + PI / 2.0)
		var kind := rng.randf()
		if kind < 0.38 and depth >= 5.5 and hw >= 2.6:
			Town._garden(pot, c, rot, rng)
			Town.gardens.append([c, rot])
			n_garden += 1
		elif kind < 0.6:
			# bûcher : bois empilé contre le mur, billot, hache
			var q: Vector2 = c + face * (depth * 0.5 - 0.8) + xl * (hw - 1.4)
			Kit.dungeon(props, "FirewoodStack", _v3(q), rot + PI, 1.2)
			var q2: Vector2 = c + xl * (-hw * 0.3)
			Kit.nature(props, "stump", _v3(q2), rng.randf() * TAU, 0.8)
			Kit.dungeon(props, "Firewood", _v3(q2 + face * 1.2), rng.randf() * TAU, 1.0)
		elif kind < 0.8:
			# fil à linge entre deux poteaux, draps colorés
			var a: Vector2 = c - xl * (hw - 0.8)
			var e: Vector2 = c + xl * (hw - 0.8)
			var ya := Terrain.height_at(a.x, a.y)
			var ye := Terrain.height_at(e.x, e.y)
			p.geo.box("bois_sombre", Vector3(a.x, ya + 1.0, a.y), Vector3(0.12, 2.0, 0.12), rot, false)
			p.geo.box("bois_sombre", Vector3(e.x, ye + 1.0, e.y), Vector3(0.12, 2.0, 0.12), rot, false)
			var L := a.distance_to(e)
			p.geo.obox("bois_sombre", Transform3D(Basis(Vector3.UP, rot + PI / 2.0), Vector3((a.x + e.x) * 0.5, (ya + ye) * 0.5 + 1.95, (a.y + e.y) * 0.5)), Vector3(L, 0.03, 0.03), false)
			var cols := ["tissu_blanc", "tissu_rouge", "tissu_blanc", "bleu_royal", "tissu_blanc"]
			var nb := int(L / 1.1)
			for k in nb:
				var q: Vector2 = a.lerp(e, (k + 0.5) / nb)
				p.geo.box(cols[(k + int(c.x)) % cols.size()], Vector3(q.x, (ya + ye) * 0.5 + 1.5, q.y), Vector3(0.8, 0.85, 0.03), rot, false)
		else:
			# remise : tonneaux, caisses, charrette, foin
			var q: Vector2 = c + xl * (hw - 1.3) - face * 0.3
			Kit.village(props, ["Prop_Cart_1", "Prop_Cart_1_Hay", "Prop_Hay_1"][rng.randi() % 3], _v3(q), rot + PI / 2.0, 1.2)
			Kit.village(props, "Prop_Barrel_1", _v3(c - xl * (hw - 1.0) + face * 1.0), rng.randf() * TAU, 1.1)
			Kit.village(props, "Prop_Crate_1", _v3(c - xl * (hw - 1.0) - face * 0.4), rng.randf() * TAU, 1.1)
		# un arbre fruitier dans une cour sur trois
		if rng.randf() < 0.35:
			var tq: Vector2 = c - face * (depth * 0.5 - 1.2) + xl * rng.randf_range(-hw + 1.2, hw - 1.2)
			Kit.nature(props, ["oak_sapling", "birch", "oak_sapling"][rng.randi() % 3], _v3(tq), rng.randf() * TAU, rng.randf_range(1.2, 1.6))
	print("[bourg] cours=%d potagers=%d" % [p.yards.size(), n_garden])

static func _fence(p: BourgPlan, q: Vector2, rot: float) -> void:
	p.mk.add("Prop_WoodenFence_Single", Transform3D(Basis(Vector3.UP, rot), Vector3(q.x, Terrain.height_at(q.x, q.y) - 0.02, q.y)), {"MI_WoodTrim": Bourg.WOOD[1]})

static func _v3(q: Vector2, dy := 0.0) -> Vector3:
	return Vector3(q.x, Terrain.height_at(q.x, q.y) + dy, q.y)

# ---------------------------------------------------------------- intérieurs

static func interiors(p: BourgPlan, root: Node3D, props: Node3D) -> void:
	for sp in p.visits:
		var nm: String = sp["name"]
		var base: Transform3D = sp["base"]
		var inn := Node3D.new()
		inn.name = "Interieur_" + nm
		root.add_child(inn)
		furn = props
		match nm:
			"taverne": _taverne(p, inn, base, sp)
			"apothicaire": _apothicaire(p, inn, base, sp)
			_: _maison(p, inn, base, sp)

## Objet du kit donjon posé dans le repère de la maison
static func _d(root: Node3D, name: String, base: Transform3D, local: Vector3, rot := 0.0, scl := 1.0) -> Node3D:
	var n := Kit.dungeon(furn, name, base * local, base.basis.get_euler().y + rot, scl)
	return n

static func _light(root: Node3D, base: Transform3D, local: Vector3, col: Color, energy: float, rng_m: float) -> OmniLight3D:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng_m
	l.shadow_enabled = false
	l.visible = false   # allumée quand le joueur entre (zone de visite)
	root.add_child(l)
	l.global_position = base * local
	l.add_to_group("lumiere_interieur")
	return l

static func _fire(root: Node3D, pos: Vector3) -> void:
	var fire := FX.particles("fire_01", 12, 0.7, [Color(1, 0.85, 0.45, 0.9), Color(1, 0.35, 0.1, 0)], 0.45, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.3
	fire.initial_velocity_max = 0.8
	fire.gravity = Vector3.ZERO
	fire.visibility_range_end = 40.0
	root.add_child(fire)
	fire.global_position = pos
	fire.emitting = true

## La taverne du Sanglier Doré (12 x 8 m) : comptoir, tonneaux, cheminée, tables, escalier, lustre
const S := 0.78   # le mobilier du kit donjon est surdimensionné pour des personnages de 1,8 m
static func _taverne(p: BourgPlan, root: Node3D, base: Transform3D, sp: Dictionary) -> void:
	var rot := base.basis.get_euler().y
	var g := p.geo
	var b := base.basis
	# comptoir le long du mur droit
	g.obox("bois_sombre", Transform3D(b, base * Vector3(4.3, 0.55, 0.4)), Vector3(0.7, 1.1, 4.2), true)
	g.obox("bois", Transform3D(b, base * Vector3(4.25, 1.13, 0.4)), Vector3(0.95, 0.08, 4.4), false)
	for k in 4:
		_d(root, "Stool_round", base, Vector3(3.55, 0, -1.2 + k * 1.1), 0.0, S)
	_d(root, "Mug", base, Vector3(4.2, 1.17, -0.8), 0.3)
	_d(root, "Mug", base, Vector3(4.3, 1.17, 1.4), 1.2)
	_d(root, "Bottle", base, Vector3(4.2, 1.17, 0.4), 0.0)
	_d(root, "Jug", base, Vector3(4.35, 1.17, 2.0), 0.0)
	# derrière le comptoir : tonneaux en perce, étagère à bouteilles
	_d(root, "Barrel_Big", base, Vector3(5.2, 0, -3.0), PI / 2.0, 0.7)
	_d(root, "Barrel_Big", base, Vector3(5.2, 0, 2.9), PI / 2.0, 0.7)
	_d(root, "Shelf_Wall", base, Vector3(5.75, 1.4, 0.4), -PI / 2.0)
	for k in 5:
		_d(root, ["Bottle", "Jar_Full", "Bottle", "Wineglass", "Bottle"][k], base, Vector3(5.6, 1.62, -0.6 + k * 0.5), 0.0)
	# cheminée sur le mur gauche, tapis devant
	Kit.place(furn, "res://assets/village2/mdvl_village_hearth_01.glb", base * Vector3(-5.5, 0.0, -0.4), rot + PI / 2.0, 1.15)
	_fire(root, base * Vector3(-5.35, 0.35, -0.4))
	_d(root, "Carpet_Red", base, Vector3(-3.6, 0.02, -0.4), PI / 2.0, 1.2)
	_d(root, "Chair", base, Vector3(-3.8, 0, -1.6), PI * 0.8, S)
	_d(root, "Chair", base, Vector3(-3.8, 0, 0.9), PI * 0.2, S)
	# tables et bancs
	for t in [Vector3(-1.0, 0, -2.2), Vector3(-1.0, 0, 1.5), Vector3(1.6, 0, -0.4)]:
		_d(root, "Table_Big", base, t, PI / 2.0, S)
		_d(root, "Bench", base, t + Vector3(-0.85, 0, 0), PI / 2.0, S)
		_d(root, "Bench", base, t + Vector3(0.85, 0, 0), -PI / 2.0, S)
		_d(root, "Mug", base, t + Vector3(0.1, 0.82 * S, -0.3), 0.4)
		_d(root, "Plate", base, t + Vector3(-0.1, 0.82 * S, 0.35), 0.0)
		_d(root, "Candlestick_Small", base, t + Vector3(0.0, 0.82 * S, 0.0), 0.0)
	_d(root, "Bread", base, Vector3(-0.9, 0.82 * S, -1.8), 0.6)
	_d(root, "Meat", base, Vector3(1.7, 0.82 * S, 0.0), 0.2)
	# escalier vers l'étage contre le mur du fond
	p.mk.add("Stair_Interior_Rails", base * Transform3D(Basis(Vector3.UP, PI / 2.0), Vector3(3.4, 0.0, -3.15)), sp["tint"])
	# décor mural : bannière, bouclier, porte-manteaux, trophées
	_d(root, "Banner", base, Vector3(-2.0, 1.4, -3.75), 0.0, 1.1)
	_d(root, "Shield", base, Vector3(-5.75, 1.7, 2.2), PI / 2.0)
	_d(root, "CoatHook_Full", base, Vector3(-2.6, 1.6, 3.75), PI)
	_d(root, "Candlestick_Wall", base, Vector3(0.5, 1.9, -3.75), 0.0)
	_d(root, "Candlestick_Wall", base, Vector3(0.5, 1.9, 3.75), PI)
	_d(root, "Chandelier", base, Vector3(0.3, 2.75, -0.3), 0.0, 0.6)
	_d(root, "Barrel_Closed", base, Vector3(-5.2, 0, 3.2), 0.4)
	_d(root, "Barrel_Closed", base, Vector3(-4.4, 0, 3.4), 1.1)
	_d(root, "Bag", base, Vector3(-5.3, 0, -3.3), 0.7)
	_light(root, base, Vector3(-4.6, 1.6, -0.4), Color(1.0, 0.62, 0.3), 2.2, 7.5)
	_light(root, base, Vector3(1.5, 2.3, 0.0), Color(1.0, 0.78, 0.5), 1.4, 9.0)
	# enseigne au-dessus de la porte
	var dp: Vector3 = sp["door"]
	var face: Vector2 = sp["face"]
	var xl := Vector2(face.y, -face.x)
	Kit.place(furn, "res://assets/village2/mdvl_village_sign_inn_01.glb", Vector3(dp.x + xl.x * 1.6 + face.x * 0.45, dp.y + 2.75, dp.z + xl.y * 1.6 + face.y * 0.45), rot + PI / 2.0, 1.2)
	# terrasse : deux tables dehors
	for k in 2:
		var t: Vector3 = base * Vector3(-4.0 + k * 7.6, 0, 6.2)
		var ty := Terrain.height_at(t.x, t.z) + 0.1
		Kit.dungeon(furn, "Table_Small", Vector3(t.x, ty, t.z), rot, 0.75)
		Kit.dungeon(furn, "Stool_round", Vector3(t.x, ty, t.z) + b * Vector3(0.8, 0, 0), 0.0, 1.0)
		Kit.dungeon(furn, "Stool_round", Vector3(t.x, ty, t.z) + b * Vector3(-0.8, 0, 0), 0.0, 1.0)
		Kit.dungeon(furn, "Mug", Vector3(t.x, ty + 0.62, t.z), 0.0, 1.0)
	# clients et tavernier
	patrons.append([base * Vector3(5.1, 0.0, 0.4), "Idle_Talking", false, rot - PI / 2.0, {"id": "tavernier", "nom": "Gaspard le tavernier", "role": "habitant"}])
	patrons.append([base * Vector3(-1.85, 0.0, -2.2), "Sitting_Talking", false, rot + PI / 2.0])
	patrons.append([base * Vector3(-0.15, 0.0, -2.2), "Sitting_Idle", true, rot - PI / 2.0])
	patrons.append([base * Vector3(-1.85, 0.0, 1.5), "Sitting_Talking", true, rot + PI / 2.0])
	patrons.append([base * Vector3(2.45, 0.0, -0.4), "Sitting_Talking", false, rot - PI / 2.0])
	patrons.append([base * Vector3(-3.8, 0.05, 0.9), "Sitting_Idle", false, rot + PI * 0.2 + PI])

## Échoppe de l'apothicaire : étagères de fioles, chaudron, bureau, boule de cristal
static func _apothicaire(p: BourgPlan, root: Node3D, base: Transform3D, sp: Dictionary) -> void:
	var b := base.basis
	p.geo.obox("bois_sombre", Transform3D(b, base * Vector3(0.0, 0.5, 0.6)), Vector3(3.4, 1.0, 0.6), true)
	p.geo.obox("bois", Transform3D(b, base * Vector3(0.0, 1.03, 0.6)), Vector3(3.6, 0.07, 0.8), false)
	for k in 5:
		_d(root, ["Potion_Red", "Potion_Blue", "Potion_Green", "Flask", "Beaker_Full_Var1"][k], base, Vector3(-1.4 + k * 0.7, 1.07, 0.6), k * 0.7)
	_d(root, "Scales", base, Vector3(1.2, 1.07, 0.5), 0.0)
	for s in [-1.0, 1.0]:
		_d(root, "Shelf", base, Vector3(s * 2.55, 0, -1.6), s * -PI / 2.0)
		for k in 4:
			_d(root, ["Jar_Full", "Potion_Green", "Jar_Big", "Book_Big_Red"][k], base, Vector3(s * 2.5, 1.0 + (k % 2) * 0.62, -2.2 + k * 0.4), 0.0)
	_d(root, "Cauldron_Small_Stand", base, Vector3(1.6, 0, -3.0), 0.0)
	_d(root, "Desk", base, Vector3(-1.2, 0, -3.0), PI)
	_d(root, "Book_Open", base, Vector3(-1.2, 0.82, -3.0), 0.0)
	_d(root, "Inkwell", base, Vector3(-0.7, 0.82, -3.0), 0.0)
	_d(root, "CrystalBall_Stand", base, Vector3(0.4, 0, -2.0), 0.0)
	_d(root, "Carpet_Green", base, Vector3(0, 0.02, 2.0), 0.0, 0.9)
	_d(root, "Chandelier", base, Vector3(0, 2.8, -0.8), 0.0, 0.5)
	_light(root, base, Vector3(0, 2.2, -0.5), Color(0.75, 1.0, 0.75), 1.5, 6.5)
	patrons.append([base * Vector3(0.0, 0.0, -0.4), "Idle", true, base.basis.get_euler().y, {"id": "apothicaire", "nom": "Ysolde l'apothicaire", "role": "habitant"}])

## Maison de Mathis : lit, coffre (quête), table, cheminée, étagère de livres
static func _maison(p: BourgPlan, root: Node3D, base: Transform3D, sp: Dictionary) -> void:
	var b := base.basis
	var rot := b.get_euler().y
	# lit (cadre de bois, couverture, oreiller)
	p.geo.obox("bois_sombre", Transform3D(b, base * Vector3(-1.9, 0.25, -2.6)), Vector3(1.5, 0.5, 2.3), true)
	p.geo.obox("tissu_rouge", Transform3D(b, base * Vector3(-1.9, 0.56, -2.4)), Vector3(1.45, 0.14, 1.8), false)
	p.geo.obox("tissu_blanc", Transform3D(b, base * Vector3(-1.9, 0.6, -3.45)), Vector3(1.2, 0.18, 0.45), false)
	p.geo.obox("bois_sombre", Transform3D(b, base * Vector3(-1.9, 0.6, -3.72)), Vector3(1.5, 1.2, 0.1), false)
	var chest := _d(root, "Chest", base, Vector3(-1.9, 0, -0.9), 0.0)
	chest.name = "CoffreMathis"
	_d(root, "Table_Small", base, Vector3(1.4, 0, 0.2), 0.0)
	_d(root, "Chair", base, Vector3(1.4, 0, 1.0), PI)
	_d(root, "Bowl_Full", base, Vector3(1.4, 0.62, 0.1), 0.0)
	_d(root, "Candlestick", base, Vector3(1.7, 0.62, -0.1), 0.0)
	Kit.place(furn, "res://assets/village2/mdvl_village_hearth_01.glb", base * Vector3(2.5, 0.0, -2.4), rot - PI / 2.0, 1.0)
	_fire(root, base * Vector3(2.35, 0.3, -2.4))
	_d(root, "Shelf_Wall", base, Vector3(-2.75, 1.5, 1.4), PI / 2.0)
	for k in 3:
		_d(root, ["Book_Brown", "Book_Green", "Scroll_Stack"][k], base, Vector3(-2.65, 1.72, 1.0 + k * 0.35), PI / 2.0)
	_d(root, "Carpet_Green", base, Vector3(0.2, 0.02, -1.2), 0.0, 0.8)
	_d(root, "CoatHook_Full", base, Vector3(1.2, 1.6, 3.75), PI)
	_light(root, base, Vector3(1.6, 1.4, -2.0), Color(1.0, 0.6, 0.3), 1.6, 6.0)
	patrons.append([base * Vector3(1.4, 0.05, 1.0), "Sitting_Idle", false, rot + PI, {"id": "mathis", "nom": "Le vieux Mathis", "role": "habitant"}])

# ---------------------------------------------------------------- zone de visite

## En entrant : étages et toit masqués (on voit l'intérieur d'en haut), caméra rapprochée, lumières allumées
static func visit_zone(p: BourgPlan, root: Node3D, nm: String, up: Node3D) -> void:
	var sp: Dictionary = p.specials[nm]
	var base: Transform3D = sp["base"]
	var z := Area3D.new()
	z.name = "Visite_" + nm
	z.collision_layer = 0
	z.collision_mask = 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(int(sp["w"]) * Bourg.M - 0.5, 2.6, int(sp["d"]) * Bourg.M - 0.5)
	cs.shape = bs
	z.add_child(cs)
	z.set_script(load("res://scripts/world/bourg/visit_zone.gd"))
	z.set("upper", up)
	z.set("lights", root.get_node("Interieur_" + nm).find_children("*", "OmniLight3D", true, false))
	root.add_child(z)
	z.global_transform = Transform3D(base.basis, base * Vector3(0, 1.3, 0))
