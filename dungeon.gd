extends Node3D
class_name Dungeon
# Donjon aléatoire : salles reliées par des couloirs, monstres, gardien, coffre de fin.
# Construit loin du monde (x ≈ 600) ; le monde renvoie une hauteur 0 et interroge walkable() ici.

const ORIGIN := Vector3(600, 0, 0)
const TILE := 4.0
const ROOM := 4            # une salle = 4 × 4 dalles (16 m)
const STEP := 6            # salle + couloir de 2 dalles
const DG := "res://assets/dungeon/"

var main: Node
var tier := 1
var floor_tiles := {}      # Vector2i → true
var rooms: Array = []      # [{c: Vector2i (coin), center: Vector3, kind}]
var spawn_pos := Vector3.ZERO
var exit_pos := Vector3.ZERO
var chest: Node3D
var chest_pos := Vector3.ZERO
var chest_open := false
var boss: Enemy
var exit_open := false
var exit_node: Node3D
var sp_dict := {"members": [], "dungeon": true}
var rng := RandomNumberGenerator.new()
var mm := {}               # chemin → [Transform3D]
var entry: Dictionary
var cleared_rooms := 0
var modifier := ""
const MODIFIERS := ["Meute", "Sentinelles", "Arcanes"]

func build(m: Node, t: int, seed_v: int, e: Dictionary) -> void:
	main = m; tier = t; entry = e; rng.seed = seed_v
	modifier = MODIFIERS[rng.randi() % MODIFIERS.size()]
	var n_rooms := 6 + t + rng.randi_range(0, 2)   # plus de salles à explorer
	# marche aléatoire sur une grille de salles
	var slots: Array[Vector2i] = [Vector2i.ZERO]
	var dirs := [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]
	var guard := 0
	while slots.size() < n_rooms and guard < 400:
		guard += 1
		var last: Vector2i = slots[-1]
		var opts := []
		for d in dirs:
			var q: Vector2i = last + d
			if q in slots: continue
			opts.append(q)
		if opts.is_empty(): break
		slots.append(opts[rng.randi() % opts.size()])
	for i in slots.size():
		var c := slots[i] * STEP
		for x in ROOM:
			for z in ROOM: floor_tiles[c + Vector2i(x, z)] = true
		var center := _tile_pos(c + Vector2i(ROOM / 2, ROOM / 2)) - Vector3(TILE * 0.5, 0, TILE * 0.5)
		rooms.append({"c": c, "center": center, "kind": "start" if i == 0 else ("boss" if i == slots.size() - 1 else "fight")})
		if i > 0:
			# couloir entre la salle précédente et celle-ci
			var a: Vector2i = slots[i - 1] * STEP; var d: Vector2i = slots[i] - slots[i - 1]
			var mid := a + Vector2i(1, 1)
			for k in range(0, STEP + 1):
				var tpos := mid + d * k
				floor_tiles[tpos] = true; floor_tiles[tpos + Vector2i(1, 0) if d.y != 0 else tpos + Vector2i(0, 1)] = true
	_geometry()
	spawn_pos = rooms[0].center
	_populate()

func _tile_pos(t: Vector2i) -> Vector3: return ORIGIN + Vector3(t.x * TILE + TILE * 0.5, 0, t.y * TILE + TILE * 0.5)

func walkable(x: float, z: float) -> bool:
	var tx := int(floor((x - ORIGIN.x) / TILE)); var tz := int(floor((z - ORIGIN.z) / TILE))
	return floor_tiles.has(Vector2i(tx, tz))

func _tile_of(p: Vector3) -> Vector2i: return Vector2i(int(floor((p.x - ORIGIN.x) / TILE)), int(floor((p.z - ORIGIN.z) / TILE)))

# Ligne de vue : tout le segment doit rester sur des dalles (pas de coup à travers les murs)
func sight(a: Vector3, b: Vector3, r := 0.45) -> bool:
	var d := Vector2(b.x - a.x, b.z - a.z); var n := int(d.length() / 0.7) + 1
	for i in n + 1:
		var t := float(i) / n
		if not walkable(a.x + d.x * t, a.z + d.y * t): return false
		# ne pas raser les coins : on teste aussi un peu de chaque côté
		if i > 0 and i < n:
			var side := Vector2(-d.y, d.x).normalized() * r
			if not walkable(a.x + d.x * t + side.x, a.z + d.y * t + side.y) or not walkable(a.x + d.x * t - side.x, a.z + d.y * t - side.y): return false
	return true

# Champ de direction (BFS depuis la dalle du héros) : chaque monstre suit la pente vers lui
var flow := {}
var flow_from := Vector2i(99999, 99999)
func _flow_update() -> void:
	var src := _tile_of(main.player.global_position)
	if src == flow_from or not floor_tiles.has(src): return
	flow_from = src; flow = {src: 0}
	var q: Array[Vector2i] = [src]; var i := 0
	while i < q.size():
		var c: Vector2i = q[i]; i += 1
		for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nb: Vector2i = c + d
			if floor_tiles.has(nb) and not flow.has(nb): flow[nb] = flow[c] + 1; q.append(nb)

