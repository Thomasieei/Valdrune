extends Node3D
## Village de départ, généré par code à partir du kit modulaire Kenney (murs) + KayKit Forest (nature).
## Tout est instancié en MultiMesh (1 draw call par type de pièce) et les collisions sont des boîtes simples.
##
## Plan (mètres, nord = -Z) :
##   rue principale  x ∈ [-6, 6]      trottoirs x ∈ [±6, ±9.2]      façades à |x| = 9.2
##   îlot sud        z ∈ [19.2, 48]   (3 maisons par côté)
##   rue transversale 1  z ∈ [9.6, 19.2]
##   place du marché z ∈ [-28.8, 9.6], x ∈ [-22.4, 22.4] — taverne à l'ouest, forge à l'est
##   rue transversale 2  z ∈ [-38.4, -28.8]
##   îlot nord       z ∈ [-67.2, -38.4]
##   parvis + mairie au bout de l'axe (z ≈ -70 … -80), falaises derrière

const S := 3.2                 # 1 case du kit = 3,2 m (étage = 3,2 m)
const ROAD := 6.0
const WALK := 9.2
const DEPTH := 2               # profondeur des maisons (cases)

var mm := {}                   # nom -> [mesh, xform_local, Array[Transform3D]]
var col_boxes: Array = []      # [centre, taille, rot_y]
var roof_x: Array = []         # [Transform3D, Color]
var gable_x: Array = []
var lamps: Array = []
var walk_paths: Array = []     # chemins des habitants (PackedVector3Array)
var spots: Array = []          # points où des habitants regardent la rue
var rng := RandomNumberGenerator.new()
var plaster := Color(0.93, 0.88, 0.78)
const ROOFS := [Color(0.72, 0.27, 0.22), Color(0.28, 0.55, 0.5), Color(0.5, 0.32, 0.22), Color(0.36, 0.4, 0.55), Color(0.62, 0.38, 0.2)]

func build() -> void:
	rng.seed = 7
	_ground()
	# --- îlots de maisons le long de la rue principale ---
	for side in [-1, 1]:
		_row(side, 48.0, 3)
		_row(side, -38.4, 3)
	# --- place du marché ---
	_tavern()
	_forge()
	_plaza_houses()
	_market()
	_townhall()
	_back_lanes()
	_street_props()
	_nature()
	_cliffs()
	_finish()

# ================= pièces =================
func _piece(n: String) -> Array:
	if mm.has(n): return mm[n]
	var path := "res://assets/town/%s.glb" % n
	if not ResourceLoader.exists(path): path = "res://assets/forest/%s.gltf" % n
	var sc: Node3D = (load(path) as PackedScene).instantiate()
	var mi: MeshInstance3D = sc.find_children("*", "MeshInstance3D", true, false)[0]
	var xf := Transform3D()
	var n2: Node = mi
	while n2 != sc: xf = (n2 as Node3D).transform * xf; n2 = n2.get_parent()
	mm[n] = [mi.mesh, xf, []]
	sc.free()
	return mm[n]

func put(n: String, pos: Vector3, rot_y := 0.0, sc := S) -> void:
	var p := _piece(n)
	var t := Transform3D(Basis(Vector3.UP, rot_y).scaled(Vector3.ONE * sc), pos)
	p[2].append(t * p[1])

func box(c: Vector3, size: Vector3, rot := 0.0) -> void: col_boxes.append([c, size, rot])

## mur sur le bord d'une case : n = normale sortante (monde)
func wall(n: String, cell_center: Vector3, normal: Vector3, y: float) -> void:
	put(n, Vector3(cell_center.x, y, cell_center.z), atan2(-normal.z, normal.x))

