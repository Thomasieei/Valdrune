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
	["gobelin", -181.0, -66.0, 80.0], ["gobelin", -167.0, -76.0, 95.0], ["gobelin", -195.0, -76.0, 90.0],
	["puglin", -132.0, -70.0, -90.0], ["puglin", -108.0, -70.0, -90.0],
	["gobelin_chef", -153.0, -104.0, 90.0], ["gobelin_chef", -183.0, -106.0, 85.0],
	["puglin_brute", -92.0, -120.0, 180.0], ["puglin_brute", -86.0, -85.0, 170.0],
	["orc", -145.0, -112.0, 180.0], ["orc", -137.0, -101.0, 175.0],
	["diablotin", -111.0, -111.0, 180.0], ["diablotin", -104.0, -101.0, 180.0],
	["orc_guerrier", -111.0, -53.0, 0.0], ["orc_guerrier", -131.0, -43.0, 10.0],
	["demon", -84.0, -36.0, -30.0], ["demon", -103.0, -52.0, 0.0],
]
const PORTAIL_ROUGE := Vector3(-127.0, 0.0, -30.0)

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
var _tangage := -0.3
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
var POSTES_V: Array = POSTES
var _arise_t := 0.0
var chateau: Chateau = null
var abime: Abime = null
var portail_abime: Node3D
const PORTAIL_ABIME := Vector3(-199.0, 0.0, -84.0)

func entrer_abime() -> void:
	if donjon or arene or chateau or abime:
		return
	await hud.fondu(true)
	abime = Abime.new()
	abime.ville = self
	add_child(abime)
	abime.demarrer()
	joueur.viser(null)
	_teleporter(abime.point_depart(), PI)
	_ambiance(true)
	_env.fog_light_color = Color(0.1, 0.3, 0.25)
	_env.ambient_light_color = Color(0.3, 0.45, 0.45)
	_musique("dungeon")
	await hud.fondu(false)
	hud.annonce("L'ABÎME", "1000 étages aux dimensions étranges · record : étage %d" % Partie.abime_max, Color(0.4, 1.0, 0.75))

func quitter_abime() -> void:
	if abime == null:
		return
	await hud.fondu(true)
	for m in abime.monstres:
		monstres.erase(m)
	abime.queue_free()
	abime = null
	_ambiance(false)
	_teleporter(PORTAIL_ABIME + Vector3(4.0, 0.3, 0.0), -PI / 2.0)
	_musique("city")
	await hud.fondu(false)

var gates: Array = []
var _gate_t := 240.0
var _break_boss: Monstre = null
var raid_boss: Monstre = null
var _raid_fin := 0.0
var _raid_fait := -1
var _nettoyage_t := 30.0
var _lod_t := 1.0
var _secousse := 0.0

var _zoom := 1.0

func zoom_impact() -> void:
	_zoom = 0.9
	if camera:
		camera.fov = 67.0

func secouer(f: float) -> void:
	_secousse = maxf(_secousse, f)

func ralenti(duree: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.3
	await get_tree().create_timer(duree, true, false, true).timeout
	Engine.time_scale = 1.0

func hitstop(duree: float) -> void:
	if Engine.time_scale < 1.0:
		return
	Engine.time_scale = 0.06
	await get_tree().create_timer(duree, true, false, true).timeout
	Engine.time_scale = 1.0
var _ciel_t := 0.0
var _etait_nuit := false
var _pluie: GPUParticles3D
var _pluie_t := 900.0
var _rival_t := 120.0
var familier: Node3D = null
var _fam_t := 30.0

func creer_familier() -> void:
	if familier:
		return
	familier = Node3D.new()
	add_child(familier)
	var corps := Modele.creer("imp", 0.7)
	for mi in corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_override = Shaders.ombre(Color(0.6, 0.3, 1.0))
		(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.55, 0.3, 1.0), 2.0)
	familier.add_child(corps)
	var ap := Modele.lecteur(corps)
	Modele.jouer(ap, "Idle")
	familier.set_meta("ap", ap)
	familier.global_position = joueur.global_position + Vector3(1.5, 0, 1.5)

func _maj_familier(dt: float) -> void:
	if familier == null:
		if Partie.achats_boutique.has("familier"):
			creer_familier()
		return
	var but := joueur.global_position + joueur.basis.x * 1.4 + Vector3(0, 0.6 + sin(Time.get_ticks_msec() / 300.0) * 0.15, 0)
	familier.global_position = familier.global_position.lerp(but, minf(1.0, dt * 4.0))
	var v := joueur.global_position - familier.global_position
	familier.rotation.y = atan2(v.x, v.z)
	_fam_t -= dt
	if _fam_t <= 0.0:
		_fam_t = 30.0
		if randf() < 0.25:
			var k: String = ["pv", "mana"].pick_random()
			Partie.potions[k] = int(Partie.potions[k]) + 1
			hud.dire("Ton familier a trouvé une potion de %s !" % ("soin" if k == "pv" else "mana"), Color(0.75, 0.6, 1.0))
const PIQUES := ["Tu traînes, chasseur. Je suis déjà loin devant.", "Encore à farmer des gobelins ?", "Le classement ne ment pas.", "Rattrape-moi si tu peux."]

