class_name Appart
extends Node3D

# L'appartement du joueur : une pièce à part, sa sœur Mina, un loyer à payer chaque jour.

const BASE := Vector3(2600.0, 0.0, 2600.0)
const PHRASES_OK := ["Tu es rentré ! J'ai préparé du thé.", "J'ai vu des chasseurs passer en bas… fais attention à toi.", "Grâce à toi, on a un toit. Merci.", "Raconte-moi ta journée dans les donjons !", "Quelqu'un a parlé de toi au marché aujourd'hui.", "Tu devrais dormir un peu, tu as l'air épuisé.", "J'ai peur quand tu pars… mais je suis fière de toi."]
const PHRASES_RANG := ["On parle de toi dans tout le quartier, tu sais.", "Des gens en costume sont venus demander si tu cherchais une guilde.", "Tu deviens quelqu'un d'important. Ne m'oublie pas."]
const PHRASES_LOYER := ["Le propriétaire est passé… il réclame le loyer.", "On doit encore de l'argent. Tu peux régler ça ?", "Je n'ai pas osé ouvrir la porte quand il a frappé."]
const PHRASES_DETTE := ["Il a parlé d'expulsion… j'ai peur.", "Je n'arrive plus à dormir avec cette dette.", "Dis-moi qu'on ne va pas finir dans la rue…"]

var ville: Node3D
var porte_pos := Vector3.ZERO
var _soeur: Node3D
var _sortie := Vector3(0, 0, 4.0)
var _t_loyer := 5.0
var _annonce_jour := -1
var _bulle_t := 0.0

func installer(v: Node3D, pts: Array) -> void:
	ville = v
	var depart: Vector3 = v.DEPART
	var tri := pts.duplicate()
	tri.sort_custom(func (a, b): return Vector2(a.x - depart.x, a.z - depart.z).length() < Vector2(b.x - depart.x, b.z - depart.z).length())
	var resto0: Vector3 = v.missions.restos[0]["pos"] if v.missions and v.missions.restos.size() > 0 else depart
	for p in tri:
		if Vector2(p.x - depart.x, p.z - depart.z).length() > 28.0 and Vector2(p.x - resto0.x, p.z - resto0.z).length() > 26.0 and not v.mur_proche(p).is_empty():
			porte_pos = p
			break
	if porte_pos == Vector3.ZERO and tri.size() > 3:
		porte_pos = tri[3]
	_porte()
	_interieur()

func _mat(c: Color, emis := false) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	if emis:
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.emission_enabled = true
		s.emission = c
	return s

func _boite(parent: Node3D, pos: Vector3, taille: Vector3, c: Color, emis := false, collision := false) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = _mat(c, emis)
	mi.position = pos
	parent.add_child(mi)
	if collision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		sb.add_child(cs)
		mi.add_child(sb)
	return mi

func _label(parent: Node3D, t: String, pos: Vector3, c: Color, taille := 30) -> Label3D:
	var lb := Label3D.new()
	lb.text = t
	lb.font = Ui.police
	lb.font_size = taille
	lb.outline_size = 9
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = c
	lb.position = pos
	lb.visibility_range_end = 70.0
	parent.add_child(lb)
	return lb

# Entrée de l'immeuble : une porte plate posée sur la façade d'un vrai bâtiment
func _porte() -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = porte_pos
	var mur: Dictionary = ville.mur_proche(porte_pos)
	if not mur.is_empty():
		var nm: Vector3 = mur["normal"]
		var mp: Vector3 = mur["pos"]
		n.global_position = Vector3(mp.x, porte_pos.y, mp.z) + nm * 0.08
		n.rotation.y = atan2(nm.x, nm.z)
		porte_pos = n.global_position + nm * 2.0
		_sortie = nm * 2.6
	var cadre := _boite(n, Vector3(0, 1.35, 0.02), Vector3(1.9, 2.7, 0.05), Color(0.12, 0.14, 0.18))
	cadre.material_override = _mat(Color(0.12, 0.14, 0.18))
	_boite(n, Vector3(0, 1.3, 0.06), Vector3(1.6, 2.5, 0.05), Color(0.2, 0.85, 0.5), true)
	_label(n, "TON APPARTEMENT", Vector3(0, 3.2, 0.4), Color(0.6, 1.0, 0.75), 26).visibility_range_end = 30.0

