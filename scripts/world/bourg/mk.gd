class_name MK
extends RefCounted
## Medieval Village MegaKit (Quaternius, CC0) : pièces modulaires de 2 m (murs 3,12 m de haut).
## Un MK = un chantier : on y pose des pièces (avec teinte facultative), puis commit() fusionne tout
## par matériau et par cellule de 48 m (quelques appels de rendu pour tout le bourg) + niveaux de détail.

const DIR := "res://assets/megakit/%s.gltf"
const TEX := "res://assets/megakit/tex/%s"
const CELL := 64.0
const M := 2.0          # module
const FH := 3.12        # hauteur d'un étage (pièces murales)

static var _mesh := {}      # nom -> ArrayMesh brut
static var _var := {}       # nom + teintes -> ArrayMesh avec couleurs de sommets
static var _mats := {}

var cells := {}             # "cx|cz" -> {mat_key -> SurfaceTool}
var det: MK                 # petits détails (fenêtres, volets, portes, corbeaux, bordures…) : sans ombre, cachés au loin
const DETAIL := ["Window_", "WindowShutters_", "Door_", "Roof_Support2", "Wall_BottomCover", "Prop_Vine", "Prop_WoodenFence", "Prop_ExteriorBorder", "Balcony_", "Prop_Support", "Corner_Exterior_Wood", "Prop_Chimney", "Floor_Wood"]
## Matériaux regroupés (moins d'appels de rendu) : la teinte de sommet fait la différence
const MERGE := {"MI_WoodTrim_Wear": "MI_WoodTrim", "MI_MetalOrnaments": "MI_WoodTrim", "MI_RedBrick": "MI_Brick", "MI_WindowGlass": "MI_WoodTrim"}
var shapes := []            # [Transform3D, Shape3D]
var tris := 0
var stats := {}

## Matériaux partagés. La couleur de sommet teinte la texture (enduits de couleurs différentes,
## tuiles plus ou moins rouges) sans multiplier les appels de rendu.
static func mat(key: String) -> Material:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.vertex_color_use_as_albedo = true
	m.roughness = 0.9
	m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	var tex := ""
	var nrm := ""
	match key:
		"MI_Plaster": tex = "plaster_c.jpg"; nrm = "plaster_n.png"
		"MI_WoodTrim": tex = "woodtrim_c.jpg"; nrm = "woodtrim_n.png"
		"MI_WoodTrim_Wear":
			tex = "woodtrim_c.jpg"; nrm = "woodtrim_n.png"
			m.albedo_color = Color(0.82, 0.78, 0.74)
		"MI_RockTrim": tex = "rocktrim_c.jpg"; nrm = "rocktrim_n.png"
		"MI_Brick": tex = "brick_c.jpg"; nrm = "brick_n.png"
		"MI_RedBrick": tex = "redbrick_c.jpg"
		"MI_UnevenBrick": tex = "unevenbrick_c.jpg"; nrm = "unevenbrick_n.png"
		"MI_RoundTiles": tex = "roundtiles_c.jpg"; nrm = "roundtiles_n.png"
		"MI_RoundTiles_Gray": tex = "roundtiles_g.jpg"; nrm = "roundtiles_n.png"
		"MI_MetalOrnaments":
			tex = "metal_c.jpg"
			m.metallic = 0.5
			m.roughness = 0.55
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		"MI_Vine":
			tex = "vine.png"
			m.albedo_color = Color(0.45, 0.62, 0.30)
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
			m.alpha_scissor_threshold = 0.5
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		"MI_WindowGlass":
			# vitres opaques (pas de transparence triée = rapide) : verre sombre bleuté
			m.albedo_color = Color(0.20, 0.24, 0.30)
			m.roughness = 0.25
			m.specular_mode = BaseMaterial3D.SPECULAR_SCHLICK_GGX
		"glass_lit":
			# fenêtres éclairées de l'intérieur : lueur chaude (le bourg a l'air habité)
			m.albedo_color = Color(1.0, 0.78, 0.45)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.62, 0.28)
			m.emission_energy_multiplier = 0.9
		_:
			m.albedo_color = Color(0.8, 0.8, 0.8)
	if tex != "":
		m.albedo_texture = load(TEX % tex)
	if nrm != "":
		m.normal_enabled = true
		m.normal_texture = load(TEX % nrm)
		m.normal_scale = 0.8
	_mats[key] = m
	return m

static func mesh(name: String) -> ArrayMesh:
	if not _mesh.has(name):
		_mesh[name] = Kit.mesh_of(DIR % name)
		if _mesh[name] == null:
			push_error("MegaKit : pièce introuvable " + name)
	return _mesh[name]

static func _mat_key(m: Material) -> String:
	if m == null:
		return "?"
	var n := String(m.resource_name)
	if n == "":
		n = m.resource_path.get_file()
	return n

