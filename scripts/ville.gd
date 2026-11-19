extends Node3D


const ECHELLE_VILLE := 0.01
const DEPART := Vector3(-157.6, 0.2, -71.0)






const POSTES := [
	["gobelin", -171.0, -73.8, 90.0], ["gobelin", -178.0, -68.8, 80.0],
	["gobelin", -185.0, -73.6, 95.0], ["gobelin", -192.0, -68.6, 85.0],
	["puglin", -128.0, -73.6, -90.0], ["puglin", -120.0, -68.8, -95.0], ["puglin", -112.0, -73.4, -85.0],
	["gobelin_chef", -158.0, -107.5, 95.0], ["gobelin_chef", -168.0, -103.5, 90.0],
	["gobelin_chef", -178.0, -109.0, 80.0],
	["puglin_brute", -89.0, -90.0, 180.0], ["puglin_brute", -88.0, -103.0, 180.0], ["puglin_brute", -90.0, -114.0, 170.0],
	["orc", -141.5, -96.0, 180.0], ["orc", -141.0, -118.0, 180.0],
	["diablotin", -107.5, -96.0, 180.0], ["diablotin", -107.5, -116.0, 180.0],
	["orc_guerrier", -126.0, -46.0, 20.0], ["orc_guerrier", -116.0, -50.0, -10.0],
	["demon", -98.0, -48.0, 0.0], ["demon", -88.0, -40.0, -40.0],
	["chevalier", -140.0, -45.0, 0.0],
	["seigneur_givre", -90.0, -18.0, -20.0],
	["gobelin", -174.5, -71.2, 85.0], ["gobelin", -188.5, -71.2, 90.0],
	["puglin", -124.0, -71.0, -90.0], ["puglin", -116.0, -71.3, -90.0],
	["gobelin_chef", -163.0, -106.0, 90.0], ["gobelin_chef", -173.0, -106.0, 90.0],
	["puglin_brute", -89.0, -96.5, 180.0], ["puglin_brute", -89.0, -108.5, 175.0],
	["orc", -141.0, -107.0, 180.0], ["diablotin", -107.5, -106.0, 180.0],
	["orc_guerrier", -121.0, -48.0, 5.0], ["demon", -93.0, -44.0, -20.0],
]

const AUTELS := [["ombres", -177.0, -57.5], ["arme", -167.0, -57.5], ["chance", -157.0, -57.5]]
const PORTAIL := Vector3(-191.0, 0.0, -56.0)
const LIEU_EVENEMENT := Vector3(-114.0, 0.0, -24.0)
const PERIODE_EVENEMENT := 900.0
const DUREE_EVENEMENT := 300.0

var joueur: Joueur
var camera: Camera3D
var monstres: Array = []
var ombres: Array = []
var hud: Hud
var _lacet := 1.45
var _tangage := -0.42
var _dist := 8.5
var _cam_pos := Vector3.ZERO
var _soleil: DirectionalLight3D
var _sphere_cam := SphereShape3D.new()
var _env: Environment
var pnjs: Array = []
var portail: Node3D
var donjon: Donjon = null
var arene: Arene = null
var chasseurs: Array = []
var _adversaire := {}
var _musique_p: AudioStreamPlayer

var boss_evt: Monstre = null
var _colonne: Node3D
var evt_fin := 0.0
var prochain_evt := 0.0

func _ready() -> void:
	add_to_group("ville")
	Ui.preparer()
	Fx.preparer(self)
	_environnement()
	_ville()
	joueur = Joueur.new()
	joueur.name = "Joueur"
	joueur.add_to_group("joueur")
	add_child(joueur)
	joueur.global_position = DEPART
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 420
	add_child(camera)
	_sphere_cam.radius = 0.35
	_cam_pos = DEPART
	for p in postes():
		var m := Monstre.new()
		m.configurer(p[0], Vector3(p[1], _sol(p[1], p[2]), p[2]), deg_to_rad(p[3]))
		m.elite = not Partie.ESPECES[p[0]].get("boss", false) and randf() < Partie.CHANCE_ELITE
		add_child(m)
		monstres.append(m)
		m.regenere.connect(func (x): if joueur.cible == x: joueur.viser(null))
	_pole()
	for k in Partie.chasseurs.size():
		var c := Chasseur.new()
		c.d = Partie.chasseurs[k]
		c.ville = self
		add_child(c)
		var p: Array = POSTES[(k * 3) % POSTES.size()]
		c.placer(Vector3(p[1] + 2.0, _sol(p[1], p[2]) + 0.3, p[2] + 2.0))
		chasseurs.append(c)
	prochain_evt = _quart_suivant()
	hud = Hud.new()
	hud.ville = self
	add_child(hud)
	Partie.change.connect(_maj_ombres)
	_maj_ombres()
	_musique()
	hud.dire("Zones rouges au sol : sors-en vite !  Bouclier bleu = PARADE : arrête de frapper.", Color(0.85, 0.75, 1.0))
	if OS.get_cmdline_user_args().size() > 0:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pilote="):
				var p := Pilote.new()
				p.scenario = a.substr(9)
				p.ville = self
				add_child(p)

