extends RefCounted
class_name Chars
# Personnages KayKit : modèle + animations partagées (Rig_Medium) + objets en main

static var lib: AnimationLibrary
const LOOPS := ["Idle_A", "Idle_B", "Running_A", "Running_B", "Walking_A", "Walking_B", "Walking_C", "Jump_Idle"]

static func library() -> AnimationLibrary:
	if lib: return lib
	lib = AnimationLibrary.new()
	for f in ["res://assets/heroes/Rig_Medium_General.glb", "res://assets/heroes/Rig_Medium_MovementBasic.glb"]:
		var s: Node = load(f).instantiate()
		var sap: AnimationPlayer = s.find_child("AnimationPlayer", true, false)
		for ln in sap.get_animation_library_list():
			var l: AnimationLibrary = sap.get_animation_library(ln)
			for n in l.get_animation_list():
				var a: Animation = l.get_animation(n)
				a.loop_mode = Animation.LOOP_LINEAR if n in LOOPS else Animation.LOOP_NONE
				if not lib.has_animation(n): lib.add_animation(n, a)
		s.free()
	return lib

# Retourne {root, ap, skel}
static func make(path: String) -> Dictionary:
	var model: Node3D = load(path).instantiate()
	var ap := AnimationPlayer.new(); model.add_child(ap); ap.root_node = NodePath("..")
	ap.add_animation_library("", library())
	# pas d'ombre temps réel (sauf le héros) : une ombre douce au sol à la place
	for mi in meshes(model): mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	model.add_child(blob(0.75))
	var skel: Skeleton3D = model.find_child("Skeleton3D", true, false)
	if skel == null:
		for c in model.find_children("*", "Skeleton3D", true, false): skel = c; break
	return {"root": model, "ap": ap, "skel": skel}

static func attach(ch: Dictionary, bone: String, path: String, scale := 1.0) -> Node3D:
	var skel: Skeleton3D = ch.skel
	if skel == null or path == "": return null
	var ba := BoneAttachment3D.new(); ba.bone_name = bone; skel.add_child(ba)
	var o: Node3D = load(path).instantiate(); o.scale = Vector3.ONE * scale; ba.add_child(o)
	return o

# Greffe une pièce d'un autre personnage KayKit (même squelette) : casque, cape, jambes…
static var _src := {}
static func graft(ch: Dictionary, model: String, mesh_name: String, tint: Color) -> void:
	var skel: Skeleton3D = ch.skel
	if skel == null: return
	if not _src.has(model):
		var inst: Node3D = load("res://assets/heroes/%s.glb" % model).instantiate()
		var d := {}
		for mi in inst.find_children("*", "MeshInstance3D", true, false): d[mi.name] = [mi.mesh, mi.skin]
		inst.free(); _src[model] = d
	var e = _src[model].get(mesh_name)
	if e == null: return
	var mi := MeshInstance3D.new(); mi.name = mesh_name; mi.mesh = e[0]; mi.skin = e[1]; mi.set_meta("grafted", true)
	skel.add_child(mi); mi.skeleton = NodePath("..")
	if tint != Color(1, 1, 1):
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate(); m.albedo_color = tint; mi.set_surface_override_material(i, m)

static var blob_mat: StandardMaterial3D
static func blob(r: float) -> MeshInstance3D:
	if blob_mat == null:
		var img := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		for y in 32:
			for x in 32:
				var d := Vector2(x - 15.5, y - 15.5).length() / 16.0
				img.set_pixel(x, y, Color(0, 0, 0, clamp(1.0 - d * d, 0.0, 1.0) * 0.5))
		blob_mat = StandardMaterial3D.new(); blob_mat.albedo_texture = ImageTexture.create_from_image(img)
		blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; blob_mat.render_priority = -1
	var mi := MeshInstance3D.new(); var q := PlaneMesh.new(); q.size = Vector2(r * 2, r * 2); q.material = blob_mat; mi.mesh = q
	mi.position.y = 0.05; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.name = "Blob"
	return mi

static func meshes(n: Node, out: Array = []) -> Array:
	if n is MeshInstance3D and n.name != "Blob": out.append(n)
	for c in n.get_children(): meshes(c, out)
	return out
