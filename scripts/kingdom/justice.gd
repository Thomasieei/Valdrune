class_name Justice
## Autorité du seigneur sur ses sujets : agenouillement, récompense, protection d'une maison,
## bannissement, arrestation (deux gardes escortent réellement l'habitant jusqu'à la prison de la cour),
## puis libération, procès, travaux forcés ou exécution. Chaque acte pèse sur les jauges
## (bienveillance, autorité, crainte, confiance des habitants) et est consigné dans les rapports.

const Y0 := 12.0
const FL := 7.4                                   # sol des cachots (4,6 m sous la cour)
const ROOM_MIN := Vector2(-38.0, -125.0)          # salle souterraine sous la cour, côté caserne
const ROOM_MAX := Vector2(-28.0, -115.0)
const STAIR_X := Vector2(-34.6, -31.4)            # escalier (tranchée) de la cour vers les cachots
const STAIR_TOP_Z := -104.0
const CELL_DOOR := Vector3(-33.0, 7.4, -118.6)    # couloir devant les cellules
const STAIR_TOP := Vector3(-33.0, 12.0, -101.5)
const STAIR_BOTTOM := Vector3(-33.0, 7.4, -116.0)
const STAIR_EDGE := Vector3(-33.0, 12.0, -104.0)    # première marche (haut)
const STAIR_FOOT := Vector3(-33.0, 7.4, -115.1)     # dernière marche (bas)
const EXIT_SOUTH := [Vector2(0, -20), Vector2(6, 20), Vector2(24, 62), Vector2(28, 90)]

static var _built := false
static var lights: Array = []

static func world() -> Node3D:
	return (Engine.get_main_loop() as SceneTree).current_scene

static func act(text: String) -> void:
	GameState.get_inst().report(text, "acte")

## Zone creusée dans le relief (Layout.height) : salle + tranchée de l'escalier, avec une marge pour les pentes du maillage
static func dug(p: Vector2) -> bool:
	var room := p.x > ROOM_MIN.x - 3.0 and p.x < ROOM_MAX.x + 3.0 and p.y > ROOM_MIN.y - 3.0 and p.y < ROOM_MAX.y + 3.0
	var trench := p.x > STAIR_X.x - 3.0 and p.x < STAIR_X.y + 3.0 and p.y > ROOM_MAX.y and p.y < STAIR_TOP_Z + 2.5
	return room or trench

static func in_cellar(p: Vector3) -> bool:
	return p.y < Y0 - 1.2 and dug(Vector2(p.x, p.z))

