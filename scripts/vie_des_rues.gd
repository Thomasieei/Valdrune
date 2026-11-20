extends RefCounted

const NOMS := ["Lina", "Yun", "Nora", "Milo"]
const ROLES := ["Coursière", "Mécanicien", "Secouriste", "Docker"]
const TYPES := ["rivalite", "racket", "livraison", "secours"]
var ville: Node
var civils: Array[Chasseur] = []
var rues: Array[Vector3] = []
var a: Chasseur
var b: Chasseur
var type := ""
var phase := ""
var delai := 12.0
var duree := 0.0
var cadence := 0.0
var coups := 0
var derniere := ""
var refuge := Vector3.ZERO
var blesse: Chasseur
var colis: Node3D
var pas := 0.0
var salut := 0.0

func installer(v: Node) -> void:
	ville = v
	for pt in ville.postes():
		rues.append(Vector3(pt[1], 0, pt[2]))
	if rues.is_empty():
		return
	for i in NOMS.size():
		var c := Chasseur.new()
		c.civil = true
		c.d = {"nom": NOMS[i], "niveau": 1, "rang": 0, "look": i}
		c.ville = ville
		ville.add_child(c)
		c.placer(ville.DEPART + Vector3(i * 4 - 5, 0, 3))
		c.mode = "passant"
		c.destination_rue = _promenade(c.global_position)
		civils.append(c)
		_plaque(c)

func _plaque(c: Chasseur) -> void:
	if c.civil:
		c._plaque.text = "%s · %s" % [c.d.nom, ROLES[NOMS.find(c.d.nom)]]
		c._plaque.modulate = Color.BISQUE
	else:
		c._maj_plaque()

func _promenade(p: Vector3) -> Vector3:
	var proches := rues.filter(func (pt: Vector3): return p.distance_squared_to(pt) < 3600.0 and p.distance_squared_to(pt) > 25.0)
	return proches.pick_random() if not proches.is_empty() and randf() < 0.88 else rues.pick_random()

func _rue_proche(p: Vector3) -> Vector3:
	var dest := p
	var dist := INF
	for pt in rues:
		var dd := p.distance_squared_to(pt)
		if dd < dist and dd > 64.0:
			dist = dd
			dest = pt
	return dest

func _acteurs(civil: bool, p: Vector3, sauf: Chasseur = null) -> Chasseur:
	var meilleur: Chasseur
	var distance := INF
	var liste: Array = civils if civil else ville.chasseurs
	for personnage: Chasseur in liste:
		if personnage == sauf or personnage.mode not in ["ville", "passant"]:
			continue
		var dd := personnage.global_position.distance_squared_to(p)
		if dd < distance:
			distance = dd
			meilleur = personnage
	return meilleur

func commencer(nature: String) -> bool:
	if rues.is_empty() or type != "" or nature not in TYPES:
		return false
	a = _acteurs(nature == "livraison", blesse.global_position if nature == "secours" and is_instance_valid(blesse) else ville.joueur.global_position)
	if not a:
		return false
	b = _acteurs(nature != "rivalite", a.global_position, a)
	if nature == "secours" and is_instance_valid(blesse) and blesse.mode == "passant":
		b = blesse
	if not b:
		return false
	type = nature
	derniere = type
	phase = "approche"
	if type == "livraison":
		colis = preload("res://assets/props/Crate_Wooden.gltf").instantiate()
		a._corps.add_child(colis)
		colis.scale = Vector3.ONE * 0.45
		colis.position = Vector3(0, 0.9, 0.4)
	coups = 0
	duree = 70.0
	cadence = 0.0
	refuge = _rue_proche(b.global_position)
	for c in [a,b]:
		c.mode = "rencontre"
		c.cible = null
		c.destination_rue = b.global_position if c == a else c.global_position
		c._but_chemin = Vector3.INF
	return true

func _local(texte: String) -> void:
	if ville.joueur.global_position.distance_to(b.global_position) < 32:
		ville.hud.dire(texte, Color.BISQUE)

func _geste(c: Chasseur, autre: Chasseur, animation: String) -> void:
	var v := autre.global_position - c.global_position
	c._corps.rotation.y = atan2(v.x,v.z)
	c.geste_rue = 0.65
	Modele.jouer(c._ap,animation,1.2,0.08)

