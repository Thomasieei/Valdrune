class_name RoomRun
extends Node3D
## Donjons à salles (Terrier Gobelin, Forteresse Orque) : une suite de salles construites
## à partir des décors fournis. Chaque salle est analysée (sol praticable, zone connexe),
## on y place des meutes, et la sortie ne s'ouvre qu'une fois la salle nettoyée.
## Dernière salle : le chef. Parfois « anormal » : 1 ou 2 rangs au-dessus, une erreur = la mort.

const ROOMS := {
	"temple": {"f": "temple", "s": 40.0, "n": "Parvis en ruines"},
	"dungeon1": {"f": "dungeon1", "s": 1.0, "n": "Galeries souterraines"},
	"brick": {"f": "brick", "s": 1.45, "n": "Salle du Sceau"},
	"abbuilding": {"f": "abbuilding", "s": 0.04, "n": "Rotonde de briques"},
	"throne": {"f": "throne", "s": 1.7, "n": "Arène du Chef de Guerre"},
}
const RANKS := ["E", "D", "C", "B", "A", "S"]
const DEFS := {
	"goblin": {"name": "Terrier Gobelin", "rank": 1, "col": Color(0.35, 1.0, 0.45), "light": Color(0.65, 1.0, 0.55),
		"seq": [["temple", 2, ""], ["dungeon1", 3, ""], ["brick", 1, "elite"], ["abbuilding", 0, "boss"]],
		"pool": [["goblin", 5], ["shaman", 2]],
		"chief": "goblin", "chief_name": "Kragg, Roi des Gobelins", "chief_scale": 1.75,
		"chief_line": "Mon terrier, mes trésors, MA viande ! Les gobelins, à table !"},
	"orc": {"name": "Forteresse Orque", "rank": 2, "col": Color(1.0, 0.5, 0.15), "light": Color(1.0, 0.6, 0.35),
		"seq": [["dungeon1", 3, ""], ["abbuilding", 2, ""], ["brick", 1, "elite"], ["throne", 0, "boss"]],
		"pool": [["orc", 3], ["goblin", 3], ["shaman", 2], ["orc_warrior", 1]],
		"chief": "orc_warrior", "chief_name": "Grukh, Chef de Guerre", "chief_scale": 1.35,
		"chief_line": "Un humain dans mon arène ? Les dieux m'envoient un jouet."},
}
const STEP := 2.0

var main
var kind := "goblin"
var def: Dictionary
var rooms: Array = []      # {node, pts, entry, exit, packs, open, portal, sealed, name, role, lo, hi}
var cur := 0
var ready_ok := false
var chief: Mob
var over := 0              # rangs au-dessus du rang du donjon (0, 1, 2)
var chief_started := false
var chest: Node3D
var chest_taken := false
var exit_pos := Vector3.INF
var exit_portal: Node3D
var run_tokens := 0

func build(m, k: String, origin: Vector3) -> void:
	main = m
	kind = k
	def = DEFS[k]
	position = origin
	over = 0
	var r := randf()
	if r < 0.1:
		over = 2
	elif r < 0.3:
		over = 1
	var seq: Array = def["seq"]
	for i in seq.size():
		var rid: String = seq[i][0]
		var rd: Dictionary = ROOMS[rid]
		var n := (load("res://assets/rooms/%s.glb" % rd["f"]) as PackedScene).instantiate() as Node3D
		n.scale = Vector3.ONE * float(rd["s"])
		n.position = Vector3(i * 420.0, 0, 0)
		add_child(n)
		for mi in n.find_children("*", "MeshInstance3D", true, false):
			var mm := mi as MeshInstance3D
			mm.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = mm.mesh.create_trimesh_shape()
			body.add_child(cs)
			mm.add_child(body)
		rooms.append({"node": n, "pts": [], "entry": n.global_position, "exit": n.global_position, "packs": [], "open": false,
			"portal": null, "sealed": null, "name": rd["n"], "role": seq[i][2], "npacks": int(seq[i][1]), "id": rid})
	visible = false

func _room_aabb(n: Node3D) -> AABB:
	var a := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var b: AABB = mm.global_transform * mm.get_aabb()
		a = b if first else a.merge(b)
		first = false
	return a