# ------------------------------------------------------------------ les cachots (sous la cour du château)
static func build_prison(parent: Node3D) -> void:
	if _built:
		return
	_built = true
	var root := Node3D.new()
	root.name = "Cachots"
	parent.add_child(root)
	var stone := _tri("pierre_base", 0.35)
	var wallm := _tri("pierre", 0.3)
	var floorm := _tri("dallage", 0.35)
	var vault := _tri("pierre", 0.25)
	var paving := _tri("paves", 0.3)
	var iron := StandardMaterial3D.new()
	iron.albedo_color = Color(0.13, 0.13, 0.15)
	iron.metallic = 0.4
	iron.roughness = 0.55
	var body := StaticBody3D.new()
	body.collision_layer = 2
	root.add_child(body)
	var cx := (ROOM_MIN.x + ROOM_MAX.x) * 0.5
	var cz := (ROOM_MIN.y + ROOM_MAX.y) * 0.5
	var w := ROOM_MAX.x - ROOM_MIN.x
	var d := ROOM_MAX.y - ROOM_MIN.y
	var hh := Y0 - FL
	var t := 0.6
	# sol, murs, plafond de la salle
	_box(root, body, Vector3(cx, FL - 0.2, cz), Vector3(w + 2 * t, 0.4, d + 2 * t), floorm, true)
	_box(root, body, Vector3(ROOM_MIN.x - t * 0.5, FL + hh * 0.5, cz), Vector3(t, hh, d + 2 * t), wallm, true)
	_box(root, body, Vector3(ROOM_MAX.x + t * 0.5, FL + hh * 0.5, cz), Vector3(t, hh, d + 2 * t), wallm, true)
	_box(root, body, Vector3(cx, FL + hh * 0.5, ROOM_MIN.y - t * 0.5), Vector3(w, hh, t), wallm, true)
	# mur sud percé pour l'escalier
	var lw := STAIR_X.x - ROOM_MIN.x
	_box(root, body, Vector3(ROOM_MIN.x + lw * 0.5, FL + hh * 0.5, ROOM_MAX.y + t * 0.5), Vector3(lw, hh, t), wallm, true)
	var rw := ROOM_MAX.x - STAIR_X.y
	_box(root, body, Vector3(STAIR_X.y + rw * 0.5, FL + hh * 0.5, ROOM_MAX.y + t * 0.5), Vector3(rw, hh, t), wallm, true)
	# voûte : dalle pavée au niveau de la cour, couvrant toute la zone creusée sauf l'escalier
	var dmin := Vector2(ROOM_MIN.x - 3.2, ROOM_MIN.y - 3.2)
	var dmax := Vector2(ROOM_MAX.x + 3.2, ROOM_MAX.y + 3.2)
	_box(root, body, Vector3((dmin.x + dmax.x) * 0.5, Y0 - 0.25, (dmin.y + ROOM_MAX.y) * 0.5), Vector3(dmax.x - dmin.x, 0.5, ROOM_MAX.y - dmin.y), paving, true)
	var tz0 := ROOM_MAX.y
	var tz1 := STAIR_TOP_Z + 2.7
	for side in [[dmin.x, STAIR_X.x - 0.5], [STAIR_X.y + 0.5, dmax.x]]:
		_box(root, body, Vector3((side[0] + side[1]) * 0.5, Y0 - 0.25, (tz0 + tz1) * 0.5), Vector3(side[1] - side[0], 0.5, tz1 - tz0), paving, true)
	_box(root, body, Vector3((STAIR_X.x + STAIR_X.y) * 0.5, Y0 - 0.25, (STAIR_TOP_Z + tz1) * 0.5), Vector3(STAIR_X.y - STAIR_X.x + 1.0, 0.5, tz1 - STAIR_TOP_Z), paving, true)
	# voûte de pierre vue d'en dessous
	_box(root, body, Vector3(cx, Y0 - 0.56, cz), Vector3(w + 2 * t, 0.12, d + 2 * t), vault, false)
	for k in 4:
		_box(root, body, Vector3(cx, Y0 - 0.85, ROOM_MIN.y + 1.0 + k * 2.7), Vector3(w, 0.45, 0.5), stone, false)
	# murs de la tranchée + parapet bien visible depuis la cour
	var tlen := STAIR_TOP_Z - ROOM_MAX.y
	for x in [STAIR_X.x - 0.25, STAIR_X.y + 0.25]:
		_box(root, body, Vector3(x, (FL + Y0 + 0.9) * 0.5, (ROOM_MAX.y + STAIR_TOP_Z) * 0.5), Vector3(0.5, Y0 + 0.9 - FL, tlen), wallm, true)
		_box(root, body, Vector3(x, Y0 + 1.0, (ROOM_MAX.y + STAIR_TOP_Z) * 0.5), Vector3(0.65, 0.2, tlen + 0.2), stone, false)
	_box(root, body, Vector3((STAIR_X.x + STAIR_X.y) * 0.5, Y0 + 0.45, ROOM_MAX.y - 0.1), Vector3(STAIR_X.y - STAIR_X.x + 1.0, 0.9, 0.5), wallm, true)
	# escalier : marches visibles + rampe invisible pour marcher sans accroc
	var steps := 16
	var run := tlen / steps
	var rise := hh / steps
	for i in steps:
		var z := ROOM_MAX.y + (i + 0.5) * run
		var top := FL + (i + 1) * rise
		_box(root, body, Vector3((STAIR_X.x + STAIR_X.y) * 0.5, top - 0.5 * (top - FL + 0.2) + 0.0, z), Vector3(STAIR_X.y - STAIR_X.x, top - FL + 0.2, run), stone, false)
	var ramp := CollisionShape3D.new()
	var rs := BoxShape3D.new()
	var rl := sqrt(tlen * tlen + hh * hh)
	rs.size = Vector3(STAIR_X.y - STAIR_X.x, 0.3, rl + 0.4)
	ramp.shape = rs
	ramp.position = Vector3((STAIR_X.x + STAIR_X.y) * 0.5, (FL + Y0) * 0.5 - 0.1, (ROOM_MAX.y + STAIR_TOP_Z) * 0.5)
	ramp.rotation.x = atan2(hh, tlen)
	body.add_child(ramp)
	# portique d'entrée et enseigne
	for x in [STAIR_X.x - 0.45, STAIR_X.y + 0.45]:
		_box(root, body, Vector3(x, Y0 + 1.6, STAIR_TOP_Z + 0.2), Vector3(0.8, 3.2, 0.8), stone, true)
	_box(root, body, Vector3((STAIR_X.x + STAIR_X.y) * 0.5, Y0 + 3.4, STAIR_TOP_Z + 0.2), Vector3(STAIR_X.y - STAIR_X.x + 2.0, 0.6, 0.9), stone, false)
	var lbl := Label3D.new()
	lbl.text = "CACHOTS"
	lbl.font_size = 96
	lbl.outline_size = 18
	lbl.pixel_size = 0.0045
	lbl.modulate = Color(1, 0.88, 0.6)
	lbl.outline_modulate = Color(0.1, 0.06, 0.03)
	lbl.position = Vector3((STAIR_X.x + STAIR_X.y) * 0.5, Y0 + 3.4, STAIR_TOP_Z + 0.7)
	root.add_child(lbl)
	# cellules : murs de séparation, barreaux espacés, portes à barreaux
	var cell_w := w / 3.0
	var bars_z := ROOM_MIN.y + 4.0
	for k in [1, 2]:
		var x: float = ROOM_MIN.x + k * cell_w
		_box(root, body, Vector3(x, FL + hh * 0.5, (ROOM_MIN.y + bars_z) * 0.5), Vector3(0.35, hh, bars_z - ROOM_MIN.y), wallm, true)
	_box(root, body, Vector3(cx, FL + 0.08, bars_z), Vector3(w, 0.16, 0.22), iron, false)
	_box(root, body, Vector3(cx, FL + 2.7, bars_z), Vector3(w, 0.16, 0.22), iron, false)
	var bar_col := CollisionShape3D.new()
	var bcs := BoxShape3D.new()
	bcs.size = Vector3(w, 2.8, 0.2)
	bar_col.shape = bcs
	bar_col.position = Vector3(cx, FL + 1.4, bars_z)
	body.add_child(bar_col)
	var nb := int(w / 0.34)
	for i in nb + 1:
		var x := ROOM_MIN.x + i * (w / nb)
		_box(root, body, Vector3(x, FL + 1.4, bars_z), Vector3(0.07, 2.7, 0.07), iron, false)
	for k in 3:
		var dx := ROOM_MIN.x + (k + 0.5) * cell_w
		for x in [dx - 0.6, dx + 0.6]:
			_box(root, body, Vector3(x, FL + 1.4, bars_z + 0.06), Vector3(0.14, 2.8, 0.14), iron, false)
		_box(root, body, Vector3(dx, FL + 1.3, bars_z + 0.08), Vector3(0.18, 0.18, 0.08), iron, false)
		# paillasse dans chaque cellule
		_box(root, body, Vector3(dx - 0.6, FL + 0.12, ROOM_MIN.y + 1.0), Vector3(1.4, 0.2, 0.9), _tri("bois", 0.6), false)
	# mobilier du geôlier
	Kit.dungeon(root, "Table_Small", Vector3(-30.0, FL, -116.6), 0.0, 1.0)
	Kit.dungeon(root, "Bench", Vector3(-36.5, FL, -116.4), 0.0, 1.0)
	Kit.dungeon(root, "Bucket", Vector3(-37.2, FL, -118.0), 0.0, 1.0)
	Kit.dungeon(root, "Key_Rusty", Vector3(-30.0, FL + 0.82, -116.6), 0.4, 1.4)
	# torches murales et lumière chaude (allumées seulement quand on descend)
	lights.clear()
	for tp in [Vector3(-37.6, FL + 2.2, -117.5), Vector3(-28.4, FL + 2.2, -117.5), Vector3(-33.0, FL + 2.4, -115.4)]:
		var tw := Kit.dungeon(root, "Torch_Wall", tp, 0.0, 1.0)
		if tp.x < -35.0:
			tw.rotation.y = PI / 2.0
		elif tp.x > -30.0:
			tw.rotation.y = -PI / 2.0
		var f := FX.particles("flame_01", 8, 0.5, [Color(1, 0.8, 0.4, 0.9), Color(1, 0.35, 0.1, 0)], 0.35, false)
		f.direction = Vector3.UP
		f.initial_velocity_min = 0.3
		f.initial_velocity_max = 0.7
		f.gravity = Vector3.ZERO
		root.add_child(f)
		f.position = tp + Vector3.UP * 0.45
		f.emitting = true
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.65, 0.35)
		l.light_energy = 2.2
		l.omni_range = 9.0
		l.shadow_enabled = false
		l.position = tp + Vector3.UP * 0.5
		l.visible = false
		root.add_child(l)
		lights.append(l)
	for x in [STAIR_X.x - 0.45, STAIR_X.y + 0.45]:
		var tt := Kit.dungeon(root, "Torch", Vector3(x, Y0 + 3.2, STAIR_TOP_Z + 0.65), 0.0, 1.0)
	# un seul maillage par matériau
	var vis := Node3D.new()
	root.add_child(vis)
	for c2 in root.get_children():
		if c2 is MeshInstance3D:
			c2.reparent(vis)
	Batcher.merge(vis, false)
	# zone : en descendant, caméra rapprochée et éclairage souterrain
	var area := Area3D.new()
	area.name = "ZoneCachots"
	area.collision_layer = 0
	area.collision_mask = 8
	var acs := CollisionShape3D.new()
	var abs := BoxShape3D.new()
	abs.size = Vector3(w, hh - 0.8, d + 6.0)
	acs.shape = abs
	acs.position = Vector3(cx, FL + (hh - 0.8) * 0.5, cz + 3.0)
	area.add_child(acs)
	root.add_child(area)
	area.body_entered.connect(func(b): if b == Combat.player and world().has_method("set_cellar"): world().set_cellar(true))
	area.body_exited.connect(func(b): if b == Combat.player and world().has_method("set_cellar"): world().set_cellar(false))
	# le geôlier
	var jailer := Guard.new()
	jailer.position = Vector3(-29.4, FL, -117.2)
	jailer.rotation.y = PI * 0.85
	parent.add_child(jailer)
	jailer.set_meta("talk", {"id": "geolier", "nom": "Mathis le geôlier", "role": "garde"})
	# les prisonniers enregistrés reprennent leur place
	for pr in Kingdom.k()["prisonniers"]:
		_spawn_prisoner(pr)

