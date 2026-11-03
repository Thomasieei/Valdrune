class_name Geo
extends RefCounted
## Constructeur de géométrie architecturale : boîtes, cylindres, cônes, toits, escaliers.
## Les UV sont en mètres (texture répétée à l'échelle réelle) → pierres et tuiles toujours à la bonne taille.
## Regroupe la géométrie par matériau (peu d'appels de rendu) et accumule les collisions.

var surfaces := {}        # nom matériau -> SurfaceTool
var shapes := []          # [Transform3D, Shape3D]
var uv_scale := {}        # nom matériau -> mètres par répétition

static var _mats := {}

static func mat(name: String) -> Material:
	if _mats.has(name):
		return _mats[name]
	var m := StandardMaterial3D.new()
	m.roughness = 0.92
	match name:
		"pierre": m.albedo_texture = load("res://assets/textures/pierre_chateau.png")
		"pierre_base": m.albedo_texture = load("res://assets/textures/pierre_base.png")
		"pierre_claire": m.albedo_texture = load("res://assets/textures/pierre_claire.png")
		"ardoise": m.albedo_texture = load("res://assets/textures/toit_ardoise.png")
		"tuile": m.albedo_texture = load("res://assets/textures/toit_tuile.png")
		"chaume": m.albedo_texture = load("res://assets/textures/toit_chaume.png")
		"bois": m.albedo_texture = load("res://assets/textures/bois.png")
		"bois_sombre": m.albedo_texture = load("res://assets/textures/bois_sombre.png")
		"crepi": m.albedo_texture = load("res://assets/textures/crepi.png")
		"dallage": m.albedo_texture = load("res://assets/textures/dallage.png")
		"paves": m.albedo_texture = load("res://assets/textures/paves.png")
		"parquet": m.albedo_texture = load("res://assets/textures/parquet.png")
		"sillons": m.albedo_texture = load("res://assets/textures/sillons.png")
		"terre": m.albedo_texture = load("res://assets/textures/terre.png")
		"tissu_blanc":
			m.albedo_color = Color(0.93, 0.90, 0.82)
		"vert_volet":
			m.albedo_color = Color(0.30, 0.45, 0.32)
		"rune":
			m.albedo_color = Color(0.4, 0.8, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.35, 0.75, 1.0)
			m.emission_energy_multiplier = 2.2
		"fer_rouille":
			m.albedo_color = Color(0.55, 0.32, 0.22)
			m.roughness = 0.7
		"cuivre":
			m.albedo_color = Color(0.85, 0.48, 0.25)
			m.metallic = 0.6
			m.roughness = 0.35
		"cristal":
			m.albedo_color = Color(0.45, 0.75, 1.0)
			m.emission_enabled = true
			m.emission = Color(0.3, 0.6, 1.0)
			m.emission_energy_multiplier = 1.2
			m.roughness = 0.15
		"tapis":
			m.albedo_color = Color(0.62, 0.12, 0.12)
		"tapis_bord":
			m.albedo_color = Color(0.85, 0.66, 0.25)
		"or":
			m.albedo_color = Color(1.0, 0.78, 0.25)
			m.metallic = 0.8
			m.roughness = 0.3
		"fer":
			m.albedo_color = Color(0.32, 0.33, 0.36)
			m.metallic = 0.6
			m.roughness = 0.45
		"vitre":
			m.albedo_color = Color(0.70, 0.80, 0.92)
			m.emission_enabled = true
			m.emission = Color(0.62, 0.74, 0.90)
			m.emission_energy_multiplier = 0.55
		"braise":
			m.albedo_color = Color(0.5, 0.12, 0.03)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.3, 0.05)
			m.emission_energy_multiplier = 1.6
		"fenetre_sombre":
			m.albedo_color = Color(0.09, 0.08, 0.10)
			m.roughness = 1.0
		"bleu_royal":
			m.albedo_color = Color(0.16, 0.26, 0.58)
		"tissu_rouge":
			m.albedo_color = Color(0.70, 0.15, 0.13)
		"blanc":
			m.albedo_color = Color(0.92, 0.90, 0.85)
		_:
			m.albedo_color = Color.MAGENTA
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	if not (name in ["or", "fer", "cuivre", "cristal"]):
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	_mats[name] = m
	return m

