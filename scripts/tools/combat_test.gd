extends Node
## Test de combat automatisé dans le vrai monde : vérifie dégâts, sorts, contrôle, mort, butin, XP, niveau,
## interruption et verrouillage des sorts. Écrit un rapport et des captures dans shots/.

var world
var log_lines: Array = []
var ok := 0
var ko := 0

func _check(cond: bool, label: String) -> void:
	if cond:
		ok += 1
		log_lines.append("OK   " + label)
	else:
		ko += 1
		log_lines.append("ÉCHEC " + label)
	print(log_lines[-1])

func _until(f: Callable, tmax: float) -> bool:
	var t := 0.0
	while not f.call() and t < tmax:
		await get_tree().create_timer(0.1, true, false, true).timeout
		t += 0.1
	return f.call()

func _wait(t: float) -> void:
	await get_tree().create_timer(t).timeout

func _shot(name: String) -> void:
	await get_tree().process_frame
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/combat_%s.png" % name)
	var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
	var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	print("SHOT combat_", name, " triangles=", prims, " draws=", draws, " monstres=", Combat.monsters.size())

func _place(p: Player, xz: Vector2, yaw_deg: float) -> void:
	p.global_position = Vector3(xz.x, Terrain.height_at(xz.x, xz.y) + 0.3, xz.y)
	p.velocity = Vector3.ZERO
	world.rig.yaw = deg_to_rad(yaw_deg)
	world.rig.pitch = deg_to_rad(-22)
	world.rig.dist_goal = 8.0
	world.rig.dist = 8.0
	world.rig._focus = p.global_position + Vector3.UP * 1.45
	world.rig._last_manual = Time.get_ticks_msec() / 1000.0 + 1000.0

func _nearest(p: Player) -> Node3D:
	var best: Node3D = null
	for m in Combat.monsters:
		if Combat.alive(m) and (best == null or m.global_position.distance_to(p.global_position) < best.global_position.distance_to(p.global_position)):
			best = m
	return best

func _face(p: Player, m: Node3D) -> void:
	var d := m.global_position - p.global_position
	p.rotation.y = atan2(d.x, d.z)
	world.rig.yaw = p.rotation.y + PI

