class_name Frontier
extends Node
## La frontière vivante du royaume :
## - postes de garde aux ponts et sur les routes : de vrais soldats qui se battent seuls ;
## - embuscades des bandits de leurs villages contre les caravanes et les postes, avec parfois
##   des « faux voyageurs » déguisés, plus forts, qui frappent par surprise ;
##   le souverain choisit : y aller lui-même, envoyer la garde, ou lever l'armée ;
## - bandes errantes qui vont d'un repaire à l'autre hors des camps.

static var inst: Frontier
static var quiet := false     # tests : pas de bandes ni d'embuscade spontanées
var world: Node3D
var posts: Array = []        # {pos: Vector3, name: String, guards: Array, wait: float}
var raid := {}               # embuscade en cours
var bands: Array = []        # {path: Array[Vector2], i: int, at: Vector2, ms: Array, kinds: Array}
var _raid_wait := 200.0
var _acc := 0.0
const ROAD_POSTS := [[Vector2(28, 140), "Poste de la route du portail"], [Vector2(70, -7), "Poste de la route des champs"], [Vector2(-75, -12), "Poste de la route de l'ouest"]]
const BAND_PATHS := [
	[Vector2(-60, 140), Vector2(-20, 118), Vector2(26, 120), Vector2(32, 170), Vector2(-40, 195), Vector2(-85, 202), Vector2(-60, 140)],
	[Vector2(210, 40), Vector2(172, 92), Vector2(130, 128), Vector2(118, 40), Vector2(168, -40), Vector2(210, 40)],
	[Vector2(-75, -60), Vector2(-110, -30), Vector2(-150, 20), Vector2(-112, 62), Vector2(-60, 40), Vector2(-75, -60)],
]

static func build(w: Node3D) -> void:
	inst = Frontier.new()
	inst.name = "Frontiere"
	inst.world = w
	w.add_child(inst)
	var k := 0
	for br in Roads.bridges:
		for end in [br[0], br[1]]:
			var a: Vector2 = end
			var b: Vector2 = br[1] if end == br[0] else br[0]
			var dir := (a - b).normalized()
			var q: Vector2 = a + dir * 2.5 + Vector2(dir.y, -dir.x) * 3.0
			inst.posts.append({"pos": Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), "name": "Poste du pont", "guards": [], "wait": 0.0, "n": 1 if k % 2 else 2})
			k += 1
	for rp in ROAD_POSTS:
		var q: Vector2 = rp[0]
		inst.posts.append({"pos": Vector3(q.x, Terrain.height_at(q.x, q.y), q.y), "name": rp[1], "guards": [], "wait": 0.0, "n": 2})
	for p in BAND_PATHS:
		inst.bands.append({"path": p, "i": 1, "at": p[0], "ms": [], "kinds": ["bandit", "bandit", "lanceur"] if bands_count() % 2 == 0 else ["bandit", "bandit", "bandit"]})
	# un étendard et un brasero par poste : on les repère de loin
	for p in inst.posts:
		var pos: Vector3 = p["pos"]
		Kit.dungeon(w, "Banner", pos + Vector3(1.2, 0, 0), 0.0, 1.0)
		Kit.dungeon(w, "Torch", pos + Vector3(-1.0, 0, 0.6), 0.0, 1.4)

static func bands_count() -> int:
	return inst.bands.size() if inst else 0

func _active() -> bool:
	for a in OS.get_cmdline_user_args():
		if String(a) in ["--tour", "--combat", "--story"]:
			return false
	return true

func _process(delta: float) -> void:
	var p := Combat.player
	if p == null:
		return
	_acc += delta
	if _acc < 0.5:
		return
	var dt := _acc
	_acc = 0.0
	_tick_posts(p, dt)
	if not quiet:
		_tick_bands(p, dt)
	_tick_raid(dt)
	if quiet or not raid.is_empty() or Spawner.paused or not Story.done() or not _active():
		return
	_raid_wait -= dt
	if _raid_wait <= 0.0:
		_raid_wait = randf_range(220.0, 360.0)
		ambush()

