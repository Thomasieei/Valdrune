class_name Chasseur
extends CharacterBody3D

# Chasseur IA : progresse comme le joueur (même monstres, même XP, mêmes donjons).
# mode "ville" : chasse en ville · "donjon" : suit les salles du donjon de groupe.

var d: Dictionary
var ville: Node
var mode := "ville"
var donjon: Donjon = null
var cible: Monstre = null
var _corps: Node3D
var _ap: AnimationPlayer
var _plaque: Label3D
var _choix_t := 0.0
var _coup_t := 0.0
var _bloque_t := 0.0
const MARCHE := 1.65
const COURSE := 3.8
var _chemin := PackedVector3Array()
var _etape := 0
var _but_chemin := Vector3.INF
var _recalcul_t := 0.0
var _cible_bloquee: Monstre
var _eviter_t := 0.0
var _depart_sur_rue := false
var _place_groupe := 0
var _derniere_pos := Vector3.ZERO
var _activite_t := 0.0
var _absent_t := 0.0
var _errance := Vector3.ZERO

func _ready() -> void:
	var forme := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.3
	cap.height = 1.7
	forme.shape = cap
	forme.position.y = 0.85
	add_child(forme)
	collision_layer = 0
	collision_mask = 1
	floor_snap_length = 0.5
	_corps = Modele.preparer(Apparence.chasseur(int(d["look"])), "chasseur_%d" % int(d["look"]), 1.8)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)
	Modele.jouer(_ap, "Idle")
	var sk: Skeleton3D = _corps.find_child("Skeleton3D", true, false)
	if sk:
		for i in sk.get_bone_count():
			var bn := sk.get_bone_name(i).to_lower()
			if bn == "hand_r" or bn.ends_with("righthand") or bn == "hand.r":
				var main := BoneAttachment3D.new()
				main.bone_name = sk.get_bone_name(i)
				sk.add_child(main)
				var prise := Node3D.new()
				prise.rotation_degrees = Modele.reglage_main["rot"]
				prise.position = Modele.reglage_main["pos"]
				prise.add_child(Modele.arme(["katana", "dague", "hache", "lame"][int(d["look"]) % 4]))
				main.add_child(prise)
				prise.scale = Vector3.ONE / maxf(sk.global_transform.basis.get_scale().x, 0.0001) if sk.is_inside_tree() else Vector3.ONE
				break
	_plaque = Label3D.new()
	_plaque.font = Ui.police
	_plaque.font_size = 24
	_plaque.outline_size = 8
	_plaque.pixel_size = 0.0016
	_plaque.fixed_size = true
	_plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plaque.position.y = 2.25
	_plaque.visibility_range_end = 40.0
	add_child(_plaque)
	_maj_plaque()
	_activite_t = randf_range(120.0, 480.0)

func _maj_plaque() -> void:
	_plaque.text = "%s  [%s]\nNiv. %d" % [d["nom"], Partie.RANGS[int(d["rang"])], int(d["niveau"])]
	_plaque.modulate = Color(1.0, 0.85, 0.4) if d.get("premium", false) else Color(0.55, 0.9, 1.0)

func _valide(m) -> bool:
	return m != null and is_instance_valid(m) and not m.mort

func _choisir_ville() -> void:
	if ville.raid_boss != _cible_bloquee and ville.raid_boss and is_instance_valid(ville.raid_boss) and not ville.raid_boss.mort:
		cible = ville.raid_boss
		return
	var dps := Partie.bot_dps(d)
	var mieux: Monstre = null
	var score := -INF
	var pris := {}
	for c in ville.chasseurs:
		if c != self and _valide(c.cible):
			pris[c.cible] = int(pris.get(c.cible, 0)) + 1
	for m in ville.monstres:
		if not _valide(m) or m == _cible_bloquee or m.allie or m.sans_chrono or m.e.get("lieu", "") != "" or m == ville.joueur.cible or int(pris.get(m, 0)) >= 2:
			continue
		var st: Dictionary = Partie.stats_monstre(m.espece, m.elite, m.mult)
		if st["pv"] / dps > st["temps"] * 0.95:
			continue
		var dist: float = m.global_position.distance_to(global_position)
		var s: float = st["xp"] / (st["pv"] / dps + 4.0 + dist / 7.0)
		if s > score:
			score = s
			mieux = m
	cible = mieux