func _ready() -> void:
	AuraGuard.enabled = false   # parade de l'aura testée à part (pouvoirs)
	while world.player == null:
		await get_tree().process_frame
	var p: Player = world.player
	var pc := p.combat
	var prog := Progression.get_inst()
	prog.reset()
	p.cbt.max_hp = prog.max_hp()
	p.cbt.hp = p.cbt.max_hp
	pc.mana = prog.max_mana()
	# 1) verrou de niveau : Égide (niv 2) refusée au niveau 1
	pc.cast("egide")
	_check(not p.cbt.has_shield(), "Égide refusée au niveau 1 (sort verrouillé)")
	# 2) aller au repaire des puglins
	_place(p, Vector2(-25, 86), 180.0)
	await _wait(2.0)
	_check(Combat.monsters.size() >= 3, "Le repaire fait apparaître ses puglins (%d)" % Combat.monsters.size())
	var m := _nearest(p)
	_check(m != null, "Un monstre est à proximité")
	if m == null:
		_finish()
		return
	_face(p, m)
	p.global_position = m.global_position - (m.global_position - p.global_position).normalized() * 9.0
	await _wait(0.5)
	# 3) Trait de feu
	var hp0: float = m.cbt.hp
	pc.target = m
	pc.cast("trait_feu")
	await _wait(0.15)
	await _shot("1_trait_de_feu")
	await _wait(1.0)
	_check(m.cbt.hp < hp0 or m.cbt.dead, "Trait de feu inflige des dégâts (%d → %d)" % [hp0, m.cbt.hp])
	_check(m.state != Monster.S.ERRANCE, "Le monstre touché passe à l'attaque (état %d)" % m.state)
	# 4) Combo à l'épée jusqu'à la mort
	prog.add_xp(0)
	var xp0 := prog.xp
	var lvl0 := prog.level
	var gold0 := prog.gold
	var swings := 0
	while Combat.alive(m) and swings < 40:
		p.global_position = m.global_position - (m.global_position - p.global_position).normalized() * 1.6
		p.global_position.y = Terrain.height_at(p.global_position.x, p.global_position.z) + 0.1
		_face(p, m)
		pc.attack()
		swings += 1
		await _wait(0.25)
		if swings == 3:
			await _shot("2_combo_epee")
	_check(m.cbt.dead, "Le puglin meurt sous les coups (%d coups)" % swings)
	_check(prog.xp > xp0 or prog.level > lvl0, "Expérience gagnée")
	await _wait(1.8)
	await _shot("3_butin")
	# ramasser le butin
	for l in FX.root.get_children():
		if l is Loot:
			p.global_position = l.global_position
			await _wait(0.4)
	await _wait(0.6)
	_check(prog.gold > gold0, "Or ramassé automatiquement (%d → %d)" % [gold0, prog.gold])
	# 5) montée de niveau
	prog.add_xp(prog.xp_to_next())
	await _wait(0.4)
	_check(prog.level >= 2, "Montée de niveau (niv %d)" % prog.level)
	await _shot("4_niveau")
	prog.add_xp(prog.xp_to_next() * 3)
	_check(prog.level >= 4, "Niveau 4 atteint : tous les sorts débloqués")
	pc.mana = prog.max_mana()
	# 6) Égide
	pc.cast("egide")
	await _wait(0.3)
	_check(p.cbt.has_shield(), "Égide active (absorbe %d)" % p.cbt.shield)
	await _shot("5_egide")
	# 7) Nova de givre sur un groupe
	var group := Combat.in_radius(p.global_position, 30.0)
	for g in group:
		g._aggro()
	await _wait(2.5)
	var near := Combat.in_radius(p.global_position, 6.0)
	pc.mana = prog.max_mana()
	pc.cast("nova_givre")
	await _wait(0.7)
	await _shot("6_nova_givre")
	var slowed := 0
	for g in near:
		if is_instance_valid(g) and (g.cbt.speed_mult() < 1.0 or g.cbt.dead):
			slowed += 1
	_check(near.is_empty() or slowed > 0, "Nova de givre ralentit les ennemis proches (%d/%d)" % [slowed, near.size()])
	# 8) Racines
	var r := _nearest(p)
	if r:
		pc.target = r
		pc.mana = prog.max_mana()
		r.global_position = p.global_position + p.forward() * 5.0
		pc.cast("racines")
		await _wait(0.5)
		_check(r.cbt.is_rooted() or r.cbt.dead, "Racines immobilisent la cible")
		await _shot("7_racines")
	# 9) Nova de givre : lancement instantané, même sous les coups (plus d'incantation interrompue)
	p.cbt.shield = 0.0
	var hpp: float = p.cbt.hp
	pc.mana = prog.max_mana()
	pc.cooldowns.erase("nova_givre")
	var s0: int = pc.stats["sorts"]
	p.cbt.take_damage(10, null)
	pc.cast("nova_givre")
	await _wait(0.3)
	_check(p.cbt.hp < hpp, "Le joueur subit des dégâts")
	_check(pc.stats["sorts"] == s0 + 1 and pc._cast_spell == "", "Nova lancée instantanément malgré le coup reçu")
	# 9b) Annulation : aucun mana dépensé, pas de recharge
	pc.cooldowns.clear()
	pc.mana = prog.max_mana()
	var mana0: float = pc.mana
	_check(pc.begin_charge("nova_givre"), "Maintenir le bouton commence la charge")
	await _wait(0.4)
	pc.cancel_charge()
	_check(absf(pc.mana - mana0) < 2.0 and pc.cooldown_left("nova_givre") == 0.0 and pc.charging == "", "Annuler : ni mana dépensé ni recharge")
	# 9c) Sort chargé à fond + visée + peur
	for g in Combat.monsters:
		if Combat.alive(g):
			g.global_position = p.global_position + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3))
			g._aggro()
	pc.mana = prog.max_mana()
	pc.begin_charge("trait_feu")
	pc.set_aim(Vector2(0, -1))
	await get_tree().create_timer(1.6, true, false, true).timeout
	_check(pc.charge_level() >= 0.95, "Charge complète après 1,1 s (%.2f)" % pc.charge_level())
	await _shot("6b_charge_visee")
	var sc0: int = pc.stats.get("sorts_charges", 0)
	pc.release_charge()
	await _wait(0.1)
	_check(int(pc.stats.get("sorts_charges", 0)) == sc0 + 1, "Trait de feu chargé à fond lancé")
	var feared := 0
	for g in Combat.monsters:
		if Combat.alive(g) and g.state == Monster.S.FUITE:
			feared += 1
	print("   (ennemis effrayés : %d / %d)" % [feared, Combat.monsters.size()])
	await _wait(0.4)
	await _shot("6c_impact_charge")
	# 9d) Nova lancée 8 fois de suite : pas de gel, joueur jamais bloqué
	var worst := 0.0
	for k in 8:
		pc.cooldowns.clear()
		pc.mana = prog.max_mana()
		pc.begin_charge("nova_givre")
		await _wait(0.2)
		var t0 := Time.get_ticks_usec()
		pc.release_charge()
		worst = maxf(worst, (Time.get_ticks_usec() - t0) / 1000.0)
		await _wait(0.5)
	print("   (pire coût processeur d'un lancement de nova : %.1f ms)" % worst)
	_check(not pc.busy() and pc.charging == "", "Après 8 novas, le joueur n'est pas bloqué")
	pc.cooldowns["nova_givre"] = pc.now() + 4.0
	await _wait(0.2)
	await _shot("6d_recharge_bouton")
	# 10) Brute élite + diablotins près du portail (scène de combat chargée)
	_place(p, Vector2(30, 200), 30.0)
	await _wait(2.5)
	for g in Combat.in_radius(p.global_position, 60.0):
		g._aggro()
	await _wait(2.0)
	pc.mana = prog.max_mana()
	var t2 := _nearest(p)
	if t2:
		_face(p, t2)
		pc.target = t2
		pc.cast("trait_feu")
		await _wait(0.2)
	await _shot("8_melee_portail")
	var n_portail := Combat.monsters.filter(func(g): return Combat.alive(g)).size()
	# peur : nova chargée à fond au milieu des diablotins
	for g in Combat.monsters:
		if Combat.alive(g):
			g.global_position = p.global_position + Vector3(randf_range(-3, 3), 0.3, randf_range(-3, 3))
	pc.cooldowns.clear()
	pc.mana = prog.max_mana()
	pc.begin_charge("nova_givre")
	await _until(func(): return pc.charge_level() >= 1.0, 6.0)
	pc.release_charge()
	await _wait(0.3)
	var fe := 0
	var tot := 0
	for g in Combat.monsters:
		if Combat.alive(g):
			tot += 1
			if g.state == Monster.S.FUITE:
				fe += 1
	await _shot("9_peur")
	_check(fe > 0, "Démonstration de puissance : %d ennemi(s) sur %d prennent la fuite" % [fe, tot])
	_check(n_portail >= 3, "Diablotins et brute présents au portail (%d)" % n_portail)
	_finish()

func _finish() -> void:
	log_lines.append("RÉSULTAT : %d réussis, %d échecs" % [ok, ko])
	print(log_lines[-1])
	var f := FileAccess.open("res://shots/combat_rapport.txt", FileAccess.WRITE)
	f.store_string("\n".join(log_lines))
	Progression.get_inst().reset()
	Progression.get_inst().save_if_dirty()
	get_tree().quit()
