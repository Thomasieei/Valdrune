class_name Ombre
extends Node3D



var donnees: Dictionary
var joueur: Joueur
var place := 0
var _corps: Node3D
var _ap: AnimationPlayer
var _coup_t := 0.0
var _anim := 0.0
var _y := 0.0
var _comp: Dictionary = {}
var _comp_t := 0.0
# Chaque ombre conserve son petit rythme visuel sans particules permanentes.
var _presence_t := 0.0
var _humeur_t := 6.0
var _humeur_active := false
var pv := 1.0
var pv_max := 1.0
var mort := false
var _rappel_t := 0.0
var _auto: Monstre = null
var _auto_t := 0.0
var _etiquette: Label3D

func _ready() -> void:
	var e: Dictionary = Partie.ESPECES[donnees["espece"]]

	var h := minf(float(e["haut"]) * 0.9, 2.3)
	_corps = Modele.creer(e["modele"], h)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)

	add_to_group("ombres")
	pv_max = Partie.pv_ombre(donnees)
	pv = pv_max
	var rouge := Partie.ombre_rouge(donnees)
	if Partie.est_general(donnees) or donnees.get("evo", false):
		_corps.scale = Vector3.ONE * (1.25 if Partie.est_general(donnees) else 1.12)
		var cl := Label3D.new()
		cl.text = "♛ GÉNÉRAL" if Partie.est_general(donnees) else "◆ ÉLITE"
		cl.font = Ui.police
		cl.font_size = 22
		cl.outline_size = 7
		cl.pixel_size = 0.0016
		cl.fixed_size = true
		cl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		cl.modulate = Color(1.0, 0.82, 0.3)
		cl.position.y = h * 1.25 + 0.55
		add_child(cl)
		var lum := OmniLight3D.new()
		lum.light_color = Color(1.0, 0.75, 0.3) if Partie.est_general(donnees) else Color(0.7, 0.5, 1.0)
		lum.light_energy = 1.5
		lum.omni_range = 4.0
		lum.position.y = 1.2
		add_child(lum)
	if Partie.est_general(donnees) and e.get("competence", {}).is_empty():
		_comp = {"nom": "Ordre du général", "cd": 15.0, "mult": 8.0}
	var mat := Shaders.ombre(Color(1.0, 0.12, 0.2) if rouge else Color(0.42, 0.2, 1.0))
	for m in _corps.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
		(m as MeshInstance3D).material_overlay = null
	if _comp.is_empty():
		_comp = e.get("competence", {})
	_comp_t = float(_comp.get("cd", 0.0)) * 0.5
	_humeur_t = 2.1 + float(place % 5) * 0.9 + randf_range(0.0, 0.7)
	var etoiles := int(donnees["etoiles"])
	if etoiles > 0:
		var l := Label3D.new()
		l.text = "★".repeat(etoiles)
		l.fixed_size = true
		l.pixel_size = 0.0016
		l.font_size = 22
		l.modulate = Color(0.8, 0.6, 1.0)
		l.font = Ui.police
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.position.y = h + 0.3
		add_child(l)
	Modele.jouer(_ap, "Idle")

