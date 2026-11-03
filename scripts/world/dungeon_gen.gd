class_name DungeonGen
## Plan et construction d'un donjon (repris de Brèche Écarlate, adapté au téléphone) :
## salle de départ, quatre salles de vie reliées en grille, salle du gardien avec estrade, trône et trésor,
## crypte cachée derrière un mur fissuré. Sol en grandes dalles continues (aucun trou où tomber),
## murs fusionnés par longueurs (peu de collisions), une lumière par salle.

const CELL := 4.0
const W := 32
const H := 32
const WALL_H := 4.6

var B: Vector3
var grid := PackedByteArray()      # 0 vide, 1 salle, 2 couloir, 3 crypte, 4 passage secret
var rooms: Array = []              # {c: Vector3, cx, cz, tx, tz, type}
var crack: Dictionary = {}         # mur fissuré {pos: Vector3, rot: float}
var rng := RandomNumberGenerator.new()

func cell_pos(x: float, z: float) -> Vector3:
	return B + Vector3(x * CELL, 0, z * CELL)

func _mark(x: int, z: int, v: int) -> void:
	if x >= 0 and z >= 0 and x < W and z < H and grid[z * W + x] == 0:
		grid[z * W + x] = v

func solid(x: int, z: int) -> bool:
	return x >= 0 and z >= 0 and x < W and z < H and grid[z * W + x] > 0

func _room(cx: int, cz: int, tx: int, tz: int, type: String, v := 1) -> Dictionary:
	var x0 := cx - tx / 2
	var z0 := cz - tz / 2
	for x in range(x0, x0 + tx):
		for z in range(z0, z0 + tz):
			_mark(x, z, v)
	var r := {"cx": cx, "cz": cz, "tx": tx, "tz": tz, "x0": x0, "z0": z0, "type": type,
		"c": cell_pos(x0 + (tx - 1) * 0.5, z0 + (tz - 1) * 0.5)}
	rooms.append(r)
	return r

func _corridor(x1: int, z1: int, x2: int, z2: int, v := 2, wide := 1) -> void:
	if z1 == z2:
		for x in range(mini(x1, x2), maxi(x1, x2) + 1):
			for k in range(-wide, wide + 1):
				_mark(x, z1 + k, v)
	else:
		for z in range(mini(z1, z2), maxi(z1, z2) + 1):
			for k in range(-wide, wide + 1):
				_mark(x1 + k, z, v)

