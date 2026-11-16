class_name CityLife
extends Node
## Vie de la ville : civils, poursuites de monstres, police, réputation, mobilier urbain, voitures garées.

var main
var civs: Array = []
var police: Array = []
var chase := {}              # {"civ": Mob, "chasers": Array, "t": float}
var chase_t := 45.0
var comment_cd := 20.0
var police_cd := 25.0
var notoriety := 0           # incidents non réglés (civil mort...)
var spawn_t := 0.0
var props_root: Node3D
var alert_lbl: Label3D

const CIV_MODELS := ["civ_coolman", "civ_woman", "civ_rida", "civ_driver", "civ_manplayer"]
const CIV_NAMES := ["Passant", "Passante", "Passant", "Ouvrier", "Passant"]
const MOCK := ["Un chasseur de rang %s ? On est bien protégés...", "Pff. Encore un amateur qui joue au héros.", "Fais attention, petit chasseur, tu pourrais te blesser.", "C'est ça, l'élite de l'Association ?"]
const ADMIRE := ["C'est lui qui a sauvé des gens hier !", "Merci pour ce que vous faites, chasseur.", "Avec lui dans le quartier, je dors mieux."]
const POLICE_MOCK := ["Encore un rang %s qui se prend pour une légende...", "Laisse ça aux pros, gamin.", "Si tu te fais mal, appelle-nous. On rira."]
const POLICE_RESPECT := ["Respect, chasseur.", "Le quartier vous doit beaucoup.", "Bon travail."]
const RANK_ORDER := "EDCBAS"

func setup() -> void:
	props_root = Node3D.new()
	main.add_child(props_root)
	main.city_extras.append(props_root)
	_place_street_props()
	_place_parked_cars()
	_place_gate_barriers()
	_spawn_police()

func rank_ok() -> bool:
	return RANK_ORDER.find(main.hunter_rank) >= RANK_ORDER.find("B")

# ------------------------------------------------------------ mobilier urbain
func _wall_spots(count: int, rmin: float, rmax: float, avoid: Array) -> Array:
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var out: Array = []
	for tries in 260:
		if out.size() >= count:
			break
		var a := randf() * TAU
		var r := randf_range(rmin, rmax)
		var c: Vector3 = main.spawn_point + Vector3(sin(a), 0, cos(a)) * r
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 40, 0), c + Vector3(0, -20, 0)))
		if g.is_empty() or absf((g["position"] as Vector3).y - main.spawn_point.y) > 1.5:
			continue
		var fp: Vector3 = g["position"]
		var d := Vector3(sin(randf() * TAU), 0, cos(randf() * TAU)).normalized()
		var w := space.intersect_ray(PhysicsRayQueryParameters3D.create(fp + Vector3(0, 0.8, 0), fp + Vector3(0, 0.8, 0) + d * 5.0))
		if w.is_empty() or absf((w["normal"] as Vector3).y) > 0.3:
			continue
		var n: Vector3 = w["normal"]
		n.y = 0
		n = n.normalized()
		var p: Vector3 = (w["position"] as Vector3) + n * 0.7
		p.y = fp.y
		var ok := true
		for o in out:
			if (o[0] as Vector3).distance_to(p) < 4.0:
				ok = false
		for av in avoid:
			if (av as Vector3).distance_to(p) < 6.0:
				ok = false
		if ok:
			out.append([p, n])
	return out

func _prop(name_part: String, pos: Vector3, yaw: float, solid := true) -> Node3D:
	var pack := (load("res://assets/props.glb") as PackedScene).instantiate()
	var item: Node3D = null
	for c in pack.get_children():
		if str(c.name).contains(name_part):
			item = c
			break
	if item == null:
		pack.queue_free()
		return null
	pack.remove_child(item)
	pack.queue_free()
	props_root.add_child(item)
	item.global_position = pos
	item.rotation.y = yaw
	if solid:
		_add_box_collider(item)
	_no_shadow(item)
	return item

