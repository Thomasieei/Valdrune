class_name Spawner
extends Node3D
## Repaire de créatures : maintient une population, réapparitions espacées,
## et ne fait exister les monstres que lorsque le joueur est assez proche (économie de calcul).

var kind := "puglin"
var count := 3
var radius := 8.0
var respawn := 30.0
var activate := 95.0
var label := ""

var _alive: Array = []
var _timers: Array = []
var _active := false
var _acc := 0.0

static var spawners: Array = []
## Suspendus pendant l'introduction (aucun repaire actif tant que l'histoire guide le joueur)
static var paused := false
var zone_id := ""
var liberated := false

## Repaires du royaume : chaque peuple a son territoire et son récit
const ZONES := [
	{"id": "berge_ouest", "kind": "puglin", "pos": Vector2(-25, 100), "n": 3, "r": 9, "label": "Pillards puglins (berge ouest)"},
	{"id": "collines_mine", "kind": "puglin", "pos": Vector2(150, -115), "n": 4, "r": 11, "label": "Camp puglin (collines de la mine)"},
	{"id": "bois_morts", "kind": "zombie", "pos": Vector2(-165, 60), "n": 4, "r": 12, "label": "Bois des Morts errants"},
	{"id": "clairiere_maudite", "kind": "zombie", "pos": Vector2(-130, 150), "n": 3, "r": 10, "label": "Clairière maudite"},
	{"id": "portail_diablotins", "kind": "imp", "pos": Vector2(70, 205), "n": 3, "r": 9, "label": "Diablotins du portail"},
	{"id": "camp_bandits", "kind": "bandit", "pos": Vector2(-60, 140), "n": 5, "r": 8, "label": "Camp de bandits (sud-ouest)"},
	{"id": "camp_bandits_chef", "kind": "chef_bandit", "pos": Vector2(-57, 143), "n": 1, "r": 3, "label": "Chef des bandits (élite)"},
	{"id": "camp_bandits_garde", "kind": "garde_elite", "pos": Vector2(-55, 140), "n": 2, "r": 4, "label": "Garde d'élite du chef"},
	{"id": "brigands_est_garde", "kind": "garde_elite", "pos": Vector2(208, 45), "n": 2, "r": 4, "label": "Garde d'élite des brigands"},
	{"id": "brigands_est_geant", "kind": "geant", "pos": Vector2(215, 36), "n": 1, "r": 3, "label": "Géant des brigands"},
	{"id": "chasseurs_est_geant", "kind": "geant", "pos": Vector2(144, 90), "n": 1, "r": 4, "label": "Géant puglin"},
	{"id": "lanceurs_sud_garde", "kind": "garde_elite", "pos": Vector2(-88, 199), "n": 1, "r": 3, "label": "Garde d'élite"},
	{"id": "rodeurs_ouest", "kind": "bandit", "pos": Vector2(-75, -60), "n": 4, "r": 10, "label": "Rôdeurs des collines ouest"},
	{"id": "deserteur", "kind": "deserteur", "pos": Vector2(90, -80), "n": 1, "r": 14, "label": "Déserteur solitaire (élite)"},
	{"id": "chasseurs_est", "kind": "puglin", "pos": Vector2(140, 85), "n": 4, "r": 11, "label": "Chasseurs puglins (plaine est)"},
	{"id": "brigands_est", "kind": "bandit", "pos": Vector2(210, 40), "n": 4, "r": 9, "label": "Brigands des collines est"},
	{"id": "brigands_est_merc", "kind": "mercenaire", "pos": Vector2(213, 44), "n": 1, "r": 3, "label": "Mercenaire de Vargas"},
	{"id": "lanceurs_sud", "kind": "lanceur", "pos": Vector2(-85, 202), "n": 2, "r": 8, "label": "Lanceurs de la lande sud"},
	{"id": "lanceurs_sud_b", "kind": "bandit", "pos": Vector2(-81, 206), "n": 2, "r": 8, "label": "Coupe-jarrets de la lande sud"},
	{"id": "camp_bandits_geant", "kind": "geant", "pos": Vector2(-64, 136), "n": 1, "r": 3, "label": "Géant du repaire"},
	{"id": "rodeurs_ouest_chef", "kind": "chef_bandit", "pos": Vector2(-72, -57), "n": 1, "r": 3, "label": "Chef des rôdeurs (élite)"},
	{"id": "rodeurs_ouest_garde", "kind": "garde_elite", "pos": Vector2(-70, -61), "n": 2, "r": 4, "label": "Garde d'élite des rôdeurs"},
	{"id": "lanceurs_sud_chef", "kind": "chef_bandit", "pos": Vector2(-84, 198), "n": 1, "r": 3, "label": "Chef de la lande (élite)"},
	{"id": "lanceurs_sud_geant", "kind": "geant", "pos": Vector2(-90, 207), "n": 1, "r": 3, "label": "Géant de la lande"},
	{"id": "brigands_est_chef", "kind": "chef_bandit", "pos": Vector2(208, 38), "n": 1, "r": 3, "label": "Chef des brigands (élite)"},
	{"id": "collines_mine_geant", "kind": "geant", "pos": Vector2(154, -111), "n": 1, "r": 3, "label": "Géant puglin des collines"},
	# bêtes des forêts : sans cervelle, elles attaquent à vue — à détruire
	{"id": "foret_goules", "kind": "goule", "pos": Vector2(-240, -40), "n": 4, "r": 12, "label": "Goules de la forêt profonde"},
	{"id": "foret_sauvages", "kind": "puglin_sauvage", "pos": Vector2(-112, 62), "n": 4, "r": 11, "label": "Puglins sauvages des bois"},
	{"id": "foret_nord", "kind": "goule", "pos": Vector2(-250, 85), "n": 3, "r": 11, "label": "Goules des sous-bois"},
	{"id": "crypte_ouest", "kind": "zombie", "pos": Vector2(-200, 0), "n": 5, "r": 12, "label": "Crypte de l'ouest"},
	{"id": "portail_brute", "kind": "imp_brute", "pos": Vector2(5, 228), "n": 1, "r": 3, "label": "Brute infernale (élite)"},
]