func avancer(dt: float) -> void:
	pas += dt
	if pas < 0.25: return
	dt = pas
	pas = 0.0
	var dehors: bool = not (ville.donjon or ville.arene or ville.chateau or ville.abime)
	for c in civils:
		c.visible = dehors and c.global_position.distance_squared_to(ville.joueur.global_position) < 7225
		if c.mode == "passant" and (c.global_position.distance_to(c.destination_rue) < 2.0 or c._bloque_t < 0.26 and c.get_real_velocity().length() < 0.1):
			c.destination_rue = _promenade(c.global_position)
	if type == "":
		if not dehors: return
		salut -= dt
		if salut <= 0.0:
			salut = 2.0
			for c in civils + ville.chasseurs:
				var souvenir: String = Partie.souvenirs_ville.get(c.d.nom,"")
				if souvenir != "" and c.global_position.distance_to(ville.joueur.global_position) < 5.0:
					ville.hud.dire("%s : %s" % [c.d.nom,souvenir], Color.BISQUE)
					salut = 75.0
					break
		delai -= dt
		if delai <= 0.0:
			var choix := TYPES.duplicate()
			choix.erase(derniere)
			commencer("secours" if is_instance_valid(blesse) else choix.pick_random())
			delai = 8.0
		return
	for c in [a,b]:
		c.visible = dehors and c.global_position.distance_squared_to(ville.joueur.global_position) < 7225
	duree -= dt
	cadence -= dt
	var distance := a.global_position.distance_to(b.global_position)
	if phase == "transport":
		if duree <= 0.0:
			_fin("")
		return
	if phase == "approche":
		a.destination_rue = b.global_position
		if distance <= 2.3:
			phase = "scene"
			a.destination_rue = a.global_position
			duree = 28.0
			b._plaque.text = "%s · %s" % [b.d.nom,{"rivalite":"Défi de guilde","racket":"Appel à l’aide","livraison":"Attend un colis","secours":"Blessure"}[type]]
			_local({"rivalite":"Deux chasseurs se disputent une prime.","racket":"Un passant appelle à l’aide.","livraison":"Une coursière cherche son destinataire.","secours":"Un passant blessé appelle un secouriste."}[type])
	elif phase == "scene" and cadence <= 0:
		cadence = 2.5
		coups += 1
		if type in ["rivalite","racket"]:
			var attaquant := b if type == "rivalite" and coups % 2 == 0 else a
			var autre := a if attaquant == b else b
			_geste(attaquant,autre,"Attack")
			_geste(autre,attaquant,"Hit")
			if coups >= 5:
				phase = "fuite"
				b.destination_rue = refuge
				a.destination_rue = a.global_position
				duree = 20.0
		elif type == "secours" and coups == 1:
			_geste(b,a,"Hit")
			Fx.anneau(b.global_position, Color.LIGHT_GREEN, 1.4)
		elif coups >= 5:
			_fin("Colis reçu. La prochaine tournée passe par les quais." if type == "livraison" else "Ça va mieux. Le chasseur m’a soigné.")
			return
	elif phase == "escorte":
		var proche := b.global_position.distance_to(ville.joueur.global_position) < 8.0
		b.destination_rue = refuge if proche else b.global_position
		if b.global_position.distance_to(refuge) < 2.5 and proche:
			_fin("Je me souviens de toi. Tu m’as accompagné jusqu’à l’abri.")
			return
	elif phase == "fuite" and b.global_position.distance_to(refuge) < 2.0:
		_fin("J’ai dû fuir. Je me méfie des chasseurs depuis.")
		return
	if duree <= 0.0:
		_fin("J’ai dû fuir. Je me méfie des chasseurs depuis." if phase == "fuite" else "")

func action() -> Dictionary:
	if type == "livraison" and phase == "approche" and ville.joueur.global_position.distance_to(a.global_position) < 4.5:
		return {"type":"rue","texte":"PORTER"}
	if phase == "transport" and ville.joueur.global_position.distance_to(b.global_position) < 4.5:
		return {"type":"rue","texte":"LIVRER"}
	if phase not in ["scene","fuite"] or ville.joueur.global_position.distance_to(b.global_position) > 4.5:
		return {}
	return {"type":"rue","texte":{"rivalite":"SÉPARER","racket":"PROTÉGER","livraison":"RÉCEPTION","secours":"SOIGNER"}[type]}

func intervenir() -> void:
	if action().is_empty(): return
	if type == "livraison" and phase == "approche":
		phase = "transport"
		duree = 180.0
		a.destination_rue = a.global_position
		colis.reparent(ville.joueur._corps, false)
		b._plaque.text = "%s · Attend ton colis" % b.d.nom
		ville.hud.dire("Apporte le colis à %s." % b.d.nom, Color.BISQUE)
	elif type == "racket":
		phase = "escorte"
		var nav := b.get_world_3d().navigation_map
		var chemin := NavigationServer3D.map_get_path(nav, b.global_position, _rue_proche(b.global_position), true)
		if not chemin.is_empty():
			refuge = chemin[-1]
		duree = 90.0
		a.destination_rue = _rue_proche(a.global_position + Vector3(12,0,0))
		b._plaque.text = "%s · Suis-moi jusqu’à l’abri" % b.d.nom
		_local("Le chasseur recule. Accompagne le passant, il t’attend si tu t’éloignes.")
	else:
		_fin({"rivalite":"Tu as séparé les chasseurs avant que ça dégénère.","livraison":"Merci pour le coup de main avec mon colis.","secours":"Merci de m’avoir soigné dans la rue."}[type])

func _fin(souvenir: String) -> void:
	if type == "racket" and phase == "fuite":
		blesse = b
	elif type == "secours" and b == blesse and souvenir != "":
		blesse = null
	if is_instance_valid(colis):
		colis.queue_free()
		colis = null
	if souvenir != "":
		Partie.souvenirs_ville[b.d.nom] = souvenir
		_local("%s : %s" % [b.d.nom,souvenir])
		Partie.sauver()
	for c in [a,b]:
		c.mode = "passant" if c.civil else "ville"
		c.destination_rue = _promenade(c.global_position)
		c._but_chemin = Vector3.INF
		_plaque(c)
	type = ""
	phase = ""
	a = null
	b = null
	delai = randf_range(18.0,45.0)