# ------------------------------------------------------------------ postes de garde
func _tick_posts(p: Node3D, dt: float) -> void:
	for post in posts:
		var pos: Vector3 = post["pos"]
		var near := p.global_position.distance_to(pos) < 95.0 or (not raid.is_empty() and (raid["at"] as Vector3).distance_to(pos) < 60.0)
		post["guards"] = (post["guards"] as Array).filter(func(s): return is_instance_valid(s) and not s.cbt.dead)
		var gs: Array = post["guards"]
		if near and gs.size() < int(post["n"]):
			post["wait"] = float(post["wait"]) - dt
			if float(post["wait"]) <= 0.0:
				_staff(post)
		for s in gs:
			var keep := near or s._target != null
			if s.visible != keep:
				s.visible = keep
				s.process_mode = Node.PROCESS_MODE_INHERIT if keep else Node.PROCESS_MODE_DISABLED
				if keep:
					Combat.add_ally(s)
				else:
					Combat.remove_ally(s)

func _staff(post: Dictionary) -> void:
	var pool: Array = Kingdom.data()["pnj"]["noms_h"]
	var gs: Array = post["guards"]
	while gs.size() < int(post["n"]):
		var s := Soldier.new()
		s.nom = pool[randi() % pool.size()]
		var pos: Vector3 = post["pos"] + Vector3(gs.size() * 1.6, 0, 0)
		pos.y = Terrain.height_at(pos.x, pos.z) + 0.2
		s.home = pos
		s.mode = Soldier.M.GARDER
		s.goal = pos
		s.free_on_return = false
		world.add_child(s)
		s.global_position = pos
		s.cbt.died.connect(func(_x): post["wait"] = 240.0)
		gs.append(s)
	post["wait"] = 0.0

## Postes et effectifs (pour la carte et les tests)
static func post_guards() -> int:
	var n := 0
	if inst:
		for p in inst.posts:
			n += (p["guards"] as Array).filter(func(s): return is_instance_valid(s) and not s.cbt.dead).size()
	return n

# ------------------------------------------------------------------ bandes errantes
func _tick_bands(p: Node3D, dt: float) -> void:
	for b in bands:
		var path: Array = b["path"]
		var at: Vector2 = b["at"]
		var ms: Array = (b["ms"] as Array).filter(func(m): return Combat.alive(m))
		if ms.is_empty() and not (b["ms"] as Array).is_empty():
			b["cool"] = 300.0     # bande anéantie : une autre se reforme plus tard
		b["ms"] = ms
		var fighting := ms.any(func(m): return m.state != Monster.S.ERRANCE)
		if not fighting:
			var tgt: Vector2 = path[int(b["i"])]
			var d := tgt - at
			if d.length() < 2.0:
				b["i"] = (int(b["i"]) + 1) % path.size()
			else:
				at += d.normalized() * minf(d.length(), 1.5 * dt)
				b["at"] = at
		var a3 := Vector3(at.x, Terrain.height_at(at.x, at.y), at.y)
		var dist := p.global_position.distance_to(a3)
		if dist < 90.0 and ms.is_empty() and float(b.get("cool", 0.0)) <= 0.0 and Story.done() and not Spawner.paused:
			for i in (b["kinds"] as Array).size():
				var m := Monster.new()
				m.kind = b["kinds"][i]
				m.no_respawn = true
				m.leash = 35.0
				m.position = a3 + Vector3((i - 1) * 1.6, 0.4, -i * 0.8)
				world.add_child(m)
				m.home = m.position
				ms.append(m)
			b["ms"] = ms
		elif dist > 140.0 and not ms.is_empty():
			for m in ms:
				m.queue_free()
			b["ms"] = []
		elif ms.is_empty():
			b["cool"] = maxf(0.0, float(b.get("cool", 0.0)) - dt)
		# la bande marche en colonne derrière son meneur (sans quitter la piste)
		var heading := Vector2.ZERO
		if path.size() > 0:
			heading = ((path[int(b["i"])] as Vector2) - at).normalized()
		for i in ms.size():
			var m: Monster = ms[i]
			var slot: Vector2 = at - heading * (i * 1.8) + Vector2(heading.y, -heading.x) * (0.8 if i % 2 else -0.8)
			m.home = Vector3(slot.x, Terrain.height_at(slot.x, slot.y), slot.y)
			if m.state == Monster.S.ERRANCE:
				m._wander = m.home
				m._t = 3.0