## Plan : départ (sud-ouest), 4 salles en grille, gardien au nord, crypte cachée à l'ouest
func plan(seed_v: int) -> void:
	rng.seed = seed_v
	grid.resize(W * H)
	grid.fill(0)
	rooms.clear()
	_room(3, 24, 4, 5, "depart")
	var N := [[10, 24], [18, 24], [26, 24], [10, 14], [18, 14], [26, 14]]
	var types := ["armurerie", "bibliotheque", "refectoire", "crypte", "caserne", "ossuaire"]
	for i in range(types.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = types[i]
		types[i] = types[j]
		types[j] = tmp
	for i in 6:
		_room(N[i][0], N[i][1], rng.randi_range(5, 6), rng.randi_range(5, 6), types[i])
	_room(18, 4, 9, 7, "boss")
	_corridor(3, 24, 10, 24)
	_corridor(10, 24, 18, 24)
	_corridor(18, 24, 26, 24)
	_corridor(10, 24, 10, 14)
	_corridor(26, 24, 26, 14)
	_corridor(18, 14, 26, 14)
	if rng.randf() < 0.6:
		_corridor(10, 14, 18, 14)
	else:
		_corridor(18, 24, 18, 14)
	_corridor(18, 14, 18, 4)
	# crypte cachée : passage étroit vers l'ouest depuis la salle (10,14), fermé par un mur fissuré
	var n: Dictionary = rooms[4]
	_room(2, 13, 3, 4, "cachette", 3)
	var xw: int = n["x0"]
	for x in range(4, xw):
		_mark(x, 13, 4)
	crack = {"pos": cell_pos(xw - 0.5, 13), "rot": PI / 2.0}

func room_of(type: String) -> Dictionary:
	for r in rooms:
		if r["type"] == type:
			return r
	return {}

## Construction : sols, murs, plafond absent (vue de dessus), torches
func build(root: Node3D, col: Color) -> void:
	var g := Geo.new()
	# sols : une dalle par rangée continue de cases (pas de joint possible = pas de chute)
	for z in H:
		var x := 0
		while x < W:
			if not solid(x, z):
				x += 1
				continue
			var x0 := x
			while x < W and solid(x, z):
				x += 1
			var a := cell_pos(x0 - 0.5, z - 0.5)
			var b := cell_pos(x - 0.5, z + 0.5)
			g.box("dallage", Vector3((a.x + b.x) * 0.5, B.y - 0.5, (a.z + b.z) * 0.5), Vector3(b.x - a.x + 0.02, 1.0, CELL + 0.02), 0.0, true)
	# murs : longueurs fusionnées sur chaque bord libre
	for z in H:
		for side in [-1, 1]:
			var x := 0
			while x < W:
				if not (solid(x, z) and not solid(x, z + side)):
					x += 1
					continue
				var x0 := x
				while x < W and solid(x, z) and not solid(x, z + side):
					x += 1
				var zz: float = z + side * 0.5
				var a := cell_pos(x0 - 0.5, zz)
				var b := cell_pos(x - 0.5, zz)
				g.box("pierre", Vector3((a.x + b.x) * 0.5, B.y + WALL_H * 0.5, a.z + side * 0.4), Vector3(b.x - a.x + 0.8, WALL_H, 0.8), 0.0, true)
	for x in W:
		for side in [-1, 1]:
			var z := 0
			while z < H:
				if not (solid(x, z) and not solid(x + side, z)):
					z += 1
					continue
				var z0 := z
				while z < H and solid(x, z) and not solid(x + side, z):
					z += 1
				var xx: float = x + side * 0.5
				var a := cell_pos(xx, z0 - 0.5)
				var b := cell_pos(xx, z - 0.5)
				g.box("pierre", Vector3(a.x + side * 0.4, B.y + WALL_H * 0.5, (a.z + b.z) * 0.5), Vector3(0.8, WALL_H, b.z - a.z + 0.8), 0.0, true)
	# plinthe sombre au pied des murs des salles : lecture des volumes
	for r in rooms:
		var c: Vector3 = r["c"]
		var sx: float = r["tx"] * CELL
		var sz: float = r["tz"] * CELL
		g.box("pierre_base", c + Vector3(0, 0.02, 0), Vector3(sx - 1.0, 0.04, sz - 1.0), 0.0, false)
	for r in rooms:
		if r["type"] in ["armurerie", "bibliotheque", "refectoire", "crypte", "caserne", "ossuaire", "depart"]:
			var c: Vector3 = r["c"]
			var hx: float = r["tx"] * CELL * 0.5 - 1.2
			var hz: float = r["tz"] * CELL * 0.5 - 1.2
			for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
				g.box("pierre_base", c + Vector3(d.x * hx, WALL_H * 0.5, d.y * hz), Vector3(1.2, WALL_H, 1.2), 0.0, true)
				g.box("pierre_claire", c + Vector3(d.x * hx, WALL_H - 0.2, d.y * hz), Vector3(1.6, 0.4, 1.6), 0.0, false)
			if r["type"] != "depart":
				g.box("tissu_rouge", c + Vector3(0, 0.06, 0), Vector3(3.0, 0.04, r["tz"] * CELL - 3.0), 0.0, false)
				g.box("or", c + Vector3(0, 0.05, 0), Vector3(3.3, 0.04, r["tz"] * CELL - 2.8), 0.0, false)
	_boss_room(g, root, col)
	g.commit(root, "Salles")
	# torches murales (flamme) et une lumière par salle
	for r in rooms:
		_lights(root, r, col)

func _lights(root: Node3D, r: Dictionary, col: Color) -> void:
	var c: Vector3 = r["c"]
	var hx: float = r["tx"] * CELL * 0.5
	var hz: float = r["tz"] * CELL * 0.5
	for s in [-1.0, 1.0]:
		var p := c + Vector3(s * (hx - 0.1), 3.0, 0)
		if not solid(int(round((p.x - B.x) / CELL + s)), int(round((p.z - B.z) / CELL))):
			Kit.dungeon(root, "Torch_Wall", p, -s * PI * 0.5, 1.3)
			var f := FX.particles("fire_01", 5, 0.45, [Color(1, 0.8, 0.4, 0.9), Color(1, 0.3, 0.1, 0)], 0.3, false)
			f.direction = Vector3.UP
			f.gravity = Vector3.ZERO
			f.initial_velocity_min = 0.3
			f.initial_velocity_max = 0.6
			root.add_child(f)
			f.global_position = p + Vector3(-s * 0.4, 0.55, 0)
			f.emitting = true
	var l := OmniLight3D.new()
	var boss: bool = r["type"] == "boss"
	l.light_color = col if boss or r["type"] == "cachette" else Color(1.0, 0.62, 0.32)
	l.light_energy = 2.6 if boss else 2.0
	l.omni_range = maxf(hx, hz) * 1.5
	l.omni_attenuation = 0.8
	root.add_child(l)
	l.global_position = c + Vector3(0, 4.2, 0)

## Salle du gardien : estrade au nord avec rampe, trône, coffre, colonnes, braseros, cercle runique
var throne := Vector3.ZERO
var chest_pos := Vector3.ZERO
var boss_spot := Vector3.ZERO
func _boss_room(g: Geo, root: Node3D, col: Color) -> void:
	var r := room_of("boss")
	var c: Vector3 = r["c"]
	var hx: float = r["tx"] * CELL * 0.5
	var hz: float = r["tz"] * CELL * 0.5
	var h := 1.4
	var ez := c.z - hz + 3.2          # centre de l'estrade (profondeur 6.4 m)
	g.box("pierre_claire", Vector3(c.x, B.y + h * 0.5, ez), Vector3(hx * 1.3, h, 6.4), 0.0, true)
	g.box("pierre_base", Vector3(c.x, B.y + h + 0.03, ez), Vector3(hx * 1.3 - 0.6, 0.06, 5.8), 0.0, false)
	# rampe centrale (pente douce, on la monte sans sauter)
	var L := 4.4
	var ang := atan2(h, L)
	var rb := Basis(Vector3.RIGHT, ang)
	g.obox("pierre_claire", Transform3D(rb, Vector3(c.x, B.y + h * 0.5 - 0.12, ez + 3.2 + L * 0.5 - 0.2)), Vector3(4.0, 0.3, sqrt(L * L + h * h)), true)
	throne = Vector3(c.x, B.y + h, ez - 1.6)
	Kit.dungeon(root, "Throne", throne, 0.0, 1.5)
	chest_pos = Vector3(c.x + 3.6, B.y + h, ez - 1.0)
	boss_spot = Vector3(c.x, B.y, c.z + 1.0)
	# colonnes en anneau (sauf devant l'estrade)
	for i in 8:
		var a := TAU * i / 8.0 + PI / 8.0
		var q := c + Vector3(cos(a) * 11.0, 0, sin(a) * 9.0)
		if q.z < ez + 4.5:
			continue
		g.box("pierre_base", Vector3(q.x, B.y + WALL_H * 0.5, q.z), Vector3(1.1, WALL_H, 1.1), 0.0, true)
	# braseros aux quatre coins
	for d in [Vector2(-1, -1), Vector2(1, -1), Vector2(-1, 1), Vector2(1, 1)]:
		var q := Vector3(c.x + d.x * (hx - 3.0), 0, ez + 4.2 if d.y < 0 else c.z + hz - 2.5)
		var y := B.y
		Kit.dungeon(root, "Firewood", Vector3(q.x, y, q.z), 0.0, 1.2)
		var f := FX.particles("flame_01", 10, 0.6, [Color(1, 0.9, 0.5, 0.0), col.lightened(0.2), Color(0.3, 0.05, 0.05, 0)], 0.8, false)
		f.direction = Vector3.UP
		f.initial_velocity_min = 0.6
		f.initial_velocity_max = 1.3
		root.add_child(f)
		f.global_position = Vector3(q.x, y + 0.3, q.z)
		f.emitting = true
	var rune := Magic.rune(Vector3(c.x, B.y + 0.06, c.z + 1.0), 7.0, col, 1e9, 0.08)
	rune.reparent(root)
	for k in 3:
		Kit.dungeon(root, ["Banner", "Banner", "Candlestick_Triple"][k], Vector3(c.x + (k - 1) * 4.0, B.y + h, c.z - hz + 0.6), 0.0, 1.3)

## Décor d'une salle de vie selon son usage
func decorate(root: Node3D, r: Dictionary) -> void:
	var c: Vector3 = r["c"]
	var hx: float = r["tx"] * CELL * 0.5 - 1.4
	var hz: float = r["tz"] * CELL * 0.5 - 1.4
	var along := func(names: Array, side: int) -> void:
		for i in names.size():
			var t := (i + 0.5) / names.size() * 2.0 - 1.0
			var p := c + Vector3(t * hx * 0.8, 0, side * hz)
			Kit.dungeon(root, names[i], p, 0.0 if side < 0 else PI, 1.0)
	match r["type"]:
		"armurerie":
			along.call(["WeaponRack_Big", "Shield", "WeaponRack_Big", "Barrel_Big"], -1)
			along.call(["WeaponRack_Small", "Barrel_Closed", "Spear", "WeaponRack_Small"], 1)
			Kit.dungeon(root, "Table_Big", c, 0.0, 1.0)
			Kit.dungeon(root, "Sword", c + Vector3(0, 0.85, 0), 0.0, 1.0)
		"bibliotheque":
			along.call(["Shelf", "Shelf", "Shelf"], -1)
			along.call(["Shelf", "Scroll_Stack", "Shelf"], 1)
			Kit.dungeon(root, "Desk", c, 0.0, 1.0)
			Kit.dungeon(root, "Book_Open", c + Vector3(0, 0.82, 0), 0.0, 1.0)
			Kit.dungeon(root, "Candlestick_Triple", c + Vector3(0.6, 0.82, 0), 0.0, 1.0)
		"refectoire":
			for s in [-1.0, 1.0]:
				var tq := c + Vector3(s * 2.6, 0, 0)
				Kit.dungeon(root, "Table_Big", tq, PI / 2.0, 1.0)
				Kit.dungeon(root, "Bench", tq + Vector3(-1.1, 0, 0), PI / 2.0, 1.0)
				Kit.dungeon(root, "Bench", tq + Vector3(1.1, 0, 0), -PI / 2.0, 1.0)
				for k in 3:
					Kit.dungeon(root, ["Mug", "Bread", "Bowl_Full"][k], tq + Vector3(0, 0.82, (k - 1) * 0.7), 0.0, 1.0)
			along.call(["Barrel_Big", "Oven", "Barrel_Big"], -1)
		"caserne":
			along.call(["WeaponRack_Big", "Barrel_Closed", "WeaponRack_Big"], -1)
			for k in 3:
				Kit.dungeon(root, "Bench", c + Vector3((k - 1) * 3.0, 0, hz * 0.5), 0.0, 1.0)
		"ossuaire":
			for k in 10:
				Kit.dungeon(root, ["Skull", "Bone"][k % 2], c + Vector3(rng.randf_range(-hx, hx), 0, -hz + rng.randf() * 1.5), rng.randf() * TAU, 1.4)
			along.call(["Candlestick_Triple", "Cauldron_Full", "Candlestick_Triple"], 1)
		"crypte":
			for i in 3:
				var q := c + Vector3((i - 1) * 3.2, 0, -hz * 0.5)
				Kit.dungeon(root, "Skull", q + Vector3(0.6, 0.1, 1.4), 0.0, 1.4)
			along.call(["Candlestick_Triple", "Bone", "Candlestick_Triple"], 1)
		"cachette":
			pass
	# éparpillé : os, tonneaux, caisses, chandeliers — le donjon vit
	for k in 8:
		var q := c + Vector3(rng.randf_range(-hx, hx), 0, rng.randf_range(-hz, hz))
		Kit.dungeon(root, ["Bone", "Skull", "Barrel_Open", "Bag", "Barrel_Closed", "Candlestick", "Bucket", "Bone"][k], q, rng.randf() * TAU, 1.1)