func _maj_ciel(dt: float) -> void:
	_ciel_t -= dt
	if _ciel_t > 0.0:
		return
	_ciel_t = 1.0
	var n := Partie.nuit()
	if n != _etait_nuit:
		_etait_nuit = n
		hud.annonce("LA NUIT TOMBE" if n else "LE JOUR SE LÈVE", "Monstres +30 % PV · éveil ×1,5" if n else "Retour à la normale", Color(0.55, 0.6, 1.0) if n else Color(1.0, 0.85, 0.5))
	if donjon == null and chateau == null and abime == null and arene == null:
		var cible_e := 0.6 if n else 1.0
		_soleil.light_energy = lerpf(_soleil.light_energy, cible_e, 0.15)
		_soleil.light_color = Color(0.62, 0.72, 1.0) if n else Color(1.0, 0.9, 0.8)
		_env.ambient_light_color = _env.ambient_light_color.lerp(Color(0.45, 0.55, 0.85) if n else Color(0.3, 0.45, 0.45), 0.15)
		_env.ambient_light_energy = lerpf(_env.ambient_light_energy, 1.1 if n else 0.6, 0.15)
		if _lampe == null:
			_lampe = OmniLight3D.new()
			_lampe.omni_range = 16.0
			_lampe.light_color = Color(0.8, 0.88, 1.0)
			_lampe.shadow_enabled = false
			_lampe.position = Vector3(0, 3.0, 0)
			joueur.add_child(_lampe)
		_lampe.light_energy = lerpf(_lampe.light_energy, 1.3 if n else 0.0, 0.2)
		var sm := _env.sky.sky_material as ProceduralSkyMaterial
		sm.sky_top_color = sm.sky_top_color.lerp(Color(0.05, 0.08, 0.2) if n else Color(0.3, 0.44, 0.72), 0.15)
		sm.sky_horizon_color = sm.sky_horizon_color.lerp((Color(0.5, 0.08, 0.1) if Partie.pluie_sang() else Color(0.1, 0.1, 0.22)) if n else (Color(0.7, 0.3, 0.3) if Partie.pluie_sang() else Color(0.85, 0.7, 0.62)), 0.15)
	_pluie_t -= 1.0
	if _pluie_t <= 0.0 and not Partie.pluie_sang():
		_pluie_t = randf_range(1200.0, 1800.0)
		Partie.pluie_fin = Time.get_unix_time_from_system() + 180.0
		hud.annonce("PLUIE DE SANG", "3 min : pièces ×1,5 · monstres déchaînés", Color(1.0, 0.25, 0.25))
	if _pluie == null:
		_pluie = GPUParticles3D.new()
		_pluie.amount = 500
		_pluie.lifetime = 1.2
		_pluie.visibility_aabb = AABB(Vector3(-20, -20, -20), Vector3(40, 40, 40))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(16, 0.5, 16)
		pm.direction = Vector3(0, -1, 0)
		pm.initial_velocity_min = 16.0
		pm.initial_velocity_max = 20.0
		pm.color = Color(0.8, 0.05, 0.08, 0.8)
		_pluie.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.03, 0.5)
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
		m.vertex_color_use_as_albedo = true
		q.material = m
		_pluie.draw_pass_1 = q
		add_child(_pluie)
	_pluie.emitting = Partie.pluie_sang() and donjon == null and chateau == null and abime == null
	_pluie.global_position = joueur.global_position + Vector3(0, 14, 0)
	_rival_t -= 1.0
	if _rival_t <= 0.0:
		_rival_t = randf_range(240.0, 420.0)
		Partie.verifier_rival()
		if Partie.rival != "" and not Partie.rival_battu:
			hud.dire("[Rival] %s : « %s »" % [Partie.rival, PIQUES.pick_random()], Color(1.0, 0.55, 0.45))

func _maj_raid() -> void:
	var t := Time.get_datetime_dict_from_system()
	var h: int = t["hour"]
	if raid_boss == null and t["minute"] >= 7 and t["minute"] < 12 and _raid_fait != h and donjon == null and chateau == null and arene == null and boss_evt == null:
		_raid_fait = h
		_lancer_raid()
	elif raid_boss and is_instance_valid(raid_boss) and not raid_boss.mort and Time.get_unix_time_from_system() > _raid_fin:
		_fin_raid(false)

func _lancer_raid() -> void:
	var total := Partie.dps_total()
	for c in Partie.chasseurs:
		total += Partie.bot_dps(c)
	Partie.raid_degats = {}
	var p := LIEU_EVENEMENT + Vector3(0, _sol(LIEU_EVENEMENT.x, LIEU_EVENEMENT.z), 0)
	raid_boss = Monstre.new()
	raid_boss.configurer("titan", p, deg_to_rad(-30))
	raid_boss.reapparait_auto = false
	raid_boss.sans_chrono = true
	raid_boss.pv_perso = total * 240.0
	raid_boss.atk_perso = Partie.ATK_RANG[mini(Partie.rang_chasseur + 1, 4)]
	add_child(raid_boss)
	raid_boss.chrono = 0.0
	monstres.append(raid_boss)
	raid_boss.vaincu.connect(func (_m): _fin_raid(true))
	_raid_fin = Time.get_unix_time_from_system() + 480.0
	Fx.son("portal", 2.0, 0.5)
	hud.annonce("RAID MONDIAL", "Gorrath, titan des failles, frappe l'esplanade ! Tous les chasseurs y vont.", Color(1.0, 0.55, 0.2))

func _fin_raid(victoire: bool) -> void:
	if raid_boss == null:
		return
	var b := raid_boss
	raid_boss = null
	var l := []
	for k in Partie.raid_degats:
		l.append([k, float(Partie.raid_degats[k])])
	l.sort_custom(func (a, c): return a[1] > c[1])
	var lignes := []
	var ma_place := -1
	for k in l.size():
		if l[k][0] == "Toi":
			ma_place = k
		if k < 5:
			lignes.append("#%d  %s  —  %s dégâts" % [k + 1, l[k][0], Fx.court(l[k][1])])
	if victoire and ma_place >= 0:
		var gain := int(5000.0 * pow(4.0, Partie.rang_chasseur) / (ma_place + 1))
		Partie.pieces += gain
		Partie.or_total += gain
		Partie.donner_cle(3 if ma_place == 0 else 1)
		if ma_place == 0:
			Partie.ajouter_objet(Partie.BUTIN_DONJON.pick_random(), 4)
			lignes.append("1re place : objet de rang A + 3 clés !")
		lignes.append("Ta place : #%d  ·  +%s pièces" % [ma_place + 1, Fx.court(gain)])
	elif not victoire:
		lignes.append("Le titan s'est retiré dans la faille…")
		monstres.erase(b)
		b.queue_free()
	hud.systeme("RAID MONDIAL — %s" % ("VICTOIRE" if victoire else "ÉCHEC"), lignes)

