class_name Vegetation
## Forêts, bosquets, arbres isolés, rochers et herbes — en MultiMesh par bloc (culling + distance de vue).
## Les zones réservées (routes, eau, bâtiments, champs) restent toujours dégagées.

const CELL := 80.0

static var _bins := {}   # clé "type|cx|cz" -> Array[Transform3D]
static var _trunks: Array = []   # [pos, rayon]

static func _add(kind: String, t: Transform3D) -> void:
	var cx := int(floor((t.origin.x + Layout.HALF) / CELL))
	var cz := int(floor((t.origin.z + Layout.HALF) / CELL))
	var key := "%s|%d|%d" % [kind, cx, cz]
	if not _bins.has(key):
		_bins[key] = []
	_bins[key].append(t)

static func _xf(x: float, z: float, s: float, rot: float, sink := 0.15) -> Transform3D:
	var y := Layout.height(x, z) - sink
	return Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), Vector3(x, y, z))

## Densité de forêt (0..1) selon la région
static func forest_density(p: Vector2) -> float:
	var n := Layout._n()
	var d := 0.0
	# grande forêt de l'ouest, avec clairières
	d = maxf(d, smoothstep(-40.0, -95.0, p.x) * 0.95)
	# bois au sud-ouest et au nord
	d = maxf(d, 0.8 * (1.0 - smoothstep(30.0, 70.0, p.distance_to(Vector2(-120, 140)))))
	d = maxf(d, 0.7 * (1.0 - smoothstep(25.0, 60.0, p.distance_to(Vector2(-60, -175)))))
	d = maxf(d, 0.55 * (1.0 - smoothstep(20.0, 45.0, p.distance_to(Vector2(105, -95)))))
	d = maxf(d, 0.6 * (1.0 - smoothstep(25.0, 55.0, p.distance_to(Vector2(110, 230)))))
	# clairières : le bruit creuse des trouées pour se promener
	var holes := n.get_noise_2d(p.x * 2.2 + 300.0, p.y * 2.2)
	d *= smoothstep(-0.05, 0.25, holes + 0.15)
	# moins dense au pied des montagnes
	var edge := maxf(absf(p.x), absf(p.y))
	d *= 1.0 - smoothstep(255.0, 290.0, edge)
	return d

