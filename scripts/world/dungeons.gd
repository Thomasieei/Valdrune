class_name Dungeons
extends Node
## Donjons qui « poppent » : une faille s'ouvre quelque part dans le royaume (ou chez les nains),
## signalée par un faisceau de lumière géant visible de loin, couleur du rang (E → SS).
## À l'intérieur : salles de pierre éclairées aux torches, monstres en pleine scène de vie
## (autour du feu, attablés, en rituel) qui se réveillent à l'approche, un gardien, un coffre, la sortie.

const RANKS := {
	"E": {"col": Color(0.6, 0.9, 0.6), "kinds": ["puglin", "bandit"], "boss": "chef_bandit", "mult": 1.0, "or": 80},
	"D": {"col": Color(0.4, 0.75, 1.0), "kinds": ["bandit", "lanceur"], "boss": "chef_bandit", "mult": 1.4, "or": 140},
	"C": {"col": Color(0.6, 0.5, 1.0), "kinds": ["mercenaire", "zombie"], "boss": "lieutenant", "mult": 1.9, "or": 220},
	"B": {"col": Color(1.0, 0.85, 0.3), "kinds": ["mercenaire", "lanceur", "zombie"], "boss": "colosse", "mult": 2.5, "or": 350},
	"A": {"col": Color(1.0, 0.5, 0.2), "kinds": ["imp", "imp_brute", "mercenaire"], "boss": "colosse", "mult": 3.3, "or": 520},
	"S": {"col": Color(1.0, 0.25, 0.25), "kinds": ["imp_brute", "mercenaire", "lieutenant"], "boss": "colosse", "mult": 4.5, "or": 800},
	"SS": {"col": Color(0.95, 0.3, 1.0), "kinds": ["imp_brute", "lieutenant", "colosse"], "boss": "colosse", "mult": 6.0, "or": 1300},
}
const SPOTS := [Vector2(-95, 60), Vector2(120, 100), Vector2(-150, -80), Vector2(200, -40), Vector2(60, 170), Vector2(-40, 190), Vector2(150, -190), Vector2(-200, 120)]
const B := Vector3(3000, 300, 0)     # intérieur des donjons : loin et au-dessus de tout relief
static var inst: Dungeons
static var _list: Array = []         # {rank, pos3, beam, zone, nom}
static var inside: Dictionary = {}   # donjon en cours
var _timer := 25.0
var _root: Node3D = null
var _scenes: Array = []
var _boss: Node3D = null
var _env_saved := {}
var cleared := 0

const NOMS := ["Crypte des Oubliés", "Fosse aux Ossements", "Antre du Fléau", "Caveau Écarlate", "Gouffre des Murmures", "Tanière du Roi-Puglin", "Catacombes de Valmont", "Abîme de Cendre"]

func _ready() -> void:
	inst = self

static func active() -> Array:
	return _list

func _process(delta: float) -> void:
	if not inside.is_empty():
		_inside_tick()
		return
	_timer -= delta
	if _timer <= 0.0:
		_timer = randf_range(300.0, 480.0)
		if _list.size() < 3:
			spawn()
		if _list.size() < 2:
			spawn()