# ================= maisons =================
## Maison : origine = coin façade gauche, `fw` = direction le long de la façade, `out` = normale de façade (vers la rue).
var map_houses: Array = []     # [centre, taille, angle]
func house(o: Vector3, fw: Vector3, out: Vector3, w: int, d: int, floors: int, kind := "home", ends := [true, true]) -> void:
	var back := -out
	var stone := rng.randf() < 0.5
	var door_i := rng.randi_range(0, w - 1) if kind == "home" else w / 2
	for f in floors:
		var y := f * S
		var timber := f > 0 and (stone or rng.randf() < 0.7)
		var pre := "wall-wood" if timber else "wall"
		for i in w:
			for j in d:
				var cc := o + fw * (i + 0.5) * S + back * (j + 0.5) * S
				if j == 0:  # façade
					var n := pre + "-window-shutters"
					if f == 0 and i == door_i: n = "wall-doorway-square" if kind != "home" else "wall-door"
					elif f == 0: n = "wall-window-glass" if kind == "tavern" else (pre + ("-window-shutters" if (i + floors) % 2 == 0 else "-window-small"))
					elif (i + f) % 3 == 1: n = pre + "-detail-cross" if timber else pre + "-window-glass"
					wall(n, cc, out, y)
				if j == d - 1: wall(pre + ("-window-small" if (i + f) % 2 == 0 else ""), cc, back, y) if pre == "wall" else wall(pre + ("-window-small" if (i + f) % 2 == 0 else "-detail-diagonal"), cc, back, y)
				if i == 0 and ends[0]: wall(pre + ("-window-shutters" if j == 0 and f > 0 else ""), cc, -fw, y) if pre == "wall" else wall(pre + ("-window-shutters" if j == 0 else "-detail-cross"), cc, -fw, y)
				if i == w - 1 and ends[1]: wall(pre + ("-window-shutters" if j == 0 and f > 0 else ""), cc, fw, y) if pre == "wall" else wall(pre + ("-window-shutters" if j == 0 else "-detail-cross"), cc, fw, y)
	# toit à deux pans, faîtage parallèle à la façade
	var ctr := o + fw * w * S * 0.5 + back * d * S * 0.5
	var top := floors * S
	var rh := d * S * (0.55 if kind == "home" else 0.62)
	var ang := atan2(-fw.z, fw.x)
	var b := Basis(Vector3.UP, ang)
	var col: Color = ROOFS[rng.randi_range(0, ROOFS.size() - 1)]
	if kind == "hall": col = Color(0.3, 0.33, 0.45)
	if kind == "tavern": col = Color(0.62, 0.24, 0.2)
	roof_x.append([Transform3D(b.scaled(Vector3(w * S + 0.5, rh, d * S + 1.0)), ctr + Vector3.UP * top), col])
	for e in [0, 1]:
		if ends[e] or kind != "home":
			var ex := o + fw * (w * S if e == 1 else 0.0) + back * d * S * 0.5
			gable_x.append([Transform3D(b.scaled(Vector3(1, rh, d * S)), ex + Vector3.UP * top), plaster])
	if rng.randf() < 0.6 or kind != "home":
		put("chimney", ctr + fw * (rng.randf_range(-0.3, 0.3) * w * S) + back * d * S * 0.15 + Vector3.UP * (top + rh * 0.5), ang, S * 0.9)
	map_houses.append([Vector2(ctr.x, ctr.z), Vector2(w * S, d * S), ang])
	# collision : un bloc par maison
	box(ctr + Vector3.UP * top * 0.5, Vector3(w * S, top + rh, d * S), ang)

## Rangée de 3 maisons collées d'un côté de la rue, du sud (z0) vers le nord
func _row(side: int, z0: float, n: int) -> void:
	var z := z0
	for k in n:
		var w := 3
		var floors := 2 if rng.randf() < 0.65 else 3
		var o := Vector3(side * WALK, 0, z) if side > 0 else Vector3(side * WALK, 0, z - w * S)
		var fw := Vector3(0, 0, -1) if side > 0 else Vector3(0, 0, 1)
		house(o, fw, Vector3(-side, 0, 0), w, DEPTH, floors, "home")
		if rng.randf() < 0.5: put("banner-red" if side > 0 else "banner-green", Vector3(side * (WALK - 0.02), S * 1.05, z - S * 1.5), atan2(0, -side), S * 0.9)
		# habitants qui regardent la rue
		spots.append(Vector3(side * (WALK - 1.2), 0.15, z - S * 1.5 + rng.randf_range(-2, 2)))
		z -= w * S

# ================= place, taverne, forge, mairie =================
func _tavern() -> void:
	# façade à x = -22.4 tournée vers l'est (+X), 4 cases de large, 3 de profondeur
	var o := Vector3(-22.4, 0, -3.2)
	house(o, Vector3(0, 0, -1), Vector3(1, 0, 0), 4, 3, 2, "tavern")
	put("overhang", Vector3(-22.4 + 0.2, S * 0.75, -3.2 - 2 * S), PI, S)
	put("overhang", Vector3(-22.4 + 0.2, S * 0.75, -3.2 - 2 * S - S), PI, S)
	for k in 3:
		var z := -4.5 - k * 3.6
		put("stall-bench", Vector3(-19.0, 0.15, z), PI / 2, S * 0.9)
		put("stall-stool", Vector3(-17.4, 0.15, z + 0.8), 0, S * 0.8)
		put("stall-stool", Vector3(-17.4, 0.15, z - 0.8), 0, S * 0.8)
	put("lantern", Vector3(-21.2, 0, -2.2), 0, 1.7); put("lantern", Vector3(-21.2, 0, -16.6), 0, 1.7)
	_sign(Vector3(-22.0, S * 1.25, -9.6), Vector3(1, 0, 0), "TAVERNE DU SANGLIER")

