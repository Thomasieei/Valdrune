class_name Joueur
extends CharacterBody3D




const VITESSE := 7.5
const PORTEE := 2.0
const CADENCE := 0.55
const CHANCE_CRIT := 0.15

var entree := Vector2.ZERO
var cible: Monstre = null
var _corps: Node3D
var _ap: AnimationPlayer
var _coup_t := 0.0
var _coup_n := 0
var _anim_coup := 0.0
var _dernier_coup := 0
var camera_lacet := 0.0
var _main: BoneAttachment3D
var _arme_vue := ""
var invulnerable := 0.0
var _dash := Vector3.ZERO
var _dash_t := 0.0
var _pause_auto := 0.0
var _auto_t := 0.0
var _progres_t := 0.0
var _derniere_dist := INF
var _ignores: Array = []

func _visible(m: Monstre) -> bool:
	var q := PhysicsRayQueryParameters3D.create(global_position + Vector3(0, 1.2, 0), m.global_position + Vector3(0, 1.0, 0))
	q.exclude = [get_rid()]
	q.collision_mask = 1
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if r.is_empty():
		return true
	var col: Object = r["collider"]
	return col is Node and (col as Node).get_parent() == m
var recharges := {"esquive": 0.0, "brise": 0.0, "cri": 0.0, "domaine": 0.0, "echange": 0.0, "pacte": 0.0}


func _maj_arme() -> void:
	var a := Partie.arme()
	var nom: String = Partie.base(a)["modele"] if not a.is_empty() else ""
	var effet: String = Partie.base(a).get("effet", "") if not a.is_empty() else ""
	if nom + effet == _arme_vue:
		return
	_arme_vue = nom + effet
	for c in _main.get_children():
		c.queue_free()
	if nom == "":
		return
	var w := Modele.arme(nom)
	if effet == "unique":

		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.76, 0.3)
			m.metallic = 0.9
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(1.0, 0.6, 0.15)
			m.emission_energy_multiplier = 0.35
			(mi as MeshInstance3D).material_override = m
			(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.7, 0.25, 1.0), 2.2)
	elif effet == "shiny":
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.85, 0.35, 1.0), 3.0)
		w.add_child(_etincelles(Color(0.9, 0.55, 1.0)))
	if effet != "":
		var lum := OmniLight3D.new()
		lum.light_color = Color(0.75, 0.4, 1.0) if effet == "shiny" else Color(1.0, 0.7, 0.35)
		lum.light_energy = 0.9
		lum.omni_range = 2.5
		lum.position = Vector3(0, 0.6, 0)
		w.add_child(lum)
	var porte := Node3D.new()
	porte.name = "Prise"
	porte.rotation_degrees = Modele.reglage_main["rot"]
	porte.position = Modele.reglage_main["pos"]
	porte.add_child(w)
	_main.add_child(porte)

	var sk: Skeleton3D = _main.get_parent()
	var ech := sk.global_transform.basis.get_scale().x
	porte.scale = Vector3.ONE / maxf(ech, 0.0001)

func _ready() -> void:
	var forme := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	forme.shape = cap
	forme.position.y = 0.9
	add_child(forme)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	_corps = Modele.creer("hero", 1.85)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)
	Modele.jouer(_ap, "Idle")
	var sk: Skeleton3D = _corps.find_child("Skeleton3D", true, false)
	_main = BoneAttachment3D.new()
	_main.name = "MainDroite"
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		if bn.ends_with("RightHand") or bn.contains("RightHand_"):
			_main.bone_name = bn
			break
	sk.add_child(_main)
	Partie.change.connect(_maj_arme)
	_maj_arme()

func viser(m: Monstre) -> void:
	cible = m
	if m:
		Fx.son("select", -6.0)