static func _tri(name: String, sc: float) -> StandardMaterial3D:
	var m: StandardMaterial3D = Geo.mat(name).duplicate()
	m.uv1_triplanar = true
	m.uv1_world_triplanar = true
	m.uv1_scale = Vector3.ONE * sc
	return m

static func _box(root: Node3D, body: StaticBody3D, pos: Vector3, size: Vector3, mat: Material, col: bool) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = size
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	root.add_child(mi)
	if col:
		var cs := CollisionShape3D.new()
		var sh := BoxShape3D.new()
		sh.size = size
		cs.shape = sh
		cs.position = pos
		body.add_child(cs)

## Place dans les cellules (3 cellules, 2 rangs), assez près des barreaux pour parler depuis le couloir
static func _cell_spot(i: int) -> Vector3:
	var cell_w := (ROOM_MAX.x - ROOM_MIN.x) / 3.0
	return Vector3(ROOM_MIN.x + ((i % 3) + 0.5) * cell_w + (0.5 if i >= 3 else -0.3), FL + 0.05, ROOM_MIN.y + 2.9 - float(i / 3 % 2) * 1.3)

static func _spawn_prisoner(pr: Dictionary) -> Villager:
	var v := Villager.new()
	v.spec = {"female": pr.get("fem", false), "outfit": pr.get("outfit", "paysan_h"), "tint": Color(0.75, 0.72, 0.68), "beard": pr.get("captif", false)}
	v.anim_name = "Idle"
	world().add_child(v)
	var i: int = Kingdom.k()["prisonniers"].find(pr)
	v.global_position = _cell_spot(maxi(i, 0))
	v.rotation.y = 0.0
	v.captive = true
	v.set_meta("talk", {"id": pr["id"], "nom": pr["nom"], "role": "prisonnier"})
	return v

