extends Node3D
class_name Crops
# Cueillette : buissons à fruits, champignons, courges et potagers des fermes.
# On cueille à la main (pas d'outil), ça repousse au bout de quelques minutes.

const REGROW := 150.0
const PATH := "res://assets/food/%s.glb"
static var _pix: StandardMaterial3D
static var _soil: StandardMaterial3D
static var _sizes := {}

var world: Node
var crops: Array = []
var grid := {}
var rng := RandomNumberGenerator.new()

static func pix_mat() -> StandardMaterial3D:
	if _pix == null:
		_pix = StandardMaterial3D.new(); _pix.albedo_texture = load("res://assets/food/pixpal.png")
		_pix.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; _pix.roughness = 0.75
	return _pix

static func soil_mat() -> StandardMaterial3D:
	if _soil == null:
		_soil = StandardMaterial3D.new(); _soil.albedo_color = Color("#6b4a2e"); _soil.roughness = 1.0
	return _soil

# modèle de nourriture avec la palette, mis à la taille voulue (plus grande dimension = size mètres)
static func food_model(k: String, size: float) -> Node3D:
	var m: String = Game.FOOD[k].m
	var n: Node3D = load(PATH % m).instantiate()
	var big := 0.0
	if _sizes.has(m): big = _sizes[m]
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = pix_mat()
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		if not _sizes.has(m):
			var bb: AABB = (mi as MeshInstance3D).get_aabb()
			big = max(big, bb.size.x, bb.size.y, bb.size.z)
	_sizes[m] = big
	n.scale = Vector3.ONE * (size / max(0.01, big))
	return n

func setup(w: Node) -> void:
	world = w; rng.seed = 4242 + int(w.map_id)

