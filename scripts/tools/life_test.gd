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
	while world.player == null or world.story == null:
		await get_tree().process_frame
	p = world.player
	Engine.max_physics_steps_per_frame = 40   # rendu logiciel très lent : la simulation garde le temps réel
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
	var jailed := await _until(func(): return not Justice.prisoner_record(vid).is_empty(), 150.0)
	_check(jailed, "Il est escorté à pied jusqu'à la prison et enfermé")
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
	# ---------------------------------------------------------------- sauvegarde
	gs.save_game()
	var g2 := GameState.new()
	g2.load_game()
	_check(Array(g2.flags.get("bannis", [])).size() == Array(gs.flags["bannis"]).size() and g2.values["crainte"] == gs.values["crainte"], "Sauvegarde : bannis et jauges conservés")
	print("RÉSULTAT : %d réussis, %d échecs" % [ok, ko])
	get_tree().quit()
