extends Node
## Contrôle visuel du « ressenti » des combats : captures au bon instant (arc de taille, ruée,
## coup final, boule de feu chargée, nova) pour juger l'image comme un joueur.
var world
var p: Player
var pc: PlayerCombat
var foes: Array = []

const SLOW := 0.1   # tout le test tourne à 1/10 de la vitesse : chaque effet dure assez d'images pour être vu
func _wait(t: float) -> void:
	await get_tree().create_timer(t / Engine.time_scale, true, false, true).timeout

## Capture « au ralenti » : le rendu logiciel tourne à 1-3 images/s, un effet de 0,25 s n'y serait
## jamais visible ; on fige presque le temps le temps de deux images, comme sur un téléphone à 60 i/s.
## Attente en temps RÉEL (la logique de combat du héros est en temps réel, les effets en temps de jeu)
func _real(t: float) -> void:
	await get_tree().create_timer(t, true, false, true).timeout

func _shot(n: String) -> void:
	await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/fx_%s.png" % n)
	print("SHOT fx_", n)

func _spawn(dist: float) -> void:
	for m in foes:
		if is_instance_valid(m):
			m.queue_free()
	foes.clear()
	for i in 3:
		var m := Monster.new()
		m.kind = "bandit"
		m.no_respawn = true
		world.add_child(m)
		var pos: Vector3 = p.global_position + p.forward() * dist + Vector3(i * 1.4 - 1.4, 0, 0)
		pos.y = Terrain.height_at(pos.x, pos.z) + 0.2
		m.global_position = pos
		m.stun(30.0, true)
		foes.append(m)

func _ready() -> void:
	while world.player == null:
		await get_tree().process_frame
	p = world.player
	pc = p.combat
	Engine.max_physics_steps_per_frame = 40
	AuraGuard.enabled = false
	Progression.get_inst().level = 12
	await _wait(1.5)
	p.global_position = Vector3(12, Terrain.height_at(12, -58) + 0.3, -58)
	p.rotation.y = PI * 0.5
	world.rig.yaw = p.rotation.y + PI
	world.rig.dist_goal = 7.0
	world.rig.pitch = deg_to_rad(-20)
	await _wait(1.0)
	Engine.time_scale = SLOW
	# primitives seules, durée longue : vérifie qu'elles se voient
	var c0: Vector3 = p.global_position + p.forward() * 3.0
	Juice.onde(c0, Color(1.0, 0.7, 0.3), 3.0, 6.0)
	Juice.lueur(c0 + Vector3(2, 0, 0), Color(0.4, 0.8, 1.0), 2.0, 6.0)
	Juice.arc(p.global_position + Vector3.UP, p.rotation.y, 2.6, Color(1, 1, 1, 1), 150.0, 6.0, 0.2)
	await _wait(1.5)
	await _shot("0_primitives")

	await _wait(1.0)
	_spawn(2.2)
	await _wait(0.5)
	pc.attack()
	await _real(1.4)
	await _shot("1_coup")
	await _real(0.3)
	pc.attack()
	await _real(0.75)
	pc.attack()
	await _real(1.6)
	await _shot("2_coup_final")
	await _wait(1.0)
	_spawn(7.0)
	await _wait(0.5)
	pc._combo = 0
	pc._attack_until = 0.0
	pc.attack()
	await _real(0.1)
	await _shot("3_ruee")
	await _real(1.4)
	await _shot("3b_ruee_impact")
	await _wait(1.0)
	_spawn(9.0)
	pc.cooldowns.clear()
	pc.mana = 999
	pc.begin_charge("trait_feu")
	await _real(1.3)
	pc.release_charge()
	await _wait(0.4)
	await _shot("4_boule_chargee")
	await _wait(1.0)
	_spawn(3.0)
	pc.cooldowns.clear()
	pc.cast("nova_givre")
	await _wait(0.08)
	await _shot("5_nova")
	print("FIN fx")
	get_tree().quit()