func postes() -> Array:
	return [] if OS.get_cmdline_user_args().has("--pilote=tailles") else POSTES

func _environnement() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	_env = e
	var ciel := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.16, 0.26, 0.52)
	mat.sky_horizon_color = Color(0.62, 0.6, 0.78)
	mat.ground_horizon_color = Color(0.55, 0.48, 0.55)
	mat.sun_angle_max = 12.0
	ciel.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.9
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.fog_enabled = true
	e.fog_light_color = Color(0.55, 0.6, 0.75)
	e.fog_density = 0.0022
	e.glow_enabled = true
	e.glow_intensity = 0.5
	we.environment = e
	add_child(we)
	_soleil = DirectionalLight3D.new()
	_soleil.rotation_degrees = Vector3(-42, 35, 0)
	_soleil.light_color = Color(1.0, 0.9, 0.8)
	_soleil.light_energy = 1.25
	_soleil.shadow_enabled = true
	_soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_soleil.directional_shadow_max_distance = 40.0
	add_child(_soleil)

func _ville() -> void:
	var v: Node3D = load("res://assets/city.glb").instantiate()
	v.scale = Vector3.ONE * ECHELLE_VILLE
	add_child(v)

	for m in v.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.create_trimesh_collision()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON

	var sol := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(800, 1, 400)
	cs.shape = bs
	sol.add_child(cs)
	sol.position = Vector3(-107, -0.52, -107)
	add_child(sol)

func _sol(x: float, z: float) -> float:
	var q := PhysicsRayQueryParameters3D.create(Vector3(x, 40, z), Vector3(x, -5, z))
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	return r["position"].y if not r.is_empty() else 0.0

func _musique(nom := "city") -> void:
	if _musique_p == null:
		_musique_p = AudioStreamPlayer.new()
		_musique_p.volume_db = -14.0
		add_child(_musique_p)
	var s: AudioStream = load("res://assets/music/%s.ogg" % nom)
	if s is AudioStreamOggVorbis:
		(s as AudioStreamOggVorbis).loop = true
	_musique_p.stream = s
	_musique_p.play()


func _pole() -> void:
	for a in AUTELS:
		var p := Pnj.new()
		p.autel = a[0]
		p.position = Vector3(a[1], _sol(a[1], a[2]), a[2])
		p.rotation.y = PI
		add_child(p)
		pnjs.append(p)
	portail = Node3D.new()
	add_child(portail)
	portail.position = PORTAIL + Vector3(0, _sol(PORTAIL.x, PORTAIL.z), 0)
	portail.rotation.y = PI / 2.0
	portail.add_child(Portail.creer(Color(0.15, 0.45, 1.0), Color(0.6, 0.25, 1.0), 2.0))
	var l := Label3D.new()
	l.text = "PORTAIL DES DONJONS\nRangs E · D · C · B"
	l.font = Ui.police
	l.font_size = 34
	l.outline_size = 10
	l.pixel_size = 0.0018
	l.fixed_size = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.6, 0.8, 1.0)
	l.position.y = 6.4
	l.visibility_range_end = 60.0
	portail.add_child(l)


func action_proche() -> Dictionary:
	var p := joueur.global_position
	if donjon:
		if donjon.sortie and p.distance_to(donjon.sortie.global_position) < 4.0:
			return {"type": "sortir"}
		return {}
	for n: Pnj in pnjs:
		if p.distance_to(n.global_position) < 3.6:
			return {"type": "autel", "autel": n.autel}
	if p.distance_to(portail.global_position) < 4.5:
		return {"type": "donjon"}
	return {}