var _break_fin := 0.0
const COULEURS_GATE := [Color(0.6, 0.65, 0.75), Color(0.3, 0.9, 0.4), Color(0.3, 0.6, 1.0), Color(0.75, 0.35, 1.0), Color(1.0, 0.6, 0.15)]

func _ouvrir_gate() -> void:
	var r := clampi(Partie.rang_chasseur + (1 if randf() < 0.3 else 0) - (1 if randf() < 0.3 else 0), 0, 3)
	var p: Array = POSTES.pick_random()
	var pos := Vector3(p[1], _sol(p[1], p[2]), p[2]) + Vector3(randf_range(-3, 3), 0, randf_range(-3, 3))
	var n := Node3D.new()
	add_child(n)
	n.position = pos
	n.add_child(Portail.creer(COULEURS_GATE[r], COULEURS_GATE[r].darkened(0.5), 1.6))
	var l := Label3D.new()
	l.font = Ui.police
	l.font_size = 30
	l.outline_size = 9
	l.pixel_size = 0.0018
	l.fixed_size = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = COULEURS_GATE[r].lightened(0.3)
	l.position.y = 5.0
	n.add_child(l)
	var gardes := []
	var l_esp: Array = Partie.ESPECES_RANG[r]
	for k in 3 + r:
		var m := Monstre.new()
		var a := TAU * k / (3 + r)
		m.configurer(l_esp[k % 2], pos + Vector3(cos(a), 0, sin(a)) * 4.0, a)
		m.reapparait_auto = false
		m.elite_fixe = k == 0
		add_child(m)
		monstres.append(m)
		gardes.append(m)
	gates.append({"noeud": n, "label": l, "rang": r, "fin": Time.get_unix_time_from_system() + 600.0, "gardes": gardes})
	hud.annonce("PORTAIL DE RANG %s OUVERT !" % Partie.RANGS[r], "Ferme-le en 10 min ou ses monstres envahiront la ville", COULEURS_GATE[r])

func _maj_gates(dt: float) -> void:
	_gate_t -= dt
	if _gate_t <= 0.0 and gates.size() < 2 and donjon == null and chateau == null:
		_gate_t = randf_range(360.0, 600.0)
		_ouvrir_gate()
	var now := Time.get_unix_time_from_system()
	for g in gates.duplicate():
		var vivants: Array = g["gardes"].filter(func (m): return is_instance_valid(m) and not m.mort)
		var reste: float = g["fin"] - now
		g["label"].text = "PORTAIL RANG %s\n%d:%02d  ·  %d gardien%s" % [Partie.RANGS[g["rang"]], int(reste) / 60, int(reste) % 60, vivants.size(), "s" if vivants.size() > 1 else ""]
		if vivants.is_empty():
			var gain := int(800.0 * pow(5.0, g["rang"]) * Partie.mult_rang())
			Partie.pieces += gain
			Partie.or_total += gain
			Partie.donner_monnaie(Partie.MONNAIES.keys().pick_random(), 2 + g["rang"] * 2)
			if randf() < 0.35:
				Partie.donner_cle()
			Partie.charger_domaine(15.0)
			hud.annonce("PORTAIL FERMÉ", "+%s pièces" % Fx.court(gain), Color(0.5, 1.0, 0.6))
			Partie.contrat("portail")
			_retirer_gate(g)
		elif reste <= 0.0:
			_debordement(g, vivants)

func _retirer_gate(g: Dictionary) -> void:
	for m in g["gardes"]:
		if is_instance_valid(m) and m.mort:
			monstres.erase(m)
			m.queue_free()
	g["noeud"].queue_free()
	gates.erase(g)

func _debordement(g: Dictionary, vivants: Array) -> void:
	var pos: Vector3 = g["noeud"].position
	var l_esp: Array = Partie.ESPECES_RANG[mini(g["rang"] + 1, 3)]
	for k in 5:
		var m := Monstre.new()
		m.configurer(l_esp[k % 2], pos + Vector3(randf_range(-6, 6), 0, randf_range(-6, 6)), randf() * TAU)
		m.reapparait_auto = false
		m.elite_fixe = randf() < 0.4
		add_child(m)
		monstres.append(m)
	hud.annonce("DÉBORDEMENT !", "Le portail de rang %s a cédé : ses monstres envahissent la ville" % Partie.RANGS[g["rang"]], Color(1.0, 0.3, 0.3))
	Fx.son("portal", 2.0, 0.6)
	g["gardes"] = []
	g["noeud"].queue_free()
	gates.erase(g)

func _break_donjon(niv: int) -> void:
	var esp: String = Donjon.SALLES_PAR_NIV[niv][5][0][0]
	_break_boss = Monstre.new()
	_break_boss.configurer(esp, PORTAIL + Vector3(7.0, _sol(PORTAIL.x + 7.0, PORTAIL.z), 0), -PI / 2.0)
	_break_boss.reapparait_auto = false
	_break_boss.mult = 1.5
	_break_boss.elite_fixe = true
	add_child(_break_boss)
	_break_boss.chrono = 0.0
	monstres.append(_break_boss)
	_break_fin = Time.get_unix_time_from_system() + 600.0
	_break_boss.vaincu.connect(func (_m):
		var gain := int(float(Donjon.DONJONS[niv]["or"]) * 2.0)
		Partie.pieces += gain
		Partie.or_total += gain
		Partie.butin_donjon(niv + 1)
		hud.annonce("BREAK MAÎTRISÉ", "Le boss échappé est tombé : +%s pièces" % Fx.court(gain), Color(0.5, 1.0, 0.6))
		_break_boss = null)
	hud.annonce("BREAK DE DONJON !", "%s s'est échappé en ville — 10 minutes pour l'abattre" % Partie.ESPECES[esp]["nom"], Color(1.0, 0.25, 0.25))

