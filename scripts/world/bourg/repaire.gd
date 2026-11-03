class_name Repaire
## Grands repaires de bandits : palissade élargie, deux tours de guet à l'entrée, une grande salle commune
## visitable (tables, trône du chef, coffres, tapis, râteliers, bannières, cheminée), des cabanes autour
## de la cour, coffres de butin, tapis, tonneaux. Les bâtiments sont en périphérie : la cour centrale
## reste libre pour les combats (les bandits errent dans le rayon du repaire).

const BIG := ["camp_bandits", "brigands_est", "lanceurs_sud"]
const NOMS := {"camp_bandits": "Salle des Coupe-Bourses", "brigands_est": "Fort des Brigands", "lanceurs_sud": "Antre des Lanceurs"}

## Rayon supplémentaire réservé autour d'un repaire (pas d'arbres sur les bâtiments)
static func extent(id: String) -> float:
	return 19.0 if BIG.has(id) else 6.0

static func build(world: Node3D, decor: Node3D, c: Vector2, r: float, id: String) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(id.hash()) + 7
	var mk := MK.new()
	mk.det = MK.new()
	var up := MK.new()
	var geo := Geo.new()
	var b := Bourg.new()
	b.mk = mk
	b.geo = geo
	b.lit_ratio = 0.35
	var e := (Layout.TOWN - c).normalized()   # l'entrée regarde vers le bourg
	var dark := {"plaster": Color(0.62, 0.57, 0.5), "wood": Color(0.42, 0.36, 0.34), "slate": true, "tiles": Color(0.4, 0.42, 0.4)}
	# --- la grande salle, au fond de la cour, porte vers le feu de camp ---
	var hc := c - e * (r + 4.6)
	var hall := {"pos": hc, "rot": atan2(e.x, e.y), "w": 6, "d": 4, "floors": 1, "roof": "long", "ground": "pierre", "visit": true, "door_k": 2, "chimney": true, "quoins": true, "seed": rng.randi(), "lit": 0.6, "jetty": false}
	hall.merge(dark)
	b.mk_up = up
	var res := b.build_house(hall)
	b.mk_up = null
	hall.merge(res, true)
	# --- cabanes autour de la cour ---
	var shacks: Array = []
	for a in [-1.25, 1.25, -2.15, 2.15]:
		var dir := (-e).rotated(a)
		var w := 2 + (rng.randi() % 2)
		var sc := c + dir * (r + 3.2 + 3.0)
		var sp := {"pos": sc, "rot": atan2(-dir.x, -dir.y), "w": w, "d": 3, "floors": 1, "roof": "pignon" if w <= 3 else "long", "ground": "pierre" if rng.randf() < 0.5 else "enduit", "seed": rng.randi(), "lit": 0.25, "chimney": rng.randf() < 0.5}
		sp.merge(dark)
		sp["plaster"] = (dark["plaster"] as Color) * rng.randf_range(0.85, 1.05)
		if Bourg.roof_ok(w, 3, sp["roof"]):
			shacks.append(b.build_house(sp).merged(sp))
	# --- tours de guet de part et d'autre de l'entrée ---
	var R := r + 13.0
	for s in [-1.0, 1.0]:
		var tp := c + e.rotated(s * 0.42) * (R - 1.6)
		_tower(mk, geo, decor, tp, atan2(-e.x, -e.y))
	# --- coffres, tapis, butin, râteliers, cage ---
	var hd: Vector3 = hall["door"]
	var hface: Vector2 = hall["face"]
	var dq := Vector2(hd.x, hd.z)
	_kit(decor, "Carpet_Red", dq + hface * 1.8, atan2(hface.x, hface.y) + PI / 2.0, 1.3, 0.04)
	_kit(decor, "Chest", dq + hface * 1.2 + Vector2(hface.y, -hface.x) * 2.2, atan2(hface.x, hface.y), 1.0)
	_kit(decor, "WeaponRack_Big", dq + hface * 0.6 - Vector2(hface.y, -hface.x) * 3.0, atan2(hface.x, hface.y), 0.9)
	_kit(decor, "Banner", dq + hface * 0.25 + Vector2(hface.y, -hface.x) * 1.6 + Vector2(0, 0), atan2(hface.x, hface.y), 1.0, 2.0)
	for sh in shacks:
		var sd: Vector3 = sh["door"]
		var sf: Vector2 = sh["face"]
		var sq := Vector2(sd.x, sd.z)
		var side := Vector2(sf.y, -sf.x)
		_kit(decor, ["Chest", "ChestSmall", "Barrel_Closed", "Bag"][rng.randi() % 4], sq + sf * 1.0 + side * 1.6, atan2(sf.x, sf.y), 1.0)
		_kit(decor, ["Barrel_Open", "FirewoodStack", "Bag"][rng.randi() % 3], sq + sf * 0.8 - side * 1.6, rng.randf() * TAU, 1.0)
		if rng.randf() < 0.5:
			_kit(decor, "Carpet_Green", sq + sf * 1.5, atan2(sf.x, sf.y) + PI / 2.0, 0.9, 0.04)
	# table de jeu dehors (dés, chopes), tonneaux
	var tq := c + e.rotated(1.9) * (r * 0.95)
	_kit(decor, "Table_Small", tq, rng.randf() * TAU, 0.8)
	_kit(decor, "Mug", tq, 0.0, 1.0, 0.62)
	_kit(decor, "Stool_round", tq + Vector2(0.9, 0.2), 0.0, 0.8)
	_kit(decor, "Stool_round", tq - Vector2(0.9, 0.2), 0.0, 0.8)
	# --- intérieur de la salle ---
	var root := Node3D.new()
	root.name = "Repaire_" + id
	world.add_child(root)
	var inn := Node3D.new()
	inn.name = "Interieur"
	root.add_child(inn)
	_hall_interior(decor, inn, hall)
	mk.commit(root, "Batiments", 0.0)
	var upn: Node3D = up.commit(root, "Toit", 0.0)
	geo.commit(root, "Socles", 2)
	# zone de visite (toit masqué, lumières)
	var z := Area3D.new()
	z.name = "Visite"
	z.collision_layer = 0
	z.collision_mask = 8
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(11.5, 2.6, 7.5)
	cs.shape = bs
	z.add_child(cs)
	z.set_script(load("res://scripts/world/bourg/visit_zone.gd"))
	z.set("upper", upn)
	z.set("lights", inn.find_children("*", "OmniLight3D", true, false))
	root.add_child(z)
	z.global_transform = Transform3D((hall["base"] as Transform3D).basis, (hall["base"] as Transform3D) * Vector3(0, 1.3, 0))
	var l := Label3D.new()
	l.text = NOMS.get(id, "Repaire")
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 56
	l.outline_size = 12
	l.pixel_size = 0.008
	l.modulate = Color(1.0, 0.75, 0.5)
	l.visibility_range_begin = 9.0
	l.visibility_range_end = 30.0
	upn.add_child(l)   # masquée avec le toit quand on est dans la salle
	l.global_position = Vector3(dq.x, hd.y + 4.4, dq.y) + Vector3(hface.x, 0, hface.y) * 0.5