func entrer_test() -> void:
	if donjon or arene:
		return
	await hud.fondu(true)
	donjon = Donjon.new()
	donjon.test_rang = Partie.rang_chasseur
	donjon.ville = self
	add_child(donjon)
	donjon.termine.connect(_fin_donjon)
	for m in donjon.monstres:
		monstres.append(m)
	joueur.viser(null)
	_teleporter(donjon.point_depart(), PI)
	_ambiance(true)
	donjon.appliquer_ambiance(_env)
	donjon.demarrer()
	_musique("dungeon")
	await hud.fondu(false)
	hud.annonce("TEST DE RANG %s" % Partie.RANGS[donjon.test_rang], "10 salles · %d minutes · ne flanche pas" % (int(Partie.DUREE_TEST) / 60), Color(1.0, 0.75, 0.3))

func entrer_donjon(n := 0, groupe := false) -> void:
	if donjon or arene:
		return
	var equipe := []
	if groupe:
		hud.annonce("RECHERCHE DE GROUPE", "Matchmaking en cours…", Color(0.5, 0.85, 1.0))
		await get_tree().create_timer(2.5).timeout
		var dispo := chasseurs.filter(func (c): return c.mode == "ville")
		dispo.sort_custom(func (a, b): return absi(int(a.d["niveau"]) - Partie.niveau) < absi(int(b.d["niveau"]) - Partie.niveau))
		equipe = dispo.slice(0, 3)
		hud.dire("Groupe trouvé : " + ", ".join(equipe.map(func (c): return "%s (niv %d)" % [c.d["nom"], int(c.d["niveau"])])), Color(0.5, 1.0, 0.7))
	await hud.fondu(true)
	donjon = Donjon.new()
	donjon.niv = n
	donjon.groupe = not equipe.is_empty()
	donjon.ville = self
	add_child(donjon)
	donjon.termine.connect(_fin_donjon)
	for m in donjon.monstres:
		monstres.append(m)
	joueur.viser(null)
	_teleporter(donjon.point_depart(), PI)
	for k in equipe.size():
		var c: Chasseur = equipe[k]
		c.mode = "donjon"
		c.donjon = donjon
		c.placer(donjon.point_depart() + Vector3((k - 1) * 1.6, 0, -1.0))
	donjon.allies = equipe
	_ambiance(true)
	donjon.appliquer_ambiance(_env)
	donjon.demarrer()
	_musique("dungeon")
	await hud.fondu(false)
	hud.annonce("DONJON DE RANG %s" % Partie.RANGS[n], "%s  ·  Salle 1 / 6 : %s" % [donjon.cfg["nom"], donjon.NOMS_SALLES[0]], Color(0.7, 0.5, 1.0))

func _fin_donjon(victoire: bool) -> void:
	if donjon.test_rang >= 0:
		if victoire:
			_musique("boss")
			hud.annonce("RANG %s OBTENU !" % Partie.RANGS[Partie.rang_chasseur], "Multiplicateur ×%.1f : dégâts, PV, mana, or et expérience" % Partie.mult_rang(), Color(1.0, 0.8, 0.3))
		else:
			hud.annonce("TEST ÉCHOUÉ", "Temps écoulé. Renforce-toi et retente.", Color(1.0, 0.35, 0.35))
		await get_tree().create_timer(3.5).timeout
		quitter_donjon()
		return
	if victoire:
		_musique("boss")
		hud.recompenses_donjon(donjon.gains)
	else:
		hud.annonce("TEMPS ÉCOULÉ", "Le donjon se referme…", Color(1.0, 0.35, 0.35))
		await get_tree().create_timer(2.5).timeout
		quitter_donjon()

func quitter_donjon() -> void:
	if donjon == null:
		return
	await hud.fondu(true)
	for m in donjon.monstres:
		monstres.erase(m)
	_liberer_allies()
	joueur.viser(null)
	donjon.queue_free()
	donjon = null
	_ambiance(false)
	_teleporter(PORTAIL + Vector3(4.0, 0.3, 0.0), -PI / 2.0)
	_musique("city")
	await hud.fondu(false)

func _teleporter(p: Vector3, lacet: float) -> void:
	joueur.global_position = p
	joueur.velocity = Vector3.ZERO
	_lacet = lacet
	_cam_pos = p + Vector3(0, 1.6, 0)
	for o in ombres:
		o.global_position = p + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-2.5, -1.0))