var portail_rouge: Node3D
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
	joueur.maj_aura_titre.call_deferred()
	add_child(joueur)
	joueur.global_position = DEPART
	camera = Camera3D.new()
	camera.fov = 62
	camera.far = 1500
	add_child(camera)
	_sphere_cam.radius = 0.35
	_cam_pos = DEPART
	_generer_zones()
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
	Partie.systeme.connect(func (t, l): hud.systeme(t, l))
	if Partie.penalite_due:
		get_tree().create_timer(3.0).timeout.connect(_penalite)
	else:
		get_tree().create_timer(3.0).timeout.connect(func (): hud.systeme("QUÊTE QUOTIDIENNE", ["Préparation pour devenir fort :", "• 100 monstres vaincus", "• 10 ombres levées", "• 1 donjon terminé", "Avant minuit. Sinon : zone de pénalité."]))
	hud.dire("Zones rouges au sol : sors-en vite !  Bouclier bleu = PARADE : arrête de frapper.", Color(0.85, 0.75, 1.0))
	if OS.get_cmdline_user_args().size() > 0:
		for a in OS.get_cmdline_user_args():
			if a.begins_with("--pilote="):
				var p := Pilote.new()
				p.scenario = a.substr(9)
				p.ville = self
				add_child(p)

var _postes_gen: Array = []
var pts_rue: Array = []
var missions: Missions
var skyline: Skyline
var appart: Appart
var carte: Carte
var chez_soi := false
var escorte: Escorte
var _lampe: OmniLight3D

func cibles_gps() -> Array:
	var l := []
	if missions:
		l.append_array(missions.cibles())
	if escorte and escorte.bureau != Vector3.INF:
		l.append({"nom": "Agence de protection", "pos": escorte.bureau, "col": Color(0.4, 0.7, 1.0)})
	if appart:
		l.append({"nom": "Ton appartement", "pos": appart.porte_pos, "col": Color(0.4, 1.0, 0.55)})
	l.append({"nom": "Portail des donjons", "pos": PORTAIL, "col": Color(0.4, 0.6, 1.0)})
	if skyline:
		l.append({"nom": "Tour des chasseurs", "pos": skyline.tour_pos, "col": Color(1.0, 0.85, 0.3)})
	l.append({"nom": "Château rouge", "pos": PORTAIL_ROUGE, "col": Color(1.0, 0.3, 0.3)})
	l.append({"nom": "Abîme", "pos": PORTAIL_ABIME, "col": Color(0.6, 0.4, 1.0)})
	return l

# Découpe la ville en zones de rang selon la distance au départ : E proche, puis D, C, B au loin.
func _generer_zones() -> void:
	var etat := get_world_3d().direct_space_state
	var sphere := SphereShape3D.new()
	sphere.radius = 1.6
	var pts := []
	seed(1234)
	for k in 900:
		var x := randf_range(-420.0, 160.0)
		var z := randf_range(-320.0, 90.0)
		var r := etat.intersect_ray(PhysicsRayQueryParameters3D.create(Vector3(x, 60, z), Vector3(x, -5, z)))
		if r.is_empty() or r["position"].y > 0.7 or r["position"].y < -0.4:
			continue
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sphere
		q.transform = Transform3D(Basis.IDENTITY, r["position"] + Vector3(0, 2.0, 0))
		if not etat.intersect_shape(q, 1).is_empty():
			continue
		var p: Vector3 = r["position"]
		if pts.any(func (o): return o.distance_to(p) < 14.0):
			continue
		pts.append(p)
	randomize()
	pts_rue = pts
	missions = Missions.new()
	add_child(missions)
	missions.installer(self, pts)
	appart = Appart.new()
	add_child(appart)
	appart.installer(self, pts)
	skyline = Skyline.new()
	add_child(skyline)
	skyline.installer(self, pts)
	var bea := Beaute.new()
	add_child(bea)
	bea.installer(self)
	escorte = Escorte.new()
	add_child(escorte)
	escorte.installer(self, pts)
	var qua := Quartiers.new()
	add_child(qua)
	qua.installer(self, pts)
	carte = Carte.new()
	carte.construire(self)
	var foule := Foule.new()
	add_child(foule)
	foule.installer(self, pts, carte)
	if pts.size() < 24:
		_postes_gen = POSTES
		return
	var par_rang := [0, 0, 0, 0]
	for p in pts:
		var d: float = Vector2(p.x - DEPART.x, p.z - DEPART.z).length()
		var rg := mini(int(d / 75.0), 3)
		if par_rang[rg] >= 10:
			continue
		par_rang[rg] += 1
		var l: Array = Partie.ESPECES_RANG[rg]
		for j in 2:
			_postes_gen.append([l[(j + par_rang[rg]) % 2], p.x + j * 6.0, p.z + randf_range(-2, 2), randf() * 360.0])
	for b in POSTES:
		if Partie.ESPECES[b[0]].get("boss", false):
			_postes_gen.append(b)
	POSTES_V = _postes_gen
	print("[ZONES] points=", pts.size(), " par rang=", par_rang)
	_lampadaires(pts)

