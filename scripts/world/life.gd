class_name Vie
extends Node
## Vie du royaume : entraînement des soldats dans la cour (épéistes et archers), caravanes marchandes
## sur la grande route (vers le portail nain une fois le contact établi), colporteurs, raids de bandits
## avec intervention de la garde, et petites phrases des habitants selon la réputation du seigneur.

static var inst: Vie

var world: Node3D
var _sparring: Array = []
var _archers: Array = []
var _targets: Array = []
var _acc := 0.0
var _bark_acc := 0.0
var _bark_cd := {}
var _bark_global := 0.0
var caravan: Node3D
var _caravan_wait := 60.0
var raid: Dictionary = {}

const SWORD_SPOTS := [[Vector3(-10, 12, -114), Vector3(-10, 12, -116.2)], [Vector3(-14, 12, -119), Vector3(-14, 12, -121.2)], [Vector3(-7, 12, -121), Vector3(-7, 12, -123.2)]]
const ARCHER_LINE := [Vector3(16, 12, -104), Vector3(16, 12, -108), Vector3(16, 12, -112), Vector3(16, 12, -116)]
const TARGET_X := 28.0
const ROAD := [Vector2(35, 222), Vector2(32, 170), Vector2(26, 120), Vector2(28, 80), Vector2(24, 62), Vector2(18, 48), Vector2(6, 20), Vector2(0, -6)]

func _ready() -> void:
	inst = self
	_build_targets()
	refresh_training()
	_peddlers()

# ------------------------------------------------------------------ entraînement (nombre lié aux effectifs réels)
func _build_targets() -> void:
	var straw := StandardMaterial3D.new()
	straw.albedo_color = Color(0.85, 0.72, 0.4)
	var red := StandardMaterial3D.new()
	red.albedo_color = Color(0.8, 0.15, 0.12)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.4, 0.27, 0.15)
	var holder := Node3D.new()
	holder.name = "CiblesTir"
	holder.add_to_group("garde_cour")
	world.add_child(holder)
	for a in ARCHER_LINE:
		var t := Node3D.new()
		holder.add_child(t)
		t.global_position = Vector3(TARGET_X, 12.0, a.z)
		var post := MeshInstance3D.new()
		var pb := BoxMesh.new()
		pb.size = Vector3(0.15, 1.3, 0.15)
		post.mesh = pb
		post.material_override = wood
		post.position = Vector3(0, 0.65, 0)
		t.add_child(post)
		for k in 3:
			var disc := MeshInstance3D.new()
			var cm := CylinderMesh.new()
			cm.top_radius = 0.55 - k * 0.17
			cm.bottom_radius = cm.top_radius
			cm.height = 0.12 + k * 0.02
			cm.radial_segments = 16
			disc.mesh = cm
			disc.material_override = straw if k != 1 else red
			disc.rotation = Vector3(0, 0, PI / 2)
			disc.position = Vector3(-0.06 - k * 0.01, 1.45, 0)
			t.add_child(disc)
		_targets.append(t.global_position)
	Batcher.merge(holder, false)

func refresh_training() -> void:
	var sold := int(Kingdom.res("soldats")) if Kingdom.inst else 6
	var pairs := clampi(1 + (sold - 6) / 2, 1, SWORD_SPOTS.size())
	var arch := clampi(sold / 3, 1, ARCHER_LINE.size())
	while _sparring.size() < pairs:
		var i := _sparring.size()
		var duo := []
		for k in 2:
			var m := _trainee(SWORD_SPOTS[i][k], 0.0 if k == 1 else PI, "Sword")
			duo.append(m)
		_sparring.append({"duo": duo, "t": randf() * 2.0, "who": 0})
	while _sparring.size() > pairs:
		for m in _sparring.pop_back()["duo"]:
			m.queue_free()
	while _archers.size() < arch:
		var i := _archers.size()
		var m := _trainee(ARCHER_LINE[i], PI / 2.0, "")
		_bow(m)
		_archers.append({"m": m, "t": randf() * 3.0, "i": i})
	while _archers.size() > arch:
		_archers.pop_back()["m"].queue_free()