func cible_devant(monstres: Array, portee := 16.0) -> Monstre:
	var avant := _corps.global_transform.basis.z
	avant.y = 0
	avant = avant.normalized()
	var mieux: Monstre = null
	var score := INF
	for m in monstres:
		if not is_instance_valid(m) or m.mort or m.allie:
			continue
		var v: Vector3 = m.global_position - global_position
		v.y = 0
		var d: float = v.length()
		if d > portee:
			continue
		var face: float = avant.dot(v.normalized()) if d > 0.1 else 1.0
		var s: float = d * (2.2 - face)
		if s < score:
			score = s
			mieux = m
	return mieux

func _physics_process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_physics_process_reel(dt)
	Partie.prof["joueur"] = int(Partie.prof.get("joueur", 0)) + Time.get_ticks_usec() - t0

func _physics_process_reel(dt: float) -> void:
	var dir := Vector3.ZERO
	if entree.length() > 0.08:
		var avant := Vector3(- sin(camera_lacet), 0, -cos(camera_lacet))
		var droite := Vector3(cos(camera_lacet), 0, -sin(camera_lacet))
		dir = droite * entree.x + avant * entree.y
		if dir.length() > 1.0:
			dir = dir.normalized()
		if entree.length() > 0.5:
			cible = null
	if entree.length() > 0.2:
		_pause_auto = 1.5
	_pause_auto -= dt
	if Partie.auto_attaque and _pause_auto <= 0.0 and (cible == null or not is_instance_valid(cible) or cible.mort) and get_parent().action_proche().is_empty():
		_auto_t -= dt
		if _auto_t <= 0.0:
			_auto_t = 0.4
			var c0 := cible_devant(get_parent().monstres.filter(func (m): return not m in _ignores), 9.0)
			if c0 and _visible(c0):
				cible = c0
				_progres_t = 0.0
				_derniere_dist = INF
	if Partie.auto_attaque and cible and is_instance_valid(cible) and not cible.mort:
		var dd := global_position.distance_to(cible.global_position)
		if dd > PORTEE + cible.haut() * 0.25 + 0.5:
			_progres_t += dt
			if _progres_t > 1.0:
				if dd > _derniere_dist - 0.5:
					_ignores.append(cible)
					get_tree().create_timer(6.0).timeout.connect(func (): _ignores.pop_front())
					cible = null
				_progres_t = 0.0
				_derniere_dist = dd
	var en_combat := cible != null and is_instance_valid(cible) and not cible.mort
	if cible and (not is_instance_valid(cible) or cible.mort):
		cible = null
	var distance := INF
	if en_combat:
		var v := cible.global_position - global_position
		v.y = 0
		distance = v.length() - cible.haut() * 0.25
		if distance > PORTEE and dir == Vector3.ZERO:
			dir = v.normalized()
	for k in recharges:
		recharges[k] = maxf(0.0, recharges[k] - dt)
	_arme_monarque(dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	var vit := VITESSE * Partie.vitesse()
	velocity.x = dir.x * vit
	velocity.z = dir.z * vit
	if _dash_t > 0.0:
		_dash_t -= dt
		velocity.x = _dash.x
		velocity.z = _dash.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - 30.0 * dt
	move_and_slide()

	if dir.length() > 0.1 and is_on_wall():
		_monter_marche(dir)
	_anim_coup -= dt
	if dir.length() > 0.1:
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))
		if _anim_coup <= 0.0:
			Modele.jouer(_ap, "Run", 1.05 * Partie.vitesse())
	elif en_combat and distance <= PORTEE + 0.3:
		var v2 := cible.global_position - global_position
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v2.x, v2.z), minf(1.0, dt * 16.0))
		_coup_t -= dt
		if _coup_t <= 0.0:
			_coup_t = CADENCE
			if not (Partie.auto_attaque and cible.en_parade()):
				_frapper()
	elif _anim_coup <= 0.0:
		Modele.jouer(_ap, "Idle" if Partie.opts["fourreau"] else "SwordIdle")

const MARCHE_MAX := 0.45
func _monter_marche(dir: Vector3) -> void:
	var haut := Vector3(0, MARCHE_MAX, 0)
	var avance := dir.normalized() * 0.3
	var t := global_transform
	if test_move(t, haut):
		return
	t = t.translated(haut)
	if test_move(t, avance):
		return
	t = t.translated(avance)

	var col := KinematicCollision3D.new()
	if test_move(t, Vector3(0, -MARCHE_MAX - 0.05, 0), col):
		t.origin.y -= col.get_travel().length()
	global_transform = t