## Une faille s'ouvre : faisceau géant + portail au sol
func spawn(rank := "") -> Dictionary:
	var free: Array = SPOTS.filter(func(s): return not _list.any(func(d): return (d["pos2"] as Vector2).distance_to(s) < 5.0))
	if free.is_empty():
		return {}
	var p2: Vector2 = free[randi() % free.size()]
	if rank == "":
		var lv := Progression.get_inst().level
		var pool := ["E", "E", "D", "D", "C"]
		if lv >= 8: pool += ["C", "B"]
		if lv >= 14: pool += ["B", "A"]
		if lv >= 20: pool += ["A", "S"]
		if lv >= 28: pool += ["S", "SS"]
		rank = pool[randi() % pool.size()]
	var col: Color = RANKS[rank]["col"]
	var y := Terrain.height_at(p2.x, p2.y)
	var pos3 := Vector3(p2.x, y, p2.y)
	var node := Node3D.new()
	node.name = "Faille_" + rank
	get_parent().add_child(node)
	node.global_position = pos3
	# faisceau géant (deux cylindres additifs) visible de toute la carte
	for k in 2:
		var c := MeshInstance3D.new()
		var cm := CylinderMesh.new()
		cm.top_radius = 1.6 if k == 0 else 0.6
		cm.bottom_radius = 2.2 if k == 0 else 0.8
		cm.height = 160.0
		cm.radial_segments = 16
		cm.cap_top = false
		cm.cap_bottom = false
		c.mesh = cm
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.albedo_color = Color(col.r, col.g, col.b, 0.35 if k == 0 else 0.8)
		m.disable_fog = true
		c.material_override = m
		c.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		c.position = Vector3(0, 80.0, 0)
		node.add_child(c)
	var rune := Magic.rune(pos3 + Vector3.UP * 0.05, 3.2, col, 99999.0, 0.4)
	rune.reparent(node)
	var lbl := Label3D.new()
	var nom: String = NOMS[randi() % NOMS.size()]
	lbl.text = "%s\nDonjon de rang %s" % [nom, rank]
	lbl.font_size = 64
	lbl.outline_size = 12
	lbl.pixel_size = 0.012
	lbl.modulate = col.lightened(0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 6.0, 0)
	node.add_child(lbl)
	var zone := Area3D.new()
	zone.collision_mask = 8   # couche du joueur
	var cs := CollisionShape3D.new()
	var sh := CylinderShape3D.new()
	sh.radius = 2.2
	sh.height = 3.0
	cs.shape = sh
	zone.add_child(cs)
	zone.position = Vector3(0, 1.5, 0)
	node.add_child(zone)
	var d := {"rank": rank, "pos2": p2, "pos3": pos3, "node": node, "nom": nom}
	zone.body_entered.connect(func(b):
		if b == Combat.player and inside.is_empty() and not Dialogue.active:
			enter(d))
	_list.append(d)
	if Hud.inst:
		Hud.inst.discover("Une faille s'ouvre !", "%s — rang %s (suivez le faisceau)" % [nom, rank])
	Sfx.play("lourd", 0.0)
	return d

# ------------------------------------------------------------------ intérieur
func _fade(cb: Callable) -> void:
	var cl := CanvasLayer.new()
	cl.layer = 20
	get_parent().add_child(cl)
	var r := ColorRect.new()
	r.color = Color(0.05, 0.02, 0.08, 0.0)
	r.set_anchors_preset(Control.PRESET_FULL_RECT)
	r.mouse_filter = Control.MOUSE_FILTER_IGNORE
	cl.add_child(r)
	var tw := cl.create_tween()
	tw.tween_property(r, "color:a", 1.0, 0.4)
	tw.tween_callback(cb)
	tw.tween_interval(0.25)
	tw.tween_property(r, "color:a", 0.0, 0.6)
	tw.tween_callback(cl.queue_free)

func enter(d: Dictionary) -> void:
	inside = d
	_fade(func():
		_build(d)
		var p := Combat.player
		p.global_position = B + Vector3(0, 0.5, 4.0)
		p.velocity = Vector3.ZERO
		p.rotation.y = PI
		var w := get_parent()
		if w.get("rig"):
			w.rig.yaw = 0.0
			w.rig.inside = true
		if Combat.companion and is_instance_valid(Combat.companion) and Combat.companion.visible:
			Combat.companion.teleport(B + Vector3(1.5, 0.5, 5.0))
		var i := 0
		for s in Escort.members:
			if is_instance_valid(s):
				i += 1
				s.global_position = B + Vector3(-1.5 * i, 0.5, 6.0)
		_env(true)
		if Hud.inst:
			Hud.inst.discover(d["nom"], "Donjon de rang %s — trouvez le gardien" % d["rank"]))

func leave(won: bool) -> void:
	var d := inside
	_fade(func():
		inside = {}
		var p := Combat.player
		var q: Vector3 = d["pos3"] + Vector3(0, 0.4, 4.0)
		p.global_position = q
		p.velocity = Vector3.ZERO
		var w := get_parent()
		if w.get("rig"):
			w.rig.inside = false
		if Combat.companion and is_instance_valid(Combat.companion) and Combat.companion.visible:
			Combat.companion.teleport(q + Vector3(1.5, 0.3, 1.0))
		for s in Escort.members:
			if is_instance_valid(s):
				s.global_position = q + Vector3(-1.5, 0.3, 1.5)
		_env(false)
		if is_instance_valid(_root):
			_root.queue_free()
		_root = null
		_scenes.clear()
		if won:
			cleared += 1
			_list.erase(d)
			if is_instance_valid(d["node"]):
				d["node"].queue_free())

