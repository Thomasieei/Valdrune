class_name Modele


static var _hauteurs := {}

const CORRECTION := {"orc_warrior": 0.42}


const CACHER := ["pCylinder"]

const UAL := "res://assets/anims/ual.res"
const NOMS_UAL := {"Idle": "Idle", "Hit": "Hit_Chest", "Death": "Death01", "Attack": "Sword_Attack",
	"Attack2": "Punch_Jab", "Walk": "Walk", "Run": "Jog_Fwd", "Roar": "Idle_No", "Celebrate": "Dance",
	"Talk": "Idle_Talking"}
static var _ual: AnimationLibrary
static var _ual_k := {}

static func _bibliotheque(ratio: float) -> AnimationLibrary:
	var cle := snappedf(ratio, 0.05)
	if absf(cle - 1.0) < 0.04:
		cle = 1.0
	if _ual == null:
		_ual = load(UAL)
	if cle == 1.0:
		return _ual
	if _ual_k.has(cle):
		return _ual_k[cle]

	var lib := AnimationLibrary.new()
	for nom_a in NOMS_UAL.values():
		var a: Animation = _ual.get_animation(nom_a).duplicate(true)
		for i in a.get_track_count():
			if a.track_get_type(i) == Animation.TYPE_POSITION_3D and String(a.track_get_path(i)).ends_with(":pelvis"):
				for k in a.track_get_key_count(i):
					a.track_set_key_value(i, k, a.track_get_key_value(i, k) * cle)
		lib.add_animation(nom_a, a)
	_ual_k[cle] = lib
	return lib

static var _peaux := {}



static func creer(nom: String, hauteur: float, peau := "") -> Node3D:
	var chemin := ("res://assets/%s" % nom) if nom.contains(".") else("res://assets/%s.glb" % nom)
	return preparer(load(chemin).instantiate(), nom, hauteur, peau)


static func preparer(n: Node3D, nom: String, hauteur: float, peau := "") -> Node3D:
	var h: float = _hauteurs.get(nom, -1.0)
	var bas := 0.0
	if h < 0.0:

		var sk: Skeleton3D = n.find_child("Skeleton3D", true, false)
		if sk:
			var t := _chaine(sk, n)
			var mn := INF
			var mx := -INF
			for i in sk.get_bone_count():
				var y := (t * sk.get_bone_global_rest(i).origin).y
				mn = minf(mn, y)
				mx = maxf(mx, y)
			h = (mx - mn) * 1.1
			bas = mn - (mx - mn) * 0.04
		else:
			var b := _boite(n)
			h = b.size.y
			bas = b.position.y
		_hauteurs[nom] = h
		_hauteurs[nom + "_bas"] = bas
	else:
		bas = _hauteurs[nom + "_bas"]
	var k := hauteur / maxf(h, 0.01) * float(CORRECTION.get(nom, 1.0))
	var pivot := Node3D.new()
	pivot.add_child(n)
	n.scale = Vector3.ONE * k
	n.position.y = -bas * k
	var ap := lecteur(pivot)
	var sk0: Skeleton3D = n.find_child("Skeleton3D", true, false)
	if (ap == null or ap.get_animation_list().is_empty()) and sk0 and sk0.find_bone("pelvis") >= 0:
		if ap == null:
			ap = AnimationPlayer.new()
			ap.name = "AnimationPlayer"
			n.add_child(ap)
		var ratio := sk0.get_bone_global_rest(sk0.find_bone("pelvis")).origin.y / 0.96
		ap.add_animation_library(&"", _bibliotheque(ratio))
		ap.set_meta("remap", NOMS_UAL)
		for a in ["Idle", "Walk", "Jog_Fwd", "Idle_Talking", "Dance", "Idle_No"]:
			if ap.has_animation(a):
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	if ap:
		for a in ap.get_animation_list():
			if a in ["Idle", "Walk", "Run", "Sprint", "SwordIdle", "JumpLoop", "Animacion", "Walk_Cycle", "Talk", "Choked", "TeleHold"]:
				ap.get_animation(a).loop_mode = Animation.LOOP_LINEAR
	var tex_peau: Texture2D = null
	if peau != "":
		if not _peaux.has(peau):
			_peaux[peau] = load("res://assets/peaux/%s.png" % peau)
		tex_peau = _peaux[peau]
	for m in pivot.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if CACHER.any(func (c): return String(mi.name).begins_with(c)):
			mi.visible = false
			continue
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var src := mi.get_active_material(s)
			if not (src is BaseMaterial3D):
				continue
			var bm := src as BaseMaterial3D
			var change := false
			var c := bm


			if bm.transparency != BaseMaterial3D.TRANSPARENCY_DISABLED:
				c = bm.duplicate() as BaseMaterial3D
				c.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA_SCISSOR
				c.alpha_scissor_threshold = 0.5
				c.cull_mode = BaseMaterial3D.CULL_BACK
				change = true
			if tex_peau and bm.albedo_texture != null:
				if not change:
					c = bm.duplicate() as BaseMaterial3D
					change = true
				c.albedo_texture = tex_peau
			if change:
				mi.set_surface_override_material(s, c)
	return pivot

static func _chaine(a: Node3D, racine: Node3D) -> Transform3D:
	var t := Transform3D.IDENTITY
	var p: Node = a
	while p != null and p != racine:
		if p is Node3D:
			t = (p as Node3D).transform * t
		p = p.get_parent()
	return t

static func lecteur(n: Node) -> AnimationPlayer:
	return n.find_child("AnimationPlayer", true, false)


