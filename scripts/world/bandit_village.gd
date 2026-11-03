class_name BanditVillage
extends Node
## Repaires de bandits devenus de vrais villages : halle du chef, forge, taverne, boucherie,
## poissonnerie, maisons, habitants qui vivent leur vie (ils fuient si le village est rasé).
## Construit autour des camps « parlants » ; le bourg du royaume n'est pas touché.

const VILLAGES := ["camp_bandits", "brigands_est", "lanceurs_sud", "rodeurs_ouest"]
const MARGE := 22.0   # le village s'étend à r + 22 m (au-delà de la salle et des cabanes du repaire)

static var inst: BanditVillage
var _people := {}      # gid -> Array de Villager
var _acc := 0.0

static func is_village(gid: String) -> bool:
	return gid in VILLAGES

## Marge réservée autour d'un repaire (pas d'arbres ni de rochers dans le village)
static func reserve(id: String) -> float:
	return radius(id) + 4.0 if id in VILLAGES else 0.0

## Rayon de la palissade du village
static func radius(id: String) -> float:
	for z in Spawner.ZONES:
		if z["id"] == id:
			return float(z["r"]) + MARGE
	return MARGE

static func build(world: Node3D) -> void:
	inst = BanditVillage.new()
	inst.name = "VillagesBandits"
	world.add_child(inst)
	var g := Geo.new()
	var root := Node3D.new()
	root.name = "VillagesDecor"
	world.add_child(root)
	for z in Spawner.ZONES:
		if z["id"] in VILLAGES:
			inst._village(g, root, world, z)
	g.commit(world, "Villages")
	Batcher.merge(root)

func _village(g: Geo, root: Node3D, world: Node3D, z: Dictionary) -> void:
	var gid: String = z["id"]
	var c: Vector2 = z["pos"]
	var rng := RandomNumberGenerator.new()
	rng.seed = absi(gid.hash())
	var face := atan2(Layout.TOWN.x - c.x, Layout.TOWN.y - c.y)   # l'entrée regarde vers le bourg
	# plan : les bâtiments en couronne, l'entrée (vers le bourg) laissée libre
	# les grands repaires ont déjà leur grande salle (Repaire) : le village s'ajoute tout autour
	var plan := ["halle", "taverne", "forge", "maison", "boucherie", "maison", "poissonnerie", "maison", "maison"]
	if Repaire.BIG.has(gid):
		plan = ["taverne", "maison", "forge", "boucherie", "maison", "poissonnerie", "maison", "maison", "maison"]
	var ring := float(z["r"]) + 14.0
	var n := plan.size()
	var spots: Dictionary = {}
	for i in n:
		var a := face + PI + (float(i) - (n - 1) * 0.5) * (TAU - 1.3) / n
		var R := ring + (1.0 if plan[i] in ["halle", "taverne"] else rng.randf_range(-0.5, 1.5))
		var q := c + Vector2(sin(a), cos(a)) * R
		if Terrain.height_at(q.x, q.y) < Layout.WATER + 0.5 or Layout.river_dist(q) < Layout.RIVER_W + 4.0 or Layout.in_castle(q, 16.0) or Layout.road_dist(q) < 6.0 or _near_town_house(q):
			continue
		var rot := atan2(c.x - q.x, c.y - q.y)   # façade tournée vers la place
		spots[plan[i]] = [q, rot]
		match plan[i]:
			"halle":
				Town.house(g, q, 11.0, 7.5, rot, 2, "ardoise", rng, "pierre_base")
				_front(root, q, rot, 4.4, "Throne", 1.3)
				for s in [-1.0, 1.0]:
					var bq: Vector2 = q + Vector2(sin(rot), cos(rot)) * 4.6 + Vector2(cos(rot), -sin(rot)) * 3.8 * s
					g.box("bois_sombre", Vector3(bq.x, Terrain.height_at(bq.x, bq.y) + 2.5, bq.y), Vector3(0.18, 5.0, 0.18), 0.0, true)
					Kit.dungeon(root, "Banner", Vector3(bq.x, Terrain.height_at(bq.x, bq.y) + 2.8, bq.y), rot, 1.3)
				_sign(root, q, rot, 5.0, "Halle du chef")
			"taverne":
				Town.house(g, q, 9.0, 7.0, rot, 2, "chaume", rng, "crepi")
				for k in 2:
					var tq: Vector2 = q + Vector2(sin(rot), cos(rot)) * 5.8 + Vector2(cos(rot), -sin(rot)) * (k * 3.4 - 1.7)
					var ty := Terrain.height_at(tq.x, tq.y)
					Kit.dungeon(root, "Table_Big", Vector3(tq.x, ty, tq.y), rot, 1.0)
					Kit.dungeon(root, "Bench", Vector3(tq.x + sin(rot) * 1.1, ty, tq.y + cos(rot) * 1.1), rot, 1.0)
					Kit.dungeon(root, "Mug", Vector3(tq.x, ty + 0.82, tq.y), 0.0, 1.0)
					Kit.dungeon(root, "Barrel_Big", Vector3(tq.x - cos(rot) * 2.6, ty, tq.y + sin(rot) * 2.6), 0.0, 1.0)
				_sign(root, q, rot, 4.0, "Taverne du Pendu")
				_lamp(root, q + Vector2(sin(rot), cos(rot)) * 4.2, Color(1.0, 0.7, 0.35))
			"forge":
				_shed(g, q, rot, 5.2, 4.2, "ardoise")
				var fq: Vector2 = q + Vector2(sin(rot), cos(rot)) * 0.4
				var fy := Terrain.height_at(fq.x, fq.y)
				g.box("pierre_base", Vector3(fq.x, fy + 0.55, fq.y), Vector3(1.6, 1.1, 1.2), rot, true)
				g.box("fenetre_sombre", Vector3(fq.x + cos(rot) * 1.6, fy + 0.45, fq.y - sin(rot) * 1.6), Vector3(0.5, 0.9, 0.5), rot, true)
				Kit.dungeon(root, "WeaponRack_Big", Vector3(q.x - sin(rot) * 1.6, fy, q.y - cos(rot) * 1.6), rot, 1.0)
				_fire(root, Vector3(fq.x, fy + 1.15, fq.y), 0.4)
				_sign(root, q, rot, 3.2, "Forge")
			"boucherie":
				_shed(g, q, rot, 4.2, 3.0, "tissu_rouge")
				var by := Terrain.height_at(q.x, q.y)
				Kit.dungeon(root, "Table_Big", Vector3(q.x, by, q.y), rot, 1.0)
				for k in 3:
					Kit.dungeon(root, "Meat", Vector3(q.x + cos(rot) * (k - 1) * 0.6, by + 0.84, q.y - sin(rot) * (k - 1) * 0.6), rng.randf() * TAU, 1.2)
				Kit.dungeon(root, "Knife", Vector3(q.x + 0.3, by + 0.84, q.y), 0.6, 1.0)
				_sign(root, q, rot, 2.4, "Boucherie")
			"poissonnerie":
				_shed(g, q, rot, 4.2, 3.0, "tissu_blanc")
				var py := Terrain.height_at(q.x, q.y)
				Kit.dungeon(root, "Table_Big", Vector3(q.x, py, q.y), rot, 1.0)
				for k in 3:
					Kit.dungeon(root, ["Bowl_Full", "Bucket", "Bowl_Full"][k], Vector3(q.x + cos(rot) * (k - 1) * 0.7, py + 0.84, q.y - sin(rot) * (k - 1) * 0.7), 0.0, 1.2)
				Kit.dungeon(root, "Barrel_Open", Vector3(q.x - sin(rot) * 1.3, py, q.y - cos(rot) * 1.3), 0.0, 1.0)
				_sign(root, q, rot, 2.4, "Poissonnerie")
			_:
				Town.house(g, q, rng.randf_range(6.5, 7.5), rng.randf_range(5.5, 6.2), rot, 1 if rng.randf() < 0.6 else 2, ["chaume", "tuile", "chaume"][rng.randi() % 3], rng, ["crepi", "pierre_base"][rng.randi() % 2])
	# place centrale : puits et étals épars
	Kit.village(root, "Prop_Well_Cobblestone", Vector3(c.x + sin(face) * 6.0, Terrain.height_at(c.x + sin(face) * 6.0, c.y + cos(face) * 6.0), c.y + cos(face) * 6.0), face, 1.3)
	_people[gid] = []
	_settle(world, gid, c, spots, rng)