func steer(p: Vector3) -> Vector3:
	_flow_update()
	var t := _tile_of(p)
	if not flow.has(t): return Vector3.ZERO
	var best := t; var bv: int = flow[t]
	for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nb: Vector2i = t + d
		if flow.has(nb) and flow[nb] < bv: bv = flow[nb]; best = nb
	var goal := _tile_pos(best)
	var v := goal - p; v.y = 0
	return v.normalized() if v.length() > 0.05 else Vector3.ZERO

func _add(path: String, xf: Transform3D) -> void:
	if not mm.has(path): mm[path] = []
	mm[path].append(xf)

func _geometry() -> void:
	var mn := Vector2i(999, 999); var mx := Vector2i(-999, -999)
	for t in floor_tiles:
		mn = Vector2i(min(mn.x, t.x), min(mn.y, t.y)); mx = Vector2i(max(mx.x, t.x), max(mx.y, t.y))
		var p := _tile_pos(t)
		_add(DG + ("floor_tile_large_rocks.gltf" if rng.randf() < 0.08 else "floor_tile_large.gltf"), Transform3D(Basis(Vector3.UP, rng.randi_range(0, 3) * PI * 0.5), p))
		# murs là où il n'y a pas de sol voisin
		for d in [[Vector2i(0, -1), 0.0], [Vector2i(0, 1), PI], [Vector2i(-1, 0), PI * 0.5], [Vector2i(1, 0), -PI * 0.5]]:
			var nb: Vector2i = t + d[0]
			if floor_tiles.has(nb): continue
			var wp: Vector3 = p + Vector3(d[0].x, 0, d[0].y) * (TILE * 0.5)
			var south: bool = d[0] == Vector2i(0, 1)
			var hgt := 0.22 if south else 0.6     # murs du bas très bas : la caméra voit le héros
			var path := DG + ("wall_cracked.gltf" if rng.randf() < 0.2 else "wall.gltf")
			_add(path, Transform3D(Basis(Vector3.UP, d[1]).scaled(Vector3(1, hgt, 1)), wp))
			var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new()
			bx.size = Vector3(TILE, 4.0, 1.0); cs.shape = bx; body.add_child(cs); body.position = wp + Vector3(0, 2.0, 0); body.rotation.y = d[1]; add_child(body)
			if not south and rng.randf() < 0.18:
				var torch: Node3D = load(DG + "torch_mounted.gltf").instantiate(); torch.position = wp + Vector3(0, 1.5, 0) - Vector3(d[0].x, 0, d[0].y) * 0.55; torch.rotation.y = d[1] + PI; add_child(torch)
				main.world._light(torch.position + Vector3(0, 0.6, 0) - Vector3(d[0].x, 0, d[0].y) * 0.3, Color("#ffa040"), 2.2, 3.0)
	# dalle physique sous tout le donjon
	var a := _tile_pos(mn) - Vector3(TILE, 0, TILE) * 0.5; var b := _tile_pos(mx) + Vector3(TILE, 0, TILE) * 0.5
	var slab := StaticBody3D.new(); var sc := CollisionShape3D.new(); var sb := BoxShape3D.new(); sb.size = Vector3(b.x - a.x, 1.0, b.z - a.z)
	sc.shape = sb; slab.add_child(sc); slab.position = (a + b) * 0.5 + Vector3(0, -0.45, 0); add_child(slab)
	# fond sombre (vide autour)
	var void_mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(400, 400); void_mi.mesh = pm
	var vm := StandardMaterial3D.new(); vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; vm.albedo_color = Color(0.03, 0.03, 0.04); void_mi.material_override = vm
	void_mi.position = (a + b) * 0.5 + Vector3(0, -2.0, 0); add_child(void_mi)
	for path in mm: _multi(path, mm[path])

func _multi(path: String, xforms: Array) -> void:
	var sc: Node3D = load(path).instantiate()
	var meshes: Array = []
	main.world._collect(sc, Transform3D.IDENTITY, meshes)
	for m in meshes:
		var mmesh := MultiMesh.new(); mmesh.transform_format = MultiMesh.TRANSFORM_3D; mmesh.mesh = m[0]; mmesh.instance_count = xforms.size()
		for i in xforms.size(): mmesh.set_instance_transform(i, xforms[i] * m[1])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mmesh; add_child(mmi)
	sc.free()

func _deco(path: String, p: Vector3, rot := 0.0, s := 1.0) -> Node3D:
	var o: Node3D = load(path).instantiate(); o.position = p; o.rotation.y = rot; o.scale = Vector3.ONE * s; add_child(o); return o

func _room_enemy(k: String, p: Vector3, camp: Dictionary, champion := false, guardian := false) -> Enemy:
	var base: Dictionary = Enemy.KINDS[k]
	var extra := {"hp": float(base.hp) * 1.4, "dmg": float(base.dmg) * 1.15, "forced_elite": champion}
	if guardian:
		extra.hp = 22.0; extra.dmg = 1.9; extra.dungeon_boss = true
		extra.name = "Gardien des profondeurs"
		extra.scale = float(base.get("scale", 1.0)) * (1.65 if base.get("animal", false) else 1.0)
		if base.get("animal", false): extra.rad = float(base.rad) * 1.5; extra.h = float(base.h) * 1.5
	var e: Enemy = main._spawn_enemy(k, tier, p, camp, false, extra)
	e.leash = 24.0 if not guardian else 20.0
	sp_dict.members.append(e)
	return e