## Décor secondaire : pas d'ombre portée et masqué au loin (économise la carte graphique).
func _no_shadow(n: Node) -> void:
	for mi in n.find_children("*", "GeometryInstance3D", true, false):
		var g := mi as GeometryInstance3D
		g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		g.visibility_range_end = 55.0

func _add_box_collider(n: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = n.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	if first or aabb.size.x < 0.15 or aabb.size.z < 0.15:
		return
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = aabb.size
	cs.shape = bs
	cs.position = aabb.get_center()
	body.add_child(cs)
	n.add_child(body)

func _place_street_props() -> void:
	var avoid: Array = [main.spawn_point, main.shop_door_pos, main.gate_pos]
	var kinds := ["Bench_37", "Bench1_12", "Bin-1_6", "Bin-2_1", "BigBin_3", "Bin-4_7", "Garbage_8", "Carton_27", "ParkLight-1_0", "ParkLight-2_23", "Tree-1_29", "Tree-2_24", "FruitShop_26", "Post_33", "Bus_station_10", "CafeSign_9"]
	var spots := _wall_spots(22, 8.0, 60.0, avoid)
	var n := 0
	for s in spots:
		var p: Vector3 = s[0]
		var nn: Vector3 = s[1]
		var k: String = kinds[n % kinds.size()]
		var yaw := atan2(nn.x, nn.z)
		if _prop(k, p, yaw, not k.begins_with("Tree")):
			n += 1
	print("PROPS ", n)

## Barrières de police autour du portail.
func _place_gate_barriers() -> void:
	if main.gate_pos == Vector3.INF:
		return
	for k in 8:
		var a := k * TAU / 8.0 + 0.2
		var p: Vector3 = main.gate_pos + Vector3(sin(a), 0, cos(a)) * 9.5
		var g: Dictionary = main.get_world_3d().direct_space_state.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 20, 0), p + Vector3(0, -20, 0)))
		if g.is_empty():
			continue
		p.y = (g["position"] as Vector3).y
		if k % 4 == 1:
			continue
		_prop("Road-Ban-1" if k % 2 == 0 else "Police_line", p, a + PI * 0.5)

func _place_parked_cars() -> void:
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	var avoid: Array = [main.spawn_point, main.shop_door_pos, main.gate_pos]
	var spots := _wall_spots(14, 12.0, 70.0, avoid)
	var placed := 0
	var models := ["Compact", "Coupe", "Hatchback", "minivan", "Sedan", "SUV", "Wagon", "Pickup", "Sport", "Offroad"]
	for s in spots:
		if placed >= 6:
			break
		var nn: Vector3 = s[1]
		var p: Vector3 = (s[0] as Vector3) + nn * 1.1
		# vérifie qu'une voiture tient là sans toucher les bâtiments
		var q := PhysicsShapeQueryParameters3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(2.1, 1.2, 4.6)
		q.shape = bs
		var yaw := atan2(nn.x, nn.z) + PI * 0.5
		q.transform = Transform3D(Basis(Vector3.UP, yaw), p + Vector3(0, 0.8, 0))
		if not space.intersect_shape(q, 1).is_empty():
			continue
		var pack := (load("res://assets/civil_cars.glb") as PackedScene).instantiate()
		var want: String = models[placed % models.size()]
		var car: Node3D = null
		for c in pack.get_children():
			if str(c.name).contains(want):
				car = c
		if car == null:
			pack.queue_free()
			continue
		pack.remove_child(car)
		pack.queue_free()
		props_root.add_child(car)
		car.global_position = p
		car.rotation.y = yaw
		_add_box_collider(car)
		_no_shadow(car)
		placed += 1
	print("CARS ", placed)