## Analyse des salles : à appeler quand la physique a enregistré les collisions.
func layout() -> void:
	for i in rooms.size():
		await _analyse(i)
	for i in rooms.size():
		_populate(i)
	ready_ok = true
	show_room(-1)
	print("RUN %s salles=%d anomalie=+%d" % [kind, rooms.size(), over])

func _ray(space: PhysicsDirectSpaceState3D, a: Vector3, b: Vector3, back: bool) -> Dictionary:
	var q := PhysicsRayQueryParameters3D.create(a, b, 1)
	q.hit_back_faces = back
	return space.intersect_ray(q)

func _analyse(i: int) -> void:
	var r: Dictionary = rooms[i]
	var n: Node3D = r["node"]
	var a := _room_aabb(n)
	var space := get_world_3d().direct_space_state
	var y0 := a.position.y + minf(a.size.y * 0.55, 4.0)
	var cells := {}
	var nx := int(a.size.x / STEP)
	var nz := int(a.size.z / STEP)
	var count := 0
	for ix in nx:
		for iz in nz:
			var x := a.position.x + (ix + 0.5) * STEP
			var z := a.position.z + (iz + 0.5) * STEP
			var hit := _ray(space, Vector3(x, y0, z), Vector3(x, a.position.y - 1.0, z), false)
			count += 1
			if count % 300 == 0:
				await get_tree().physics_frame
			if hit.is_empty() or (hit["normal"] as Vector3).y < 0.8:
				continue
			var p: Vector3 = hit["position"]
			if not _ray(space, p + Vector3(0, 0.15, 0), p + Vector3(0, 2.3, 0), true).is_empty():
				continue
			var ok := true
			for d: Vector3 in [Vector3(1, 0, 0), Vector3(-1, 0, 0), Vector3(0, 0, 1), Vector3(0, 0, -1)]:
				if not _ray(space, p + Vector3(0, 0.9, 0), p + Vector3(0, 0.9, 0) + d * 0.9, true).is_empty():
					ok = false
					break
			if ok:
				cells[Vector2i(ix, iz)] = p
	# plus grande zone connexe (liaisons vérifiées dans les deux sens : rien de coincé dans un mur)
	var comp_of := {}
	var best: Array = []
	for c in cells.keys():
		if comp_of.has(c):
			continue
		var comp: Array = [c]
		comp_of[c] = true
		var qi := 0
		while qi < comp.size():
			var cc: Vector2i = comp[qi]
			qi += 1
			for nb in _nbrs(cc, cells, space):
				if not comp_of.has(nb):
					comp_of[nb] = true
					comp.append(nb)
		if comp.size() > best.size():
			best = comp
		await get_tree().physics_frame
	var pts := {}
	for c in best:
		pts[c] = cells[c]
	r["cells"] = pts
	if best.is_empty():
		r["entry"] = n.global_position + Vector3(0, 1, 0)
		r["exit"] = r["entry"] + Vector3(6, 0, 0)
		print("RUN_ROOM %s VIDE" % r["id"])
		return
	var d0 := _bfs(best[0], pts, space)
	var fa: Vector2i = _far(d0)
	var da := _bfs(fa, pts, space)
	var fb: Vector2i = _far(da)
	r["dist"] = da
	r["maxd"] = float(da[fb])
	r["entry"] = pts[fa]
	r["exit"] = pts[fb]
	r["lo"] = a.position
	r["hi"] = a.end
	print("RUN_ROOM %s points=%d/%d longueur=%d entree=%s sortie=%s" % [r["id"], best.size(), cells.size(), int(r["maxd"]), (r["entry"] as Vector3).round(), (r["exit"] as Vector3).round()])

func _nbrs(c: Vector2i, cells: Dictionary, space: PhysicsDirectSpaceState3D) -> Array:
	var out: Array = []
	var p: Vector3 = cells[c]
	for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
		var nc: Vector2i = c + o
		if not cells.has(nc):
			continue
		var q: Vector3 = cells[nc]
		if absf(q.y - p.y) > 0.7:
			continue
		var h := Vector3(0, 0.8, 0)
		if not _ray(space, p + h, q + h, true).is_empty() or not _ray(space, q + h, p + h, true).is_empty():
			continue
		out.append(nc)
	return out