func _env(on: bool) -> void:
	var w := get_parent()
	var we := w.find_children("*", "WorldEnvironment", true, false)
	var sun := w.find_child("Soleil", false, false) as DirectionalLight3D
	if we.is_empty():
		return
	var env: Environment = we[0].environment
	if on:
		_env_saved = {"ae": env.ambient_light_energy, "se": sun.light_energy if sun else 1.0, "fog": env.fog_enabled}
		env.ambient_light_energy = 0.35
		env.fog_enabled = false
		if sun:
			sun.light_energy = 0.05
	elif not _env_saved.is_empty():
		env.ambient_light_energy = _env_saved["ae"]
		env.fog_enabled = _env_saved["fog"]
		if sun:
			sun.light_energy = _env_saved["se"]

## Cinq salles en enfilade : entrée, deux salles de vie, antichambre, salle du gardien
func _build(d: Dictionary) -> void:
	_root = Node3D.new()
	_root.name = "DonjonInterieur_" + String(d["rank"])
	get_parent().add_child(_root)
	var g := Geo.new()
	var col: Color = RANKS[d["rank"]]["col"]
	var rooms := [Vector3(0, 0, 0), Vector3(0, 0, -22), Vector3(14, 0, -44), Vector3(0, 0, -66), Vector3(0, 0, -92)]
	var sizes := [Vector2(10, 10), Vector2(16, 14), Vector2(14, 14), Vector2(12, 12), Vector2(22, 20)]
	for i in rooms.size():
		var c: Vector3 = B + rooms[i]
		var sz: Vector2 = sizes[i]
		g.box("dallage", c + Vector3(0, -0.25, 0), Vector3(sz.x, 0.5, sz.y), 0.0, true)
		g.box("pierre_base", c + Vector3(0, 6.2, 0), Vector3(sz.x + 1.0, 0.6, sz.y + 1.0), 0.0, false)
		for s in [-1.0, 1.0]:
			g.box("pierre", c + Vector3(s * (sz.x * 0.5 + 0.4), 3.0, 0), Vector3(0.8, 6.0, sz.y + 0.8), 0.0, true)
			# piliers
			for k in 2:
				g.box("pierre_base", c + Vector3(s * (sz.x * 0.5 - 1.0), 3.0, -sz.y * 0.25 + k * sz.y * 0.5), Vector3(1.0, 6.0, 1.0), 0.0, true)
		# murs avant / arrière avec une ouverture centrale de 3 m
		for wz in [-1.0, 1.0]:
			if (i == 0 and wz > 0) or (i == rooms.size() - 1 and wz < 0):
				g.box("pierre", c + Vector3(0, 3.0, wz * (sz.y * 0.5 + 0.4)), Vector3(sz.x + 1.6, 6.0, 0.8), 0.0, true)
			else:
				var side := (sz.x - 3.0) * 0.5
				for sx in [-1.0, 1.0]:
					g.box("pierre", c + Vector3(sx * (1.5 + side * 0.5), 3.0, wz * (sz.y * 0.5 + 0.4)), Vector3(side + 0.8, 6.0, 0.8), 0.0, true)
				g.box("pierre", c + Vector3(0, 5.0, wz * (sz.y * 0.5 + 0.4)), Vector3(3.2, 2.0, 0.8), 0.0, true)
	# couloirs entre les salles
	for i in rooms.size() - 1:
		var a: Vector3 = B + rooms[i] - Vector3(0, 0, sizes[i].y * 0.5 + 0.8)
		var b: Vector3 = B + rooms[i + 1] + Vector3(0, 0, sizes[i + 1].y * 0.5 + 0.8)
		var seg := b - a
		var mid := (a + b) * 0.5
		var L := seg.length()
		var rot := atan2(seg.x, seg.z)
		g.box("dallage", mid + Vector3(0, -0.25, 0), Vector3(3.2, 0.5, L + 1.0), rot, true)
		g.box("pierre_base", mid + Vector3(0, 4.2, 0), Vector3(4.2, 0.5, L + 1.0), rot, false)
		var bas := Basis(Vector3.UP, rot)
		for s in [-1.0, 1.0]:
			g.box("pierre", mid + bas * Vector3(s * 2.0, 2.0, 0), Vector3(0.8, 4.0, L + 1.0), rot, true)
	g.commit(_root, "Salles")
	# lumière : torches murales + 3 vraies lumières colorées
	for i in rooms.size():
		var c2: Vector3 = B + rooms[i]
		var sz2: Vector2 = sizes[i]
		for s in [-1.0, 1.0]:
			Kit.dungeon(_root, "Torch_Wall", c2 + Vector3(s * (sz2.x * 0.5 - 0.05), 3.2, 0), -s * PI * 0.5, 1.3)
			var f := FX.particles("fire_01", 6, 0.5, [Color(1, 0.8, 0.4, 0.9), Color(1, 0.3, 0.1, 0)], 0.35, false)
			f.direction = Vector3.UP
			f.gravity = Vector3.ZERO
			f.initial_velocity_min = 0.3
			f.initial_velocity_max = 0.6
			_root.add_child(f)
			f.global_position = c2 + Vector3(s * (sz2.x * 0.5 - 0.45), 3.75, 0)
			f.emitting = true
		if i % 2 == 0:
			var l := OmniLight3D.new()
			l.light_color = Color(1.0, 0.65, 0.35) if i < 4 else col
			l.light_energy = 2.2
			l.omni_range = 16.0
			l.position = c2 + Vector3(0, 4.5, 0)
			_root.add_child(l)
	# décor des scènes : feux de camp, tables, ossements
	var fire_c: Vector3 = B + rooms[1]
	Kit.dungeon(_root, "Firewood", fire_c, 0.0, 1.4)
	var ff := FX.particles("fire_01", 14, 0.7, [Color(1, 0.85, 0.45, 0.95), Color(1, 0.35, 0.1, 0)], 0.9, false)
	ff.direction = Vector3.UP
	ff.gravity = Vector3.ZERO
	ff.initial_velocity_min = 0.5
	ff.initial_velocity_max = 1.2
	_root.add_child(ff)
	ff.global_position = fire_c + Vector3(0, 0.3, 0)
	ff.emitting = true
	Kit.dungeon(_root, "Table_Big", B + rooms[2], 0.0, 1.0)
	for k in 6:
		Kit.dungeon(_root, ["Skull", "Bone", "Barrel_Big", "Chest", "Bone", "Candlestick_Triple"][k], B + rooms[k % 4 + 1] + Vector3(randf_range(-4, 4), 0, randf_range(-4, 4)), randf() * TAU, 1.0)
	# habitants du donjon : scènes de vie qui se réveillent à l'approche
	var R: Dictionary = RANKS[d["rank"]]
	var kinds: Array = R["kinds"]
	_scenes.clear()
	_scene(B + rooms[1], kinds, 4, "feu", float(R["mult"]))
	_scene(B + rooms[2], kinds, 3, "table", float(R["mult"]))
	_scene(B + rooms[3], kinds, 3, "garde", float(R["mult"]))
	# le gardien et son trésor
	_boss = _monster(String(R["boss"]), B + rooms[4] + Vector3(0, 0, -4), float(R["mult"]) * 1.6)
	_boss.peaceful = true
	_scenes.append({"c": B + rooms[4], "m": [_boss], "awake": false, "boss": true})
	var chest := Kit.dungeon(_root, "Chest", B + rooms[4] + Vector3(0, 0, -8.5), 0.0, 1.6)
	chest.set_meta("ouvert", false)
	var beam := Magic.rune(B + rooms[4] + Vector3(0, 0.05, -8.5), 1.6, col, 99999.0, 1.0)
	beam.reparent(_root)
	_root.set_meta("coffre", chest)