# Lampadaires néon le long des rues : têtes émissives (le glow les fait briller), sans lumière dynamique
# Retouches de matériaux (gratuites en performance) : fenêtres et enseignes qui brillent, routes mouillées
func _embellir_ville(v: Node3D) -> void:
	var vus := {}
	for m in v.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		if mi.mesh == null:
			continue
		for s in mi.mesh.get_surface_count():
			var mat := mi.mesh.surface_get_material(s) as StandardMaterial3D
			if mat == null or vus.has(mat):
				continue
			vus[mat] = true
			var n := mat.resource_name.to_lower()
			if n.contains("glow"):
				mat.emission_enabled = true
				if mat.emission_texture == null and mat.emission.get_luminance() < 0.05:
					mat.emission = Color(1.0, 0.85, 0.55)
				mat.emission_energy_multiplier = 2.2
			elif n.contains("road") or n.contains("ground"):
				mat.roughness = 0.55
				mat.albedo_color = mat.albedo_color * Color(1.0, 0.86, 0.74)
				mat.metallic_specular = 0.5
			elif n.contains("filler") or n.contains("paramount") or n.contains("clinic") or n.contains("laundry") or n.contains("pawn") or n.contains("fish"):
				mat.roughness = minf(mat.roughness, 0.8)

func _lampadaires(pts: Array) -> void:
	var pied := StandardMaterial3D.new()
	pied.albedo_color = Color(0.15, 0.16, 0.2)
	pied.metallic = 0.7
	pied.roughness = 0.35
	var couleurs := [Color(0.4, 0.85, 1.0), Color(1.0, 0.45, 0.85), Color(1.0, 0.8, 0.45), Color(0.6, 0.5, 1.0)]
	var tetes := []
	for c in couleurs:
		var t := StandardMaterial3D.new()
		t.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		t.albedo_color = c
		t.emission_enabled = true
		t.emission = c
		t.emission_energy_multiplier = 3.0
		tetes.append(t)
	var cy := CylinderMesh.new()
	cy.top_radius = 0.07
	cy.bottom_radius = 0.11
	cy.height = 4.2
	cy.radial_segments = 6
	var sp := SphereMesh.new()
	sp.radius = 0.28
	sp.height = 0.56
	sp.radial_segments = 8
	sp.rings = 4
	var halo := QuadMesh.new()
	halo.size = Vector2(1.8, 1.8)
	var k := 0
	for p in pts:
		k += 1
		if k % 3 != 0:
			continue
		var base: Vector3 = p + Vector3(4.5, 0, 0)
		var mi := MeshInstance3D.new()
		mi.mesh = cy
		mi.material_override = pied
		mi.position = base + Vector3(0, 2.1, 0)
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visibility_range_end = 90.0
		add_child(mi)
		var t := MeshInstance3D.new()
		t.mesh = sp
		t.material_override = tetes[k % tetes.size()]
		t.position = base + Vector3(0, 4.3, 0)
		t.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		t.visibility_range_end = 120.0
		add_child(t)
		var h := MeshInstance3D.new()
		h.mesh = halo
		var hm := StandardMaterial3D.new()
		hm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		hm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		hm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
		hm.albedo_texture = load("res://assets/fx/circle_05.png")
		hm.albedo_color = Color(couleurs[k % couleurs.size()], 0.35)
		h.material_override = hm
		h.position = t.position
		h.visibility_range_end = 120.0
		add_child(h)

# Cherche un mur de bâtiment existant près d'un point de rue (pour poser enseignes et portes dessus)
func mur_proche(p: Vector3, portee := 30.0) -> Dictionary:
	var etat := get_world_3d().direct_space_state
	var mieux := {}
	var dm := INF
	var o := p + Vector3(0, 1.4, 0)
	for k in 16:
		var a := TAU * k / 16.0
		var d := Vector3(cos(a), 0, sin(a))
		var r := etat.intersect_ray(PhysicsRayQueryParameters3D.create(o, o + d * portee))
		if r.is_empty():
			continue
		var nm: Vector3 = r["normal"]
		if absf(nm.y) > 0.3:
			continue
		var dist := o.distance_to(r["position"])
		if dist < 2.4 or dist >= dm:
			continue
		if nm.dot(-d) < 0.85:
			continue
		var o2 := o + Vector3(0, 5, 0)
		var r2 := etat.intersect_ray(PhysicsRayQueryParameters3D.create(o2, o2 + d * (dist + 0.6)))
		if r2.is_empty():
			continue
		var lat := d.cross(Vector3.UP) * 2.2
		var large := true
		for sgn in [-1.0, 1.0]:
			var oo: Vector3 = o + lat * sgn
			var r3 := etat.intersect_ray(PhysicsRayQueryParameters3D.create(oo, oo + d * (dist + 1.0)))
			if r3.is_empty() or absf(oo.distance_to(r3["position"]) - dist) > 0.8:
				large = false
		if not large:
			continue
		dm = dist
		mieux = {"pos": r["position"], "normal": Vector3(nm.x, 0, nm.z).normalized()}
	return mieux

func rang_zone(p: Vector3) -> int:
	return mini(int(Vector2(p.x - DEPART.x, p.z - DEPART.z).length() / 75.0), 3)

func postes() -> Array:
	return [] if OS.get_cmdline_user_args().has("--pilote=tailles") else (_postes_gen if not _postes_gen.is_empty() else POSTES)

func _environnement() -> void:
	var we := WorldEnvironment.new()
	var e := Environment.new()
	_env = e
	var ciel := Sky.new()
	var mat := ProceduralSkyMaterial.new()
	mat.sky_top_color = Color(0.3, 0.44, 0.72)
	mat.sky_horizon_color = Color(0.85, 0.7, 0.62)
	mat.sky_curve = 0.12
	mat.sun_angle_max = 25.0
	mat.ground_horizon_color = Color(0.55, 0.48, 0.55)
	mat.sun_angle_max = 12.0
	ciel.sky_material = mat
	e.background_mode = Environment.BG_SKY
	e.sky = ciel
	e.ambient_light_source = Environment.AMBIENT_SOURCE_SKY
	e.ambient_light_energy = 0.6
	e.ambient_light_sky_contribution = 0.65
	e.tonemap_mode = Environment.TONE_MAPPER_ACES
	e.tonemap_exposure = 0.88
	e.adjustment_enabled = true
	e.adjustment_saturation = 1.0
	e.adjustment_contrast = 1.1
	e.glow_bloom = 0.02
	e.glow_hdr_threshold = 1.5
	e.fog_enabled = true
	e.fog_light_color = Color(0.75, 0.7, 0.78)
	e.fog_density = 0.0035
	e.fog_aerial_perspective = 0.4
	e.fog_sky_affect = 0.3
	e.glow_enabled = true
	e.glow_intensity = 0.65
	we.environment = e
	add_child(we)
	_soleil = DirectionalLight3D.new()
	_soleil.rotation_degrees = Vector3(-42, 35, 0)
	_soleil.light_color = Color(1.0, 0.86, 0.7)
	_soleil.light_energy = 1.0
	_soleil.shadow_enabled = true
	_soleil.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	_soleil.directional_shadow_max_distance = 42.0
	_soleil.shadow_blur = 1.5
	add_child(_soleil)

