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
var pv := 1.0
var pv_max := 1.0
var mort := false
var _rappel_t := 0.0
var _auto: Monstre = null
var _auto_t := 0.0
var _etiquette: Label3D
var role := "melee"
var mana := 0.0
var mana_max := 0.0
var _role_idx := 0
var _spec_t := 2.0
var _tank_t := 1.0
var _soin_t := 0.0
var _hot_t := 0.0
var _hot_cd := 0.0
var _hot_ps := 0.0
var _scan_t := 0.0
var _msg_t := 0.0
var _anneau_pied: MeshInstance3D = null

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
	role = Partie.role_ombre(donnees)
	var rcol: Color = Partie.ROLES[role]["col"]
	mana_max = 30.0 + 20.0 * Partie.rang_ombre(donnees) + 6.0 * int(donnees["etoiles"])
	mana = mana_max
	for o in Partie.ombres_equipees():
		if o["uid"] == donnees["uid"]:
			break
		if Partie.role_ombre(o) == role:
			_role_idx += 1
	var rl := Label3D.new()
	rl.text = String(Partie.ROLES[role]["nom"]).to_upper()
	rl.font = Ui.police
	rl.font_size = 15
	rl.outline_size = 5
	rl.pixel_size = 0.0016
	rl.fixed_size = true
	rl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	rl.modulate = rcol.lightened(0.2)
	rl.position.y = h + 0.75
	rl.visibility_range_end = 10.0
	add_child(rl)
	_volutes(rcol, h)
	if role == "tank" or role == "soin":
		_anneau_pied = _tore(rcol, 0.95)
		add_child(_anneau_pied)
	var mat := Shaders.ombre(Color(1.0, 0.12, 0.2) if rouge else rcol)
	for m in _corps.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
		(m as MeshInstance3D).material_overlay = null
	if _comp.is_empty():
		_comp = e.get("competence", {})
	_comp_t = float(_comp.get("cd", 0.0)) * 0.5
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

func _tore(c: Color, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = r * 0.88
	t.outer_radius = r
	t.rings = 32
	t.ring_segments = 4
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r, c.g, c.b, 0.55)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.scale = Vector3(1, 0.05, 1)
	mi.position.y = 0.06
	return mi