static func prisoner_record(id: String) -> Dictionary:
	for pr in Kingdom.k()["prisonniers"]:
		if pr["id"] == id:
			return pr
	return {}

# ------------------------------------------------------------------ actes envers un habitant
static func kneel(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	m["agenouille"] = int(m.get("agenouille", 0)) + 1
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	m["relation"] = int(m.get("relation", 0)) - (1 if int(m["agenouille"]) == 1 else 4)
	if int(m["agenouille"]) >= 2:
		gs.add("confiance_habitants", -1)
	if n.has_method("kneel"):
		n.kneel(5.0)
	elif n.has_method("react"):
		n.react("Fixing_Kneeling", 5.0)
	FX.bark(n, "Oui… mon seigneur." if int(m["agenouille"]) == 1 else "Encore… ? Comme vous voudrez.", 2.3, 3.0)
	act("Vous avez fait agenouiller %s devant vous." % t["nom"])

static func reward(n: Node3D) -> String:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	var day := int(Kingdom.res("jour")) if Kingdom.inst else 0
	if int(m.get("recompense_jour", -1)) == day:
		return "Vous l'avez déjà récompensé aujourd'hui"
	var prog := Progression.get_inst()
	if prog.gold < 25:
		return "Il vous faut 25 pièces d'or"
	prog.add_gold(-25)
	m["recompense_jour"] = day
	m["relation"] = int(m.get("relation", 0)) + 6
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 2)
	gs.add("reputation", 1)
	if n.has_method("nod"):
		n.nod()
	FX.bark(n, "Merci, {titre} ! Ma famille ne l'oubliera pas.".replace("{titre}", gs.titre), 2.3, 3.0)
	act("Vous avez donné 25 pièces d'or à %s et sa famille pour sa loyauté." % t["nom"])
	return ""

