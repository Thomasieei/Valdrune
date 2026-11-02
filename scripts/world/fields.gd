class_name Fields
## CHAMPS ÉVOLUTIFS — parcelles de blé et de choux qui passent par 5 états :
## 0 terre labourée → 1 semis → 2 pousse → 3 maturité → 4 récolte (chaume + bottes de foin) → 0 …
## La croissance est continue (shader : taille et couleur par parcelle), sans coût CPU.
## Des paysans travaillent la parcelle selon son état (semer, arroser, récolter).

const PHASE := 40.0          # secondes par état (temps accéléré pour la démo)
static var plots: Array = []  # dictionnaires
static var _time := 0.0

static func build(parent: Node3D) -> void:
	plots.clear()
	var root = Node3D.new()
	root.name = "Champs"
	root.set_script(load("res://scripts/world/fields_runtime.gd"))
	parent.add_child(root)
	var rng = RandomNumberGenerator.new()
	rng.seed = 5
	var g = Geo.new()
	var pw = 20.0
	var pd = 12.0
	var gap = 3.2
	var x = Layout.FIELDS_MIN.x + 2.0
	var idx = 0
	while x + pw < Layout.FIELDS_MAX.x:
		var z = Layout.FIELDS_MIN.y + 2.0
		while z + pd < Layout.FIELDS_MAX.y:
			var c = Vector2(x + pw * 0.5, z + pd * 0.5)
			var ok = c.distance_to(Layout.FARM) > 26.0
			for corner in [Vector2(x, z), Vector2(x + pw, z), Vector2(x, z + pd), Vector2(x + pw, z + pd), c]:
				if Layout.road_dist(corner) < 2.0 or Layout.river_dist(corner) < Layout.RIVER_W + 4.0:
					ok = false
			if ok:
				var kind = "ble" if rng.randf() < 0.68 else "chou"
				var plot = {"c": c, "size": Vector2(pw, pd), "kind": kind, "offset": float(idx % 5) * PHASE + rng.randf() * PHASE * 0.8, "state": -1}
				_ground(g, plot)
				_crops(root, plot, rng)
				plots.append(plot)
				idx += 1
			z += pd + gap
		x += pw + gap
	g.commit(root, "Sillons", 1, false)
	_fences(root)
	_farmers(root)

static func _ground(g: Geo, plot: Dictionary) -> void:
	var c: Vector2 = plot["c"]
	var s: Vector2 = plot["size"]
	var nx = int(s.x / 2.0)
	var nz = int(s.y / 2.0)
	for i in nx:
		for j in nz:
			var a = Vector2(c.x - s.x * 0.5 + i * s.x / nx, c.y - s.y * 0.5 + j * s.y / nz)
			var b = a + Vector2(s.x / nx, s.y / nz)
			var p00 = Vector3(a.x, Terrain.height_at(a.x, a.y) + 0.05, a.y)
			var p10 = Vector3(b.x, Terrain.height_at(b.x, a.y) + 0.05, a.y)
			var p11 = Vector3(b.x, Terrain.height_at(b.x, b.y) + 0.05, b.y)
			var p01 = Vector3(a.x, Terrain.height_at(a.x, b.y) + 0.05, b.y)
			g.quad("sillons", p01, p11, p10, p00, 1)

static func _crops(root: Node3D, plot: Dictionary, rng: RandomNumberGenerator) -> void:
	var c: Vector2 = plot["c"]
	var s: Vector2 = plot["size"]
	var mesh: Mesh = CropMeshes.wheat() if plot["kind"] == "ble" else CropMeshes.cabbage()
	var step = Vector2(0.6, 0.6) if plot["kind"] == "ble" else Vector2(1.1, 1.5)
	var xs = []
	var z = c.y - s.y * 0.5 + step.y * 0.5
	while z < c.y + s.y * 0.5:
		var x = c.x - s.x * 0.5 + step.x * 0.5
		while x < c.x + s.x * 0.5:
			var px = x + rng.randf_range(-0.12, 0.12)
			var pz = z + rng.randf_range(-0.08, 0.08)
			xs.append(Transform3D(Basis(Vector3.UP, rng.randf() * TAU).scaled(Vector3.ONE * rng.randf_range(0.85, 1.15)), Vector3(px, Terrain.height_at(px, pz) + 0.02, pz)))
			x += step.x
		z += step.y
	var mm = MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = mesh
	mm.instance_count = xs.size()
	for i in xs.size():
		mm.set_instance_transform(i, xs[i])
	var mmi = MultiMeshInstance3D.new()
	mmi.multimesh = mm
	var mat: ShaderMaterial = CropMeshes.material().duplicate()
	mat.set_shader_parameter("kind", 0.0 if plot["kind"] == "ble" else 1.0)
	mmi.material_override = mat
	plot["mat"] = mat
	mmi.visibility_range_end = 170.0
	mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mmi)
	plot["mmi"] = mmi
	plot["hay"] = []

static func _fences(root: Node3D) -> void:
	# clôture basse autour de la cour de ferme
	var g = Geo.new()
	var c = Layout.FARM
	var r = 22.0
	var n = 40
	for i in n:
		if i in [9, 10, 29, 30]:   # passages (route est-ouest)
			continue
		var a0 = TAU * i / n
		var a1 = TAU * (i + 1) / n
		var p0 = c + Vector2(cos(a0), sin(a0)) * r
		var p1 = c + Vector2(cos(a1), sin(a1)) * r
		var y0 = Terrain.height_at(p0.x, p0.y)
		var y1 = Terrain.height_at(p1.x, p1.y)
		g.box("bois_sombre", Vector3(p0.x, y0 + 0.6, p0.y), Vector3(0.16, 1.2, 0.16), 0.0, true)
		for hh in [0.5, 0.95]:
			var a3 = Vector3(p0.x, y0 + hh, p0.y)
			var b3 = Vector3(p1.x, y1 + hh, p1.y)
			var seg = b3 - a3
			g.obox("bois", Transform3D(Basis.looking_at(seg.normalized(), Vector3.UP), (a3 + b3) * 0.5), Vector3(0.08, 0.12, seg.length()), false)
	g.commit(root, "Clotures", 2)

static func _farmers(root: Node3D) -> void:
	var specs = [{"outfit": "paysan_h", "beard": true}, {"female": true, "outfit": "paysan_f", "hair": "Hair_Buns"}, {"outfit": "paysan_h", "hair": "Hair_Buzzed", "tint": Color(0.9, 1.0, 0.85)}]
	for i in mini(3, plots.size()):
		var f = Farmer.new()
		f.spec = specs[i]
		f.plot_index = (i * 7) % plots.size()
		root.add_child(f)

## État 0..4 d'une parcelle et progression dans l'état (0..1)
static func state_of(plot: Dictionary, t: float) -> Vector2:
	var cycle = PHASE * 5.0
	var u = fmod(t + plot["offset"], cycle) / PHASE
	return Vector2(floor(u), u - floor(u))
