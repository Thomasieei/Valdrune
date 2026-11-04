class_name Dungeons
extends Node
## Donjons qui « poppent » : une faille s'ouvre quelque part dans le royaume (ou chez les nains),
## signalée par un faisceau de lumière géant visible de loin, couleur du rang (E → SS).
## À l'intérieur : salles de pierre éclairées aux torches, monstres en pleine scène de vie
## (autour du feu, attablés, en rituel) qui se réveillent à l'approche, un gardien, un coffre, la sortie.

const RANKS := {
	"E": {"col": Color(0.6, 0.9, 0.6), "kinds": ["puglin", "bandit"], "boss": "chef_de_guerre", "mult": 1.0, "or": 80},
	"D": {"col": Color(0.4, 0.75, 1.0), "kinds": ["bandit", "lanceur"], "boss": "chef_de_guerre", "mult": 1.4, "or": 140},
	"C": {"col": Color(0.6, 0.5, 1.0), "kinds": ["mercenaire", "zombie"], "boss": "seigneur_os", "mult": 1.9, "or": 220},
	"B": {"col": Color(1.0, 0.85, 0.3), "kinds": ["mercenaire", "lanceur", "zombie"], "boss": "brute_infernale", "mult": 2.5, "or": 350},
	"A": {"col": Color(1.0, 0.5, 0.2), "kinds": ["imp", "imp_brute", "mercenaire"], "boss": "seigneur_os", "mult": 3.3, "or": 520},
	"S": {"col": Color(1.0, 0.25, 0.25), "kinds": ["imp_brute", "mercenaire", "lieutenant"], "boss": "brute_infernale", "mult": 4.5, "or": 800},
	"SS": {"col": Color(0.95, 0.3, 1.0), "kinds": ["imp_brute", "lieutenant", "colosse"], "boss": "colosse", "mult": 6.0, "or": 1300},
}
const SPOTS := [Vector2(-95, 60), Vector2(120, 100), Vector2(-150, -80), Vector2(200, -40), Vector2(60, 170), Vector2(-40, 190), Vector2(150, -190), Vector2(-200, 120), Vector2(-180, -40), Vector2(100, 200), Vector2(-250, 0), Vector2(230, -120), Vector2(-120, 240), Vector2(0, 140), Vector2(-60, -110), Vector2(250, 60)]
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
	var free: Array = SPOTS.filter(func(s): return not _list.any(func(d): return (d["pos2"] as Vector2).distance_to(s) < 5.0) and _dry(s))
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
		c.visibility_range_begin = 30.0     # de près, le faisceau plein écran coûterait cher : on voit le portail
		c.position = Vector3(0, 80.0, 0)
		node.add_child(c)
	var portal := RiftPortal.new()
	portal.col = col
	portal.scale_k = 0.8
	node.add_child(portal)
	portal.rotation.y = atan2(Layout.TOWN.x - p2.x, Layout.TOWN.y - p2.y)   # le tourbillon fait face au bourg
	var lbl := Label3D.new()
	var nom: String = NOMS[randi() % NOMS.size()]
	lbl.text = "%s\nDonjon de rang %s" % [nom, rank]
	lbl.font_size = 64
	lbl.outline_size = 12
	lbl.pixel_size = 0.012
	lbl.modulate = col.lightened(0.3)
	lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lbl.position = Vector3(0, 9.5, 0)
	lbl.visibility_range_end = 120.0
	node.add_child(lbl)
	var d := {"rank": rank, "pos2": p2, "pos3": pos3, "node": node, "nom": nom}
	portal.entered.connect(func():
		if inside.is_empty() and not Dialogue.active:
			enter(d))
	_list.append(d)
	if Hud.inst:
		Hud.inst.discover("Une faille s'ouvre !", "%s — rang %s (suivez le faisceau)" % [nom, rank])
	Sfx.play("lourd", 0.0)
	return d