func _bfs(start: Vector2i, pts: Dictionary, space: PhysicsDirectSpaceState3D) -> Dictionary:
	var dist := {start: 0}
	var q: Array = [start]
	var qi := 0
	while qi < q.size():
		var c: Vector2i = q[qi]
		qi += 1
		for o in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
			var nc: Vector2i = c + o
			if pts.has(nc) and not dist.has(nc) and absf((pts[nc] as Vector3).y - (pts[c] as Vector3).y) < 0.7:
				dist[nc] = int(dist[c]) + 1
				q.append(nc)
	return dist

func _far(dist: Dictionary) -> Vector2i:
	var best: Vector2i = dist.keys()[0]
	for c in dist.keys():
		if int(dist[c]) > int(dist[best]):
			best = c
	return best

## Point praticable dont la distance (en cases) depuis l'entrée est la plus proche de frac × longueur.
func _at_frac(r: Dictionary, frac: float) -> Vector3:
	var dist: Dictionary = r.get("dist", {})
	if dist.is_empty():
		return r["entry"]
	var want := frac * float(r["maxd"])
	var best: Vector2i = dist.keys()[0]
	var bd := 1e9
	for c in dist.keys():
		var e := absf(float(dist[c]) - want)
		if e < bd:
			bd = e
			best = c
	return (r["cells"] as Dictionary)[best]

func _spots_near(r: Dictionary, c: Vector3, n: int) -> Array:
	var cand: Array = []
	for p in (r.get("cells", {}) as Dictionary).values():
		var d := (p as Vector3).distance_to(c)
		if d > 1.5 and d < 8.0:
			cand.append(p)
	cand.shuffle()
	var out: Array = []
	for p in cand:
		var ok := true
		for q in out:
			if (q as Vector3).distance_to(p) < 1.8:
				ok = false
				break
		if ok:
			out.append(p)
		if out.size() >= n:
			break
	while out.size() < n:
		out.append(c + Vector3(randf_range(-1.5, 1.5), 0, randf_range(-1.5, 1.5)))
	return out

func _pick_kind() -> String:
	var pool: Array = def["pool"]
	var tot := 0
	for e in pool:
		tot += int(e[1])
	var x := randi() % tot
	for e in pool:
		x -= int(e[1])
		if x < 0:
			return str(e[0])
	return str(pool[0][0])

func _light(at: Vector3, col: Color, energy: float, rng: float) -> void:
	var l := FX.new_light(true)
	l.light_color = col
	l.light_energy = energy
	l.omni_range = rng
	add_child(l)
	l.global_position = at + Vector3(0, 3.0, 0)

func _populate(i: int) -> void:
	var r: Dictionary = rooms[i]
	var lc: Color = def["light"]
	_light(r["entry"], lc, 1.6, 14.0)
	var role := str(r["role"])
	if role == "boss":
		var cp := _at_frac(r, 0.7)
		_light(cp, Color(1, 0.35, 0.25), 2.4, 20.0)
		_light(_at_frac(r, 0.35), lc, 1.4, 16.0)
		_spawn_chief(cp, r["entry"])
		return
	var np := int(r["npacks"])
	for k in np:
		var frac := (k + 1.0) / (np + 1.0) * 0.9 + 0.08
		var c := _at_frac(r, frac)
		_light(c, lc, 1.8, 15.0)
		var size := 3 + i + (1 if kind == "orc" else 0)
		if role == "elite":
			size = 3
		var pack := {"center": c, "mobs": [], "engaged": false, "cleared": false}
		var spots := _spots_near(r, c, size)
		for s in size:
			var mk := _pick_kind()
			if role == "elite" and s == 0:
				mk = "orc_warrior" if kind == "orc" else "orc"
			var mob: Mob = main.spawn_free_mob(mk, spots[s])
			mob.set_meta("run", true)
			mob.dormant = true
			mob.leash_r = 60.0
			mob.home = spots[s]
			mob.face_to(r["entry"], true)
			if mk == "goblin" and randf() < 0.35:
				mob.make_variant("berserker" if randf() < 0.5 else "eclaireur")
			if role == "elite" and s < 2:
				mob.make_elite()
			(pack["mobs"] as Array).append(mob)
		(r["packs"] as Array).append(pack)
	# sortie scellée tant que la salle n'est pas nettoyée
	var sealed := FX.ground_disc(1.4, Color(0.6, 0.15, 0.15), 0.5, true)
	add_child(sealed)
	sealed.global_position = (r["exit"] as Vector3) + Vector3(0, 0.05, 0)
	var lb := Label3D.new()
	lb.text = "PASSAGE SCELLÉ"
	lb.font_size = 40
	lb.pixel_size = 0.0045
	lb.outline_size = 10
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.modulate = Color(1, 0.45, 0.4)
	lb.position.y = 2.3
	sealed.add_child(lb)
	r["sealed"] = sealed