func _a(nom: String, repli: String) -> String:
	return nom if _ap and _ap.has_animation(nom) else repli

func animer_arise() -> void:
	if _ap and _ap.has_animation("M_Arise"):
		_anim_coup = Modele.jouer(_ap, "M_Arise", 1.4, 0.05) * 0.8

func _frapper() -> void:
	if Partie.opts["fourreau"]:
		Partie.opts["fourreau"] = false
		maj_fourreau()
		Fx.son("sheath", -2.0)
	_coup_n = (_coup_n + 1) % 3
	var anim: String = ["Slash1", "Slash2", _a(["M_Leap", "M_Spin", "Heavy"][randi() % 3], "Heavy")][_coup_n]
	if _coup_n == 2 and cible and is_instance_valid(cible):
		var w := cible.global_position - global_position
		w.y = 0
		if w.length() > 1.6:
			_dash = w.normalized() * 9.0
			_dash_t = 0.12
	_dernier_coup = Time.get_ticks_msec()
	_anim_coup = Modele.jouer(_ap, anim, (2.3 if anim.begins_with("M_") else 1.7) if _coup_n == 2 else 1.9, 0.06) * 0.9
	Fx.son(["swing1", "swing2", "swing3"][_coup_n], -4.0, randf_range(0.95, 1.08))
	var c := cible
	_arc(_coup_n)
	await get_tree().create_timer(0.16).timeout
	if c == null or not is_instance_valid(c) or c.mort:
		return
	Partie.en_combat()
	var crit := randf() < Partie.chance_crit()
	var lourd := _coup_n == 2
	var deg := Partie.dps_joueur() * CADENCE * (2.0 if crit else 1.0) * randf_range(0.9, 1.1) * (1.6 if lourd else 0.85)
	c.frapper(deg, crit or lourd)
	var v := get_parent()
	if lourd:
		v.secouer(0.3)
		Fx.son("slam", -6.0, 1.3)
	if crit or lourd:
		v.secouer(0.35 if crit else 0.25)
		v.hitstop(0.035)
		v.zoom_impact()
	else:
		v.secouer(0.06)
	Fx.son(["hit1", "hit2", "hit3"][randi() % 3], -2.0 if crit else -5.0)