func _monster(kind: String, at: Vector3, mult: float) -> Node3D:
	var m := Monster.new()
	m.kind = kind
	m.no_respawn = true
	m.position = at + Vector3(0, 0.3, 0)
	_root.add_child(m)
	m.cbt.max_hp *= mult
	m.cbt.hp = m.cbt.max_hp
	m.leash = 40.0
	return m

func _scene(c: Vector3, kinds: Array, n: int, kind: String, mult: float) -> void:
	var ms: Array = []
	for i in n:
		var a := TAU * i / n + 0.4
		var r := 2.4 if kind == "feu" else (1.6 if kind == "table" else 3.0)
		var at := c + Vector3(cos(a) * r, 0, sin(a) * r)
		var m := _monster(kinds[i % kinds.size()], at, mult)
		m.peaceful = true
		m.look_at(Vector3(c.x, m.global_position.y, c.z), Vector3.UP)
		m.rotate_y(PI)
		if kind != "garde" and m._ap.has_animation("Sitting_Idle"):
			m._ap.play("Sitting_Idle")
		ms.append(m)
	_scenes.append({"c": c, "m": ms, "awake": false, "boss": false, "kind": kind})

const CHAT := {
	"feu": ["…et là, le chevalier a pleuré comme un veau !", "Passe-moi la viande.", "Tu entends ? Non… rien.", "Le chef dit qu'on bouge à l'aube."],
	"table": ["Encore une partie de dés ?", "Triche encore et je te coupe la main.", "J'ai faim. On a faim."],
	"garde": ["Rien à signaler.", "Je déteste ce couloir.", "Tu crois qu'il reviendra, le souverain ?"],
}
var _chat_t := 0.0