func _init() -> void:
	uv_scale = {"pierre": 4.0, "pierre_base": 4.5, "pierre_claire": 2.5, "ardoise": 3.0, "tuile": 3.0, "chaume": 3.5,
		"bois": 2.0, "bois_sombre": 2.0, "crepi": 4.0, "dallage": 7.0, "paves": 7.0, "parquet": 3.0, "sillons": 6.0, "terre": 3.0}

func _st(m: String) -> SurfaceTool:
	if not surfaces.has(m):
		var st := SurfaceTool.new()
		st.begin(Mesh.PRIMITIVE_TRIANGLES)
		surfaces[m] = st
	return surfaces[m]

func _sc(m: String) -> float:
	return uv_scale.get(m, 2.0)

## Quad (4 coins dans l'ordre, sens trigo vu de l'extérieur). UV projetées selon la normale.
func quad(m: String, a: Vector3, b: Vector3, c: Vector3, d: Vector3, uv_mode := 0) -> void:
	var st := _st(m)
	var nrm := (b - a).cross(c - a).normalized()
	var s := _sc(m)
	var pts := [a, c, b, a, d, c]   # Godot : faces avant en sens horaire
	# repère tangent : axe U le long de (b - a), V vertical (ou selon d - a)
	var u_ax := (b - a).normalized()
	var v_ax := (d - a).normalized()
	for p in pts:
		var uv := Vector2((p - a).dot(u_ax), -(p - a).dot(v_ax)) / s
		if uv_mode == 1:   # projection monde (sols)
			uv = Vector2(p.x, p.z) / s
		st.set_normal(nrm)
		st.set_uv(uv)
		st.add_vertex(p)

## Boîte orientée (rotation Y) : centre, taille.
func box(m: String, center: Vector3, size: Vector3, rot_y := 0.0, collide := true, top_mat := "", skip_bottom := true) -> void:
	obox(m, Transform3D(Basis(Vector3.UP, rot_y), center), size, collide, top_mat, skip_bottom)

## Boîte avec transformation quelconque (ex. planches inclinées d'un pont)
func obox(m: String, xf: Transform3D, size: Vector3, collide := true, top_mat := "", skip_bottom := true) -> void:
	var h := size * 0.5
	var c := [Vector3(-h.x, -h.y, -h.z), Vector3(h.x, -h.y, -h.z), Vector3(h.x, -h.y, h.z), Vector3(-h.x, -h.y, h.z),
		Vector3(-h.x, h.y, -h.z), Vector3(h.x, h.y, -h.z), Vector3(h.x, h.y, h.z), Vector3(-h.x, h.y, h.z)]
	var w := []
	for v in c:
		w.append(xf * v)
	var tm := top_mat if top_mat != "" else m
	quad(m, w[3], w[2], w[6], w[7])  # +z
	quad(m, w[1], w[0], w[4], w[5])  # -z
	quad(m, w[2], w[1], w[5], w[6])  # +x
	quad(m, w[0], w[3], w[7], w[4])  # -x
	quad(tm, w[7], w[6], w[5], w[4], 1 if xf.basis.y.y > 0.99 else 0)  # haut
	if not skip_bottom:
		quad(m, w[0], w[1], w[2], w[3], 1)
	if collide:
		var bs := BoxShape3D.new()
		bs.size = size
		shapes.append([xf, bs])

## Mur entre deux points au sol (épaisseur, hauteur), base à y0.
func wall(m: String, a: Vector3, b: Vector3, thick: float, height: float, collide := true) -> void:
	var mid := (a + b) * 0.5
	var d := b - a
	var len := Vector2(d.x, d.z).length()
	box(m, Vector3(mid.x, a.y + height * 0.5, mid.z), Vector3(len, height, thick), rot_for(d), collide)

