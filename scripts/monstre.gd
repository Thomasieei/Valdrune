class_name Monstre
extends Node3D






signal vaincu(m: Monstre)
signal regenere(m: Monstre)

const REAPPARITION := 7.0
const FENETRE_EVEIL := 6.0
const OR_ELITE := Color(1.0, 0.72, 0.18)

var espece := "gobelin"
var e: Dictionary
var elite := false
var elite_fixe := false
var mult := 1.0
var sans_chrono := false
var reapparait_auto := true
var pv := 0.0
var pv_max := 1.0
var temps_max := 20.0
var chrono := -1.0
var mort := false
var eveillable := false
var _eveil_fin := 0.0
var _orientation := 0.0
var _corps: Node3D
var _ap: AnimationPlayer
var _plaque: Label3D
var _reapparait := 0.0
var _flash := 0.0
var _aura: Node3D
var _base_haut := 1.0
var _zone_t := 3.0
var _parade := 0.0
var _parade_cd := 8.0
var _bouclier: Node3D
var enrage := false
var _etourdi := 0.0
var _clones_faits := 0
var _clones: Array = []
var _t_vie := 0.0
var _plaque_sale := false
var _plaque_t := 0.0
var pv_perso := -1.0
var atk_perso := -1.0
var nom_perso := ""
var _dernier := ""
var _dernier_bot: Node = null
var totems: Array = []
var _origine := Vector3.ZERO
var _errance := Vector3.ZERO
var _errance_t := 0.0

const CADENCE_ZONE := [6.5, 5.5, 4.6, 3.9, 3.2]
const RAYON_ZONE := [2.4, 2.8, 3.2, 3.7, 4.3]

func configurer(p_espece: String, pos: Vector3, angle: float) -> void:
	espece = p_espece
	position = pos
	_orientation = angle

func haut() -> float:
	return _base_haut * (1.22 if elite else 1.0)

func _ready() -> void:
	e = Partie.ESPECES[espece]
	_base_haut = e["haut"]
	if elite_fixe:
		elite = true
	_construire_corps()

	var zone := Area3D.new()
	zone.collision_layer = 4
	zone.collision_mask = 0
	zone.monitoring = false
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = maxf(0.7, _base_haut * 0.35)
	cap.height = _base_haut + 0.4
	cs.shape = cap
	cs.position.y = _base_haut / 2.0
	zone.add_child(cs)
	zone.set_meta("monstre", self)
	add_child(zone)

	var corps := StaticBody3D.new()
	var cs2 := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = maxf(0.4, _base_haut * 0.2)
	cyl.height = _base_haut
	cs2.shape = cyl
	cs2.position.y = _base_haut / 2.0
	corps.add_child(cs2)
	add_child(corps)
	_plaque = Label3D.new()
	_plaque.fixed_size = true
	_plaque.pixel_size = 0.0016
	_plaque.font_size = 26
	_plaque.outline_size = 8
	_plaque.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	_plaque.visibility_range_end = 40.0
	_plaque.font = Ui.police
	add_child(_plaque)
	Partie.change.connect(func (): _plaque_sale = true)
	_appliquer_rang()

func _construire_corps() -> void:
	if _corps:
		_corps.queue_free()
	_corps = Modele.creer(e["modele"], _base_haut, e.get("peau", ""))
	_corps.rotation.y = _orientation
	add_child(_corps)
	_ap = Modele.lecteur(_corps)
	Modele.jouer(_ap, "Idle", randf_range(0.85, 1.1))
	if _ap and _ap.current_animation != "":
		_ap.seek(randf() * 1.5, true)
	if e.has("teinte"):
		for m in _corps.find_children("*", "MeshInstance3D", true, false):
			var mi := m as MeshInstance3D
			if mi.mesh == null:
				continue
			for s in mi.mesh.get_surface_count():
				var src := mi.get_active_material(s)
				if src is BaseMaterial3D:
					var c := (src as BaseMaterial3D).duplicate() as BaseMaterial3D
					c.albedo_color = c.albedo_color * e["teinte"]
					mi.set_surface_override_material(s, c)
	if espece == "baran":
		Shaders.entourer(_corps, Color(0.9, 0.15, 0.3), 1.2)
	elif espece == "roi_gobelin":
		Shaders.entourer(_corps, Color(1.0, 0.7, 0.2), 1.0)


