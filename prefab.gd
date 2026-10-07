extends RefCounted
class_name Prefab
# Bâtiments et chemins « tout faits » pour le mode Construction : une maison entière, une boutique,
# une forge, une fontaine, des dalles de chemin… chacun est un seul objet qu'on pose, tourne et déplace.
# Chemin spécial « @… » enregistré dans le décor de la carte.

const V := "res://assets/village/"
const DG := "res://assets/dungeon/"
const H := "res://assets/hex/"

# [chemin, titre, icône] : ce qui apparaît dans le catalogue
const BUILDINGS := [
	["@house:4:1:plaster", "Petite maison", "it_chest_open"], ["@house:4:2:plaster", "Petite maison · étage", "it_chest_open"],
	["@house:6:1:plaster", "Maison", "it_chest_open"], ["@house:6:2:plaster", "Maison · étage", "it_chest_open"],
	["@house:6:2:brick", "Maison de pierre", "it_chest_open"], ["@house:6:3:brick", "Grande maison", "it_chest_open"],
	["@house:6:3:plaster", "Maison haute", "it_chest_open"], ["@shop:blue", "Boutique (auvent bleu)", "it_coins"],
	["@shop:green", "Boutique (auvent vert)", "it_coins"], ["@shop:red", "Boutique (auvent rouge)", "it_coins"],
	["@shop:purple", "Hôtel des ventes", "it_coins"], ["@forge", "Atelier de forge", "it_hunt"], ["@fountain", "Fontaine", "it_seal"],
	["@tower", "Tour de garde", "it_seal"], ["@stall", "Étal de marché", "it_coins"], ["@bench", "Banc", "it_seal"],
	["@well", "Puits", "it_seal"],
]
const PATHS := [
	["@path:pave:4", "Pavés 4×4", "it_seal"], ["@path:pave:8", "Pavés 8×4 (rue)", "it_seal"], ["@path:dirt:4", "Chemin de terre 4×4", "it_seal"],
	["@path:dirt:8", "Chemin de terre 8×4", "it_seal"], ["@plaza:6", "Place ronde (petite)", "it_seal"], ["@plaza:10", "Place ronde (grande)", "it_seal"],
]

static func title_of(path: String) -> String:
	for arr in [BUILDINGS, PATHS]:
		for e in arr:
			if e[0] == path: return e[1]
	return path

static func make(path: String) -> Node3D:
	var p := path.split(":")
	var root := Node3D.new()
	match p[0]:
		"@house": _house(root, int(p[1]), int(p[2]), p[3], hash(path))
		"@shop": _shop(root, p[1])
		"@forge": _forge(root)
		"@fountain": _fountain(root)
		"@tower": _tower(root)
		"@stall": _stall(root)
		"@bench": _bench(root)
		"@well": _well(root)
		"@path": root = PathTile.new(); (root as PathTile).setup(p[1], float(p[2]))
		"@plaza": root = PathTile.new(); (root as PathTile).setup("plaza", float(p[1]))
		"@field": root = FieldTile.new(); (root as FieldTile).setup(p[1], float(p[2]) if p.size() > 2 else 10.0, float(p[3]) if p.size() > 3 else 8.0)
		"@road": root = RoadTile.new(); (root as RoadTile).setup(p[1], float(p[2]), p[3] if p.size() > 3 else "")
	return root

