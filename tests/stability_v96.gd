extends Node

var m: Node3D
var checks: Array = []
var failed := 0

func _ready() -> void:
	run.call_deferred()

func check(ok: bool, name: String) -> void:
	checks.append({"name": name, "passed": ok})
	if not ok: failed += 1; push_error("FAIL: " + name)
	print("PASS: " if ok else "FAIL: ", name)

func step(frames: int) -> void:
	for i in frames: await get_tree().physics_frame

func save_text(path: String, value: String) -> void:
	var f := FileAccess.open(path, FileAccess.WRITE)
	f.store_string(value); f.close()

func test_saves() -> void:
	var path := "user://qa_save.json"
	for suffix in ["", ".bak", ".tmp", ".bak.tmp"]:
		if FileAccess.file_exists(path + suffix): DirAccess.remove_absolute(path + suffix)
	var original := Game.default_state()
	original.silver = 1234; original.gear.epee = 3; original.inv.wood[2] = 12
	check(Game.write_saved_state(path, original), "Première sauvegarde complète créée")
	var newer: Dictionary = original.duplicate(true); newer.silver = 3456
	check(Game.write_saved_state(path, newer), "Nouvelle progression sauvegardée sans supprimer la précédente")
	var restored: Dictionary = Game.load_saved_state(path)
	check(restored.silver == 3456 and restored.gear.epee == 3 and restored.inv.wood[2] == 12, "Argent, équipement et ressources conservés après relecture")
	save_text(path, "{\"v\":2,\"silver\":")
	restored = Game.load_saved_state(path)
	check(Game.save_recovered and restored.silver == 1234 and restored.gear.epee == 3, "Fichier interrompu : récupération réelle de la copie de secours")
	save_text(path + ".tmp", JSON.stringify(newer))
	restored = Game.load_saved_state(path)
	check(restored.silver == 3456, "Écriture complète interrompue avant remplacement : dernière progression récupérée")
	save_text(path + ".tmp", "{")
	check(Game.load_saved_state(path).silver == 1234, "Une écriture temporaire incomplète ne masque pas la bonne copie")
	check(not Game.write_saved_state("user://missing_qa_dir/save.json", newer), "Une écriture impossible signale l’échec sans annoncer une réussite")
	check(Game.load_saved_state(path).silver == 1234, "Une écriture impossible laisse la progression récupérable")
	var partial := {"v": 2, "silver": 9000, "gear": {"epee": 4}, "inv": {"wood": [0, 7]}, "items": [null, {"slot": "epee", "tier": 3, "nm": "Épée conservée"}]}
	var fixed: Dictionary = Game.normalize_saved_state(partial)
	check(fixed.silver == 9000 and fixed.gear.epee == 4 and fixed.gear.armure == 1, "Ancienne sauvegarde partielle : équipement existant conservé et cases manquantes complétées")
	check(fixed.inv.wood.size() == 6 and fixed.inv.wood[1] == 7 and fixed.inv.ore.size() == 6, "Inventaire partiel complété sans perdre les ressources existantes")
	check(fixed.items.size() == 1 and fixed.items[0].nm == "Épée conservée", "Un élément endommagé ne fait pas perdre les objets valides")

func clear_enemies() -> void:
	for e in m.enemies.duplicate():
		if is_instance_valid(e): e.queue_free()
	m.enemies.clear(); m.select_enemy(null)

func movement_spot() -> Vector3:
	var points: Array[Vector3] = []
	for x in range(-15, 16, 3):
		for z in range(-15, 16, 3): points.append(m.camp_spawn + Vector3(x, 0, z))
	points.sort_custom(func(a, b): return a.distance_squared_to(m.camp_spawn) < b.distance_squared_to(m.camp_spawn))
	for p in points:
		var valid := true
		for k in 9:
			var q: Vector3 = p + Vector3(k, 0, 0)
			if not m.world.walkable(q.x, q.z) or m.world.near_house(Vector2(q.x, q.z), 1.0) or m.world._near_node_grid(q, 1.2): valid = false; break
		if valid: return p
	return m.camp_spawn