func _appliquer_rang() -> void:
	var st := Partie.stats_monstre(espece, elite, mult)
	pv_max = pv_perso if pv_perso > 0.0 else st["pv"]
	pv = pv_max
	temps_max = 1000000000.0 if sans_chrono else st["temps"]
	_corps.scale = Vector3.ONE * (1.22 if elite else 1.0)
	for mi in _corps.find_children("*", "MeshInstance3D", true, false):
		if espece != "baran" and espece != "roi_gobelin":
			(mi as MeshInstance3D).material_overlay = Shaders.halo(OR_ELITE, 0.9) if elite else null
	if elite and _aura == null:
		_aura = _cercle(OR_ELITE, maxf(1.0, _base_haut * 0.55))
		add_child(_aura)
	elif not elite and _aura:
		_aura.queue_free()
		_aura = null
	_plaque.position.y = haut() + 0.35
	_maj_plaque()

func _cercle(c: Color, r: float) -> Node3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.86
	t.outer_radius = r
	t.rings = 40
	t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	m.emission_energy_multiplier = 2.0
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.06, 1)
	mi.position.y = 0.06
	return mi

func _maj_plaque() -> void:
	var v: Dictionary = Partie.verdict(espece, elite, mult) if not sans_chrono else {"texte": "", "couleur": Color.WHITE}
	var tete := "★ ÉLITE  " if elite else ""
	_plaque.text = "%s[%s] %s%s" % [tete, Partie.RANGS[e["rang"]], nom_perso if nom_perso != "" else e["nom"], ("\n" + v["texte"]) if v["texte"] != "" else ""]
	if sans_chrono:
		_plaque.modulate = OR_ELITE.lightened(0.2) if elite else(Partie.COULEURS_RANG[e["rang"]] as Color).lightened(0.25)
	else:
		_plaque.modulate = OR_ELITE.lightened(0.2) if elite else v["couleur"]

func _combat(dt: float) -> void:
	var j: Node3D = get_tree().get_first_node_in_group("joueur")
	if j == null or chrono < 0.0 or global_position.distance_to(j.global_position) > 20.0:
		return
	var r: int = mini(int(e["rang"]), 4)
	if _etourdi > 0.0:
		_etourdi -= dt
		return
	_zone_t -= dt
	if _zone_t <= 0.0:
		var rapport := puissance() / maxf(Partie.dps_total(), 1.0)
		var calme := (3.0 if rapport < 0.3 else (1.8 if rapport < 1.0 else 1.0)) * (0.7 if Partie.pluie_sang() and e.get("lieu", "") == "" else 1.0)
		_zone_t = CADENCE_ZONE[r] * randf_range(0.85, 1.15) * (0.8 if elite else 1.0) * (0.5 if enrage else 1.0) * calme
		var cible: Vector3 = j.global_position
		var ombres := get_tree().get_nodes_in_group("ombres").filter(func (o): return not o.mort and o.global_position.distance_to(global_position) < 16.0)
		if not ombres.is_empty() and randf() < 0.35:
			cible = ombres.pick_random().global_position
		_zone(cible, RAYON_ZONE[r] * (1.2 if elite else 1.0), 1.5 if r < 3 else 1.2)
	if r >= 1:
		if _parade > 0.0:
			_parade -= dt
			if _parade <= 0.0 and _bouclier:
				_bouclier.queue_free()
				_bouclier = null
		else:
			_parade_cd -= dt
			if _parade_cd <= 0.0:
				_parade_cd = randf_range(7.0, 11.0) - r
				_parade = 1.3
				_bouclier = _cercle(Color(0.35, 0.75, 1.0), maxf(1.1, _base_haut * 0.6))
				_bouclier.position.y = haut() * 0.5
				_bouclier.scale = Vector3(1, 0.25, 1)
				add_child(_bouclier)
				Fx.texte(global_position + Vector3(0, haut() + 0.8, 0), "PARADE !", Color(0.45, 0.8, 1.0), 1.3, 1.0)
				Fx.son("sheath", -4.0)

func en_parade() -> bool:
	return _parade > 0.0

func briser(degats: float) -> void:
	if mort:
		return
	var avait := _parade > 0.0
	_parade = 0.0
	if _bouclier:
		_bouclier.queue_free()
		_bouclier = null
	_etourdi = 2.0 if avait else 1.0
	Fx.anneau(global_position, Color(0.5, 0.85, 1.0), 3.5)
	Fx.texte(global_position + Vector3(0, haut() + 0.9, 0), "GARDE BRISÉE !" if avait else "ÉTOURDI", Color(0.6, 0.9, 1.0), 1.4, 1.1)
	frapper(degats * (1.5 if avait else 1.0), true)