func _near_town_house(q: Vector2) -> bool:
	for h in Town.houses:
		if (h[0] as Vector2).distance_to(q) < float(h[1]) + 7.0:
			return true
	return false

## Échoppe ouverte : poteaux et auvent
func _shed(g: Geo, q: Vector2, rot: float, w: float, d: float, roof: String) -> void:
	var b := Basis(Vector3.UP, rot)
	var y := Terrain.height_at(q.x, q.y)
	for cx in [-w * 0.5, w * 0.5]:
		for cz in [-d * 0.5, d * 0.5]:
			var p: Vector3 = Vector3(q.x, y, q.y) + b * Vector3(cx, 0, cz)
			g.box("bois_sombre", Vector3(p.x, Terrain.height_at(p.x, p.z) + 1.4, p.z), Vector3(0.22, 2.9, 0.22), rot, true)
	g.hip_roof(roof, Vector3(q.x, y + 2.8, q.y), w * 0.6, d * 0.6, 1.1, rot)
	g.box("terre", Vector3(q.x, y + 0.04, q.y), Vector3(w, 0.08, d), rot, false)

func _front(root: Node3D, q: Vector2, rot: float, dist: float, prop: String, sc: float) -> void:
	var p := q + Vector2(sin(rot), cos(rot)) * dist
	Kit.dungeon(root, prop, Vector3(p.x, Terrain.height_at(p.x, p.y), p.y), rot, sc)

func _sign(root: Node3D, q: Vector2, rot: float, dist: float, txt: String) -> void:
	var p := q + Vector2(sin(rot), cos(rot)) * dist
	var l := Label3D.new()
	l.text = txt
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 48
	l.outline_size = 10
	l.pixel_size = 0.01
	l.modulate = Color(1.0, 0.85, 0.6)
	l.visibility_range_end = 30.0
	root.get_parent().add_child(l)
	l.position = Vector3(p.x, Terrain.height_at(p.x, p.y) + 3.4, p.y)