## Emplacement sain pour un portail : terre ferme tout autour, loin des camps
static func _dry(q: Vector2) -> bool:
	for k in 8:
		var o := q + Vector2(cos(TAU * k / 8.0), sin(TAU * k / 8.0)) * 7.0
		if Terrain.height_at(o.x, o.y) < Layout.WATER + 0.6:
			return false
	for z in Spawner.ZONES:
		if q.distance_to(z["pos"]) < float(z["r"]) + 22.0:
			return false
	return true

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
		p.global_position = _spawn + Vector3(0, 0.5, 0)
		p.velocity = Vector3.ZERO
		p.rotation.y = PI
		var w := get_parent()
		if w.get("rig"):
			w.rig.yaw = 0.0
			w.rig.inside = true
		if Combat.companion and is_instance_valid(Combat.companion) and Combat.companion.visible:
			Combat.companion.teleport(_spawn + Vector3(1.5, 0.5, 1.0))
		var i := 0
		for s in Escort.members:
			if is_instance_valid(s):
				i += 1
				s.global_position = _spawn + Vector3(-1.5 * i, 0.5, 2.0)
		_env(true)
		if Hud.inst:
			Hud.inst.discover(d["nom"], "Donjon de rang %s — nettoyez les salles, réveillez le gardien, prenez son trésor" % d["rank"]))

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
		_chest = null
		_crack_body = null
		if Hud.inst:
			Hud.inst.objective("")
			Hud.inst.hide_prompt()
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
		_env_saved = {"ae": env.ambient_light_energy, "se": sun.light_energy if sun else 1.0, "fog": env.fog_enabled, "bg": env.background_mode, "bc": env.background_color}
		env.ambient_light_energy = 0.35
		env.fog_enabled = false
		env.background_mode = Environment.BG_COLOR     # sous terre : pas de ciel
		env.background_color = Color(0.02, 0.015, 0.03)
		if sun:
			sun.light_energy = 0.05
	elif not _env_saved.is_empty():
		env.ambient_light_energy = _env_saved["ae"]
		env.fog_enabled = _env_saved["fog"]
		env.background_mode = _env_saved["bg"]
		env.background_color = _env_saved["bc"]
		if sun:
			sun.light_energy = _env_saved["se"]

## Donjon complet (plan de Brèche Écarlate) : départ, quatre salles de vie, gardien sur son estrade, crypte cachée
var _spawn := B
var _gen: DungeonGen
var _chest: Node3D = null
var _chest_state := ""          # "scelle" → "pret" → "ouvert"
var _crack_body: StaticBody3D = null
var _secret_chest: Node3D = null
var _exit: RiftPortal = null
var _boss_phase := 0
var _safe := Vector3.ZERO