func _interieur() -> void:
	var r := Node3D.new()
	add_child(r)
	r.global_position = BASE
	_boite(r, Vector3(0, -0.2, 0), Vector3(18, 0.4, 14), Color(0.3, 0.19, 0.12), false, true)
	_boite(r, Vector3(0, 5.2, 0), Vector3(18, 0.3, 14), Color(0.2, 0.2, 0.26))
	var mur := Color(0.5, 0.46, 0.55)
	_boite(r, Vector3(0, 2.5, -7.0), Vector3(18, 5, 0.4), mur, false, true)
	_boite(r, Vector3(0, 2.5, 7.0), Vector3(18, 5, 0.4), mur, false, true)
	_boite(r, Vector3(-9.0, 2.5, 0), Vector3(0.4, 5, 14), mur, false, true)
	_boite(r, Vector3(9.0, 2.5, 0), Vector3(0.4, 5, 14), mur, false, true)
	# baie vitrée avec la ville la nuit
	_boite(r, Vector3(0, 2.6, -6.75), Vector3(10, 3.2, 0.1), Color(0.05, 0.08, 0.2), true)
	for k in 14:
		var tw := MeshInstance3D.new()
		var b := BoxMesh.new()
		b.size = Vector3(1.0, 1.0, 1.0)
		tw.mesh = b
		tw.material_override = Skyline.materiau()
		var hh := randf_range(1.5, 3.1)
		var ww := randf_range(0.7, 1.4)
		tw.scale = Vector3(ww, hh, ww)
		tw.position = Vector3(-4.6 + k * 0.7, 1.0 + hh / 2.0 - 0.1, -6.62)
		r.add_child(tw)
	# mobilier
	_boite(r, Vector3(-6.2, 0.35, -3.8), Vector3(2.4, 0.7, 3.4), Color(0.25, 0.3, 0.55), false, true)
	_boite(r, Vector3(-6.2, 0.8, -5.1), Vector3(1.6, 0.25, 0.8), Color(0.9, 0.9, 0.95))
	_label(r, "LIT", Vector3(-6.2, 1.7, -3.8), Color(0.7, 0.8, 1.0), 26)
	_boite(r, Vector3(5.5, 0.4, -2.0), Vector3(3.0, 0.8, 1.1), Color(0.5, 0.25, 0.25), false, true)
	_boite(r, Vector3(1.8, 0.45, 0.8), Vector3(1.8, 0.9, 1.8), Color(0.45, 0.3, 0.2), false, true)
	_boite(r, Vector3(6.4, 0.5, 3.8), Vector3(1.8, 1.0, 1.2), Color(0.85, 0.8, 0.7), false, true)
	_label(r, "LOYER", Vector3(6.4, 1.7, 3.8), Color(1.0, 0.85, 0.35), 26)
	_boite(r, Vector3(6.4, 1.05, 3.8), Vector3(0.5, 0.06, 0.35), Color(1.0, 0.9, 0.4), true)
	# porte de sortie
	_boite(r, Vector3(0, 1.5, 6.75), Vector3(2.0, 3.0, 0.1), Color(0.2, 0.8, 0.45), true)
	_label(r, "SORTIR", Vector3(0, 3.5, 6.5), Color(0.5, 1.0, 0.7), 26)
	for lp in [Vector3(-4, 3.8, 0), Vector3(4, 3.8, 0), Vector3(0, 3.8, 4)]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.82, 0.6)
		l.light_energy = 1.6
		l.omni_range = 11.0
		l.position = lp
		r.add_child(l)
	# Mina
	var n: Node3D = Apparence.mira.call()
	_soeur = Modele.preparer(n, "soeur_mina", 1.62)
	_soeur.position = Vector3(3.2, 0, -3.0)
	_soeur.rotation.y = PI * 0.8
	r.add_child(_soeur)
	var ap := Modele.lecteur(_soeur)
	Modele.jouer(ap, "Idle")
	_label(r, "Mina (ta sœur)", Vector3(3.2, 2.2, -3.0), Color(1.0, 0.75, 0.9), 28)

func point_entree() -> Vector3:
	return BASE + Vector3(0, 0.4, 5.2)

func pos_soeur() -> Vector3:
	return BASE + Vector3(3.2, 0, -3.0)

