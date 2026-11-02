extends Node
## Test automatisé du Scénario 3 dans le vrai monde : introduction complète (dialogues à choix, embuscade,
## ralenti d'esquive, Colosse, guidage, garde, roi, assaut de la cour, nomination), puis compagnon, missions,
## événement à décision, dialogue universel (mémoire, commerce), simulation du royaume et sauvegarde.

var world
var ok := 0
var ko := 0
var gs: GameState
var st: Story
var p: Player

func _check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		print("OK   " + label)
	else:
		ko += 1
		print("ÉCHEC " + label)

func _wait(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/story_%s.png" % name)
	print("SHOT story_", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME), " fps=", Engine.get_frames_per_second())

func _place(xz: Vector2, yaw_deg: float, y := INF) -> void:
	var h := Terrain.height_at(xz.x, xz.y) + 0.3 if y == INF else y
	p.global_position = Vector3(xz.x, h, xz.y)
	p.velocity = Vector3.ZERO
	world.rig.yaw = deg_to_rad(yaw_deg)
	world.rig.pitch = deg_to_rad(-20)
	world.rig._focus = p.global_position + Vector3.UP * 1.45

## Répond aux dialogues avec la liste de choix donnée (index parmi les réponses visibles), puis avance jusqu'à la fin
func _talk(choices: Array) -> void:
	var i := 0
	var guard := 0
	while Dialogue.active and guard < 60:
		guard += 1
		await _wait(0.15)
		var n: Dictionary = world.dlg._convo["nodes"][world.dlg._node_id]
		var vis := 0
		for ch in n.get("choices", []):
			if not ch.has("cond") or Dialogue.cond(ch["cond"]):
				vis += 1
		if vis > 0:
			world.dlg.choose(choices[i] if i < choices.size() else 0)
			i += 1
		else:
			world.dlg._shown = 99999.0
			world.dlg.advance()

func _kill_all() -> void:
	for m in Combat.monsters.duplicate():
		if Combat.alive(m):
			m.cbt.take_damage(99999.0, p, "magie")

func _wait_step(s: String, tmax := 8.0) -> bool:
	var t := 0.0
	while st.step != s and t < tmax:
		await _wait(0.1)
		t += 0.1
	return st.step == s