static func band_positions() -> Array:
	var out := []
	if inst:
		for b in inst.bands:
			out.append(b["at"])
	return out

# ------------------------------------------------------------------ embuscades
## Les bandits d'un village sortent frapper la caravane (ou, à défaut, un poste de garde).
func ambush(force_disguise := false) -> bool:
	var cara: Node3D = null
	var life := world.get_node_or_null("Vie")
	if life and "caravan" in life and is_instance_valid(life.caravan) and not life.caravan.looted:
		cara = life.caravan
	var at := Vector3.ZERO
	var target_name := ""
	if cara:
		at = cara.global_position
		target_name = "la caravane d'Odon"
	else:
		var cands := posts.filter(func(p): return Combat.player == null or (p["pos"] as Vector3).distance_to(Combat.player.global_position) > 40.0)
		if cands.is_empty():
			return false
		var post: Dictionary = cands[randi() % cands.size()]
		at = post["pos"]
		target_name = String(post["name"]).to_lower()
		if (post["guards"] as Array).is_empty():
			_staff(post)
	var src := _source_camp(Vector2(at.x, at.z))
	if src == "":
		return false
	# les pillards surgissent d'un fourré à une vingtaine de mètres
	var ms: Array = []
	var disguised := force_disguise or randf() < 0.45
	var kinds := ["bandit", "bandit", "lanceur"]
	if disguised:
		kinds = ["bandit_deguise", "bandit_deguise", "bandit"]
	var ang := randf() * TAU
	for i in kinds.size():
		var q := at + Vector3(cos(ang) * 18.0 + i * 1.5, 0, sin(ang) * 18.0 + i)
		if Terrain.height_at(q.x, q.z) < Layout.WATER + 0.4:
			q = at + Vector3(i * 1.5 - 1.5, 0, 6.0)
		q.y = Terrain.height_at(q.x, q.z) + 0.4
		var m := Monster.new()
		m.kind = kinds[i]
		m.no_respawn = true
		m.leash = 60.0
		m.position = q
		world.add_child(m)
		m.home = at
		if m.kind == "bandit_deguise":
			m.peaceful = true      # il s'approche en voyageur…
			m.set_meta("deguise", true)
		ms.append(m)
	if cara:
		cara.under_attack = true
		cara._merchant.exposed(true)
	raid = {"at": at, "ms": ms, "cara": cara, "t": 150.0, "src": src, "nom": target_name, "sent": false}
	var camp: String = String(CampParley.zone(src).get("label", "des bandits"))
	GameState.get_inst().report("Embuscade : les bandits (%s) attaquent %s !" % [camp, target_name], "alerte")
	if Hud.inst:
		Hud.inst.discover("Embuscade !", "Les bandits attaquent %s%s" % [target_name, " — certains sont déguisés" if disguised else ""])
		Hud.inst.objective("Défendre %s" % target_name)
		var choices := [
			["epee", "J'y vais", func(): _go_myself()],
			["bouclier", "Envoyer la garde", func(): send_guards(3)],
		]
		if Army.reserve() > 0:
			choices.append(["legion", "Lever l'armée", func(): send_army(6)])
		Hud.inst.show_choices(choices, 9.0, Callable())
	return true

func _source_camp(from: Vector2) -> String:
	var best := ""
	var bd := INF
	for gid in BanditVillage.VILLAGES:
		var st := String(CampParley._st().get(gid, "neutre"))
		if st in ["rase", "treve", "allie", "soumis", "libere"]:
			continue
		var sp := Spawner.by_id(gid)
		if sp and sp.liberated:
			continue
		var d := from.distance_to(CampParley.zone(gid)["pos"])
		if d < bd:
			bd = d
			best = gid
	return best