## Copie de la pièce avec couleurs de sommet (teinte par matériau, blanc sinon)
static func variant(name: String, tint: Dictionary) -> ArrayMesh:
	var key := name + str(tint)
	if _var.has(key):
		return _var[key]
	var src := mesh(name)
	var out := ArrayMesh.new()
	if src == null:
		_var[key] = out
		return out
	var lite := _lite(name)
	for s in src.get_surface_count():
		var arr := src.surface_get_arrays(s)
		if lite.has(s):
			arr = lite[s][0]
			arr[Mesh.ARRAY_INDEX] = lite[s][1]
		var mk := _mat_key(src.surface_get_material(s))
		var n: int = (arr[Mesh.ARRAY_VERTEX] as PackedVector3Array).size()
		var cols := PackedColorArray()
		cols.resize(n)
		var dflt := Color.WHITE
		if mk == "MI_MetalOrnaments":
			dflt = Color(0.3, 0.29, 0.29)
		elif mk == "MI_WindowGlass":
			dflt = Color(0.3, 0.38, 0.5)   # vitre sombre (fusionnée avec le bois)
		cols.fill(tint.get(mk, dflt))
		arr[Mesh.ARRAY_COLOR] = cols
		arr[Mesh.ARRAY_TEX_UV2] = null
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
		out.surface_set_name(out.get_surface_count() - 1, mk)
	_var[key] = out
	return out

## Pièces lourdes (toits de tuiles rondes, angles en pierre, portes ouvragées : jusqu'à 6 000 triangles) :
## on garde un niveau de détail simplifié (~35 %) — invisible à hauteur de caméra, 3 fois moins coûteux sur téléphone.
static var _lites := {}
static func _lite(name: String) -> Dictionary:
	if _lites.has(name):
		return _lites[name]
	var res := {}
	var src := mesh(name)
	var total := 0
	for s in src.get_surface_count():
		total += src.surface_get_array_index_len(s) / 3
	if total > 380:
		var im := ImporterMesh.new()
		for s in src.get_surface_count():
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, src.surface_get_arrays(s))
		im.generate_lods(20.0, 60.0, [])
		for s in src.get_surface_count():
			var full := src.surface_get_array_index_len(s)
			if full < 360:
				continue
			var best := PackedInt32Array()
			for l in im.get_surface_lod_count(s):
				var ix := im.get_surface_lod_indices(s, l)
				if ix.size() >= full * 0.25:
					best = ix
			if best.size() > 0:
				# les indices simplifiés se rapportent aux sommets de l'ImporterMesh (réordonnés)
				res[s] = [im.get_surface_arrays(s), best]
	_lites[name] = res
	return res

## Pose une pièce. remap : {"MI_WindowGlass": "glass_lit"} pour changer un matériau.
func add(name: String, xf: Transform3D, tint := {}, remap := {}) -> void:
	if det:
		for pre in DETAIL:
			if name.begins_with(pre):
				det.add(name, xf, tint, remap)
				return
	var v := variant(name, tint)
	var cx := int(floor(xf.origin.x / CELL))
	var cz := int(floor(xf.origin.z / CELL))
	var ck := "%d|%d" % [cx, cz]
	if not cells.has(ck):
		cells[ck] = {}
	var c: Dictionary = cells[ck]
	for s in v.get_surface_count():
		var mk: String = v.surface_get_name(s)
		mk = remap.get(mk, MERGE.get(mk, mk))
		if not c.has(mk):
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			c[mk] = st
		(c[mk] as SurfaceTool).append_from(v, s, xf)
		tris += v.surface_get_array_index_len(s) / 3
		stats[name] = stats.get(name, 0) + v.surface_get_array_index_len(s) / 3

## Raccourci : pièce en (x, y, z) tournée de rot autour de Y
func put(name: String, pos: Vector3, rot := 0.0, tint := {}, remap := {}, scl := 1.0) -> void:
	add(name, Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * scl), pos), tint, remap)

func col_box(xf: Transform3D, size: Vector3) -> void:
	var b := BoxShape3D.new()
	b.size = size
	shapes.append([xf, b])

func commit(parent: Node3D, name: String, vis_end := 0.0, lods := true, shadows := true) -> Node3D:
	var root := Node3D.new()
	root.name = name
	parent.add_child(root)
	if det:
		det.commit(root, "Details", 95.0, lods, false)
	for ck in cells:
		var c: Dictionary = cells[ck]
		var im := ImporterMesh.new()
		for mk in c:
			var st: SurfaceTool = c[mk]
			im.add_surface(Mesh.PRIMITIVE_TRIANGLES, st.commit_to_arrays(), [], {}, mat(mk), mk)
		if lods:
			im.generate_lods(25.0, 60.0, [])
		var mi := MeshInstance3D.new()
		mi.name = "Lot_" + String(ck).replace("|", "_").replace("-", "m")
		mi.mesh = im.get_mesh()
		if vis_end > 0.0:
			mi.visibility_range_end = vis_end
		if not shadows:
			mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		root.add_child(mi)
	if shapes.size() > 0:
		var body := StaticBody3D.new()
		body.name = "Collisions"
		body.collision_layer = 2
		body.collision_mask = 0
		for s in shapes:
			var cs := CollisionShape3D.new()
			cs.shape = s[1]
			cs.transform = s[0]
			body.add_child(cs)
		root.add_child(body)
	return root
