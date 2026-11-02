class_name WorldEvents
extends Node
## Événements du monde : embuscades sur les routes, pillards, morts qui se relèvent…
## Un groupe surgit à distance du joueur (hors du bourg), signalé à l'écran ; vaincu, il rapporte une prime.

const KINDS := [
	{"kinds": ["bandit", "bandit", "lanceur"], "titre": "Embuscade !", "sub": "Des bandits surgissent sur la route", "or": 45},
	{"kinds": ["puglin", "puglin", "puglin", "puglin"], "titre": "Pillards puglins", "sub": "Une bande puglin rôde tout près", "or": 35},
	{"kinds": ["zombie", "zombie", "zombie"], "titre": "Les morts se relèvent", "sub": "Des morts errants sortent de terre", "or": 40},
	{"kinds": ["mercenaire", "bandit"], "titre": "Hommes de Vargas", "sub": "Des mercenaires de Vargas vous traquent", "or": 70},
]
var _t := 120.0
var count := 0
static var force_next := false

func _ready() -> void:
	# modes de test automatisés : pas d'événement aléatoire (les tests les déclenchent eux-mêmes)
	for a in OS.get_cmdline_user_args():
		if String(a).begins_with("--"):
			set_process(false)

func _process(delta: float) -> void:
	_t -= delta
	if _t > 0.0 and not force_next:
		return
	_t = randf_range(150.0, 240.0)
	var p := Combat.player
	if p == null or Spawner.paused or not Story.done():
		return
	if not force_next and (Vector2(p.global_position.x, p.global_position.z).distance_to(Layout.TOWN) < 60.0 or Layout.in_castle(Vector2(p.global_position.x, p.global_position.z), 10.0)):
		return
	force_next = false
	trigger(p.global_position, -p.global_basis.z)

func trigger(at: Vector3, fwd: Vector3) -> Spawner:
	var e: Dictionary = KINDS[randi() % KINDS.size()]
	for attempt in 16:
		var a := atan2(fwd.x, fwd.z) + randf_range(-0.9, 0.9)
		var d := randf_range(22.0, 32.0)
		var q := Vector2(at.x + sin(a) * d, at.z + cos(a) * d)
		var h := Terrain.height_at(q.x, q.y)
		if h < Layout.WATER + 0.6 or Layout.in_castle(q, 8.0) or q.distance_to(Layout.TOWN) < 45.0 or absf(q.x) > Layout.HALF - 20 or absf(q.y) > Layout.HALF - 20:
			continue
		count += 1
		var root := Node3D.new()
		root.name = "Evenement_%d" % count
		get_parent().add_child(root)
		root.position = Vector3(q.x, h, q.y)
		var last: Spawner = null
		var kinds: Array = e["kinds"]
		var groups := {}
		for k in kinds:
			groups[k] = int(groups.get(k, 0)) + 1
		var left := [groups.size()]
		for k in groups:
			var s := Spawner.new()
			s.kind = k
			s.count = groups[k]
			s.radius = 5.0
			s.one_shot = true
			s.respawn = 1e9
			s.zone_id = "evt_%d" % count
			s.label = e["titre"]
			root.add_child(s)
			s.cleared.connect(func():
				left[0] -= 1
				if left[0] <= 0:
					_done(e, root))
			last = s
		var w := get_parent()
		if w.get("hud"):
			w.hud.discover(e["titre"], e["sub"])
		return last
	return null

func _done(e: Dictionary, root: Node3D) -> void:
	Progression.get_inst().add_gold(int(e["or"]))
	GameState.get_inst().add("reputation", 1)
	GameState.get_inst().report("%s — menace repoussée. Le royaume vous en sait gré (+%d or)." % [e["titre"], e["or"]], "acte")
	var w := get_parent()
	if w.get("hud"):
		w.hud.discover("Menace repoussée", "+%d or" % e["or"])
	get_tree().create_timer(6.0).timeout.connect(func():
		if is_instance_valid(root):
			root.queue_free())
