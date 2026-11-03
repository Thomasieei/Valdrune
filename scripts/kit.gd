class_name Kit
## Accès aux assets : instanciation, matériaux partagés, échelles de référence.

const NATURE := "res://assets/nature/mdvl_nature_%s_01.glb"
const VILLAGE := "res://assets/village/%s.obj"
const DUNGEON := "res://assets/dungeon/%s.fbx"

## Échelles harmonisées (1 unité = 1 m, personnage = 1,82 m)
const S_VILLAGE := 1.3   # portes 2,6 m, modules 1,3 m
const S_DUNGEON := 1.0   # salles 8 m, halls 10 m de haut
const S_TREE := 2.0      # chênes ~8,6 m, pins ~12 m (avec variation)

static var _cache := {}
static var _lpd_mat: StandardMaterial3D

static func lpd_material() -> StandardMaterial3D:
	if _lpd_mat == null:
		_lpd_mat = StandardMaterial3D.new()
		_lpd_mat.albedo_texture = load("res://assets/dungeon/LPD_Texture.png")
		_lpd_mat.roughness = 0.9
		_lpd_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		_lpd_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	return _lpd_mat

static func _load(path: String) -> Resource:
	if not _cache.has(path):
		var r: Resource = load(path)
		if r is ArrayMesh and path.begins_with("res://assets/village/"):
			r = _flatten(r)
		_cache[path] = r
	return _cache[path]

## Les modèles .obj du village ont une surface (donc un appel de rendu) par couleur : un tonneau = 40 appels.
## On les fond en une seule surface à couleurs de sommets → 1 appel par objet (énorme gain sur téléphone).
static var _vc_mat: StandardMaterial3D
static func _flatten(m: ArrayMesh) -> Mesh:
	var n := m.get_surface_count()
	if n <= 1:
		return m
	for i in n:
		var mt := m.surface_get_material(i)
		if mt is BaseMaterial3D and ((mt as BaseMaterial3D).albedo_texture != null or (mt as BaseMaterial3D).emission_enabled or (mt as BaseMaterial3D).transparency != BaseMaterial3D.TRANSPARENCY_DISABLED):
			return m
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in n:
		var mt := m.surface_get_material(i)
		var col: Color = (mt as BaseMaterial3D).albedo_color if mt is BaseMaterial3D else Color.WHITE
		var a := m.surface_get_arrays(i)
		var v: PackedVector3Array = a[Mesh.ARRAY_VERTEX]
		var nm = a[Mesh.ARRAY_NORMAL]
		var idx = a[Mesh.ARRAY_INDEX]
		var order: PackedInt32Array = idx if idx != null and idx.size() > 0 else PackedInt32Array(range(v.size()))
		for k in order:
			st.set_color(col)
			if nm != null and nm.size() > k:
				st.set_normal(nm[k])
			st.add_vertex(v[k])
	if _vc_mat == null:
		_vc_mat = StandardMaterial3D.new()
		_vc_mat.vertex_color_use_as_albedo = true
		_vc_mat.roughness = 0.9
		_vc_mat.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
	st.set_material(_vc_mat)
	st.index()
	return st.commit()

static func mesh_of(path: String) -> Mesh:
	var r := _load(path)
	if r is Mesh:
		return r
	var key := path + "#mesh"
	if not _cache.has(key):
		var s: Node = r.instantiate()
		var mi: MeshInstance3D = s if s is MeshInstance3D else s.find_child("*", true, false) as MeshInstance3D
		if not (mi is MeshInstance3D):
			for c in s.find_children("*", "MeshInstance3D", true, false):
				mi = c
				break
		_cache[key] = mi.mesh if mi else null
		s.free()
	return _cache[key]

static func place(parent: Node, path: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var r := _load(path)
	var n: Node3D
	if r is Mesh:
		var mi := MeshInstance3D.new()
		mi.mesh = r
		n = mi
	else:
		n = r.instantiate()
	if path.begins_with("res://assets/farm/"):
		for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
			mi.material_override = farm_material()
	if path.begins_with("res://assets/dungeon/"):
		for mi in n.find_children("*", "MeshInstance3D", true, false) + ([n] if n is MeshInstance3D else []):
			mi.material_override = lpd_material()
	n.position = pos
	n.rotation.y = rot_y
	n.scale = Vector3.ONE * scale
	parent.add_child(n)
	return n

static var _farm_mat: StandardMaterial3D
static func farm_material() -> StandardMaterial3D:
	if _farm_mat == null:
		_farm_mat = StandardMaterial3D.new()
		_farm_mat.albedo_texture = load("res://assets/farm/LowPolyFarmLite_Texture_01.png")
		_farm_mat.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST_WITH_MIPMAPS
		_farm_mat.roughness = 0.9
	return _farm_mat

## Potager : chou, plant de tomate, butte de terre, clôture, arrosoir, caisse (Low Poly Farm Lite)
static func farm(parent: Node, name: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	return place(parent, "res://assets/farm/%s_01.fbx" % name, pos, rot_y, scale)

static func nature(parent: Node, name: String, pos: Vector3, rot_y := 0.0, scale := 1.0) -> Node3D:
	var path := NATURE % name
	if name.right(3).begins_with("_0"):
		path = "res://assets/nature/mdvl_nature_%s.glb" % name
	return place(parent, path, pos, rot_y, scale)

static func village(parent: Node, name: String, pos: Vector3, rot_y := 0.0, scale := S_VILLAGE) -> Node3D:
	return place(parent, VILLAGE % name, pos, rot_y, scale)

static func dungeon(parent: Node, name: String, pos: Vector3, rot_y := 0.0, scale := S_DUNGEON) -> Node3D:
	return place(parent, DUNGEON % name, pos, rot_y, scale)