static func rot_for(d: Vector3) -> float:
	# rotation Y telle que l'axe X local suive la direction d
	return -atan2(d.z, d.x)

## Cylindre (tour). sides faces, de y0 à y1.
func cylinder(m: String, center: Vector3, r: float, y0: float, y1: float, sides := 16, collide := true, cap := true, cap_mat := "") -> void:
	var circ := TAU * r
	var s := _sc(m)
	var st := _st(m)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(center.x + cos(a0) * r, y0, center.z + sin(a0) * r)
		var p1 := Vector3(center.x + cos(a1) * r, y0, center.z + sin(a1) * r)
		var u0 := circ * i / sides / s
		var u1 := circ * (i + 1) / sides / s
		var n0 := Vector3(cos(a0), 0, sin(a0))
		var n1 := Vector3(cos(a1), 0, sin(a1))
		var quadv := [[p0, n0, Vector2(u0, -y0 / s)], [Vector3(p0.x, y1, p0.z), n0, Vector2(u0, -y1 / s)], [Vector3(p1.x, y1, p1.z), n1, Vector2(u1, -y1 / s)],
			[p0, n0, Vector2(u0, -y0 / s)], [Vector3(p1.x, y1, p1.z), n1, Vector2(u1, -y1 / s)], [p1, n1, Vector2(u1, -y0 / s)]]
		for q in quadv:
			st.set_normal(q[1]); st.set_uv(q[2]); st.add_vertex(q[0])
	if cap:
		var cm := cap_mat if cap_mat != "" else m
		var cs := _st(cm)
		for i in sides:
			var a0 := TAU * i / sides
			var a1 := TAU * (i + 1) / sides
			var sc := _sc(cm)
			for p in [Vector3(center.x, y1, center.z), Vector3(center.x + cos(a1) * r, y1, center.z + sin(a1) * r), Vector3(center.x + cos(a0) * r, y1, center.z + sin(a0) * r)]:
				cs.set_normal(Vector3.UP); cs.set_uv(Vector2(p.x, p.z) / sc); cs.add_vertex(p)
	if collide:
		var cy := CylinderShape3D.new()
		cy.radius = r
		cy.height = y1 - y0
		shapes.append([Transform3D(Basis(), Vector3(center.x, (y0 + y1) * 0.5, center.z)), cy])

## Cône (toit de tour), légèrement débordant.
func cone(m: String, center: Vector3, r: float, y0: float, height: float, sides := 16) -> void:
	var st := _st(m)
	var s := _sc(m)
	var apex := Vector3(center.x, y0 + height, center.z)
	var slant := sqrt(r * r + height * height)
	for i in sides:
		var a0 := TAU * i / sides
		var a1 := TAU * (i + 1) / sides
		var p0 := Vector3(center.x + cos(a0) * r, y0, center.z + sin(a0) * r)
		var p1 := Vector3(center.x + cos(a1) * r, y0, center.z + sin(a1) * r)
		var nm := (p1 - p0).cross(apex - p0).normalized() * -1.0
		if nm.y < 0:
			nm = -nm
		var arc := TAU * r / sides / s
		var verts := [[p0, Vector2(i * arc, slant / s)], [apex, Vector2((i + 0.5) * arc, 0)], [p1, Vector2((i + 1) * arc, slant / s)]]
		# ordre pour face extérieure
		for v in [verts[0], verts[2], verts[1]]:
			st.set_normal(nm); st.set_uv(v[1]); st.add_vertex(v[0])

## Pyramide / toit à 4 pans sur un rectangle (centre, demi-tailles), hauteur h.
func hip_roof(m: String, c: Vector3, hx: float, hz: float, h: float, rot_y := 0.0) -> void:
	var b := Basis(Vector3.UP, rot_y)
	var ridge := maxf(hx - hz, 0.0)
	var r0 := c + b * Vector3(-ridge, h, 0)
	var r1 := c + b * Vector3(ridge, h, 0)
	var A := c + b * Vector3(-hx, 0, -hz)
	var B := c + b * Vector3(hx, 0, -hz)
	var C := c + b * Vector3(hx, 0, hz)
	var D := c + b * Vector3(-hx, 0, hz)
	quad(m, D, C, r1, r0)
	quad(m, B, A, r0, r1)
	_tri(m, C, B, r1)
	_tri(m, A, D, r0)

