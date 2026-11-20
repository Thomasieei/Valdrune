class_name Pilote
extends Node


var scenario := ""
var ville: Node
var _n := 0

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("/tmp/caps_arise")
	# Le banc d'essai visuel ne doit pas être interrompu par une mort.
	# Actif uniquement avec --pilote=animation --sans-sauvegarde.
	if scenario in ["animation", "animation2", "legion"]:
		ville.joueur.invulnerable = 600.0
		Partie.opts["arise"] = false
	await get_tree().create_timer(1.5).timeout
	match scenario:
		"scan":
			_scan()
		"plan":
			await _plan()
		"vues":
			await _vues()
		"combat":
			await _combat()
		"arme":
			await _arme()
		"menus":
			await _menus()
		"icones":
			await _icones()
		"nouveautes":
			await _nouveautes()
		"tour":
			await _tour()
		"animation":
			await _demo_animation()
		"animation2":
			await _atelier_animation()
		"legion":
			await _atelier_animation(true)
		"marche":
			var j: Joueur = ville.joueur
			j.global_position = Vector3(-165.0, 0.3, -72.0)
			ville._lacet = 0.0
			ville._cam_pos = j.global_position + Vector3(0, 1.6, 0)
			await attendre(1.0)
			print("[MARCHE] depart y=", j.global_position.y)
			j.entree = Vector2(0, 1)
			ville.hud.set_process(false)
			await attendre(0.5)
			await capture("dos_en_marchant")
			for k in 8:
				await attendre(0.4)
				print("[MARCHE] t=", k * 0.4, " z=", snappedf(j.global_position.z, 0.01), " y=", snappedf(j.global_position.y, 0.01))
			j.entree = Vector2.ZERO
			ville._lacet = 1.57
			await attendre(1.0)
			await capture("sur_trottoir")

			j.entree = Vector2(-1, 0)
			await attendre(0.6)
			await capture("profil")
			j.entree = Vector2.ZERO
		"tailles":
			var x0 := -160.0
			var k := 0
			for esp in Partie.ESPECES:
				var m := Monstre.new()
				m.configurer(esp, Vector3(x0 + k * 4.5, 0, -68.0), 0.0)
				ville.add_child(m)
				k += 1
			ville.joueur.global_position = Vector3(x0 + 9.0, 0.3, -64.0)
			ville._lacet = 0.0
			ville._tangage = -0.12
			ville._dist = 13.0
			ville._cam_pos = Vector3(x0 + 9.0, 1.6, -61.0)
			await attendre(1.0)
			ville.joueur.global_position = Vector3(x0 + 9.0, 0.3, -64.0)
			await capture("tailles")
	print("[PILOTE] fini")
	get_tree().quit()

# Démonstration reproductible des vrais personnages et de leurs animations.
# Aucun ajout n'est sauvegardé : le pilote est exécuté avec --sans-sauvegarde.
func _demo_animation() -> void:
	var v = ville
	var j: Joueur = v.joueur
	v.hud.set_process(false)
	v.hud._racine.hide() # captures sans superposition du HUD
	Partie.auto_attaque = false
	Partie.auto_ombres = false
	Partie.opts["patrouille"] = false
	Partie.opts["diviser"] = false
	Partie.opts["rangees"] = false
	Partie.ombres = [
		{"uid": 9001, "espece": "gobelin", "etoiles": 1, "eq": true},
		{"uid": 9002, "espece": "puglin", "etoiles": 1, "eq": true},
		{"uid": 9003, "espece": "orc", "etoiles": 1, "eq": true},
		{"uid": 9004, "espece": "gobelin_chef", "etoiles": 1, "eq": true},
	]
	Partie.change.emit()
	# Inventaire reel des os et des animations importees par Godot.
	for spec in [["hero", j._corps], ["goblin", v.ombres[0]._corps], ["puglin", v.ombres[1]._corps], ["orc", v.ombres[2]._corps]]:
		var sk: Skeleton3D = spec[1].find_child("Skeleton3D", true, false)
		var ap: AnimationPlayer = Modele.lecteur(spec[1])
		var os := []
		if sk:
			for b in sk.get_bone_count():
				os.append(sk.get_bone_name(b))
		print("[RIG] ", spec[0], " bones=", os, " anims=", ap.get_animation_list() if ap else [])
	# Plan plus serre: le premier rendu etait illisible et finissait derriere un etal.
	j.global_position = v.DEPART + Vector3(0, 0.0, -9.0)
	v._lacet = 0.0
	v._tangage = -0.11
	v._dist = 5.8
	v._cam_pos = j.global_position + Vector3(0, 1.6, 0)
	j._corps.rotation.y = PI
	await attendre(0.8)
	await capture("repos")
	j.entree = Vector2(0, -0.38)
	for k in 12:
		await attendre(0.16)
		await capture("animation_%03d" % k)
	j.entree = Vector2.ZERO
	await attendre(0.45)
	await capture("arret")
	j.entree = Vector2(0, -1)
	for k in 12:
		await attendre(0.16)
		await capture("animation_%03d" % (k + 12))
	j.entree = Vector2.ZERO
	await attendre(0.55)
	await capture("fin")
	print("[ANIMATION] images=24, demonstration terminee")