func _build(d: Dictionary) -> void:
	_root = Node3D.new()
	_root.name = "DonjonInterieur_" + String(d["rank"])
	get_parent().add_child(_root)
	var R: Dictionary = RANKS[d["rank"]]
	var col: Color = R["col"]
	_gen = DungeonGen.new()
	_gen.B = B
	_gen.plan(randi())
	_gen.build(_root, col)
	_spawn = _gen.room_of("depart")["c"]
	_safe = _spawn
	_boss_phase = 0
	_chest_state = "scelle"
	var kinds: Array = R["kinds"]
	var mult := float(R["mult"])
	_scenes.clear()
	var scene_kinds := {"armurerie": "garde", "bibliotheque": "table", "refectoire": "table", "crypte": "feu", "caserne": "garde", "ossuaire": "feu"}
	var elite_room := mult >= 2.5   # rang B et plus : un lieutenant garde une des salles
	for r in _gen.rooms:
		if r["type"] in scene_kinds:
			_gen.decorate(_root, r)
			if r["type"] == "crypte" or r["type"] == "armurerie":
				Kit.dungeon(_root, "Firewood", r["c"], 0.0, 1.4)
			_scene(r["c"], kinds, 3 + (1 if mult >= 1.9 else 0), scene_kinds[r["type"]], mult)
			if elite_room and r["type"] == "caserne":
				var lt := _monster("lieutenant", r["c"] + Vector3(0, 0, -3), mult)
				lt.peaceful = true
				(_scenes[-1]["m"] as Array).append(lt)
	# le gardien endormi au pied de son estrade, son trésor scellé à côté du trône
	_boss = _monster(String(R["boss"]), _gen.boss_spot, mult)
	_boss.peaceful = true
	_boss.def = _boss.def.duplicate(true)       # phase 2 : on modifie SA copie, jamais la définition commune
	_boss.leash = 60.0
	_boss._ap.speed_scale = 0.35
	_scenes.append({"c": _gen.boss_spot, "m": [_boss], "awake": false, "boss": true})
	_chest = Kit.dungeon(_root, "Chest", _gen.chest_pos, PI, 1.7)
	var seal := Magic.rune(_gen.chest_pos + Vector3.UP * 0.05, 1.4, Color(0.6, 0.6, 0.7), 1e9, 0.3)
	seal.reparent(_root)
	_chest.set_meta("sceau", seal)
	# mur fissuré : un mur qui sonne creux, une lueur filtre entre les pierres
	_crack_body = StaticBody3D.new()
	_crack_body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(0.9, DungeonGen.WALL_H, DungeonGen.CELL)
	cs.shape = bs
	_crack_body.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = bs.size
	mi.mesh = bm
	mi.material_override = Geo.mat("pierre_base")
	_crack_body.add_child(mi)
	_root.add_child(_crack_body)
	_crack_body.global_position = _gen.crack["pos"] + Vector3(0, DungeonGen.WALL_H * 0.5, 0)
	var glow := Magic.rune(_gen.crack["pos"] + Vector3(0.5, 1.6, 0), 0.9, Color(0.75, 0.6, 1.0), 1e9, 0.5)
	glow.reparent(_root)
	glow.rotation = Vector3(0, 0, PI / 2.0)
	var hide: Dictionary = _gen.room_of("cachette")
	_secret_chest = Kit.dungeon(_root, "ChestSmall", hide["c"], 0.0, 1.6)
	Magic.pillar(hide["c"], Color(0.75, 0.6, 1.0), 4.0, 0.8, 1e9)
	_objective()

func _objective() -> void:
	if Hud.inst == null or inside.is_empty():
		return
	var total := 0
	var done := 0
	for sc in _scenes:
		if not sc["boss"]:
			total += 1
			if (sc["m"] as Array).filter(func(m): return Combat.alive(m)).is_empty():
				done += 1
	var g := "endormi"
	if _boss != null and Combat.alive(_boss):
		g = "éveillé" if _boss_phase > 0 else "endormi"
	elif _chest_state == "pret":
		g = "vaincu — ouvrez son trésor"
	elif _chest_state == "ouvert":
		g = "vaincu — portail de sortie ouvert"
	Hud.inst.objective("%s · salles %d/%d · gardien %s" % [inside.get("nom", ""), done, total, g])

