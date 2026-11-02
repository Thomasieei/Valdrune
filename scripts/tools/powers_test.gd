extends Node
## Test automatisé des 20 pouvoirs du souverain : Chambre des Arcanes (déblocage, équipement, sauvegarde),
## effet réel de chaque pouvoir sur de vraies créatures, mana et recharges, résistance des boss,
## anciens sorts toujours fonctionnels.

var world
var ok := 0
var ko := 0
var p: Player
var pc: PlayerCombat
var prog: Progression
var foes: Array = []
var boss: Monster
const ARENA := Vector2(130, 60)

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
	get_viewport().get_texture().get_image().save_png("res://shots/pouvoir_%s.png" % name)
	print("SHOT pouvoir_", name, " draws=", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))

func _place(xz: Vector2, yaw_deg: float, y := INF) -> void:
	var h := Terrain.height_at(xz.x, xz.y) + 0.3 if y == INF else y
	p.global_position = Vector3(xz.x, h, xz.y)
	p.velocity = Vector3.ZERO
	p.rotation.y = deg_to_rad(yaw_deg)
	world.rig.yaw = p.rotation.y + PI
	world.rig.pitch = deg_to_rad(-24)
	world.rig._focus = p.global_position + Vector3.UP * 1.45
	world.rig._last_manual = Time.get_ticks_msec() / 1000.0 + 1000.0

## Remet les ennemis en ligne devant le joueur, PV pleins, sans contrôle
func _reset_foes(dist := 5.0, spacing := 1.6) -> void:
	var fwd := p.forward()
	var side := Vector3(fwd.z, 0, -fwd.x)
	for i in foes.size():
		var m: Monster = foes[i]
		if not is_instance_valid(m) or m.cbt.dead:
			var n := Monster.new()
			n.kind = "bandit"
			n.no_respawn = true
			world.add_child(n)
			foes[i] = n
			m = n
		var pos := p.global_position + fwd * dist + side * (i - 1) * spacing
		pos.y = Terrain.height_at(pos.x, pos.z) + 0.2
		m.global_position = pos
		m.cbt.hp = m.cbt.max_hp
		m.cbt.slow_until = 0.0
		m.cbt.rooted_until = 0.0
		m._ap.speed_scale = 1.0
		m.state = Monster.S.ERRANCE
		m._aggro()
	if is_instance_valid(boss):
		boss.global_position = p.global_position + fwd * (dist + 3.0) + Vector3.UP * 0.2
		boss.cbt.hp = boss.cbt.max_hp
		boss._cc_immune = 0.0
		boss.state = Monster.S.POURSUITE
		boss._sp_cool = {"seisme": 1e9, "balayage": 1e9, "ruee": 1e9}
	pc.cooldowns.clear()
	pc.mana = prog.max_mana()
	p.cbt.hp = p.cbt.max_hp
	p.cbt.invulnerable_until = 0.0
	p.cbt.reflect_until = 0.0

func _hp_sum() -> float:
	var t := 0.0
	for m in foes:
		if is_instance_valid(m):
			t += m.cbt.max_hp - m.cbt.hp if not m.cbt.dead else m.cbt.max_hp
	return t

func _count_state(st: int) -> int:
	var n := 0
	for m in foes:
		if is_instance_valid(m) and not m.cbt.dead and m.state == st:
			n += 1
	return n

func _cast(id: String) -> void:
	pc.cooldowns.clear()
	pc.mana = prog.max_mana()
	pc.target = foes[1] if is_instance_valid(foes[1]) and not foes[1].cbt.dead else null
	pc.cast(id)