func _zone(p: Vector3, rayon: float, delai: float) -> void:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = rayon
	cy.bottom_radius = rayon
	cy.height = 0.04
	mi.mesh = cy
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = Color(1.0, 0.1, 0.05, 0.42)
	m.no_depth_test = false
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var bord := _cercle(Color(1.0, 0.25, 0.15), rayon)
	var racine := Node3D.new()
	racine.add_child(mi)
	racine.add_child(bord)
	get_parent().add_child(racine)
	racine.global_position = p + Vector3(0, 0.08, 0)
	mi.scale = Vector3(0.05, 1, 0.05)
	var tw := racine.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE, delai)
	tw.tween_callback(_impact.bind(racine, rayon))
	tw.tween_callback(racine.queue_free)

func _impact(racine: Node3D, rayon: float) -> void:
	var atk := (atk_perso if atk_perso > 0.0 else Partie.atk_monstre(espece, elite)) * (2.0 if enrage else 1.0)
	if not mort:
		var j: Node3D = get_tree().get_first_node_in_group("joueur")
		if j and _dans_zone(j.global_position, racine.global_position, rayon):
			_toucher_joueur(j, atk)
		for o in get_tree().get_nodes_in_group("ombres"):
			if not o.mort and _dans_zone(o.global_position, racine.global_position, rayon):
				o.blesser(atk)
		for p in get_tree().get_nodes_in_group("pactes"):
			if not p.mort and _dans_zone(p.global_position, racine.global_position, rayon):
				p.blesser_pacte(puissance() * 1.5)
		Fx.anneau(racine.global_position, Color(1.0, 0.35, 0.15), rayon)
		Fx.son("slam", -8.0)

func _dans_zone(a: Vector3, c: Vector3, r: float) -> bool:
	return Vector2(a.x - c.x, a.z - c.z).length() <= r and absf(a.y - c.y) < 3.0

func _toucher_joueur(j: Node3D, d: float, raison := "ZONE") -> void:
	var jj := j as Joueur
	if jj and jj.invulnerable > 0.0:
		Fx.texte(j.global_position + Vector3(0, 2.3, 0), "ESQUIVÉ", Color(0.5, 1.0, 0.8), 1.1, 0.7)
		return
	Fx.texte(j.global_position + Vector3(0, 2.3, 0), "-%d  %s" % [int(d), raison], Color(1.0, 0.25, 0.25), 1.2, 1.1)
	var v := get_tree().get_first_node_in_group("ville")
	if v and v.hud:
		v.hud.flash_degats(raison)
	if Partie.blesser(d):
		if v:
			v.mort_joueur()

func _process(dt: float) -> void:
	if allie:
		if not mort:
			_ia_pacte(dt)
		return
	_plaque_t -= dt
	if _plaque_sale and _plaque_t <= 0.0:
		_plaque_t = 0.6
		_plaque_sale = false
		if _plaque.visible:
			_maj_plaque()
	if not mort:
		_combat(dt)
		_errer(dt)
		if _ap == null:
			_t_vie += dt
			_corps.position.y = absf(sin(_t_vie * 2.2)) * 0.12
			_corps.rotation.z = sin(_t_vie * 1.1) * 0.05
	if _aura:
		_aura.rotation.y += dt * 1.2
	if _flash > 0.0:
		_flash = maxf(0.0, _flash - dt * 6.0)
		_corps.scale = Vector3.ONE * (1.22 if elite else 1.0) * (1.0 + _flash * 0.06)
	if mort:
		if eveillable and Time.get_ticks_msec() / 1000.0 > _eveil_fin:
			eveillable = false
		if reapparait_auto:
			_reapparait -= dt
			if _reapparait <= 0.0:
				_renaitre()
		return
	if chrono >= 0.0:
		chrono += dt
		if chrono >= temps_max and not enrage:
			enrage = true
			Fx.texte(global_position + Vector3(0, haut() + 0.6, 0), "ENRAGÉ !", Color(1.0, 0.25, 0.2), 1.6, 1.4)
			Fx.anneau(global_position, Color(1.0, 0.2, 0.15), 4.0)
			Partie.message.emit("%s est enragé : dégâts doublés, finis-le vite !" % e["nom"], Color(1.0, 0.45, 0.4))
			Modele.jouer(_ap, "Roar" if _ap and _ap.has_animation("Roar") else "Celebrate")
			for mi in _corps.find_children("*", "MeshInstance3D", true, false):
				(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(1.0, 0.15, 0.1), 1.6)
			_retour_idle(1.5)
		if enrage and j_loin():
			enrage = false
			chrono = -1.0
			pv = pv_max
			_appliquer_rang()