func _trainee(pos: Vector3, yaw: float, weapon: String) -> Node3D:
	var n := Node3D.new()
	n.add_to_group("garde_cour")
	n.add_to_group("pnj")
	n.set_meta("talk", {"id": "recrue_%d_%d" % [int(pos.x), int(pos.z)], "nom": Kingdom.data()["pnj"]["noms_h"][absi(int(pos.z * 3.0)) % 12], "role": "garde"})
	var m := CharBuilder.build({"outfit": "rodeur_h", "tint": Color(0.55, 0.62, 0.95), "skin_light": randf() > 0.4, "beard": randf() > 0.6})
	n.add_child(m)
	world.add_child(n)
	n.global_position = pos
	n.rotation.y = yaw
	if weapon != "":
		var skel: Skeleton3D = m.get_node("Armature/Skeleton3D")
		var att := BoneAttachment3D.new()
		att.bone_name = "hand_r"
		skel.add_child(att)
		var w := Kit.dungeon(att, weapon, Vector3.ZERO, 0.0, 1.0)
		w.rotation_degrees = Vector3(-90, 0, 0)
	n.set_meta("ap", m.get_node("AnimationPlayer"))
	return n

## Arc procédural (bois courbé + corde) tenu dans la main gauche
func _bow(n: Node3D) -> void:
	var m: Node3D = n.get_child(0)
	var skel: Skeleton3D = m.get_node("Armature/Skeleton3D")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_l"
	skel.add_child(att)
	var wood := StandardMaterial3D.new()
	wood.albedo_color = Color(0.45, 0.28, 0.12)
	var holder := Node3D.new()
	att.add_child(holder)
	holder.rotation_degrees = Vector3(0, 0, 90)
	for k in 7:
		var a := -0.9 + k * 0.3
		var seg := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(0.035, 0.2, 0.035)
		seg.mesh = bm
		seg.material_override = wood
		seg.position = Vector3(cos(a) * 0.45 - 0.35, sin(a) * 0.62, 0)
		seg.rotation.z = a
		holder.add_child(seg)
	var string := MeshInstance3D.new()
	var sm := BoxMesh.new()
	sm.size = Vector3(0.01, 1.1, 0.01)
	string.mesh = sm
	string.position = Vector3(-0.1, 0, 0)
	holder.add_child(string)

func _process(delta: float) -> void:
	var p := Combat.player
	if p == null:
		return
	_acc += delta
	_bark_acc += delta
	_bark_global -= delta
	# entraînement animé seulement si le joueur est assez près pour le voir
	var near_court := p.global_position.distance_to(Vector3(0, 12, -110)) < 70.0
	if near_court:
		for sp in _sparring:
			sp["t"] -= delta
			if sp["t"] <= 0.0:
				sp["t"] = randf_range(1.1, 1.6)
				var a: Node3D = sp["duo"][sp["who"]]
				var b: Node3D = sp["duo"][1 - sp["who"]]
				_anim(a, ["b/Sword_Regular_A", "b/Sword_Regular_B", "Sword_Attack"][randi() % 3])
				_anim(b, "b/Sword_Block")
				sp["who"] = 1 - sp["who"]
				if p.global_position.distance_to(a.global_position) < 18.0:
					Sfx.play("epee", -16.0)
		for ar in _archers:
			ar["t"] -= delta
			if ar["t"] <= 0.0:
				ar["t"] = randf_range(2.4, 3.6)
				_anim(ar["m"], "Pistol_Shoot")
				_arrow(ar["m"].global_position + Vector3(0.4, 1.5, 0), _targets[ar["i"]] + Vector3(-0.1, 1.45, randf_range(-0.25, 0.25)))
	if _bark_acc > 0.5:
		_bark_acc = 0.0
		_barks(p)
	if _acc >= 1.0:
		var dt := _acc
		_acc = 0.0
		if Story.done():
			_caravan_tick(dt)
			_raid_tick(dt)

func _anim(n: Node3D, a: String) -> void:
	var ap: AnimationPlayer = n.get_meta("ap")
	if ap.has_animation(a):
		ap.play(a, 0.12)
		ap.queue("Sword_Idle" if a != "Pistol_Shoot" else "Pistol_Idle")

func _arrow(from: Vector3, to: Vector3) -> void:
	var ar := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.03, 0.03, 0.7)
	ar.mesh = bm
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.5, 0.36, 0.2)
	ar.material_override = mat
	world.add_child(ar)
	ar.global_position = from
	ar.look_at(to, Vector3.UP)
	var tw := ar.create_tween()
	var mid := (from + to) * 0.5 + Vector3.UP * 0.6
	tw.tween_method(func(t: float):
		var a := from.lerp(mid, t)
		var b := mid.lerp(to, t)
		var p := a.lerp(b, t)
		if p.distance_to(ar.global_position) > 0.01:
			ar.look_at(p + (p - ar.global_position), Vector3.UP)
		ar.global_position = p, 0.0, 1.0, 0.45)
	tw.tween_interval(3.0)
	tw.tween_callback(ar.queue_free)