## Un camp = un repaire principal + ses annexes (chef, mercenaire, seconde bande) : même groupe
static func group_of(id: String) -> String:
	for suf in ["_chef", "_merc", "_b", "_garde", "_geant"]:
		if id.ends_with(suf):
			return id.substr(0, id.length() - suf.length())
	return id

## Population totale d'un camp (toutes annexes comprises)
static func group_count(gid: String) -> int:
	var n := 0
	for z in ZONES:
		if group_of(z["id"]) == gid:
			n += int(z["n"])
	return n

static func by_id(id: String) -> Spawner:
	for s in spawners:
		if s.zone_id == id:
			return s
	return null

static func build(world: Node3D) -> void:
	spawners.clear()
	for z in ZONES:
		var s := Spawner.new()
		s.kind = z["kind"]
		s.count = int(z["n"]) + (1 if not MonsterDB.DEFS[z["kind"]].get("elite", false) else 0)
		s.radius = z["r"]
		s.label = z["label"]
		s.zone_id = z["id"]
		if MonsterDB.DEFS[s.kind].get("elite", false):
			s.respawn = 120.0
		var p: Vector2 = z["pos"]
		s.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		world.add_child(s)
		spawners.append(s)

func _process(delta: float) -> void:
	_acc += delta
	if _acc < 0.5:
		return
	var dt := _acc
	_acc = 0.0
	var p := Combat.player
	if p == null or paused or liberated:
		if (paused or liberated) and _active:
			_active = false
			for m in _alive:
				if is_instance_valid(m):
					m.queue_free()
			_alive.clear()
			_timers.clear()
		return
	var d := p.global_position.distance_to(global_position)
	if not _active and d < activate:
		_active = true
		_fill(false)
	elif _active and d > activate + 50.0:
		_active = false
		for m in _alive:
			if is_instance_valid(m):
				m.queue_free()
		_alive.clear()
		_timers.clear()
	if not _active:
		return
	# les occupants parlent quand le seigneur approche
	_bark_t -= dt
	if _bark_t <= 0.0 and d < 30.0 and _alive.size() > 0:
		_bark_t = randf_range(5.0, 9.0)
		var m: Node3D = _alive[randi() % _alive.size()]
		if Combat.alive(m):
			Camps.bark(kind, m)
	for i in range(_timers.size() - 1, -1, -1):
		_timers[i] -= dt
		if _timers[i] <= 0.0:
			_timers.remove_at(i)
			_spawn_one()

## Les occupants arrivent un par un (0,25 s d'écart) : jamais plusieurs personnages construits
## dans la même image — c'était une source de pics de ms à l'approche d'un camp.
func _fill(_now: bool) -> void:
	var k := 0
	while _alive.size() + _timers.size() < count:
		if k == 0:
			_spawn_one()
		else:
			_timers.append(0.25 * k)
		k += 1

func _spawn_one() -> void:
	for attempt in 12:
		var a := randf() * TAU
		var r := randf() * radius
		var x := global_position.x + cos(a) * r
		var z := global_position.z + sin(a) * r
		var h := Terrain.height_at(x, z)
		if h < Layout.WATER + 0.5 or Layout.road_dist(Vector2(x, z)) < 1.0:
			continue
		var m := Monster.new()
		m.kind = kind
		m.spawner = self
		m.leash = radius + 26.0
		m.position = Vector3(x, h + 0.2, z)
		get_parent().add_child(m)
		m.peaceful = CampParley.is_peaceful(zone_id)
		m.rotation.y = randf() * TAU
		_alive.append(m)
		return

var _bark_t := 2.0
var one_shot := false   # groupe d'événement : pas de réapparition, disparaît une fois vaincu
var kills := 0
signal cleared

func on_monster_died(m: Node) -> void:
	_alive.erase(m)
	kills += 1
	Contracts.on_kill(zone_id)
	Quests.on_kill(zone_id)
	if one_shot:
		if _alive.is_empty():
			cleared.emit()
			liberated = true
			queue_free()
		return
	_timers.append(respawn)