# Plateau isole pour comparer les poses et les mouvements a l'echelle du personnage.
# L'atelier ne modifie ni le monde, ni les sauvegardes, ni les combats du jeu livre.
func _atelier_animation(legion := false) -> void:
	var v = ville
	var j: Joueur = v.joueur
	v.hud.set_process(false)
	v.hud._racine.hide()
	Partie.createur = false
	Partie.niveau = 49 # quatre ombres visibles sans toucher aux sauvegardes
	Partie.auto_attaque = false
	Partie.auto_ombres = false
	Partie.opts["patrouille"] = false
	Partie.opts["diviser"] = legion
	Partie.opts["rangees"] = false
	Partie.ombres = []
	var especes := ["gobelin", "puglin", "orc", "gobelin_chef"]
	for k in (16 if legion else 4):
		Partie.ombres.append({"uid": 99001 + k, "espece": especes[k % 4], "etoiles": 1, "eq": true})
	Partie.change.emit()
	var centre := Vector3(850.0, 0.0, 850.0)
	var plateau := StaticBody3D.new()
	var cube := BoxMesh.new()
	cube.size = Vector3(300.0, 0.35, 300.0)
	var sol := MeshInstance3D.new()
	sol.mesh = cube
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.25, 0.27, 0.33)
	mat.roughness = 0.85
	sol.material_override = mat
	plateau.add_child(sol)
	var forme := CollisionShape3D.new()
	var bo := BoxShape3D.new()
	bo.size = cube.size
	forme.shape = bo
	plateau.add_child(forme)
	# Local position avant l'ajout a l'arbre : evite l'erreur get_global_transform.
	plateau.position = centre + Vector3(0, -0.18, 0)
	v.add_child(plateau)
	# Eclairage de presentation: absent des scenes du jeu normal.
	var lumiere := OmniLight3D.new()
	lumiere.light_color = Color(0.65, 0.79, 1.0)
	lumiere.light_energy = 1.5
	lumiere.omni_range = 13.0
	lumiere.position = centre + Vector3(1.5, 6.0, 4.0)
	v.add_child(lumiere)
	j.global_position = centre + Vector3(0, 0.3, 0)
	j.velocity = Vector3.ZERO
	j._corps.rotation.y = 0.0
	for k in v.ombres.size():
		var o: Ombre = v.ombres[k]
		var ligne := int(k / 4)
		var col := k % 4
		o.global_position = centre + Vector3((float(col) - 1.5) * 1.6, 0.0, -2.2 - float(ligne) * 1.75)
		o._humeur_t = 0.7 + float(k) * 0.23
		if legion:
			for l in o.get_children():
				if l is Label3D:
					l.visible = false
	v._lacet = 0.0
	v._tangage = -0.32
	v._dist = 9.4 if legion else 4.6
	v.camera.fov = 62.0 if legion else 52.0
	v._cam_pos = j.global_position + Vector3(0, 1.2, 0)
	await attendre(0.6)
	for frame in 72:
		if frame == 10:
			j.entree = Vector2(0.0, -0.35)
		if frame == 24:
			j.entree = Vector2(0.0, -1.0)
		if frame == 40:
			j.entree = Vector2.ZERO
			j.global_position = centre + Vector3(0, 0.3, 0)
			j.velocity = Vector3.ZERO
			for k in v.ombres.size():
				var ligne := int(k / 4)
				var col := k % 4
				v.ombres[k].global_position = centre + Vector3((float(col) - 1.5) * 1.6, 0.0, -2.2 - float(ligne) * 1.75)
				v.ombres[k]._but_pret = false
		if frame == 44:
			var monstre := Monstre.new()
			monstre.configurer("gobelin", centre + Vector3(2.2, 0.0, 2.4), PI)
			monstre.pv_perso = 1.0e12
			monstre.reapparait_auto = false
			monstre.sans_chrono = true
			v.add_child(monstre)
			v.monstres.append(monstre)
			j.viser(monstre)
			if legion:
				var m2 := Monstre.new()
				m2.configurer("orc", centre + Vector3(-3.8, 0.0, 3.5), PI)
				m2.pv_perso = 1.0e12
				m2.reapparait_auto = false
				m2.sans_chrono = true
				v.add_child(m2)
				v.monstres.append(m2)
		if frame in [9, 23, 35, 49, 66]:
			print("[ATELIER][ETAT] phase=", frame, " joueur=", j._ap.current_animation if j._ap else "absent", " ombres=", v.ombres.map(func (o): return o._ap.current_animation if o._ap else "absent"))
			if legion:
				var dist_min := INF
				for a in v.ombres.size():
					for b in range(a + 1, v.ombres.size()):
						var delta: Vector3 = v.ombres[a].global_position - v.ombres[b].global_position
						delta.y = 0.0
						dist_min = minf(dist_min, delta.length())
				print("[LEGION] phase=", frame, " count=", v.ombres.size(), " min_spacing=", snappedf(dist_min, 0.01), "fps_ci=", Engine.get_frames_per_second())
		await attendre(0.125)
		await capture("animation_%03d" % frame)
	j.entree = Vector2.ZERO
	j.viser(null)
	await capture("fin")
	print("[ATELIER] 72 frames, repos/marche/sprint/combat, legion=", legion)