# ------------------------------------------------------------------ petites phrases selon la réputation
static func popularity() -> float:
	var gs := GameState.get_inst()
	return gs.val("confiance_habitants") + gs.val("reputation") * 0.6 + gs.val("bienveillance") * 0.5 - gs.val("arrogance") * 0.4 - gs.val("crainte") * 0.3

static func tier() -> String:
	var gs := GameState.get_inst()
	var pop := popularity()
	if gs.val("crainte") >= 15 and pop < 10:
		return "craint"
	if pop >= 18:
		return "adore"
	if pop >= 6:
		return "bon"
	if pop <= -10:
		return "deteste"
	return "neutre"

func _barks(p: Player) -> void:
	if not Story.done() or Dialogue.active or _bark_global > 0.0:
		return
	if Combat.in_radius(p.global_position, 18.0).size() > 0:
		return
	var now := Time.get_ticks_msec() / 1000.0
	var gs := GameState.get_inst()
	for n in get_tree().get_nodes_in_group("pnj"):
		if not n.visible or not n.has_meta("talk"):
			continue
		var d: float = n.global_position.distance_to(p.global_position)
		if d > 6.0 or d < 1.2:
			continue
		var id: String = n.get_meta("talk")["id"]
		if now < float(_bark_cd.get(id, 0.0)):
			continue
		var role: String = n.get_meta("talk")["role"]
		if role in ["roi", "prisonnier", "escorte_prison"]:
			continue
		_bark_cd[id] = now + 90.0
		_bark_global = 7.0
		var tr := tier()
		var key := tr
		if role == "garde":
			key = "garde_craint" if tr in ["craint", "deteste"] else "garde_bon"
			if n.has_method("nod"):
				n.nod()
		var rel := int(gs.mem(id).get("relation", 0))
		if rel >= 8 and key == "neutre":
			key = "bon"
		elif rel <= -6 and role != "garde":
			key = "deteste"
		var pool: Array = Kingdom.data()["barks"][key]
		if FOREIGN_BARKS.has(role):
			pool = FOREIGN_BARKS[role]
		FX.bark(n, String(pool[randi() % pool.size()]).replace("{titre}", gs.titre), 2.3, 3.2)
		return

const FOREIGN_BARKS := {
	"nain": ["Hmpf. Un humain.", "Par la barbe de mon père…", "Pas de mains sales sur l'enclume !", "La bière est meilleure ici qu'en surface, hein ?", "Écoute les marteaux, humain."],
	"garde_nain": ["Avance, humain. Doucement.", "On te surveille.", "Pour Karak Dûm !"],
	"roi_nain": ["…"],
	"brigand_civil": ["Ne regardez pas le chef dans les yeux.", "On ne veut pas d'histoires, seigneur.", "Encore un chevalier…"],
}

# ------------------------------------------------------------------ caravanes et colporteurs
func _peddlers() -> void:
	var routes := [
		[Vector2(4, -16), Vector2(30, -14), Vector2(55, -8), Vector2(80, -6), Vector2(55, -8), Vector2(30, -14)],
		[Vector2(-4, -22), Vector2(-30, -20), Vector2(-60, -14), Vector2(-90, -10), Vector2(-60, -14), Vector2(-30, -20)],
	]
	for i in routes.size():
		var v := Villager.new()
		v.spec = {"outfit": "paysan_h" if i == 0 else "paysan_f", "female": i == 1, "hair": "Hair_SimpleParted" if i == 0 else "Hair_Long", "tint": Color(0.9, 0.75, 0.55)}
		v.path = routes[i]
		v.speed = 1.2
		world.add_child(v)
		v.set_meta("talk", {"id": "colporteur_%d" % i, "nom": ["Anselme", "Clémence"][i], "role": "marchand"})

func _caravan_tick(dt: float) -> void:
	if caravan and is_instance_valid(caravan):
		return
	_caravan_wait -= dt
	if _caravan_wait > 0.0:
		return
	_caravan_wait = randf_range(150.0, 240.0)
	caravan = Caravan.new()
	caravan.route = ROAD
	caravan.dwarven = GameState.get_inst().flag("contact_nains")
	world.add_child(caravan)

