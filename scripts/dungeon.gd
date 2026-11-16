class_name Dungeon
extends Node3D
## Monde du Portail : le Marais Brumeux (asset Misty Marsh) sous une brume rouge.
## Plusieurs zones de meutes (dont des camps en maisons d'orc), d'intelligence croissante,
## puis le portail écarlate vers la salle du trône (Hall d'Igris).

const MARSH_SCALE := 0.2
const HOUSE_SCALE := 0.018
var main
var rooms: Array = []          # zones : {center, mobs, engaged, cleared, kind}
var entry_point := Vector3.ZERO
var throne_door := Vector3.ZERO
var throne_portal: Node3D
var marsh: Node3D

func build(m) -> void:
	main = m
	marsh = (load("res://assets/marsh.glb") as PackedScene).instantiate()
	marsh.scale = Vector3.ONE * MARSH_SCALE
	add_child(marsh)
	for mi in marsh.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mm.mesh.create_trimesh_shape()
		body.add_child(cs)
		mm.add_child(body)
	# éclairage rouge du monde du portail
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-35, 60, 0)
	sun.light_color = Color(1.0, 0.45, 0.4)
	sun.light_energy = 0.7
	add_child(sun)

## À appeler une fois la physique prête (collisions du marais actives).
func layout() -> void:
	var space := get_world_3d().direct_space_state
	var pts: Array = []
	for ix in range(-55, 56, 5):
		for iz in range(-95, 96, 5):
			var p := to_global(Vector3(ix * 2.0, 60, iz * 2.0))
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -140, 0)))
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.85:
				continue
			var c: Vector3 = hit["position"]
			if _flat(space, c, 5.0):
				pts.append(c)
	print("DUNGEON points praticables ", pts.size())
	if pts.is_empty():
		pts.append(to_global(Vector3(0, 5, 0)))
	# entrée : point praticable le plus au sud ; zones en chaîne vers le nord
	pts.sort_custom(func(a, b): return a.z < b.z)
	entry_point = pts[0]
	var chain: Array = [entry_point]
	var kinds := ["meute", "camp_orc", "embuscade", "gardiens"]
	for k in kinds.size():
		var prev: Vector3 = chain[chain.size() - 1]
		var best := Vector3.INF
		var bscore := -1e9
		for p in pts:
			var pv: Vector3 = p
			var d := pv.distance_to(prev)
			if d < 22.0 or d > 45.0:
				continue
			var score := (pv - entry_point).length() - absf(d - 32.0)
			for c in chain:
				if (c as Vector3).distance_to(pv) < 20.0:
					score -= 1000.0
			if score > bscore:
				bscore = score
				best = pv
		if best == Vector3.INF:
			best = prev + Vector3(0, 0, 30)
		chain.append(best)
		rooms.append({"center": best, "mobs": [], "engaged": false, "cleared": false, "kind": kinds[k]})
	var last: Vector3 = chain[chain.size() - 1]
	var dir := (last - chain[chain.size() - 2]).normalized()
	throne_door = last + Vector3(dir.x, 0, dir.z) * 9.0
	var hit2 := space.intersect_ray(PhysicsRayQueryParameters3D.create(throne_door + Vector3(0, 40, 0), throne_door + Vector3(0, -80, 0)))
	if not hit2.is_empty():
		throne_door = hit2["position"]
	throne_portal = FX.portal(self, throne_door, Color(0.5, 0.05, 0.08), 2.0)
	_populate()
	print("DUNGEON zones ", rooms.size(), " entree ", entry_point, " trone ", throne_door)

func _flat(space: PhysicsDirectSpaceState3D, c: Vector3, r: float) -> bool:
	for o in [Vector3(r, 0, 0), Vector3(-r, 0, 0), Vector3(0, 0, r), Vector3(0, 0, -r)]:
		var p: Vector3 = c + o + Vector3(0, 30, 0)
		var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -80, 0)))
		if hit.is_empty() or absf((hit["position"] as Vector3).y - c.y) > 1.2:
			return false
	return true

func room_center(i: int) -> Vector3:
	return rooms[i]["center"]

func _ground(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 30, 0), p + Vector3(0, -60, 0)))
	return (hit["position"] as Vector3) if not hit.is_empty() else p