func _tour() -> void:
	var v = ville
	var j: Joueur = v.joueur
	Partie.niveau = 22
	Partie.rang_chasseur = 3
	Partie.cles = 3
	Partie.pieces = 50000
	for esp in ["gobelin", "gobelin", "puglin", "orc", "gobelin_chef"]:
		Partie.ombres.append({"uid": 9000 + Partie.ombres.size(), "espece": esp, "etoiles": 1, "eq": true})
	Partie.change.emit()
	await attendre(2.5)
	await capture("ville_depart")
	var m0: Monstre = j.cible_devant(v.monstres, 200.0)
	if m0:
		j.global_position = m0.global_position + Vector3(2.5, 0.3, 0)
		await attendre(0.5)
		j.viser(m0)
		await attendre(3.5)
		await capture("combat_ville")
	for t in ["inventaire", "ombres", "stats", "boutique", "classement", "journal", "donjon"]:
		v.hud.ouvrir(t)
		await attendre(0.6)
		await capture("menu_" + t)
		v.hud.fermer()
	for n in [0, 1, 2, 3]:
		v.entrer_donjon(n)
		await attendre(3.0)
		await capture("donjon_%d" % n)
		await v.quitter_donjon()
		await attendre(1.5)
	v.entrer_chateau()
	await attendre(4.0)
	await capture("chateau")
	if v.chateau:
		v.chateau._fin()
	await attendre(2.5)
	v.entrer_test()
	await attendre(3.0)
	await capture("test_rang")
	await v.quitter_donjon()
	await attendre(1.5)
	if m0:
		j.global_position = m0.global_position + Vector3(3.0, 0.3, 0)
	await attendre(1.0)
	Partie.speciale = "telekinesie"
	Partie.mana = Partie.mana_max()
	print("[TOUR] tk: ", j.competence("echange"))
	await attendre(1.0)
	await capture("telekinesie")
	v.hud._tk_fermer(false)
	v.hud._barre_basculer("rangees")
	await attendre(1.0)
	await capture("ombres_rangees")
	v.lancer_arene()
	await attendre(4.5)
	await capture("arene")

