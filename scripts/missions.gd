class_name Missions
extends Node3D

# Métiers de la ville. Un seul moteur de missions : on prend un contrat chez un employeur,
# on le remplit dans le temps imparti, on est payé. Premier métier : COURSIER.

const RESTOS := ["Chez Marcel", "Le Dragon d'Or", "Pizzeria Luigi", "Ramen Ichiban", "Burger Néon", "Tacos Zone"]
const PLATS := ["Ramen fumant", "Pizza napolitaine", "Kebab frites", "Plateau de sushis", "Burger double", "Tacos XL", "Bubble tea", "Galettes bretonnes", "Soupe miso", "Poulet croustillant"]
const CLIENTS := ["Mme Lambert", "M. Okabe", "Julie", "Le vieux Pascal", "Sofia", "M. Tran", "Inès", "Dr Moreau", "Léo", "Mamie Odette"]
const REPLIQUES := ["Pile à l'heure, merci !", "Encore chaud, bravo !", "Tu es rapide, toi !", "Mon héros ! Voilà pour toi.", "Ça sent bon ! Garde la monnaie.", "Les chasseurs livrent maintenant ? Génial."]
const RETARD := ["C'est froid… mais merci quand même.", "Tu en as mis du temps…", "J'avais faim, moi !"]

var ville: Node3D
var restos: Array = []
var actif := false
var m := {}
var _client: Node3D
var _faisceau: MeshInstance3D
var _plat_n := 0

func installer(v: Node3D, pts: Array) -> void:
	ville = v
	if pts.size() < 8:
		return
	# 1er restaurant près du départ (visible dès le début), les autres répartis dans la ville
	var choisis: Array = []
	var depart: Vector3 = ville.DEPART
	var tri := pts.duplicate()
	tri.sort_custom(func (a, b): return Vector2(a.x - depart.x, a.z - depart.z).length() < Vector2(b.x - depart.x, b.z - depart.z).length())
	for p in tri:
		if Vector2(p.x - depart.x, p.z - depart.z).length() > 22.0:
			choisis.append(p)
			break
	while choisis.size() < 6:
		var mieux: Vector3 = pts[0]
		var d_max := -1.0
		for p in pts:
			var dmin := INF
			for c in choisis:
				dmin = minf(dmin, Vector2(p.x - c.x, p.z - c.z).length())
			if dmin > d_max:
				d_max = dmin
				mieux = p
		choisis.append(mieux)
	for k in choisis.size():
		restos.append({"pos": choisis[k], "nom": RESTOS[k]})
		_stand(choisis[k], RESTOS[k])

func _mat(c: Color, emis := false) -> StandardMaterial3D:
	var s := StandardMaterial3D.new()
	s.albedo_color = c
	if emis:
		s.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		s.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		s.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		s.cull_mode = BaseMaterial3D.CULL_DISABLED
	return s