func run() -> void:
	test_saves()
	Game.S = Game.default_state(); Game.stats_dirty(); Game.crashed_last = false; Game.save_recovered = false
	m = load("res://main.tscn").instantiate(); get_tree().root.add_child(m); get_tree().current_scene = m
	check(m.net == null, "Scénario sans connexion ni compte créé sur le serveur")
	var play_button: Button
	for b in m.hud.title.find_children("*", "Button", true, false):
		if b.text == "Jouer": play_button = b; break
	check(play_button != null, "Bouton Jouer présent sur l’écran réel de démarrage")
	if play_button: play_button.emit_signal("pressed")
	m.hud._start()
	await step(130)
	check(m.hud.title == null and not m.hud.panel_open, "Démarrage utilisable sans fenêtre automatique bloquant le joystick")
	check(Game.S.tips.has("start"), "Objectif initial et progression de découverte initialisés")

	clear_enemies()
	var spot: Vector3 = movement_spot(); m._teleport_group(spot)
	await step(45)
	check(m.player.is_on_floor(), "Le personnage rejoint réellement le sol après une transition")
	var before: Vector3 = m.player.global_position
	m.hud.joy.vec = Vector2.RIGHT
	await step(45)
	check(m.player.global_position.x > before.x + 2.0, "Joystick : déplacement réel sur la carte avec collisions actives")
	m.hud.buttons.main.held = true; m.hud.keyboard_main_mode = "attack"
	m.hud.touches[0] = "joy"; m.hud.touch_starts[0] = {"pos": Vector2.ZERO, "time": 0, "dragged": false}
	m.hud.pinch[0] = Vector2.ONE
	m.hud.notification(Node.NOTIFICATION_APPLICATION_PAUSED)
	before = m.player.global_position
	await step(30)
	check(Vector2(m.player.global_position.x - before.x, m.player.global_position.z - before.z).length() < 0.2, "Après mise en veille : aucun déplacement dû à un doigt resté bloqué")
	check(not m.hud.buttons.main.held and m.hud.keyboard_main_mode == "" and m.hud.pinch.is_empty() and m.hud.touches.is_empty(), "Après interruption : attaque, clavier, touches et zoom relâchés")
	m.hud.show_menu(); m.hud.notification(Node.NOTIFICATION_WM_GO_BACK_REQUEST)
	check(not m.hud.panel_open and not ProjectSettings.get_setting("application/config/quit_on_go_back"), "Retour Android ferme le menu sans quitter la partie")
	m.hud.joy.vec = Vector2.RIGHT; m.hud.keyboard_main_mode = "attack"
	m.hud.show_menu(); before = m.player.global_position
	await step(30)
	check(m.player.global_position.distance_to(before) < 0.3 and m.hud.keyboard_main_mode == "", "Ouvrir un menu ne conserve aucune commande de déplacement ou d’attaque")
	m.hud.close_panel()
	m.hud.show_menu(); m.player.invuln = 0.0; m.player.hurt(1.0, null)
	check(not m.hud.panel_open, "Un coup reçu referme le menu pour permettre de réagir immédiatement")

	# The player and enemy keep their real physics and combat loops throughout this encounter.
	clear_enemies(); m._teleport_group(spot); await step(20)
	var camp := {"members": []}
	var enemy: Enemy = m._spawn_enemy("minion", 1, spot + Vector3(6, 0, 0), camp, false, {"hp": 15.0})
	m.select_enemy(enemy); await step(2)
	var environmental_hp: float = enemy.hp
	enemy.take_hit(1.0, null, 0.0)
	check(enemy.hp < environmental_hp, "Un dégât sans attaquant valide ne provoque pas d’erreur de combat")
	var start_hp: float = enemy.hp
	m.hud.buttons.main.held = true
	await step(240)
	check(is_instance_valid(enemy) and enemy.hp < start_hp, "Combat réel : approche de la cible puis coups qui touchent")
	check(not m.player.dead and m.player.hp > 0.0, "Combat réel : une cible de premier tier reste jouable avec l’équipement initial")
	check(m.player.swing_cd > 0.0 and m.player.swing_cd < 1.5, "Combat continu : les attaques utilisent la cadence prévue sans se figer")
	m.hud.reset_controls(); m.select_enemy(null)
	clear_enemies(); m._teleport_group(spot); m.player.hp = m.player.max_hp
	var portal := Node3D.new(); m.add_child(portal)
	m.enter_dungeon({"tier": 1, "seed": 54321, "pos": spot, "node": portal})
	await step(90)
	check(m.player.is_on_floor() and not m.player.dead and m.dungeon != null, "Donjon en fonctionnement : apparition sur le sol et entrée sans mort immédiate")
	var dg: Dungeon = m.dungeon
	var at: Vector3 = dg.rooms[1].center
	m._teleport_group(at); await step(240)
	check(not m.player.dead, "Première salle : survie possible le temps de réagir avec le héros initial")
	check(dg.rooms[1].camp.members.any(func(e): return e.state in ["chase", "windup", "recover"]), "Les ennemis du donjon engagent réellement le joueur")
	m.exit_dungeon(false); m._teleport_group(spot); await step(20)
	check(m.player.is_on_floor() and m.dungeon == null, "Retour du donjon : collisions et sol du monde rétablis")

	DirAccess.make_dir_recursive_absolute("res://tests/artifacts")
	var out := FileAccess.open("res://tests/artifacts/stability_v96_results.json", FileAccess.WRITE)
	out.store_string(JSON.stringify({"checks": checks, "failed": failed}, "\t")); out.close()
	print("STABILITY TESTS: ", checks.size() - failed, "/", checks.size())
	m.queue_free(); await get_tree().process_frame
	get_tree().quit(1 if failed else 0)
