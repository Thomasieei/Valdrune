class_name Apparence



const P := "res://assets/pnj/"
static var _tetes := {}

static func _greffer(m: MeshInstance3D, squel: Skeleton3D) -> void:
	var t := m.transform
	m.get_parent().remove_child(m)
	m.owner = null
	squel.add_child(m)
	m.transform = t
	m.skeleton = NodePath("..")


static func _decouper(source: Mesh, y_min: float, x_min: float, cou := 0.0) -> ArrayMesh:
	var cle := [source, y_min, x_min, cou]
	if _tetes.has(cle):
		return _tetes[cle]
	var res := ArrayMesh.new()
	for s in source.get_surface_count():
		var arr := source.surface_get_arrays(s)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var garde := PackedInt32Array()
		for i in range(0, idx.size(), 3):
			var a := v[idx[i]]
			var b := v[idx[i + 1]]
			var c := v[idx[i + 2]]
			var y := maxf(a.y, maxf(b.y, c.y))
			var large := maxf(absf(a.x), maxf(absf(b.x), absf(c.x)))
			var haut := y > y_min or (cou > 0.0 and y > y_min - 0.08 and large < cou)
			var main := x_min > 0.0 and minf(absf(a.x), minf(absf(b.x), absf(c.x))) > x_min
			if haut or main:
				garde.append_array([idx[i], idx[i + 1], idx[i + 2]])
		arr[Mesh.ARRAY_INDEX] = garde
		for k in [Mesh.ARRAY_CUSTOM0, Mesh.ARRAY_CUSTOM1, Mesh.ARRAY_CUSTOM2, Mesh.ARRAY_CUSTOM3]:
			arr[k] = null
		var fmt: int = source.surface_get_format(s)
		res.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt &Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS)
		res.surface_set_material(s, source.surface_get_material(s))
	_tetes[cle] = res
	return res


static func _teinter(squel: Skeleton3D, prefixe: String, teinte: Color) -> void:
	for m in squel.get_children():
		if not (m is MeshInstance3D) or not String(m.name).begins_with(prefixe):
			continue
		var mi := m as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src := mi.mesh.surface_get_material(i)
			if not (src is BaseMaterial3D) or String(src.resource_name).begins_with("MI_Regular"):
				continue
			var c := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
			c.albedo_color = c.albedo_color * teinte
			mi.set_surface_override_material(i, c)

static func _cheveux(squel: Skeleton3D, noms: Array, couleur: Color, tex := "T_Hair_1_BaseColor.png") -> void:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load(P + tex)
	m.albedo_color = couleur
	m.roughness = 0.8
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
	m.alpha_scissor_threshold = 0.4
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	for nom in noms:
		var h: Node3D = load(P + "%s.gltf" % nom).instantiate()
		for mi in h.find_children("*", "MeshInstance3D", true, false):
			_greffer(mi, squel)
			(mi as MeshInstance3D).material_override = m
		h.free()

static func _visage(squel: Skeleton3D, femme: bool) -> void:
	var corps: Node3D = load(P + ("Superhero_Female_FullBody.gltf" if femme else "Superhero_Male_FullBody.gltf")).instantiate()
	var sq2: Skeleton3D = corps.find_child("Skeleton3D", true, false)
	for mi in sq2.get_children():
		if not (mi is MeshInstance3D):
			continue
		var n := String(mi.name)
		if n.begins_with("Eye"):
			_greffer(mi, squel)
		elif n.begins_with("Super"):
			(mi as MeshInstance3D).mesh = _decouper(mi.mesh, 1.4, 0.62) if femme else _decouper(mi.mesh, 1.58, 0.0, 0.075)
			_greffer(mi, squel)
	corps.free()


static func chasseur(look: int) -> Node3D:
	var femme := look % 2 == 1
	var base: Node3D = load(P + ("Female_Ranger.gltf" if femme else "Male_Peasant.gltf")).instantiate()
	var sq: Skeleton3D = base.find_child("Skeleton3D", true, false)
	_visage(sq, femme)
	var teintes := [Color(0.25, 0.3, 0.45), Color(0.6, 0.2, 0.25), Color(0.2, 0.45, 0.35), Color(0.35, 0.3, 0.6)]
	var cheveux := [Color(0.1, 0.08, 0.08), Color(0.85, 0.85, 0.9), Color(0.55, 0.3, 0.15), Color(0.15, 0.2, 0.45)]
	if femme:
		_cheveux(sq, ["Hair_Long"], cheveux[look], "T_Hair_2_BaseColor.png")
	else:
		_cheveux(sq, ["Hair_Buzzed"], cheveux[look])
	_teinter(sq, "Female_Ranger" if femme else "Male_Peasant", teintes[look])
	return base

static func kang() -> Node3D:
	var base: Node3D = load(P + "Male_Peasant.gltf").instantiate()
	var sq: Skeleton3D = base.find_child("Skeleton3D", true, false)
	_visage(sq, false)
	_cheveux(sq, ["Hair_Buzzed", "Hair_Beard"], Color(0.16, 0.12, 0.1))
	_teinter(sq, "Male_Peasant", Color(0.55, 0.38, 0.28))
	return base


static func esil() -> Node3D:
	var base: Node3D = load(P + "Female_Ranger.gltf").instantiate()
	var sq: Skeleton3D = base.find_child("Skeleton3D", true, false)
	_visage(sq, true)
	_teinter(sq, "Female_Ranger", Color(0.5, 0.32, 0.85))
	return base


static func mira() -> Node3D:
	var base: Node3D = load(P + "Female_Peasant.gltf").instantiate()
	var sq: Skeleton3D = base.find_child("Skeleton3D", true, false)
	_visage(sq, true)
	_cheveux(sq, ["Hair_Buns"], Color(0.85, 0.62, 0.3), "T_Hair_2_BaseColor.png")
	_teinter(sq, "Female_Peasant", Color(0.55, 0.95, 0.65))
	return base
