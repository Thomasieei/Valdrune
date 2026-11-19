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
	Partie.change.connect(_maj_plaque)
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
	pv_max = st["pv"]
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
	_plaque.text = "%s[%s] %s%s" % [tete, Partie.RANGS[e["rang"]], e["nom"], ("\n" + v["texte"]) if v["texte"] != "" else ""]
	if sans_chrono:
		_plaque.modulate = OR_ELITE.lightened(0.2) if elite else(Partie.COULEURS_RANG[e["rang"]] as Color).lightened(0.25)
	else:
		_plaque.modulate = OR_ELITE.lightened(0.2) if elite else v["couleur"]

func _process(dt: float) -> void:
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
		if chrono >= temps_max:

			chrono = -1.0
			pv = pv_max
			Fx.texte(global_position + Vector3(0, haut() + 0.6, 0), "Régénéré !", Color(1.0, 0.35, 0.3), 1.4)
			Partie.message.emit("%s s'est régénéré : il te faut plus de puissance." % e["nom"], Color(1.0, 0.45, 0.4))
			Modele.jouer(_ap, "Roar" if _ap and _ap.has_animation("Roar") else "Celebrate")
			regenere.emit(self)
			_retour_idle(1.5)

func temps_restant() -> float:
	return temps_max - maxf(chrono, 0.0)

func frapper(degats: float, crit: bool, source := "joueur") -> void:
	if mort:
		return
	if chrono < 0.0:
		chrono = 0.0
	var reel := minf(degats, pv)
	pv -= degats
	Partie.compter(reel, source)
	_flash = 1.0
	var h := haut()
	Fx.degats(global_position + Vector3(randf_range(-0.9, 0.9), h * randf_range(0.55, 1.05), randf_range(-0.3, 0.3)), degats, crit, source == "ombres")
	if pv <= 0.0:
		_mourir()
	elif randf() < 0.35 and _ap and _ap.current_animation != "Hit" and _ap.current_animation != "Hit_Chest":
		Modele.jouer(_ap, "Hit", 1.3, 0.05)
		_retour_idle(0.45)

func _retour_idle(apres: float) -> void:
	await get_tree().create_timer(apres).timeout
	if not mort and is_inside_tree():
		Modele.jouer(_ap, "Idle")

func _mourir() -> void:
	mort = true
	pv = 0.0
	chrono = -1.0
	_plaque.visible = false
	if Modele.jouer(_ap, "Death", 1.0, 0.08) <= 0.0:

		var tw := create_tween()
		tw.tween_property(_corps, "rotation:x", -PI / 2.0, 0.5).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	eveillable = true
	_eveil_fin = Time.get_ticks_msec() / 1000.0 + FENETRE_EVEIL
	_reapparait = REAPPARITION + (6.0 if e.get("boss", false) else 0.0)
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