func capture(nom: String) -> void:
	await RenderingServer.frame_post_draw
	_n += 1
	get_viewport().get_texture().get_image().save_png("/tmp/caps_arise/%02d_%s.png" % [_n, nom])
	print("[CAPTURE] ", nom)

func attendre(s: float) -> void:
	await get_tree().create_timer(s).timeout


func _scan() -> void:
	var esp: PhysicsDirectSpaceState3D = ville.get_world_3d().direct_space_state
	var c: Vector3 = ville.DEPART
	var lignes := []
	for z in range(-60, 61, 4):
		var l := ""
		for x in range(-60, 61, 4):
			var p := Vector3(c.x + x, 40, c.z + z)
			var r := esp.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -50, 0)))
			l += "." if r.is_empty() or r["position"].y < 0.35 else "#"
		lignes.append("%4d %s" % [int(c.z + z), l])
	print("[SCAN] x de %d à %d par 4" % [int(c.x - 60), int(c.x + 60)])
	for l in lignes:
		print("[SCAN] ", l)

func _plan() -> void:
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = float(OS.get_environment("TAILLE")) if OS.get_environment("TAILLE") != "" else 120.0
	ville.add_child(cam)
	var c: Vector3 = ville.DEPART
	cam.global_position = Vector3(c.x + float(OS.get_environment("DX")), 120, c.z + float(OS.get_environment("DZ")))
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.make_current()
	ville.hud.visible = false
	for x in range(-60, 61, 10):
		for z in range(-60, 61, 10):
			var l := Label3D.new()
			l.text = "%d,%d" % [int(c.x + x), int(c.z + z)]
			l.font_size = 40
			l.pixel_size = 0.02
			l.modulate = Color(1, 1, 0)
			l.outline_size = 8
			l.no_depth_test = true
			l.rotation_degrees = Vector3(-90, 0, 0)
			ville.add_child(l)
			l.global_position = Vector3(c.x + x, 60, c.z + z)
	await attendre(1.0)
	await capture("plan")

func _vues() -> void:
	for v in OS.get_environment("VUES").split(";"):
		var a := v.split(",")
		ville.joueur.global_position = Vector3(float(a[0]), 0.3, float(a[1]))
		ville._lacet = deg_to_rad(float(a[2]))
		ville._tangage = float(a[3])
		ville._cam_pos = ville.joueur.global_position + Vector3(0, 1.6, 0)
		await attendre(1.2)
		await capture(a[4])

func _combat() -> void:
	var j: Joueur = ville.joueur
	var m: Monstre = ville.monstres[0]
	j.global_position = m.global_position + Vector3(0, 0.2, 6)
	ville._lacet = 0.0
	ville._cam_pos = j.global_position + Vector3(0, 1.6, 0)
	await attendre(0.8)
	await capture("avant")
	ville.frapper()
	await attendre(1.6)
	await capture("frappe")
	var t := 0.0
	while not m.mort and t < 30.0:
		await attendre(0.5)
		t += 0.5
	print("[COMBAT] gobelin mort=", m.mort, " en ", t, " s  pieces=", Partie.pieces)
	await attendre(0.4)
	await capture("victoire")
	Partie.echecs_eveil = Partie.PITIE
	ville.eveiller()
	await attendre(0.5)
	await capture("eveil")
	await attendre(1.5)
	print("[COMBAT] ombres=", Partie.ombres.size())
	await capture("ombre")

	var fort: Monstre = null
	for x in ville.monstres:
		if x.espece == "orc":
			fort = x
	if fort:
		j.global_position = fort.global_position + Vector3(0, 0.2, 5)
		ville._cam_pos = j.global_position + Vector3(0, 1.6, 0)
		await attendre(0.5)
		j.viser(fort)
		await attendre(3.0)
		await capture("orc_combat")
		var t2 := 0.0
		while fort.chrono >= 0.0 or t2 < 1.0:
			await attendre(0.5)
			t2 += 0.5
			if t2 > 40.0:
				break
		print("[COMBAT] orc regenere pv=", fort.pv, "/", fort.e["pv"], " mort=", fort.mort)
		await capture("orc_regen")
	Partie.pieces = 500
	Partie.change.emit()
	ville.hud.ouvrir("inventaire")
	await attendre(0.4)
	await capture("forge")
	ville.hud.ouvrir("ombres")
	await attendre(0.4)
	await capture("ombres")