func _forge() -> void:
	var o := Vector3(22.4, 0, -16.0)
	house(o, Vector3(0, 0, 1), Vector3(-1, 0, 0), 4, 3, 2, "forge")
	for k in 4: put("pillar-wood", Vector3(19.4, 0, -15.4 + k * 3.85), 0, S * 1.05)
	put("roof-flat", Vector3(20.8, S * 1.0, -12.8), PI, S); put("roof-flat", Vector3(20.8, S * 1.0, -9.6), PI, S); put("roof-flat", Vector3(20.8, S * 1.0, -6.4), PI, S)
	put("cart-high", Vector3(17.5, 0.15, -18.5), 0.4, S * 0.9)
	box(Vector3(20.8, S * 0.5, -9.6), Vector3(2.8, S, 0.4))
	_sign(Vector3(22.0, S * 1.25, -9.6), Vector3(-1, 0, 0), "FORGE & ARMURERIE")

func _plaza_houses() -> void:
	# maisons qui ferment la place au nord-ouest / sud-ouest / nord-est / sud-est
	house(Vector3(-22.4, 0, 9.6), Vector3(0, 0, -1), Vector3(1, 0, 0), 2, 3, 2)
	house(Vector3(-22.4, 0, -16.0), Vector3(0, 0, -1), Vector3(1, 0, 0), 2, 3, 3)
	house(Vector3(22.4, 0, -28.8), Vector3(0, 0, 1), Vector3(-1, 0, 0), 2, 3, 3)
	house(Vector3(22.4, 0, 3.2), Vector3(0, 0, 1), Vector3(-1, 0, 0), 2, 3, 2)

func _market() -> void:
	put("fountain-round-detail", Vector3(0, 0.0, -9.6), 0, 3.0)
	box(Vector3(0, 0.6, -9.6), Vector3(5.6, 1.2, 5.6))
	var stalls := ["stall-red", "stall-green", "stall", "stall-red", "stall-green", "stall"]
	for k in 6:
		var row := -1 if k < 3 else 1
		var z := 3.0 - (k % 3) * 6.4 - 3.2
		var x := row * 15.5
		put(stalls[k], Vector3(x, 0.15, z), PI / 2 if row < 0 else -PI / 2, S * 1.1)
		box(Vector3(x, 0.8, z), Vector3(2.4, 1.6, 3.4))
		put("cart", Vector3(x + row * -2.6, 0.15, z + 1.6), rng.randf() * TAU, S * 0.7) if k % 2 == 0 else null
	for p in [Vector3(-8, 0, 3), Vector3(8, 0, 3), Vector3(-8, 0, -22), Vector3(8, 0, -22)]:
		put("lantern", p, 0, 1.7)
	for i in 6: spots.append(Vector3(rng.randf_range(-12, 12), 0.15, rng.randf_range(-24, 4)))

func _townhall() -> void:
	# au bout de l'axe, façade vers le sud
	var o := Vector3(-12.8, 0, -73.6)
	house(o, Vector3(1, 0, 0), Vector3(0, 0, 1), 8, 3, 3, "hall")
	for k in 5: put("pillar-stone", Vector3(-7.2 + k * 3.6, 0, -72.4), 0, S * 1.2)
	put("stairs-wide-stone", Vector3(0, 0, -71.6), -PI / 2, S * 0.5)
	for x in [-9.6, 9.6]: put("banner-red", Vector3(x, S * 2.0, -73.62), -PI / 2, S)
	_sign(Vector3(0, S * 2.55, -73.4), Vector3(0, 0, 1), "MAIRIE DE BRUNEVAL")
	for x in [-5.0, 5.0]: spots.append(Vector3(x, 0.15, -70.5))