func _spawn_chief(p: Vector3, look: Vector3) -> void:
	chief = main.spawn_free_mob(str(def["chief"]), p)
	chief.set_meta("run", true)
	chief.set_meta("chief", true)
	chief.make_elite()
	var rk := int(def["rank"]) + over
	chief.display_name = str(def["chief_name"])
	chief.rank = RANKS[clampi(rk, 0, RANKS.size() - 1)]
	chief.model.scale *= float(def["chief_scale"]) / 1.3
	chief.body_r *= 1.3
	chief.arm *= 1.3
	var hpm := [5.0, 8.5, 12.0][over]
	var dmm := [1.6, 3.2, 5.0][over]
	chief.max_hp *= hpm
	chief.hp = chief.max_hp
	chief.dmg *= dmm
	chief.reward_gold *= 3 + over * 3
	chief.dormant = true
	chief.leash_r = 300.0
	chief.home = p
	chief.face_to(look, true)
	if chief.hp_bar:
		chief.hp_bar.queue_free()
		chief.hp_bar = null
		chief.hp_fill = null
	if over > 0:
		var aura := FX.new_light(true)
		aura.light_color = Color(0.8, 0.1, 1.0) if over == 2 else Color(1, 0.15, 0.1)
		aura.light_energy = 2.0
		aura.omni_range = 7.0
		aura.position.y = 2.0
		chief.add_child(aura)

func room() -> Dictionary:
	return rooms[cur]

func boss_room() -> bool:
	return str(room()["role"]) == "boss"

func show_room(i: int) -> void:
	cur = maxi(i, 0)
	for k in rooms.size():
		(rooms[k]["node"] as Node3D).visible = k == i
		for p in rooms[k]["packs"]:
			for m in p["mobs"]:
				if is_instance_valid(m) and not (m as Mob).is_shadow:
					(m as Mob).visible = k == i
	if chief and is_instance_valid(chief) and not chief.is_shadow:
		chief.visible = i >= 0 and str(rooms[i]["role"]) == "boss"

func next_target() -> Vector3:
	var r := room()
	for p in r["packs"]:
		if not p["cleared"]:
			return p["center"]
	if boss_room():
		if chief and is_instance_valid(chief) and not chief.dead:
			return chief.global_position
		return exit_pos if exit_pos != Vector3.INF else r["exit"]
	return r["exit"]

func update(hero: Unit) -> void:
	if not ready_ok:
		return
	var r := room()
	for p in r["packs"]:
		if p["cleared"]:
			continue
		var c: Vector3 = p["center"]
		if not p["engaged"]:
			var hit_any := false
			for m in p["mobs"]:
				if is_instance_valid(m) and not (m as Mob).dormant:
					hit_any = true
			if hero.global_position.distance_to(c) < 15.0 or hit_any:
				p["engaged"] = true
				for m in p["mobs"]:
					var mm := m as Mob
					if is_instance_valid(mm) and not mm.dead:
						mm.dormant = false
						mm.set_target(hero)
		else:
			var alive := false
			for m in p["mobs"]:
				if is_instance_valid(m) and not (m as Mob).dead and not (m as Mob).is_shadow:
					alive = true
			if not alive:
				p["cleared"] = true
				_check_room_clear()
	if boss_room() and chief and is_instance_valid(chief) and not chief_started and not chief.dead:
		if hero.global_position.distance_to(chief.global_position) < 16.0 or not chief.dormant:
			_start_chief(hero)

