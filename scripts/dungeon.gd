class_name Dungeon
extends Node3D
## Donjon procédural en pièces KayKit (grille de 4 m) : salles, couloirs, barrières de mana,
## embuscade, puis porte du trône vers la salle du Commandant Écarlate.

const T := 4.0
var main
var rooms: Array = []          # {cx, z0, w, h, mobs:[], engaged, cleared, kind, barrier}
var entry_point := Vector3.ZERO
var throne_door := Vector3.ZERO
var pieces := {}

func _p(name: String) -> PackedScene:
	if not pieces.has(name):
		pieces[name] = load("res://assets/dun/" + name)
	return pieces[name]

func _put(name: String, pos: Vector3, yaw := 0.0, sc := 1.0) -> Node3D:
	var n := _p(name).instantiate() as Node3D
	add_child(n)
	n.position = pos
	n.rotation.y = yaw
	n.scale = Vector3.ONE * sc
	return n

func _box(pos: Vector3, size: Vector3) -> void:
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = size
	cs.shape = bs
	b.add_child(cs)
	add_child(b)
	b.position = pos

func build(m) -> void:
	main = m
	# salles : centre en x (tuiles), début en z, largeur, profondeur, type
	var spec := [
		{"w": 3, "h": 3, "kind": "entree"},
		{"w": 5, "h": 4, "kind": "meute"},
		{"w": 5, "h": 5, "kind": "piliers"},
		{"w": 5, "h": 6, "kind": "embuscade"},
		{"w": 5, "h": 5, "kind": "gardiens"},
	]
	var z := 0
	for i in spec.size():
		var r: Dictionary = spec[i].duplicate()
		r["cx"] = 0
		r["z0"] = z
		r["mobs"] = []
		r["engaged"] = false
		r["cleared"] = i == 0
		r["id"] = i
		rooms.append(r)
		z += int(r["h"]) + 2   # couloir de 2 tuiles
	for i in rooms.size():
		_build_room(i)
		if i < rooms.size() - 1:
			_build_corridor(int(rooms[i]["z0"]) + int(rooms[i]["h"]), int(rooms[i + 1]["z0"]) - 1)
	entry_point = to_global(Vector3(0, 0.2, 0))
	var last: Dictionary = rooms[rooms.size() - 1]
	throne_door = to_global(Vector3(0, 0, (int(last["z0"]) + int(last["h"]) - 1) * T + 1.0))
	# grand portail rouge vers la salle du trône
	FX.portal(self, throne_door + Vector3(0, 0, 0.6), Color(1, 0.1, 0.12), 1.7)
	_populate()