func _house(at: Vector3, yaw: float) -> void:
	var h := (load("res://assets/orc_house.glb") as PackedScene).instantiate() as Node3D
	add_child(h)
	h.global_position = _ground(at) + Vector3(0, -0.2, 0)
	h.scale = Vector3.ONE * HOUSE_SCALE
	h.rotation.y = yaw
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var cyl := CylinderShape3D.new()
	cyl.radius = 6.0
	cyl.height = 8.0
	cs.shape = cyl
	b.add_child(cs)
	add_child(b)
	b.global_position = h.global_position + Vector3(0, 4, 0)
	var fire := OmniLight3D.new()
	fire.light_color = Color(1, 0.45, 0.15)
	fire.light_energy = 2.5
	fire.omni_range = 12.0
	add_child(fire)
	fire.global_position = h.global_position + Vector3(0, 3, 0) + Vector3(sin(yaw), 0, cos(yaw)) * 8.0

func _populate() -> void:
	var packs := [
		[["goblin", 0, 0], ["goblin", 2.5, 1], ["goblin", -2.5, 1], ["shaman", 0, 4]],
		[["orc", 0, 0], ["goblin", 3, -2], ["goblin", -3, -2], ["shaman", 2, 4], ["shaman", -2, 4]],
		[["goblin", 6, 6], ["goblin", -6, 6], ["goblin", 6, -6], ["goblin", -6, -6], ["orc", 0, 7], ["shaman", 0, -7]],
		[["orc", 3, 0], ["orc", -3, 0], ["shaman", 0, 4], ["goblin", 5, 3], ["goblin", -5, 3]],
	]
	for i in rooms.size():
		var c: Vector3 = rooms[i]["center"]
		var kind := str(rooms[i]["kind"])
		if kind == "camp_orc" or kind == "gardiens":
			_house(c + Vector3(12, 0, 6), randf() * TAU)
		if kind == "gardiens":
			_house(c + Vector3(-13, 0, 4), randf() * TAU)
		var beacon := OmniLight3D.new()
		beacon.light_color = Color(1, 0.2, 0.15)
		beacon.light_energy = 2.0
		beacon.omni_range = 16.0
		add_child(beacon)
		beacon.global_position = c + Vector3(0, 6, 0)
		for e in packs[i]:
			var p := _ground(c + Vector3(float(e[1]), 0, float(e[2])))
			var mob: Mob = main.spawn_free_mob(str(e[0]), p)
			mob.dormant = true
			mob.room_id = i
			mob.leash_r = 45.0
			mob.home = p
			if kind == "gardiens":
				mob.make_elite()
			if kind == "embuscade":
				mob.visible = false
			rooms[i]["mobs"].append(mob)

func update(hero: Unit) -> void:
	for r in rooms:
		if r["cleared"]:
			continue
		var c: Vector3 = r["center"]
		var dist := Vector2(hero.global_position.x - c.x, hero.global_position.z - c.z).length()
		if dist < (16.0 if str(r["kind"]) != "embuscade" else 9.0) and not r["engaged"]:
			r["engaged"] = true
			_engage(r, hero)
		if r["engaged"]:
			var alive := false
			for m in r["mobs"]:
				if not (m as Mob).dead and not (m as Mob).is_shadow:
					alive = true
			if not alive:
				r["cleared"] = true
				main.system_msg("[ SYSTÈME ]\nMeute éliminée. %d / %d" % [cleared_count(), rooms.size()])
				if all_cleared():
					main.system_msg("[ SYSTÈME ]\nLe portail du trône s'est ouvert.\nLe Commandant Écarlate t'attend.")
					if throne_portal:
						throne_portal.queue_free()
					throne_portal = FX.portal(self, throne_door, Color(1, 0.1, 0.12), 2.2)

func _engage(r: Dictionary, hero: Unit) -> void:
	var kind := str(r["kind"])
	if kind == "embuscade":
		main.system_msg("[ SYSTÈME ]\nEMBUSCADE !")
		for m in r["mobs"]:
			var mm := m as Mob
			mm.visible = true
			FX.shadow_puff(main, mm.global_position)
	for m in r["mobs"]:
		var mm := m as Mob
		mm.dormant = false
		mm.set_target(hero)
	if kind == "gardiens":
		var first := r["mobs"][0] as Mob
		FX.speech(first, "Personne ne dérange le Commandant. Surtout pas un humain.", Color(1, 0.75, 0.6), 3.4, 3.5)

func cleared_count() -> int:
	var n := 0
	for r in rooms:
		if r["cleared"]:
			n += 1
	return n

func next_target() -> Vector3:
	for r in rooms:
		if not r["cleared"]:
			return r["center"]
	return throne_door

func all_cleared() -> bool:
	for r in rooms:
		if not r["cleared"]:
			return false
	return true
