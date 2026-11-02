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

static func _graft(skel: Skeleton3D, scene_path: String) -> Array:
	var added := []
	var s: Node = load(scene_path).instantiate()
	var src: Skeleton3D = s.find_child("Skeleton3D", true, false)
	if src == null:
		s.free()
		return added
	for c in src.get_children():
		if c is MeshInstance3D:
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
		if bodymi:
			bodymi.mesh = _head_only(bodymi.mesh)
		var pieces := _graft(skel, OUTFITS[outfit])
		var tint: Color = opts.get("tint", Color.WHITE)
		if tint != Color.WHITE:
			for mi in pieces:
				for i in mi.mesh.get_surface_count():
					var m = mi.mesh.surface_get_material(i)
					if m is StandardMaterial3D and not String(m.resource_name).contains("Regular"):
						var d: StandardMaterial3D = m.duplicate()
						d.albedo_color = tint
						mi.set_surface_override_material(i, d)
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
				var d: StandardMaterial3D = m.duplicate()
				d.albedo_color = hc
				mi.set_surface_override_material(i, d)
	if opts.get("skin_light", false) and outfit == "":
		var body := skel.find_child("SuperHero_*", false, false) as MeshInstance3D
		if body:
			var m: StandardMaterial3D = body.mesh.surface_get_material(0).duplicate()
			var tex := "res://assets/chars/base/T_Superhero_Female_Light_BaseColor.png" if female else "res://assets/chars/base/T_Superhero_Male_Ligh.png"
			m.albedo_texture = load(tex)
			body.set_surface_override_material(0, m)
	var ap := AnimationPlayer.new()
	ap.name = "AnimationPlayer"
	root.add_child(ap)
	ap.add_animation_library("", _lib("res://assets/anims/UAL1_Standard.glb").duplicate())
	ap.add_animation_library("b", _lib("res://assets/anims/UAL2_Standard.glb"))
	return root
