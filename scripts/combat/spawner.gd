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

## Repaires du royaume : chaque peuple a son territoire et son récit
const ZONES := [
	{"kind": "puglin", "pos": Vector2(-25, 100), "n": 3, "r": 9, "label": "Pillards puglins (berge ouest)"},
	{"kind": "puglin", "pos": Vector2(150, -115), "n": 4, "r": 11, "label": "Camp puglin (collines de la mine)"},
	{"kind": "zombie", "pos": Vector2(-165, 60), "n": 4, "r": 12, "label": "Bois des Morts errants"},
	{"kind": "zombie", "pos": Vector2(-130, 150), "n": 3, "r": 10, "label": "Clairière maudite"},
	{"kind": "imp", "pos": Vector2(70, 205), "n": 3, "r": 9, "label": "Diablotins du portail"},
	{"kind": "imp_brute", "pos": Vector2(5, 228), "n": 1, "r": 3, "label": "Brute infernale (élite)"},
]

static func build(world: Node3D) -> void:
	spawners.clear()
	for z in ZONES:
		var s := Spawner.new()
		s.kind = z["kind"]
		s.count = z["n"]
		s.radius = z["r"]
		s.label = z["label"]
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
	if p == null:
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
	for i in range(_timers.size() - 1, -1, -1):
		_timers[i] -= dt
		if _timers[i] <= 0.0:
			_timers.remove_at(i)
			_spawn_one()

func _fill(_now: bool) -> void:
	while _alive.size() + _timers.size() < count:
		_spawn_one()

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
		m.rotation.y = randf() * TAU
		_alive.append(m)
		return

func on_monster_died(m: Node) -> void:
	_alive.erase(m)
	_timers.append(respawn)