func _ville() -> void:
	var v: Node3D = load("res://assets/city.glb").instantiate()
	v.scale = Vector3.ONE * ECHELLE_VILLE
	add_child(v)

	for m in v.find_children("*", "MeshInstance3D", true, false):
		var mi := m as MeshInstance3D
		mi.create_trimesh_collision()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		var taille := mi.get_aabb().size.length() * ECHELLE_VILLE
		mi.visibility_range_end = 70.0 if taille < 4.0 else (140.0 if taille < 25.0 else 0.0)
		mi.visibility_range_end_margin = 10.0
		mi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_DISABLED

	_embellir_ville(v)

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
	portail_rouge = Node3D.new()
	add_child(portail_rouge)
	portail_rouge.position = PORTAIL_ROUGE + Vector3(0, _sol(PORTAIL_ROUGE.x, PORTAIL_ROUGE.z), 0)
	portail_rouge.add_child(Portail.creer(Color(1.0, 0.1, 0.1), Color(0.5, 0.0, 0.05), 2.6))
	var lr := Label3D.new()
	lr.text = "CHÂTEAU ROUGE\n250 étages · clé requise"
	lr.font = Ui.police
	lr.font_size = 34
	lr.outline_size = 10
	lr.pixel_size = 0.0018
	lr.fixed_size = true
	lr.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lr.modulate = Color(1.0, 0.4, 0.4)
	lr.position.y = 7.6
	lr.visibility_range_end = 32.0
	portail_rouge.add_child(lr)
	portail_abime = Node3D.new()
	add_child(portail_abime)
	portail_abime.position = PORTAIL_ABIME + Vector3(0, _sol(PORTAIL_ABIME.x, PORTAIL_ABIME.z), 0)
	portail_abime.add_child(Portail.creer(Color(0.3, 1.0, 0.7), Color(0.4, 0.1, 0.8), 2.2))
	var la := Label3D.new()
	la.text = "L'ABÎME\n1000 étages"
	la.font = Ui.police
	la.font_size = 32
	la.outline_size = 10
	la.pixel_size = 0.0018
	la.fixed_size = true
	la.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	la.modulate = Color(0.45, 1.0, 0.75)
	la.position.y = 6.4
	la.visibility_range_end = 32.0
	portail_abime.add_child(la)
	l.font = Ui.police
	l.font_size = 34
	l.outline_size = 10
	l.pixel_size = 0.0018
	l.fixed_size = true
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.modulate = Color(0.6, 0.8, 1.0)
	l.position.y = 6.4
	l.visibility_range_end = 32.0
	portail.add_child(l)


func action_proche() -> Dictionary:
	var p := joueur.global_position
	if chez_soi:
		return appart.action(p)
	if abime:
		return {"type": "quitter_abime"} if p.distance_to(abime.point_depart()) < 4.0 else {}
	if chateau:
		return {}
	if donjon and donjon.secret and not donjon.secret_ouvert and is_instance_valid(donjon.secret) and p.distance_to(donjon.secret.global_position) < 3.5:
		return {"type": "secret"}
	if donjon:
		if donjon.sortie and p.distance_to(donjon.sortie.global_position) < 4.0:
			return {"type": "sortir"}
		return {}
	for n: Pnj in pnjs:
		if p.distance_to(n.global_position) < 3.6:
			return {"type": "autel", "autel": n.autel}
	if missions:
		var am := missions.action(p)
		if not am.is_empty():
			return am
	if escorte:
		var ae := escorte.action(p)
		if not ae.is_empty():
			return ae
	if appart:
		var aa := appart.action(p)
		if not aa.is_empty():
			return aa
	if p.distance_to(portail.global_position) < 4.5:
		return {"type": "donjon"}
	if p.distance_to(portail_rouge.global_position) < 5.0:
		return {"type": "chateau"}
	if p.distance_to(portail_abime.global_position) < 5.0:
		return {"type": "abime"}
	return {}


func _penalite() -> void:
	Partie.penalite_due = false
	hud.systeme("[ PÉNALITÉ ]", ["Quête quotidienne non accomplie.", "Zone de pénalité : survis aux monstres", "qui t'encerclent. Tue-les tous."])
	var l_esp: Array = Partie.ESPECES_RANG[mini(Partie.rang_chasseur, 3)]
	for k in 6:
		var m := Monstre.new()
		var a := TAU * k / 6.0
		m.configurer(l_esp[k % 2], joueur.global_position + Vector3(cos(a), 0, sin(a)) * 7.0, a + PI)
		m.reapparait_auto = false
		m.elite_fixe = true
		add_child(m)
		m.chrono = 0.0
		monstres.append(m)

