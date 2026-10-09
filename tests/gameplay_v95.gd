extends Node

var m: Node3D
var checks: Array = []
var failed := 0

func check(ok: bool, name: String) -> void:
	checks.append({"name": name, "passed": ok})
	if not ok: failed += 1; push_error("FAIL: " + name)
	print("PASS: " if ok else "FAIL: ", name)

func _ready() -> void:
	run.call_deferred()

func capture(name: String) -> void:
	if DisplayServer.get_name() == "headless": return
	m.update_goal(); m._context(0.0); m._update_moods(0.1)
	m.hud.update(0.01)
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	img.save_png("res://tests/artifacts/" + name + ".png")

func freeze_enemies() -> void:
	for e in m.enemies:
		if is_instance_valid(e): e.set_physics_process(false); e.set_process(false)

func clear_enemies() -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e): e.queue_free()
	m.enemies.clear(); m.selected_enemy = null

func run() -> void:
	Game.S = Game.default_state(); Game.stats_dirty()
	m = load("res://main.tscn").instantiate(); get_tree().root.add_child(m); get_tree().current_scene = m
	m.set_process(false); m.player.set_physics_process(false)
	m.hud.close_panel()
	if m.hud.title: m.hud.title.visible = false
	freeze_enemies()
	check(m.net == null, "Vérification isolée des services en ligne")
	check(m.hud.buttons.has("target"), "Bouton de ciblage disponible sur mobile")
	check(m.world.nodes.size() > 0 and m.npcs.size() > 0, "Carte et ressources du jeu chargées")

	# A held attack may never become an entry action without another press.
	m.hud.set_main("attack", "ATTAQUE", Hud.GOLD)
	m.hud.buttons.main.held = true; m.hud.keyboard_main_mode = "attack"
	m.hud.set_main("enter", "ENTRER", Hud.GOLD)
	check(not m.hud.buttons.main.held and m.hud.keyboard_main_mode == "", "Un appui d’attaque ne déclenche pas un portail")
	m.auto_hold = true
	check(not m.hud.main_held(), "Le mode AUTO ne peut pas entrer seul dans un portail")
	m.auto_hold = false

	clear_enemies()
	var origin: Vector3 = m.camp_spawn
	m._teleport_group(origin)
	var camp := {"members": []}
	var near: Enemy = m._spawn_enemy("minion", 1, origin + Vector3(2, 0, 0), camp, false)
	var chosen: Enemy = m._spawn_enemy("loup", 1, origin + Vector3(-4, 0, -2), camp, false)
	freeze_enemies(); m.select_enemy(chosen)
	check(m.combat_target(m.player.global_position, 15.0) == chosen, "La cible choisie prime sur le monstre le plus proche")
	check(m.combat_target(m.player.global_position, 1.0) == null, "Une cible hors de portée n’est pas remplacée silencieusement")
	check(m.target_ring.visible, "Anneau de sélection visible")
	check(chosen.ch.root.scale.x > float(Enemy.KINDS.loup.scale) * 1.4, "Loup visuellement agrandi")
	check(chosen.radius > float(Enemy.KINDS.loup.rad) and chosen.body_h > float(Enemy.KINDS.loup.h), "Corps et barre de vie adaptés à l’animal agrandi")
	check(float(chosen.def.wind) >= 0.85 and float(chosen.def.cd) >= 2.0, "Attaques ennemies annoncées et espacées")
	var screen: Vector2 = m.cam.unproject_position(chosen.global_position + Vector3(0, chosen.body_h * 0.7, 0))
	m.select_enemy(null)
	check(m.try_pick_enemy(screen) and m.selected_enemy == chosen, "Un toucher sur l’animal le sélectionne")
	m._context(0.0)
	check(m.hud.main_mode == "attack", "Une cible verrouillée garde la priorité sur les entrées et PNJ")
	await capture("ciblage_v95")

	Game.S.weapon_kind = "epee"; Game.S.gear.epee = 5; Game.stats_dirty()
	m.player.reset_actions(false); m.player.attack(near)
	check(m.player.swing_cd >= 0.8, "Attaque de base ralentit le rythme du combat")
	m._teleport_group(origin)
	await get_tree().create_timer(0.3).timeout
	check(near.hp == near.max_hp, "Un coup différé est annulé lors d’un changement de zone")
	Game.S.weapon_kind = "baton"; Game.stats_dirty(); m.player.skill_cd = [0.0, 0.0, 0.0, 0.0]
	m.player.reset_actions(false); m.player.use_skill(0); m.player.use_skill(1)
	check(m.player.skill_cd[0] >= 5.4 and m.player.skill_cd[1] == 0.0, "Recharge des sorts allongée et rafale de sorts empêchée")
	m._teleport_group(origin)
	await get_tree().physics_frame
	await get_tree().process_frame
	var projectile_left := false
	for n in m.get_children():
		if n is Player.Shot or n is Player.Fireball: projectile_left = true
	check(not projectile_left, "Les projectiles disparaissent au changement de zone")
	m.player.dodge_cd = 0.0; m.player.dodge()
	check(m.player.dodge_cd == Player.DODGE_COOLDOWN, "L’esquive conserve une vraie recharge")

	# Old movement tweens must not pull the character into the previous scene.
	Game.S.weapon_kind = "hache"; Game.stats_dirty(); m.select_enemy(near)
	m.player.leap(); var destination := origin + Vector3(5, 0, 0)
	m._teleport_group(destination); var after_tp: Vector3 = m.player.global_position
	await get_tree().create_timer(0.55).timeout
	check(m.player.global_position.distance_to(after_tp) < 0.01, "Un ancien bond ne ramène pas le héros après un TP")

	# A terrain-height mismatch is insufficient; an actual fall must last long enough.
	m.transition_grace = 0.0
	var h: float = m.world.ground_y(origin.x, origin.z)
	m.player.global_position = Vector3(origin.x, h - 1.5, origin.z); m.player.velocity.y = -10.0
	var before: Vector3 = m.player.global_position
	for i in 10: m._unstick(m.player, 0.1)
	check(m.player.global_position == before, "Une petite différence de hauteur ne provoque aucun TP")
	m.player.global_position.y = h - 6.0; m.player.velocity.y = -20.0
	for i in 7: m._unstick(m.player, 0.1)
	check(m.player.global_position.y < h - 5.0, "Une chute brève n’est pas corrigée prématurément")
	m._unstick(m.player, 0.1)
	check(m.player.global_position.y > h and m.player.global_position.x == origin.x, "Une chute persistante est corrigée verticalement sur le sol proche")
	m.player.global_position = Vector3(-46, -2, 8); before = m.player.global_position
	for i in 20: m.player._block_water(0.1)
	check(m.player.global_position == before, "La berge n’est plus atteinte par un saut automatique")
	m._teleport_group(origin)

	# Invocations reset at dungeon, arena, and tower boundaries, including between floors.
	Game.S.weapon_kind = "dompteur"; Game.stats_dirty()
	Game.add_pet("loup", 0)
	m.player.skill_cd = [0.0, 0.0, 0.0, 0.0]; m.player.use_skill(0)
	check(m.pets.size() == 1 and m.player.skill_cd[0] == Game.PET_CD, "Invocation de familier fonctionnelle avant la transition")
	var portal := Node3D.new(); m.add_child(portal)
	var entry := {"tier": 1, "seed": 12345, "pos": origin, "node": portal}
	m.enter_dungeon(entry); freeze_enemies()
	check(m.pets.is_empty() and m.player.skill_cd[0] == 0.0, "Dompteur réinitialisé à l’entrée du donjon")
	var dg: Dungeon = m.dungeon
	check(dg.modifier in Dungeon.MODIFIERS and dg.rooms.size() >= 7, "Donjon complet avec une variante de défi")
	check(dg.boss.def.get("dungeon_boss", false) and dg.boss.max_hp >= Game.mob_hp(1) * 22.0, "Gardien plus résistant et doté de phases")
	m._teleport_group(dg.boss.global_position + Vector3(0, 0, 7))
	m.select_enemy(dg.boss); dg.boss.state = "windup"; dg.boss.t_state = 0.0
	await capture("gardien_v95")
	dg.boss.state = "idle"; m._teleport_group(dg.spawn_pos)
	var first: Dictionary = dg.rooms[1].camp
	var front: Enemy = first.members[0]; front.aggro()
	check(first.members.all(func(e): return e.state == "chase") and dg.boss.state == "idle", "Chaque salle réagit avec son propre groupe")
	dg.boss.hp = dg.boss.max_hp * 0.49; dg.boss._physics_process(0.0)
	check(dg.boss.enraged, "Le gardien change de tactique à mi-vie")
	var old_count: int = dg.sp_dict.members.size(); m.boss_summon(dg.boss); freeze_enemies()
	check(dg.sp_dict.members.size() == old_count + 3 and dg.boss.camp.members.all(func(e): return e.tier == 1), "Renforts du gardien au bon tier et comptés dans le nettoyage")
	m.open_dungeon_chest()
	check(not dg.chest_open, "Le trésor reste scellé tant qu’il reste des ennemis")
	for e in dg.sp_dict.members: e.dead = true
	m.open_dungeon_chest()
	check(dg.chest_open, "Le trésor se libère après nettoyage du donjon")
	m.hud.close_panel(); m.exit_dungeon(false); m._teleport_group(origin)
	m._arena_open("ranked"); m.player.skill_cd[0] = 60.0
	m.summon_pet(0); m.exit_arena()
	check(m.pets.is_empty() and m.player.skill_cd[0] == 0.0, "Invocations réinitialisées à la sortie de l’arène")
	m.player.skill_cd[0] = 60.0; m.enter_tower(1); freeze_enemies()
	check(m.player.skill_cd[0] == 0.0, "Invocations disponibles à l’entrée de la tour")
	m.player.skill_cd[0] = 60.0; m.summon_pet(0); m.enter_tower(2); freeze_enemies()
	check(m.pets.is_empty() and m.player.skill_cd[0] == 0.0, "Invocations réinitialisées entre deux étages")
	m._do_exit_tower(false); m._teleport_group(origin)

	# Quest markers have different availability and reward states and cannot overlap service names.
	var smith: Npc
	for n in m.npcs:
		if n.act == "forge": smith = n; break
	check(smith != null, "PNJ de quête présent")
	if smith:
		Game.S.vq = {}; m.mood_t = 0.0; m._update_moods(0.1)
		check(smith.get_meta("qmark").text == "!", "Point d’exclamation pour une quête disponible")
		m.vq.accept("forge"); m.vq.event("kill_loup", 5); m.mood_t = 0.0; m._update_moods(0.1)
		check(smith.get_meta("qmark").text == "?", "Point d’interrogation quand la récompense est prête")
		check(smith.get_meta("qmark").position.y > smith.marker.position.y + 0.8, "Le marqueur ne se superpose plus au nom du service")

	var spans: Array = m.world._forest_clear_spans()
	var clear := true; var trees := 0
	for nd in m.world.nodes:
		if nd.type != "wood": continue
		trees += 1
		for span in spans:
			if World.seg_dist(Vector2(nd.pos.x, nd.pos.z), span[0], span[1]) < float(span[2]): clear = false
	check(spans.size() > 0 and trees > 0 and clear, "Arbres récoltables dégagés des chemins et services de la carte 1")

	# A stale respawn callback cannot teleport someone who already returned to camp.
	m.player.dead = true; m.on_player_death(); m.teleport_camp()
	m._teleport_group(origin + Vector3(5, 0, 0)); after_tp = m.player.global_position
	await get_tree().create_timer(2.8).timeout
	check(m.player.global_position.distance_to(after_tp) < 0.01, "Une ancienne réapparition ne déclenche plus de TP tardif")
	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var out := FileAccess.open("res://tests/artifacts/gameplay_v95_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks": checks, "failed": failed}, "\t")); out.close()
	print("GAMEPLAY TESTS: ", checks.size() - failed, "/", checks.size())
	m.queue_free(); await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
