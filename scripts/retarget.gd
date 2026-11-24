class_name Retarget
extends RefCounted
# Applique les clips Motifect (rotations globales, T-pose, Y haut, +Z devant) sur n'importe quel squelette Mixamo.
# Utilisation : Modele.jouer(ap, "X_jab_right") -> le clip est construit à la volée sur le squelette du modèle.

const SRC := ["Hips", "Spine", "Spine1", "Spine2", "Neck", "Head", "LeftShoulder", "LeftArm", "LeftForeArm", "LeftHand",
	"RightShoulder", "RightArm", "RightForeArm", "RightHand", "LeftUpLeg", "LeftLeg", "LeftFoot", "LeftToeBase",
	"RightUpLeg", "RightLeg", "RightFoot", "RightToeBase"]
const HAUT_SRC := 0.915

static var _donnees := {}
static var _anims := {}
static var erreur := ""


static func _nettoyer(n: String) -> String:
	var s := n.replace("mixamorig:", "").replace("mixamorig_", "")
	var i := s.rfind("_")
	if i > 0 and s.substr(i + 1).is_valid_int():
		s = s.substr(0, i)
	return s


static func _charger(clip: String) -> Dictionary:
	if _donnees.has(clip):
		return _donnees[clip]
	var d := {}
	var chemin := "res://assets/mo/%s.mot" % clip
	if FileAccess.file_exists(chemin):
		var p = JSON.parse_string(FileAccess.get_file_as_string(chemin))
		if p is Dictionary:
			d = p
	_donnees[clip] = d
	return d


static func _rel(n: Node3D, racine: Node) -> Transform3D:
	var t := Transform3D.IDENTITY
	var c: Node = n
	while c != null and c != racine:
		if c is Node3D:
			t = (c as Node3D).transform * t
		c = c.get_parent()
	return t


static func _visiter(sk: Skeleton3D, i: int, ordre: Array, vus: Dictionary) -> void:
	if vus.has(i):
		return
	vus[i] = true
	var p := sk.get_bone_parent(i)
	if p >= 0:
		_visiter(sk, p, ordre, vus)
	ordre.append(i)


# Ajoute l'animation « X_<clip> » au lecteur. Renvoie false si impossible.
static func ajouter(ap: AnimationPlayer, nom: String) -> bool:
	var clip := nom.substr(2)
	var d := _charger(clip)
	if d.is_empty():
		erreur = "donnees vides " + clip + " existe=" + str(FileAccess.file_exists("res://assets/mo/%s.mot" % clip))
		return false
	var racine := ap.get_node_or_null(ap.root_node)
	if racine == null:
		erreur = "racine null " + str(ap.root_node)
		return false
	var sk: Skeleton3D = null
	for c in racine.find_children("*", "Skeleton3D", true, false):
		sk = c as Skeleton3D
		break
	if sk == null or sk.get_bone_count() < 20:
		erreur = "squelette absent sous " + str(racine.get_path())
		return false
	var cle := "%s|%d|%s|%s" % [racine.get_path_to(sk), sk.get_bone_count(), sk.get_bone_name(0), clip]
	var anim: Animation = _anims.get(cle)
	if anim == null:
		anim = _construire(sk, racine, d)
		if anim == null:
			erreur = "construire null " + cle + " os0-5=" + str([sk.get_bone_name(1), sk.get_bone_name(2), sk.get_bone_name(3)])
			return false
		_anims[cle] = anim
	var lib: AnimationLibrary
	if ap.has_animation_library(""):
		lib = ap.get_animation_library("")
	else:
		lib = AnimationLibrary.new()
		ap.add_animation_library("", lib)
	lib.add_animation(nom, anim)
	return true