func _volutes(c: Color, h: float) -> void:
	var p := GPUParticles3D.new()
	p.amount = 10
	p.lifetime = 1.5
	p.visibility_aabb = AABB(Vector3(-2, -1, -2), Vector3(4, 5, 4))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.45
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3.ZERO
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 0.8))
	g.set_color(g.get_point_count() - 1, Color(c.r, c.g, c.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.12, 0.12)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.albedo_texture = Fx.pastille()
	m.vertex_color_use_as_albedo = true
	q.material = m
	p.draw_pass_1 = q
	p.position.y = h * 0.5
	add_child(p)

func soigner(montant: float) -> void:
	if mort or montant <= 0.0:
		return
	pv = minf(pv_max, pv + montant)
	if montant >= 8.0:
		Fx.texte(global_position + Vector3(0, 2.1, 0), "+%d" % int(montant), Color(0.4, 1.0, 0.55), 0.9, 0.7)

func _rayon(a: Vector3, b: Vector3, c: Color) -> void:
	var d := a.distance_to(b)
	if d < 0.5:
		return
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.14, 0.14, d)
	mi.mesh = bm
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r, c.g, c.b, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	get_parent().add_child(mi)
	mi.look_at_from_position((a + b) / 2.0, b, Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.tween_callback(mi.queue_free)

func _tank_tick(dt: float) -> void:
	_tank_t -= dt
	if _tank_t > 0.0:
		return
	var rayon := 4.0 + 1.8 * Partie.rang_ombre(donnees) + 0.5 * int(donnees["etoiles"])
	var proche := false
	for m in joueur.get_parent().monstres:
		if is_instance_valid(m) and not m.mort and not m.allie and m.global_position.distance_to(global_position) <= rayon:
			m.provoquer(self, 2.7)
			proche = true
	if proche:
		_tank_t = 2.3
		Fx.anneau(global_position, Color(1.0, 0.12, 0.12), rayon)
		Fx.son("slam", -12.0, 0.6)
		if _anneau_pied:
			_anneau_pied.scale = Vector3(rayon / 0.95, 0.05, rayon / 0.95)
			var tw := _anneau_pied.create_tween()
			tw.tween_property(_anneau_pied, "scale", Vector3(1, 0.05, 1), 0.6)
	else:
		_tank_t = 0.5

func _puissance_soin() -> float:
	return 220.0 * (1.0 + 0.9 * Partie.rang_ombre(donnees)) * pow(1.25, int(donnees["etoiles"]))

func _soin_tick(dt: float) -> void:
	_soin_t -= dt
	_hot_cd -= dt
	_msg_t -= dt
	if _hot_t > 0.0:
		_hot_t -= dt
		soigner(_hot_ps * dt)
		if _hot_t <= 0.0 and _anneau_pied:
			_anneau_pied.scale = Vector3(1, 0.05, 1)
	_scan_t -= dt
	if _scan_t > 0.0:
		return
	_scan_t = 0.4
	var pire := 1.0
	var pos := Vector3.ZERO
	var trouve := false
	var rj: float = Partie.pv / maxf(Partie.pv_max(), 1.0)
	if rj < pire and global_position.distance_to(joueur.global_position) < 14.0:
		pire = rj
		pos = joueur.global_position
		trouve = true
	for o in get_tree().get_nodes_in_group("ombres"):
		if o == self or o.mort or o.rangee:
			continue
		var ro: float = o.pv / maxf(o.pv_max, 1.0)
		if ro < pire and o.global_position.distance_to(global_position) < 14.0:
			pire = ro
			pos = o.global_position
			trouve = true
	if trouve and pire < 0.7 and _soin_t <= 0.0:
		if mana >= 18.0:
			mana -= 18.0
			_soin_t = 6.0
			_soin_zone(pos)
		elif _msg_t <= 0.0:
			_msg_t = 4.0
			Fx.texte(global_position + Vector3(0, 2.6, 0), "SANS MANA", Color(0.5, 0.6, 1.0), 0.9, 0.9)
	var rs := pv / maxf(pv_max, 1.0)
	if rs < 0.55 and _hot_cd <= 0.0 and _hot_t <= 0.0 and mana >= 12.0:
		mana -= 12.0
		_hot_cd = 9.0
		_hot_t = 2.3
		_hot_ps = 100.0 * (1.0 + 0.9 * Partie.rang_ombre(donnees)) * pow(1.25, int(donnees["etoiles"]))
		if _anneau_pied:
			_anneau_pied.scale = Vector3(1.9, 0.05, 1.9)
		Fx.anneau(global_position, Color(0.35, 1.0, 0.55), 2.4)
		Fx.texte(global_position + Vector3(0, 2.6, 0), "SOIN CONTINU", Color(0.4, 1.0, 0.6), 1.0, 1.0)

func _soin_zone(pos: Vector3) -> void:
	var col := Color(0.35, 1.0, 0.55)
	var p := _puissance_soin()
	Modele.jouer(_ap, "Attack", 1.0, 0.08)
	_anim = 0.6
	_rayon(global_position + Vector3(0, 1.4, 0), pos + Vector3(0, 1.0, 0), col)
	Fx.anneau(pos, col, 4.0)
	Fx.son("orb", -4.0, 1.3)
	Fx.texte(global_position + Vector3(0, 2.6, 0), "SOIN DE ZONE", col, 1.1, 1.0)
	if joueur.global_position.distance_to(pos) <= 4.0:
		Partie.pv = minf(Partie.pv_max(), Partie.pv + p)
		Fx.texte(joueur.global_position + Vector3(0, 2.4, 0), "+%d" % int(p), col, 1.1, 0.9)
	for o in get_tree().get_nodes_in_group("ombres"):
		if not o.mort and not o.rangee and o.global_position.distance_to(pos) <= 4.0:
			o.soigner(p)

func _spec_role(dt: float, c: Monstre) -> void:
	_spec_t -= dt
	if _spec_t > 0.0:
		return
	if role == "melee":
		_spec_t = 5.5
		_anim = 0.8
		Modele.jouer(_ap, "Attack2", 1.2, 0.08)
		Fx.anneau(global_position, Color(1.0, 0.6, 0.2), 3.8)
		Fx.son("slam", -4.0)
		Fx.texte(global_position + Vector3(0, 2.8, 0), "TOURBILLON", Color(1.0, 0.65, 0.2), 0.9, 0.9)
		await get_tree().create_timer(0.3).timeout
		if not is_instance_valid(self) or mort:
			return
		var deg := Partie.dps_ombre(donnees) * 6.0
		for m in joueur.get_parent().monstres:
			if is_instance_valid(m) and not m.mort and not m.allie and m.global_position.distance_to(global_position) <= 3.8 + m.haut() * 0.3:
				m.role_source = "dist" if role == "dist" else "melee"
				m.frapper(deg, true, "ombres")
	elif role == "dist":
		if mana < 15.0:
			if _msg_t <= 0.0:
				_msg_t = 4.0
				Fx.texte(global_position + Vector3(0, 2.6, 0), "SANS MANA", Color(0.5, 0.6, 1.0), 0.9, 0.9)
			_msg_t -= dt
			return
		mana -= 15.0
		_spec_t = 4.5
		_anim = 0.8
		Modele.jouer(_ap, "Attack", 1.0, 0.08)
		var col := Color(0.4, 0.75, 1.0)
		_rayon(global_position + Vector3(0, 1.4, 0), c.global_position + Vector3(0, c.haut() * 0.6, 0), col)
		Fx.texte(global_position + Vector3(0, 2.8, 0), "TIR CHARGÉ", col, 1.3, 1.1)
		await get_tree().create_timer(0.35).timeout
		if is_instance_valid(self) and not mort and is_instance_valid(c) and not c.mort:
			c.role_source = "dist" if role == "dist" else "melee"
			c.frapper(Partie.dps_ombre(donnees) * 9.0, true, "ombres")
			Fx.explosion(c.global_position + Vector3(0, c.haut() * 0.5, 0), col, 3.0)

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_usec()
	_process_reel(dt)
	Partie.prof["ombres"] = int(Partie.prof.get("ombres", 0)) + Time.get_ticks_usec() - t0

func _process_reel(dt: float) -> void:
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
	mana = minf(mana_max, mana + (2.5 + 0.6 * Partie.rang_ombre(donnees)) * dt)
	if role == "tank":
		_tank_tick(dt)
	elif role == "soin":
		_soin_tick(dt)
	var c: Monstre = _choisir_cible(dt)
	var vise: Vector3

	var attaque := c != null
	if attaque:

		var a := place * TAU / 8.0 + 0.8
		var r := c.haut() * 0.3 + 1.3
		var vers_j := joueur.global_position - c.global_position
		vers_j.y = 0
		vers_j = vers_j.normalized() if vers_j.length() > 0.1 else Vector3(0, 0, 1)
		if role == "tank":
			vise = c.global_position + vers_j * (c.haut() * 0.3 + 1.8)
		elif role == "dist" or role == "soin":
			vise = c.global_position + vers_j * (7.0 + _role_idx * 1.2) + Vector3(cos(a), 0, -sin(a)) * 1.5
		else:
			vise = c.global_position + Vector3(sin(a), 0, cos(a)) * r
	else:
		var b := Basis(Vector3.UP, joueur._corps.rotation.y)
		var cote := -1.0 if (_role_idx + place) % 2 == 0 else 1.0
		match role:
			"tank":
				vise = joueur.global_position + b * Vector3(cote * (1.5 + _role_idx * 0.6), 0, 1.7 + _role_idx * 0.5)
			"melee":
				vise = joueur.global_position + b * Vector3(cote * (2.0 + _role_idx * 0.6), 0, 0.2 - _role_idx * 0.6)
			"dist":
				vise = joueur.global_position + b * Vector3(cote * (1.0 + _role_idx * 0.7), 0, -2.2 - _role_idx * 0.8)
			_:
				vise = joueur.global_position + b * Vector3(cote * 0.8 * (1 + _role_idx), 0, -3.4 - _role_idx * 1.0)
	var v := vise - global_position
	v.y = 0
	var d := v.length()
	if d > 0.35:
		var vit := clampf(d * 3.0, 2.0, 16.0) * Partie.vit_ombre()
		global_position += v.normalized() * minf(d, vit * dt)
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v.x, v.z), minf(1.0, dt * 10.0))
		if _anim <= 0.0:
			Modele.jouer(_ap, "Run" if vit > 4.0 else "Walk")
	if attaque and _comp.is_empty() and (role == "melee" or role == "dist"):
		_spec_role(dt, c)
	if attaque and not _comp.is_empty():
		_comp_t -= dt
		if _comp_t <= 0.0:
			_comp_t = float(_comp["cd"])
			_competence(c)
	if d > (0.35 if role == "tank" or role == "melee" else 1.8):
		pass
	elif attaque:
		var w := c.global_position - global_position
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(w.x, w.z), minf(1.0, dt * 10.0))
		_coup_t -= dt
		if _coup_t <= 0.0:
			_coup_t = 0.9
			var anim := "Attack" if randf() < 0.6 else "Attack2"
			_anim = Modele.jouer(_ap, anim, 1.5, 0.08) * 0.85
			var deg := Partie.dps_ombre(donnees) * 0.9
			await get_tree().create_timer(0.25).timeout
			if is_instance_valid(c) and not c.mort:
				c.role_source = "dist" if role == "dist" else "melee"
				c.frapper(deg, false, "ombres")
	elif _anim <= 0.0:
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

