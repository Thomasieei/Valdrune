class_name CharBuilder
## Assemble un personnage Quaternius : corps de base + tenue + coiffure,
## partageant le squelette universel (65 os), et branche les bibliothèques UAL1 + UAL2.

const BODY_M := "res://assets/chars/base/Superhero_Male_FullBody.gltf"
const BODY_F := "res://assets/chars/base/Superhero_Female_FullBody.gltf"
const OUTFITS := {
	"paysan_h": "res://assets/chars/outfits/Male_Peasant.gltf",
	"paysan_f": "res://assets/chars/outfits/Female_Peasant.gltf",
	"rodeur_h": "res://assets/chars/outfits/Male_Ranger.gltf",
	"rodeur_f": "res://assets/chars/outfits/Female_Ranger.gltf",
}
const HAIR_DIR := "res://assets/chars/hair/"

static var _libs := {}
static var _mats := {}

## Matériau mobile partagé : teinte éventuelle, sans normal map ni spéculaire (moins cher, quasi invisible à cette distance).
static func _mobile_mat(m: Material, tint: Color = Color.WHITE, tex: Texture2D = null) -> Material:
	if not (m is StandardMaterial3D):
		return m
	var key := "%d|%s|%d" % [m.get_instance_id(), tint.to_html(), tex.get_instance_id() if tex else 0]
	if not _mats.has(key):
		var d: StandardMaterial3D = m.duplicate()
		if tint != Color.WHITE:
			d.albedo_color = tint
		if tex:
			d.albedo_texture = tex
		d.normal_enabled = false
		d.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		d.roughness_texture = null
		d.metallic_texture = null
		d.metallic = 0.0
		d.roughness = 0.85
		d.ao_enabled = false
		d.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
		_mats[key] = d
	return _mats[key]
static var _heads := {}

## Ne garde que la tête et le cou du corps de base (le reste est sous la tenue),
## sinon la peau du corps "Superhero" traverse les vêtements prévus pour le corps "Regular".
static func _head_only(mesh: Mesh) -> Mesh:
	if _heads.has(mesh):
		return _heads[mesh]
	var out := ArrayMesh.new()
	for si in mesh.get_surface_count():
		var arr: Array = mesh.surface_get_arrays(si)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx: PackedInt32Array = arr[Mesh.ARRAY_INDEX]
		var keep := PackedInt32Array()
		for t in range(0, idx.size(), 3):
			var ok := true
			for k in 3:
				var p := v[idx[t + k]]
				if p.y < 1.40 or absf(p.x) > 0.24:
					ok = false
					break
			if ok:
				keep.append(idx[t]); keep.append(idx[t + 1]); keep.append(idx[t + 2])
		arr[Mesh.ARRAY_INDEX] = keep
		var fmt: int = mesh.surface_get_format(si)
		out.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr, [], {}, fmt)
		out.surface_set_material(si, mesh.surface_get_material(si))
	_heads[mesh] = out
	return out

static func _lib(path: String) -> AnimationLibrary:
	if not _libs.has(path):
		var s: Node = load(path).instantiate()
		var ap: AnimationPlayer = s.get_node("AnimationPlayer")
		_libs[path] = ap.get_animation_library("")
		s.free()
	return _libs[path]

static func _graft(skel: Skeleton3D, scene_path: String, only: Array = []) -> Array:
	var added := []
	var s: Node = load(scene_path).instantiate()
	var src: Skeleton3D = s.find_child("Skeleton3D", true, false)
	if src == null:
		s.free()
		return added
	for c in src.get_children():
		if c is MeshInstance3D:
			if not only.is_empty():
				var keep := false
				for o in only:
					if String(c.name).contains(o):
						keep = true
				if not keep:
					continue
			c.owner = null
			src.remove_child(c)
			skel.add_child(c)
			c.owner = null
			c.skeleton = NodePath("..")
			added.append(c)
	s.free()
	return added

