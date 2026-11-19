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

func _ready() -> void:
	var e: Dictionary = Partie.ESPECES[donnees["espece"]]

	var h := minf(float(e["haut"]) * 0.9, 2.3)
	_corps = Modele.creer(e["modele"], h)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)

	var rouge := Partie.rang_ombre(donnees) >= 5
	var mat := Shaders.ombre(Color(1.0, 0.12, 0.2) if rouge else Color(0.42, 0.2, 1.0))
	for m in _corps.find_children("*", "MeshInstance3D", true, false):
		(m as MeshInstance3D).material_override = mat
		(m as MeshInstance3D).material_overlay = null
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

func _process(dt: float) -> void:
	if joueur == null:
		return
	_anim -= dt
	var c: Monstre = joueur.cible
	var vise: Vector3

	var attaque := c != null and is_instance_valid(c) and not c.mort
	if attaque:

		var a := place * TAU / 8.0 + 0.8
		var r := c.haut() * 0.3 + 1.3
		vise = c.global_position + Vector3(sin(a), 0, cos(a)) * r
	else:
		var b := Basis(Vector3.UP, joueur._corps.rotation.y)

		var rangee := place / 2
		var cote := -1.0 if place % 2 == 0 else 1.0
		vise = joueur.global_position + b * Vector3(cote * (1.3 + rangee * 0.5), 0, -1.2 - rangee * 1.1)
	var v := vise - global_position
	v.y = 0
	var d := v.length()
	if d > 0.35:
		var vit := clampf(d * 3.0, 2.0, 16.0)
		global_position += v.normalized() * minf(d, vit * dt)
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v.x, v.z), minf(1.0, dt * 10.0))
		if _anim <= 0.0:
			Modele.jouer(_ap, "Run" if vit > 4.0 else "Walk")
	if attaque and not _comp.is_empty():
		_comp_t -= dt
		if _comp_t <= 0.0:
			_comp_t = float(_comp["cd"])
			_competence(c)
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
			var deg := Partie.dps_ombre(donnees) * 0.9
			await get_tree().create_timer(0.25).timeout
			if is_instance_valid(c) and not c.mort:
				c.frapper(deg, false, "ombres")
	elif _anim <= 0.0:
		Modele.jouer(_ap, "Idle")

	global_position.y = lerpf(global_position.y, joueur.global_position.y, minf(1.0, dt * 8.0))


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