func _go_myself() -> void:
	if raid.is_empty():
		return
	if Combat.player and Combat.player.has_method("set_flying") and Combat.player.global_position.distance_to(raid["at"]) > 60.0:
		if Hud.inst:
			Hud.inst.show_message("Volez jusqu'à l'embuscade : elle est marquée sur la carte", Color(1, 0.8, 0.4))
	raid["self"] = true

## La garde quitte la porte du château et court au secours (vrais soldats, vrais combats)
func send_guards(n: int) -> void:
	if raid.is_empty() or raid["sent"]:
		return
	raid["sent"] = true
	var pool: Array = Kingdom.data()["pnj"]["noms_h"]
	var at: Vector3 = raid["at"]
	var start := Escort.GATE
	# la garde part du poste le plus proche s'il y en a un, sinon du château
	var bd := INF
	for post in posts:
		var d: float = (post["pos"] as Vector3).distance_to(at)
		if d < bd and d > 15.0:
			bd = d
			start = post["pos"]
	for i in n:
		var s := Soldier.new()
		s.nom = pool[(i * 5 + randi()) % pool.size()]
		s.home = start
		world.add_child(s)
		s.global_position = start + Vector3(i * 1.4, 0.3, 0)
		s.go_to(at + Vector3(i * 1.5 - 1.5, 0, 2.0))
	GameState.get_inst().report("La garde part défendre %s." % raid["nom"], "armee")

func send_army(n: int) -> void:
	if raid.is_empty():
		return
	var made := Army.deploy(n)
	Army.order(made, "attaquer", [raid["at"]])
	raid["sent"] = true
	GameState.get_inst().report("L'armée marche sur l'embuscade (%d soldats)." % made.size(), "armee")

func _tick_raid(dt: float) -> void:
	if raid.is_empty():
		return
	var ms: Array = (raid["ms"] as Array).filter(func(m): return Combat.alive(m))
	raid["t"] = float(raid["t"]) - dt
	var cara: Node3D = raid["cara"]
	# les faux voyageurs se démasquent à quelques pas de leur proie
	for m in ms:
		if m.has_meta("deguise") and m.peaceful:
			var prey: Node3D = cara._merchant if is_instance_valid(cara) else null
			var dest: Vector3 = prey.global_position if prey else raid["at"]
			if m.global_position.distance_to(dest) < 5.0 or m.cbt.hp < m.cbt.max_hp:
				m.peaceful = false
				m.remove_meta("deguise")
				FX.bark(m, ["Surprise, marchand !", "Tes gardes ne te sauveront pas !", "Le voyage s'arrête ici !"][randi() % 3], 2.6, 2.4)
				Juice.onde(m.global_position, Color(1.0, 0.4, 0.2), 3.0, 0.4)
				if prey:
					m.force_target = prey
					m.force_until = Time.get_ticks_msec() / 1000.0 + 8.0
				m._aggro()
			elif m.state == Monster.S.ERRANCE:
				m._wander = dest
				m._t = 3.0
		elif m.state == Monster.S.ERRANCE and is_instance_valid(cara) and not cara.looted:
			m.force_target = cara._merchant
			m.force_until = Time.get_ticks_msec() / 1000.0 + 3.0
			m._aggro()
	var lost: bool = is_instance_valid(cara) and cara.looted
	if ms.is_empty() or lost or float(raid["t"]) <= 0.0:
		var gs := GameState.get_inst()
		if ms.is_empty():
			var gain := 40 + 15 * (raid["ms"] as Array).size()
			Kingdom.add("tresor", gain)
			gs.report("Embuscade repoussée devant %s : +%d or de butin." % [raid["nom"], gain], "victoire")
			if Hud.inst:
				Hud.inst.discover("Embuscade repoussée", "+%d or de butin" % gain)
		elif not lost:
			for m in ms:
				m.frighten(10.0)
		if is_instance_valid(cara):
			cara.under_attack = false
			cara._merchant.exposed(false)
		if Hud.inst:
			Hud.inst.objective("")
		raid = {}

static func raid_active() -> bool:
	return inst != null and not inst.raid.is_empty()