## opts: {female, outfit, hair, beard, skin_light, tint}
static func build(opts: Dictionary) -> Node3D:
	var female: bool = opts.get("female", false)
	var root: Node3D = load(BODY_F if female else BODY_M).instantiate()
	var skel: Skeleton3D = root.get_node("Armature/Skeleton3D")
	var outfit: String = opts.get("outfit", "")
	if outfit != "":
		var bodymi := skel.find_child("SuperHero_*", false, false) as MeshInstance3D
		var only: Array = opts.get("pieces", [])
		if bodymi and only.is_empty():
			bodymi.mesh = _head_only(bodymi.mesh)
		var pieces := _graft(skel, OUTFITS[outfit], only)
		var tint: Color = opts.get("tint", Color.WHITE)
		if tint != Color.WHITE:
			for mi in pieces:
				for i in mi.mesh.get_surface_count():
					var m = mi.mesh.surface_get_material(i)
					if m is StandardMaterial3D and not String(m.resource_name).contains("Regular"):
						mi.set_surface_override_material(i, _mobile_mat(m, tint))
	var hair: String = opts.get("hair", "Hair_SimpleParted" if not female else "Hair_Long")
	var hc: Color = opts.get("hair_color", [Color(0.28, 0.18, 0.10), Color(0.12, 0.09, 0.07), Color(0.62, 0.45, 0.22), Color(0.45, 0.20, 0.10)][randi() % 4])
	var hair_meshes := []
	if hair != "" and not (outfit.begins_with("rodeur")):
		hair_meshes += _graft(skel, HAIR_DIR + hair + ".gltf")
	if opts.get("beard", false):
		hair_meshes += _graft(skel, HAIR_DIR + "Hair_Beard.gltf")
	for e in ["Eyebrows"]:
		var eb := skel.find_child(e, false, false)
		if eb is MeshInstance3D:
			hair_meshes.append(eb)
	for mi in hair_meshes:
		for i in mi.mesh.get_surface_count():
			var m = mi.mesh.surface_get_material(i)
			if m is StandardMaterial3D:
				mi.set_surface_override_material(i, _mobile_mat(m, hc))
	if opts.get("skin_light", false) and outfit == "":
		var body := skel.find_child("SuperHero_*", false, false) as MeshInstance3D
		if body:
			var tex := "res://assets/chars/base/T_Superhero_Female_Light_BaseColor.png" if female else "res://assets/chars/base/T_Superhero_Male_Ligh.png"
			body.set_surface_override_material(0, _mobile_mat(body.mesh.surface_get_material(0), Color.WHITE, load(tex)))
	_merge(skel, opts.get("hero", false))
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.add_animation_library("", _lib("res://assets/anims/UAL1_Standard.glb"))
	ap.add_animation_library("b", _lib("res://assets/anims/UAL2_Standard.glb"))
	return root