func _build_room(i: int) -> void:
	var r: Dictionary = rooms[i]
	var w := int(r["w"])
	var h := int(r["h"])
	var z0 := int(r["z0"])
	var x0 := -(w / 2)
	for ix in range(x0, x0 + w):
		for iz in range(z0, z0 + h):
			_put("floor_tile_large_rocks.gltf.glb" if (ix + iz) % 5 == 0 else "floor_tile_large.gltf.glb", Vector3(ix * T, 0, iz * T))
	_box(Vector3(0, -0.5, (z0 + h * 0.5 - 0.5) * T), Vector3(w * T, 1.0, h * T))
	var zs := z0 * T - T * 0.5
	var zn := (z0 + h - 1) * T + T * 0.5
	var xw := x0 * T - T * 0.5
	var xe := (x0 + w - 1) * T + T * 0.5
	# murs sud / nord (porte au centre si couloir)
	for ix in range(x0, x0 + w):
		var south_door := ix == 0 and i > 0
		var north_door := ix == 0 and i < rooms.size() - 1
		_wall(Vector3(ix * T, 0, zs), 0.0, south_door)
		if i == rooms.size() - 1 and ix == 0:
			_wall(Vector3(ix * T, 0, zn), PI, true)
		else:
			_wall(Vector3(ix * T, 0, zn), PI, north_door)
	for iz in range(z0, z0 + h):
		_wall(Vector3(xw, 0, iz * T), PI * 0.5, false)
		_wall(Vector3(xe, 0, iz * T), -PI * 0.5, false)
	for c in [Vector3(xw, 0, zs), Vector3(xe, 0, zs), Vector3(xw, 0, zn), Vector3(xe, 0, zn)]:
		_put("pillar_decorated.gltf.glb", c)
	# éclairage + décor
	var lt := OmniLight3D.new()
	lt.light_color = Color(1.0, 0.55, 0.25)
	lt.light_energy = 2.2
	lt.omni_range = maxf(w, h) * T * 0.8
	lt.position = Vector3(0, 5.0, (z0 + h * 0.5 - 0.5) * T)
	add_child(lt)
	for iz in range(z0, z0 + h, 2):
		var tl := _put("torch_mounted.gltf.glb", Vector3(xw + 0.55, 2.2, iz * T), PI * 0.5)
		tl.rotation.y = PI * 0.5
		var tr := _put("torch_mounted.gltf.glb", Vector3(xe - 0.55, 2.2, iz * T), -PI * 0.5)
		tr.rotation.y = -PI * 0.5
		for tpos in [Vector3(xw + 0.9, 2.9, iz * T), Vector3(xe - 0.9, 2.9, iz * T)]:
			var f := OmniLight3D.new()
			f.light_color = Color(1, 0.5, 0.2)
			f.light_energy = 0.9
			f.omni_range = 5.0
			f.position = tpos
			add_child(f)
	var props := ["barrel_large.gltf.glb", "crates_stacked.gltf.glb", "rubble_large.gltf.glb", "sword_shield_broken.gltf.glb", "candle_triple.gltf.glb"]
	for k in 3:
		var side := -1.0 if k % 2 == 0 else 1.0
		var px := (xw + 1.6) if side < 0 else (xe - 1.6)
		var pz := (z0 + (k + 1) * h / 4.0 - 0.5) * T
		var pr := _put(props[(i + k) % props.size()], Vector3(px, 0, pz), randf() * TAU, 0.8 if props[(i + k) % props.size()] == "rubble_large.gltf.glb" else 1.0)
		if props[(i + k) % props.size()] != "candle_triple.gltf.glb" and props[(i + k) % props.size()] != "sword_shield_broken.gltf.glb":
			_box(Vector3(px, 1.0, pz), Vector3(1.6, 2.0, 1.6))
	_put("banner_patternA_red.gltf.glb", Vector3(-T, 0, zn - 0.6), PI)
	_put("banner_patternA_red.gltf.glb", Vector3(T, 0, zn - 0.6), PI)
	if str(r["kind"]) == "piliers":
		for c in [Vector3(-T, 0, (z0 + 1) * T), Vector3(T, 0, (z0 + 1) * T), Vector3(-T, 0, (z0 + 3) * T), Vector3(T, 0, (z0 + 3) * T)]:
			_put("column.gltf.glb", c, 0.0, 2.6)
			_box(c + Vector3(0, 1.8, 0), Vector3(1.6, 3.6, 1.6))

func _wall(pos: Vector3, yaw: float, door: bool) -> void:
	_put("wall_doorway.glb" if door else ("wall_cracked.gltf.glb" if randf() < 0.25 else "wall.gltf.glb"), pos, yaw)
	var along := Vector3(cos(yaw), 0, -sin(yaw))
	if door:
		for s in [-1.0, 1.0]:
			_box(pos + along * (1.55 * s) + Vector3(0, 2, 0), Vector3(0.9, 4, 0.9) if absf(sin(yaw)) < 0.5 else Vector3(0.9, 4, 0.9))
		_box(pos + Vector3(0, 3.6, 0), Vector3(4, 0.8, 1) if absf(sin(yaw)) < 0.5 else Vector3(1, 0.8, 4))
	else:
		_box(pos + Vector3(0, 2, 0), Vector3(4, 4, 1) if absf(sin(yaw)) < 0.5 else Vector3(1, 4, 4))