static var _fum_pm: ParticleProcessMaterial
static var _fum_q: QuadMesh

static func fumee(pos: Vector3, parent: Node, sortie: bool) -> void:
	if _fum_pm == null:
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_RING
		pm.emission_ring_axis = Vector3(0, 1, 0)
		pm.emission_ring_radius = 0.9
		pm.emission_ring_inner_radius = 0.2
		pm.emission_ring_height = 0.1
		pm.direction = Vector3(0, 1, 0)
		pm.spread = 25.0
		pm.initial_velocity_min = 0.6
		pm.initial_velocity_max = 1.8
		pm.gravity = Vector3(0, 0.4, 0)
		pm.scale_min = 2.5
		pm.scale_max = 5.0
		var g := Gradient.new()
		g.set_color(0, Color(0.12, 0.02, 0.22, 0.9))
		g.add_point(0.45, Color(0.05, 0.0, 0.1, 0.7))
		g.set_color(g.get_point_count() - 1, Color(0.0, 0.0, 0.0, 0.0))
		var gt := GradientTexture1D.new()
		gt.gradient = g
		pm.color_ramp = gt
		_fum_pm = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.5, 0.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true
		m.albedo_texture = load("res://assets/fx/smoke_02.png")
		q.material = m
		_fum_q = q
	var p := GPUParticles3D.new()
	p.amount = 30
	p.lifetime = 1.3
	p.one_shot = true
	p.explosiveness = 0.75
	p.process_material = _fum_pm
	p.draw_pass_1 = _fum_q
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
	pv -= d * (0.6 if role == "tank" else 1.0)
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
		c.role_source = "dist" if role == "dist" else "melee"
		c.frapper(Partie.dps_ombre(donnees) * float(_comp["mult"]), true, "ombres")
		Fx.anneau(c.global_position, Color(1.0, 0.45, 0.2), 6.0)

func temps_competence() -> float:
	return _comp_t if not _comp.is_empty() else -1.0