## Un soldat part réellement veiller sur la maison de l'habitant
static func protect_house(n: Node3D) -> String:
	if Escort.available() <= 0 and int(Kingdom.res("soldats")) < 3:
		return "Aucun soldat disponible"
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var m := gs.mem(t["id"])
	var s := Soldier.new()
	s.nom = Kingdom.data()["pnj"]["noms_h"][randi() % 12]
	s.home = Escort.GATE
	world().add_child(s)
	var p := Combat.player
	var from: Vector3 = p.global_position - p.global_transform.basis.z * 12.0 if p.global_position.distance_to(Escort.GATE) > 60.0 else Escort.GATE
	from.y = Terrain.height_at(from.x, from.z) + 0.3
	s.global_position = from
	var spot: Vector3 = n.global_position + Vector3(1.8, 0, 1.2)
	spot.y = Terrain.height_at(spot.x, spot.z)
	s.go_to(spot)
	s.get_tree().create_timer(180.0).timeout.connect(func(): if is_instance_valid(s): s.send_home())
	m["peur"] = false
	m["relation"] = int(m.get("relation", 0)) + 6
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 3)
	act("Vous avez envoyé le soldat %s veiller sur la maison de %s." % [s.nom, t["nom"]])
	return ""

static func banish(n: Node3D, raison: String) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	var bl: Array = gs.flags.get("bannis", [])
	bl.append(t["id"])
	gs.flags["bannis"] = bl
	gs.add("autorite", 3)
	gs.add("crainte", 4)
	gs.add("bienveillance", -3)
	gs.add("confiance_habitants", -3)
	if Kingdom.inst:
		Kingdom.add("population", -1)
	n.remove_from_group("pnj")
	n.remove_meta("talk")
	FX.bark(n, "Très bien… je pars.", 2.3, 3.0)
	if n is Villager:
		var pts := [Vector2(n.global_position.x, n.global_position.z)]
		pts.append_array(EXIT_SOUTH)
		n.leave(pts)
	else:
		n.queue_free()
	act("Vous avez banni %s du royaume (%s)." % [t["nom"], raison])