const GRIMOIRE := [
	["flammes", "Flammes noires de destruction", "Réduit en cendres tout monstre à 25 m."],
	["gravite", "Gravité du Roi démon", "Écrase et paralyse tout à 35 m pendant 8 s."],
	["lance", "Lance de l'abîme", "Anéantit ta cible, quelles que soient ses protections."],
	["legion", "Légion des morts", "Lève en ombres tous les monstres tombés autour de toi."],
	["resurrection", "Résurrection", "Ramène toutes tes ombres, PV et mana au maximum."],
	["temps", "Inversion du temps", "Les monstres morts de la zone reviennent à la vie."],
	["domaine", "Domaine du Roi démon", "Domaine du Monarque instantané (ombres ×3)."],
	["fortune", "Trésor du château démoniaque", "+1 M pièces, 50 clés, 100 de chaque monnaie."],
	["ascension", "Ascension", "+10 niveaux et un rang de chasseur."],
	["saut", "Saut dimensionnel", "Téléportation devant le château rouge."],
	["etages", "Effondrement du château", "Au château : saute 10 étages d'un coup."],
]

func grimoire() -> Array:
	return GRIMOIRE

func basculer_createur() -> void:
	Partie.createur = not Partie.createur
	joueur.aura_anos(Partie.createur)
	if Partie.createur:
		Fx.anneau(joueur.global_position, Color(0.9, 0.05, 0.12), 10.0)
		Fx.son("portal", 0.0, 0.5)
		hud.annonce("ANOS", "Le Roi démon s'éveille — mode créateur activé", Color(1.0, 0.15, 0.2))
	else:
		hud.annonce("MODE CRÉATEUR DÉSACTIVÉ", "Retour au chasseur normal", Color(0.7, 0.75, 0.9))
	Partie.change.emit()

func _abattre(m: Monstre) -> void:
	if m.mort:
		return
	m._dernier = "joueur"
	m.pv = 0.0
	m._mourir()

func sort_anos(id: String) -> void:
	var p := joueur.global_position
	Fx.son("slam", 0.0, 0.6)
	match id:
		"flammes":
			Fx.anneau(p, Color(0.08, 0.0, 0.1), 25.0)
			Fx.anneau(p, Color(0.6, 0.0, 0.1), 18.0)
			for m in monstres.duplicate():
				if is_instance_valid(m) and m.global_position.distance_to(p) < 25.0:
					Fx.anneau(m.global_position, Color(0.1, 0.0, 0.1), 2.5)
					_abattre(m)
		"gravite":
			Fx.anneau(p, Color(0.3, 0.1, 0.6), 35.0)
			for m in monstres:
				if is_instance_valid(m) and not m.mort and m.global_position.distance_to(p) < 35.0:
					m._etourdi = 8.0
					m._parade = 0.0
					m.frapper(m.pv_max * 0.3, true, "evenement")
		"lance":
			var c := joueur.cible if joueur.cible and is_instance_valid(joueur.cible) else joueur.cible_devant(monstres, 40.0)
			if c:
				Fx.anneau(c.global_position, Color(0.05, 0.0, 0.08), 5.0)
				_abattre(c)
		"legion":
			var n := 0
			for m in monstres:
				if is_instance_valid(m) and m.eveillable and m.global_position.distance_to(p) < 35.0:
					Partie.force_eveil = true
					Partie.eveiller(m.espece)
					Partie.force_eveil = false
					m.eveil_reussi()
					n += 1
			hud.dire("%d ombre%s levée%s" % [n, "s" if n > 1 else "", "s" if n > 1 else ""], Color(0.8, 0.6, 1.0))
		"resurrection":
			for o in ombres:
				if o.mort:
					o._revenir()
			Partie.pv = Partie.pv_max()
			Partie.mana = Partie.mana_max()
		"temps":
			Fx.anneau(p, Color(0.4, 0.8, 1.0), 30.0)
			for m in monstres:
				if is_instance_valid(m) and m.mort and m.reapparait_auto and m.global_position.distance_to(p) < 40.0:
					m._renaitre()
		"domaine":
			Partie.charge = 100.0
			joueur.competence("domaine")
		"fortune":
			Partie.pieces += 1000000
			Partie.or_total += 1000000
			Partie.cles += 50
			for k in Partie.monnaies:
				Partie.monnaies[k] = int(Partie.monnaies[k]) + 100
		"ascension":
			for k in 10:
				Partie.xp += Partie.xp_requise()
				Partie.niveau += 1
				Partie.xp -= Partie.xp_requise()
			Partie.rang_chasseur = mini(Partie.rang_chasseur + 1, 4)
		"saut":
			if donjon == null and chateau == null and arene == null:
				_teleporter(PORTAIL_ROUGE + Vector3(5.0, 0.3, 0.0), -PI / 2.0)
		"etages":
			if chateau:
				chateau.etage += 9
				for m in chateau._vague:
					if is_instance_valid(m):
						_abattre(m)
	Partie.sauver()
	Partie.change.emit()

func entrer_chateau() -> void:
	if donjon or arene or chateau or Partie.cles <= 0:
		return
	Partie.cles -= 1
	await hud.fondu(true)
	chateau = Chateau.new()
	chateau.ville = self
	add_child(chateau)
	chateau.termine.connect(_fin_chateau)
	joueur.viser(null)
	_teleporter(chateau.point_depart(), PI)
	_ambiance(true)
	_env.fog_light_color = Color(0.3, 0.02, 0.02)
	_env.ambient_light_color = Color(0.45, 0.15, 0.15)
	_musique("boss")
	await hud.fondu(false)
	hud.annonce("CHÂTEAU ROUGE", "Monte le plus haut possible avant la fin du temps", Color(1.0, 0.3, 0.3))
	chateau.demarrer()

