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
		_cache[path] = load(path)
	return _cache[path]

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