func _sign(p: Vector3, n: Vector3, t: String) -> void:
	var l := Label3D.new(); l.text = t; l.font_size = 64; l.outline_size = 14; l.modulate = Color(1, 0.88, 0.55)
	l.pixel_size = 0.012; add_child(l); l.position = p + n * 0.15
	l.rotation.y = atan2(n.x, n.z)

# ================= ruelles arrière, jardins =================
func _back_lanes() -> void:
	for side in [-1, 1]:
		for zr in [[48.0, 19.2], [-38.4, -67.2]]:
			# maisons tournées vers la ruelle arrière (x = ±28.8)
			var z: float = zr[0] - 3.2
			for k in 2:
				var o := Vector3(side * 32.0, 0, z) if side > 0 else Vector3(side * 32.0, 0, z - 3 * S)
				house(o, Vector3(0, 0, -1) if side > 0 else Vector3(0, 0, 1), Vector3(-side, 0, 0), 3, 2, 2)
				z -= 3 * S + 3.2
			# jardins entre la rangée principale et la ruelle : haies, potagers, arbres
			var gz0: float = zr[0] - 2.0; var gz1: float = zr[1] + 2.0
			for gz in range(int(gz1), int(gz0), 3):
				put("fence", Vector3(side * 16.0, 0, gz + 1.5), 0.0 if side > 0 else PI, S * 0.95)
			for t in 3:
				var tz := rng.randf_range(gz1 + 3, gz0 - 3)
				_tree(Vector3(side * rng.randf_range(19.5, 25.0), 0, tz), true)
			for t in 4:
				put("Bush_%d_A_Color1" % rng.randi_range(1, 4), Vector3(side * rng.randf_range(17.5, 26.0), 0, rng.randf_range(gz1, gz0)), rng.randf() * TAU, S * 1.0)

# ================= mobilier urbain =================
func _street_props() -> void:
	for side in [-1, 1]:
		for z in [44.0, 34.4, 24.8, -42.0, -51.6, -61.2]:
			put("lantern", Vector3(side * 6.6, 0.15, z), 0, 1.7)
			lamps.append(Vector3(side * 6.6, 3.4, z))
		for z in [40.0, 28.0, -46.0, -58.0]:
			if rng.randf() < 0.7: put(["Bush_1_A_Color1", "Bush_2_A_Color1", "Bush_4_B_Color1"][rng.randi_range(0, 2)], Vector3(side * 8.6, 0.15, z), rng.randf() * TAU, S * 0.8)
	# chemins des habitants : allers-retours sur chaque trottoir + tour de place
	for side in [-1, 1]:
		walk_paths.append(PackedVector3Array([Vector3(side * 7.6, 0.15, 46), Vector3(side * 7.6, 0.15, -66)]))
	walk_paths.append(PackedVector3Array([Vector3(-12, 0.15, 4), Vector3(12, 0.15, 4), Vector3(12, 0.15, -24), Vector3(-12, 0.15, -24)]))
	walk_paths.append(PackedVector3Array([Vector3(-36, 0.15, 14.4), Vector3(36, 0.15, 14.4)]))
	walk_paths.append(PackedVector3Array([Vector3(-36, 0.15, -33.6), Vector3(36, 0.15, -33.6)]))

# ================= sol =================
var map_rects: Array = []      # [centre, taille, couleur] pour la mini-carte
func _slab(c: Vector3, size: Vector3, mat: Material) -> void:
	var col := Color(0.55, 0.43, 0.3) if mat is StandardMaterial3D else Color(0.72, 0.68, 0.6)
	map_rects.append([Vector2(c.x, c.z), Vector2(size.x, size.z), col])
	var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = size; mi.mesh = bm; mi.material_override = mat
	mi.position = c; add_child(mi)

func _pave(base: Color, joint: Color, sc: float) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = preload("res://scripts/pave.gdshader")
	m.set_shader_parameter("base", base); m.set_shader_parameter("joint", joint); m.set_shader_parameter("sc", sc)
	return m