func competence(k: String) -> String:
	var d: Dictionary = Partie.COMPETENCES[k]
	if k == "domaine":
		if Partie.domaine_actif():
			return "Domaine déjà actif"
		if Partie.charge < 100.0:
			return "Domaine chargé à %d %% — tue des monstres" % int(Partie.charge)
		Partie.charge = 0.0
		_anim_coup = Modele.jouer(_ap, _a("M_Charge", "Cast"), 1.6, 0.05) * 0.9
		Partie.domaine_fin = Partie.temps() + Partie.DUREE_DOMAINE
		Fx.son("arise", 0.0, 0.6)
		Fx.son("portal", -2.0, 0.7)
		Fx.anneau(global_position, Color(0.45, 0.1, 0.9), 14.0)
		Fx.texte(global_position + Vector3(0, 3.2, 0), "DOMAINE DU MONARQUE", Color(0.75, 0.45, 1.0), 2.0, 2.0)
		var v := get_tree().get_first_node_in_group("ville")
		if v:
			v.hud.domaine(Partie.DUREE_DOMAINE)
		return ""
	if recharges[k] > 0.0:
		return "Recharge : %.1f s" % recharges[k]
	if Partie.mana < d["mana"]:
		return "Pas assez de mana (%d)" % int(d["mana"])
	var c := cible
	if k == "brise":
		if c == null or not is_instance_valid(c) or c.mort:
			return "Aucune cible"
		var v := c.global_position - global_position
		v.y = 0
		if v.length() - c.haut() * 0.25 > PORTEE + 1.2:
			return "Trop loin"
	var vil := get_parent()
	if k == "pacte":
		var c2 := cible
		if c2 == null or not is_instance_valid(c2) or c2.mort or c2.allie:
			c2 = cible_devant(vil.monstres, 40.0)
		if c2 == null:
			return "Vise l'ennemi à ensorceler"
		if Partie.mana < d["mana"]:
			return "Pas assez de mana (%d)" % int(d["mana"])
		Partie.depenser_mana(d["mana"])
		recharges[k] = d["cd"]
		_anim_coup = Modele.jouer(_ap, _a("M_Bolt", "Cast"), 1.3, 0.05) * 0.8
		Fx.anneau(c2.global_position, Color(0.3, 1.0, 0.7), 5.0)
		Fx.son("arise", -2.0, 1.3)
		if c2.puissance() > Partie.dps_total():
			Fx.texte(c2.global_position + Vector3(0, c2.haut() + 1.0, 0), "REFUSE LE PACTE", Color(1.0, 0.4, 0.4), 1.4, 1.2)
			return ""
		for p in get_tree().get_nodes_in_group("pactes"):
			if is_instance_valid(p) and not p.mort:
				return "Un seul pacte à la fois"
		cible = null
		if vil.abime and c2.get_parent() != vil.abime:
			c2.reparent(vil.abime)
		c2.pacte()
		Fx.texte(c2.global_position + Vector3(0, c2.haut() + 1.0, 0), "PACTE SCELLÉ", Color(0.4, 1.0, 0.75), 1.6, 1.4)
		return ""
	if k == "echange" and Partie.speciale == "telekinesie":
		var l: Array = vil.monstres.filter(func (m): return is_instance_valid(m) and not m.mort and m.global_position.distance_to(global_position) < 10.0)
		if l.is_empty():
			return "Aucun ennemi à soulever"
		var dt2: Dictionary = Partie.COMPETENCES["telekinesie"]
		if Partie.mana < dt2["mana"]:
			return "Pas assez de mana (%d)" % int(dt2["mana"])
		Partie.depenser_mana(dt2["mana"])
		recharges[k] = dt2["cd"]
		_anim_coup = Modele.jouer(_ap, _a("M_Crush", "Telekinesis"), 1.3, 0.05) * 0.9
		for m in l:
			m.lever()
		Fx.son("portal", -4.0, 1.5)
		vil.hud.menu_telekinesie(l)
		return ""
	if k == "echange":
		var vivantes: Array = vil.ombres.filter(func (o): return not o.mort)
		if vivantes.is_empty():
			return "Aucune ombre à échanger"
		var reference: Vector3 = cible.global_position if c and is_instance_valid(c) and not c.mort else global_position + _corps.global_transform.basis.z * 100.0
		vivantes.sort_custom(func (a, b): return a.global_position.distance_to(reference) < b.global_position.distance_to(reference))
		var o: Node3D = vivantes[0]
		Partie.depenser_mana(d["mana"])
		recharges[k] = d["cd"]
		var ici := global_position
		_anim_coup = Modele.jouer(_ap, _a("M_Blink", "Dash"), 1.8, 0.03) * 0.6
		Fx.anneau(ici, Color(0.5, 0.25, 1.0), 2.0)
		global_position = o.global_position + Vector3(0, 0.3, 0)
		o.global_position = ici
		velocity = Vector3.ZERO
		invulnerable = 0.6
		Fx.anneau(global_position, Color(0.5, 0.25, 1.0), 2.4)
		Fx.son("shadow", -2.0, 1.4)
		return ""
	Partie.depenser_mana(d["mana"])
	Partie.en_combat()
	recharges[k] = d["cd"]
	match k:
		"esquive":
			var dir := Vector3.ZERO
			if entree.length() < 0.2:
				dir = -_corps.global_transform.basis.z
			else:
				var b := Basis(Vector3.UP, camera_lacet)
				dir = b * Vector3(entree.x, 0, -entree.y)
			dir.y = 0
			_dash = dir.normalized() * 13.0
			_dash_t = 0.38
			invulnerable = 0.5
			_trainee(0.38)
			cible = null
			var gauche := _corps.global_transform.basis.x.dot(dir) > 0.0
			Modele.jouer(_ap, _a("M_DashL" if gauche else "M_DashR", "Roll"), 1.5, 0.05)
			_anim_coup = 0.3
			Fx.son("swing2", -2.0, 1.3)
			Fx.anneau(global_position, Color(0.5, 1.0, 0.85), 1.4)
		"brise":
			_anim_coup = Modele.jouer(_ap, _a("M_Slam", "Slam"), 1.3, 0.05) * 0.9
			Fx.son("slam", -2.0)
			_brise_differe(c)
		"cri":
			_anim_coup = Modele.jouer(_ap, _a("M_Fireball", "Cast"), 1.4, 0.05) * 0.8
			Partie.cri_fin = Partie.temps() + Partie.DUREE_CRI
			Fx.son("arise", -2.0, 0.8)
			Fx.anneau(global_position, Color(0.65, 0.3, 1.0), 7.0)
			Fx.texte(global_position + Vector3(0, 2.8, 0), "CRI DU MONARQUE", Color(0.8, 0.55, 1.0), 1.5, 1.4)
	return ""