## Toit à deux pans (pignon) ; axe du faîtage selon X local.
func gable_roof(m: String, c: Vector3, hx: float, hz: float, h: float, rot_y := 0.0, gable_mat := "") -> void:
	var b := Basis(Vector3.UP, rot_y)
	var r0 := c + b * Vector3(-hx, h, 0)
	var r1 := c + b * Vector3(hx, h, 0)
	var A := c + b * Vector3(-hx, 0, -hz)
	var B := c + b * Vector3(hx, 0, -hz)
	var C := c + b * Vector3(hx, 0, hz)
	var D := c + b * Vector3(-hx, 0, hz)
	quad(m, D, C, r1, r0)
	quad(m, B, A, r0, r1)
	var g := gable_mat if gable_mat != "" else m
	_tri(g, C, B, r1)
	_tri(g, A, D, r0)

func _tri(m: String, a: Vector3, b: Vector3, c: Vector3) -> void:
	var st := _st(m)
	var nrm := (b - a).cross(c - a).normalized()
	var s := _sc(m)
	var u_ax := (b - a).normalized()
	var v_ax := nrm.cross(u_ax)
	for p in [a, c, b]:
		st.set_normal(nrm)
		st.set_uv(Vector2((p - a).dot(u_ax), -(p - a).dot(v_ax)) / s)
		st.add_vertex(p)

## Créneaux le long d'un segment (sur le haut d'un mur)
func crenels(m: String, a: Vector3, b: Vector3, thick: float, step := 2.4, w := 1.3, h := 1.4) -> void:
	var d := b - a
	var len := d.length()
	var n := int(len / step)
	var rot := rot_for(d)
	for i in n + 1:
		var t := (i * step + (len - n * step) * 0.5) / len
		var p := a.lerp(b, clampf(t, 0, 1))
		box(m, p + Vector3.UP * h * 0.5, Vector3(w, h, thick), rot, false)

## Créneaux autour d'une tour ronde
func ring_crenels(m: String, center: Vector3, r: float, y: float, count := 12, h := 1.4) -> void:
	for i in count:
		var a := TAU * (i + 0.5) / count
		var p := Vector3(center.x + cos(a) * r, y + h * 0.5, center.z + sin(a) * r)
		box(m, p, Vector3(1.0, h, 1.4), -a, false)

## Escalier droit : de a (bas) vers la direction dir, n marches.
func stairs(m: String, base: Vector3, dir_rot: float, width: float, rise: float, run: float, n: int) -> void:
	var b := Basis(Vector3.UP, dir_rot)
	for i in n:
		var h := rise * (i + 1)
		var c := base + b * Vector3(0, h * 0.5, -(i + 0.5) * run)
		box(m, c, Vector3(width, h, run), dir_rot, false)
	# collision : rampe lisse
	var length := run * n
	var height := rise * n
	var ang := atan2(height, length)
	var bs := BoxShape3D.new()
	var hyp := sqrt(length * length + height * height)
	bs.size = Vector3(width, 0.2, hyp)
	var xf := Transform3D(b * Basis(Vector3.RIGHT, ang), base + b * Vector3(0, height * 0.5, -length * 0.5))
	shapes.append([xf, bs])

func commit(parent: Node3D, name: String, layer := 2, shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = name
	var mesh := ArrayMesh.new()
	for m in surfaces:
		var st: SurfaceTool = surfaces[m]
		st.commit(mesh)
		mesh.surface_set_material(mesh.get_surface_count() - 1, mat(m))
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	if not shadows:
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(mi)
	if shapes.size() > 0:
		var body := StaticBody3D.new()
		body.collision_layer = layer
		body.collision_mask = 0
		for s in shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[1]
			cs.transform = s[0]
			body.add_child(cs)
		root.add_child(body)
	parent.add_child(root)
	return root