func _build_corridor(z_from: int, z_to: int) -> void:
	for iz in range(z_from, z_to + 1):
		_put("floor_tile_large.gltf.glb", Vector3(0, 0, iz * T))
		_wall(Vector3(-T * 0.5, 0, iz * T), PI * 0.5, false)
		_wall(Vector3(T * 0.5, 0, iz * T), -PI * 0.5, false)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1, 0.45, 0.2)
		lt.light_energy = 1.0
		lt.omni_range = 6.0
		lt.position = Vector3(0, 3, iz * T)
		add_child(lt)
	_box(Vector3(0, -0.5, (z_from + z_to) * 0.5 * T), Vector3(T, 1, (z_to - z_from + 1) * T))

func room_center(i: int) -> Vector3:
	var r: Dictionary = rooms[i]
	return to_global(Vector3(0, 0, (int(r["z0"]) + int(r["h"]) * 0.5 - 0.5) * T))

func _room_point(i: int, fx: float, fz: float) -> Vector3:
	var r: Dictionary = rooms[i]
	var w := float(r["w"]) * T - 3.0
	var h := float(r["h"]) * T - 3.0
	return room_center(i) + Vector3((fx - 0.5) * w, 0.3, (fz - 0.5) * h)

func _populate() -> void:
	var packs := {
		1: [["goblin", 0.3, 0.6], ["goblin", 0.7, 0.6], ["goblin", 0.5, 0.8], ["shaman", 0.5, 0.95]],
		2: [["orc", 0.5, 0.6], ["goblin", 0.25, 0.4], ["goblin", 0.75, 0.4], ["shaman", 0.2, 0.9], ["shaman", 0.8, 0.9]],
		3: [["goblin", 0.05, 0.1], ["goblin", 0.95, 0.1], ["goblin", 0.05, 0.9], ["goblin", 0.95, 0.9], ["orc", 0.5, 1.0], ["shaman", 0.5, 0.0]],
		4: [["orc", 0.3, 0.75], ["orc", 0.7, 0.75], ["shaman", 0.5, 0.95]],
	}
	for i in packs.keys():
		for e in packs[i]:
			var mob: Mob = main.spawn_free_mob(str(e[0]), _room_point(i, float(e[1]), float(e[2])))
			mob.dormant = true
			mob.room_id = i
			mob.leash_r = 60.0
			mob.home = mob.global_position
			if i == 4:
				mob.make_elite()
			if i == 3:
				mob.visible = false
			rooms[i]["mobs"].append(mob)
		_make_barrier(i)

## Barrière de mana à la sortie de la salle (disparaît quand la salle est nettoyée).
func _make_barrier(i: int) -> void:
	var r: Dictionary = rooms[i]
	var zn := (int(r["z0"]) + int(r["h"]) - 1) * T + T * 0.5
	if i == rooms.size() - 1:
		zn -= 1.5
	var b := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(3.2, 4, 0.4)
	cs.shape = bs
	b.add_child(cs)
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(3.2, 3.6, 0.1)
	mi.mesh = bm
	mi.material_override = FX.mat(Color(1, 0.15, 0.2), 2.0, 0.35)
	b.add_child(mi)
	add_child(b)
	b.position = Vector3(0, 1.8, zn)
	r["barrier"] = b

func update(hero: Unit) -> void:
	var hp := to_local(hero.global_position)
	for r in rooms:
		if r["cleared"]:
			continue
		var w := float(r["w"]) * T
		var z0 := float(r["z0"]) * T - T * 0.5
		var z1 := z0 + float(r["h"]) * T
		var inside: bool = absf(hp.x) < w * 0.5 - 0.5 and hp.z > z0 + 1.0 and hp.z < z1
		if inside and not r["engaged"]:
			r["engaged"] = true
			_engage(r, hero)
		if r["engaged"]:
			var alive := false
			for m in r["mobs"]:
				if not (m as Mob).dead and not (m as Mob).is_shadow:
					alive = true
			if not alive:
				r["cleared"] = true
				if r.has("barrier") and is_instance_valid(r["barrier"]):
					var b: Node3D = r["barrier"]
					FX.burst(main, b.global_position, Color(1, 0.3, 0.3), 40, 0.12, 4.0, 0.6, 2.0)
					b.queue_free()
				main.system_msg("[ SYSTÈME ]\nSalle nettoyée. La barrière de mana se dissipe.")

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

func all_cleared() -> bool:
	for r in rooms:
		if not r["cleared"]:
			return false
	return true