var _aura_anos: Array = []
var _aura_titre: Node3D = null

func maj_aura_titre() -> void:
	if _aura_titre:
		_aura_titre.queue_free()
		_aura_titre = null
	if Partie.titre == "" or not Partie.TITRES.has(Partie.titre):
		return
	var col: Color = Partie.TITRES[Partie.titre]["couleur"]
	_aura_titre = Node3D.new()
	add_child(_aura_titre)
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.75
	t.outer_radius = 0.85
	anneau.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col, 0.7)
	anneau.material_override = m
	anneau.scale = Vector3(1, 0.05, 1)
	anneau.position.y = 0.06
	_aura_titre.add_child(anneau)
	var p := _etincelles(col)
	p.amount = 16
	p.position = Vector3(0, 0.3, 0)
	_aura_titre.add_child(p)
	var tw := anneau.create_tween().set_loops()
	tw.tween_property(anneau, "rotation:y", TAU, 4.0).from(0.0)

func aura_anos(on: bool) -> void:
	for n in _aura_anos:
		if is_instance_valid(n):
			n.queue_free()
	_aura_anos.clear()
	for mi in _corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.9, 0.05, 0.12), 2.6) if on else null
	if on:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.1, 0.15)
		l.light_energy = 2.5
		l.omni_range = 6.0
		l.position = Vector3(0, 1.4, 0)
		add_child(l)
		_aura_anos.append(l)
		var p := _etincelles(Color(1.0, 0.15, 0.2))
		p.amount = 40
		p.position = Vector3(0, 1.0, 0)
		add_child(p)
		_aura_anos.append(p)

func _trainee(duree: float) -> void:
	var n := 7
	for k in n:
		get_tree().create_timer(duree * k / n).timeout.connect(func ():
			Fx.anneau(global_position + Vector3(0, 0.05, 0), Color(0.45, 0.9, 1.0, 0.8), 0.9 - k * 0.08)
			Fx.texte(global_position + Vector3(randf_range(-0.2, 0.2), 1.0, 0), "·", Color(0.6, 0.95, 1.0), 2.0, 0.35))
	var tw := create_tween()
	tw.tween_property(_corps, "scale", Vector3(1.08, 0.9, 1.08), duree * 0.3)
	tw.tween_property(_corps, "scale", Vector3.ONE, duree * 0.7)

var _eclair_t := 0.0
var _eclair_i := 0

func maj_fourreau() -> void:
	if _main:
		_main.visible = not Partie.opts["fourreau"]
	Modele.jouer(_ap, "Idle" if Partie.opts["fourreau"] else "SwordIdle")