func _ambiance(donj: bool) -> void:
	_soleil.visible = not donj
	_env.background_mode = Environment.BG_COLOR if donj else Environment.BG_SKY
	_env.background_color = Color(0.01, 0.0, 0.02)
	_env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR if donj else Environment.AMBIENT_SOURCE_SKY
	_env.ambient_light_color = Color(0.22, 0.18, 0.32)
	_env.ambient_light_energy = 1.1 if donj else 0.9
	_env.fog_light_color = Color(0.1, 0.05, 0.16) if donj else Color(0.55, 0.6, 0.75)
	_env.fog_density = 0.012 if donj else 0.0022

	var lan: OmniLight3D = joueur.get_node_or_null("Lanterne")
	if lan == null:
		lan = OmniLight3D.new()
		lan.name = "Lanterne"
		lan.light_color = Color(0.75, 0.7, 1.0)
		lan.light_energy = 1.6
		lan.omni_range = 9.0
		lan.position = Vector3(0, 2.6, 0)
		joueur.add_child(lan)
	lan.visible = donj
	_env.glow_intensity = 0.9 if donj else 0.5


func _quart_suivant() -> float:
	var t := Time.get_unix_time_from_system()
	return (floor(t / PERIODE_EVENEMENT) + 1.0) * PERIODE_EVENEMENT

func temps_avant_evt() -> float:
	return prochain_evt - Time.get_unix_time_from_system()

func evt_restant() -> float:
	return evt_fin - Time.get_unix_time_from_system()