func _errer(dt: float) -> void:
	if not reapparait_auto or chrono >= 0.0 or e.get("boss", false) or e.get("lieu", "") != "":
		return
	if _origine == Vector3.ZERO:
		_origine = global_position
	_errance_t -= dt
	if _errance_t <= 0.0:
		_errance_t = randf_range(4.0, 9.0)
		_errance = _origine + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)) if randf() < 0.7 else global_position
	var v := _errance - global_position
	v.y = 0
	if v.length() > 0.3:
		global_position += v.normalized() * minf(v.length(), 1.2 * dt)
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v.x, v.z), minf(1.0, dt * 5.0))
		if _ap and _ap.current_animation != "Walk" and _ap.current_animation != "Hit":
			Modele.jouer(_ap, "Walk", 0.8)
	elif _ap and _ap.current_animation == "Walk":
		Modele.jouer(_ap, "Idle")

var leve := false
var allie := false
var pv_pacte := 1.0
var _pacte_cible: Monstre = null
var _pacte_t := 0.0
var _riposte_t := 0.0

func puissance() -> float:
	return pv_max / maxf(minf(temps_max, 45.0), 20.0) * 0.6

func pacte() -> void:
	allie = true
	chrono = -1.0
	_parade = 0.0
	pv_pacte = pv_max * 0.35
	add_to_group("pactes")
	for mi in _corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.3, 1.0, 0.7), 2.2)
	_plaque.text = "◈ PACTE — %s" % (nom_perso if nom_perso != "" else e["nom"])
	_plaque.modulate = Color(0.45, 1.0, 0.75)
	Fx.anneau(global_position, Color(0.3, 1.0, 0.7), 4.0)

func blesser_pacte(d: float) -> void:
	if not allie or mort:
		return
	pv_pacte -= d
	Fx.texte(global_position + Vector3(0, haut() + 0.4, 0), "-%s" % Fx.court(d), Color(0.4, 1.0, 0.7), 0.9, 0.6)
	if pv_pacte <= 0.0:
		mort = true
		allie = false
		_plaque.visible = false
		Fx.anneau(global_position, Color(0.2, 0.6, 0.4), 3.0)
		Partie.message.emit("Ton pacte est rompu : %s est mort pour de bon." % e["nom"], Color(1.0, 0.5, 0.45))
		var tw := create_tween()
		tw.tween_property(_corps, "scale", Vector3.ONE * 0.01, 0.8)

func _ia_pacte(dt: float) -> void:
	var v := get_tree().get_first_node_in_group("ville")
	if v == null:
		return
	if _pacte_cible == null or not is_instance_valid(_pacte_cible) or _pacte_cible.mort:
		_pacte_cible = null
		var mieux := INF
		for m in v.monstres:
			if is_instance_valid(m) and not m.mort and not m.allie and m != self:
				var dd: float = m.global_position.distance_to(global_position)
				if dd < mieux:
					mieux = dd
					_pacte_cible = m
	if _pacte_cible == null:
		var j: Node3D = v.joueur
		var w := j.global_position - global_position
		w.y = 0
		if w.length() > 5.0:
			global_position += w.normalized() * 6.0 * dt
			_corps.rotation.y = atan2(w.x, w.z)
			Modele.jouer(_ap, "Run")
		else:
			Modele.jouer(_ap, "Idle")
		return
	var u := _pacte_cible.global_position - global_position
	u.y = 0
	var portee := 1.8 + haut() * 0.3 + _pacte_cible.haut() * 0.3
	if u.length() > portee:
		global_position += u.normalized() * 6.5 * dt
		_corps.rotation.y = atan2(u.x, u.z)
		Modele.jouer(_ap, "Run")
		return
	_corps.rotation.y = atan2(u.x, u.z)
	_pacte_t -= dt
	if _pacte_t <= 0.0:
		_pacte_t = 1.0
		Modele.jouer(_ap, "Attack", 1.3, 0.06)
		_pacte_cible.frapper(puissance(), randf() < 0.2, "allie")
	_riposte_t -= dt
	if _riposte_t <= 0.0 and is_instance_valid(_pacte_cible) and not _pacte_cible.mort:
		_riposte_t = 1.5
		blesser_pacte(_pacte_cible.puissance() * 0.5)