## Arrestation : deux gardes viennent chercher l'habitant et l'escortent jusqu'à la prison
static func arrest(n: Node3D, raison: String) -> void:
	var t: Dictionary = n.get_meta("talk")
	var gs := GameState.get_inst()
	gs.add("autorite", 3)
	gs.add("crainte", 5)
	gs.add("confiance_habitants", -2)
	var fem: bool = n is Villager and bool(n.spec.get("female", false))
	var outfit: String = String(n.spec.get("outfit", "paysan_h")) if n is Villager else "rodeur_h"
	var rec := {"id": t["id"], "nom": t["nom"], "role": t["role"], "raison": raison, "fem": fem, "outfit": outfit, "jour": int(Kingdom.res("jour")) if Kingdom.inst else 1}
	n.remove_from_group("pnj")
	n.set_meta("talk", {"id": t["id"], "nom": t["nom"], "role": "escorte_prison"})
	if n is Villager:
		n.captive = true
	FX.bark(n, "Quoi ?! Non, attendez !", 2.3, 3.0)
	act("Vous avez fait arrêter %s (%s)." % [t["nom"], raison])
	var guards := []
	var p := Combat.player
	for i in 2:
		var s := Soldier.new()
		s.nom = Kingdom.data()["pnj"]["noms_h"][(i * 5 + randi()) % 12]
		s.home = Escort.GATE
		s.slot = i
		world().add_child(s)
		var from: Vector3 = p.global_position - p.global_transform.basis.z * 8.0 + Vector3(i * 1.5, 0, 0)
		from.y = Terrain.height_at(from.x, from.z) + 0.3
		s.global_position = from
		var spot: Vector3 = n.global_position + Vector3(-1.0 + i * 2.0, 0, 0.8)
		s.go_to(spot)
		guards.append(s)
	var lead: Soldier = guards[0]
	lead.arrived.connect(func():
		if lead.mode != Soldier.M.GARDER and lead.mode != Soldier.M.ALLER:
			return
		lead.say("Au nom du seigneur, suis-nous.", 2.5)
		if n is Villager:
			n.react("Walk", 999.0)
		var path := _path_to_prison(n.global_position)
		for g in guards:
			if is_instance_valid(g):
				g.prisoner = n
				g.mode = Soldier.M.ESCORTE_PRISONNIER
				g.goal = path[0] + Vector3(g.slot * 1.4, 0, 0)
				g.set_meta("chemin", path)
		_walk_escort(guards, path, 0, n, rec), CONNECT_ONE_SHOT)

## Trajet à pied jusqu'à la prison : route du bourg, porte du château, cour
static func _path_to_prison(from: Vector3) -> Array:
	var pts := []
	if from.z > -86.0:
		for q in [Vector2(0, -48), Vector2(0, -70), Vector2(0, -92)]:
			if from.z > q.y:
				pts.append(Vector3(q.x, Terrain.height_at(q.x, q.y), q.y))
	pts.append(Vector3(-20, 12.0, -106))
	pts.append(STAIR_TOP)
	pts.append(STAIR_EDGE)
	pts.append(STAIR_FOOT)
	pts.append(STAIR_BOTTOM)
	pts.append(CELL_DOOR)
	return pts

static func _walk_escort(guards: Array, path: Array, i: int, n: Node3D, rec: Dictionary) -> void:
	var lead: Soldier = guards[0]
	if not is_instance_valid(lead) or lead.cbt.dead:
		return
	if i >= path.size():
		# arrivée : le prisonnier entre dans la cellule
		var prs: Array = Kingdom.k()["prisonniers"]
		prs.append(rec)
		GameState.get_inst().mark()
		if is_instance_valid(n):
			n.global_position = _cell_spot(prs.size() - 1)
			n.rotation.y = 0.0
			n.set_meta("talk", {"id": rec["id"], "nom": rec["nom"], "role": "prisonnier"})
			if n is Villager:
				n.react("Idle", 0.1)
		for g in guards:
			if is_instance_valid(g):
				g.prisoner = null
				g.send_home()
		GameState.get_inst().report("%s a été enfermé(e) à la prison du château." % rec["nom"], "acte")
		return
	for g in guards:
		if is_instance_valid(g):
			g.goal = path[i] + Vector3(g.slot * 1.4, 0, 0)
			g.mode = Soldier.M.ESCORTE_PRISONNIER
	lead.arrived.connect(func(): _walk_escort(guards, path, i + 1, n, rec), CONNECT_ONE_SHOT)

# ------------------------------------------------------------------ décisions sur un prisonnier
static func _remove_record(id: String) -> Dictionary:
	var prs: Array = Kingdom.k()["prisonniers"]
	for pr in prs:
		if pr["id"] == id:
			prs.erase(pr)
			GameState.get_inst().mark()
			return pr
	return {}