func _choisir_donjon() -> void:
	cible = null
	if donjon.salle >= donjon._par_salle.size():
		return
	var mieux := INF
	for m in donjon._par_salle[donjon.salle]:
		if _valide(m):
			var dd: float = m.global_position.distance_to(global_position)
			if dd < mieux:
				mieux = dd
				cible = m

func _destination() -> Vector3:
	if mode == "guide":
		return ville.guide_destination()
	if mode in ["vers_portail", "vers_groupe"]:
		return ville.portail.global_position
	if mode == "donjon":
		var c := donjon.centre(mini(donjon.salle, 5))
		var dans_salle := absf(global_position.z - c.z) < Donjon.DEMI - 0.5
		if not dans_salle:
			# on suit le couloir central, jamais à travers les murs
			var lane := Vector3(Donjon.ORIGINE.x + (get_index() % 3 - 1) * 1.2, global_position.y, c.z)
			if absf(global_position.x - lane.x) > 1.0:
				return Vector3(lane.x, global_position.y, global_position.z)
			return lane
		if _valide(cible):
			return cible.global_position
		return c + Vector3((get_index() % 3 - 1) * 2.0, 0, -4.0)
	if _valide(cible):
		return cible.global_position
	if _errance == Vector3.ZERO or global_position.distance_to(_errance) < 2.0:
		var p: Array = ville.POSTES_V.pick_random()
		_errance = Vector3(p[1], global_position.y, p[2]) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	return _errance

func _direction_rue(but: Vector3, dt: float) -> Vector3:
	var carte := get_world_3d().navigation_map
	if NavigationServer3D.map_get_iteration_id(carte) == 0:
		return Vector3.ZERO
	_recalcul_t -= dt
	if _but_chemin == Vector3.INF or (_recalcul_t <= 0.0 and _but_chemin.distance_squared_to(but) > 2.25):
		_chemin = NavigationServer3D.map_get_path(carte, global_position, but, true)
		_but_chemin = but
		_recalcul_t = 0.8
		_etape = 0
	while _etape < _chemin.size():
		var trajet := _chemin[_etape] - global_position
		trajet.y = 0.0
		if trajet.length_squared() > 0.16:
			return trajet.normalized()
		_etape += 1
	return Vector3.ZERO