# ------------------------------------------------------------ police
func _spawn_police() -> void:
	var spots := _wall_spots(4, 10.0, 35.0, [main.spawn_point])
	if spots.size() < 2:
		return
	var route: Array = []
	for s in spots:
		route.append((s[0] as Vector3) + (s[1] as Vector3) * 1.5)
	for i in 2:
		var p := main.spawn_free_mob("police", route[i % route.size()]) as Mob
		p.patrol = route
		p.patrol_i = i * 2
		p.patrol_off = Vector3(i * 1.2, 0, 0)
		police.append(p)
	# voiture de police garée avec gyrophares
	if ResourceLoader.exists("res://assets/police_ford.glb"):
		var s0: Array = spots[0]
		var car := (load("res://assets/police_ford.glb") as PackedScene).instantiate() as Node3D
		props_root.add_child(car)
		var nn: Vector3 = s0[1]
		car.global_position = (s0[0] as Vector3) + nn * 2.2 + Vector3(0, 0.63, 0)
		car.rotation.y = atan2(nn.x, nn.z) + PI * 0.5
		_add_box_collider(car)
		_no_shadow(car)
		_lightbar(car)
	print("POLICE ", police.size())

func _lightbar(car: Node3D) -> void:
	var aabb := AABB()
	var first := true
	for mi in car.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = car.global_transform.affine_inverse() * m.global_transform * m.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var top := aabb.get_center() + Vector3(0, aabb.size.y * 0.5 + 0.06, 0)
	var red := MeshInstance3D.new()
	var blue := MeshInstance3D.new()
	for pair in [[red, Color(1, 0.1, 0.1), -0.35], [blue, Color(0.15, 0.35, 1.0), 0.35]]:
		var mi: MeshInstance3D = pair[0]
		var bm := BoxMesh.new()
		bm.size = Vector3(0.6, 0.12, 0.22)
		mi.mesh = bm
		mi.material_override = FX.mat(pair[1], 4.0)
		mi.position = top + Vector3(float(pair[2]), 0, 0)
		car.add_child(mi)
	var tw := car.create_tween().set_loops()
	tw.tween_callback(_lb.bind(red, blue, true))
	tw.tween_interval(0.35)
	tw.tween_callback(_lb.bind(red, blue, false))
	tw.tween_interval(0.35)

func _lb(r: Node3D, b: Node3D, on: bool) -> void:
	r.visible = on
	b.visible = not on

## La police réagit au chasseur : salut, moquerie ou contrôle (amende) après un incident.
func _police_check(delta: float) -> void:
	police_cd -= delta
	if police_cd > 0.0 or main.in_dialogue:
		return
	for p in police:
		var m := p as Mob
		if not is_instance_valid(m) or m.dead:
			continue
		if m.global_position.distance_to(main.hero.global_position) > 6.0:
			continue
		police_cd = randf_range(50.0, 80.0)
		m.face_to(main.hero.global_position, true)
		if notoriety > 0 and not rank_ok():
			m.play("Point", 0.1, 1.0, true)
			m.busy = 1.5
			main.dialogue("Agent de police", "Halte, chasseur. Un civil est mort pendant ton intervention. Le règlement est clair : amende de 150 or. Et la prochaine fois, fais ton travail.", [
				["Payer l'amende (150 or)", _fine_pay],
				["« Ce n'était pas ma faute. »", _fine_argue],
				["Partir sans payer", _fine_flee],
			])
			print("POLICE_CONTROL")
		elif main.rep >= 60:
			m.play("Salute", 0.1, 1.0, true)
			m.busy = 2.0
			FX.speech(m, POLICE_RESPECT[randi() % POLICE_RESPECT.size()], Color(0.7, 0.85, 1.0), 2.3, 2.6)
		elif not rank_ok() and randf() < 0.6:
			m.play("FoldArms", 0.1, 1.0, true)
			m.busy = 2.5
			var line: String = POLICE_MOCK[randi() % POLICE_MOCK.size()]
			FX.speech(m, line % main.hunter_rank if line.contains("%s") else line, Color(0.7, 0.85, 1.0), 2.3, 2.8)
		return