static func _kit(decor: Node3D, name: String, q: Vector2, rot: float, scl: float, dy := 0.0) -> Node3D:
	return Kit.dungeon(decor, name, Vector3(q.x, Terrain.height_at(q.x, q.y) + dy, q.y), rot, scl)

## Tour de guet : quatre poteaux, plate-forme, garde-corps, toit de tuiles sombres, échelle
static func _tower(mk: MK, geo: Geo, decor: Node3D, p: Vector2, rot: float) -> void:
	var y := Terrain.height_at(p.x, p.y)
	var b := Basis(Vector3.UP, rot)
	var c := Vector3(p.x, y, p.y)
	for o in [Vector2(-1.2, -1.2), Vector2(1.2, -1.2), Vector2(1.2, 1.2), Vector2(-1.2, 1.2)]:
		geo.box("bois_sombre", c + b * Vector3(o.x, 2.6, o.y), Vector3(0.28, 5.2, 0.28), rot, true)
	geo.box("bois", c + b * Vector3(0, 4.0, 0), Vector3(3.0, 0.18, 3.0), rot, true)
	for s in 4:
		var a := rot + s * PI / 2.0
		var bb := Basis(Vector3.UP, a)
		geo.box("bois_sombre", c + bb * Vector3(0, 4.6, 1.45), Vector3(3.0, 0.1, 0.1), a, false)
		geo.box("bois_sombre", c + bb * Vector3(0, 4.3, 1.45), Vector3(3.0, 0.5, 0.06), a, false)
	geo.box("bois_sombre", c + b * Vector3(0, 1.9, 1.75), Vector3(0.9, 3.8, 0.12), rot, false)
	mk.add("Roof_RoundTiles_4x4", Transform3D(b.scaled(Vector3(0.82, 0.7, 0.82)), c + Vector3(0, 5.2, 0)), {"MI_RoundTiles": Color(0.42, 0.4, 0.38), "MI_WoodTrim": Color(0.42, 0.36, 0.34)}, {"MI_RoundTiles": "MI_RoundTiles_Gray"})
	Kit.dungeon(decor, "Torch", c + b * Vector3(1.3, 4.1, 1.3), rot, 1.2)

