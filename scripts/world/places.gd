class_name Places
## Lieux du royaume : ferme et moulin, camp de bûcherons, mine et gisements, ponton du lac,
## falaises du plateau, et le PORTAIL vers le royaume des nains (scellé pour l'instant).

static var portal_mat: ShaderMaterial

static func build(world: Node3D) -> void:
	var parent = Node3D.new()
	parent.name = "LieuxDecor"
	world.add_child(parent)
	var rng = RandomNumberGenerator.new()
	rng.seed = 404
	var g = Geo.new()
	_farm(g, parent, rng)
	_lumber(g, parent, rng)
	_mine(g, parent, rng)
	_pier(g, parent)
	_portal(g, parent)
	g.commit(world, "Lieux")
	_cliffs(parent, rng)
	_ores(parent, rng)

static func _ground(p: Vector2) -> float:
	return Terrain.height_at(p.x, p.y)

# ------------------------------------------------------------ FERME + MOULIN
static func _farm(g: Geo, parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.FARM
	Town.house(g, c + Vector2(-8, -10), 10.0, 7.0, 0.0, 2, "chaume", rng)
	# grange : grand volume en bois, porte charretière
	var bc = c + Vector2(10, -9)
	var y = _ground(bc) + 0.2
	g.box("pierre_base", Vector3(bc.x, y - 0.4, bc.y), Vector3(15.0, 1.2, 10.5), 0.0, true)
	g.box("bois", Vector3(bc.x, y + 3.0, bc.y), Vector3(14.0, 6.0, 10.0), 0.0, true)
	g.box("bois_sombre", Vector3(bc.x, y + 2.2, bc.y + 5.05), Vector3(4.0, 4.4, 0.12), 0.0, false)
	g.box("bois", Vector3(bc.x - 1.0, y + 2.2, bc.y + 5.1), Vector3(0.2, 4.4, 0.08), 0.6, false)
	g.box("bois", Vector3(bc.x + 1.0, y + 2.2, bc.y + 5.1), Vector3(0.2, 4.4, 0.08), -0.6, false)
	g.gable_roof("tuile", Vector3(bc.x, y + 6.0, bc.y), 7.6, 5.8, 4.2, 0.0, "bois")
	# moulin à vent : tour de pierre conique + ailes animées
	var mc = c + Vector2(4, 14)
	var my = _ground(mc)
	g.cylinder("pierre", Vector3(mc.x, 0, mc.y), 3.4, my - 0.5, my + 9.0, 14, true, false)
	g.cylinder("pierre_claire", Vector3(mc.x, 0, mc.y), 3.6, my + 8.6, my + 9.2, 14, false, false)
	g.cone("chaume", Vector3(mc.x, 0, mc.y), 3.9, my + 9.0, 4.5, 14)
	g.box("bois_sombre", Vector3(mc.x, my + 1.1, mc.y + 3.35), Vector3(1.3, 2.2, 0.2), 0.0, false)
	var sails = Node3D.new()
	sails.name = "AilesMoulin"
	sails.position = Vector3(mc.x, my + 9.5, mc.y + 3.9)
	parent.add_child(sails)
	var sg = Geo.new()
	for k in 4:
		var a = TAU * k / 4.0
		var b = Basis(Vector3.BACK, a)
		sg.obox("bois_sombre", Transform3D(b, b * Vector3(0, 4.6, 0)), Vector3(0.25, 9.2, 0.2), false)
		sg.obox("tissu_blanc", Transform3D(b, b * Vector3(0.75, 5.3, 0.05)), Vector3(1.3, 6.4, 0.04), false)
	sg.box("bois_sombre", Vector3.ZERO, Vector3(0.6, 0.6, 0.8), 0.0, false)
	sg.commit(sails, "Ailes", 2)
	var spin = Spinner.new()
	sails.add_child(spin)
	# foin, charrette
	Kit.village(parent, "Prop_Cart_1_Hay", Vector3(c.x + 2, _ground(c + Vector2(2, 0)), c.y), 0.4, 1.3)
	for i in 4:
		var p = c + Vector2(-2 + i * 1.6, -2 + (i % 2) * 1.5)
		Kit.village(parent, "Prop_Hay_1", Vector3(p.x, _ground(p), p.y), rng.randf() * TAU, 1.4)
	Kit.village(parent, "Prop_Well_Grass", Vector3(c.x - 10, _ground(c + Vector2(-10, 5)), c.y + 5), 0.0, 1.4)

# ------------------------------------------------------------ CAMP DE BÛCHERONS
static func _lumber(g: Geo, parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.LUMBER
	Town.house(g, c + Vector2(-6, -6), 7.0, 5.5, 0.8, 1, "chaume", rng, "bois")
	# piles de rondins
	for k in 3:
		var p = c + Vector2(4 + k * 3.2, 3)
		Kit.nature(parent, "log", Vector3(p.x, _ground(p), p.y), 0.1 * k + PI / 2.0, 1.4)
		Kit.nature(parent, "log", Vector3(p.x, _ground(p) + 0.9, p.y), 0.1 * k + PI / 2.0, 1.3)
	Kit.dungeon(parent, "FirewoodStack", Vector3(c.x - 1, _ground(c), c.y + 5), 0.3, 1.8)
	for k in 6:
		var a = rng.randf() * TAU
		var p = c + Vector2(cos(a), sin(a)) * rng.randf_range(8, 15)
		Kit.nature(parent, "stump", Vector3(p.x, _ground(p) - 0.1, p.y), rng.randf() * TAU, 1.1)
	# chevalet de sciage
	var sp = c + Vector2(2, -3)
	var y = _ground(sp)
	for dx in [-0.7, 0.7]:
		g.box("bois_sombre", Vector3(sp.x + dx, y + 0.45, sp.y), Vector3(0.12, 0.9, 1.0), 0.0, false)
	g.box("bois", Vector3(sp.x, y + 0.95, sp.y), Vector3(2.6, 0.32, 0.32), 0.0, false)
	# bûcherons à l'ouvrage (face à un arbre de la lisière)
	for i in 2:
		var v = Villager.new()
		v.spec = {"outfit": "paysan_h", "beard": i == 0, "hair": "Hair_Buzzed", "tint": Color(0.85, 0.75, 0.65)}
		v.anim_name = "b/TreeChopping"
		var p = c + Vector2(-12 - i * 5, 6 + i * 4)
		v.position = Vector3(p.x, _ground(p), p.y)
		v.rotation.y = -PI / 2.0
		parent.add_child(v)
		Kit.nature(parent, "oak", Vector3(p.x - 1.6, _ground(p) - 0.1, p.y), rng.randf() * TAU, 1.9)

# ------------------------------------------------------------ MINE
static func _mine(g: Geo, parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.MINE
	var face = atan2(-0.6, 0.8)   # entrée tournée vers le sud-ouest (vers la route)
	var b = Basis(Vector3.UP, face)
	var y = _ground(c)
	# paroi rocheuse : falaises Avramania en arc autour de l'entrée
	for k in range(-2, 3):
		var off = b * Vector3(k * 7.4, 0, -2.0 - absf(k) * 1.6)
		Kit.nature(parent, "cliff_0%d" % (absi(k) % 3 + 1), Vector3(c.x + off.x - (b * Vector3(3.7, 0, 0)).x, y - 0.6, c.y + off.z - (b * Vector3(3.7, 0, 0)).z), face, 2.6)
	Kit.nature(parent, "cave_01", Vector3(c.x - (b * Vector3(5.2, 0, 0)).x, y - 0.3, c.y - (b * Vector3(5.2, 0, 0)).z), face, 2.6)
	# boisage de l'entrée
	for s in [-1.0, 1.0]:
		var q: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(s * 2.6, 0, 1.2)
		g.box("bois_sombre", Vector3(q.x, y + 2.0, q.z), Vector3(0.45, 4.0, 0.45), face, true)
	var ql: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(0, 0, 1.2)
	g.box("bois_sombre", Vector3(ql.x, y + 4.1, ql.z), Vector3(6.2, 0.5, 0.55), face, false)
	g.box("fenetre_sombre", Vector3(ql.x, y + 2.0, ql.z) + b * Vector3(0, 0, -0.6), Vector3(4.6, 4.0, 0.2), face, false)
	# rails qui sortent de la mine
	for k in 9:
		var q: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(0, 0, 2.0 + k * 1.2)
		g.box("bois", Vector3(q.x, _ground(Vector2(q.x, q.z)) + 0.08, q.z), Vector3(2.2, 0.14, 0.3), face, false)
	for s in [-0.6, 0.6]:
		var a3: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(s, 0, 1.6)
		var b3: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(s, 0, 12.0)
		a3.y = _ground(Vector2(a3.x, a3.z)) + 0.2
		b3.y = _ground(Vector2(b3.x, b3.z)) + 0.2
		var seg = b3 - a3
		g.obox("fer", Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP), (a3 + b3) * 0.5), Vector3(0.1, 0.1, seg.length()), false)
	var cart: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(0, 0, 7.0)
	Kit.village(parent, "Prop_Cart_1", Vector3(cart.x, _ground(Vector2(cart.x, cart.z)), cart.z), face, 1.1)
	Kit.dungeon(parent, "Torch", Vector3(ql.x, y + 3.0, ql.z) + b * Vector3(2.0, 0, 0.4), 0.0, 1.5)
	# mineur
	var v = Villager.new()
	v.spec = {"outfit": "paysan_h", "beard": true, "hair": "Hair_Buzzed", "tint": Color(0.7, 0.7, 0.75)}
	v.anim_name = "b/Melee_Hook"
	var mp: Vector3 = Vector3(c.x, 0, c.y) + b * Vector3(4.5, 0, 3.5)
	v.position = Vector3(mp.x, _ground(Vector2(mp.x, mp.z)), mp.z)
	v.rotation.y = face + PI / 2.0
	parent.add_child(v)

## Gisements de minerai : grappes de cristaux / pépites sur des rochers (fer, cuivre, or, cristal)
static func _ores(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var g = Geo.new()
	var spots = []
	for i in 14:
		var a = rng.randf() * TAU
		spots.append(Layout.MINE + Vector2(cos(a), sin(a)) * rng.randf_range(10, 30))
	for i in 10:
		spots.append(Vector2(rng.randf_range(120, 240), rng.randf_range(-250, -120)))
	for i in 5:
		spots.append(Vector2(rng.randf_range(-250, -150), rng.randf_range(-260, -200)))
	var kinds = ["fer_rouille", "fer_rouille", "cuivre", "or", "cristal"]
	for p in spots:
		if Layout.reserved(p, 0.0) and p.distance_to(Layout.MINE) < 9.0:
			continue
		var y = Terrain.height_at(p.x, p.y)
		var m: String = kinds[rng.randi() % kinds.size()]
		Kit.nature(parent, "boulder", Vector3(p.x, y - 0.3, p.y), rng.randf() * TAU, rng.randf_range(1.4, 2.0))
		for k in rng.randi_range(4, 7):
			var o = Vector3(rng.randf_range(-0.9, 0.9), 0, rng.randf_range(-0.9, 0.9))
			var h = rng.randf_range(0.5, 1.2)
			var tilt = Basis(Vector3(o.z, 0, -o.x).normalized() if o.length() > 0.01 else Vector3.RIGHT, rng.randf_range(0.2, 0.6))
			_crystal(g, m, Transform3D(tilt, Vector3(p.x, y + 0.5, p.y) + o), 0.16 + h * 0.08, h)
	g.commit(parent, "Gisements", 2, false)

static func _crystal(g: Geo, m: String, xf: Transform3D, r: float, h: float) -> void:
	var n = 6
	for i in n:
		var a0 = TAU * i / n
		var a1 = TAU * (i + 1) / n
		var p0 = xf * Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 = xf * Vector3(cos(a1) * r, 0, sin(a1) * r)
		var q0 = xf * Vector3(cos(a0) * r, h, sin(a0) * r)
		var q1 = xf * Vector3(cos(a1) * r, h, sin(a1) * r)
		var tip = xf * Vector3(0, h + r * 1.8, 0)
		g.quad(m, p0, p1, q1, q0)
		g._tri(m, q0, q1, tip)

# ------------------------------------------------------------ PONTON DU LAC
static func _pier(g: Geo, parent: Node3D) -> void:
	var start = Vector2(140, 158)
	var dir = (Layout.LAKE - start).normalized()
	var yaw = atan2(dir.x, dir.y)
	var len = 18.0
	var y = maxf(Terrain.height_at(start.x, start.y), 0.6) + 0.2
	var mid = start + dir * len * 0.5
	g.box("bois", Vector3(mid.x, y, mid.y), Vector3(3.0, 0.3, len), yaw, true)
	for k in 7:
		var p = start + dir * (2.0 + k * 2.6)
		for s in [-1.0, 1.0]:
			var q = p + Vector2(dir.y, -dir.x) * s * 1.3
			g.box("bois_sombre", Vector3(q.x, y - 1.2, q.y), Vector3(0.25, 3.0, 0.25), yaw, false)
	var bp = start + dir * len + Vector2(dir.y, -dir.x) * 3.0
	Kit.village(parent, "Prop_Boat_1", Vector3(bp.x, -0.15, bp.y), yaw, 1.4)
	var bp2 = start + dir * (len - 6) - Vector2(dir.y, -dir.x) * 3.2
	Kit.village(parent, "Prop_Boat_2", Vector3(bp2.x, -0.15, bp2.y), yaw + 0.3, 1.4)

# ------------------------------------------------------------ PORTAIL
static func _portal(g: Geo, parent: Node3D) -> void:
	var c: Vector2 = Layout.PORTAL
	var y := Layout.PORTAL_H
	# esplanade dallée posée à plat sur le sol aplani (aucune marche : on y entre de plain-pied)
	for disc_def in [[11.5, 0.08, "pierre_base"], [6.5, 0.14, "pierre_claire"]]:
		var dm := CylinderMesh.new()
		dm.top_radius = disc_def[0]
		dm.bottom_radius = disc_def[0] + 0.1
		dm.height = 0.7
		dm.radial_segments = 40
		dm.rings = 1
		var di := MeshInstance3D.new()
		di.mesh = dm
		var dmat := (Geo.mat("dallage") as StandardMaterial3D).duplicate() as StandardMaterial3D
		dmat.uv1_triplanar = true
		dmat.uv1_scale = Vector3.ONE * 0.4
		di.material_override = dmat
		di.position = Vector3(c.x, y + float(disc_def[1]) - 0.35, c.y)
		parent.add_child(di)
	# arche : deux piliers massifs et un arc de voussoirs (plan vertical, face à la route)
	var R := 4.4
	var cy := y + 3.4
	for s in [-1.0, 1.0]:
		g.box("pierre_claire", Vector3(c.x + s * (R + 0.4), y + 1.7, c.y), Vector3(1.6, 3.4, 1.8), 0.0, true)
		g.box("pierre_base", Vector3(c.x + s * (R + 0.4), y + 0.25, c.y), Vector3(2.1, 0.5, 2.3), 0.0, false)
		g.box("pierre_base", Vector3(c.x + s * (R + 0.4), y + 3.5, c.y), Vector3(1.9, 0.3, 2.0), 0.0, false)
	var n := 13
	for i in n + 1:
		var a := PI * i / n
		var p := Vector3(c.x + cos(a) * (R + 0.4), cy + sin(a) * (R + 0.4), c.y)
		var bas := Basis(Vector3.BACK, a + PI / 2.0)
		g.obox("pierre_claire", Transform3D(bas, p), Vector3(1.25, 1.6, 1.7), false)
		if i % 2 == 0:
			g.obox("rune", Transform3D(bas, p + Vector3(0, 0, 0.86)), Vector3(0.5, 0.6, 0.04), false)
	# clé de voûte
	g.box("pierre_base", Vector3(c.x, cy + R + 1.2, c.y), Vector3(1.4, 1.2, 2.0), 0.0, false)
	# pierres levées, bien droites, en cercle sur le bord de l'esplanade
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var q := Vector2(c.x + cos(a) * 10.0, c.y + sin(a) * 10.0)
		if absf(q.y - c.y + 10.0) < 4.0 and absf(q.x - c.x) < 5.0:
			continue   # le passage vers la route reste dégagé
		g.box("pierre_base", Vector3(q.x, y + 1.7, q.y), Vector3(1.1, 3.4, 0.8), -a, true)
		g.box("rune", Vector3(q.x, y + 2.3, q.y) + Vector3(cos(a), 0, sin(a)) * -0.41, Vector3(0.3, 0.9, 0.05), -a + PI / 2.0, false)
	# voile du portail (shader animé) : disque plat inscrit dans l'arche
	var veil := MeshInstance3D.new()
	var disc := CylinderMesh.new()
	disc.top_radius = R - 0.35
	disc.bottom_radius = R - 0.35
	disc.height = 0.08
	disc.radial_segments = 40
	veil.mesh = disc
	veil.rotation_degrees = Vector3(90, 0, 0)
	veil.position = Vector3(c.x, cy, c.y)
	veil.scale = Vector3(1.0, 1.0, (cy - y - 0.15) / (R - 0.35))
	portal_mat = ShaderMaterial.new()
	portal_mat.shader = load("res://shaders/portal.gdshader")
	veil.material_override = portal_mat
	veil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(veil)
	var light := OmniLight3D.new()
	light.position = Vector3(c.x, cy, c.y - 2.5)
	light.light_color = Color(0.45, 0.6, 1.0)
	light.light_energy = 1.4
	light.omni_range = 14.0
	parent.add_child(light)
	# franchir le voile : message (le portail est scellé)
	var zone := Area3D.new()
	zone.collision_mask = 1 << 1 | 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(R * 1.6, 3.0, 1.2)
	cs.shape = bs
	zone.add_child(cs)
	zone.position = Vector3(c.x, y + 1.5, c.y)
	parent.add_child(zone)
	zone.body_entered.connect(func(b):
		if b == Combat.player:
			var w := parent.get_tree().current_scene
			if w.get("hud"):
				w.hud.hint("Le voile résiste : le portail des nains est scellé. Il faudra gagner leur confiance.", "", 4.0))
	# panneau
	var sign := Label3D.new()
	sign.text = "Royaume des Nains\nPortail scellé"
	sign.font_size = 64
	sign.outline_size = 12
	sign.modulate = Color(1.0, 0.95, 0.8)
	sign.position = Vector3(c.x + 7.0, y + 2.6, c.y - 12.5)
	sign.billboard = BaseMaterial3D.BILLBOARD_FIXED_Y
	sign.pixel_size = 0.008
	parent.add_child(sign)
	g.box("bois_sombre", Vector3(c.x + 7.0, y + 1.0, c.y - 12.5), Vector3(0.2, 2.0, 0.2), 0.0, true)

# ------------------------------------------------------------ FALAISES DU PLATEAU
static func _cliffs(parent: Node3D, rng: RandomNumberGenerator) -> void:
	var c = Layout.CASTLE
	var hx = Layout.CASTLE_HALF.x + 20.0
	var hz = Layout.CASTLE_HALF.y + 20.0
	var sides = [
		[Vector2(-hx, -hz), Vector2(hx, -hz), 0.0],          # nord
		[Vector2(hx, -hz), Vector2(hx, hz - 10), PI / 2.0],   # est
		[Vector2(-hx, hz - 10), Vector2(-hx, -hz), -PI / 2.0],# ouest
	]
	for s in sides:
		var a: Vector2 = c + s[0]
		var b: Vector2 = c + s[1]
		var len = a.distance_to(b)
		var n = int(len / 9.5)
		for k in n:
			var p = a.lerp(b, (k + 0.5) / n) + Vector2(rng.randf_range(-1.5, 1.5), rng.randf_range(-1.5, 1.5))
			var y = Terrain.height_at(p.x, p.y)
			var rot: float = s[2] + PI + rng.randf_range(-0.12, 0.12)
			Kit.nature(parent, "cliff_0%d" % (rng.randi() % 3 + 1), Vector3(p.x, y - 2.8, p.y), rot, rng.randf_range(2.4, 2.8))