func _fire(root: Node3D, at: Vector3, r: float) -> void:
	var fire := FX.particles("flame_01", 12, 0.6, [Color(1, 0.9, 0.5, 0.0), Color(1.0, 0.5, 0.15), Color(0.3, 0.1, 0.05, 0)], 0.7, false)
	fire.direction = Vector3.UP
	fire.initial_velocity_min = 0.6
	fire.initial_velocity_max = 1.2
	fire.gravity = Vector3(0, 0.4, 0)
	fire.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	fire.emission_sphere_radius = r
	fire.visibility_range_end = 55.0
	root.get_parent().add_child(fire)
	fire.position = at
	fire.emitting = true
	_lamp(root, Vector2(at.x, at.z), Color(1.0, 0.55, 0.25))

func _lamp(root: Node3D, q: Vector2, col: Color) -> void:
	var l := OmniLight3D.new()
	l.light_color = col
	l.light_energy = 1.6
	l.omni_range = 7.0
	l.distance_fade_enabled = true
	l.distance_fade_begin = 35.0
	l.distance_fade_length = 8.0
	root.get_parent().add_child(l)
	l.position = Vector3(q.x, Terrain.height_at(q.x, q.y) + 2.2, q.y)

## Habitants : artisans à leur poste, passants qui vont de l'un à l'autre
func _settle(world: Node3D, gid: String, c: Vector2, spots: Dictionary, rng: RandomNumberGenerator) -> void:
	var jobs := [["forge", "Forgeron", "paysan_h", "Fixing_Kneeling"], ["taverne", "Tavernière", "paysan_f", "Idle_Talking"],
		["boucherie", "Boucher", "paysan_h", "Idle"], ["poissonnerie", "Poissonnière", "paysan_f", "Idle_Talking"]]
	var noms_h := ["Gaspard", "Rufus", "Bastien", "Corentin", "Jacquot", "Mathurin"]
	var noms_f := ["Margot", "Ysaline", "Berthe", "Agnès", "Mahaut", "Pernelle"]
	var k := 0
	for j in jobs:
		if not spots.has(j[0]):
			continue
		var q: Vector2 = spots[j[0]][0]
		var rot: float = spots[j[0]][1]
		var p := q + Vector2(sin(rot), cos(rot)) * (2.2 if j[0] != "taverne" else 5.0)
		var fem: bool = j[2] == "paysan_f"
		var v := Villager.new()
		v.spec = {"outfit": j[2], "female": fem, "hair": "Hair_Long" if fem else "Hair_Buzzed", "beard": not fem and rng.randf() < 0.6, "tint": Color(0.55, 0.47, 0.4)}
		v.anim_name = j[3]
		world.add_child(v)
		v.position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		v.rotation.y = rot + PI
		var nom: String = (noms_f if fem else noms_h)[(k + absi(gid.hash())) % 6]
		v.set_meta("talk", {"id": "%s_civ_%d" % [gid, k], "nom": "%s le %s" % [nom, String(j[1]).to_lower()] if not fem else "%s la %s" % [nom, String(j[1]).to_lower()], "role": "brigand_civil"})
		_people[gid].append(v)
		k += 1
	# passants : de la place aux échoppes, en boucle
	var keys := spots.keys()
	for i in 3:
		if keys.size() < 2:
			break
		var a: Vector2 = spots[keys[(i * 2) % keys.size()]][0]
		var b: Vector2 = spots[keys[(i * 2 + 3) % keys.size()]][0]
		var fem := i == 1
		var v := Villager.new()
		v.spec = {"outfit": "paysan_f" if fem else "paysan_h", "female": fem, "hair": "Hair_Long" if fem else "Hair_SimpleParted", "tint": Color(0.6, 0.5, 0.42)}
		v.path = [c.lerp(a, 0.6), c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3)), c.lerp(b, 0.6), c + Vector2(rng.randf_range(-3, 3), rng.randf_range(-3, 3))]
		v.speed = 1.1
		world.add_child(v)
		v.set_meta("talk", {"id": "%s_civ_%d" % [gid, k], "nom": (noms_f if fem else noms_h)[(k + 3) % 6], "role": "brigand_civil"})
		_people[gid].append(v)
		k += 1

## Village rasé : les habitants prennent la route et disparaissent
func _process(delta: float) -> void:
	_acc += delta
	if _acc < 2.0:
		return
	_acc = 0.0
	for gid in _people:
		if String(CampParley._st().get(gid, "")) != "rase":
			continue
		var c: Vector2 = CampParley.zone(gid)["pos"]
		for v in _people[gid]:
			if is_instance_valid(v) and not v.captive:
				var out := c + (Vector2(v.global_position.x, v.global_position.z) - c).normalized() * 60.0
				v.leave([out])
		_people[gid] = []

static func people(gid: String) -> Array:
	if inst == null or not inst._people.has(gid):
		return []
	return inst._people[gid].filter(func(v): return is_instance_valid(v))