## Salle commune : longues tables, trône du chef sur estrade, coffres, tapis, râteliers, cheminée
static func _hall_interior(decor: Node3D, inn: Node3D, hall: Dictionary) -> void:
	var base: Transform3D = hall["base"]
	var rot := base.basis.get_euler().y
	var S := 0.78
	var d := func(name: String, local: Vector3, r := 0.0, s := 1.0) -> void:
		Kit.dungeon(decor, name, base * local, rot + r, s)
	# estrade et trône au fond
	var geo_y := base * Vector3(0, 0.12, -2.9)
	var plat := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(4.2, 0.24, 1.8)
	plat.mesh = bm
	plat.material_override = Geo.mat("bois_sombre")
	decor.add_child(plat)
	plat.global_transform = Transform3D(base.basis, geo_y)
	d.call("Throne", Vector3(0, 0.24, -3.3), 0.0, 0.85)
	d.call("Carpet_Red", Vector3(0, 0.03, -0.6), PI / 2.0, 1.3)
	d.call("Banner", Vector3(-1.6, 1.5, -3.75), 0.0, 1.0)
	d.call("Banner", Vector3(1.6, 1.5, -3.75), 0.0, 1.0)
	d.call("Chest", Vector3(-2.6, 0, -3.1), 0.3)
	d.call("Chest", Vector3(2.6, 0, -3.1), -0.3)
	d.call("Skull", Vector3(-2.6, 0.75, -3.1), 0.0, 1.2)
	# deux longues tables de beuverie
	for x in [-3.2, 3.2]:
		d.call("Table_Big", Vector3(x, 0, 0.6), 0.0, S)
		d.call("Bench", Vector3(x - 0.85, 0, 0.6), PI / 2.0, S)
		d.call("Bench", Vector3(x + 0.85, 0, 0.6), -PI / 2.0, S)
		d.call("Mug", Vector3(x + 0.1, 0.64, 0.2), 0.3)
		d.call("Mug", Vector3(x - 0.15, 0.64, 1.1), 1.0)
		d.call("Meat", Vector3(x, 0.64, 0.6), 0.5)
		d.call("Candlestick_Small", Vector3(x, 0.64, -0.2))
	# butin entassé, râteliers, tonneaux
	d.call("WeaponRack_Big", Vector3(-5.6, 0, -1.6), PI / 2.0, 0.9)
	d.call("WeaponRack_Small", Vector3(5.6, 0, -1.6), -PI / 2.0, 0.9)
	d.call("Barrel_Closed", Vector3(5.2, 0, 2.9))
	d.call("Barrel_Closed", Vector3(4.4, 0, 3.2), 0.8)
	d.call("Bag", Vector3(-5.2, 0, 3.0), 0.4)
	d.call("ChestSmall", Vector3(-4.4, 0, 3.2), 0.2)
	d.call("Shield", Vector3(-5.75, 1.7, 1.2), PI / 2.0)
	d.call("Sword", Vector3(5.6, 1.2, 1.0), -PI / 2.0)
	Kit.place(decor, "res://assets/village2/mdvl_village_hearth_01.glb", base * Vector3(5.5, 0.0, 1.0), rot - PI / 2.0, 1.1)
	DecoFire.at(inn, base * Vector3(5.35, 0.3, 1.0))
	d.call("Chandelier", Vector3(0, 2.75, 0.4), 0.0, 0.6)
	var lights := [[Vector3(4.6, 1.5, 1.0), Color(1.0, 0.55, 0.25), 2.0, 7.0], [Vector3(-1.0, 2.3, 0.0), Color(1.0, 0.75, 0.45), 1.3, 9.0]]
	for li in lights:
		var l := OmniLight3D.new()
		l.light_color = li[1]
		l.light_energy = li[2]
		l.omni_range = li[3]
		l.visible = false
		inn.add_child(l)
		l.global_position = base * (li[0] as Vector3)