func _stand(p: Vector3, nom: String) -> void:
	var n := Node3D.new()
	add_child(n)
	n.global_position = p
	n.rotation.y = randf() * TAU
	var compt := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(2.4, 1.0, 0.9)
	compt.mesh = b
	compt.material_override = _mat(Color(0.35, 0.2, 0.1))
	compt.position = Vector3(0, 0.5, 0.9)
	n.add_child(compt)
	var toit := MeshInstance3D.new()
	var t := BoxMesh.new()
	t.size = Vector3(2.8, 0.12, 1.6)
	toit.mesh = t
	toit.material_override = _mat(Color(1.0, 0.45, 0.15))
	toit.position = Vector3(0, 2.6, 0.7)
	toit.rotation.x = 0.18
	n.add_child(toit)
	for sx in [-1.2, 1.2]:
		var pl := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.05
		cy.bottom_radius = 0.05
		cy.height = 2.6
		cy.radial_segments = 5
		pl.mesh = cy
		pl.material_override = _mat(Color(0.2, 0.2, 0.25))
		pl.position = Vector3(sx, 1.3, 1.3)
		n.add_child(pl)
	var cuisto: Node3D = Apparence.kang.call()
	cuisto = Modele.preparer(cuisto, "resto_cuisto", 1.8)
	cuisto.position = Vector3(0, 0, 0.1)
	cuisto.rotation.y = PI
	n.add_child(cuisto)
	var ap := Modele.lecteur(cuisto)
	Modele.jouer(ap, "Idle")
	if ap:
		ap.seek(randf() * 2.0, true)
	var lb := Label3D.new()
	lb.text = "%s\nLIVRAISONS" % nom
	lb.font = Ui.police
	lb.font_size = 30
	lb.outline_size = 9
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(1.0, 0.75, 0.35)
	lb.position.y = 3.2
	lb.visibility_range_end = 70.0
	n.add_child(lb)
	var lum := OmniLight3D.new()
	lum.light_color = Color(1.0, 0.7, 0.35)
	lum.light_energy = 1.0
	lum.omni_range = 6.0
	lum.position = Vector3(0, 2.2, 1.0)
	n.add_child(lum)
	# colonne de lumière orange visible de loin
	n.add_child(_colonne(Color(1.0, 0.6, 0.2, 0.35), 40.0, 0.5))