func _arme() -> void:
	var j: Joueur = ville.joueur
	if OS.get_environment("ROT") != "":
		var r := OS.get_environment("ROT").split(",")
		Modele.reglage_main["rot"] = Vector3(float(r[0]), float(r[1]), float(r[2]))
	if OS.get_environment("POS") != "":
		var q := OS.get_environment("POS").split(",")
		Modele.reglage_main["pos"] = Vector3(float(q[0]), float(q[1]), float(q[2]))
	j.global_position = Vector3(-160, 0.3, -64)
	ville._dist = 2.6
	ville._tangage = -0.15
	for nom in OS.get_environment("ARMES").split(","):
		var o := Partie.ajouter_objet(nom, 2, false)
		Partie.equipe["arme"] = o["uid"]
		Partie.change.emit()
		j._corps.rotation.y = 0.0
		ville._lacet = deg_to_rad(float(OS.get_environment("LACET")) if OS.get_environment("LACET") != "" else 60.0)
		ville._cam_pos = j.global_position + Vector3(0, 1.3, 0)
		Modele.jouer(j._ap, "Idle")
		await attendre(0.8)
		var w: Node3D = j._main.get_child(0)
		var mn := Vector3.INF
		var mx := -Vector3.INF
		for m in w.find_children("*", "MeshInstance3D", true, false):
			var bb: AABB = (m as MeshInstance3D).global_transform * (m as MeshInstance3D).get_aabb()
			mn = mn.min(bb.position)
			mx = mx.max(bb.end)
		print("[ARME] ", nom, " taille monde=", (mx - mn), " main=", j._main.global_position, " os=", j._main.bone_name, " ech porte=", w.global_transform.basis.get_scale())
		await capture("%s_repos" % nom)
		j._anim_coup = 5.0
		Modele.jouer(j._ap, "Slash1", 1.0)
		await attendre(0.3)
		await capture("%s_coup" % nom)

func _clic(p: Vector2) -> void:
	for presse in [true, false]:
		var e := InputEventMouseButton.new()
		e.button_index = MOUSE_BUTTON_LEFT
		e.pressed = presse
		e.position = p
		e.global_position = p
		Input.parse_input_event(e)
		await get_tree().process_frame
	await get_tree().process_frame