static func build(parent: Node3D) -> void:
	_bins.clear()
	_trunks.clear()
	var rng := RandomNumberGenerator.new()
	rng.seed = 2026
	var step := 6.5
	var x := -Layout.HALF + 4.0
	while x < Layout.HALF - 4.0:
		var z := -Layout.HALF + 4.0
		while z < Layout.HALF - 4.0:
			var px := x + rng.randf_range(-2.8, 2.8)
			var pz := z + rng.randf_range(-2.8, 2.8)
			var p := Vector2(px, pz)
			var h := Layout.height(px, pz)
			if h > Layout.WATER + 0.7 and h < 34.0 and not Layout.reserved(p, 2.0):
				var nm := Layout.normal(px, pz)
				if nm.y > 0.8:
					var dens := forest_density(p)
					var lone := 0.018   # arbres isolés dans les prés
					if rng.randf() < maxf(dens, lone):
						var kind := "oak"
						var r := rng.randf()
						var conifer := smoothstep(-80.0, -200.0, p.y) * 0.7 + smoothstep(12.0, 26.0, h) * 0.8
						if r < conifer * 0.9:
							kind = "pine"
						elif Layout.river_dist(p) < 30.0 and r < 0.55:
							kind = "birch"
						elif r > 0.82:
							kind = "birch"
						var s := Kit.S_TREE * rng.randf_range(0.8, 1.25)
						if kind == "pine":
							s *= 0.85
						elif kind == "birch":
							s *= 0.75
						_add(kind, _xf(px, pz, s, rng.randf() * TAU))
						_trunks.append([Vector3(px, h, pz), 0.35 * s])
					elif dens > 0.2 and rng.randf() < 0.35:
						_add(["bush", "fern"][rng.randi() % 2], _xf(px, pz, rng.randf_range(1.1, 1.7), rng.randf() * TAU, 0.05))
					elif dens > 0.3 and rng.randf() < 0.08:
						_add(["log", "stump", "mushrooms"][rng.randi() % 3], _xf(px, pz, 1.3, rng.randf() * TAU, 0.05))
			z += step
		x += step
	# rochers : collines du nord-est, berges, montagnes
	for i in 520:
		var px := rng.randf_range(-Layout.HALF + 10, Layout.HALF - 10)
		var pz := rng.randf_range(-Layout.HALF + 10, Layout.HALF - 10)
		var p := Vector2(px, pz)
		if Layout.reserved(p, 1.0):
			continue
		var h := Layout.height(px, pz)
		var nm := Layout.normal(px, pz)
		var want := 0.05 + smoothstep(0.85, 0.7, nm.y) * 0.8 + (1.0 - smoothstep(30.0, 90.0, p.distance_to(Vector2(165, -150)))) * 0.5
		if h > 24.0:
			want += 0.4
		if h < Layout.WATER + 0.3 or rng.randf() > want:
			continue
		var k: String = ["boulder", "rocks", "rock_mossy", "slab", "pebbles"][rng.randi() % 5]
		var s := rng.randf_range(1.2, 2.6) if k != "pebbles" else 1.5
		_add(k, _xf(px, pz, s, rng.randf() * TAU, 0.2))
		if k == "boulder" or k == "rocks":
			_trunks.append([Vector3(px, h, pz), 0.55 * s])
	# herbes hautes et fleurs (visibles de près seulement)
	for i in 9000:
		var px := rng.randf_range(-260, 260)
		var pz := rng.randf_range(-260, 260)
		var p := Vector2(px, pz)
		if Layout.road_dist(p) < 1.0 or Layout.in_castle(p, 2.0) or Layout.in_fields(p, 1.0):
			continue
		var h := Layout.height(px, pz)
		if h < Layout.WATER + 0.6 or h > 26.0:
			continue
		var k := "grass"
		if rng.randf() < 0.18 and Layout.river_dist(p) > 12:
			k = "flowers"
		_add(k, _xf(px, pz, rng.randf_range(1.2, 2.0), rng.randf() * TAU, 0.02))
	_emit(parent)
	_collisions(parent)

static func _emit(parent: Node3D) -> void:
	var root := Node3D.new()
	root.name = "Vegetation"
	parent.add_child(root)
	for key in _bins:
		var kind: String = key.split("|")[0]
		var arr: Array = _bins[key]
		var mesh := Kit.mesh_of(Kit.NATURE % kind)
		if mesh == null:
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.mesh = mesh
		mm.instance_count = arr.size()
		for i in arr.size():
			mm.set_instance_transform(i, arr[i])
		var mmi := MultiMeshInstance3D.new()
		mmi.multimesh = mm
		var small := kind in ["grass", "flowers", "fern", "pebbles", "mushrooms"]
		var mid := kind in ["bush", "log", "stump", "rock_mossy", "slab", "rocks"]
		mmi.visibility_range_end = 55.0 if small else (130.0 if mid else 260.0)
		mmi.visibility_range_end_margin = 10.0
		mmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED
		if small:
			mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mmi)

static func _collisions(parent: Node3D) -> void:
	var body := StaticBody3D.new()
	body.name = "Troncs"
	body.collision_layer = 4
	body.collision_mask = 0
	for t in _trunks:
		var cs := CollisionShape3D.new()
		var cyl := CylinderShape3D.new()
		cyl.radius = t[1]
		cyl.height = 4.0
		cs.shape = cyl
		cs.position = t[0] + Vector3.UP * 1.5
		body.add_child(cs)
	parent.add_child(body)