func _near(p: Vector3, r: float) -> bool:
	var cx := int(floor(p.x / 8.0)); var cz := int(floor(p.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for c in grid.get(Vector2i(cx + dx, cz + dz), []):
				if Vector2(c.pos.x - p.x, c.pos.z - p.z).length() < r: return true
	return false

func add_crop(k: String, t: int, p: Vector3, plant := "", rot := 0.0) -> Dictionary:
	if plant == "": plant = Game.FOOD[k].plant
	p.y = world.height(p.x, p.z)
	var root := Node3D.new(); root.position = p; root.rotation.y = rng.randf() * TAU if plant != "rang" else rot; add_child(root)
	var parts: Array = []
	match plant:
		"buisson":
			var bush: Node3D = load("res://assets/forest/" + ["Bush_2_A_Color1.gltf", "Bush_1_E_Color1.gltf", "Bush_2_D_Color1.gltf"][rng.randi() % 3]).instantiate()
			bush.scale = Vector3.ONE * rng.randf_range(1.15, 1.4); root.add_child(bush)
			var fs: float = 0.26 if k in ["cerise", "fraise", "citron", "kiwi", "figue"] else 0.32
			for i in 6:
				var a := i * TAU / 6.0 + rng.randf() * 0.6
				var f := food_model(k, fs)
				f.position = Vector3(cos(a) * rng.randf_range(0.45, 0.62), rng.randf_range(0.45, 1.0), sin(a) * rng.randf_range(0.45, 0.62))
				f.rotation = Vector3(rng.randf() * 0.6, rng.randf() * TAU, rng.randf() * 0.6)
				root.add_child(f); parts.append(f)
		"rang":
			# dans un champ labouré : 3 légumes alignés sur le sillon
			for i in 3:
				var f := food_model(k, 0.6)
				f.position = Vector3(-0.75 + i * 0.75, 0.16, rng.randf_range(-0.1, 0.1))
				f.rotation = Vector3(0, rng.randf() * TAU, 0)
				root.add_child(f); parts.append(f)
			var lf: Node3D = load("res://assets/forest/Grass_1_C_Color1.gltf").instantiate(); lf.scale = Vector3.ONE * 0.55; lf.position.y = 0.1; root.add_child(lf)
		"potager":
			# butte de terre + 4 légumes posés dessus
			var mound := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = 0.85; sm.height = 0.7; sm.radial_segments = 10; sm.rings = 5
			mound.mesh = sm; mound.scale = Vector3(1.0, 0.45, 0.75); mound.position.y = -0.05; mound.material_override = soil_mat()
			mound.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(mound)
			for i in 4:
				var f := food_model(k, 0.42)
				f.position = Vector3(-0.5 + i * 0.33, 0.12, rng.randf_range(-0.18, 0.18))
				f.rotation = Vector3(0, rng.randf() * TAU, 0)
				root.add_child(f); parts.append(f)
		_:
			var n := 3 if k.begins_with("c") or k in ["girolle", "amanite", "morille"] else 2
			var fs: float = 0.38 if k in ["cepe", "girolle", "amanite", "morille"] else 0.62
			for i in n:
				var f := food_model(k, fs * rng.randf_range(0.85, 1.15))
				f.position = Vector3(rng.randf_range(-0.5, 0.5), 0.0, rng.randf_range(-0.5, 0.5))
				f.rotation.y = rng.randf() * TAU
				root.add_child(f); parts.append(f)
			var tuft: Node3D = load("res://assets/forest/Grass_1_C_Color1.gltf").instantiate(); tuft.scale = Vector3.ONE * 0.9; root.add_child(tuft)
	for gi in root.find_children("*", "GeometryInstance3D", true, false): (gi as GeometryInstance3D).visibility_range_end = 70.0
	var c := {"kind": k, "tier": t, "pos": p, "root": root, "parts": parts, "ready": true, "t": 0.0, "plant": plant}
	crops.append(c)
	var gk := Vector2i(int(floor(p.x / 8.0)), int(floor(p.z / 8.0)))
	if not grid.has(gk): grid[gk] = []
	grid[gk].append(c)
	return c

# cueillette sauvage : buissons et champignons répartis dans chaque région
func build_wild() -> void:
	for reg in range(1, World.REGIONS.size()):
		var R: Dictionary = World.REGIONS[reg]
		var sets: Array = Game.FOOD_BY_STYLE.get(R.get("style", "meadow"), Game.FOOD_BY_STYLE.meadow)
		var wild: Array = sets[0]
		var want := 14; var placed := 0; var tries := 0
		while placed < want and tries < 3000:
			tries += 1
			var p := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
			if world.region_at(p.x, p.z) != reg: continue
			if not world._free_spot(p, 1.2, true): continue
			if world._near_node_grid(p, 3.5) or _near(p, 7.0): continue
			# par petits groupes de 2 : on trouve un coin à cueillir, pas un buisson perdu
			var k: String = wild[rng.randi() % wild.size()]
			add_crop(k, R.tier, p); placed += 1
			var q := p + Vector3(rng.randf_range(-3, 3), 0, rng.randf_range(-3, 3))
			if world._free_spot(q, 1.0, true) and not world._near_node_grid(q, 2.5):
				add_crop(k, R.tier, q); placed += 1

func nearest(pp: Vector3, r: float) -> Dictionary:
	var best := {}; var bd := r
	var cx := int(floor(pp.x / 8.0)); var cz := int(floor(pp.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for c in grid.get(Vector2i(cx + dx, cz + dz), []):
				if not c.ready: continue
				var d := Vector2(c.pos.x - pp.x, c.pos.z - pp.z).length()
				if d < bd: bd = d; best = c
	return best

func pick(c: Dictionary) -> int:
	if not c.ready: return 0
	c.ready = false; c.t = REGROW * rng.randf_range(0.8, 1.2)
	for f in c.parts: (f as Node3D).visible = false
	return 2 + (1 if c.plant in ["potager", "rang"] else 0) + (1 if rng.randf() < 0.25 else 0)

var _acc := 0.0
func update(dt: float) -> void:
	_acc += dt
	if _acc < 0.5: return
	var step := _acc; _acc = 0.0
	for c in crops:
		if c.ready: continue
		c.t -= step
		if c.t <= 0.0:
			c.ready = true
			for f in c.parts:
				var nd: Node3D = f; nd.visible = true
				var s0: Vector3 = nd.scale; nd.scale = s0 * 0.2
				create_tween().tween_property(nd, "scale", s0, 0.8).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