## Fusionne toutes les pièces du personnage (tête, tenue, cheveux…) en UN maillage skinné,
## une surface par matériau : ~12 appels de rendu par personnage deviennent ~4.
static func _merge(skel: Skeleton3D, hero := false) -> void:
	var pieces: Array = []
	for c in skel.get_children():
		if c is MeshInstance3D and c.mesh != null and c.skin != null:
			pieces.append(c)
	if pieces.size() < 2:
		return
	var nb := skel.get_bone_count()
	var binds: Array = []
	binds.resize(nb)
	var maps := {}
	for mi in pieces:
		var sk: Skin = mi.skin
		var mp := PackedInt32Array()
		mp.resize(sk.get_bind_count())
		for i in sk.get_bind_count():
			var b := sk.get_bind_bone(i)
			var nm := String(sk.get_bind_name(i))
			if nm != "":
				b = skel.find_bone(nm)
			mp[i] = maxi(b, 0)
			if b >= 0 and binds[b] == null:
				binds[b] = sk.get_bind_pose(i)
		maps[mi] = mp
	var skin := Skin.new()
	for b in nb:
		skin.add_bind(b, binds[b] if binds[b] != null else skel.get_bone_global_rest(b).affine_inverse())
	var groups := {}   # clé -> {mat, use8, v, n, uv, bones, weights, idx}
	for mi in pieces:
		var mesh: Mesh = mi.mesh
		var mp: PackedInt32Array = maps[mi]
		for si in mesh.get_surface_count():
			var arr: Array = mesh.surface_get_arrays(si)
			if arr[Mesh.ARRAY_BONES] == null:
				continue
			var fmt: int = mesh.surface_get_format(si)
			var use8: bool = (fmt & Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS) != 0
			var mat: Material = mi.get_active_material(si)
			var key := "%d|%s" % [mat.get_instance_id() if mat else 0, use8]
			if not groups.has(key):
				groups[key] = {"mat": mat, "use8": use8, "v": PackedVector3Array(), "n": PackedVector3Array(), "uv": PackedVector2Array(), "b": PackedInt32Array(), "w": PackedFloat32Array(), "i": PackedInt32Array()}
			var g: Dictionary = groups[key]
			var base: int = g["v"].size()
			var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
			g["v"].append_array(v)
			var nrm = arr[Mesh.ARRAY_NORMAL]
			if nrm != null and nrm.size() == v.size():
				g["n"].append_array(nrm)
			else:
				for k in v.size(): g["n"].append(Vector3.UP)
			var uv = arr[Mesh.ARRAY_TEX_UV]
			if uv != null and uv.size() == v.size():
				g["uv"].append_array(uv)
			else:
				for k in v.size(): g["uv"].append(Vector2.ZERO)
			var bones: PackedInt32Array = arr[Mesh.ARRAY_BONES]
			for k in bones.size():
				var bi := bones[k]
				bones[k] = mp[bi] if bi < mp.size() else 0
			g["b"].append_array(bones)
			g["w"].append_array(arr[Mesh.ARRAY_WEIGHTS])
			var idx = arr[Mesh.ARRAY_INDEX]
			if idx == null or idx.size() == 0:
				idx = PackedInt32Array(range(v.size()))
			for k in idx.size():
				g["i"].append(idx[k] + base)
	var im := ImporterMesh.new()
	var mats: Array = []
	for key in groups:
		var g: Dictionary = groups[key]
		var a := []
		a.resize(Mesh.ARRAY_MAX)
		a[Mesh.ARRAY_VERTEX] = g["v"]
		a[Mesh.ARRAY_NORMAL] = g["n"]
		a[Mesh.ARRAY_TEX_UV] = g["uv"]
		a[Mesh.ARRAY_BONES] = g["b"]
		a[Mesh.ARRAY_WEIGHTS] = g["w"]
		a[Mesh.ARRAY_INDEX] = g["i"]
		var flags := Mesh.ARRAY_FLAG_USE_8_BONE_WEIGHTS if g["use8"] else 0
		im.add_surface(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, null, "", flags)
		mats.append(_mobile_mat(g["mat"]) if g["mat"] else null)
	# niveaux de détail automatiques : le personnage se simplifie avec la distance
	var bone_xf: Array = []
	for b in nb:
		bone_xf.append(skel.get_bone_global_rest(b))
	im.generate_lods(25.0, 60.0, bone_xf)
	var am: ArrayMesh = im.get_mesh()
	if not hero:
		# PNJ : on part directement du premier niveau simplifié (~moitié des triangles)
		var light := ArrayMesh.new()
		for si in im.get_surface_count():
			var a: Array = im.get_surface_arrays(si)
			if im.get_surface_lod_count(si) > 0:
				a[Mesh.ARRAY_INDEX] = im.get_surface_lod_indices(si, 0)
			light.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, a, [], {}, im.get_surface_format(si))
		am = light
	for mi in pieces:
		skel.remove_child(mi)
		mi.queue_free()
	var out := MeshInstance3D.new()
	out.name = "Corps"
	out.mesh = am
	for i in mats.size():
		out.set_surface_override_material(i, mats[i])
	out.skin = skin
	skel.add_child(out)
	out.skeleton = NodePath("..")
	if not hero:
		out.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