# Champ cultivé : terre labourée en sillons + rangées de cultures, qui épousent le terrain
class FieldTile extends Node3D:
	var crop := "wheat"
	var w := 10.0
	var d := 8.0
	var soil: MeshInstance3D
	var plants: Node3D
	func setup(c: String, ww: float, dd: float) -> void:
		crop = c; w = ww; d = dd
		soil = MeshInstance3D.new(); add_child(soil)
		var m := StandardMaterial3D.new(); m.albedo_color = Color("#7a5634"); m.roughness = 1.0; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		soil.material_override = m; soil.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		plants = Node3D.new(); add_child(plants)
		set_meta("aabb", AABB(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w, 0.6, d))); set_meta("flat", true)
	func preview() -> void: conform(null)
	func conform(world: Node) -> void:
		var gx: Transform3D = global_transform if is_inside_tree() else transform
		var inv := gx.affine_inverse()
		var hy := func(lx: float, lz: float) -> float:
			if world == null: return 0.06
			var wp := gx * Vector3(lx, 0, lz)
			return (inv * Vector3(wp.x, world.ground_y(wp.x, wp.z) + 0.06, wp.z)).y
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var nx := int(w); var nz := int(d * 2.0)
		for i in nx:
			for j in nz:
				var x0 := -w * 0.5 + i * w / nx; var x1 := x0 + w / nx; var z0 := -d * 0.5 + j * d / nz; var z1 := z0 + d / nz
				var ridge := 0.08 if j % 2 == 0 else 0.0
				var q := [Vector3(x0, hy.call(x0, z0) + ridge, z0), Vector3(x1, hy.call(x1, z0) + ridge, z0), Vector3(x1, hy.call(x1, z1), z1), Vector3(x0, hy.call(x0, z1), z1)]
				var col := Color("#8a6040") if j % 2 == 0 else Color("#6a4628")
				for k in [0, 1, 2, 0, 2, 3]:
					st.set_color(col); st.set_normal(Vector3.UP); st.add_vertex(q[k])
		soil.mesh = st.commit()
		(soil.material_override as StandardMaterial3D).vertex_color_use_as_albedo = true
		for c in plants.get_children(): c.queue_free()
		var path := "res://assets/qnature/Grass_Wispy_Tall.gltf"
		var sc := 1.1; var tint := Color("#e8c060")
		match crop:
			"cabbage": path = "res://assets/food/cabbage.glb"; sc = 2.4; tint = Color(1, 1, 1)
			"carrot": path = "res://assets/food/carrotWithStem.glb"; sc = 2.4; tint = Color(1, 1, 1)
			"corn": path = "res://assets/food/cornWithLeafs.glb"; sc = 3.0; tint = Color(1, 1, 1)
		var xfs: Array = []
		var step := 0.7 if crop == "wheat" else 1.1
		var z := -d * 0.5 + 0.5
		var rr := RandomNumberGenerator.new(); rr.seed = int(w * 13 + d * 7)
		while z < d * 0.5 - 0.3:
			var x := -w * 0.5 + 0.4
			while x < w * 0.5 - 0.3:
				xfs.append(Transform3D(Basis(Vector3.UP, rr.randf() * TAU).scaled(Vector3.ONE * sc * rr.randf_range(0.85, 1.15)), Vector3(x + rr.randf_range(-0.1, 0.1), hy.call(x, z) + 0.05, z)))
				x += step
			z += 1.0
		for part in Prefab._parts(path):
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[0]; mm.instance_count = xfs.size()
			for i in xfs.size(): mm.set_instance_transform(i, (xfs[i] as Transform3D) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			if path.contains("/food/"): mmi.material_override = Crops.pix_mat()
			elif part[2]: mmi.material_override = part[2]
			if crop == "wheat":
				var src = mmi.material_override if mmi.material_override else (part[0] as Mesh).surface_get_material(0)
				if src is StandardMaterial3D:
					var m2: StandardMaterial3D = src.duplicate(); m2.albedo_color = tint; mmi.material_override = m2
			plants.add_child(mmi)

# tracé « @road:kind:largeur:x,z;x,z;… » (points relatifs au centre de l'objet)
static func road_path(kind: String, w: float, pts: Array) -> String:
	var sp: PackedStringArray = []
	for q: Vector2 in pts: sp.append("%s,%s" % [snappedf(q.x, 0.1), snappedf(q.y, 0.1)])
	return "@road:%s:%s:%s" % [kind, snappedf(w, 0.1), ";".join(sp)]

# Chemin libre dessiné au doigt : un ruban qui épouse le terrain
class RoadTile extends Node3D:
	var kind := "pave"
	var w := 3.0
	var pts: Array = []
	var mi: MeshInstance3D
	func setup(k: String, width: float, enc: String) -> void:
		kind = k; w = width
		for e in enc.split(";", false):
			var xy := e.split(",")
			if xy.size() == 2: pts.append(Vector2(float(xy[0]), float(xy[1])))
		# segments longs redécoupés : le ruban suit les bosses au lieu de passer sous la colline
		var dense: Array = []
		for i in pts.size():
			if i > 0:
				var a: Vector2 = pts[i - 1]; var b: Vector2 = pts[i]
				var n := int(a.distance_to(b) / 1.5)
				for kk in range(1, n): dense.append(a.lerp(b, float(kk) / n))
			dense.append(pts[i])
		pts = dense
		mi = MeshInstance3D.new(); add_child(mi)
		var m := StandardMaterial3D.new()
		m.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png")
		m.albedo_color = Color(0.82, 0.78, 0.72) if k == "pave" else Color("#a0805a")
		if k == "dirt": m.uv1_scale = Vector3(0.35, 0.35, 1)
		m.roughness = 1.0; m.texture_repeat = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var bb := AABB(Vector3.ZERO, Vector3.ZERO); var first := true
		for q: Vector2 in pts:
			var a := AABB(Vector3(q.x - w * 0.5, 0, q.y - w * 0.5), Vector3(w, 0.2, w))
			bb = a if first else bb.merge(a); first = false
		set_meta("aabb", bb); set_meta("flat", true); set_meta("road", true)
	func preview() -> void: conform(null)
	func conform(world: Node) -> void:
		if pts.size() < 2: return
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var gx: Transform3D = global_transform if is_inside_tree() else transform
		var inv := gx.affine_inverse()
		var CROSS := 4
		var rows: Array = []
		var L := 0.0
		for i in pts.size():
			var a: Vector2 = pts[max(0, i - 1)]; var b: Vector2 = pts[min(pts.size() - 1, i + 1)]
			var t := (b - a).normalized(); var n := Vector2(-t.y, t.x)
			if i > 0: L += (pts[i] - pts[i - 1]).length()
			var ww := w * (1.0 + (0.12 * sin(L * 1.7) + 0.08 * sin(L * 0.6) if kind == "dirt" else 0.0))
			var row: Array = []
			for j in CROSS + 1:
				var f := float(j) / CROSS - 0.5
				var lp: Vector2 = pts[i] + n * f * ww
				var v := Vector3(lp.x, 0.07, lp.y)
				if world != null:
					var wp := gx * Vector3(lp.x, 0, lp.y)
					v = inv * Vector3(wp.x, world.ground_y(wp.x, wp.z) + 0.07 + 0.04 * (1.0 - abs(f) * 2.0), wp.z)
				row.append([v, Vector2(L * 0.5, f * ww * 0.5)])
			rows.append(row)
		for i in rows.size() - 1:
			for j in CROSS:
				var q := [rows[i][j], rows[i][j + 1], rows[i + 1][j + 1], rows[i + 1][j]]
				for k in [0, 2, 1, 0, 3, 2]:
					st.set_normal(Vector3.UP); st.set_uv(q[k][1]); st.add_vertex(q[k][0])
		mi.mesh = st.commit()

# ——— outils ———
static var _mesh_cache := {}     # chemin → [[mesh, transform local, material]]
static func _parts(path: String) -> Array:
	if _mesh_cache.has(path): return _mesh_cache[path]
	var src: Node3D = load(path).instantiate()
	var out: Array = []
	for mi in src.find_children("*", "MeshInstance3D", true, false):
		var t := Transform3D.IDENTITY; var nd: Node = mi
		while nd != null and nd != src:
			t = (nd as Node3D).transform * t; nd = nd.get_parent()
		out.append([(mi as MeshInstance3D).mesh, t, (mi as MeshInstance3D).material_override])
	src.free()
	_mesh_cache[path] = out
	return out

static func _mm(root: Node3D, lists: Dictionary) -> void:
	for path in lists:
		var arr: Array = lists[path]
		for part in _parts(path):
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = part[0]
			mm.instance_count = arr.size()
			for i in arr.size(): mm.set_instance_transform(i, (arr[i] as Transform3D) * (part[1] as Transform3D))
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
			if part[2]: mmi.material_override = part[2]
			root.add_child(mmi)

static func _box(root: Node3D, sz: Vector3, pos: Vector3, mat: Material) -> void:
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = sz; mi.mesh = bm; mi.position = pos; mi.material_override = mat; root.add_child(mi)

static func _cyl(root: Node3D, rt: float, rb: float, h: float, pos: Vector3, mat: Material, seg := 16) -> void:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = rt; cm.bottom_radius = rb; cm.height = h; cm.radial_segments = seg; mi.mesh = cm; mi.position = pos; mi.material_override = mat; root.add_child(mi)

static func _model(root: Node3D, path: String, pos: Vector3, rot := 0.0, sc := 1.0) -> void:
	var n: Node3D = load(path).instantiate(); n.position = pos; n.rotation.y = rot; n.scale = Vector3.ONE * sc; root.add_child(n)

static func _mat(tex: String, col: Color, k := 0.5) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = load(tex); m.albedo_color = col; m.roughness = 0.95
	m.uv1_triplanar = true; m.uv1_world_triplanar = true; m.uv1_scale = Vector3(k, k, k); return m

static func _info(root: Node3D, size: Vector3) -> void:
	root.set_meta("aabb", AABB(Vector3(-size.x * 0.5, 0, -size.z * 0.5), size)); root.set_meta("box", size)

# ——— maison complète (mêmes pièces que les villes du jeu) ———
static func _house(root: Node3D, w: int, floors: int, style: String, seed_v: int) -> void:
	var D := 8.0; var W := float(w)
	var L := {}
	var put := func(path: String, xf: Transform3D) -> void:
		if not L.has(path): L[path] = []
		L[path].append(xf)
	var X := func(lx: float, ly: float, lz: float, r: float) -> Transform3D: return Transform3D(Basis(Vector3.UP, r), Vector3(lx, ly, lz))
	var hr := RandomNumberGenerator.new(); hr.seed = seed_v
	var stone_base := floors >= 2 or style == "brick"
	var thin := hr.randf() < 0.4
	var piece := func(f: int, kind: String) -> String:
		var wl := "Wall_Plaster" if style == "plaster" else "Wall_UnevenBrick"
		if f == 0 and stone_base: wl = "Wall_UnevenBrick"
		elif f >= 1: wl = "Wall_Plaster"
		if kind == "_Window": return wl + ("_Window_Thin_Round" if thin else "_Window_Wide_Round")
		if kind == "_Straight" and wl == "Wall_Plaster" and f >= 1 and hr.randf() < 0.55: return "Wall_Plaster_WoodGrid"
		return wl + kind
	var window := func(xf: Transform3D) -> void:
		put.call(V + ("Window_Thin_Round1.gltf" if thin else "Window_Wide_Round1.gltf"), xf)
		put.call(V + ("WindowShutters_Thin_Round_Open.gltf" if thin else "WindowShutters_Wide_Round_Open.gltf"), xf)
	# soubassement de pierre sous le rez-de-chaussée (rattrape les pentes)
	for i in int(W / 2):
		var lx := -W / 2 + 1 + i * 2
		put.call(V + "Wall_UnevenBrick_Straight.gltf", X.call(lx, -3.12, D / 2, 0.0)); put.call(V + "Wall_UnevenBrick_Straight.gltf", X.call(lx, -3.12, -D / 2, PI))
	for i in int(D / 2):
		var lz := -D / 2 + 1 + i * 2
		put.call(V + "Wall_UnevenBrick_Straight.gltf", X.call(W / 2, -3.12, lz, PI * 0.5)); put.call(V + "Wall_UnevenBrick_Straight.gltf", X.call(-W / 2, -3.12, lz, -PI * 0.5))
	for f in floors:
		var y := f * 3.12
		for i in int(W / 2):
			var lx := -W / 2 + 1 + i * 2
			var kind := "_Window"
			if f == 0 and i == int(W / 4): kind = "_Door_Round"
			elif f == 0 and i % 2 == 1: kind = "_Straight"
			var xf: Transform3D = X.call(lx, y, D / 2, 0.0)
			put.call(V + piece.call(f, kind) + ".gltf", xf)
			if kind == "_Window": window.call(xf)
			if kind == "_Door_Round":
				put.call(V + ("DoorFrame_Round_Brick.gltf" if stone_base else "DoorFrame_Round_WoodDark.gltf"), xf)
				put.call(V + "Door_1_Round.gltf", X.call(lx - 0.51, y, D / 2 - 0.12, 0.0))
			var bk: String = piece.call(f, "_Straight" if i % 2 == 0 else "_Window")
			var bxf: Transform3D = X.call(lx, y, -D / 2, PI)
			put.call(V + bk + ".gltf", bxf)
			if bk.contains("Window"): window.call(bxf)
		for i in int(D / 2):
			var lz := -D / 2 + 1 + i * 2
			var k2 := "_Window" if (i + f) % 2 == 1 else "_Straight"
			for sd: float in [1.0, -1.0]:
				var sxf: Transform3D = X.call(sd * W / 2, y, lz, sd * PI * 0.5)
				put.call(V + piece.call(f, k2) + ".gltf", sxf)
				if k2 == "_Window": window.call(sxf)
		for cx in [-W / 2, W / 2]:
			for cz in [-D / 2, D / 2]: put.call(V + ("Corner_Exterior_Brick.gltf" if f == 0 and stone_base else "Corner_Exterior_Wood.gltf"), X.call(cx, y, cz, 0.0))
	var ry := floors * 3.12
	put.call(V + "Roof_RoundTiles_%dx8.gltf" % w, X.call(0, ry, 0, 0.0))
	put.call(V + "Roof_Front_Brick%d.gltf" % w, X.call(0, ry, D / 2, 0.0))
	put.call(V + "Roof_Front_Brick%d.gltf" % w, X.call(0, ry, -D / 2, PI))
	put.call(V + "Prop_Chimney.gltf", X.call(W / 2 - 0.9, ry + 0.6, -D / 4, 0.0))
	_mm(root, L)
	_info(root, Vector3(W + 0.4, ry + 2.5, D + 0.4))

# ——— boutique : maison à étage + auvent coloré, tonneaux et caisses ———
static func _shop(root: Node3D, col: String) -> void:
	_house(root, 6, 2, "plaster", hash(col))
	var c1: Color = {"blue": Color("#2f6fb0"), "green": Color("#3c7a3a"), "red": Color("#b0352a"), "purple": Color("#7a2a6a")}.get(col, Color("#b0352a"))
	_awning(root, Vector3(-1.0, 0, 5.4), 4.4, 2.2, c1, Color("#f0e6d0"))
	_model(root, H + "barrel.gltf", Vector3(-3.5, 0, 5.0), 0.0, 3.0)
	_model(root, H + "crate_A_big.gltf", Vector3(1.6, 0, 5.0), 0.3, 3.0)
	_info(root, Vector3(6.4, 8.8, 8.4))

static func _awning(root: Node3D, c: Vector3, w: float, d: float, c1: Color, c2: Color, h := 2.6) -> void:
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#4a3322")
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			_cyl(root, 0.07, 0.08, h + (0.3 if sz < 0 else 0.0), c + Vector3(sx * (w * 0.5 - 0.15), (h + (0.3 if sz < 0 else 0.0)) * 0.5, sz * (d * 0.5 - 0.15)), wood, 8)
	for i in 6:
		var m := StandardMaterial3D.new(); m.albedo_color = c1 if i % 2 == 0 else c2; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(w / 6.0, 0.05, d + 0.3); mi.mesh = bm
		mi.position = c + Vector3(-w * 0.5 + (i + 0.5) * w / 6.0, h + 0.15, 0); mi.rotation.x = -0.12; mi.material_override = m; root.add_child(mi)

# ——— atelier de forge ouvert : dallage, charpente, foyer, enclume ———
static func _forge(root: Node3D) -> void:
	var wood := _mat("res://assets/village/T_WoodTrim_BaseColor.png", Color("#a07a58"), 0.8)
	var tile := _mat("res://assets/village/T_RoundTiles_BaseColor.png", Color.WHITE, 0.5)
	var stone := _mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color("#9a8c7c"), 0.9)
	var w := 5.0; var d := 3.6; var hh := 2.9
	for sx: float in [-1.0, 1.0]:
		for sz: float in [-1.0, 1.0]:
			var ph: float = hh + (0.45 if sz < 0 else 0.0)
			_box(root, Vector3(0.24, ph, 0.24), Vector3(sx * (w * 0.5 - 0.15), ph * 0.5, sz * (d * 0.5 - 0.15)), wood)
	var roof := MeshInstance3D.new(); var rb := BoxMesh.new(); rb.size = Vector3(w + 0.7, 0.14, d + 0.8); roof.mesh = rb; roof.position = Vector3(0, hh + 0.33, 0); roof.rotation.x = atan2(0.45, d); roof.material_override = tile; root.add_child(roof)
	_cyl(root, 0.6, 0.7, 0.8, Vector3(1.4, 0.4, -0.6), stone, 10)
	var coal := StandardMaterial3D.new(); coal.albedo_color = Color("#ff7a20"); coal.emission_enabled = true; coal.emission = Color("#ff5a10"); coal.emission_energy_multiplier = 2.5
	_cyl(root, 0.45, 0.45, 0.06, Vector3(1.4, 0.81, -0.6), coal, 10)
	var fire := OmniLight3D.new(); fire.light_color = Color("#ff7a20"); fire.light_energy = 2.4; fire.omni_range = 3.4; fire.position = Vector3(1.4, 1.3, -0.6); root.add_child(fire)
	var steel := StandardMaterial3D.new(); steel.albedo_color = Color("#3a3d44"); steel.metallic = 0.7; steel.roughness = 0.45
	_box(root, Vector3(0.45, 0.5, 0.45), Vector3(-0.8, 0.25, 0.3), steel); _box(root, Vector3(0.95, 0.2, 0.38), Vector3(-0.8, 0.6, 0.3), steel)
	_model(root, H + "weaponrack.gltf", Vector3(-2.0, 0, -1.2), 0.0, 4.2)
	_model(root, DG + "barrel_large.gltf", Vector3(2.2, 0, 1.0), 0.0, 0.42)
	_info(root, Vector3(w + 0.6, 3.6, d + 0.6))

