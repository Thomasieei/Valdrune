extends Node
## Test automatisé de la vie du royaume : entraînement, phrases des habitants, garde rapprochée,
## raid de bandits avec intervention de la garde, justice (agenouillement, récompense, arrestation
## avec escorte jusqu'à la prison, procès, bannissement), caravane, sauvegarde.

var world
var ok := 0
var ko := 0
var p: Player
var gs: GameState

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
	for i in 3:
		await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/vie_%s.png" % name)
	print("SHOT vie_", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _place(xz: Vector2, yaw_deg: float, y := INF) -> void:
	var h := Terrain.height_at(xz.x, xz.y) + 0.3 if y == INF else y
	p.global_position = Vector3(xz.x, h, xz.y)
	p.velocity = Vector3.ZERO
	world.rig.yaw = deg_to_rad(yaw_deg)
	world.rig.pitch = deg_to_rad(-22)
	world.rig._focus = p.global_position + Vector3.UP * 1.45

func _until(f: Callable, tmax: float) -> bool:
	var t := 0.0
	while not f.call() and t < tmax:
		await _wait(0.25)
		t += 0.25
	return f.call()

func _villager_near(pos: Vector2, exclude: Array = []) -> Villager:
	var best: Villager = null
	var bd := INF
	for n in get_tree().get_nodes_in_group("pnj"):
		if n is Villager and n.has_meta("talk") and not n.captive and not exclude.has(n):
			var r: String = n.get_meta("talk")["role"]
			if r == "marchand":
				continue
			var d: float = Vector2(n.global_position.x, n.global_position.z).distance_to(pos)
			if d < bd:
				bd = d
				best = n
	return best

func _ready() -> void:
	Frontier.quiet = true
	while world.player == null or world.story == null:
		await get_tree().process_frame
	p = world.player
	Engine.max_physics_steps_per_frame = 40
	AuraGuard.enabled = false   # parade de l'aura testée à part (pouvoirs)   # rendu logiciel très lent : la simulation garde le temps réel
	gs = GameState.get_inst()
	await _wait(1.5)
	_check(Story.done() and Kingdom.inst != null, "Partie en mode libre, royaume actif")
	# ---------------------------------------------------------------- entraînement
	_place(Vector2(2, -106), 90)
	world.rig.yaw = deg_to_rad(80)
	world.rig._last_manual = Time.get_ticks_msec() / 1000.0 + 1000.0
	await _wait(3.0)
	_check(Vie.inst._sparring.size() >= 1 and Vie.inst._archers.size() >= 1, "Soldats à l'épée et archers à l'entraînement (%d duels, %d archers)" % [Vie.inst._sparring.size(), Vie.inst._archers.size()])
	await _shot("01_entrainement")
	world.rig.yaw = deg_to_rad(-80)
	world.rig._last_manual = Time.get_ticks_msec() / 1000.0 + 1000.0
	await _wait(2.5)
	await _shot("01b_archers")
	var a0 := Vie.inst._archers.size()
	Kingdom.k()["soldats"] = 12
	Kingdom.add("soldats", 0)
	await _wait(0.5)
	_check(Vie.inst._archers.size() > a0, "Plus de soldats → plus de recrues à l'entraînement (%d archers)" % Vie.inst._archers.size())
	# ---------------------------------------------------------------- phrases des habitants
	gs.values["reputation"] = 20
	gs.values["confiance_habitants"] = 15
	_check(Vie.tier() == "adore", "Réputation élevée : le peuple adore le seigneur")
	var vn := _villager_near(Vector2(0, -20))
	_place(Vector2(vn.global_position.x + 2.5, vn.global_position.z + 1.0), 90)
	Vie.inst._bark_global = 0.0
	var barked := await _until(func():
		for n in get_tree().get_nodes_in_group("pnj"):
			if n.get_node_or_null("Bulle"):
				return true
		return false, 4.0)
	_check(barked, "Un habitant salue le seigneur au passage")
	await _shot("02_salut_habitant")
	gs.values["crainte"] = 30
	gs.values["confiance_habitants"] = 0
	gs.values["reputation"] = 0
	_check(Vie.tier() == "craint", "Seigneur redouté : le peuple le craint")
	gs.values["crainte"] = 0
	# ---------------------------------------------------------------- garde rapprochée
	var garric := Talk.node_of("garric")
	_check(garric != null, "Garric est à son poste")
	var s1 := Escort.take_guard(garric)
	_check(s1 != null and not garric.visible, "Garric quitte son poste et rejoint la garde rapprochée")
	_check(Escort.call_guards(2) == 2, "Deux gardes de plus arrivent du château")
	_place(Vector2(10, -40), 180)
	await _until(func():
		for s in Escort.members:
			if s.global_position.distance_to(p.global_position) > 14.0:
				return false
		return true, 15.0)
	var near := 0
	for s in Escort.members:
		if s.global_position.distance_to(p.global_position) < 14.0:
			near += 1
	for s in Escort.members:
		print("   soldat %s mode %d pos %s vel %s ts %.2f fps %d proc %s" % [s.nom, s.mode, s.global_position, s.velocity, Engine.time_scale, Engine.get_frames_per_second(), s.can_process()])
	print("   joueur ", p.global_position)
	_check(near == 3, "Les trois gardes suivent le seigneur (%d à proximité)" % near)
	await _shot("03_garde_rapprochee")
	Escort.set_mode(Escort.members[1], Soldier.M.ECLAIREUR)
	_check(Escort.members[1].mode == Soldier.M.ECLAIREUR, "Un garde ouvre la marche en éclaireur")
	# un ennemi surgit : la garde se bat
	var b := Monster.new()
	b.kind = "bandit"
	b.no_respawn = true
	b.position = p.global_position + Vector3(4, 0.3, -3)
	world.add_child(b)
	b._aggro()
	var hit := await _until(func(): return b.cbt.dead or b.cbt.hp < b.cbt.max_hp, 15.0)
	_check(hit, "La garde rapprochée attaque l'ennemi (%d/%d PV)" % [int(b.cbt.hp), int(b.cbt.max_hp)])
	await _shot("04_garde_combat")
	if is_instance_valid(b) and not b.cbt.dead:
		b.cbt.take_damage(9999, p, "magie")
	# ---------------------------------------------------------------- raid de bandits
	Vie.inst.start_raid("bourg_est")
	_check(Vie.inst.raid.size() > 0 and Vie.inst.raid["bandits"].size() >= 3, "Raid : des bandits pillent les maisons à l'est du bourg")
	_check(Vie.inst.raid["guards"].size() >= 1, "La garnison envoie %d soldat(s)" % Vie.inst.raid["guards"].size())
	_place(Vector2(30, -8), 90)
	await _wait(2.0)
	await _shot("05_raid")
	var fought := await _until(func():
		for m in Vie.inst.raid.get("bandits", []):
			if is_instance_valid(m) and (m.cbt.dead or m.cbt.hp < m.cbt.max_hp):
				return true
		return Vie.inst.raid.is_empty(), 30.0)
	_check(fought, "Gardes et bandits s'affrontent réellement")
	for m in Vie.inst.raid.get("bandits", []):
		if is_instance_valid(m) and not m.cbt.dead:
			m.cbt.take_damage(9999, p, "magie")
	Vie.inst._raid_tick(1.0)
	_check(Vie.inst.raid.is_empty() and String(gs.reports[0]["t"]).find("repoussés") >= 0, "Raid repoussé, consigné dans les rapports")
	Escort.dismiss_all()
	await _wait(0.5)
	_check(Escort.members.is_empty(), "La garde rapprochée retourne à ses postes")
	# ---------------------------------------------------------------- justice
	var v1 := _villager_near(Vector2(0, -60))
	var rel0 := int(gs.mem(v1.get_meta("talk")["id"]).get("relation", 0))
	Justice.kneel(v1)
	_check(gs.val("crainte") > 0 and gs.val("autorite") > 0, "« À genoux ! » : autorité et crainte augmentent")
	_place(Vector2(v1.global_position.x + 2, v1.global_position.z + 2), 225)
	await _wait(0.8)
	await _shot("06_agenouille")
	Progression.get_inst().add_gold(100)
	var g0 := Progression.get_inst().gold
	_check(Justice.reward(v1) == "" and Progression.get_inst().gold == g0 - 25, "Récompense de 25 or pour la famille")
	_check(int(gs.mem(v1.get_meta("talk")["id"])["relation"]) > rel0, "La relation avec l'habitant s'améliore")
	# menu d'ordres présent dans le dialogue
	var conv := Talk.build(v1)
	_check(conv["nodes"].has("ordres") and conv["nodes"].has("arreter") and conv["nodes"].has("bannir"), "Le dialogue propose les ordres du seigneur (genoux, récompense, bannir, arrêter)")
	var vid: String = v1.get_meta("talk")["id"]
	Justice.arrest(v1, "On t'a vu voler au marché")
	_place(Vector2(v1.global_position.x + 3, v1.global_position.z + 3), 225)
	var escorted := await _until(func(): return v1.has_meta("talk") and v1.get_meta("talk")["role"] == "escorte_prison" and Soldier.all.filter(func(x): return x.mode == Soldier.M.ESCORTE_PRISONNIER).size() >= 2, 50.0)
	print("   v1 %s %s ; soldats : %s" % [v1.global_position, v1.get_meta("talk"), Soldier.all.map(func(x): return "%s m%d %s" % [x.nom, x.mode, x.global_position])])
	_check(escorted, "Deux gardes viennent chercher l'habitant et l'emmènent")
	await _wait(1.0)
	await _shot("07_arrestation")
	# pendant tout le trajet : gardes et prisonnier restent sur le sol (jamais sous la carte)
	var worst := [0.0, ""]
	var probe := func() -> bool:
		for x in Soldier.all.filter(func(q): return q.mode == Soldier.M.ESCORTE_PRISONNIER) + ([v1] if is_instance_valid(v1) else []):
			var pos: Vector3 = x.global_position
			var dz := Justice.dug(Vector2(pos.x, pos.z))
			var err := 0.0
			if dz:
				err = maxf(Justice.FL - 0.4 - pos.y, pos.y - (Justice.Y0 + 0.4))
			else:
				err = absf(pos.y - Powers.ground(pos + Vector3.UP * 0.6))
			if err > worst[0]:
				worst[0] = err
				worst[1] = "%s %s" % [x.name, pos]
		return not Justice.prisoner_record(vid).is_empty()
	var jailed := await _until(probe, 150.0)
	_check(jailed, "Il est escorté à pied jusqu'à la prison et enfermé")
	_check(float(worst[0]) < 0.7, "Escorte toujours au niveau du sol, escaliers compris (écart max %.2f m %s)" % [worst[0], worst[1]])
	_place(Vector2(-27, -106), 0)
	world.rig.yaw = deg_to_rad(17)
	world.rig._last_manual = Time.get_ticks_msec() / 1000.0 + 1000.0
	await _wait(1.5)
	await _shot("08_prison")
	var conv2 := Talk.build(v1)
	_check(conv2["nodes"].has("proces") and conv2["nodes"].has("exec"), "Au prisonnier : libérer, procès, travaux forcés ou exécution")
	world.dlg.start(conv2)
	await _wait(0.5)
	world.dlg.choose(1)   # procès
	await _wait(0.3)
	world.dlg.choose(1)   # coupable : l'exil
	await _wait(0.5)
	_check(Justice.prisoner_record(vid).is_empty() and Array(gs.flags.get("bannis", [])).has(vid), "Procès : exilé, il quitte la prison et le royaume")
	var v2 := _villager_near(Vector2(0, -20), [v1])
	var pop0 := int(Kingdom.res("population"))
	Justice.banish(v2, "Tu m'as trahi")
	_check(int(Kingdom.res("population")) == pop0 - 1 and Array(gs.flags["bannis"]).size() >= 2, "Bannissement : l'habitant s'en va, la population baisse")
	_check(String(gs.reports[0]["t"]).find("banni") >= 0, "L'acte est consigné dans les rapports")
	# ---------------------------------------------------------------- bourg complet
	_check(Town.houses.size() - Town.gardens.size() >= 20 and Town.gardens.size() >= 6, "Bourg : %d maisons alignées sur les rues, %d potagers clôturés" % [Town.houses.size() - Town.gardens.size(), Town.gardens.size()])
	var merch := 0
	var crieur: Villager = null
	for n in get_tree().get_nodes_in_group("pnj"):
		if n.has_meta("talk"):
			if n.get_meta("talk")["role"] == "marchand": merch += 1
			if n.get_meta("talk")["role"] == "crieur": crieur = n
	_check(merch >= 4, "Un marchand à chaque étal (%d)" % merch)
	var inside := 0
	for n in get_tree().get_nodes_in_group("pnj"):
		if n is Villager and n.visible and not n.captive and Place.blocked(n.global_position):
			inside += 1
	_check(inside == 0, "Aucun habitant coincé dans le décor (%d)" % inside)
	# ---------------------------------------------------------------- contrats de primes
	_check(crieur != null, "Le crieur public est sur la place")
	var cv := Talk.build(crieur)
	_check(cv["nodes"].has("contrats") and cv["nodes"]["contrats"]["choices"].size() >= 2, "Le crieur propose des contrats de primes")
	var z: Dictionary = Contracts.offers()[0]
	Contracts.accept(z)
	var sp := Spawner.by_id(z["id"])
	var zp: Vector2 = z["pos"]
	_place(zp + Vector2(6, 6), 220)
	var spawned := await _until(func(): return sp._alive.size() > 0, 15.0)
	var need := int(Contracts._st()["actifs"][z["id"]]["need"])
	var g1 := Progression.get_inst().gold
	var guard := 0
	while Contracts._st()["actifs"].has(z["id"]) and guard < 40:
		guard += 1
		for m in sp._alive.duplicate():
			if Combat.alive(m):
				m.cbt.take_damage(99999, p, "magie")
		await _wait(0.6)
		if sp._alive.is_empty():
			sp._timers = [0.0]
	_check(spawned and z["id"] in Contracts._st()["faits"] and Progression.get_inst().gold > g1, "Contrat rempli (%s, %d cibles) : prime versée (+%d or)" % [z["label"], need, Progression.get_inst().gold - g1])
	# ---------------------------------------------------------------- événement du monde
	_place(Vector2(-60, 40), 180)
	await _wait(0.5)
	var ev: Spawner = world.events.trigger(p.global_position, Vector3(0, 0, 1))
	_check(ev != null, "Un événement surgit près du joueur hors du bourg")
	var root: Node = ev.get_parent()
	var all_sp := root.get_children().filter(func(c): return c is Spawner)
	await _until(func(): return all_sp.all(func(s): return not is_instance_valid(s) or s._alive.size() > 0), 10.0)
	var g2 := Progression.get_inst().gold
	for k in 30:
		for s in all_sp:
			if is_instance_valid(s):
				for m in s._alive.duplicate():
					if Combat.alive(m):
						m.cbt.take_damage(99999, p, "magie")
		await _wait(0.4)
		if Progression.get_inst().gold > g2:
			break
	_check(Progression.get_inst().gold > g2, "Événement repoussé : récompense versée (+%d or)" % (Progression.get_inst().gold - g2))
	# ---------------------------------------------------------------- quêtes personnelles
	var giver: Villager = null
	for n in get_tree().get_nodes_in_group("pnj"):
		if n is Villager and Quests.can_offer(n) and Vector2(n.global_position.x, n.global_position.z).distance_to(Layout.TOWN) < 60.0:
			giver = n
			break
	_check(giver != null, "Un habitant a du travail pour le seigneur (« ! » doré)")
	await _wait(0.6)
	_place(Vector2(giver.global_position.x + 3.0, giver.global_position.z), 0)
	await _wait(0.8)
	_check(world.quests._marks.has(giver) and world.quests._marks[giver].visible and world.quests._marks[giver].text == "!", "Le « ! » flotte au-dessus du donneur de quête")
	var qc := Talk.build(giver)
	_check(qc["nodes"].has("q_offre"), "Il propose une quête dans le dialogue")
	# forcer chaque type de quête et les jouer réellement
	var types_ok := {}
	for qt in ["chasse", "livraison", "recuperation", "escorte"]:
		var q: Dictionary = {}
		for k in 12:
			var cand := Quests.make(giver)
			if cand["type"] == qt:
				q = cand
				break
			Quests._st()["faites"] = int(Quests._st()["faites"]) + 1
		if q.is_empty():
			print("   (type %s non généré)" % qt)
			continue
		Quests.actives().clear()
		Quests.accept(q)
		await _wait(0.5)
		match qt:
			"chasse":
				var qsp := Spawner.by_id(q["zone"])
				var qzp: Vector2 = Spawner.ZONES.filter(func(z): return z["id"] == q["zone"])[0]["pos"]
				_place(qzp + Vector2(5, 5), 0)
				await _until(func(): return qsp._alive.size() > 0, 12.0)
				for k in 30:
					for m in qsp._alive.duplicate():
						if Combat.alive(m):
							m.cbt.take_damage(99999, p, "magie")
					await _wait(0.5)
					if q["state"] == "a_rendre":
						break
					if qsp._alive.is_empty():
						qsp._timers = [0.0]
			"livraison":
				var to := Talk.node_of(q["to_id"])
				var cv2 := Talk.build(to)
				for ch in cv2["nodes"]["menu"]["choices"]:
					if ch.get("next", "") == "q_livre":
						ch["callback"].call()
			"recuperation":
				_place(Vector2(float(q["pos"][0]) + 4.0, float(q["pos"][1])), 0)
				await _wait(1.0)
				if qt == "recuperation":
					await _shot("10_quete_objet")
				_place(Vector2(float(q["pos"][0]), float(q["pos"][1])), 0)
				await _until(func(): return q["state"] == "a_rendre", 6.0)
			"escorte":
				await _wait(0.6)
				var fol: Villager = world.quests._followers.get(q["id"])
				_check(fol != null, "Escorte : le fils du donneur suit le seigneur")
				var dest := Vector2(float(q["pos"][0]), float(q["pos"][1]))
				_place(dest + Vector2(3, 3), 0)
				await _wait(1.2)
				_place(dest + Vector2(1, 1), 0)
				await _until(func(): return q["state"] == "a_rendre", 10.0)
				for m in Combat.monsters.duplicate():
					if is_instance_valid(m) and m.global_position.distance_to(p.global_position) < 60.0 and Combat.alive(m):
						m.cbt.take_damage(99999, p, "magie")
		var gq0 := Progression.get_inst().gold
		var back := Talk.build(giver)
		var ok_back := false
		for ch in back["nodes"]["menu"]["choices"]:
			if ch.get("next", "") == "q_rendre":
				ch["callback"].call()
				ok_back = true
		types_ok[qt] = q["state"] == "a_rendre" and ok_back and Progression.get_inst().gold > gq0
		_check(types_ok[qt], "Quête « %s » accomplie et récompensée (%s)" % [qt, q["titre"]])
		Quests._st()["donneurs"].erase(giver.get_meta("talk")["id"])
	# ---------------------------------------------------------------- capture
	_place(Vector2(-60, 60), 0)
	await _wait(0.4)
	if Dialogue.active:
		print("   (dialogue resté ouvert avant la capture — fermé)")
		world.dlg._close()
	var bdt := Monster.new()
	bdt.kind = "bandit"
	bdt.no_respawn = true
	world.add_child(bdt)
	bdt.global_position = p.global_position + Vector3(0, 0.3, 2.0)
	await _wait(0.4)
	bdt.stun(6.0, false)
	bdt.cbt.hp = bdt.cbt.max_hp * 0.2
	await _wait(0.8)
	print("   (capture : dist %.1f, pv %d/%d, capturable %s, nearest %s, capt %s, label %s, dlg %s)" % [bdt.global_position.distance_to(p.global_position), bdt.cbt.hp, bdt.cbt.max_hp, Capture.capturable(bdt), Capture.nearest(p.global_position), world._capt, world.hud.btn_talk.label, Dialogue.active])
	_check(world._capt == bdt and world.hud.btn_talk.label.begins_with("Capturer"), "Bandit affaibli : bouton « Capturer »")
	var np0: int = Kingdom.k()["prisonniers"].size()
	world._talk()
	await _wait(2.2)
	_check(not is_instance_valid(bdt) and Kingdom.k()["prisonniers"].size() == np0 + 1, "Le bandit se rend et part aux cachots")
	Kingdom.k()["soldats"] = Kingdom.max_soldiers() - 1
	var cap: Dictionary = Kingdom.k()["prisonniers"][-1]
	var cn := Talk.node_of(cap["id"])
	var cc := Talk.build(cn)
	_check(cc["nodes"].has("interro") and cc["nodes"].has("rancon") and cc["nodes"].has("enrole"), "Au captif : interroger, rançon, enrôler")
	var sold0 := int(Kingdom.res("soldats"))
	for ch in cc["nodes"]["menu"]["choices"]:
		if ch.get("next", "") == "enrole":
			ch["callback"].call()
	_check(int(Kingdom.res("soldats")) == sold0 + 1 and Justice.prisoner_record(cap["id"]).is_empty(), "Le captif enrôlé rejoint la garde")
	# ---------------------------------------------------------------- serviteurs : appel et retour de mission
	_place(Vector2(10, -30), 0)
	await _wait(0.5)
	world.kui.open("personnages")
	await _wait(0.8)
	await _shot("11_serviteurs")
	Portraits.get_tex("elian").get_image().save_png("res://shots/vie_portrait_elian.png")
	world.kui.close_ui()
	await _wait(0.3)
	MissionReturn.summon("elian")
	var came := await _until(func(): return Dialogue.active, 15.0)
	_check(came, "Appel : Elian accourt et attend les ordres")
	await _shot("12_appel")
	world.dlg._close()
	await _until(func(): return not Dialogue.active, 3.0)
	Kingdom.inst.mission_done.emit({"agent": "elian", "statut": "reussie", "rapport": "Mission d'essai — RÉUSSITE.\nGains : +50 or"})
	var rep := await _until(func(): return Dialogue.active, 15.0)
	_check(rep, "Retour de mission : l'agent revient, salue et fait son rapport")
	await _shot("13_rapport")
	world.dlg._close()
	await _wait(0.3)
	# ---------------------------------------------------------------- pourparlers d'un camp + duel d'honneur
	var gid := "camp_bandits"
	CampParley.set_status(gid, "neutre")
	var cz: Vector2 = CampParley.zone(gid)["pos"]
	_place(cz + Vector2(0, 30), 180)
	await _until(func(): return CampParley.members(gid).size() >= 3, 15.0)
	var mem := CampParley.members(gid)
	var handed := await _until(func(): return world.hud.btn_prompt.visible and world.hud.btn_prompt.label == "Parlementer", 6.0)
	_check(mem.size() >= 3 and handed, "Camp de bandits : %d occupants, bouton ✋ « Parlementer » avant le combat" % mem.size())
	world.hud.btn_prompt.pressed.emit()
	var hailed := await _until(func(): return Dialogue.active, 12.0)
	var mlabels := []
	if hailed:
		for ch in world.dlg._convo["nodes"]["menu"]["choices"]:
			mlabels.append(ch["text"])
	_check(hailed and mlabels.size() >= 6, "« Halte ! Qui va là ? » : le chef vient parlementer (%d choix)" % mlabels.size())
	await _shot("10_pourparlers")
	world.dlg.choose(3)   # duel d'honneur
	await _wait(0.6)
	var chef: Node3D = CampParley.inst.duel_chef
	_check(chef != null and chef.duel and CampParley.members(gid).filter(func(m): return m != chef).all(func(m): return m.peaceful), "Duel d'honneur : le chef seul contre le souverain, ses hommes regardent")
	var sold_c := int(Kingdom.res("soldats"))
	for k in 30:
		if Dialogue.active or not Combat.alive(chef):
			break
		chef.cbt.take_damage(60.0, p, "magie")
		await _wait(0.4)
	_check(Combat.alive(chef) and Dialogue.active, "Vaincu, le chef se rend au lieu de mourir")
	world.dlg.choose(0)   # tu me serviras
	await _wait(0.5)
	_check(String(CampParley._st().get(gid, "")) == "allie" and CampParley.members(gid).is_empty() == false or String(CampParley._st().get(gid, "")) == "allie", "Le camp se rallie au souverain (%d → %d soldats, caserne max %d)" % [sold_c, int(Kingdom.res("soldats")), Kingdom.max_soldiers()])
	# ---------------------------------------------------------------- royaume des nains
	_place(Layout.PORTAL + Vector2(0, -6), 0)
	await _wait(0.5)
	p.global_position = Vector3(Layout.PORTAL.x, Layout.PORTAL_H + 0.4, Layout.PORTAL.y)   # on franchit l'arche
	await _until(func(): return DwarfRealm.inside, 15.0)
	await _wait(0.8)
	print("   (Karak : dedans=%s pos=%s mort=%s)" % [DwarfRealm.inside, p.global_position, p.cbt.dead])
	_check(DwarfRealm.inside and p.global_position.y > 190.0 and not p.cbt.dead, "Le portail mène à Karak Dûm (vallée enneigée)")
	await _wait(1.0)
	_check(absf(p.global_position.y - DwarfRealm.ground(p.global_position.x - DwarfRealm.O.x, p.global_position.z - DwarfRealm.O.z)) < 1.2, "On tient debout sur la neige (pas de chute)")
	await _shot("11_karak_arrivee")
	_place(Vector2(DwarfRealm.O.x, DwarfRealm.O.z + DwarfRealm.GATE_Z + 14.0), 180, DwarfRealm.O.y + 0.4)
	var halted := await _until(func(): return Dialogue.active, 8.0)
	_check(halted, "Le capitaine nain arrête le souverain devant la porte")
	await _shot("12_karak_porte")
	Progression.get_inst().add_gold(500)
	world.dlg.choose(1)   # présent pour le roi
	await _wait(3.5)
	_check(DwarfRealm.inst.gate_open, "Un présent : la porte de bronze s'ouvre")
	var king := Talk.node_of("roi_nain")
	var kc := Talk.build(king)
	var klabels := []
	for ch in kc["nodes"]["menu"]["choices"]:
		klabels.append(ch["text"])
	_check(klabels.size() >= 5 and String(klabels[0]).contains("alliance"), "Audience du roi Thorvald : alliance, acier, guerriers, Vargas")
	_place(Vector2(DwarfRealm.O.x + 2.0, DwarfRealm.O.z - 104.0), 180, DwarfRealm.O.y + 0.4)
	world.rig.yaw = 0.0
	await _wait(1.0)
	await _shot("13_karak_cour")
	DwarfRealm.inst.leave()
	await _until(func(): return not DwarfRealm.inside, 10.0)
	await _wait(0.5)
	_check(not DwarfRealm.inside and p.global_position.y < 60.0, "Retour à Valmont par le portail")
	# ---------------------------------------------------------------- commandement rapide
	var cu: CommandUI = CommandUI.inst
	cu.open()
	var n0 := Escort.members.size()
	cu.order("portail")
	await _wait(0.6)
	_check(Escort.members.size() >= n0 + 2 and Escort.members.all(func(s): return s.global_position.distance_to(p.global_position) < 8.0), "Portail : deux gardes apparaissent à vos côtés")
	await _shot("14_commandement")
	cu.order("patrouille")
	_check(Escort.members.all(func(s): return s.patrol.size() == 4 and s.mode == Soldier.M.GARDER), "« Patrouillez ici » : ronde autour du point choisi")
	cu.order("passif")
	_check(Escort.members.all(func(s): return s.passive and s._pick_target() == null), "« Ne pas attaquer » : la garde n'engage plus le combat")
	cu.order("renvoi")
	cu.close()
	await _wait(0.5)
	_check(Escort.members.is_empty(), "« Rentrez » : la garde retourne au château")
	_check(WorkersView != null and world.find_child("Ouvriers", false, false) != null, "Ouvriers visibles sur les chantiers")
	# ---------------------------------------------------------------- gouverner (façon Age of Empires)
	var gu: GestionUI = GestionUI.inst
	gu.open("travail")
	var w0 := int(Kingdom.bld("scierie")["ouvriers"])
	for k in 3:
		Kingdom.set_workers("scierie", 1)
	_check(int(Kingdom.bld("scierie")["ouvriers"]) > w0, "Travail : on affecte des ouvriers au bois (%d → %d)" % [w0, int(Kingdom.bld("scierie")["ouvriers"])])
	await _shot("15_gestion_travail")
	gu.tab = "armee"
	gu._sel_n = 6
	gu.refresh()
	var dep := Army.deploy(6)
	await _wait(0.5)
	_check(dep.size() >= 4, "Armée : %d soldats sortent de la caserne" % dep.size())
	gu._pick = "patrouille"
	gu._on_pick(Vector2(-20, -40))
	gu._on_pick(Vector2(10, -40))
	Army.order(Army.alive(), "patrouille", gu._route.duplicate())
	_check(Army.alive().all(func(s): return s.patrol.size() == 2), "Armée : ronde tracée sur la mini-carte")
	await _shot("16_gestion_armee")
	Army.order(Army.alive(), "rentrer")
	gu.tab = "gens"
	gu.refresh()
	var folks := People.all()
	_check(folks.size() >= 15, "Gens : %d personnes à portée de commandement" % folks.size())
	await _shot("17_gestion_gens")
	gu.close()
	var va: Node3D = folks.filter(func(n): return n is Villager)[0]
	var vb: Node3D = folks.filter(func(n): return n is Villager)[1]
	People.summon(va)
	_check(va.global_position.distance_to(p.global_position) < 4.5, "Appeler : %s arrive auprès du souverain" % People.nom(va))
	var ida: String = va.get_meta("talk")["id"]
	var idb: String = vb.get_meta("talk")["id"]
	People.duel(va, vb, true)
	var fell := await _until(func(): var bl: Array = gs.flags.get("bannis", []); return bl.has(ida) or bl.has(idb), 20.0)
	_check(fell, "Duel à mort entre deux habitants : le perdant tombe")
	# ---------------------------------------------------------------- donjon qui « poppe »
	var dg: Dungeons = Dungeons.inst
	var dd := dg.spawn("E")
	_check(not dd.is_empty() and is_instance_valid(dd["node"]), "Une faille de donjon s'ouvre, faisceau géant visible")
	dg.enter(dd)
	await _until(func(): return not Dungeons.inside.is_empty() and p.global_position.y > 290.0, 12.0)
	_check(p.global_position.y > 290.0, "On entre dans le donjon (salles de pierre)")
	await _wait(1.0)
	await _shot("18_donjon")
	var boss: Node3D = dg._boss
	_place(Vector2(Dungeons.B.x, Dungeons.B.z - 88.0), 180, Dungeons.B.y + 0.5)
	await _wait(1.5)
	await _shot("19_donjon_gardien")
	var g_before := Progression.get_inst().gold
	if Combat.alive(boss):
		boss.cbt.take_damage(9999999.0, p, "magie")
	await _until(func(): return Progression.get_inst().gold > g_before, 8.0)
	_check(Progression.get_inst().gold > g_before, "Gardien vaincu : le coffre récompense (+%d or)" % (Progression.get_inst().gold - g_before))
	await _until(func(): return Dungeons.inside.is_empty(), 12.0)
	await _wait(1.0)
	_check(Dungeons.inside.is_empty() and p.global_position.y < 100.0, "Retour au royaume, la faille se referme")
	# ---------------------------------------------------------------- sentinelles d'un camp, puis camp rasé
	var gz2 := "brigands_est"
	CampParley.set_status(gz2, "neutre")
	CampParley.inst._hailed.erase(gz2)
	var c2: Vector2 = CampParley.zone(gz2)["pos"]
	await _wait(2.5)   # la sortie de faille finit son fondu avant qu'on bouge
	_place(c2 + Vector2(0, 70), 180)
	await _until(func(): return CampParley.members(gz2).size() >= 5, 15.0)
	_place(c2 + Vector2(0, 46), 180)
	print("   (sentinelles : distance au camp %.1f, membres %d, statut %s)" % [Vector2(p.global_position.x, p.global_position.z).distance_to(c2), CampParley.members(gz2).size(), CampParley._st().get(gz2, "")])
	var stopped := await _until(func(): return Dialogue.active, 15.0)
	_check(stopped and String(world.dlg._convo["nodes"]["menu"]["nom"]).begins_with("Sentinelle"), "Les sentinelles arrêtent le souverain avant tout combat")
	await _shot("20_sentinelles")
	world.dlg.choose(1)   # raser le camp
	await _wait(0.5)
	var elites := CampParley.members(gz2).filter(func(m): return m.kind in ["garde_elite", "geant", "mercenaire"])
	_check(elites.size() >= 3, "Le camp a son chef, sa garde d'élite et un géant (%d élites)" % elites.size())
	for k in 20:
		for m in CampParley.members(gz2):
			m.cbt.take_damage(99999.0, p, "magie")
		await _wait(0.4)
		if CampParley.members(gz2).is_empty():
			break
	_place(c2 + Vector2(0, 4), 180)
	var razable := await _until(func(): return world.hud.btn_prompt.visible and world.hud.btn_prompt.label == "Raser le camp", 8.0)
	_check(razable, "Camp vaincu : « Raser le camp » est proposé")
	world.hud.btn_prompt.pressed.emit()
	await _wait(1.0)
	_check(String(CampParley._st().get(gz2, "")) == "rase", "Le camp part en fumée et ne reviendra pas")
	await _shot("21_camp_rase")
	# ---------------------------------------------------------------- contremaître et rassemblement
	Talk._preset("scierie")
	_check(int(Kingdom.bld("scierie")["ouvriers"]) >= 10, "Contremaître : tout le monde au bois (%d bûcherons)" % int(Kingdom.bld("scierie")["ouvriers"]))
	_place(Layout.LUMBER + Vector2(-25, 0), 90)
	await _until(func(): return WorkersView.inst.count("scierie") >= int(Kingdom.bld("scierie")["ouvriers"]), 30.0)
	_check(WorkersView.inst.count("scierie") == mini(int(Kingdom.bld("scierie")["ouvriers"]), 30), "Au chantier, on voit VRAIMENT chaque bûcheron (%d)" % WorkersView.inst.count("scierie"))
	await _shot("22_bucherons")
	_place(Layout.TOWN + Vector2(0, 20), 0)
	await _wait(0.5)
	WorkersView.inst.gather()
	await _wait(1.0)
	var near_w := 0
	for v in WorkersView.inst._shown["scierie"]:
		if is_instance_valid(v) and v.global_position.distance_to(p.global_position) < 20.0:
			near_w += 1
	_check(near_w == WorkersView.inst.count("scierie"), "Rassemblement : tous les travailleurs alignés devant le souverain")
	await _shot("23_rassemblement")
	WorkersView.inst.dismiss()
	# ---------------------------------------------------------------- vol
	p.set_flying(true)
	p.input_dir = Vector2(0, -1)
	var y0 := p.global_position.y
	await _wait(2.0)
	_check(p.flying and p.global_position.y > y0 + 3.0, "Vol : le souverain s'élève sur son cercle magique (%.1f m)" % (p.global_position.y - y0))
	await _shot("24_vol")
	p.input_dir = Vector2.ZERO
	p.set_flying(false)
	await _wait(1.5)
	# ---------------------------------------------------------------- caravane
	if Vie.inst.caravan and is_instance_valid(Vie.inst.caravan):
		Vie.inst.caravan.queue_free()
		await get_tree().process_frame
	Vie.inst.caravan = null
	Vie.inst._caravan_wait = 0.0
	Vie.inst._caravan_tick(1.0)
	var car: Caravan = Vie.inst.caravan
	_check(car != null, "Une caravane marchande arrive par la grande route")
	car._i = car._pts.size() - 2
	var last: Vector2 = car._pts[car._i]
	car.global_position = Vector3(last.x, Terrain.height_at(last.x, last.y), last.y)
	var tr0 := Kingdom.res("tresor")
	_place(Vector2(last.x + 4, last.y + 6), 200)
	var sold := await _until(func(): return car._state == "vente", 20.0)
	print("   caravane état %s i %d/%d pos %s" % [car._state, car._i, car._pts.size(), car.global_position])
	_check(sold and Kingdom.res("tresor") > tr0, "La caravane vend au bourg : le trésor augmente")
	await _shot("09_caravane")
	# ---------------------------------------------------------------- charrette dans le bon sens
	var cart_m: Node3D = car._cart.get_child(0)
	_check(is_zero_approx(cart_m.rotation.y) and car._merchant.position.z > car._cart.position.z, "Charrette : brancards devant, le marchand la tire (plus à l'envers)")
	# ---------------------------------------------------------------- villages de bandits
	for vg in BanditVillage.VILLAGES.filter(func(x): return String(CampParley._st().get(x, "")) != "rase"):
		_check(BanditVillage.people(vg).size() >= 5, "Village de bandits %s : artisans et habitants (%d)" % [vg, BanditVillage.people(vg).size()])
	var vil_c: Vector2 = CampParley.zone("camp_bandits")["pos"]
	_place(vil_c + (Layout.TOWN - vil_c).normalized() * 30.0, rad_to_deg(atan2(vil_c.x - Layout.TOWN.x, vil_c.y - Layout.TOWN.y)))
	await _wait(2.0)
	await _shot("30_village_bandits")
	var ms_vil := CampParley.members("camp_bandits")
	_check(ms_vil.any(func(m): return m.kind == "chef_bandit") and ms_vil.any(func(m): return m.kind == "garde_elite") and ms_vil.any(func(m): return m.kind == "geant"), "Repaire : chef, garde d'élite et géant")
	for cg in ["rodeurs_ouest", "lanceurs_sud", "brigands_est"]:
		var kinds := []
		for zz in Spawner.ZONES:
			if Spawner.group_of(zz["id"]) == cg:
				kinds.append(zz["kind"])
		_check("chef_bandit" in kinds and ("garde_elite" in kinds or "geant" in kinds), "Camp %s : un chef et son élite" % cg)
	_check(MonsterDB.DEFS.has("goule") and Spawner.by_id("foret_goules") != null and not CampParley.PARLANTS.has("goule"), "Forêts : goules et puglins sauvages, sans pourparlers")
	# ---------------------------------------------------------------- postes de garde des ponts
	_check(Roads.bridges.size() > 0 and Frontier.inst.posts.size() >= Roads.bridges.size() * 2, "Postes de garde sur chaque pont (%d ponts, %d postes)" % [Roads.bridges.size(), Frontier.inst.posts.size()])
	var pont_p: Vector3 = Frontier.inst.posts[0]["pos"]
	_place(Vector2(pont_p.x + 6, pont_p.z + 6), 0)
	await _until(func(): return Frontier.post_guards() > 0, 6.0)
	_check(Frontier.post_guards() > 0, "Les gardes tiennent le pont (%d)" % Frontier.post_guards())
	var intrus := Monster.new()
	intrus.kind = "bandit"
	intrus.no_respawn = true
	intrus.position = pont_p + Vector3(5, 0.5, 0)
	world.add_child(intrus)
	var pont_ok := await _until(func(): return not Combat.alive(intrus) or intrus.cbt.hp < intrus.cbt.max_hp, 15.0)
	_check(pont_ok, "Un bandit approche du pont : la garde l'attaque d'elle-même")
	await _shot("31_garde_pont")
	if is_instance_valid(intrus):
		intrus.queue_free()
	# ---------------------------------------------------------------- embuscade contre une caravane
	if is_instance_valid(car):
		car.queue_free()
	Vie.inst.caravan = null
	Vie.inst._caravan_wait = 0.0
	Vie.inst._caravan_tick(1.0)
	var cara2: Caravan = Vie.inst.caravan
	cara2._i = 4
	var qq4: Vector2 = cara2._pts[4]
	cara2.global_position = Vector3(qq4.x, Terrain.height_at(qq4.x, qq4.y), qq4.y)
	_place(qq4 + Vector2(8, 8), 0)
	await _wait(0.5)
	var emb_ok: bool = Frontier.inst.ambush(true)
	_check(emb_ok and Frontier.raid_active(), "Embuscade : les bandits d'un village frappent la caravane")
	var dis_m: Array = (Frontier.inst.raid["ms"] as Array).filter(func(m): return m.kind == "bandit_deguise")
	_check(dis_m.size() >= 1 and dis_m[0].peaceful, "Des faux voyageurs déguisés approchent sans se trahir")
	_check(world.hud.choice_btns.size() >= 2, "Le souverain choisit : y aller ou envoyer la garde")
	world.hud.choose(1)
	_check(Frontier.inst.raid.get("sent", false), "La garde est envoyée au secours")
	var demasque := await _until(func(): return dis_m.any(func(m): return Combat.alive(m) and not m.peaceful), 25.0)
	for m in (Frontier.inst.raid.get("ms", []) as Array):
		if is_instance_valid(m):
			print("   (pillard %s : état %d, pacifique %s, pv %d, dist marchand %.1f, cible %s)" % [m.kind, m.state, m.peaceful, m.cbt.hp, m.global_position.distance_to(cara2._merchant.global_position), m.force_target])
	print("   (embuscade : en cours %s, caravane %s, marchand %d pv)" % [Frontier.raid_active(), is_instance_valid(cara2), cara2._merchant.cbt.hp])
	_check(demasque, "Le faux voyageur se démasque et attaque")
	var blesse := await _until(func(): return cara2._merchant.cbt.hp < cara2._merchant.cbt.max_hp or not Frontier.raid_active(), 20.0)
	_check(blesse, "Les pillards s'en prennent réellement au marchand")
	await _shot("32_embuscade")
	for m in (Frontier.inst.raid.get("ms", []) as Array):
		if Combat.alive(m):
			m.cbt.take_damage(9999.0, p)
	var fini_emb := await _until(func(): return not Frontier.raid_active(), 5.0)
	_check(fini_emb, "Embuscade terminée (repoussée ou pillage)")
	# ---------------------------------------------------------------- bande errante
	Frontier.quiet = false
	var band_p: Vector2 = Frontier.band_positions()[0]
	_place(band_p + Vector2(10, 10), 0)
	var roam_ok := await _until(func(): return not (Frontier.inst.bands[0]["ms"] as Array).is_empty(), 4.0)
	_check(roam_ok, "Une bande errante circule hors des camps")
	var band_a0: Vector2 = Frontier.inst.bands[0]["at"]
	_place(band_p + Vector2(105, 0), 0)   # assez loin pour qu'elle renonce, assez près pour rester en jeu
	await _wait(4.0)
	print("   (bande : états %s, i %d)" % [(Frontier.inst.bands[0]["ms"] as Array).map(func(m): return m.state if is_instance_valid(m) else -1), int(Frontier.inst.bands[0]["i"])])
	_check((Frontier.inst.bands[0]["at"] as Vector2).distance_to(band_a0) > 2.0, "La bande se déplace d'un repaire à l'autre")
	Frontier.quiet = true
	_place(Layout.TOWN + Vector2(0, 20), 0)
	# ---------------------------------------------------------------- ordre chiffré au contremaître
	Talk._plan = {"scierie": 10, "ferme": 15, "mine": 5, "marche": 0}
	var tot_bras := Kingdom.idle_people()
	for j in ["ferme", "scierie", "mine", "marche"]:
		tot_bras += int(Kingdom.bld(j)["ouvriers"])
	var ordre: Dictionary = Talk._exact()
	_check(ordre["scierie"] == mini(10, tot_bras) and ordre["ferme"] == mini(15, maxi(0, tot_bras - 10)) and ordre["mine"] == mini(5, maxi(0, tot_bras - 25)), "Contremaître : ordre chiffré exécuté à l'homme près (%s)" % str(ordre))
	# ---------------------------------------------------------------- sauvegarde
	gs.save_game()
	var gsv := GameState.new()
	gsv.load_game()
	_check(Array(gsv.flags.get("bannis", [])).size() == Array(gs.flags["bannis"]).size() and gsv.values["crainte"] == gs.values["crainte"], "Sauvegarde : bannis et jauges conservés")
	print("RÉSULTAT : %d réussis, %d échecs" % [ok, ko])
	get_tree().quit()