static func _boite(n: Node3D) -> AABB:
	var b := AABB()
	var premier := true
	for m in n.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		var t := Transform3D.IDENTITY
		var p: Node = mi
		while p != null and p != n:
			if p is Node3D:
				t = (p as Node3D).transform * t
			p = p.get_parent()
		var bb := t * mi.get_aabb()
		b = bb if premier else b.merge(bb)
		premier = false
	return b


# Les clips sont résolus une seule fois, y compris pour les squelettes UAL.
class Locomotion:
	var lecteur: AnimationPlayer
	var repos: StringName
	var marche: StringName
	var course: StringName
	var sprint: StringName
	var allure := 0

	func _init(ap: AnimationPlayer) -> void:
		lecteur = ap
		if not ap:
			return
		repos = _clip(["Idle", "Animacion"])
		marche = _clip(["Walk", "Walk_Cycle"])
		course = _clip(["Run", "Jog_Fwd", marche])
		sprint = _clip(["Sprint", course])

	func _clip(noms: Array) -> StringName:
		for nom in noms:
			if nom != "" and lecteur.has_animation(nom):
				return nom
		return &""

	func orienter(corps: Node3D, direction: Vector3, vitesse: float, dt: float, action: bool) -> void:
		var inclinaison := 0.0
		if direction.length_squared() > 0.0001:
			var angle := atan2(direction.x, direction.z)
			var ecart := angle_difference(corps.rotation.y, angle)
			corps.rotation.y += ecart * (1.0 - exp(-15.0 * dt))
			if not action:
				# Transfert de poids pendant la courbe, puis retour à la verticale.
				inclinaison = -clampf(ecart, -0.9, 0.9) * clampf(vitesse / 7.5, 0.0, 1.0) * 0.11
		corps.rotation.z = lerpf(corps.rotation.z, inclinaison, 1.0 - exp(-10.0 * dt))

	func avancer(vitesse: float, dt: float, arme := false) -> void:
		if not lecteur:
			return
		var ancienne := allure
		if vitesse < (0.11 if allure > 0 else 0.22):
			allure = 0
		elif vitesse > (6.65 if allure == 3 else 7.1) and sprint != course:
			allure = 3
		elif vitesse > (3.25 if allure >= 2 else 3.85):
			allure = 2
		else:
			allure = 1
		var clip := repos
		var cadence := 1.0
		match allure:
			0:
				if arme and lecteur.has_animation("SwordIdle"):
					clip = &"SwordIdle"
			1:
				clip = marche
				cadence = clampf(vitesse / 2.35, 0.32, 1.48)
			2:
				clip = course
				var reference := 2.9 if course == marche else 5.4
				cadence = clampf(vitesse / reference, 0.75, 1.85)
			3:
				clip = sprint
				cadence = clampf(vitesse / 7.5, 0.85, 1.65)
		if clip == &"":
			return
		if lecteur.current_animation != clip:
			var phase := -1.0
			if ancienne > 0 and allure > 0 and lecteur.current_animation in [marche, course, sprint] and lecteur.current_animation_length > 0:
				phase = fposmod(lecteur.current_animation_position / lecteur.current_animation_length, 1.0)
			lecteur.play(clip, 0.16)
			if phase >= 0.0:
				lecteur.seek(phase * lecteur.get_animation(clip).length)
		lecteur.speed_scale = lerpf(lecteur.speed_scale, cadence, 1.0 - exp(-16.0 * dt))

static func jouer(ap: AnimationPlayer, nom: String, vitesse := 1.0, fondu := 0.15) -> float:
	if ap == null:
		return 0.0
	if not ap.has_animation(nom):
		var alt: String = {"Idle": "Animacion", "Walk": "Walk_Cycle", "Run": "Walk_Cycle"}.get(nom, "")
		if alt != "" and ap.has_animation(alt):
			nom = alt
	if not ap.has_animation(nom):
		var r: Dictionary = ap.get_meta("remap", {})
		nom = r.get(nom, "")
		if nom == "" or not ap.has_animation(nom):
			return 0.0
	if ap.current_animation == nom and ap.get_animation(nom).loop_mode != Animation.LOOP_NONE:
		ap.speed_scale = vitesse
		return 0.0
	ap.play(nom, fondu)
	ap.speed_scale = vitesse
	return ap.get_animation(nom).length / vitesse



const ARMES := {
	"dague": {"long": 0.55, "inv": true},
	"katana": {"long": 1.05, "inv": true},
	"hache": {"long": 0.8, "inv": true},
	"lame": {"long": 1.0, "inv": false},
	"sl_sword": {"long": 1.1, "inv": false},
}
static var reglage_main := {"rot": Vector3(90, 0, 0), "pos": Vector3(0, 0.02, 0.03)}


static func arme(nom: String) -> Node3D:
	var r: Dictionary = ARMES.get(nom, {"long": 0.9, "inv": false})
	var n: Node3D = load("res://assets/%s.glb" % nom).instantiate()
	var b := _boite(n)
	var axes := [b.size.x, b.size.y, b.size.z]
	var grand := axes.find(axes.max())
	var k: float = r["long"] / maxf(axes[grand], 0.0001)
	var pivot := Node3D.new()
	var centre := b.get_center()

	var bas := Basis.IDENTITY
	if grand == 0:
		bas = Basis(Vector3(0, 0, 1), deg_to_rad(90))
	elif grand == 2:
		bas = Basis(Vector3(1, 0, 0), deg_to_rad(-90))
	if r["inv"]:
		bas = Basis(Vector3(0, 0, 1), PI) * bas
	var t := Transform3D(bas.scaled(Vector3.ONE * k), Vector3.ZERO)

	var c := t * centre
	t.origin = -c + Vector3(0, r["long"] * 0.38, 0)
	var conteneur := Node3D.new()
	conteneur.transform = t
	conteneur.add_child(n)
	pivot.add_child(conteneur)
	for m in pivot.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
	return pivot