static func _fountain(root: Node3D) -> void:
	var stone := _mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color("#d8d2c4"), 1.0)
	var water := StandardMaterial3D.new(); water.albedo_color = Color(0.25, 0.6, 0.85, 0.85); water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; water.roughness = 0.08
	_cyl(root, 2.6, 2.75, 0.3, Vector3(0, 0.05, 0), stone, 32); _cyl(root, 2.25, 2.3, 0.7, Vector3(0, 0.45, 0), stone, 32)
	_cyl(root, 2.05, 2.05, 0.06, Vector3(0, 0.78, 0), water, 32); _cyl(root, 0.32, 0.42, 1.7, Vector3(0, 1.2, 0), stone)
	_cyl(root, 0.95, 0.35, 0.3, Vector3(0, 2.1, 0), stone); _cyl(root, 0.85, 0.85, 0.05, Vector3(0, 2.24, 0), water)
	root.set_meta("aabb", AABB(Vector3(-2.75, 0, -2.75), Vector3(5.5, 2.6, 5.5))); root.set_meta("radius", 2.6)

static func _tower(root: Node3D) -> void:
	var mat := _mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color("#d4cfc4"), 0.45)
	var cap := _mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color("#b8b2a8"), 0.9)
	_cyl(root, 1.45, 1.6, 5.2, Vector3(0, 1.9, 0), mat); _cyl(root, 1.75, 1.5, 0.45, Vector3(0, 4.7, 0), cap)
	for k in 8:
		var a := TAU * k / 8.0
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.55, 0.55, 0.35); mi.mesh = bm
		mi.position = Vector3(cos(a) * 1.55, 5.2, sin(a) * 1.55); mi.rotation.y = -a + PI * 0.5; mi.material_override = cap; root.add_child(mi)
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color("#3d5f9a")
	_cyl(root, 0.0, 1.85, 2.4, Vector3(0, 6.4, 0), rm, 12)
	root.set_meta("aabb", AABB(Vector3(-1.8, 0, -1.8), Vector3(3.6, 7.6, 3.6))); root.set_meta("radius", 1.55)