func lancer_evenement() -> void:
	if boss_evt:
		return
	var p := LIEU_EVENEMENT + Vector3(0, _sol(LIEU_EVENEMENT.x, LIEU_EVENEMENT.z), 0)
	boss_evt = Monstre.new()
	boss_evt.configurer("baran", p, deg_to_rad(-30))
	boss_evt.reapparait_auto = false
	add_child(boss_evt)
	monstres.append(boss_evt)
	boss_evt.vaincu.connect(_evt_vaincu)
	boss_evt.regenere.connect(func (x): if joueur.cible == x: joueur.viser(null))
	evt_fin = Time.get_unix_time_from_system() + DUREE_EVENEMENT
	_colonne = MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 2.2
	cy.bottom_radius = 2.2
	cy.height = 90.0
	cy.cap_top = false
	cy.cap_bottom = false
	(_colonne as MeshInstance3D).mesh = cy
	(_colonne as MeshInstance3D).material_override = Shaders.colonne(Color(0.85, 0.12, 0.35))
	(_colonne as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(_colonne)
	_colonne.global_position = p + Vector3(0, 52.0, 0)
	Fx.anneau(p, Color(0.9, 0.15, 0.3), 9.0)
	Fx.son("portal", 2.0)
	hud.annonce("ÉVÉNEMENT", "Baran, roi des démons est apparu sur l'esplanade !", Color(1.0, 0.3, 0.4))

func _evt_vaincu(m: Monstre) -> void:
	var arme := Partie.butin_unique("faux_neant")
	hud.annonce("BARAN EST TOMBÉ", "Lame du Néant obtenue !" if arme else "Tente de lever son ombre !", Color(0.9, 0.5, 1.0))
	if _colonne:
		_colonne.queue_free()
		_colonne = null
	get_tree().create_timer(Monstre.FENETRE_EVEIL + 1.0).timeout.connect(_fin_evenement)

func _fin_evenement() -> void:
	if boss_evt:
		monstres.erase(boss_evt)
		if joueur.cible == boss_evt:
			joueur.viser(null)
		boss_evt.queue_free()
		boss_evt = null
	if _colonne:
		_colonne.queue_free()
		_colonne = null
	prochain_evt = _quart_suivant()


func _maj_ombres() -> void:
	var eq := Partie.ombres_equipees()
	var cles := eq.map(func (o): return "%s|%d" % [o["espece"], o["etoiles"]])
	var actuelles := ombres.map(func (o): return "%s|%d" % [o.donnees["espece"], o.donnees["etoiles"]])
	if cles == actuelles:
		return
	for o in ombres:
		o.queue_free()
	ombres.clear()
	for k in eq.size():
		var o := Ombre.new()
		o.donnees = eq[k]
		o.joueur = joueur
		o.place = k
		add_child(o)
		o.global_position = joueur.global_position + Vector3(randf_range(-2, 2), 0, randf_range(1, 3))
		ombres.append(o)


func frapper() -> void:
	var c := joueur.cible
	if c == null or not is_instance_valid(c) or c.mort:
		c = joueur.cible_devant(monstres)
	if c == null:
		hud.dire("Aucun monstre à portée.", Color(1, 0.6, 0.5))
		Fx.son("error", -6.0)
		return
	joueur.viser(c)

func monstre_eveillable() -> Monstre:
	for m: Monstre in monstres:
		if is_instance_valid(m) and m.eveillable and m.global_position.distance_to(joueur.global_position) < 12.0:
			return m
	return null

func eveiller() -> void:
	var m := monstre_eveillable()
	if m == null:
		return
	m.eveillable = false
	Fx.son("arise", 0.0)
	Fx.anneau(m.global_position, Color(0.55, 0.2, 1.0), 3.0)
	Fx.texte(m.global_position + Vector3(0, 2.5, 0), "LÈVE-TOI", Color(0.8, 0.55, 1.0), 1.8, 1.4)
	await get_tree().create_timer(0.8).timeout
	var o := Partie.eveiller(m.espece)
	if o.is_empty():
		m.eveil_rate()
		if m.e.get("lieu", "") == "evenement":
			hud.dire("L'ombre du roi des démons refuse de se lever… (%.2f %% de chance)" % (Partie.chance_eveil(m.espece) * 100.0), Color(0.85, 0.6, 0.7))
		else:
			hud.dire("L'éveil a échoué… (%d/%d avant réussite garantie)" % [Partie.echecs_eveil, Partie.PITIE + 1], Color(0.75, 0.7, 0.85))
		Fx.son("error", -4.0)
	else:
		m.eveil_reussi()
		Fx.son("shadow", 0.0)
		Fx.anneau(m.global_position, Color(0.75, 0.4, 1.0), 4.5)
		if m.e.get("lieu", "") == "evenement":
			Fx.anneau(m.global_position, Color(1.0, 0.15, 0.25), 9.0)
			hud.annonce("OMBRE LÉGENDAIRE", "Baran se relève à tes côtés — carte rouge de rang A !", Color(1.0, 0.25, 0.3))
		else:
			hud.dire("Nouvelle ombre : %s [%s]" % [m.e["nom"], Partie.RANGS[m.e["rang"]]], Color(0.8, 0.6, 1.0))

var _mort_en_cours := false

func _liberer_allies() -> void:
	if donjon == null:
		return
	for c: Chasseur in donjon.allies:
		if is_instance_valid(c):
			c.mode = "ville"
			c.donjon = null
			c.placer(PORTAIL + Vector3(randf_range(3, 6), 0.3, randf_range(-3, 3)))
			if donjon.sortie:
				for k in 6:
					Partie.bot_gagner(c.d, Partie.SALLES_BOSS[donjon.niv])
			c._maj_plaque()

func lancer_arene() -> void:
	if donjon or arene:
		return
	_adversaire = Partie.adversaire_arene()
	hud.annonce("ARÈNE", "Adversaire : %s  ·  niveau %d  ·  ÉLO %d" % [_adversaire["nom"], int(_adversaire["niveau"]), int(_adversaire["elo"])], Color(1.0, 0.7, 0.3))
	await get_tree().create_timer(1.8).timeout
	await hud.fondu(true)
	arene = Arene.new()
	arene.adversaire = _adversaire
	add_child(arene)
	monstres.append(arene.rival)
	arene.termine.connect(_fin_arene)
	joueur.viser(arene.rival)
	_teleporter(arene.point_depart(), 0.0)
	Partie.pv = Partie.pv_max()
	arene.demarrer()
	await hud.fondu(false)
	hud.annonce("COMBAT !", "90 secondes pour vaincre %s" % _adversaire["nom"], Color(1.0, 0.55, 0.25))

func _fin_arene(victoire: bool) -> void:
	if arene == null:
		return
	var a := arene
	arene = null
	a.actif = false
	var r := Partie.fin_arene(_adversaire, victoire)
	monstres.erase(a.rival)
	joueur.viser(null)
	await hud.fondu(true)
	a.queue_free()
	_teleporter(PORTAIL + Vector3(4.0, 0.3, 0.0), -PI / 2.0)
	await hud.fondu(false)
	hud.annonce("VICTOIRE !" if victoire else "DÉFAITE", "ÉLO %+d  ·  +%d jeton%s d'arène" % [r["elo"], r["jetons"], "s" if r["jetons"] > 1 else ""], Color(0.5, 1.0, 0.5) if victoire else Color(1.0, 0.4, 0.4))
var _cercle_portee: MeshInstance3D
var _portee_vue := 0.0

func _maj_portee(dt: float) -> void:
	if _cercle_portee == null:
		_cercle_portee = MeshInstance3D.new()
		var t := TorusMesh.new()
		t.inner_radius = 0.97
		t.outer_radius = 1.0
		t.rings = 64
		t.ring_segments = 4
		_cercle_portee.mesh = t
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.7, 0.4, 1.0, 0.7)
		_cercle_portee.material_override = m
		_cercle_portee.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(_cercle_portee)
	var c := joueur.cible
	if c and is_instance_valid(c) and not c.mort and not ombres.is_empty():
		var v := c.global_position - joueur.global_position
		v.y = 0
		if v.length() > Partie.portee_ombres() + c.haut() * 0.3:
			if _portee_vue <= 0.0:
				hud.dire("Cible hors de portée de tes ombres : rapproche-toi.", Color(0.8, 0.6, 1.0))
			_portee_vue = 2.5
	_portee_vue -= dt
	_cercle_portee.visible = _portee_vue > 0.0
	if _cercle_portee.visible:
		var r := Partie.portee_ombres()
		_cercle_portee.global_position = joueur.global_position + Vector3(0, 0.12, 0)
		_cercle_portee.scale = Vector3(r, 0.05, r)
		(_cercle_portee.material_override as StandardMaterial3D).albedo_color.a = clampf(_portee_vue, 0.0, 0.7)