# ---------- Interaction ----------
func action(p: Vector3) -> Dictionary:
	if ville.chez_soi:
		var loc := p - BASE
		if Vector2(loc.x, loc.z).distance_to(Vector2(0, 6.0)) < 2.8:
			return {"type": "appart_sortir"}
		if Vector2(loc.x, loc.z).distance_to(Vector2(3.2, -3.0)) < 2.6:
			return {"type": "soeur"}
		if Vector2(loc.x, loc.z).distance_to(Vector2(-6.2, -3.8)) < 3.0:
			return {"type": "lit"}
		if Vector2(loc.x, loc.z).distance_to(Vector2(6.4, 3.8)) < 2.7:
			return {"type": "loyer"}
		return {}
	if p.distance_to(porte_pos) < 3.8:
		return {"type": "appart_entrer"}
	return {}

func entrer() -> void:
	if ville.chez_soi or ville.donjon or ville.chateau or ville.abime:
		return
	await ville.hud.fondu(true)
	ville.chez_soi = true
	ville.joueur.viser(null)
	ville._teleporter(point_entree(), PI)
	ville._ambiance(true)
	ville._env.ambient_light_color = Color(0.75, 0.6, 0.5)
	ville._env.ambient_light_energy = 1.3
	ville._env.fog_density = 0.0006
	ville._env.fog_light_color = Color(0.3, 0.25, 0.3)
	await ville.hud.chargement("Entrée dans ton appartement…", 0.9)
	await ville.hud.fondu(false)
	var du := Partie.loyer_du()
	if du > 0:
		ville.hud.dire("Loyer dû : %d or — dépose-le sur le bureau." % du, Color(1.0, 0.75, 0.4))
	else:
		ville.hud.dire("Chez toi. Mina est là.", Color(0.8, 1.0, 0.85))

func sortir() -> void:
	if not ville.chez_soi:
		return
	await ville.hud.fondu(true)
	ville.chez_soi = false
	ville._ambiance(false)
	ville._teleporter(porte_pos + _sortie + Vector3(0, 0.3, 0), 0.0)
	await ville.hud.chargement("Retour en ville…", 0.6)
	await ville.hud.fondu(false)

func parler() -> void:
	var j := Partie.jours_impayes()
	var l: Array = PHRASES_OK
	if j >= 3:
		l = PHRASES_DETTE
	elif j >= 1:
		l = PHRASES_LOYER
	elif Partie.rang_chasseur >= 2 and randf() < 0.4:
		l = PHRASES_RANG
	var t: String = l.pick_random()
	Fx.texte(pos_soeur() + Vector3(0, 2.7, 0), t, Color(1.0, 0.85, 0.95), 1.1, 3.4)
	ville.hud.dire("Mina : « %s »" % t, Color(1.0, 0.85, 0.95))
	Fx.son("open", -8.0, 1.5)

func dormir() -> void:
	if Partie.jours_impayes() >= 3:
		ville.hud.dire("Impossible de dormir avec cette dette. Paye le loyer.", Color(1.0, 0.6, 0.5))
		return
	await ville.hud.fondu(true)
	Partie.pv = Partie.pv_max()
	Partie.mana = Partie.mana_max()
	Partie.change.emit()
	await ville.get_tree().create_timer(0.6).timeout
	await ville.hud.fondu(false)
	ville.hud.dire("Tu as bien dormi : PV et mana restaurés.", Color(0.6, 0.9, 1.0))

func payer() -> void:
	var du := Partie.loyer_du()
	if du <= 0:
		ville.hud.dire("Loyer à jour. Prochain paiement demain.", Color(0.7, 1.0, 0.8))
		return
	if Partie.payer_loyer():
		ville.hud.dire("Loyer payé : -%d or. Mina est soulagée." % du, Color(0.6, 1.0, 0.7))
		Fx.son("orb", 0.0, 0.9)
	else:
		ville.hud.dire("Pas assez d'or : %d requis." % du, Color(1.0, 0.6, 0.5))
		Fx.son("error", -6.0)

func _process(dt: float) -> void:
	_t_loyer -= dt
	if _t_loyer > 0.0 or ville == null or ville.chez_soi or ville.donjon != null:
		return
	_t_loyer = 45.0
	var du := Partie.loyer_du()
	var jour := int(Time.get_unix_time_from_system() / 86400.0)
	if du > 0 and _annonce_jour != jour:
		_annonce_jour = jour
		ville.hud.systeme("LOYER DÛ", ["Le propriétaire réclame %d or." % du, "Rentre à ton appartement pour payer."])