static func _stall(root: Node3D) -> void:
	_model(root, DG + "table_medium_decorated_A.gltf", Vector3.ZERO, 0.0, 0.85)
	_awning(root, Vector3(0, 0, -0.3), 3.6, 2.6, Color("#b0352a"), Color("#f0e6d0"), 2.4)
	_model(root, H + "sack.gltf", Vector3(1.6, 0, 0.4), 0.0, 2.6)
	_info(root, Vector3(3.0, 2.8, 2.0))

static func _bench(root: Node3D) -> void:
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#7a5232")
	var st := StandardMaterial3D.new(); st.albedo_color = Color("#a8a296")
	_box(root, Vector3(1.8, 0.1, 0.5), Vector3(0, 0.48, 0), wood); _box(root, Vector3(0.25, 0.45, 0.45), Vector3(-0.7, 0.22, 0), st); _box(root, Vector3(0.25, 0.45, 0.45), Vector3(0.7, 0.22, 0), st)
	_info(root, Vector3(1.8, 0.6, 0.5))

static func _well(root: Node3D) -> void:
	var stone := _mat("res://assets/village/T_UnevenBrick_BaseColor.png", Color("#c8c0b0"), 1.0)
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#5a3d26")
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color("#8a3a2e")
	_cyl(root, 1.0, 1.05, 0.9, Vector3(0, 0.45, 0), stone, 20)
	for sx: float in [-1.0, 1.0]: _box(root, Vector3(0.15, 2.2, 0.15), Vector3(sx * 0.85, 1.1, 0), wood)
	_box(root, Vector3(1.9, 0.12, 0.12), Vector3(0, 2.0, 0), wood)
	_cyl(root, 0.0, 1.3, 0.8, Vector3(0, 2.55, 0), rm, 4)
	root.set_meta("aabb", AABB(Vector3(-1.1, 0, -1.1), Vector3(2.2, 3.0, 2.2))); root.set_meta("radius", 1.0)