func _populate() -> void:
	var skel := {1: ["minion", "minion", "rogue"], 2: ["minion", "rogue", "warrior"], 3: ["warrior", "rogue", "minion", "mage"], 4: ["warrior", "mage", "rogue", "warrior"], 5: ["warrior", "mage", "rogue", "warrior", "mage"]}
	var beasts := {1: ["renard", "renard", "loup"], 2: ["loup", "loup", "cerf"], 3: ["loup", "taureau", "loup"], 4: ["taureau", "loup", "loup", "cerf"], 5: ["taureau", "loup", "taureau", "loup"]}
	var theme := "beasts" if modifier == "Meute" else "skel"
	for ri in rooms.size():
		var r: Dictionary = rooms[ri]
		var room_camp := {"members": [], "dungeon": true, "room": ri}
		r["camp"] = room_camp
		var c: Vector3 = r.center
		match r.kind:
			"start":
				_deco(DG + "pillar_decorated.gltf", c + Vector3(-5, 0, -5), 0.0, 0.7)
				_deco(DG + "pillar_decorated.gltf", c + Vector3(5, 0, -5), 0.0, 0.7)
				_deco(DG + "banner_patternC_red.gltf", c + Vector3(0, 0, -6.5), 0.0, 1.0)
			"fight":
				var kinds: Array = (beasts if theme == "beasts" else skel)[tier].duplicate()
				if modifier == "Arcanes": kinds.append("mage" if ri % 2 == 0 else "archer")
				for i in kinds.size():
					var p := c + Vector3(cos(i * 2.2) * 3.0, 0, sin(i * 2.2) * 3.0)
					_room_enemy(kinds[i], p, room_camp, modifier == "Sentinelles" and i == 0)
				for k in 2:
					var q := c + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
					_deco(DG + ["barrel_small_stack.gltf", "rubble_half.gltf", "crates_stacked.gltf", "candle_triple.gltf"][rng.randi() % 4], q, rng.randf() * TAU, 0.8)
				if rng.randf() < 0.4: _deco(DG + "coin_stack_large.gltf", c + Vector3(rng.randf_range(-5, 5), 0, rng.randf_range(-5, 5)), 0.0, 1.2)
			"boss":
				# gardien du donjon : élite géante + coffre doré
				var gk: String = ("taureau" if tier >= 3 else "loup") if theme == "beasts" else "boss"
				boss = _room_enemy(gk, c + Vector3(0, 0, -2), room_camp, false, true)
				boss.name_lbl.text = "Gardien du donjon · T%d" % tier; boss.name_lbl.modulate = Color("#ffb04a"); boss.name_lbl.font_size = 56; boss.bar_root.visible = true
				var minion: String = "minion" if theme == "skel" else "loup"
				for i in 2: _room_enemy(minion, c + Vector3(-4 + i * 8, 0, 1), room_camp)
				chest_pos = c + Vector3(0, 0, -6)
				chest = _deco(DG + "chest_gold.gltf", chest_pos, 0.0, 1.4)
				_deco(DG + "sword_shield_gold.gltf", c + Vector3(-5, 0, -6.5), 0.4, 1.2)
				exit_pos = c + Vector3(0, 0, 4)
				for q in [c + Vector3(-6, 0, -6), c + Vector3(6, 0, -6)]: _deco(DG + "pillar_decorated.gltf", q, 0.0, 0.7)

# Le portail de sortie apparaît quand le gardien tombe
func open_exit() -> void:
	if exit_open: return
	exit_open = true
	exit_node = Node3D.new(); exit_node.position = exit_pos; add_child(exit_node)
	var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.6; cm.bottom_radius = 1.6; cm.height = 0.05; disc.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(0.5, 0.8, 1.0, 0.7); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	disc.material_override = m; disc.position.y = 0.1; exit_node.add_child(disc)
	main.world._light(exit_pos + Vector3(0, 1.2, 0), Color("#7fd0ff"), 2.6, 4.0)
	var l := Label3D.new(); l.text = "SORTIE"; l.font_size = 56; l.outline_size = 12; l.modulate = Color("#bfe8ff"); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.008; l.position.y = 2.2; l.no_depth_test = true; exit_node.add_child(l)

func alive_count() -> int:
	var n := 0
	for e in sp_dict.members:
		if is_instance_valid(e) and not e.dead: n += 1
	return n

func map_image() -> Image:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8); img.fill(Color(0.06, 0.06, 0.08))
	for t in floor_tiles:
		var px: int = 32 + t.x * 2 - 6; var pz: int = 32 + t.y * 2 - 6
		for dx in 2:
			for dz in 2:
				if px + dx >= 0 and px + dx < 64 and pz + dz >= 0 and pz + dz < 64: img.set_pixel(px + dx, pz + dz, Color(0.5, 0.45, 0.38))
	return img