func _process(dt: float) -> void:
	if joueur == null:
		return
	_anim -= dt
	if rangee:
		global_position = joueur.global_position
		return
	if mort:
		global_position = global_position.lerp(joueur.global_position + Vector3(0, 0, 1.5), minf(1.0, dt * 3.0))
		_etiquette.text = "✝ Rappel : %d mana" % int(Partie.cout_rappel(donnees)) if Partie.mana < Partie.cout_rappel(donnees) else "✝ Rappel…"
		_rappel_t -= dt
		if _rappel_t <= 0.0:
			if Partie.opts["rappel"] and not Partie.opts["patrouille"] and Partie.depenser_mana(Partie.cout_rappel(donnees)):
				_revenir()
			else:
				_rappel_t = 1.0
		return
	pv = minf(pv_max, pv + pv_max * 0.01 * dt)
	var c: Monstre = _choisir_cible(dt)
	var vise: Vector3

	var attaque := c != null
	if attaque:

		# Au-dela de huit unites, evite de superposer les positions.
		var anneau := int(place / 8)
		var a := float(place % 8) * TAU / 8.0 + 0.8 + float(anneau) * 0.24
		var r := c.haut() * 0.3 + 1.3 + float(anneau) * 0.85
		vise = c.global_position + Vector3(sin(a), 0, cos(a)) * r
	else:
		var b := Basis(Vector3.UP, joueur._corps.rotation.y)

		var rangee := place / 2
		var cote := -1.0 if place % 2 == 0 else 1.0
		vise = joueur.global_position + b * Vector3(cote * (1.3 + rangee * 0.5), 0, -1.2 - rangee * 1.1)
	var v := vise - global_position
	v.y = 0
	var d := v.length()
	# Une gestuelle de repos s'interrompt immediatement si l'ombre doit agir.
	if _humeur_active and (d > 0.35 or attaque):
		_humeur_active = false
		_anim = 0.0
	if d > 0.35:
		var vit := clampf(d * 3.5, 1.5, 15.0) * Partie.vit_ombre()
		global_position += v.normalized() * minf(d, vit * dt)
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v.x, v.z), minf(1.0, dt * 10.0))
		if _anim <= 0.0:
			var marche := d < 1.6 or vit < 4.0
			Modele.jouer(_ap, "Walk" if marche else "Run", clampf(vit / 7.0, 0.75, 1.45), 0.18)
	if attaque and not _comp.is_empty():
		_comp_t -= dt
		if _comp_t <= 0.0:
			_comp_t = float(_comp["cd"])
			_competence(c)
	# Une respiration et un balancement differents par unite: aspect vivant
	# sans AnimationTree ou particules supplementaires par ombre.
	_presence_t += dt
	var repos := 1.0 if d <= 0.35 and _anim <= 0.0 else 0.0
	var vague := sin(_presence_t * (2.0 + float(place % 3) * 0.18) + float(place) * 1.1)
	_corps.position.y = lerpf(_corps.position.y, vague * 0.026 * repos, minf(1.0, dt * 7.0))
	_corps.rotation.z = lerp_angle(_corps.rotation.z, vague * 0.016 * repos, minf(1.0, dt * 5.0))
	if d > 0.35:
		pass
	elif attaque:
		var w := c.global_position - global_position
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(w.x, w.z), minf(1.0, dt * 10.0))
		_coup_t -= dt
		if _coup_t <= 0.0:
			_coup_t = 0.9
			var anim := "Attack" if randf() < 0.6 else "Attack2"
			_anim = Modele.jouer(_ap, anim, 1.5, 0.08) * 0.85
			# Petite anticipation/reprise, la simulation des degats reste identique.
			var impulsion := create_tween()
			impulsion.tween_property(_corps, "rotation:x", -0.11, 0.09)
			impulsion.tween_property(_corps, "rotation:x", 0.0, 0.18)
			var deg := Partie.dps_ombre(donnees) * 0.9
			await get_tree().create_timer(0.25).timeout
			if is_instance_valid(c) and not c.mort:
				c.frapper(deg, false, "ombres")
	elif _anim <= 0.0:
		_humeur_active = false
		# Gestuelle propre aux especes, uniquement lorsque l'ombre attend.
		_humeur_t -= dt
		if _humeur_t <= 0.0 and global_position.distance_to(joueur.global_position) < 15.0:
			var esp: String = donnees["espece"]
			var geste := "Roar" if esp in ["orc", "orc_guerrier", "puglin", "puglin_brute"] else "Cheer"
			var duree := Modele.jouer(_ap, geste, 1.0, 0.16)
			if duree > 0.0:
				_anim = duree
				_humeur_active = true
			else:
				Modele.jouer(_ap, "Idle")
			_humeur_t = randf_range(10.0, 16.0)
		else:
			Modele.jouer(_ap, "Idle")

	global_position.y = lerpf(global_position.y, joueur.global_position.y, minf(1.0, dt * 8.0))


func _a_portee(m: Monstre) -> bool:
	if m == null or not is_instance_valid(m) or m.mort or m.allie:
		return false
	var v := m.global_position - joueur.global_position
	v.y = 0
	return v.length() <= Partie.portee_ombres() + m.haut() * 0.3

var _garde: Monstre = null

func _a_portee_patrouille(m) -> bool:
	return m != null and is_instance_valid(m) and not m.mort and not m.allie

func _choisir_cible(dt: float) -> Monstre:
	if Partie.opts["patrouille"]:
		_auto_t -= dt
		if _auto_t <= 0.0 or not _a_portee_patrouille(_garde):
			_auto_t = 1.0
			_garde = null
			var mieux := INF
			for m in joueur.get_parent().monstres:
				if _a_portee_patrouille(m):
					var dd: float = m.global_position.distance_to(global_position) + (0.0 if m.sans_chrono == false else 999.0)
					if dd < mieux:
						mieux = dd
						_garde = m
		return _garde if _a_portee_patrouille(_garde) else null
	if Partie.opts["diviser"]:
		_auto_t -= dt
		if _auto_t <= 0.0 or not _a_portee(_garde):
			_auto_t = 0.6
			var l: Array = joueur.get_parent().monstres.filter(func (m): return _a_portee(m))
			l.sort_custom(func (a, b): return a.global_position.distance_to(joueur.global_position) < b.global_position.distance_to(joueur.global_position))
			_garde = l[place % l.size()] if not l.is_empty() else null
		return _garde if _a_portee(_garde) else null
	var c: Monstre = joueur.cible
	if _a_portee(c):
		_garde = c
		return c
	if _a_portee(_garde):
		return _garde
	if not Partie.auto_ombres:
		return null
	_auto_t -= dt
	if _auto_t <= 0.0 or not _a_portee(_auto):
		_auto_t = 0.5
		_auto = null
		var mieux := INF
		for m in joueur.get_parent().monstres:
			if _a_portee(m):
				var d: float = m.global_position.distance_to(joueur.global_position)
				if d < mieux:
					mieux = d
					_auto = m
	return _auto if _a_portee(_auto) else null