func _menus() -> void:
	Partie.pieces = 25000
	Partie.niveau = 9
	for t in [["katana", 1], ["hache", 2], ["lame", 3], ["monarque", 4], ["dague", 0], ["katana", 0], ["capuche", 1],
			["cape_or", 3], ["plastron", 0], ["bottes_sang", 2], ["couronne", 4], ["masque", 1], ["bourse", 2], ["crane", 3],
			["oeuf_azur", 1], ["grimoire", 4], ["pepite", 0]]:
		Partie.ajouter_objet(t[0], t[1], false)
	for esp in ["gobelin", "gobelin", "gobelin", "orc", "gobelin_chef", "orc_guerrier", "chevalier"]:
		Partie.echecs_eveil = Partie.PITIE
		Partie.eveiller(esp)
	Partie.ajouter_objet("lame", 3)
	await attendre(0.6)
	await capture("hud_butin")
	ville.hud.ouvrir("inventaire")
	await attendre(0.5)
	await capture("inv_armes")

	var p: Control = ville.hud._panneau
	var cartes := p.get_children().filter(func (c): return c is Button and c.has_meta("carte"))
	print("[MENU] cartes=", cartes.size())
	await _clic(cartes[1].get_global_rect().get_center())
	await attendre(0.3)
	await capture("inv_detail")
	var d: Control = ville.hud._detail
	print("[MENU] detail=", d != null)
	if d:
		var b: Button = d.find_children("*", "Button", true, false)[0]
		print("[MENU] bouton=", b.text)
		await _clic(b.get_global_rect().get_center())
		await attendre(0.5)
		print("[MENU] arme equipee=", Partie.base(Partie.arme())["nom"], " rarete=", Partie.arme()["rarete"])
	await capture("inv_apres_equiper")
	ville.hud._onglet = "accessoire"
	Partie.equiper_le_meilleur(["tete", "cape", "armure", "bottes", "relique"])
	ville.hud._construire()
	await attendre(0.4)
	await capture("inv_accessoires")
	ville.hud._onglet = "relique"
	ville.hud._construire()
	await attendre(0.4)
	await capture("inv_reliques")
	ville.hud.ouvrir("ombres")
	await attendre(0.4)
	await capture("ombres")
	ville.hud._montrer_detail("ombre", Partie.ombres[0])
	await attendre(0.3)
	await capture("ombre_detail")
	ville.hud.ouvrir("stats")
	await attendre(0.4)
	await capture("stats")
	ville.hud.ouvrir("index")
	await attendre(0.4)
	await capture("index")
	ville.hud.fermer()
	var m: Monstre = ville.monstres[0]
	ville.joueur.global_position = m.global_position + Vector3(0, 0.2, 4)
	ville._cam_pos = ville.joueur.global_position + Vector3(0, 1.6, 0)
	ville._lacet = 0.0
	await attendre(0.5)
	var orc: Monstre = null
	for x in ville.monstres:
		if x.espece == "chevalier":
			orc = x
	ville.joueur.global_position = orc.global_position + Vector3(0, 0.2, 7)
	ville._cam_pos = ville.joueur.global_position + Vector3(0, 1.6, 0)
	await attendre(0.5)
	ville.joueur.viser(orc)
	await attendre(3.5)
	await capture("combat_hud")


func _icones() -> void:
	var liste := {"sh_goblin": ["goblin", "", Color(0.5, 0.25, 1.0)], "sh_puglin": ["puglin", "", Color(0.5, 0.25, 1.0)],
		"sh_orc": ["orc", "", Color(0.5, 0.25, 1.0)], "sh_orc_warrior": ["orc_warrior", "", Color(0.5, 0.25, 1.0)],
		"sh_imp": ["imp", "", Color(0.5, 0.25, 1.0)], "sh_igris": ["igris", "", Color(0.5, 0.25, 1.0)],
		"sh_baran": ["imp", "", Color(1.0, 0.15, 0.25)]}
	for nom in liste:
		var d: Array = liste[nom]
		var vp := SubViewport.new()
		vp.size = Vector2i(256, 256)
		vp.transparent_bg = true
		vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
		add_child(vp)
		var env := WorldEnvironment.new()
		var e := Environment.new()
		e.background_mode = Environment.BG_CLEAR_COLOR
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
		e.ambient_light_color = Color(0.4, 0.35, 0.6)
		e.glow_enabled = true
		e.glow_intensity = 0.8
		env.environment = e
		vp.add_child(env)
		var hh: float = {"puglin": 1.3, "orc_warrior": 1.55}.get(d[0], 2.0)
		var m := Modele.creer(d[0], hh)
		vp.add_child(m)
		m.rotation.y = deg_to_rad(28)
		var mat := Shaders.ombre(d[2]).duplicate() as ShaderMaterial
		mat.set_shader_parameter("force", 3.2)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = mat
		var ap := Modele.lecteur(m)
		Modele.jouer(ap, "Idle")
		var cam := Camera3D.new()
		cam.fov = 30
		vp.add_child(cam)
		cam.position = Vector3(0, hh * 0.58, 4.3)
		cam.look_at(Vector3(0, hh * 0.5, 0))
		await attendre(0.6)
		await RenderingServer.frame_post_draw
		var img := vp.get_texture().get_image()
		img.save_png("res://assets/ui/items/%s.png" % nom)
		img.save_png("/tmp/caps_arise/ic_%s.png" % nom)
		print("[ICONE] ", nom)
		vp.queue_free()