func _physics_process(dt: float) -> void:
	if _depart_sur_rue:
		var carte := get_world_3d().navigation_map
		if NavigationServer3D.map_get_iteration_id(carte) == 0:
			return
		var sol := Vector3(global_position.x, 0, global_position.z)
		global_position = NavigationServer3D.map_get_closest_point(carte, sol) + Vector3.UP * 0.05
		_derniere_pos = global_position
		_depart_sur_rue = false
	if mode == "absent":
		_absent_t -= dt
		if _absent_t <= 0.0:
			Partie.bot_fin_activite(d)
			mode = "ville"
			visible = global_position.distance_squared_to(ville.joueur.global_position) < 85.0 * 85.0
			collision_mask = 1
			_but_chemin = Vector3.INF
			_maj_plaque()
		return
	_coup_t = maxf(0.0, _coup_t - dt)
	_eviter_t -= dt
	if _eviter_t <= 0.0:
		_cible_bloquee = null
	if mode == "ville":
		_activite_t -= dt
		if _activite_t <= 0.0:
			_activite_t = randf_range(300.0, 900.0)
			var act := Partie.bot_activite(d)
			if not act.is_empty():
				mode = "vers_portail"
				_absent_t = float(act["duree"])
				cible = null
	if mode in ["vers_portail", "vers_groupe"]:
		if global_position.distance_to(ville.portail.global_position) <= 2.5:
			if mode == "vers_groupe":
				mode = "donjon"
				visible = true
				placer(donjon.point_depart() + Vector3((_place_groupe - 1) * 1.6, 0, -1.0))
				return
			mode = "absent"
			hide()
			collision_mask = 0
			velocity = Vector3.ZERO
			Fx.anneau(global_position, Color(0.4, 0.7, 1.0), 2.0)
			return
	elif mode != "guide":
		_choix_t -= dt
		if _choix_t <= 0.0:
			_choix_t = 1.0
			if mode == "donjon":
				_choisir_donjon()
			elif not _valide(cible) or (_valide(ville.raid_boss) and cible != ville.raid_boss) or cible.allie or cible == ville.joueur.cible:
				_choisir_ville()
	var but := _destination()
	var distance := global_position.distance_to(but)
	var au_contact := _valide(cible) and not cible.allie and global_position.distance_to(cible.global_position) <= 2.0 + cible.haut() * 0.25
	var dir := Vector3.ZERO
	if not au_contact and distance > 0.6:
		if mode == "donjon":
			dir = Vector3(but.x - global_position.x, 0, but.z - global_position.z).normalized()
		else:
			dir = _direction_rue(but, dt)
	var presse := (_valide(cible) or mode == "vers_groupe") and distance > 5.0
	var vitesse := COURSE if presse else MARCHE
	velocity.x = move_toward(velocity.x, dir.x * vitesse, 10.0 * dt)
	velocity.z = move_toward(velocity.z, dir.z * vitesse, 10.0 * dt)
	velocity.y = -2.0 if is_on_floor() else velocity.y - 30.0 * dt
	move_and_slide()
	if is_on_wall() and is_on_floor() and dir != Vector3.ZERO:
		Joueur.franchir_marche(self, dir)
	var mouvement := get_real_velocity()
	mouvement.y = 0
	if au_contact:
		var w := cible.global_position - global_position
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(w.x, w.z), minf(1.0, dt * 12.0))
		if _coup_t <= 0.0:
			_coup_t = 0.6
			Modele.jouer(_ap, "Attack", 1.6, 0.06)
			var crit := randf() < 0.15
			cible.frapper(Partie.bot_dps(d) * 0.6 * (2.0 if crit else 1.0), crit, "allie" if mode == "donjon" else "bot", self)
	elif mouvement.length() > 0.15:
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(mouvement.x, mouvement.z), minf(1.0, dt * 10.0))
		var course := mouvement.length() > 2.4
		Modele.jouer(_ap, "Run" if course else "Walk", clampf(mouvement.length() / (COURSE if course else MARCHE), 0.4, 1.4))
	else:
		Modele.jouer(_ap, "Idle")
	_bloque_t += dt
	if _bloque_t >= 2.5:
		if not au_contact and mode != "donjon" and distance > 2.0 and global_position.distance_squared_to(_derniere_pos) < 0.5:
			_cible_bloquee = cible
			_eviter_t = 15.0
			cible = null
			_errance = Vector3.ZERO
			_but_chemin = Vector3.INF
			if mode == "vers_portail":
				mode = "ville"
				d["etat"] = "ville"
		_derniere_pos = global_position
		_bloque_t = 0.0

func rejoindre_groupe(instance: Donjon, place: int) -> void:
	donjon = instance
	mode = "vers_groupe"
	_place_groupe = place
	cible = null
	_but_chemin = Vector3.INF

func a_tue(espece: String, elite: bool, mult: float) -> void:
	var avant := int(d["niveau"])
	Partie.bot_gagner(d, espece, elite, mult)
	if int(d["niveau"]) > avant:
		Fx.anneau(global_position, Color(1.0, 0.8, 0.3), 2.5)
		Fx.texte(global_position + Vector3(0, 2.6, 0), "NIVEAU %d" % int(d["niveau"]), Color(1.0, 0.85, 0.35), 1.2, 1.2)
	_maj_plaque()

func placer(p: Vector3) -> void:
	global_position = p
	_depart_sur_rue = mode == "ville"
	_but_chemin = Vector3.INF
	_bloque_t = 0.0
	_coup_t = 0.0
	_derniere_pos = p
	velocity = Vector3.ZERO
	cible = null
	_choix_t = 0.0
