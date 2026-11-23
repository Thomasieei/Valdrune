class_name Escorte
extends Node3D

# Métier : garde du corps. Un client terrifié doit traverser la ville à pied ; des embuscades de monstres l'attendent en chemin.
const REP_CLIENT := ["Ils sont là… je les entends respirer.", "Ne me laissez pas seul !", "Je sens quelque chose derrière nous…", "Faites vite, je vous en supplie !", "Les murs… ils nous regardent."]
const REP_MONSTRE := ["Il sent si bon… la peur.", "On t'attendait.", "Reste avec nous…", "Il ne fallait pas sortir ce soir.", "Chuuut… ne crie pas."]

var ville: Node3D
var bureau := Vector3.INF
var actif := false
var _c: Node3D
var _ap: AnimationPlayer
var _route := PackedVector2Array()
var _i := 1
var _pv := 100.0
var _t := 0.0
var _dest := Vector3.ZERO
var _dist := 0.0
var _emb: Array = []
var _emb_fait := [false, false, false]
var _emb_pts := [0.3, 0.55, 0.8]
var _yt := 0.0
var _y := 0.0
var _parle := 4.0
var _marq: MeshInstance3D
var _anim_cur := ""

func installer(v: Node3D, pts: Array) -> void:
	ville = v
	var dep: Vector3 = v.DEPART
	var resto0: Vector3 = v.missions.restos[0]["pos"] if v.missions and v.missions.restos.size() > 0 else dep
	var tri := pts.duplicate()
	tri.sort_custom(func (a, b): return Vector2(a.x - dep.x, a.z - dep.z).length() < Vector2(b.x - dep.x, b.z - dep.z).length())
	for p in tri:
		var d := Vector2(p.x - dep.x, p.z - dep.z).length()
		if d < 28.0 or d > 90.0:
			continue
		if Vector2(p.x - resto0.x, p.z - resto0.z).length() < 24.0:
			continue
		if v.appart and Vector2(p.x - v.appart.porte_pos.x, p.z - v.appart.porte_pos.z).length() < 40.0:
			continue
		var mur: Dictionary = v.mur_proche(p)
		if mur.is_empty():
			continue
		_bureau(mur, p)
		return

func _bureau(mur: Dictionary, p: Vector3) -> void:
	var nm: Vector3 = mur["normal"]
	var mp: Vector3 = mur["pos"]
	var n := Node3D.new()
	add_child(n)
	n.global_position = Vector3(mp.x, p.y, mp.z) + nm * 0.1
	n.rotation.y = atan2(nm.x, nm.z)
	bureau = n.global_position + nm * 2.0
	var cadre := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.6, 2.7, 0.06)
	cadre.mesh = b
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.12, 0.2, 0.4)
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	cadre.material_override = m
	cadre.position = Vector3(0, 1.35, 0.03)
	n.add_child(cadre)
	var lb := Label3D.new()
	lb.text = "AGENCE DE PROTECTION\nEscortes · garde du corps"
	lb.font = Ui.police
	lb.font_size = 26
	lb.outline_size = 8
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(0.55, 0.8, 1.0)
	lb.position = Vector3(0, 3.2, 0.4)
	lb.visibility_range_end = 30.0
	n.add_child(lb)

func action(p: Vector3) -> Dictionary:
	if bureau != Vector3.INF and not actif and p.distance_to(bureau) < 4.2:
		return {"type": "escorte_prendre"}
	return {}

func _chemin(p: Vector3, q: Vector3) -> PackedVector2Array:
	var res := PackedVector2Array()
	var carte: Carte = ville.carte
	var ids: Array = carte._astar.get_id_path(carte._libre(carte._cell(Vector2(p.x, p.z))), carte._libre(carte._cell(Vector2(q.x, q.z))))
	if ids.size() < 8:
		return res
	for id: Vector2i in ids:
		res.append(Vector2(Carte.X0 + (id.x + 0.5) * Carte.CELL, Carte.Z0 + (id.y + 0.5) * Carte.CELL))
	return res

func prendre() -> void:
	if actif or ville.donjon != null or ville.chateau != null or ville.abime != null or ville.chez_soi:
		return
	if ville.missions and ville.missions.actif:
		ville.hud.dire("Termine ta livraison d'abord.", Color(1.0, 0.7, 0.4))
		return
	var tri: Array = ville.pts_rue.duplicate()
	tri.shuffle()
	for q: Vector3 in tri:
		var d := bureau.distance_to(q)
		if d < 120.0 or d > 300.0:
			continue
		var ch := _chemin(bureau, q)
		if ch.is_empty():
			continue
		_route = ch
		_dest = q
		_dist = d
		break
	if _route.is_empty():
		ville.hud.dire("Aucun client disponible pour l'instant.", Color(1.0, 0.7, 0.4))
		return
	_c = Foule._civil(randf() < 0.5)
	add_child(_c)
	_c.global_position = bureau
	_ap = Modele.lecteur(_c)
	_anim_cur = ""
	_anim("Idle")
	_i = 1
	_pv = 100.0
	_emb.clear()
	_emb_fait = [false, false, false]
	var niv := 1 + int(Partie.metier.get("garde", {}).get("faites", 0)) / 4
	_t = _dist * 1.15 / 2.1 + 45.0
	actif = true
	_marq = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 1.2
	cy.bottom_radius = 1.2
	cy.height = 70.0
	cy.cap_top = false
	cy.cap_bottom = false
	cy.radial_segments = 10
	_marq.mesh = cy
	var mm := StandardMaterial3D.new()
	mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	mm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	mm.cull_mode = BaseMaterial3D.CULL_DISABLED
	mm.albedo_color = Color(0.7, 0.45, 1.0, 0.3)
	_marq.material_override = mm
	_marq.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_marq)
	_marq.global_position = _dest + Vector3(0, 35.0, 0)
	ville.hud.systeme("ESCORTE", ["Conduis ton client à destination (%d m)." % int(_dist), "Reste près de lui : des monstres rôdent.", "Niveau de métier : %d" % niv])
	Fx.texte(_c.global_position + Vector3(0, 2.3, 0), "Merci d'être venu… vite.", Color(1.0, 0.9, 0.7), 1.1, 2.0)