func _arme_monarque(dt: float) -> void:
	if not Partie.opts["monarque"] or Partie.niveau < Partie.NIVEAU_MONARQUE or entree.length() > 0.2 or _dash_t > 0.0:
		return
	_eclair_t -= dt
	if _eclair_t > 0.0:
		return
	_eclair_t = 0.3
	if Partie.mana < Partie.MANA_ECLAIR:
		return
	var l: Array = get_parent().monstres.filter(func (m): return is_instance_valid(m) and not m.mort and not m.allie and m.global_position.distance_to(global_position) < 30.0)
	if l.is_empty():
		return
	_eclair_i = (_eclair_i + 1) % l.size()
	var m: Monstre = l[_eclair_i]
	Partie.depenser_mana(Partie.MANA_ECLAIR)
	Partie.en_combat()
	var depart := global_position
	var v := m.global_position - global_position
	v.y = 0
	var dist := v.length() - (1.2 + m.haut() * 0.25)
	if dist > 0.5:
		# ruée physique (plus de téléportation qui faisait traverser le sol et planter la caméra)
		_dash = v.normalized() * 28.0
		_dash_t = minf(dist / 28.0, 0.3)
	_corps.rotation.y = atan2(v.x, v.z)
	Fx.anneau(depart, Color(1.0, 0.85, 0.3), 0.8)
	Fx.anneau(global_position, Color(1.0, 0.75, 0.2), 1.4)
	_anim_coup = Modele.jouer(_ap, [_a("M_Blink", "Dash"), _a("M_SlashMagic", "Slash1"), "Slash2"][_eclair_i % 3], 2.4, 0.02) * 0.5
	Fx.son("swing2", -6.0, 1.4)
	var crit := randf() < Partie.chance_crit()
	m.frapper(Partie.dps_joueur() * (2.0 if crit else 1.0), crit)

static var _arc_mesh: ArrayMesh

static func _mesh_arc() -> ArrayMesh:
	if _arc_mesh:
		return _arc_mesh
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	for k in n:
		var a0 := deg_to_rad(-75.0 + 150.0 * k / n)
		var a1 := deg_to_rad(-75.0 + 150.0 * (k + 1) / n)
		var f0 := sin(PI * k / n)
		var f1 := sin(PI * (k + 1) / n)
		var p := [Vector3(sin(a0) * 0.8, 0, cos(a0) * 0.8), Vector3(sin(a0) * 1.7, 0, cos(a0) * 1.7), Vector3(sin(a1) * 1.7, 0, cos(a1) * 1.7), Vector3(sin(a1) * 0.8, 0, cos(a1) * 0.8)]
		var c := [Color(1, 1, 1, 0.0), Color(1, 1, 1, f0), Color(1, 1, 1, f1), Color(1, 1, 1, 0.0)]
		for idx in [0, 1, 2, 0, 2, 3]:
			st.set_color(c[idx])
			st.add_vertex(p[idx])
	_arc_mesh = st.commit()
	return _arc_mesh

func _arc(n: int) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = _mesh_arc()
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.vertex_color_use_as_albedo = true
	var o: Dictionary = Partie.arme()
	var col: Color = Partie.COULEURS_RARETE[int(o.get("rarete", 1))] if not o.is_empty() else Color(0.6, 0.85, 1.0)
	m.albedo_color = col.lightened(0.3)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.global_position = global_position + Vector3(0, 1.05, 0) + _corps.global_transform.basis.z * 0.3
	mi.rotation.y = _corps.rotation.y
	mi.rotate_object_local(Vector3.FORWARD, [0.5, -0.5, 0.0][n])
	mi.scale = Vector3.ONE * 0.7
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * 1.2, 0.2).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.22)
	tw.tween_callback(mi.queue_free)

func _brise_differe(cc: Monstre) -> void:
	await get_tree().create_timer(0.3).timeout
	get_parent().secouer(0.6)
	get_parent().hitstop(0.08)
	if is_instance_valid(cc) and not cc.mort:
		cc.briser(Partie.dps_joueur() * CADENCE * 4.0)

func _etincelles(c: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.03, 0.45, 0.03)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 1.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/fx/etincelle.png")
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.55, 0)
	return p