func _fine_pay() -> void:
	main.gold = maxi(main.gold - 150, 0)
	notoriety = 0
	main.rep += 2
	main.close_dialogue()
	main.system_msg("Amende payée. L'affaire est close. Réputation +2")

func _fine_argue() -> void:
	notoriety = 0
	main.rep -= 3
	main.dialogue("Agent de police", "Dis ça à sa famille. ...Dégage.", [["Partir", main.close_dialogue]])

func _fine_flee() -> void:
	main.rep -= 5
	main.close_dialogue()
	main.system_msg("Tu ignores la police. Réputation -5")

# ------------------------------------------------------------ civils
func tick(delta: float) -> void:
	if main.zone != "city" or main.hero == null:
		return
	spawn_t -= delta
	if spawn_t <= 0.0:
		spawn_t = 2.0
		_stream_civs()
	comment_cd -= delta
	_police_check(delta)
	_chase_tick(delta)

func _stream_civs() -> void:
	var hp: Vector3 = main.hero.global_position
	for i in range(civs.size() - 1, -1, -1):
		if not is_instance_valid(civs[i]):
			civs.remove_at(i)
			continue
		var c := civs[i] as Mob
		if not c.dead and c.global_position.distance_to(hp) > 75.0 and c.chasers.is_empty():
			main.mobs.erase(c)
			c.queue_free()
			civs.remove_at(i)
	var alive := 0
	for c in civs:
		if is_instance_valid(c) and not (c as Mob).dead:
			alive += 1
	if alive >= 5:
		return
	var space: PhysicsDirectSpaceState3D = main.get_world_3d().direct_space_state
	for tries in 6:
		var a := randf() * TAU
		var p := hp + Vector3(sin(a), 0, cos(a)) * randf_range(22.0, 50.0)
		if not main._is_open(space, p + Vector3(0, 80, 0)):
			continue
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 40, 0), p + Vector3(0, -20, 0)))
		if g.is_empty():
			continue
		p = g["position"]
		var bad := false
		for u in main.units_of_team(1):
			if (u as Unit).global_position.distance_to(p) < 15.0:
				bad = true
				break
		if bad:
			continue
		var c := main.spawn_free_mob("civil", p) as Mob
		for mi in c.model.find_children("*", "MeshInstance3D", true, false):
			(mi as GeometryInstance3D).visibility_range_end = 42.0
		civs.append(c)
		return

func civ_comment(c: Mob) -> void:
	if comment_cd > 0.0 or main.speech_cd > 0.0 or randf() > 0.35:
		return
	comment_cd = randf_range(40.0, 70.0)
	main.speech_cd = 3.0
	c.face_to(main.hero.global_position, true)
	if main.rep >= 60:
		FX.speech(c, ADMIRE[randi() % ADMIRE.size()], Color(0.9, 0.95, 1.0), 2.2, 2.8)
		c.play("Help", 0.15, 1.0, true)
	elif not rank_ok():
		var line: String = MOCK[randi() % MOCK.size()]
		FX.speech(c, line % main.hunter_rank if line.contains("%s") else line, Color(0.9, 0.95, 1.0), 2.2, 2.8)
		c.play("Shrug" if randf() < 0.5 else "FoldArms", 0.15, 1.0, true)
	c.busy = 2.4

# ------------------------------------------------------------ poursuites : un civil attaqué court vers le chasseur
func _chase_tick(delta: float) -> void:
	if chase.is_empty():
		chase_t -= delta
		if chase_t <= 0.0:
			chase_t = randf_range(80.0, 140.0)
			start_chase()
		return
	var c = chase["civ"]
	chase["t"] = float(chase["t"]) - delta
	var alive_ch: Array = []
	for m in chase["chasers"]:
		if is_instance_valid(m) and not (m as Mob).dead:
			alive_ch.append(m)
	if not is_instance_valid(c) or (c as Mob).dead:
		_end_chase(false)
		return
	if alive_ch.is_empty():
		_end_chase(true)
		return
	if float(chase["t"]) <= 0.0:
		for m in alive_ch:
			(m as Mob).target = null
		(c as Mob).chasers = []
		_clear_alert()
		chase = {}
		return
	# les monstres ne lâchent pas leur proie
	for m in alive_ch:
		var mm := m as Mob
		if mm.target == null or not is_instance_valid(mm.target):
			mm.target = c
		mm.home = mm.global_position