func mort_joueur() -> void:
	if _mort_en_cours:
		return
	_mort_en_cours = true
	joueur.viser(null)
	Fx.son("error", 0.0)
	if arene:
		_fin_arene(false)
		Partie.pv = Partie.pv_max()
		_mort_en_cours = false
		return
	var r := Partie.mourir()
	await hud.fondu(true)
	if donjon:
		for m in donjon.monstres:
			monstres.erase(m)
		_liberer_allies()
		donjon.queue_free()
		donjon = null
		_ambiance(false)
		_musique("city")
	_teleporter(DEPART, 1.45)
	await hud.fondu(false)
	hud.ecran_mort(r)
	_mort_en_cours = false

func tourner_camera(rel: Vector2) -> void:
	_lacet -= rel.x * 0.006
	_tangage = clampf(_tangage - rel.y * 0.004, -1.1, -0.12)

func toucher_monde(p: Vector2) -> void:
	var o := camera.project_ray_origin(p)
	var q := PhysicsRayQueryParameters3D.create(o, o + camera.project_ray_normal(p) * 80.0)
	q.collide_with_areas = true
	q.collision_mask = 4
	var r := get_world_3d().direct_space_state.intersect_ray(q)
	if not r.is_empty() and r["collider"].has_meta("monstre"):
		var m: Monstre = r["collider"].get_meta("monstre")
		if not m.mort:
			joueur.viser(m)

func _process(dt: float) -> void:
	if boss_evt == null and donjon == null and arene == null and temps_avant_evt() <= 0.0:
		lancer_evenement()
	elif boss_evt and not boss_evt.mort and evt_restant() <= 0.0:
		hud.dire("Baran est reparti dans les ténèbres…", Color(1.0, 0.45, 0.5))
		_fin_evenement()
	joueur.camera_lacet = _lacet
	_maj_portee(dt)
	_cam_pos = _cam_pos.lerp(joueur.global_position + Vector3(0, 1.6, 0), minf(1.0, dt * 9.0))
	var dir := Vector3(sin(_lacet) * cos(_tangage), -sin(_tangage), cos(_lacet) * cos(_tangage))
	var voulu := _cam_pos + dir * _dist


	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = _sphere_cam
	q.transform = Transform3D(Basis.IDENTITY, _cam_pos)
	q.motion = voulu - _cam_pos
	q.exclude = [joueur.get_rid()]
	var f := get_world_3d().direct_space_state.cast_motion(q)
	if f[0] < 1.0:
		voulu = _cam_pos + (voulu - _cam_pos) * maxf(f[0] - 0.02, 0.0)
	camera.global_position = voulu
	camera.look_at(_cam_pos, Vector3.UP)