static func _construire(sk: Skeleton3D, racine: Node, d: Dictionary) -> Animation:
	var nb := sk.get_bone_count()
	var T := Transform3D.IDENTITY
	if sk != racine:
		T = _rel(sk, racine)
	var Rs: Basis = T.basis.orthonormalized()
	var noms := {}
	for i in nb:
		noms[_nettoyer(sk.get_bone_name(i))] = i
	if not noms.has("Hips"):
		return null
	var ih: int = noms["Hips"]
	var srcidx := PackedInt32Array()
	srcidx.resize(nb)
	srcidx.fill(-1)
	for k in SRC.size():
		if noms.has(SRC[k]):
			srcidx[noms[SRC[k]]] = k
	var ordre: Array = []
	var vus := {}
	for i in nb:
		_visiter(sk, i, ordre, vus)
	# os actifs : Hips et ses descendants
	var actif := PackedByteArray()
	actif.resize(nb)
	for i in ordre:
		var p := sk.get_bone_parent(i)
		if i == ih or (p >= 0 and actif[p] == 1):
			actif[i] = 1
	var repos: Array = []
	repos.resize(nb)
	for i in nb:
		repos[i] = Rs * sk.get_bone_global_rest(i).basis.orthonormalized()
	var n: int = int(d["n"])
	var fps: float = float(d.get("fps", 30))
	var q: Array = d["q"]
	var h: Array = d["h"]
	var anim := Animation.new()
	anim.length = maxf(0.05, float(n - 1) / fps)
	anim.loop_mode = Animation.LOOP_NONE
	var chemin_sk := str(racine.get_path_to(sk))
	var pistes := PackedInt32Array()
	pistes.resize(nb)
	pistes.fill(-1)
	for i in ordre:
		if actif[i] == 1:
			var tr := anim.add_track(Animation.TYPE_ROTATION_3D)
			anim.track_set_path(tr, NodePath("%s:%s" % [chemin_sk, sk.get_bone_name(i)]))
			pistes[i] = tr
	var tr_pos := anim.add_track(Animation.TYPE_POSITION_3D)
	anim.track_set_path(tr_pos, NodePath("%s:%s" % [chemin_sk, sk.get_bone_name(ih)]))
	var rest_h: Vector3 = T * sk.get_bone_global_rest(ih).origin
	var k_ech: float = rest_h.y / HAUT_SRC
	var T_inv := T.affine_inverse()
	var p_hips := sk.get_bone_parent(ih)
	var rest_parent := Transform3D.IDENTITY
	if p_hips >= 0:
		rest_parent = sk.get_bone_global_rest(p_hips).affine_inverse()
	var derive_x: float = float(h[(n - 1) * 3])
	var derive_z: float = float(h[(n - 1) * 3 + 2])
	var nj := SRC.size()
	var Ga: Array = []
	Ga.resize(nb)
	for f in n:
		var t := float(f) / fps
		for i in ordre:
			var p := sk.get_bone_parent(i)
			var s := srcidx[i]
			if s >= 0:
				var o := (f * nj + s) * 4
				var qs := Quaternion(float(q[o]), float(q[o + 1]), float(q[o + 2]), float(q[o + 3])).normalized()
				Ga[i] = Basis(qs) * repos[i]
			elif p >= 0:
				Ga[i] = (Ga[p] as Basis) * ((repos[p] as Basis).inverse() * (repos[i] as Basis))
			else:
				Ga[i] = repos[i]
			if pistes[i] >= 0:
				var loc: Basis
				if p >= 0:
					loc = (Ga[p] as Basis).inverse() * (Ga[i] as Basis)
				else:
					loc = Rs.inverse() * (Ga[i] as Basis)
				anim.rotation_track_insert_key(pistes[i], t, loc.orthonormalized().get_rotation_quaternion())
		var u := float(f) / maxf(1.0, float(n - 1))
		var pm := Vector3(
			rest_h.x + (float(h[f * 3]) - derive_x * u) * k_ech,
			float(h[f * 3 + 1]) * k_ech,
			rest_h.z + (float(h[f * 3 + 2]) - derive_z * u) * k_ech)
		anim.position_track_insert_key(tr_pos, t, rest_parent * (T_inv * pm))
	return anim