func _inside_tick() -> void:
	var p := Combat.player
	if p == null or _root == null:
		return
	var dt := get_process_delta_time()
	_chat_t -= dt
	if p.is_on_floor() and p.global_position.y > B.y - 1.0:
		_safe = p.global_position
	if p.global_position.y < B.y - 6.0:
		p.global_position = _safe + Vector3.UP * 0.6     # filet de sécurité (ne devrait jamais servir)
		p.velocity = Vector3.ZERO
	for sc in _scenes:
		var ms: Array = (sc["m"] as Array).filter(func(m): return Combat.alive(m))
		sc["m"] = ms
		if sc["awake"] or ms.is_empty():
			continue
		var reach := 15.0 if sc["boss"] else 10.0
		var hit: bool = ms.any(func(m): return not m.peaceful or m.cbt.hp < m.cbt.max_hp)   # frappé de loin : il s'éveille aussi
		if p.global_position.distance_to(sc["c"]) < reach or hit:
			sc["awake"] = true
			if sc["boss"]:
				_awaken(ms[0])
			else:
				for m in ms:
					m.peaceful = false
					m._aggro()
				FX.bark(ms[0], ["Intrus !", "Aux armes !", "C'est lui ! Le souverain !"][randi() % 3], 2.4, 2.0)
		elif _chat_t <= 0.0 and not sc["boss"] and p.global_position.distance_to(sc["c"]) < 24.0:
			_chat_t = 4.0
			var lines: Array = CHAT.get(sc.get("kind", "feu"), CHAT["feu"])
			FX.bark(ms[randi() % ms.size()], lines[randi() % lines.size()], 2.3, 2.6)
	# phase 2 du gardien : sous la moitié de sa vie, il enrage et appelle sa garde
	if _boss != null and Combat.alive(_boss) and _boss_phase == 1 and _boss.cbt.hp < _boss.cbt.max_hp * 0.5:
		_enrage(_boss)
	if _boss != null and not Combat.alive(_boss):
		_boss = null
		_chest_state = "pret"
		var R: Dictionary = RANKS[inside["rank"]]
		var seal: Node3D = _chest.get_meta("sceau")
		if is_instance_valid(seal):
			seal.queue_free()
		Magic.pillar(_chest.global_position, R["col"], 12.0, 1.0, 1e9)
		Juice.onde(_chest.global_position, R["col"], 5.0, 0.6)
		Sfx.play("niveau", 0.0)
		if Hud.inst:
			Hud.inst.discover("Gardien vaincu !", "Son trésor s'est descellé, sur l'estrade")
	# coffre du gardien
	if _chest_state == "pret" and Hud.inst and p.global_position.distance_to(_chest.global_position) < 3.2:
		Hud.inst.show_prompt("main", "Ouvrir le trésor", func(): open_chest(), 0.4)
	# mur fissuré, puis petit coffre caché
	if is_instance_valid(_crack_body) and Hud.inst and p.global_position.distance_to(_crack_body.global_position) < 3.4:
		Hud.inst.show_prompt("onde", "Briser le mur fissuré", func(): break_wall(), 0.4)
	if is_instance_valid(_secret_chest) and not _secret_chest.has_meta("pris") and Hud.inst and p.global_position.distance_to(_secret_chest.global_position) < 2.6:
		Hud.inst.show_prompt("main", "Ouvrir le coffre caché", func(): _open_secret(), 0.4)
	if Engine.get_process_frames() % 30 == 0:
		_objective()
	if p.cbt.dead:
		leave(false)

## Réveil du gardien : plan de cinéma, rugissement, nom en grand
func _awaken(b: Node3D) -> void:
	if _boss_phase > 0:
		return
	_boss_phase = 1
	b._ap.speed_scale = 1.0
	var w := get_parent()
	var p := Combat.player
	if w.get("rig") and p:
		var look: Vector3 = b.global_position + Vector3.UP * 1.6
		var from: Vector3 = look + (p.global_position - look).normalized() * 6.0 + Vector3.UP * 2.0
		w.rig.cine_on(from, look)
		get_tree().create_timer(1.8).timeout.connect(func():
			if is_instance_valid(w.rig):
				w.rig.cine_off())
	FX.bark(b, ["Qui ose troubler mon repos ?!", "Tu n'aurais jamais dû descendre ici.", "Enfin… un adversaire digne de moi."][randi() % 3], 3.4, 3.0)
	Juice.onde(b.global_position, Color(1.0, 0.3, 0.2), 8.0, 0.7)
	Sfx.play("explosion", -2.0)
	if p:
		p.shake(0.6)
	if Hud.inst:
		Hud.inst.discover(String(b.def["nom"]).to_upper(), "Gardien de %s" % inside.get("nom", "la faille"))
	get_tree().create_timer(1.6).timeout.connect(func():
		if Combat.alive(b):
			b.peaceful = false
			b._aggro())

func _enrage(b: Node3D) -> void:
	_boss_phase = 2
	b.def["vitesse"] = float(b.def["vitesse"]) * 1.25
	b.def["course"] = float(b.def["course"]) * 1.25
	b.def["degats"] = float(b.def["degats"]) * 1.3
	FX.bark(b, ["ASSEZ ! À MOI, MA GARDE !", "Tu vas le payer !"][randi() % 2], 3.4, 2.6)
	Juice.onde(b.global_position, Color(1.0, 0.15, 0.1), 10.0, 0.8)
	Magic.burst(b.global_position + Vector3.UP, Color(1.0, 0.2, 0.15), 2.0, true)
	Sfx.play("explosion", -3.0)
	FX.cast_glow(b, Color(1.0, 0.2, 0.15))
	var R: Dictionary = RANKS[inside["rank"]]
	for i in 2:
		var at: Vector3 = b.global_position + Vector3((i * 2 - 1) * 4.0, 0, 3.0)
		Magic.pillar(at, Color(1.0, 0.3, 0.2), 6.0, 0.8, 1.0)
		var m := _monster((R["kinds"] as Array)[i % (R["kinds"] as Array).size()], at, float(R["mult"]))
		m._aggro()