func start_chase(force_civ: Mob = null) -> bool:
	var hp: Vector3 = main.hero.global_position
	var victim: Mob = force_civ
	if victim == null:
		for c in civs:
			if not is_instance_valid(c):
				continue
			var cm := c as Mob
			if not cm.dead and cm.global_position.distance_to(hp) > 14.0 and cm.global_position.distance_to(hp) < 45.0:
				victim = cm
				break
	if victim == null:
		return false
	var away := victim.global_position - hp
	away.y = 0
	away = away.normalized() if away.length() > 0.1 else Vector3.FORWARD
	var chasers: Array = []
	var kinds := ["goblin", "goblin"] if main.hero.level < 4 else ["goblin", "orc"]
	for i in kinds.size():
		var sp: Vector3 = victim.global_position + away * (8.0 + i * 1.5) + Vector3(i * 1.4 - 0.7, 0, 0)
		var m := main.spawn_free_mob(kinds[i], sp) as Mob
		m.target = victim
		m.home = sp
		m.leash_r = 80.0
		m.speed *= 0.95
		chasers.append(m)
	victim.chasers = chasers
	victim.stamina = 6.0
	victim.busy = 0.0
	FX.speech(victim, "À l'aide ! Un chasseur ! Ils me poursuivent !", Color(1, 0.9, 0.8), 2.3, 3.0)
	main.speech_cd = 3.0
	chase = {"civ": victim, "chasers": chasers, "t": 60.0}
	main.system_msg("Un civil est attaqué ! Il court vers toi.")
	main.sfx("error", null, -4.0)
	_set_alert(victim)
	print("CHASE start")
	return true

func _set_alert(v: Mob) -> void:
	_clear_alert()
	alert_lbl = Label3D.new()
	alert_lbl.text = "!"
	alert_lbl.font_size = 96
	alert_lbl.pixel_size = 0.0016
	alert_lbl.fixed_size = true
	alert_lbl.outline_size = 16
	alert_lbl.modulate = Color(1, 0.25, 0.2)
	alert_lbl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	alert_lbl.no_depth_test = true
	alert_lbl.position.y = 2.4
	v.add_child(alert_lbl)
	var tw := alert_lbl.create_tween().set_loops()
	tw.tween_property(alert_lbl, "scale", Vector3.ONE * 1.3, 0.3)
	tw.tween_property(alert_lbl, "scale", Vector3.ONE, 0.3)

func _clear_alert() -> void:
	if alert_lbl and is_instance_valid(alert_lbl):
		alert_lbl.queue_free()
	alert_lbl = null

func _end_chase(saved: bool) -> void:
	var c = chase.get("civ")
	_clear_alert()
	chase = {}
	if saved and is_instance_valid(c):
		var cm := c as Mob
		cm.chasers = []
		main.rep += 6
		main.gold += 40
		cm.face_to(main.hero.global_position, true)
		cm.play("Help", 0.15, 1.0, true)
		cm.busy = 2.5
		main.speech_cd = 0.0
		FX.speech(cm, ["Merci... merci, chasseur !", "Vous m'avez sauvé la vie !", "Je... je ne l'oublierai pas."][randi() % 3], Color(0.9, 1.0, 0.9), 2.3, 3.0)
		main.system_msg("Civil sauvé ! Réputation +6, 40 or")
		main.sfx("victory", null, -6.0)
		print("CHASE saved")
	else:
		main.rep -= 8
		notoriety += 1
		main.system_msg("Le civil n'a pas survécu. Réputation -8")
		print("CHASE failed")