func _inside_tick() -> void:
	var p := Combat.player
	if p == null or _root == null:
		return
	_chat_t -= get_process_delta_time()
	for sc in _scenes:
		var ms: Array = (sc["m"] as Array).filter(func(m): return Combat.alive(m))
		sc["m"] = ms
		if not sc["awake"]:
			if ms.size() > 0 and p.global_position.distance_to(sc["c"]) < (12.0 if sc["boss"] else 9.0):
				sc["awake"] = true
				for m in ms:
					m.peaceful = false
					m._aggro()
				if sc["boss"]:
					FX.bark(ms[0], ["Qui ose troubler mon repos ?!", "Tu n'aurais jamais dû venir ici.", "Enfin un adversaire digne !"][randi() % 3], 3.2, 3.0)
					var w := get_parent()
					if w.get("rig"):
						w.rig.shake(0.4)
				else:
					FX.bark(ms[0], ["Intrus !", "Aux armes !", "C'est lui ! Le souverain !"][randi() % 3], 2.4, 2.0)
			elif _chat_t <= 0.0 and ms.size() > 0 and not sc["boss"] and p.global_position.distance_to(sc["c"]) < 22.0:
				_chat_t = 4.0
				var lines: Array = CHAT.get(sc.get("kind", "feu"), CHAT["feu"])
				FX.bark(ms[randi() % ms.size()], lines[randi() % lines.size()], 2.3, 2.6)
	# gardien vaincu : le coffre s'ouvre, puis la sortie
	if _boss != null and not Combat.alive(_boss):
		_boss = null
		var chest: Node3D = _root.get_meta("coffre")
		var R: Dictionary = RANKS[inside["rank"]]
		var gold := int(R["or"]) + randi() % 60
		Progression.get_inst().add_gold(gold)
		Progression.get_inst().add_xp(int(gold * 0.8))
		Progression.get_inst().potions_soin += 2
		Magic.pillar(chest.global_position, R["col"], 10.0, 1.2, 4.0)
		Magic.halo(chest.global_position + Vector3.UP, 4.0, R["col"], 0.8)
		Sfx.play("niveau", 0.0)
		if Hud.inst:
			Hud.inst.discover("Gardien vaincu !", "Coffre : +%d or, +%d XP, 2 potions — la faille se referme" % [gold, int(gold * 0.8)])
		GameState.get_inst().report("Donjon « %s » (rang %s) nettoyé : %d or." % [inside["nom"], inside["rank"], gold], "acte")
		get_tree().create_timer(5.0).timeout.connect(func(): leave(true))
	if p.global_position.y < B.y - 8.0:
		p.global_position = B + Vector3(0, 0.5, 4.0)   # filet de sécurité
	if p.cbt.dead:
		leave(false)