static func release(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	var pr := _remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("bienveillance", 2)
	gs.add("confiance_habitants", 2)
	var m := gs.mem(t["id"])
	m["relation"] = int(m.get("relation", 0)) + 3
	FX.bark(n, "Merci… merci, {titre}.".replace("{titre}", gs.titre), 2.3, 3.0)
	n.global_position = STAIR_TOP
	n.set_meta("talk", {"id": t["id"], "nom": t["nom"], "role": String(pr.get("role", "habitant"))})
	if n is Villager:
		n.leave([Vector2(-20, -100), Vector2(0, -92), Vector2(0, -60), Vector2(2, -30)])
	act("Vous avez libéré %s." % t["nom"])

static func forced_labor(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	gs.add("confiance_habitants", -1)
	if Kingdom.inst:
		Kingdom.add("pierre", 15)
	FX.bark(n, "La mine… pour combien de temps ?", 2.3, 3.0)
	if n is Villager:
		n.global_position = STAIR_TOP
		n.leave([Vector2(-20, -100), Vector2(0, -92), Vector2(30, -92), Vector2(58, -120), Vector2(125, -140)])
	act("%s est condamné(e) aux travaux forcés à la mine." % t["nom"])

static func execute(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("bienveillance", -6)
	gs.add("crainte", 8)
	gs.add("autorite", 3)
	gs.add("confiance_habitants", -6)
	gs.add("reputation", -3)
	if Kingdom.inst:
		Kingdom.add("population", -1)
		Kingdom.add("moral", -4)
	n.remove_meta("talk")
	# mise en scène sobre : les gardes l'emmènent, il disparaît dans l'ombre de la caserne
	if n is Villager:
		n.global_position = STAIR_TOP
		n.leave([Vector2(-40, -100), Vector2(-44, -97)])
	act("Vous avez ordonné l'exécution de %s. Le bourg l'apprendra." % t["nom"])

static func exile_prisoner(n: Node3D) -> void:
	var t: Dictionary = n.get_meta("talk")
	_remove_record(t["id"])
	var gs := GameState.get_inst()
	gs.add("autorite", 2)
	gs.add("crainte", 2)
	if Kingdom.inst:
		Kingdom.add("population", -1)
	var bl: Array = gs.flags.get("bannis", [])
	bl.append(t["id"])
	gs.flags["bannis"] = bl
	n.remove_meta("talk")
	if n is Villager:
		n.global_position = STAIR_TOP
		var pts := [Vector2(-20, -100), Vector2(0, -92)]
		pts.append_array(EXIT_SOUTH)
		n.leave(pts)
	act("%s est exilé(e) de Valmont après son procès." % t["nom"])

# ------------------------------------------------------------------ dialogues (options ajoutées par Talk)
static func add_options(nodes: Dictionary, choices: Array, who: String, label: String, n: Node3D, role: String) -> void:
	var gs := GameState.get_inst()
	var t: Dictionary = n.get_meta("talk")
	var m := gs.mem(t["id"])
	if role == "prisonnier":
		var pr := prisoner_record(t["id"])
		nodes["menu"]["text"] = "%s (motif : %s). Que décidez-vous, %s ?" % ["Pitié… je n'ai rien fait de mal" if gs.val("crainte") < 10 else "Je… je ferai ce que vous voudrez", pr.get("raison", "inconnu"), gs.titre]
		choices.clear()
		choices.append({"text": "Je te libère. Rentre chez toi.", "tone": "bienveillance", "next": "END", "callback": func(): release(n)})
		choices.append({"text": "Tu seras jugé publiquement.", "tone": "diplomatie", "next": "proces"})
		choices.append({"text": "Aux travaux forcés, à la mine.", "tone": "autorite", "next": "END", "callback": func(): forced_labor(n)})
		choices.append({"text": "Qu'on l'exécute.", "tone": "arrogance", "next": "exec"})
		choices.append({"text": "Pourrir ici te fera réfléchir.", "tone": "indifference", "next": "END"})
		Capture.add_options(nodes, choices, n, pr)
		nodes["proces"] = {"who": "conseil", "nom": "Procès devant le bourg", "text": "Les habitants se rassemblent dans la cour. %s est accusé(e) : %s. Le verdict vous appartient." % [t["nom"], pr.get("raison", "")],
			"choices": [
				{"text": "Innocent. Il est libre.", "tone": "bienveillance", "next": "END", "callback": func():
					gs.add("reputation", 2)
					release(n)},
				{"text": "Coupable : l'exil.", "tone": "autorite", "next": "END", "callback": func(): exile_prisoner(n)},
				{"text": "Coupable : il reste au cachot.", "tone": "autorite", "next": "END", "callback": func():
					gs.add("autorite", 1)
					act("Le procès de %s s'achève : il reste au cachot." % t["nom"])},
			]}
		nodes["exec"] = {"who": "conseil", "nom": "Le capitaine de la garde", "text": "Mon seigneur… vous êtes certain ? Le peuple s'en souviendra.",
			"choices": [
				{"text": "Exécutez l'ordre.", "tone": "autorite", "next": "END", "callback": func(): execute(n)},
				{"text": "Non. Pas aujourd'hui.", "tone": "bienveillance", "next": "END"},
			]}
		return
	if not Story.done() or role in ["roi", "elian", "soldat", "escorte_prison"]:
		return
	# demande d'aide : certains habitants ont peur des bandits
	if role in ["habitant", "paysan", "bucheron", "marchand"] and m.get("peur", false):
		nodes["peur"] = {"who": who, "nom": label, "text": String(Kingdom.data()["barks"]["peur_bandits"]).replace("{titre}", gs.titre),
			"choices": [
				{"text": "Je t'envoie un garde pour veiller sur ta maison.", "tone": "bienveillance", "next": "peur_ok", "callback": func():
					var e := protect_house(n)
					if e != "" and Hud.inst:
						Hud.inst.show_message(e, Color(1, 0.6, 0.5))},
				{"text": "Ferme bien ta porte. C'est tout.", "tone": "indifference", "next": "menu", "callback": func(): m["relation"] = int(m.get("relation", 0)) - 1},
			]}
		nodes["peur_ok"] = {"who": who, "nom": label, "text": "Merci, {titre}… je dormirai mieux ce soir.".replace("{titre}", gs.titre), "next": "menu"}
		choices.insert(0, {"text": "Tu sembles inquiet ?", "next": "peur"})
	var au: Dictionary = choices.pop_back()   # « Au revoir » reste en dernier
	choices.append({"text": "Ordres du seigneur…", "next": "ordres"})
	choices.append(au)
	var ord := []
	ord.append({"text": "À genoux devant ton seigneur !", "tone": "autorite", "next": "END", "callback": func(): kneel(n)})
	ord.append({"text": "Pour ta loyauté, voici 25 pièces pour ta famille.", "tone": "bienveillance", "cond": "or>=25", "next": "END", "callback": func():
		var e := reward(n)
		if e != "" and Hud.inst:
			Hud.inst.show_message(e, Color(1, 0.6, 0.5))})
	if n is Villager:
		ord.append({"text": "Quitte mon royaume. Tu es banni.", "tone": "arrogance", "next": "bannir"})
		ord.append({"text": "Gardes ! Arrêtez cet individu.", "tone": "autorite", "next": "arreter"})
	ord.append({"text": "Rien. Retourne à tes affaires.", "next": "menu"})
	nodes["ordres"] = {"who": who, "nom": label, "text": "Oui, {titre} ?".replace("{titre}", gs.titre), "choices": ord}
	var reasons := ["Tu m'as trahi.", "Je n'ai pas de comptes à te rendre.", "Tes paroles m'insultent.", "On t'a vu voler au marché."]
	var ban := []
	var arr := []
	for r in reasons:
		var rr: String = r
		ban.append({"text": rr, "next": "END", "callback": func(): banish(n, rr.trim_suffix("."))})
		arr.append({"text": rr, "next": "END", "callback": func(): arrest(n, rr.trim_suffix("."))})
	ban.append({"text": "… Non, oublie ça.", "next": "menu"})
	arr.append({"text": "… Non, oublie ça.", "next": "menu"})
	nodes["bannir"] = {"who": who, "nom": label, "text": "Banni ?! Mais pourquoi, {titre} ?".replace("{titre}", gs.titre), "choices": ban}
	nodes["arreter"] = {"who": who, "nom": label, "text": "M'arrêter ? Qu'est-ce que j'ai fait ?!", "choices": arr}