var rangee := false

static func fumee(pos: Vector3, parent: Node, sortie: bool) -> void:
	var p := GPUParticles3D.new()
	p.amount = 46
	p.lifetime = 1.4
	p.one_shot = true
	p.explosiveness = 0.75
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
	pm.emission_ring_axis = Vector3(0, 1, 0)
	pm.emission_ring_radius = 0.9
	pm.emission_ring_inner_radius = 0.2
	pm.emission_ring_height = 0.1
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.6
	pm.initial_velocity_max = 2.2 if sortie else 1.2
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 2.5
	pm.scale_max = 5.0
	pm.turbulence_enabled = true
	pm.turbulence_noise_strength = 0.8
	var g := Gradient.new()
	g.set_color(0, Color(0.12, 0.02, 0.22, 0.9))
	g.add_point(0.45, Color(0.05, 0.0, 0.1, 0.7))
	g.set_color(g.get_point_count() - 1, Color(0.0, 0.0, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.5, 0.5)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/fx/smoke_02.png")
	q.material = m
	p.draw_pass_1 = q
	parent.add_child(p)
	p.global_position = pos
	p.emitting = true
	var flaque := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.3
	cy.bottom_radius = 1.3
	cy.height = 0.02
	flaque.mesh = cy
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.albedo_color = Color(0.02, 0.0, 0.05, 0.85)
	flaque.material_override = fm
	flaque.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(flaque)
	flaque.global_position = pos + Vector3(0, 0.04, 0)
	flaque.scale = Vector3(0.1, 1, 0.1)
	var tw := flaque.create_tween()
	tw.tween_property(flaque, "scale", Vector3.ONE, 0.3)
	tw.tween_interval(0.9)
	tw.tween_property(fm, "albedo_color:a", 0.0, 0.6)
	tw.tween_callback(flaque.queue_free)
	tw.tween_callback(p.queue_free)

func ranger(oui: bool) -> void:
	if oui == rangee or mort:
		return
	rangee = oui
	var h := _corps.get_meta("h", 2.0) as float
	fumee(global_position, get_parent(), not oui)
	var tw := create_tween()
	if oui:
		tw.tween_interval(0.15)
		tw.tween_property(_corps, "position:y", -2.6, 0.7).set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_QUAD)
		tw.tween_callback(func (): _corps.visible = false)
	else:
		global_position = joueur.global_position + Vector3(randf_range(-2.5, 2.5), 0, randf_range(-2.5, 2.5))
		_corps.position.y = -2.6
		_corps.visible = true
		tw.tween_interval(0.2)
		tw.tween_property(_corps, "position:y", 0.0, 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	Fx.son("shadow", -6.0, 0.7 if oui else 1.0)

func blesser(d: float) -> void:
	if rangee:
		return
	if mort:
		return
	pv -= d
	Fx.texte(global_position + Vector3(0, 2.0, 0), "-%d" % int(d), Color(0.85, 0.5, 1.0), 0.9, 0.7)
	if pv <= 0.0:
		mort = true
		_rappel_t = 4.0
		_corps.visible = false
		if _etiquette == null:
			_etiquette = Label3D.new()
			_etiquette.fixed_size = true
			_etiquette.pixel_size = 0.0016
			_etiquette.font_size = 20
			_etiquette.outline_size = 6
			_etiquette.modulate = Color(0.6, 0.65, 1.0)
			_etiquette.font = Ui.police
			_etiquette.billboard = BaseMaterial3D.BILLBOARD_ENABLED
			_etiquette.position.y = 1.2
			add_child(_etiquette)
		_etiquette.visible = true
		Fx.anneau(global_position, Color(0.4, 0.15, 0.7), 1.6)

func _revenir() -> void:
	mort = false
	pv = pv_max
	_corps.visible = true
	if _etiquette:
		_etiquette.visible = false
	global_position = joueur.global_position + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5))
	Fx.anneau(global_position, Color(0.6, 0.3, 1.0), 2.0)
	Fx.son("shadow", -8.0)

func _competence(c: Monstre) -> void:
	Modele.jouer(_ap, "Attack", 1.0, 0.08)
	_anim = 0.8
	Fx.son("slam", 0.0)
	Fx.anneau(c.global_position, Color(1.0, 0.15, 0.25), 4.5)
	Fx.texte(global_position + Vector3(0, 3.2, 0), String(_comp["nom"]).to_upper(), Color(1.0, 0.3, 0.35), 1.5, 1.5)
	await get_tree().create_timer(0.35).timeout
	if is_instance_valid(c) and not c.mort:
		c.frapper(Partie.dps_ombre(donnees) * float(_comp["mult"]), true, "ombres")
		Fx.anneau(c.global_position, Color(1.0, 0.45, 0.2), 6.0)

func temps_competence() -> float:
	return _comp_t if not _comp.is_empty() else -1.0