func lever() -> void:
	if mort:
		return
	leve = true
	_etourdi = 6.0
	_parade = 0.0
	var tw := create_tween()
	tw.tween_property(_corps, "position:y", 2.6, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	tw.parallel().tween_property(_corps, "rotation:z", 0.35, 0.6)
	Fx.anneau(global_position, Color(0.4, 0.8, 1.0), 2.0)

func reposer(ecraser := false) -> void:
	if not leve:
		return
	leve = false
	_etourdi = 0.0
	var tw := create_tween()
	tw.tween_property(_corps, "position:y", 0.0, 0.18 if ecraser else 0.5).set_ease(Tween.EASE_IN)
	tw.parallel().tween_property(_corps, "rotation:z", 0.0, 0.3)
	if ecraser:
		tw.tween_callback(func ():
			Fx.anneau(global_position, Color(0.5, 0.85, 1.0), 3.5)
			Fx.son("slam", 0.0)
			frapper(Partie.dps_joueur() * 12.0, true, "evenement"))

func capituler(choix: String) -> void:
	if mort:
		return
	leve = false
	mort = true
	eveillable = false
	pv = 0.0
	chrono = -1.0
	_plaque.visible = false
	if choix == "butin":
		var gain := Partie.gagner(espece, elite, mult)
		for k in 2:
			if randf() < 0.5:
				Partie.gagner(espece, elite, mult)
		Fx.pieces(global_position + Vector3(0, 1.0, 0), gain)
		Fx.son("coins")
	elif choix == "servir":
		Partie.force_eveil = randf() < 0.5
		Partie.eveiller(espece)
		Partie.force_eveil = false
	var tw := create_tween()
	tw.tween_property(_corps, "position:y", 0.0, 0.3)
	tw.tween_property(_corps, "scale", Vector3.ONE * 0.01, 0.5)
	_reapparait = REAPPARITION + 4.0
	vaincu.emit(self)

func j_loin() -> bool:
	var j: Node3D = get_tree().get_first_node_in_group("joueur")
	return j == null or j.global_position.distance_to(global_position) > 28.0

func temps_restant() -> float:
	return temps_max - maxf(chrono, 0.0)

func frapper(degats: float, crit: bool, source := "joueur", qui: Node = null) -> void:
	if mort or allie:
		return
	var meca: String = e.get("meca", "")
	if meca == "ombres_seules" and source == "joueur":
		if randf() < 0.3:
			Fx.texte(global_position + Vector3(0, haut() * 0.8, 0), "IMMUNISÉ — ombres seules", Color(0.75, 0.6, 1.0), 1.0, 0.7)
		return
	if meca == "totems" and totems.any(func (t): return is_instance_valid(t) and not t.mort):
		if randf() < 0.3:
			Fx.texte(global_position + Vector3(0, haut() * 0.8, 0), "PROTÉGÉ — détruis les totems", Color(1.0, 0.45, 0.4), 1.0, 0.7)
		return
	_dernier = source
	_dernier_bot = qui
	if chrono < 0.0:
		chrono = 0.0
	if _parade > 0.0 and source != "evenement":
		Fx.texte(global_position + Vector3(0, haut() * 0.8, 0), "PARÉ", Color(0.5, 0.85, 1.0), 1.0, 0.6)
		if source == "joueur":
			var j: Node3D = get_tree().get_first_node_in_group("joueur")
			if j:
				_toucher_joueur(j, Partie.atk_monstre(espece, elite) * 0.6, "RIPOSTE (parade)")
		return
	var reel := minf(degats, pv)
	pv -= degats
	if source == "joueur" or source == "ombres":
		Partie.compter(reel, source)
	if espece == "titan":
		var qui_nom: String = "Toi" if source in ["joueur", "ombres", "evenement"] else (str(qui.d["nom"]) if qui and is_instance_valid(qui) and "d" in qui else "?")
		Partie.raid_degats[qui_nom] = float(Partie.raid_degats.get(qui_nom, 0.0)) + reel
	_flash = 1.0
	var h := haut()
	if source == "bot" or source == "allie":
		Fx.texte(global_position + Vector3(randf_range(-0.9, 0.9), h * randf_range(0.5, 0.9), 0), Fx.court(degats), Color(0.55, 0.85, 1.0), 0.7, 0.6)
	else:
		Fx.degats(global_position + Vector3(randf_range(-0.9, 0.9), h * randf_range(0.55, 1.05), randf_range(-0.3, 0.3)), degats, crit, source == "ombres")
	if e.get("clones", false) and pv > 0.0:
		var seuils := [0.66, 0.33]
		if _clones_faits < seuils.size() and pv / pv_max < seuils[_clones_faits]:
			_clones_faits += 1
			_invoquer_clones()
	if pv <= 0.0:
		_mourir()
	elif randf() < 0.35 and _ap and _ap.current_animation != "Hit" and _ap.current_animation != "Hit_Chest":
		Modele.jouer(_ap, "Hit", 1.3, 0.05)
		_retour_idle(0.45)

func _invoquer_clones() -> void:
	Fx.texte(global_position + Vector3(0, haut() + 1.0, 0), "MULTICLONAGE !", Color(1.0, 0.6, 0.15), 1.6, 1.4)
	Fx.son("portal", 0.0)
	var v := get_tree().get_first_node_in_group("ville")
	for k in 3:
		var a := TAU * k / 3.0
		var cl := Monstre.new()
		cl.configurer("clone_naruto", global_position + Vector3(cos(a), 0, sin(a)) * 3.5, _orientation)
		cl.sans_chrono = true
		cl.reapparait_auto = false
		var par := get_parent()
		par.add_child(cl)
		if par is Donjon:
			(par as Donjon).monstres.append(cl)
		Fx.anneau(cl.global_position, Color(1.0, 1.0, 1.0), 1.8)
		_clones.append(cl)
		if v:
			v.monstres.append(cl)

func _retour_idle(apres: float) -> void:
	await get_tree().create_timer(apres).timeout
	if not mort and is_inside_tree():
		Modele.jouer(_ap, "Idle")

func _mourir() -> void:
	mort = true
	pv = 0.0
	chrono = -1.0
	enrage = false
	_etourdi = 0.0
	_parade = 0.0
	if _bouclier:
		_bouclier.queue_free()
		_bouclier = null
	_plaque.visible = false
	if Modele.jouer(_ap, "Death", 1.0, 0.08) <= 0.0:

		var tw := create_tween()
		tw.tween_property(_corps, "rotation:x", -PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	eveillable = float(e.get("eveil", 0.0)) > 0.0
	for cl in _clones:
		if is_instance_valid(cl) and not cl.mort:
			cl.frapper(cl.pv + 1.0, false, "evenement")
	_eveil_fin = Time.get_ticks_msec() / 1000.0 + FENETRE_EVEIL
	_reapparait = REAPPARITION + (6.0 if e.get("boss", false) else 0.0)
	if _dernier == "bot" and _dernier_bot and is_instance_valid(_dernier_bot):
		eveillable = false
		_dernier_bot.a_tue(espece, elite, mult)
	else:
		var gain := Partie.gagner(espece, elite, mult)
		Fx.pieces(global_position + Vector3(0, 1.0, 0), gain)
		Fx.son("coins")
	if elite:
		Fx.anneau(global_position, OR_ELITE, 3.0)
	vaincu.emit(self)


func eveil_reussi() -> void:
	eveillable = false
	var tw := create_tween()
	tw.tween_property(_corps, "position:y", -haut(), 1.2).set_ease(Tween.EASE_IN)

func eveil_rate() -> void:
	eveillable = false
	var tw := create_tween()
	tw.tween_property(_corps, "scale", Vector3.ONE * 0.01, 0.6)

func _renaitre() -> void:
	mort = false
	if not elite_fixe:
		elite = not e.get("boss", false) and randf() < Partie.CHANCE_ELITE
	_corps.position.y = 0.0
	_corps.rotation.x = 0.0
	_appliquer_rang()
	var cible_ech := _corps.scale
	_corps.scale = Vector3.ONE * 0.01
	var tw := create_tween()
	tw.tween_property(_corps, "scale", cible_ech, 0.5).set_trans(Tween.TRANS_BACK)
	Modele.jouer(_ap, "Idle")
	_plaque.visible = true
	Fx.anneau(global_position, OR_ELITE if elite else Color(0.6, 0.3, 1.0), 2.4 if elite else 1.6)
	if elite:
		Fx.texte(global_position + Vector3(0, haut() + 0.9, 0), "ÉLITE !", OR_ELITE, 1.5, 1.4)