func _ready() -> void:
	while world.player == null or world.story == null:
		await get_tree().process_frame
	p = world.player
	Engine.max_physics_steps_per_frame = 40   # rendu logiciel très lent : la simulation garde le temps réel
	st = world.story
	gs = GameState.get_inst()
	await _wait(1.0)
	# ---------------------------------------------------------------- 1. réveil au portail
	_check(st.step == "debut", "L'histoire commence au portail (étape « debut »)")
	_check(not world.hud.btn_attack.visible and not world.hud.btn_spells["trait_feu"].visible, "Aucun bouton de combat avant que le récit ne les introduise")
	_check(Spawner.paused, "Les repaires sont suspendus pendant l'introduction")
	await _shot("01_portail")
	var t := 0.0
	while not Dialogue.active and t < 15.0:
		await _wait(0.2)
		t += 0.2
	_check(Dialogue.active, "Elian accourt et engage la conversation")
	await _wait(1.5)
	await _shot("02_dialogue_elian")
	await _talk([0, 2])   # bienveillant, puis « ton roi me le revaudra »
	_check(gs.val("bienveillance") >= 3 and gs.flag("veut_recompense"), "Les choix modifient la personnalité et posent des drapeaux (bienveillance %d)" % gs.val("bienveillance"))
	_check(int(Dialogue._value("relation_elian")) == 6, "La relation avec Elian est retenue (%d)" % int(Dialogue._value("relation_elian")))
	_check(await _wait_step("suivre"), "Étape « suivre Elian »")
	_check(world.hud.hint_key() == "deplacer", "Conseil discret de déplacement affiché")
	await _shot("03_suivre")
	# ---------------------------------------------------------------- 2. embuscade + tutoriel
	_place(Vector2(30, 152), 180)
	st.elian.teleport(Vector3(Story.AMBUSH.x, Terrain.height_at(Story.AMBUSH.x, Story.AMBUSH.y) + 0.3, Story.AMBUSH.y))
	_check(await _wait_step("embuscade"), "L'embuscade se déclenche à l'arrivée d'Elian")
	await _wait(0.3)
	_check(st.enemies.size() == 3, "Trois mercenaires de Vargas attaquent (%d)" % st.enemies.size())
	_check(world.hud.btn_attack.visible and world.hud.btn_attack.pulse, "Le bouton d'épée apparaît et s'illumine")
	await _wait(2.0)
	await _shot("04_embuscade")
	for i in 3:
		p.combat.attack()
		await _wait(0.7)
	await _wait(0.3)
	_check(world.hud.hint_key() == "combo" or gs.flag("tuto_epee"), "Après trois coups, le tutoriel passe au combo")
	# attaque dangereuse : ralenti et esquive
	var m: Monster = null
	for e in st.enemies:
		if Combat.alive(e):
			m = e
			break
	m.global_position = p.global_position + Vector3(0, 0, -2.5)
	m._sp_cool.clear()
	m._start_special(m.def["speciales"][0], p)
	await get_tree().process_frame
	_check(Engine.time_scale < 0.5, "Première attaque dangereuse : le temps ralentit (×%.2f)" % Engine.time_scale)
	_check(world.hud.hint_key() == "esquive" and world.hud.btn_dodge.pulse, "Le conseil d'esquive s'affiche, le bouton s'illumine")
	await _wait(0.4)
	await _shot("05_ralenti_esquive")
	p.combat.dodge()
	await _wait(0.3)
	_check(Engine.time_scale == 1.0, "L'esquive rend au temps sa vitesse normale")
	_kill_all()
	await _wait(0.5)
	_check(world.hud.btn_spells["trait_feu"].visible, "La magie est introduite après le premier ennemi abattu")
	# ---------------------------------------------------------------- 3. le Colosse
	_check(await _wait_step("colosse", 4.0), "Le Colosse entre en scène après l'embuscade")
	var boss: Monster = st.boss
	_check(boss != null and boss.cbt.max_hp >= 500, "Brokk le Colosse : beaucoup de points de vie (%d)" % (boss.cbt.max_hp if boss else 0))
	_place(Vector2(26, 124), 180)
	boss.global_position = Vector3(26, Terrain.height_at(26, 120) + 0.2, 120)
	await _wait(1.5)
	boss._sp_cool.clear()
	boss._start_special(boss.def["speciales"][0], p)
	var tele: Telegraph = boss._tele
	tele.struck.connect(func(): print("   (frappe : joueur dans la zone = %s, distance %.1f)" % [tele.contains(p.global_position), p.global_position.distance_to(tele.global_position)]))
	await _wait(0.6)
	await _shot("06_colosse_zone")
	_place(Vector2(boss.global_position.x, boss.global_position.z + 2.0), 180)
	var hp0 := p.cbt.hp
	var tw := 0.0
	while is_instance_valid(tele) and tele.is_processing() and tw < 6.0:
		await _wait(0.1)
		tw += 0.1
	await _wait(0.2)
	print("   (distance au Colosse : %.1f, état %d)" % [p.global_position.distance_to(boss.global_position), boss.state])
	_check(p.cbt.hp < hp0 or p.cbt.dead, "Rester dans la zone du séisme fait mal (%d → %d)" % [hp0, p.cbt.hp])
	p.cbt.hp = p.cbt.max_hp
	await _wait(1.0)
	_check(st.elian.cbt.dead or st.elian._target != null, "Elian participe au combat (cible ou à terre)")
	await _shot("07_colosse_combat")
	boss.cbt.take_damage(99999.0, p, "magie")
	_check(await _wait_step("apres_colosse", 3.0), "Le Colosse vaincu → suite de l'histoire")
	t = 0.0
	while not Dialogue.active and t < 5.0:
		await _wait(0.2)
		t += 0.2
	await _talk([2])   # « pourquoi Vargas… » → apprend le sceau
	_check(gs.flag("sait_sceau"), "Le choix « méfiant » révèle l'histoire du sceau")
	_check(await _wait_step("guidage"), "Elian guide le joueur vers le château")
	_check(world.hud.shown["potions"] and world.hud.shown["sorts"], "Tous les boutons sont désormais visibles")
	# ---------------------------------------------------------------- 4. le bourg, la porte, le roi
	_place(Vector2(0, -20), 180)
	await _wait(1.0)
	await _shot("08_decouverte_bourg")
	st.elian.teleport(Vector3(0, Terrain.height_at(0, -72), -72))
	_place(Vector2(0, -76), 180)
	_check(await _wait_step("porte", 3.0), "Arrivée à la porte : le garde Garric interpelle")
	await _wait(0.8)
	await _shot("09_garde")
	await _talk([0])
	_check(await _wait_step("roi"), "La porte s'ouvre, direction la salle du trône")
	# vraie marche (sans téléportation) de la cour jusque dans la salle du trône : le passage doit être libre
	_place(Vector2(0, -116), 180)
	st.elian.teleport(Vector3(1.5, Terrain.height_at(1.5, -114) + 0.3, -114))
	var tw0 := 0.0
	for tc in world.find_children("*", "TouchControls", true, false):
		tc.set_process(false)
	while p.global_position.z > -140.0 and tw0 < 14.0:
		world.rig.yaw = 0.0
		p.cam_yaw = 0.0
		p.input_dir = Vector2(0, -1)
		await get_tree().physics_frame
		tw0 += get_physics_process_delta_time()
	p.input_dir = Vector2.ZERO
	for tc in world.find_children("*", "TouchControls", true, false):
		tc.set_process(true)
	_check(p.global_position.z < -140.0 and absf(p.global_position.y - Castle.FLOOR) < 1.0, "Le joueur entre à pied dans la salle du trône (z=%.1f)" % p.global_position.z)
	await _wait(3.0)
	var ez := st.elian.global_position.z
	print("   Elian : mode %d, point %d/%d, pos %s, vitesse %s" % [st.elian.mode, st.elian.wp_i, st.elian.waypoints.size(), st.elian.global_position, st.elian.velocity])
	_check(ez < -130.0, "Elian entre aussi dans le donjon (z=%.1f)" % ez)
	await _shot("09b_entree_donjon")
	_place(Vector2(0, -150), 180, Castle.FLOOR + 0.3)
	st.elian.teleport(Vector3(-2.5, Castle.FLOOR + 0.3, -147))
	world._set_inside(true)
	t = 0.0
	while not Dialogue.active and t < 5.0:
		await _wait(0.2)
		t += 0.2
	_check(Dialogue.active, "Le roi Aldric engage la conversation")
	await _wait(1.2)
	await _shot("10_roi")
	# respect → que voulez-vous → négocier → (autorité insuffisante : 2e option masquée) → marché conclu
	await _talk([0, 0, 1, 0])
	_check(Progression.get_inst().gold >= 100, "La négociation avec le roi rapporte de l'or (%d)" % Progression.get_inst().gold)
	t = 0.0
	while not Dialogue.active and t < 3.0:
		await _wait(0.2)
		t += 0.2
	_check(Dialogue.active, "Alerte : les mercenaires sont dans la cour")
	await _talk([0])
	_check(await _wait_step("assaut"), "Étape « défendre la cour »")
	var hidden := true
	for g in get_tree().get_nodes_in_group("garde_cour"):
		if g.visible:
			hidden = false
	_check(hidden, "Les gardes de la cour se sont repliés pendant l'assaut")
	# ---------------------------------------------------------------- 5. assaut de la cour
	world._set_inside(false)
	_place(Vector2(0, -112), 0)
	await _wait(1.0)
	_check(st._wave == 1 and st.enemies.size() == 5, "Première vague : mercenaires et lanceurs de haches (%d)" % st.enemies.size())
	await _wait(1.5)
	await _shot("11_assaut_cour")
	_kill_all()
	await _wait(1.0)
	_check(st._wave == 2, "Deuxième vague : le lieutenant Harsk")
	await _wait(1.5)
	await _shot("12_lieutenant")
	_kill_all()
	_check(await _wait_step("roi_apres", 4.0), "La cour est défendue")
	_check(gs.flag("cour_defendue") and gs.val("reputation") >= 5, "Conséquences : réputation +5 (%d)" % gs.val("reputation"))
	_place(Vector2(0, -150), 180, Castle.FLOOR + 0.3)
	world._set_inside(true)
	t = 0.0
	while not Dialogue.active and t < 5.0:
		await _wait(0.2)
		t += 0.2
	await _talk([2])   # Protecteur de Valmont
	_check(await _wait_step("libre", 4.0), "Fin de l'introduction : le joueur gouverne")
	_check(gs.titre == "Protecteur de Valmont", "Titre obtenu selon le choix : %s" % gs.titre)
	_check(not Spawner.paused, "Les repaires du monde se réveillent")
	var e: Dictionary = gs.companions.get("elian", {})
	_check(not e.is_empty() and int(e["relation"]) >= 6, "Elian devient compagnon persistant avec la relation accumulée (%d)" % int(e.get("relation", 0)))
	_check(world.hud.btn_kingdom.visible, "Bouton du bureau royal disponible")
	world._set_inside(false)
	# ---------------------------------------------------------------- 6. royaume, missions, événements
	_check(Kingdom.inst != null, "La simulation du royaume tourne")
	var day := int(Kingdom.k()["jour"])
	for i in Kingdom.TICKS_PER_DAY:
		Kingdom.inst._tick(true)
	_check(int(Kingdom.k()["jour"]) == day + 1, "Une journée passe (jour %d)" % Kingdom.k()["jour"])
	var tr := Kingdom.res("tresor")
	Kingdom.set_tax(3)
	_check(Kingdom.daily_balance()["tresor"] > 0 and Kingdom.moral_target() < 55, "Impôt lourd : plus d'or, moral visé en baisse (%d)" % int(Kingdom.moral_target()))
	Kingdom.set_tax(1)
	_check(Kingdom.recruit() == "", "Recruter un soldat")
	Kingdom.k()["tresor"] = 500.0
	Kingdom.k()["bois"] = 300.0
	Kingdom.k()["pierre"] = 300.0
	_check(Kingdom.upgrade("ferme"), "Améliorer les fermes")
	_check(Kingdom.upgrade_block_reason("muraille") != "", "La muraille exige d'abord les plans (mission de recherche)")
	world.kui.open("economie")
	await _wait(0.4)
	await _shot("13_bureau_economie")
	world.kui.show_tab("missions")
	await _wait(0.3)
	await _shot("14_bureau_missions")
	_check(Kingdom.start_mission("liberer_berge", "elian") == "", "Elian part libérer la berge ouest")
	world.kui.show_tab("missions")
	await _wait(0.3)
	await _shot("15_mission_en_cours")
	world.kui.close_ui()
	await _wait(2.5)
	Kingdom.inst._check_missions()
	_check(not st.elian.visible, "Elian a quitté le monde pendant sa mission")
	for r in gs.missions:
		if r["statut"] == "en_cours":
			r["fin"] = Time.get_unix_time_from_system() - 1.0
			r["chance"] = 1.0
	Kingdom.inst._check_missions()
	_check(gs.missions[0]["statut"] == "reussie" and Kingdom.territory_ok("berge_ouest"), "Mission réussie : la berge ouest est libérée")
	_check(Spawner.by_id("berge_ouest").liberated, "Le repaire libéré ne fait plus apparaître de créatures")
	_check(st.elian.visible, "Elian est revenu")
	_check(String(gs.reports[0]["t"]).find("RÉUSSITE") >= 0, "Rapport détaillé de mission")
	_check(int(gs.companions["elian"]["xp"]) > 0 or int(gs.companions["elian"]["niveau"]) > 1, "Elian gagne de l'expérience")
	var pop := int(Kingdom.k()["population"])
	Kingdom.inst.present_event("refugies")
	await _wait(0.8)
	await _shot("16_evenement")
	await _talk([0])
	_check(int(Kingdom.k()["population"]) == pop + 14, "Décision : accueillir les réfugiés (+14 habitants)")
	_check(Kingdom.inst._extra_people.size() > 0, "Effet visible : de nouveaux habitants sur la place (%d)" % Kingdom.inst._extra_people.size())
	# ---------------------------------------------------------------- 7. dialogue universel
	_place(Vector2(0, -12), 180)
	await _wait(0.6)
	var merchant := Talk.node_of("marchand_0")
	_check(merchant != null, "Des marchands tiennent les étals")
	_place(Vector2(merchant.global_position.x + 1.5, merchant.global_position.z + 1.0), 0)
	await _wait(0.6)
	_check(world.hud.btn_talk.visible, "Le bouton « Parler » apparaît près d'un PNJ")
	var gold := Progression.get_inst().gold
	var pots := Progression.get_inst().potions_soin
	world.dlg.start(Talk.build(merchant))
	await _wait(0.8)
	await _shot("17_marchand")
	# menu : Discuter(0) Parlez-moi de vous(1) Royaume(2) Nouvelles(3) Commerce(4)…
	var labels := []
	for ch in world.dlg._convo["nodes"]["menu"]["choices"]:
		labels.append(ch["text"])
	_check("Commerce" in labels and "Négocier les prix" in labels, "Options propres au marchand : commerce et négociation")
	await _talk([labels.find("Commerce"), 0, 2, labels.size() - 1])
	_check(Progression.get_inst().potions_soin == pots + 1 and Progression.get_inst().gold < gold, "Achat d'une potion de soin")
	var said := Array(gs.mem("marchand_0").get("sujets", [])).size()
	world.dlg.start(Talk.build(merchant))
	await _talk([0, 99])
	world.dlg.start(Talk.build(merchant))
	await _talk([0, 99])
	_check(Array(gs.mem("marchand_0")["sujets"]).size() >= said + 2 and int(gs.mem("marchand_0")["vu"]) >= 3, "Le PNJ se souvient (rencontres, sujets déjà abordés)")
	world.dlg.start(Talk.build(merchant))
	await _wait(0.6)
	_check(world.dlg._close_btn.visible, "Bouton « Fermer » visible dans les conversations avec les PNJ")
	world.dlg._close_btn.pressed.emit()
	await _wait(0.2)
	_check(not Dialogue.active, "« Fermer » termine la conversation")
	var g := Talk.node_of("garric")
	_check(g != null, "Le garde Garric est identifiable par son nom")
	# ---------------------------------------------------------------- 8. sauvegarde
	gs.save_game()
	var g2 := GameState.new()
	g2.load_game()
	_check(g2.story == "libre" and g2.titre == gs.titre and g2.companions.has("elian") and int(g2.kingdom["population"]) == int(Kingdom.k()["population"]), "Sauvegarde / chargement : histoire, titre, compagnon et royaume conservés")
	print("RÉSULTAT : %d réussis, %d échecs" % [ok, ko])
	get_tree().quit()