func _anim(nom: String, vit := 1.0) -> void:
	if _ap and _anim_cur != nom:
		_anim_cur = nom
		Modele.jouer(_ap, nom, vit, 0.15)

func _embuscade() -> void:
	var idx := mini(_i + 4, _route.size() - 1)
	var pt := Vector3(_route[idx].x, _c.global_position.y, _route[idx].y)
	var rg: int = ville.rang_zone(pt)
	var l: Array = Partie.ESPECES_RANG[mini(rg, 3)]
	for k in 3:
		var m := Monstre.new()
		var a := TAU * k / 3.0
		m.configurer(l[k % 2], pt + Vector3(cos(a), 0, sin(a)) * 3.0, a + PI)
		m.reapparait_auto = false
		m.elite_fixe = k == 0 and rg >= 1
		ville.add_child(m)
		ville.monstres.append(m)
		_emb.append(m)
		Fx.texte(m.global_position + Vector3(0, m.haut() + 1.2, 0), REP_MONSTRE.pick_random(), Color(0.9, 0.3, 0.45), 1.1, 2.4)
	ville.hud.annonce("EMBUSCADE !", "Protège ton client", Color(1.0, 0.35, 0.4))

func texte() -> String:
	if not actif:
		return ""
	var reste := _c.global_position.distance_to(_dest) if _c else 0.0
	return "ESCORTE · %d m · %d:%02d · client %d %%" % [int(reste), int(_t) / 60, int(_t) % 60, int(_pv)]

func guide() -> Dictionary:
	if actif:
		return {"nom": "Destination du client", "pos": _dest, "col": Color(0.75, 0.5, 1.0)}
	return {}

func _fin(ok: bool, raison: String) -> void:
	actif = false
	if _marq:
		_marq.queue_free()
	if ok:
		var f: Dictionary = Partie.metier.get("garde", {"faites": 0})
		f["faites"] = int(f["faites"]) + 1
		Partie.metier["garde"] = f
		var niv := 1 + int(f["faites"]) / 4
		var gain := int((60.0 + 0.45 * _dist) * (1.0 + 0.12 * (niv - 1)) * (1.0 + 0.8 * Partie.rang_chasseur) * (0.6 + 0.4 * _pv / 100.0))
		Partie.gain_travail(gain, gain * 0.35)
		Fx.pieces(ville.joueur.global_position + Vector3(0, 1.0, 0), gain)
		_anim("Celebrate")
		ville.hud.systeme("ESCORTE RÉUSSIE", ["Client sain et sauf (%d %%)." % int(_pv), "+%d pièces" % gain, "Escortes réussies : %d" % int(f["faites"])])
	else:
		ville.hud.systeme("ESCORTE ÉCHOUÉE", [raison])
		_anim("Death")
	var c := _c
	get_tree().create_timer(4.0).timeout.connect(func (): if is_instance_valid(c): c.queue_free())
	_c = null

func _process(dt: float) -> void:
	if not actif or _c == null or ville.joueur == null:
		return
	if ville.donjon != null or ville.chateau != null or ville.abime != null or ville.chez_soi:
		return
	_t -= dt
	if _t <= 0.0:
		_fin(false, "Temps écoulé.")
		return
	var pj: Vector3 = ville.joueur.global_position
	var pc: Vector3 = _c.global_position
	var menace := 0
	for m in _emb:
		if is_instance_valid(m) and not m.mort and m.global_position.distance_to(pc) < 4.5:
			menace += 1
	if menace > 0:
		_pv -= menace * 6.0 * dt
		if _pv <= 0.0:
			_fin(false, "Le client n'a pas survécu.")
			return
	var frac := float(_i) / float(maxi(_route.size() - 1, 1))
	for k in 3:
		if not _emb_fait[k] and frac >= float(_emb_pts[k]):
			_emb_fait[k] = true
			_embuscade()
	if pc.distance_to(_dest) < 3.5:
		_fin(true, "")
		return
	_parle -= dt
	var d_j := pc.distance_to(pj)
	if menace > 0:
		_anim("Block")
	elif d_j > 14.0:
		_anim("Idle")
		if _parle <= 0.0:
			_parle = 6.0
			Fx.texte(pc + Vector3(0, 2.3, 0), "Attendez-moi !", Color(1.0, 0.85, 0.5), 1.1, 1.6)
	else:
		if _i < _route.size():
			var dir := _route[_i] - Vector2(pc.x, pc.z)
			if dir.length() < 1.0:
				_i += 1
			else:
				var pas := dir.normalized() * 2.1 * dt
				_c.global_position.x += pas.x
				_c.global_position.z += pas.y
				_c.rotation.y = lerp_angle(_c.rotation.y, atan2(dir.x, dir.y), minf(1.0, dt * 8.0))
				_anim("Walk", 1.3)
		if _parle <= 0.0:
			_parle = randf_range(7.0, 11.0)
			Fx.texte(pc + Vector3(0, 2.3, 0), REP_CLIENT.pick_random(), Color(0.95, 0.85, 1.0), 1.0, 2.2)
	_yt -= dt
	if _yt <= 0.0:
		_yt = 0.25
		_y = ville._sol(pc.x, pc.z)
	_c.global_position.y = lerpf(_c.global_position.y, _y, minf(1.0, dt * 8.0))