func _fin_chateau(etage: int) -> void:
	if chateau == null:
		return
	var c := chateau
	chateau = null
	for m in c.monstres:
		monstres.erase(m)
	joueur.viser(null)
	await hud.fondu(true)
	c.queue_free()
	_ambiance(false)
	_teleporter(PORTAIL_ROUGE + Vector3(5.0, 0.3, 0.0), -PI / 2.0)
	_musique("city")
	await hud.fondu(false)
	hud.annonce("CHÂTEAU : ÉTAGE %d" % etage, "Record : étage %d / 250" % Partie.etage_max, Color(1.0, 0.45, 0.4))

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
	if donjon == null:
		return
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
	var aide := 0.0
	for c in equipe:
		aide += Partie.bot_dps(c.d)
	donjon.mult_groupe = 1.0 + 0.75 * equipe.size()
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
	if donjon == null:
		return
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
		var nv := donjon.niv
		hud.annonce("TEMPS ÉCOULÉ", "Le donjon s'emballe…", Color(1.0, 0.35, 0.35))
		await get_tree().create_timer(2.5).timeout
		await quitter_donjon()
		if _break_boss == null:
			_break_donjon(nv)

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
	_env.ambient_light_energy = 2.2 if donj else 0.9
	_env.fog_light_color = Color(0.1, 0.05, 0.16) if donj else Color(0.55, 0.6, 0.75)
	_env.fog_density = 0.004 if donj else 0.0022

	var lan: OmniLight3D = joueur.get_node_or_null("Lanterne")
	if lan == null:
		lan = OmniLight3D.new()
		lan.name = "Lanterne"
		lan.light_color = Color(0.75, 0.7, 1.0)
		lan.light_energy = 2.4
		lan.omni_range = 14.0
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
	var cles := eq.map(func (o): return "%s|%d|%s|%s" % [o["espece"], o["etoiles"], o.get("evo", false), Partie.est_general(o)])
	var actuelles := ombres.map(func (o): return "%s|%d|%s|%s" % [o.donnees["espece"], o.donnees["etoiles"], o.donnees.get("evo", false), Partie.est_general(o.donnees)])
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
		if Partie.opts["rangees"]:
			o.ranger.call_deferred(true)


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
	joueur.animer_arise()
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
	if abime:
		var r1 := Partie.mourir()
		quitter_abime()
		hud.ecran_mort(r1)
		_mort_en_cours = false
		return
	if chateau:
		var r0 := Partie.mourir()
		chateau._fin()
		hud.ecran_mort(r0)
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
	_tangage = clampf(_tangage - rel.y * 0.004, -1.1, 0.5)

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
	var t0 := Time.get_ticks_usec()
	_process_reel(dt)
	Partie.prof["ville"] = int(Partie.prof.get("ville", 0)) + Time.get_ticks_usec() - t0

func _process_reel(dt: float) -> void:
	if boss_evt == null and donjon == null and arene == null and chateau == null and abime == null and temps_avant_evt() <= 0.0:
		lancer_evenement()
	elif boss_evt and not boss_evt.mort and evt_restant() <= 0.0:
		hud.dire("Baran est reparti dans les ténèbres…", Color(1.0, 0.45, 0.5))
		_fin_evenement()
	joueur.camera_lacet = _lacet
	_maj_gates(dt)
	_maj_raid()
	_maj_ciel(dt)
	if donjon:
		donjon._maj_pieges(dt)
	_maj_familier(dt)
	_lod_t -= dt
	if _lod_t <= 0.0:
		_lod_t = 1.0
		var pj := joueur.global_position
		for m in monstres:
			if is_instance_valid(m) and not m.allie:
				var loin: bool = m.global_position.distance_to(pj) > 50.0 and m != raid_boss and m != boss_evt
				if m.visible == loin:
					m.visible = not loin
					m.set_process(not loin)
					if m._ap:
						m._ap.active = not loin
				elif not loin and m._ap:
					var tres_proche: bool = m.global_position.distance_to(pj) < 35.0
					if m._ap.callback_mode_process != (AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if tres_proche else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS):
						m._ap.callback_mode_process = AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_IDLE if tres_proche else AnimationMixer.ANIMATION_CALLBACK_MODE_PROCESS_PHYSICS
		for c in chasseurs:
			if is_instance_valid(c) and c.mode == "ville":
				var proche: bool = c.global_position.distance_to(pj) < 60.0
				if c.visible != proche:
					c.visible = proche
					if c._ap:
						c._ap.active = proche
	_nettoyage_t -= dt
	if _nettoyage_t <= 0.0:
		_nettoyage_t = 30.0
		for m in monstres.duplicate():
			if is_instance_valid(m) and m.mort and not m.reapparait_auto and not m.eveillable and m.get_parent() == self and m != boss_evt:
				monstres.erase(m)
				m.queue_free()
	if _break_boss and is_instance_valid(_break_boss) and not _break_boss.mort and Time.get_unix_time_from_system() > _break_fin:
		var perte := int(Partie.pieces * 0.1)
		Partie.pieces -= perte
		hud.annonce("LA VILLE A SOUFFERT", "Le boss échappé a pillé la ville : -%s pièces" % Fx.court(perte), Color(1.0, 0.3, 0.3))
		monstres.erase(_break_boss)
		_break_boss.queue_free()
		_break_boss = null
	_arise_t -= dt
	if Partie.opts["arise"] and _arise_t <= 0.0 and monstre_eveillable():
		_arise_t = 1.2
		eveiller()
	_maj_portee(dt)
	_cam_pos = _cam_pos.lerp(joueur.global_position + Vector3(0, 1.6, 0), minf(1.0, dt * 9.0))
	var dir := Vector3(sin(_lacet) * cos(_tangage), -sin(_tangage), cos(_lacet) * cos(_tangage))
	var combat: bool = joueur.cible != null and is_instance_valid(joueur.cible) and not joueur.cible.mort
	_zoom = lerpf(_zoom, 0.82 if combat else 1.0, minf(1.0, dt * 2.5))
	camera.fov = lerpf(camera.fov, 62.0 + joueur.elan * 14.0, minf(1.0, dt * 6.0))
	var voulu := _cam_pos + dir * _dist * _zoom


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
	if _secousse > 0.01:
		camera.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), randf_range(-1, 1)) * _secousse * 0.35
		_secousse *= exp(-dt * 9.0)
