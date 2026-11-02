class_name Escort
## Garde rapprochée du seigneur : des soldats bien réels qui le suivent, ouvrent la marche ou gardent un lieu.
## On peut prendre un garde à son poste (en lui parlant) ou appeler des renforts depuis le château.
## La composition est sauvegardée : la garde revient avec le joueur au prochain lancement.

const MAX := 4
const GATE := Vector3(0, 12.2, -80)
static var members: Array = []

static func world() -> Node3D:
	return (Engine.get_main_loop() as SceneTree).current_scene

static func available() -> int:
	# on garde toujours deux hommes à la garnison
	var sold := int(Kingdom.res("soldats")) if Kingdom.inst else 6
	return clampi(sold - 2 - members.size(), 0, MAX - members.size())

static func _slot() -> int:
	var used := []
	for s in members:
		used.append(s.slot)
	for i in MAX:
		if not used.has(i):
			return i
	return 0

## Un garde décoratif quitte son poste et rejoint l'escorte
static func take_guard(g: Node3D) -> Soldier:
	if available() <= 0:
		return null
	var s := Soldier.new()
	var t: Dictionary = g.get_meta("talk", {})
	s.nom = String(t.get("nom", "Soldat"))
	s.home = g.global_position
	s.source_guard = g
	s.slot = _slot()
	world().add_child(s)
	s.global_position = g.global_position + Vector3.UP * 0.2
	s.rotation.y = g.rotation.y
	g.visible = false
	g.process_mode = Node.PROCESS_MODE_DISABLED
	g.remove_from_group("pnj")
	s.mode = Soldier.M.ESCORTE
	members.append(s)
	s.say("À vos ordres !", 2.0)
	_save()
	return s

## Renforts depuis la porte du château (noms donnés pour la restauration d'une sauvegarde)
static func call_guards(n: int, names: Array = []) -> int:
	var made := 0
	var pool: Array = Kingdom.data()["pnj"]["noms_h"]
	for i in n:
		if available() <= 0:
			break
		var s := Soldier.new()
		s.nom = names[i] if i < names.size() else pool[randi() % pool.size()]
		s.home = GATE
		s.slot = _slot()
		world().add_child(s)
		var p := Combat.player
		var spawn := GATE + Vector3(i * 1.2, 0, 0)
		# si le joueur est loin du château, les renforts arrivent derrière lui (pas de marche de 300 m)
		if p and p.global_position.distance_to(GATE) > 60.0:
			spawn = p.global_position - p.global_transform.basis.z * 14.0 + Vector3(i * 1.5, 0, 0)
		spawn.y = Terrain.height_at(spawn.x, spawn.z) + 0.3
		s.global_position = spawn
		s.mode = Soldier.M.ESCORTE
		members.append(s)
		made += 1
	_save()
	return made

static func dismiss(s: Soldier) -> void:
	if not members.has(s):
		return
	members.erase(s)
	s.say("Je retourne à mon poste.", 2.0)
	s.send_home()
	_save()

static func dismiss_all() -> void:
	for s in members.duplicate():
		dismiss(s)

static func set_mode(s: Soldier, m: int) -> void:
	if m == Soldier.M.GARDER:
		s.go_to(s.global_position, Soldier.M.GARDER)
	else:
		s.mode = m
	_save()

static func forget(s: Soldier) -> void:
	members.erase(s)
	_save()

static func _save() -> void:
	var names := []
	for s in members:
		if is_instance_valid(s):
			names.append(s.nom)
	GameState.get_inst().flags["escorte"] = names
	GameState.get_inst().mark()

## Au chargement : la garde rapprochée sauvegardée rejoint le joueur
static func restore() -> void:
	var names: Array = GameState.get_inst().flags.get("escorte", [])
	members.clear()
	if names.size() > 0:
		call_guards(names.size(), names)

static func mode_name(m: int) -> String:
	return {Soldier.M.ESCORTE: "escorte", Soldier.M.ECLAIREUR: "éclaireur", Soldier.M.GARDER: "garde le lieu", Soldier.M.RETOUR: "retourne au poste"}.get(m, "en service")