## Ouverture du trésor : le coffre jaillit, l'or gicle, le butin s'affiche
func open_chest() -> void:
	if _chest_state != "pret":
		return
	_chest_state = "ouvert"
	if Hud.inst:
		Hud.inst.hide_prompt()
	var R: Dictionary = RANKS[inside["rank"]]
	var col: Color = R["col"]
	var c := _chest.global_position
	var tw := _chest.create_tween()
	tw.tween_property(_chest, "scale", _chest.scale * 1.25, 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_property(_chest, "scale", _chest.scale, 0.25)
	Magic.sparks(c + Vector3.UP, Color(1.0, 0.85, 0.3), 40, 9.0, 1.0)
	Magic.burst(c + Vector3.UP, col, 1.6, true)
	FX.impact_light(c + Vector3.UP, Color(1.0, 0.85, 0.4), 6.0, 10.0)
	Sfx.play("or", 0.0)
	var gold := int(R["or"]) + randi() % 60
	var xp := int(gold * 0.8)
	var prog := Progression.get_inst()
	prog.add_gold(gold)
	prog.add_xp(xp)
	prog.add_potion("soin", 2)
	var extra := ""
	if randf() < 0.35 + 0.1 * ["E", "D", "C", "B", "A", "S", "SS"].find(inside["rank"]):
		prog.add_potion("mana", 2)
		extra = " · 2 potions de mana"
	if Hud.inst:
		Hud.inst.discover("Trésor du gardien", "+%d or · +%d XP · 2 potions de soin%s" % [gold, xp, extra])
	GameState.get_inst().report("Donjon « %s » (rang %s) nettoyé : %d or." % [inside["nom"], inside["rank"], gold], "acte")
	# le portail de sortie s'ouvre au centre de la salle
	_exit = RiftPortal.new()
	_exit.col = col
	_exit.scale_k = 0.6
	_root.add_child(_exit)
	_exit.global_position = _gen.boss_spot + Vector3(0, 0, 3.0)
	_exit.entered.connect(func(): leave(true))
	_objective()

func break_wall() -> void:
	if not is_instance_valid(_crack_body):
		return
	var at := _crack_body.global_position
	Magic.debris(at, 22, 8.0)
	Juice.dust(at - Vector3(0, 1.5, 0), 26, 7.0)
	Juice.onde(at - Vector3(0, 2.0, 0), Color(0.8, 0.7, 1.0), 4.0, 0.5)
	Sfx.play("lourd", 0.0)
	if Combat.player:
		Combat.player.shake(0.5)
	_crack_body.queue_free()
	if Hud.inst:
		Hud.inst.hide_prompt()
		Hud.inst.show_message("Le mur s'effondre : un passage secret !", Color(0.85, 0.75, 1.0))

func _open_secret() -> void:
	if not is_instance_valid(_secret_chest) or _secret_chest.has_meta("pris"):
		return
	_secret_chest.set_meta("pris", true)
	var R: Dictionary = RANKS[inside["rank"]]
	var gold := int(int(R["or"]) * 0.6)
	Progression.get_inst().add_gold(gold)
	Progression.get_inst().add_potion("mana", 1)
	Magic.sparks(_secret_chest.global_position + Vector3.UP, Color(0.85, 0.7, 1.0), 30, 8.0, 0.9)
	Sfx.play("or", 0.0)
	if Hud.inst:
		Hud.inst.hide_prompt()
		Hud.inst.discover("Cachette secrète", "+%d or · 1 potion de mana" % gold)
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