func _check_room_clear() -> void:
	var r := room()
	for p in r["packs"]:
		if not p["cleared"]:
			return
	if r["open"]:
		return
	r["open"] = true
	if r["sealed"]:
		(r["sealed"] as Node3D).queue_free()
	r["portal"] = FX.portal(self, r["exit"], def["col"], 1.6)
	main.sfx("portal", null, -4.0)
	main.system_msg("[ SYSTÈME ]\n%s nettoyée. Le passage s'ouvre." % str(r["name"]))

func _start_chief(hero: Unit) -> void:
	chief_started = true
	chief.dormant = false
	chief.set_target(hero)
	FX.speech(chief, str(def["chief_line"]), Color(1, 0.6, 0.45), 3.6, 4.0)
	main.boss = chief
	main.boss_bar_name.text = "%s  [%s]" % [chief.display_name, chief.rank]
	main.boss_bar_root.visible = true
	main.shake(0.3)

func enter_room_msg() -> void:
	var r := room()
	if boss_room():
		var t := "[ SYSTÈME ]\n%s — le chef du donjon est ici." % str(r["name"])
		if over > 0:
			t = "[ SYSTÈME ]\n⚠ ANOMALIE DÉTECTÉE ⚠\nLe chef est de rang %s : %d rang%s au-dessus de ce Portail.\nUne seule erreur peut être fatale. Fuir n'a rien de honteux." % [chief.rank, over, "s" if over > 1 else ""]
		main.system_msg(t)
	else:
		main.system_msg("[ SYSTÈME ]\n%s — salle %d / %d.\nÉlimine les meutes pour ouvrir le passage." % [str(r["name"]), cur + 1, rooms.size()])

## Jetons de donjon gagnés sur chaque monstre.
func on_kill(m: Mob) -> void:
	var n := 0
	if m == chief:
		n = 10 * (1 + over * 2)
	elif m.elite:
		n = 3
	elif randf() < 0.6:
		n = 1
	if n > 0:
		main.add_tokens(kind, n, m.global_position)
		run_tokens += n
	if m == chief:
		_on_chief_dead()

func _on_chief_dead() -> void:
	main.boss_bar_root.visible = false
	main.boss = null
	main.rep += 10 + over * 10
	main.hero.gain_xp(250.0 * (1 + over * 2))
	main.system_msg("[ SYSTÈME ]\n%s est tombé !%s\nUn coffre est apparu." % [chief.display_name, "\nAnomalie vaincue : récompenses multipliées." if over > 0 else ""])
	var r := room()
	var cpos := _at_frac(r, 0.85)
	chest = main.make_chest(cpos, 0.55)
	var lt := FX.new_light(true)
	lt.light_color = Color(1, 0.8, 0.3)
	lt.light_energy = 2.2
	lt.omni_range = 7.0
	lt.position.y = 2.0
	chest.add_child(lt)
	exit_pos = r["entry"]
	exit_portal = FX.portal(self, exit_pos, Color(0.25, 0.55, 1.0), 1.6)

func open_chest() -> void:
	chest_taken = true
	main.open_chest_anim(chest)
	var p := chest.global_position
	for k in 1 + over:
		main.drop_loot(p + Vector3(-1.4 + k * 1.4, 0, 0.8), "boss" if (kind == "orc" or over > 0) else "elite")
	main.drop_loot(p + Vector3(1.4, 0, -0.6), "elite")
	var g := (500 if kind == "goblin" else 900) * (1 + over)
	main.gold += g
	main.essence += 4 + over * 4
	main.add_tokens(kind, 5 * (1 + over), p)
	run_tokens += 5 * (1 + over)
	main.sfx("chest")
	main.sfx("victory")
	main.save_game()
	main.system_msg("[ SYSTÈME ]\nCoffre du chef : %d or, %d essences.\nJetons gagnés pendant ce donjon : %d." % [g, 4 + over * 4, run_tokens])

func cleanup() -> void:
	for r in rooms:
		for p in r["packs"]:
			for m in p["mobs"]:
				if is_instance_valid(m) and not (m as Mob).is_shadow:
					main.mobs.erase(m)
					(m as Node).queue_free()
	if chief and is_instance_valid(chief) and not chief.is_shadow:
		main.mobs.erase(chief)
		chief.queue_free()
	queue_free()