func _placer(p: Vector3, lacet: float, tangage := -0.42, dist := 8.5) -> void:
	ville.joueur.global_position = p
	ville._lacet = lacet
	ville._tangage = tangage
	ville._dist = dist
	ville._cam_pos = p + Vector3(0, 1.6, 0)

func _monstre(esp: String) -> Monstre:
	for x in ville.monstres:
		if is_instance_valid(x) and x.espece == esp and not x.mort:
			return x
	return null


func _nouveautes() -> void:
	var etape := OS.get_environment("ETAPE")
	Partie.pieces = 250000
	Partie.niveau = 14
	Partie.change.emit()
	if etape == "" or etape == "bestiaire":

		var x0 := -205.0
		var k := 0
		var esps := ["gobelin", "puglin", "gobelin_chef", "puglin_brute", "orc", "diablotin", "orc_guerrier", "demon", "seigneur_givre"]
		for esp in esps:
			var m := Monstre.new()
			m.configurer(esp, Vector3(x0 + k * 5.0, 0.0, -63.0), 0.0)
			m.elite = k == 1
			ville.add_child(m)
			k += 1
		_placer(Vector3(x0 + 20.0, 0.3, -52.0), 0.0, -0.18, 22.0)
		await attendre(1.5)
		await capture("bestiaire")
		_placer(Vector3(x0 + 5.0, 0.3, -56.0), 0.0, -0.2, 6.0)
		await attendre(1.0)
		await capture("elite_proche")
	if etape == "" or etape == "heros":

		for esp in ["gobelin", "puglin", "orc", "diablotin", "orc_guerrier", "baran"]:
			var o := {"uid": 900 + Partie.ombres.size(), "espece": esp, "etoiles": 1 if esp == "orc" else 0, "eq": true}
			Partie.ombres.append(o)
		Partie.points["legion"] = 10
		Partie.change.emit()
		_placer(Vector3(-160.0, 0.3, -66.0), PI, -0.25, 5.0)
		ville.joueur._corps.rotation.y = 0.0
		await attendre(2.0)
		await capture("heros_face")
		_placer(Vector3(-160.0, 0.3, -66.0), 0.0, -0.3, 7.5)
		ville.joueur._corps.rotation.y = 0.0
		await attendre(1.5)
		await capture("heros_dos_ombres")

		var orc := _monstre("orc")
		_placer(orc.global_position + Vector3(0, 0.3, 6.0), 0.0)
		await attendre(0.4)
		ville.joueur.viser(orc)
		await attendre(4.0)
		await capture("combat_direct")
	if etape == "" or etape == "pole":

		_placer(Vector3(-167.0, 0.3, -70.0), PI, -0.3, 12.0)
		await attendre(1.5)
		await capture("pole")
		_placer(Vector3(-188.0, 0.3, -62.0), PI * 0.75, -0.25, 9.0)
		await attendre(1.0)
		await capture("portail")

		Partie.monnaies["eclat"] = 14
		ville.joueur.visible = false
		for k in 3:
			_placer(Vector3(-177.0 + k * 10.0, 0.3, -60.0), PI, -0.12, 3.2)
			await attendre(0.8)
			await capture("pnj_%d" % k)
		ville.joueur.visible = true
		_placer(Vector3(-177.0, 0.3, -60.5), PI, -0.3, 6.0)
		await attendre(0.8)
		await capture("pres_pnj")
		print("[TEST] action=", ville.hud._action)
		ville.hud.agir()
		await attendre(0.5)
		await capture("autel")
		ville.hud._lancer_roll(1)
		await attendre(1.0)
		await capture("roll_milieu")
		await attendre(2.2)
		await capture("roll_fin")
		print("[TEST] rolls=", Partie.rolls, " eclats=", Partie.monnaies["eclat"])
		ville.hud._lancer_roll(10)
		await attendre(14.0)
		await capture("roll_x10")
		print("[TEST] rolls apres x10=", Partie.rolls, " tirages=", Partie.tirages)
		ville.hud.fermer()
		ville.hud.ouvrir("stats")
		await attendre(0.4)
		await capture("competences")
		Partie.ajouter_objet("croc_roi", Partie.UNIQUE, false)
		var fx := Partie.ajouter_objet("faux_neant", Partie.SHINY, false)
		Partie.rolls["arme"] = 3
		Partie.rolls["chance"] = 1
		ville.hud._onglet = "arme"
		ville.hud.ouvrir("inventaire")
		await attendre(0.6)
		await capture("inv_uniques")
		ville.hud._montrer_detail("objet", fx)
		await attendre(0.3)
		await capture("detail_shiny")
		Partie.equiper(fx)
		ville.hud._onglet = "sac"
		ville.hud._choix = []
		ville.hud._construire()
		await attendre(0.4)
		await capture("sac")
		ville.hud.fermer()
		_placer(Vector3(-160.0, 0.3, -66.0), PI * 0.8, -0.2, 3.6)
		ville.joueur._corps.rotation.y = 0.5
		await attendre(1.2)
		await capture("arme_shiny")
		ville.hud.ouvrir("ombres")
		await attendre(0.5)
		await capture("ombres_rouge")
		ville.hud.fermer()
	if etape == "" or etape == "donjon":

		_placer(Vector3(-187.5, 0.3, -56.0), PI / 2.0, -0.3, 7.0)
		await attendre(0.6)
		print("[TEST] action portail=", ville.hud._action)
		ville.hud.agir()
		await attendre(0.5)
		await capture("donjon_panneau")
		ville.hud.fermer()
		await ville.entrer_donjon()
		await attendre(1.5)
		await capture("donjon_salle1")
		var dj: Donjon = ville.donjon
		for s in 6:

			for m in dj._par_salle[s]:
				ville.joueur.viser(m)
				await attendre(1.6)
				if not m.mort:
					m.frapper(m.pv + 1.0, true)
				await attendre(0.4)
			await attendre(1.4)
			if s < 5:
				_placer(dj.centre(s + 1) + Vector3(0, 0.3, -8.0), PI if false else 0.0)
				ville._lacet = PI
				await attendre(1.2)
				await capture("donjon_salle%d" % (s + 2))
		await attendre(1.0)
		await capture("donjon_victoire")
		await attendre(3.0)
		await capture("donjon_recompenses")
		print("[TEST] gains=", dj.gains, " temps=", dj.duree())
		ville.hud.fermer()
		_placer(dj.sortie.global_position + Vector3(0, 0.3, 2.5), PI, -0.25, 7.0)
		await attendre(0.8)
		await capture("donjon_sortie")
		ville.hud._maj_action()
		print("[TEST] action sortie=", ville.hud._action)
		ville.hud.agir()
		await attendre(2.0)
		await capture("retour_ville")
	if etape == "" or etape == "evenement":

		if Partie.ombres.is_empty():
			for esp in ["orc", "diablotin", "orc_guerrier"]:
				Partie.ombres.append({"uid": 950 + Partie.ombres.size(), "espece": esp, "etoiles": 0, "eq": true})
			Partie.change.emit()
		ville.lancer_evenement()
		_placer(Vector3(-160.0, 0.3, -70.0), 0.0, -0.35, 8.5)
		await attendre(1.5)
		await capture("evt_annonce")
		_placer(Vector3(-150.0, 0.3, -66.0), -2.3, -0.2, 8.5)
		await attendre(1.0)
		await capture("evt_colonne")
		var b: Monstre = ville.boss_evt
		_placer(b.global_position + Vector3(4.0, 0.3, 10.0), 0.3, -0.3, 10.0)
		await attendre(0.5)
		ville.joueur.viser(b)
		await attendre(9.0)
		for o in ville.ombres:
			print("[OMBRE] ", o.donnees["espece"], " pos=", o.global_position, " d=", o.global_position.distance_to(b.global_position), " chrono=", b.chrono, " cible=", ville.joueur.cible)
		await capture("evt_combat")
		b.frapper(b.pv + 1.0, true)
		await attendre(1.5)
		await capture("evt_vaincu")
		Partie.force_eveil = true
		ville.eveiller()
		await attendre(2.5)
		await capture("evt_eveil")
		Partie.force_eveil = false
		print("[TEST] ombres=", Partie.ombres.map(func (o): return o["espece"]))
		print("[TEST] arme=", Partie.base(Partie.arme())["nom"])