func _ground() -> void:
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(320, 320); g.mesh = pm
	var gm := ShaderMaterial.new(); gm.shader = preload("res://scripts/ground.gdshader"); g.material_override = gm; add_child(g)
	var road := _pave(Color(0.47, 0.44, 0.41), Color(0.27, 0.25, 0.23), 0.8)
	var walkm := _pave(Color(0.66, 0.6, 0.52), Color(0.42, 0.38, 0.33), 0.55)
	var plaza := _pave(Color(0.6, 0.5, 0.42), Color(0.36, 0.3, 0.25), 0.65)
	var dirt := StandardMaterial3D.new(); dirt.albedo_color = Color(0.55, 0.43, 0.3); dirt.roughness = 1
	_slab(Vector3(0, 0.02, -14), Vector3(ROAD * 2, 0.04, 132), road)                     # rue principale
	for side in [-1, 1]:
		_slab(Vector3(side * 7.6, 0.08, 33.6), Vector3(3.2, 0.16, 28.8), walkm)           # trottoirs îlot sud
		_slab(Vector3(side * 7.6, 0.08, -52.8), Vector3(3.2, 0.16, 28.8), walkm)          # trottoirs îlot nord
	_slab(Vector3(0, 0.03, 14.4), Vector3(83.2, 0.05, 9.6), road)                         # transversale 1
	_slab(Vector3(0, 0.03, -33.6), Vector3(83.2, 0.05, 9.6), road)                        # transversale 2
	_slab(Vector3(0, 0.04, -9.6), Vector3(44.8, 0.06, 38.4), plaza)                       # place du marché
	_slab(Vector3(0, 0.04, -70.0), Vector3(30, 0.06, 6.0), plaza)                         # parvis mairie
	for side in [-1, 1]:
		_slab(Vector3(side * 30.4, 0.025, 33.6), Vector3(3.2, 0.03, 34), dirt)            # ruelles arrière
		_slab(Vector3(side * 30.4, 0.025, -52.8), Vector3(3.2, 0.03, 34), dirt)
	_slab(Vector3(0, 0.02, 81), Vector3(7, 0.03, 62), dirt)                               # chemin vers la campagne
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
	bs.size = Vector3(320, 1, 320); cs.shape = bs; cs.position.y = -0.5; body.add_child(cs); add_child(body)

# ================= nature =================
func _tree(p: Vector3, small := false) -> void:
	var n := "Tree_%d_%s_Color1" % [rng.randi_range(1, 4), ["A", "B", "C"][rng.randi_range(0, 2)]]
	put(n, p, rng.randf() * TAU, 2.0 if small else rng.randf_range(2.4, 3.4))
	box(p + Vector3.UP * 1.5, Vector3(0.8, 3, 0.8))

func _nature() -> void:
	# arbres de la place (4 coins) et de l'entrée
	for p in [Vector3(-18, 0, 6), Vector3(18, 0, 6), Vector3(-18, 0, -25), Vector3(18, 0, -25)]: _tree(p, true)
	# campagne au sud : bosquets, rochers, prés clôturés
	for g in [Vector3(-30, 0, 72), Vector3(34, 0, 66), Vector3(-48, 0, 100), Vector3(46, 0, 104), Vector3(-42, 0, 128), Vector3(40, 0, 138)]:
		for k in rng.randi_range(3, 5): _tree(g + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6)))
		for k in 3: put("Bush_%d_%s_Color1" % [rng.randi_range(1, 4), ["A", "B", "C"][rng.randi_range(0, 2)]], g + Vector3(rng.randf_range(-8, 8), 0, rng.randf_range(-8, 8)), rng.randf() * TAU, S * 1.8)
	for k in 10:
		var p := Vector3(rng.randf_range(-60, 60), 0, rng.randf_range(58, 140))
		if abs(p.x) < 6: continue
		put("Rock_1_%s_Color1" % ["A", "B", "C", "D", "E"][rng.randi_range(0, 4)], p, rng.randf() * TAU, S * rng.randf_range(1.5, 3.0))
	for f in [[Vector3(-22, 0, 60), 6, 4], [Vector3(14, 0, 82), 7, 5]]:
		var c: Vector3 = f[0]
		for i in f[1]:
			put("fence", c + Vector3(i * S, 0, 0), PI / 2, S); put("fence", c + Vector3(i * S, 0, f[2] * S), -PI / 2, S)
		for j in f[2]:
			put("fence", c + Vector3(-S * 0.5 - S * 0.4, 0, j * S + S * 0.5), PI, S); put("fence", c + Vector3((f[1] - 0.5) * S - S * 0.1, 0, j * S + S * 0.5), 0, S)
	for k in 14:
		var side := -1 if k % 2 == 0 else 1
		_tree(Vector3(side * rng.randf_range(41, 52), 0, rng.randf_range(-60, 50)))
	# collines au loin
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color(0.36, 0.55, 0.27); hm.roughness = 1
	for h in [[Vector3(-70, -6, 120), 30], [Vector3(60, -8, 140), 36], [Vector3(-10, -10, 175), 40], [Vector3(95, -5, 70), 24], [Vector3(-95, -6, 60), 26]]:
		var mi := MeshInstance3D.new(); var sm := SphereMesh.new(); sm.radius = h[1]; sm.height = h[1] * 0.9; sm.radial_segments = 20; sm.rings = 8
		mi.mesh = sm; mi.material_override = hm; mi.position = h[0]; mi.scale = Vector3(1.4, 0.55, 1); add_child(mi)