func _colonne(c: Color, h: float, r: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = r
	cy.bottom_radius = r
	cy.height = h
	cy.radial_segments = 8
	cy.cap_top = false
	cy.cap_bottom = false
	mi.mesh = cy
	mi.material_override = _mat(c, true)
	mi.position.y = h / 2.0
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.visibility_range_end = 260.0
	return mi

func _process(dt: float) -> void:
	if not actif or ville == null:
		return
	if ville.donjon != null or ville.chateau != null or ville.abime != null:
		return
	m["t"] = float(m["t"]) - dt
	if float(m["t"]) <= 0.0:
		echouer()

# ---------- Interaction ----------
func action(p: Vector3) -> Dictionary:
	if actif and _client and is_instance_valid(_client) and p.distance_to(_client.global_position) < 3.4:
		return {"type": "livrer"}
	for k in restos.size():
		if p.distance_to(restos[k]["pos"]) < 4.6:
			return {"type": "resto", "idx": k}
	return {}

func prendre(k: int) -> void:
	if actif:
		ville.hud.dire("Termine d'abord ta livraison en cours.", Color(1.0, 0.7, 0.4))
		return
	var depart: Vector3 = restos[k]["pos"]
	var pts: Array = ville.pts_rue.filter(func (q): return Vector2(q.x - depart.x, q.z - depart.z).length() > 70.0 and Vector2(q.x - depart.x, q.z - depart.z).length() < 330.0)
	if pts.is_empty():
		pts = ville.pts_rue
	var dest: Vector3 = pts.pick_random()
	var d := Vector2(dest.x - depart.x, dest.z - depart.z).length()
	var niv := _niveau()
	var vit: float = Joueur.VITESSE * Partie.vitesse() * 1.7
	var temps: float = d * 1.35 / vit + 18.0
	var gain := int((12.0 + d * 0.2) * (1.0 + 0.12 * (niv - 1)) * (1.0 + 0.8 * Partie.rang_chasseur))
	var plat: String = PLATS[_plat_n % PLATS.size()]
	_plat_n += 1
	var cl: String = CLIENTS.pick_random()
	m = {"resto": restos[k]["nom"], "plat": plat, "client": cl, "dest": dest, "t": temps, "t_max": temps, "gain": gain}
	actif = true
	_poser_client(dest, cl)
	ville.hud.dire("Livraison : %s → %s (%d m)" % [plat, cl, int(d)], Color(1.0, 0.85, 0.5))
	Fx.son("open", -4.0, 1.3)

func _poser_client(dest: Vector3, nom: String) -> void:
	_nettoyer()
	_client = Node3D.new()
	add_child(_client)
	_client.global_position = dest
	var n: Node3D = [Apparence.mira, Apparence.esil].pick_random().call()
	var corps := Modele.preparer(n, "client_pnj", 1.76)
	_client.add_child(corps)
	var ap := Modele.lecteur(corps)
	Modele.jouer(ap, "Idle")
	var lb := Label3D.new()
	lb.text = nom
	lb.font = Ui.police
	lb.font_size = 28
	lb.outline_size = 9
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(0.5, 0.95, 1.0)
	lb.position.y = 2.4
	_client.add_child(lb)
	_faisceau = _colonne(Color(0.3, 0.85, 1.0, 0.4), 60.0, 0.6)
	_client.add_child(_faisceau)

func _nettoyer() -> void:
	if _client and is_instance_valid(_client):
		_client.queue_free()
	_client = null

func livrer() -> void:
	if not actif:
		return
	var reste: float = float(m["t"]) / float(m["t_max"])
	var rapide := reste > 0.5
	var gain := int(m["gain"] * (1.5 if rapide else 1.0))
	Partie.gain_travail(gain, int(gain * 0.25))
	Partie.metier["coursier"]["livrees"] = int(Partie.metier["coursier"]["livrees"]) + 1
	var niv_av := _niveau_de(int(Partie.metier["coursier"]["livrees"]) - 1)
	var rep: String = REPLIQUES.pick_random() if rapide else RETARD.pick_random()
	Fx.texte(_client.global_position + Vector3(0, 2.8, 0), rep, Color(0.7, 1.0, 0.8), 1.2, 2.2)
	Fx.texte(_client.global_position + Vector3(0, 3.6, 0), "+%d or%s" % [gain, "  (RAPIDE ×1.5)" if rapide else ""], Color(1.0, 0.85, 0.3), 1.5, 1.8)
	Fx.explosion(_client.global_position, Color(1.0, 0.85, 0.4), 1.8)
	Fx.son("orb", 0.0, 1.2)
	if _niveau() > niv_av:
		ville.hud.systeme("COURSIER — NIVEAU %d" % _niveau(), ["Les livraisons paient mieux.", "Livraisons effectuées : %d" % int(Partie.metier["coursier"]["livrees"])])
	_fin()

func echouer() -> void:
	ville.hud.dire("Livraison échouée : le client n'a plus faim…", Color(1.0, 0.5, 0.45))
	Fx.son("error", -4.0)
	_fin()

func _fin() -> void:
	actif = false
	m = {}
	_nettoyer()
	Partie.change.emit()

func _niveau_de(n: int) -> int:
	return mini(1 + n / 5, 20)

func _niveau() -> int:
	return _niveau_de(int(Partie.metier["coursier"]["livrees"]))

# ---------- Interface ----------
func guide() -> Dictionary:
	if actif and _client and is_instance_valid(_client):
		return {"pos": _client.global_position, "couleur": Color(0.3, 0.85, 1.0), "nom": m["client"]}
	if not actif and ville and ville.donjon == null:
		# propose le restaurant le plus proche tant qu'on n'a pas de livraison
		var p: Vector3 = ville.joueur.global_position
		var mieux := -1
		var dm := INF
		for k in restos.size():
			var d := p.distance_to(restos[k]["pos"])
			if d < dm:
				dm = d
				mieux = k
		if mieux >= 0 and dm > 25.0 and int(Partie.metier["coursier"]["livrees"]) < 1:
			return {"pos": restos[mieux]["pos"], "couleur": Color(1.0, 0.65, 0.25), "nom": "Livraisons"}
	return {}

func texte() -> String:
	if not actif or _client == null or not is_instance_valid(_client):
		return ""
	var d := int(ville.joueur.global_position.distance_to(_client.global_position))
	var t := maxi(int(float(m["t"])), 0)
	return "LIVRAISON : %s → %s\n%d m  ·  %d:%02d  ·  +%d or" % [m["plat"], m["client"], d, t / 60, t % 60, int(m["gain"])]