# ——— dalle de chemin qui épouse le relief ———
class PathTile extends Node3D:
	var kind := "pave"
	var size := 4.0
	var mi: MeshInstance3D
	func setup(k: String, s: float) -> void:
		kind = k; size = s
		mi = MeshInstance3D.new(); add_child(mi)
		var m := StandardMaterial3D.new(); m.albedo_texture = load("res://assets/village/T_UnevenBrick_BaseColor.png" if k != "plaza" else "res://assets/village/T_Brick_BaseColor.png")
		m.albedo_color = Color(0.82, 0.78, 0.72) if k != "dirt" else Color("#a0805a"); m.roughness = 1.0; m.uv1_scale = Vector3(1, 1, 1) if k != "dirt" else Vector3(0.35, 0.35, 1)
		m.texture_repeat = true; m.cull_mode = BaseMaterial3D.CULL_DISABLED
		mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var w := size if k != "plaza" else size * 2.0
		var d := 4.0 if k != "plaza" else size * 2.0
		set_meta("aabb", AABB(Vector3(-w * 0.5, 0, -d * 0.5), Vector3(w, 0.2, d)))
		set_meta("flat", true)
	func preview() -> void:
		if kind == "plaza":
			var cm := CylinderMesh.new(); cm.top_radius = size; cm.bottom_radius = size; cm.height = 0.1; mi.mesh = cm
		else:
			var bm := BoxMesh.new(); bm.size = Vector3(size, 0.1, 4.0); mi.mesh = bm
	func conform(world: Node) -> void:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var gp: Vector3 = global_position; var b := Basis(Vector3.UP, rotation.y)
		var y0: float = gp.y
		var hpt := func(lx: float, lz: float) -> Vector3:
			var wp: Vector3 = gp + b * Vector3(lx, 0, lz)
			return Vector3(lx, world.ground_y(wp.x, wp.z) - y0 + 0.07, lz)
		if kind == "plaza":
			var seg := 32; var rings := 4
			for i in seg:
				var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
				for r in rings:
					var f0 := size * float(r) / rings; var f1 := size * float(r + 1) / rings
					var q := [hpt.call(cos(a0) * f0, sin(a0) * f0), hpt.call(cos(a1) * f0, sin(a1) * f0), hpt.call(cos(a1) * f1, sin(a1) * f1), hpt.call(cos(a0) * f1, sin(a0) * f1)]
					for k in [0, 2, 1, 0, 3, 2]:
						var v: Vector3 = q[k]; st.set_normal(Vector3.UP); st.set_uv(Vector2(v.x, v.z) * 0.5); st.add_vertex(v)
		else:
			var w := size; var d := 4.0; var n := int(w); var m := 4
			for i in n:
				for j in m:
					var x0 := -w * 0.5 + i * w / n; var x1 := x0 + w / n; var z0 := -d * 0.5 + j * d / m; var z1 := z0 + d / m
					var q := [hpt.call(x0, z0), hpt.call(x1, z0), hpt.call(x1, z1), hpt.call(x0, z1)]
					for k in [0, 1, 2, 0, 2, 3]:
						var v: Vector3 = q[k]; st.set_normal(Vector3.UP); st.set_uv(Vector2(v.x, v.z) * 0.5); st.add_vertex(v)
		mi.mesh = st.commit()