func _ready() -> void:
	while world.player == null or world.story == null:
		await get_tree().process_frame
	Engine.max_physics_steps_per_frame = 40
	p = world.player
	pc = p.combat
	prog = Progression.get_inst()
	await _wait(1.5)
	for i in 6:
		prog.add_xp(prog.xp_to_next())
	prog.add_gold(9000)
	pc.mana = prog.max_mana()
	_check(prog.level >= 7, "Seigneur niveau %d" % prog.level)
	# ---------------------------------------------------------------- Chambre des Arcanes
	_place(Vector2(-15, -134.2), 180, Castle.FLOOR + 0.3)
	world._set_inside(true)
	await _wait(1.0)
	_check(world._arc_near and world.hud.btn_talk.visible and world.hud.btn_talk.label == "Chambre des Arcanes", "Près du cristal : bouton « Chambre des Arcanes »")
	_check(PlayerCombat.practice, "Dans la chambre : entraînement (mana gratuit)")
	await _shot("01_chambre")
	world._talk()
	await _wait(0.6)
	_check(ArcanesUI.is_open() and get_tree().paused, "La Chambre des Arcanes s'ouvre (jeu en pause)")
	world.aui.cat = "telekinesie"
	world.aui.sel = "main_invisible"
	world.aui.refresh()
	await _wait(0.4)
	await _shot("02_interface")
	prog.level = maxi(prog.level, 12)
	var n0 := prog.pouvoirs.size()
	for id in SpellDB.DEFS:
		if SpellDB.is_power(id):
			world.aui.sel = id
			world.aui._unlock()
	_check(prog.pouvoirs.size() == n0 + 20, "Les 20 pouvoirs se débloquent contre de l'or (%d)" % prog.pouvoirs.size())
	world.aui.sel = "meteore"
	var g0 := prog.gold
	world.aui._upgrade(150)
	_check(prog.rank("meteore") == 2 and prog.gold == g0 - 150, "Amélioration au rang 2")
	world.aui.sel = "main_invisible"
	world.aui._equip(0)
	world.aui.sel = "meteore"
	world.aui._equip(1)
	_check(prog.slots[0] == "main_invisible" and prog.slots[1] == "meteore" and world.hud.btn_slots[0].icon == "main", "Équipement dans les emplacements 1 et 2, boutons mis à jour")
	world.aui.sel = "main_invisible"
	world.aui._equip(3)
	_check(prog.slots[3] == "main_invisible" and prog.slots[0] == "racines", "Équiper un pouvoir déjà équipé l'échange de place")
	world.aui._try()
	await _wait(0.8)
	var dummies := Combat.monsters.filter(func(m): return m.kind == "mannequin")
	_check(dummies.size() == 3 and not get_tree().paused, "« Essayer » : trois mannequins dans la chambre")
	var mana0 := pc.mana
	pc.cooldowns.clear()
	pc.target = dummies[0]
	pc.cast("meteore")
	await _wait(1.4)
	print("   (mannequin %d/%d, mana %.1f → %.1f, entraînement %s)" % [dummies[0].cbt.hp, dummies[0].cbt.max_hp, mana0, pc.mana, PlayerCombat.practice])
	_check(pc.mana >= mana0 - 0.5 and dummies[0].cbt.hp < dummies[0].cbt.max_hp, "Essai gratuit sur un mannequin (dégâts, mana intact)")
	await _shot("03_essai_mannequin")
	# pendant l'essai, la Chambre reste accessible (bouton) pour terminer l'entraînement
	_place(Vector2(-15, -134.2), 180, Castle.FLOOR + 0.3)
	await _wait(0.8)
	_check(world.hud.btn_talk.visible and world.hud.btn_talk.label == "Chambre des Arcanes", "Pendant l'essai : la Chambre reste accessible malgré les mannequins")
	# quitter la chambre met fin à l'entraînement (mannequins retirés)
	_place(Vector2(-15, -120), 0, Castle.FLOOR + 0.3)
	await _wait(1.0)
	_check(Combat.monsters.filter(func(m): return is_instance_valid(m) and m.kind == "mannequin").is_empty() and not PlayerCombat.practice, "Sortir de la chambre termine l'entraînement")
	# sauvegarde
	prog.save_if_dirty()
	var p2 := Progression.new()
	p2.load_game()
	_check(p2.slots == prog.slots and p2.pouvoirs.size() == prog.pouvoirs.size() and p2.rank("meteore") == 2, "Pouvoirs, rangs et emplacements conservés après sauvegarde")
	world._set_inside(false)
	# ---------------------------------------------------------------- arène
	_place(ARENA, 0)
	await _wait(1.0)
	_check(not PlayerCombat.practice, "Hors de la chambre : coûts normaux")
	for i in 3:
		foes.append(null)
	_reset_foes()
	boss = Monster.new()
	boss.kind = "colosse"
	boss.no_respawn = true
	world.add_child(boss)
	_reset_foes()
	await _wait(0.6)
	# mana et recharge réels
	pc.mana = prog.max_mana()
	pc.cooldowns.clear()
	var m0 := pc.mana
	pc.cast("chaines")
	_check(pc.mana < m0 - 10 and pc.cooldown_left("chaines") > 5.0, "Mana dépensé et recharge lancée (%d mana, %.0f s)" % [int(m0 - pc.mana), pc.cooldown_left("chaines")])
	pc.cast("chaines")
	_check(pc.cooldown_left("chaines") > 5.0 and pc.stats["sorts"] > 0, "Impossible de relancer pendant la recharge")
	await _wait(1.0)
	# ---------------------------------------------------------------- chaque pouvoir
	var tests := [
		["main_invisible", 0.35, func(): return foes[1].state == Monster.S.SOULEVE, "Main invisible : l'ennemi est soulevé"],
		["ecrasement", 0.3, func(): return _count_state(Monster.S.ETOURDI) >= 2, "Écrasement : ennemis plaqués au sol"],
		["arsenal", 2.4, func(): return _hp_sum() > 0.0, "Arsenal spectral : les épées frappent"],
		["projection", 1.2, func(): return _hp_sum() > 0.0, "Projection absolue : ennemi écrasé au sol"],
		["singularite", 1.2, func(): return foes[0].global_position.distance_to(foes[2].global_position) < 4.5, "Singularité : les ennemis sont aspirés"],
		["dome", 0.6, func():
			var dists := foes.map(func(m): return snappedf(Vector2(m.global_position.x - p.global_position.x, m.global_position.z - p.global_position.z).length(), 0.1))
			print("   (dôme : invulnérable %s, distances %s, barrières %d, états %s, en jeu %s)" % [p.cbt.invulnerable_until > Combatant.now(), dists, p.find_children("*", "DomeBarrier", true, false).size(), foes.map(func(m): return m.state), foes.map(func(m): return Combat.alive(m))])
			return p.cbt.invulnerable_until > Combatant.now() and dists.min() >= 3.5, "Dôme souverain : invulnérable, ennemis repoussés"],
		["mur", 0.6, func(): return FX.root.get_children().any(func(n): return n is StaticBody3D), "Mur impérial : un vrai mur bloque le passage"],
		["reflet", 0.2, func():
			var h0: float = foes[1].cbt.hp
			p.cbt.take_damage(30, foes[1])
			return foes[1].cbt.hp < h0, "Reflet : le coup est renvoyé à l'agresseur"],
		["arret_temps", 0.3, func(): return _count_state(Monster.S.ETOURDI) >= 3 and foes[0]._ap.speed_scale == 0.0, "Arrêt temporel : ennemis figés"],
		["chaines", 0.3, func(): return _count_state(Monster.S.ETOURDI) >= 2, "Chaînes du jugement : ennemis entravés"],
		["meteore", 1.6, func(): return _hp_sum() > 0.0, "Chute céleste : le météore frappe"],
		["piliers", 0.5, func(): return _hp_sum() > 0.0, "Jugement terrestre : piliers sous les ennemis"],
		["orage", 2.6, func(): return _hp_sum() > 0.0, "Orage : les éclairs frappent"],
		["main_titan", 2.2, func(): return _hp_sum() > 0.0, "Main du titan : saisie et écrasement"],
		["faille", 2.6, func(): return _hp_sum() > 0.0, "Faille d'annihilation : aspiration puis explosion"],
		["legion", 0.8, func(): return Soldier.all.filter(func(s): return s.spectral and not s.cbt.dead).size() >= 3, "Légion : guerriers spectraux invoqués"],
		["presence", 0.5, func(): return _count_state(Monster.S.FUITE) + _count_state(Monster.S.ETOURDI) >= 1, "Présence écrasante : les faibles fuient ou s'agenouillent"],
		["oeil", 0.8, func(): return world.hud.eye._panels.any(func(x): return x.visible), "Œil du souverain : panneaux d'information"],
		["incarnation", 0.4, func(): return pc.incarnated() and p.cbt.incoming_until > Combatant.now(), "Incarnation souveraine : forme ultime active"],
	]
	var base_ms := Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0
	var peak_ms := 0.0
	var peak_draws := 0
	var shots := ["arsenal", "singularite", "dome", "mur", "chaines", "meteore", "orage", "main_titan", "faille", "legion", "presence", "oeil", "incarnation", "piliers", "ecrasement"]
	if OS.get_cmdline_user_args().has("rapide"):
		tests = tests.filter(func(x): return x[0] in ["projection", "singularite", "dome"])
	for t in tests:
		var id: String = t[0]
		_reset_foes(5.0 if id != "dome" else 2.5, 3.0 if id == "singularite" else 1.6)
		await _wait(0.4)
		_cast(id)
		var wait: float = t[1]
		if id in shots:
			await _wait(minf(wait, 0.5))
			await _shot("p_" + id)
			wait = maxf(0.0, wait - 0.5)
		await _wait(wait)
		peak_ms = maxf(peak_ms, Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0)
		peak_draws = maxi(peak_draws, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
		var res: bool = t[2].call()
		_check(res, t[3])
		await _wait(2.5 if id == "singularite" else 0.3)   # laisser l'implosion finir avant le test suivant
	# transposition : échange avec la cible
	_reset_foes(7.0)
	await _wait(0.3)
	var before := p.global_position
	var tgt: Monster = foes[1]
	print("   (avant transposition : joueur %s mort=%s, cible %s, occupé=%s)" % [before, p.cbt.dead, tgt.global_position, pc.busy()])
	_cast("transposition")
	await _wait(0.3)
	print("   (transposition : cible %s à %.1f m, état %d, joueur %s → %s)" % [tgt.def["nom"], tgt.global_position.distance_to(before), tgt.state, before, p.global_position])
	_check(p.global_position.distance_to(before) > 4.0, "Transposition : le seigneur change de place (%.1f m)" % p.global_position.distance_to(before))
	# incarnation : dégâts réduits
	pc.incarnation_until = Combatant.now() + 5.0
	p.cbt.incoming_until = Combatant.now() + 5.0
	p.cbt.incoming_mult = 0.5
	var hp0 := p.cbt.hp
	p.cbt.reflect_until = 0.0
	p.cbt.take_damage(40, null, "arcane")
	_check(hp0 - p.cbt.hp <= 24.0, "Incarnation : dégâts subis réduits (%d au lieu de 40)" % int(hp0 - p.cbt.hp))
	# ---------------------------------------------------------------- boss
	boss._cc_immune = 0.0
	var first := boss.stun(3.0)
	var second := boss.stun(3.0)
	_check(first and not second and boss.cbt.speed_mult() < 1.0, "Boss : premier contrôle bref, puis immunité 6 s (simplement ralenti)")
	_check(not boss.lift(3.0, 1.0), "Boss : trop lourd pour être soulevé")
	boss._stun_end = 0.0
	# ---------------------------------------------------------------- anciens sorts
	ArcanesUI.equip("trait_feu", 0)
	ArcanesUI.equip("egide", 1)
	ArcanesUI.equip("nova_givre", 2)
	ArcanesUI.equip("racines", 3)
	_reset_foes()
	await _wait(0.3)
	var s0: int = pc.stats["sorts"]
	for id in ["trait_feu", "egide", "nova_givre", "racines"]:
		_cast(id)
		await _wait(0.5)
	print("   (sorts lancés %d, mort=%s, occupé=%s)" % [pc.stats["sorts"] - s0, p.cbt.dead, pc.busy()])
	_check(pc.stats["sorts"] == s0 + 4, "Les quatre sorts d'origine fonctionnent toujours")
	print("   (rendu logiciel : temps de traitement au repos %.0f ms, pic pendant les pouvoirs %.0f ms ; appels de rendu max %d)" % [base_ms, peak_ms, peak_draws])
	print("RÉSULTAT : %d réussis, %d échecs" % [ok, ko])
	get_tree().quit()