func _cliffs() -> void:
	# falaise en arc au nord et sur les côtés : gros rochers superposés, du gris au brun
	var pts: Array = []
	for i in 34:
		var a: float = lerp(-0.15 * PI, -0.85 * PI, i / 33.0)
		pts.append(Vector3(cos(a) * 64, 0, -50 + sin(a) * 56))
	for side in [-1, 1]:
		for i in 10: pts.append(Vector3(side * rng.randf_range(54, 60), 0, -30 + i * 9))
	for p in pts:
		for layer in 2:
			var n := "Rock_3_%s_Color1" % ["A", "B", "C", "D", "E", "F", "G", "H", "I"][rng.randi_range(0, 8)]
			var s := rng.randf_range(16, 24) * (1.0 - layer * 0.35)
			put(n, p + Vector3(rng.randf_range(-4, 4), s * 0.35 + layer * s * 0.5, rng.randf_range(-4, 4)), rng.randf() * TAU, s)
		if rng.randf() < 0.35: _tree(p + Vector3(rng.randf_range(-3, 3), 9, 0))
	# murs invisibles de la vallée
	box(Vector3(0, 10, -100), Vector3(140, 20, 4))
	box(Vector3(-60, 10, -10), Vector3(4, 20, 160)); box(Vector3(60, 10, -10), Vector3(4, 20, 160))
	box(Vector3(0, 10, 160), Vector3(140, 20, 4))

# ================= assemblage =================
func _finish() -> void:
	for n in mm:
		var p: Array = mm[n]
		if p[2].is_empty(): continue
		var mmi := MultiMeshInstance3D.new(); var m := MultiMesh.new()
		m.transform_format = MultiMesh.TRANSFORM_3D; m.mesh = p[0]; m.instance_count = p[2].size()
		for i in p[2].size(): m.set_instance_transform(i, p[2][i])
		mmi.multimesh = m; add_child(mmi)
	_roofs()
	var body := StaticBody3D.new(); add_child(body)
	for b in col_boxes:
		var cs := CollisionShape3D.new(); var bs := BoxShape3D.new(); bs.size = b[1]; cs.shape = bs
		cs.position = b[0]; cs.rotation.y = b[2]; body.add_child(cs)

func _roofs() -> void:
	# toit : prisme unitaire (pans) + pignons (triangles), instancié avec une couleur par maison
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var A := Vector3(-0.5, 0, 0.5); var B := Vector3(0.5, 0, 0.5); var C := Vector3(0.5, 1, 0); var D := Vector3(-0.5, 1, 0)
	var E := Vector3(-0.5, 0, -0.5); var F := Vector3(0.5, 0, -0.5)
	for tri in [[A, B, C], [A, C, D], [F, E, D], [F, D, C]]:
		var nrm: Vector3 = (tri[1] - tri[0]).cross(tri[2] - tri[0]).normalized()
		for v in tri: st.set_normal(nrm); st.add_vertex(v)
	var slope := st.commit()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tri in [[Vector3(0, 0, -0.5), Vector3(0, 0, 0.5), Vector3(0, 1, 0)]]:
		for v in tri: st.set_normal(Vector3.RIGHT); st.add_vertex(v)
	var gab := st.commit()
	for pair in [[slope, roof_x, true], [gab, gable_x, false]]:
		var arr: Array = pair[1]
		if arr.is_empty(): continue
		var mat := StandardMaterial3D.new(); mat.vertex_color_use_as_albedo = true; mat.cull_mode = BaseMaterial3D.CULL_DISABLED; mat.roughness = 0.85
		var m := MultiMesh.new(); m.transform_format = MultiMesh.TRANSFORM_3D; m.use_colors = true; m.mesh = pair[0]
		m.instance_count = arr.size()
		for i in arr.size(): m.set_instance_transform(i, arr[i][0]); m.set_instance_color(i, arr[i][1])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = m; mmi.material_override = mat; add_child(mmi)