# ------------------------------------------------------------------ raids de bandits
## Un raid frappe un lieu du royaume ; la garde part réellement à leur rencontre.
func start_raid(id := "") -> void:
	if not raid.is_empty():
		return
	var places: Array = Kingdom.data()["raids"]
	var pl: Dictionary = places[randi() % places.size()]
	for p in places:
		if p["id"] == id:
			pl = p
	var c := Vector3(pl["pos"][0], 0, pl["pos"][1])
	c.y = Terrain.height_at(c.x, c.z)
	var bandits := []
	var n := 3 + (1 if randf() < 0.5 else 0)
	for i in n:
		var m := Monster.new()
		m.kind = "chef_bandit" if i == 0 and randf() < 0.35 else "bandit"
		m.no_respawn = true
		m.leash = 40.0
		var a := TAU * i / n
		m.position = c + Vector3(cos(a) * 3.0, 0.3, sin(a) * 3.0)
		world.add_child(m)
		bandits.append(m)
	var fire := _fires(c)
	var guards := []
	var sold := int(Kingdom.res("soldats"))
	var send := clampi(sold / 3, 1, 3)
	for i in send:
		var s := Soldier.new()
		s.nom = Kingdom.data()["pnj"]["noms_h"][(i * 7 + randi()) % 12]
		s.home = Escort.GATE
		world.add_child(s)
		s.global_position = Escort.GATE + Vector3(i * 1.4, 0, 0)
		s.go_to(c + Vector3(i * 1.5, 0, 2.0))
		guards.append(s)
	raid = {"lieu": pl, "bandits": bandits, "guards": guards, "t": 110.0, "fire": fire, "centre": c}
	GameState.get_inst().report("Raid de bandits sur %s ! La garde est en route." % pl["nom"], "alerte")
	if Hud.inst:
		Hud.inst.discover("Raid de bandits !", "Ils pillent %s — la garde intervient" % pl["nom"])
		Hud.inst.objective("Repoussez les bandits (%s)" % pl["nom"])

func _fires(c: Vector3) -> Node3D:
	var root := Node3D.new()
	world.add_child(root)
	root.global_position = c
	for k in 3:
		var f := FX.particles("fire_01", 14, 0.9, [Color(1, 0.8, 0.4, 0.9), Color(1, 0.35, 0.1, 0.6), Color(0.2, 0.1, 0.05, 0)], 1.2, false)
		f.direction = Vector3.UP
		f.spread = 15.0
		f.initial_velocity_min = 1.0
		f.initial_velocity_max = 2.2
		f.gravity = Vector3(0, 1.5, 0)
		f.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
		f.emission_sphere_radius = 0.6
		root.add_child(f)
		f.position = Vector3(randf_range(-5, 5), 0.4, randf_range(-5, 5))
		f.emitting = true
		var sm := FX.particles("smoke_02", 6, 3.0, [Color(0.2, 0.2, 0.2, 0.6), Color(0.3, 0.3, 0.3, 0)], 3.0, false, false)
		sm.direction = Vector3.UP
		sm.initial_velocity_min = 1.0
		sm.initial_velocity_max = 2.0
		sm.gravity = Vector3(0.4, 0.6, 0)
		root.add_child(sm)
		sm.position = f.position + Vector3.UP * 1.0
		sm.emitting = true
	return root

func _raid_tick(dt: float) -> void:
	if raid.is_empty():
		return
	raid["t"] = float(raid["t"]) - dt
	var alive := 0
	for m in raid["bandits"]:
		if is_instance_valid(m) and not m.cbt.dead:
			alive += 1
	var gs := GameState.get_inst()
	if alive == 0:
		gs.report("Les bandits ont été repoussés de %s." % raid["lieu"]["nom"], "armee")
		gs.add("reputation", 1)
		gs.add("confiance_habitants", 1)
		if Hud.inst:
			Hud.inst.show_message("Raid repoussé !", Color(0.6, 1, 0.6))
		_end_raid(false)
	elif float(raid["t"]) <= 0.0:
		# pillage réussi : pertes réelles, le lieu fume encore un moment
		Kingdom.add("tresor", -30)
		Kingdom.add("nourriture", -25)
		Kingdom.add("moral", -5)
		gs.add("confiance_habitants", -2)
		gs.report("Les bandits ont pillé %s : -30 or, -25 nourriture, le moral baisse." % raid["lieu"]["nom"], "alerte")
		if Hud.inst:
			Hud.inst.show_message("Les bandits ont pillé %s" % raid["lieu"]["nom"], Color(1, 0.55, 0.45))
		for m in raid["bandits"]:
			if is_instance_valid(m) and not m.cbt.dead:
				m.queue_free()
		_end_raid(true)

func _end_raid(razed: bool) -> void:
	for s in raid["guards"]:
		if is_instance_valid(s) and not s.cbt.dead:
			s.send_home()
	var fire: Node3D = raid["fire"]
	if is_instance_valid(fire):
		get_tree().create_timer(120.0 if razed else 20.0).timeout.connect(func(): if is_instance_valid(fire): fire.queue_free())
	if Hud.inst:
		Hud.inst.objective("")
	raid = {}
