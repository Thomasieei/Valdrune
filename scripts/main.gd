extends Node3D
## Arise Ville — Chasseur, camps d'élite, portail de donjon gardé, donjon multi-salles, boss Igris.

const CITY_SCALE := 0.01
const JOY_R := 110.0
const DUN_O := Vector3(3000, 0, 0)
const HALL_O := Vector3(3000, 0, 600)
const GATE_PERIOD := 900.0
const REP_PASS := 30

var city: Node3D
var hero: Hero
var mobs: Array = []
var camps: Array = []
var elite_camps: Array = []
var spawn_point := Vector3.ZERO
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.34
var shake_amt := 0.0
var shots_mode := false
var world_env: WorldEnvironment
var env_city: Environment
var env_dun: Environment
var env_hall: Environment
var moon: DirectionalLight3D
# progression
var gold := 0
var essence := 0
var rep := 0
var zone := "city"
var in_dialogue := false
# portail + gardes
var gate: Node3D
var gate_pos := Vector3.ZERO
var gate_timer := GATE_PERIOD
var gate_open_for_me := false
var guards: Array = []
var guard_talk_cd := 0.0
var guards_hostile := false
# donjon
var dungeon: Dungeon
var hall: Node3D
var hall_entry := Vector3.ZERO
var boss: Mob
var boss_started := false
var boss_reward_taken := false
var exit_portal: Node3D
var exit_pos := Vector3.INF
var boss_chest: Node3D
var boss_enraged_choice := false
# UI
var joy_ui: Control
var joy_touch := -1
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var look_touch := -1
var hp_fill: ColorRect
var mp_fill: ColorRect
var hp_txt: Label
var shadow_txt: Label
var res_txt: Label
var gate_txt: Label
var msg_panel: PanelContainer
var msg_label: Label
var msg_tw: Tween
var buttons := {}
var interact_btn: Button
var interact_action: Callable
var dlg_panel: PanelContainer
var dlg_name: Label
var dlg_text: Label
var dlg_choices: VBoxContainer
var boss_bar_root: Control
var boss_bar_fill: ColorRect
var boss_bar_name: Label
var fade: ColorRect
# ciblage + panneau des ombres / stats
var focus_target: Unit
var focus_marker: MeshInstance3D
var tap_pos := Vector2.ZERO
var tap_time := 0.0
var tap_index := -1
var menu_panel: PanelContainer
var menu_body: VBoxContainer
var menu_tab := ""
var menu_refresh := 0.0
var unarmed_btn: Button
var base_fov := 64.0

func _ready() -> void:
	shots_mode = OS.get_cmdline_user_args().has("--shots")
	_build_env()
	_build_other_envs()
	_build_city()
	hero = Hero.new()
	hero.world = self
	hero.main = self
	add_child(hero)
	hero.setup_hero()
	_build_camera()
	_build_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	spawn_point = _find_spawn()
	hero.global_position = spawn_point + Vector3(0, 0.2, 0)
	_make_camps(spawn_point)
	_make_elite_camps()
	await _build_dungeon()
	_build_hall()
	_spawn_gate(true)
	system_msg("[ SYSTÈME ]\nUn Portail de rang C est apparu en ville.\nL'Association des Chasseurs le garde.")
	if shots_mode:
		_run_shots()

func _build_other_envs() -> void:
	env_dun = env_city.duplicate() as Environment
	env_dun.background_mode = Environment.BG_COLOR
	env_dun.background_color = Color(0.02, 0.01, 0.02)
	env_dun.ambient_light_color = Color(0.55, 0.4, 0.35)
	env_dun.ambient_light_energy = 0.45
	env_dun.fog_light_color = Color(0.12, 0.05, 0.04)
	env_dun.fog_density = 0.03
	env_hall = env_city.duplicate() as Environment
	env_hall.background_mode = Environment.BG_COLOR
	env_hall.background_color = Color(0.08, 0.0, 0.01)
	env_hall.ambient_light_color = Color(0.75, 0.62, 0.6)
	env_hall.ambient_light_energy = 0.55
	env_hall.fog_light_color = Color(0.25, 0.04, 0.05)
	env_hall.fog_density = 0.006

# ---------------------------------------------------------------- monde
func _build_env() -> void:
	world_env = WorldEnvironment.new()
	var we := world_env
	var e := Environment.new()
	var sky := Sky.new()
	var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.02, 0.03, 0.09)
	sm.sky_horizon_color = Color(0.16, 0.12, 0.3)
	sm.ground_bottom_color = Color(0.02, 0.02, 0.04)
	sm.ground_horizon_color = Color(0.12, 0.09, 0.22)
	sm.sun_angle_max = 8.0
	sky.sky_material = sm
	e.background_mode = Environment.BG_SKY
	e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.42, 0.45, 0.7)
	e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	e.tonemap_exposure = 1.1
	e.glow_enabled = true
	e.glow_intensity = 0.55
	e.glow_bloom = 0.04
	e.glow_hdr_threshold = 1.3
	e.fog_enabled = true
	e.fog_light_color = Color(0.18, 0.16, 0.38)
	e.fog_density = 0.012
	e.fog_sky_affect = 0.6
	we.environment = e
	env_city = e
	add_child(we)
	moon = DirectionalLight3D.new()
	var moon_l := moon
	moon_l.rotation_degrees = Vector3(-38, -35, 0)
	moon_l.light_color = Color(0.62, 0.7, 1.0)
	moon_l.light_energy = 0.75
	moon_l.shadow_enabled = true
	moon_l.directional_shadow_max_distance = 60.0
	add_child(moon_l)

func _build_city() -> void:
	city = (load("res://assets/city.glb") as PackedScene).instantiate()
	city.scale = Vector3.ONE * CITY_SCALE
	add_child(city)
	for mi in city.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var nm := mat.resource_name.to_lower()
			if nm.contains("glow"):
				var g := mat.duplicate() as StandardMaterial3D
				g.emission_enabled = true
				g.emission_texture = g.albedo_texture
				g.emission = Color(1, 1, 1)
				g.emission_energy_multiplier = 1.15
				if nm.contains("red"):
					g.emission = Color(1, 0.2, 0.25)
				elif nm.contains("green"):
					g.emission = Color(0.3, 1, 0.5)
				m.set_surface_override_material(i, g)
			elif nm.contains("roadsground"):
				var r := mat.duplicate() as StandardMaterial3D
				r.roughness = 0.62
				r.metallic_specular = 0.55
				m.set_surface_override_material(i, r)
		_build_collision(m)
	# sol de sécurité sous la ville
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2000, 1, 2000)
	cs.shape = bs
	cs.position = Vector3(0, -0.55, 0)
	floor_body.add_child(cs)
	add_child(floor_body)

## Collisions de la ville sans les surfaces lumineuses (halos, néons) qui créaient des murs invisibles.
func _build_collision(m: MeshInstance3D) -> void:
	var faces := PackedVector3Array()
	var skipped := 0
	for i in m.mesh.get_surface_count():
		var mat := m.mesh.surface_get_material(i)
		var nm := mat.resource_name.to_lower() if mat else ""
		if nm.contains("glow"):
			skipped += 1
			continue
		var arr := m.mesh.surface_get_arrays(i)
		var v: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]
		var idx = arr[Mesh.ARRAY_INDEX]
		if idx is PackedInt32Array and (idx as PackedInt32Array).size() > 0:
			for k in (idx as PackedInt32Array):
				faces.append(v[k])
		else:
			faces.append_array(v)
	var shape := ConcavePolygonShape3D.new()
	shape.backface_collision = true
	shape.set_faces(faces)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	m.add_child(body)
	print("COLLISION faces ", faces.size() / 3, " surfaces lumineuses ignorées ", skipped)

func _find_spawn() -> Vector3:
	var space := get_world_3d().direct_space_state
	var aabb := AABB()
	var first := true
	for mi in city.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var center := aabb.get_center()
	var best := Vector3(center.x, 0, center.z)
	var best_d := INF
	var step := 4.0
	for ix in range(-40, 41):
		for iz in range(-40, 41):
			var p := Vector3(center.x + ix * step, 80, center.z + iz * step)
			if not _is_open(space, p):
				continue
			var d := Vector2(ix, iz).length()
			if d < best_d:
				best_d = d
				best = Vector3(p.x, 0.05, p.z)
	print("SPAWN ", best)
	return best

func _is_open(space: PhysicsDirectSpaceState3D, p: Vector3) -> bool:
	for o in [Vector3.ZERO, Vector3(2.5, 0, 0), Vector3(-2.5, 0, 0), Vector3(0, 0, 2.5), Vector3(0, 0, -2.5)]:
		var q := PhysicsRayQueryParameters3D.create(p + o, p + o + Vector3(0, -120, 0))
		var hit := space.intersect_ray(q)
		if hit.is_empty() or (hit["position"] as Vector3).y > 0.4:
			return false
	return true


# ================================================================ unités
func units_of_team(t: int) -> Array:
	var out: Array = []
	if hero and hero.team == t:
		out.append(hero)
	for m in mobs:
		if (m as Mob).team == t:
			out.append(m)
	return out

func all_mobs() -> Array:
	return mobs

func shadow_list() -> Array:
	var out: Array = []
	for m in mobs:
		var mm := m as Mob
		if mm.is_shadow and not mm.dead:
			out.append(mm)
	return out

func shadow_count() -> int:
	var n := 0
	for m in mobs:
		var mm := m as Mob
		if mm.is_shadow and not mm.dead:
			n += 1
	return n

func spawn_free_mob(kind: String, pos: Vector3) -> Mob:
	var m := Mob.new()
	m.world = self
	m.main = self
	add_child(m)
	m.configure(kind)
	m.global_position = pos + Vector3(0, 0.3, 0)
	m.home = pos
	m.died.connect(_on_mob_died)
	mobs.append(m)
	return m

func spawn_mob(kind: String, pos: Vector3, camp: Dictionary) -> Mob:
	var m := spawn_free_mob(kind, pos)
	camp["members"].append(m)
	return m

func _make_camps(origin: Vector3) -> void:
	var space := get_world_3d().direct_space_state
	var comps := [["goblin", "goblin"], ["goblin", "goblin", "goblin"], ["goblin", "goblin", "shaman"], ["orc", "goblin"],
		["goblin", "goblin", "goblin", "shaman"], ["orc", "shaman", "shaman"], ["goblin", "shaman", "goblin"], ["orc", "orc"]]
	var spots: Array = []
	for r: float in [15.0, 24.0, 33.0, 44.0, 56.0, 70.0, 85.0, 100.0]:
		for k in 24:
			var a := k * TAU / 24.0 + r * 0.37
			var p := origin + Vector3(sin(a) * r, 0, cos(a) * r)
			if not _is_open(space, p + Vector3(0, 80, 0)):
				continue
			var ok := true
			for s in spots:
				if (s as Vector3).distance_to(p) < 14.0:
					ok = false
			if ok:
				spots.append(p)
				break
	for i in mini(spots.size(), comps.size()):
		var camp := {"pos": spots[i], "kinds": comps[i], "members": [], "respawn": -1.0}
		camps.append(camp)
		_fill_camp(camp)
	print("CAMPS ", camps.size())

func _fill_camp(camp: Dictionary) -> void:
	var kinds: Array = camp["kinds"]
	for i in kinds.size():
		var a := i * TAU / kinds.size()
		spawn_mob(kinds[i], (camp["pos"] as Vector3) + Vector3(sin(a), 0, cos(a)) * 2.2, camp)

# ---------------------------------------------------------------- camps d'élite sur les plateformes
func _make_elite_camps() -> void:
	var space := get_world_3d().direct_space_state
	var aabb := AABB()
	var first := true
	for mi in city.find_children("*", "MeshInstance3D", true, false):
		var bb: AABB = (mi as MeshInstance3D).global_transform * (mi as MeshInstance3D).get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var step := 2.0
	var nx := int(aabb.size.x / step)
	var nz := int(aabb.size.z / step)
	var H := PackedFloat32Array()
	H.resize(nx * nz)
	for ix in nx:
		for iz in nz:
			var p := Vector3(aabb.position.x + ix * step, 80, aabb.position.z + iz * step)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -120, 0)))
			H[ix * nz + iz] = (hit["position"] as Vector3).y if not hit.is_empty() else -99.0
	var cands: Array = []
	for lo: float in [0.08, 0.03]:
		for ix in range(4, nx - 4):
			for iz in range(4, nz - 4):
				var h0 := H[ix * nz + iz]
				if h0 < lo or h0 > 1.4:
					continue
				var flat := true
				for dx in range(-4, 5):
					for dz in range(-4, 5):
						if absf(H[(ix + dx) * nz + iz + dz] - h0) > 0.06:
							flat = false
							break
					if not flat:
						break
				if flat:
					cands.append(Vector3(aabb.position.x + ix * step, h0, aabb.position.z + iz * step))
		if cands.size() >= 3:
			break
	var chosen: Array = []
	cands.shuffle()
	for c in cands:
		var cv: Vector3 = c
		if cv.distance_to(spawn_point) < 18.0:
			continue
		var ok := true
		for o in chosen:
			if (o as Vector3).distance_to(cv) < 35.0:
				ok = false
		for cp in camps:
			if (cp["pos"] as Vector3).distance_to(cv) < 12.0:
				ok = false
		if ok:
			chosen.append(cv)
		if chosen.size() >= 4:
			break
	var comps := [["orc", "goblin", "goblin", "shaman"], ["goblin", "goblin", "shaman", "shaman"], ["orc", "orc", "shaman"], ["goblin", "goblin", "goblin", "orc"]]
	for i in chosen.size():
		var c := {"pos": chosen[i], "kinds": comps[i % comps.size()], "members": [], "state": "guarded", "timer": 0.0}
		var chest := (load("res://assets/chest_gold.glb") as PackedScene).instantiate() as Node3D
		add_child(chest)
		chest.global_position = chosen[i]
		chest.scale = Vector3.ONE * 0.9
		var lt := OmniLight3D.new()
		lt.light_color = Color(1, 0.75, 0.3)
		lt.light_energy = 1.6
		lt.omni_range = 5.0
		lt.position.y = 1.6
		chest.add_child(lt)
		var lb := Label3D.new()
		lb.font_size = 40
		lb.pixel_size = 0.006
		lb.outline_size = 10
		lb.modulate = Color(1, 0.85, 0.4)
		lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		lb.position.y = 2.1
		lb.text = "Coffre gardé"
		chest.add_child(lb)
		var ring := FX.ground_disc(6.5, Color(1, 0.6, 0.15), 0.18, true)
		add_child(ring)
		ring.global_position = chosen[i] + Vector3(0, 0.03, 0)
		c["chest"] = chest
		c["label"] = lb
		elite_camps.append(c)
		_fill_elite(c)
	print("ELITE_CAMPS ", elite_camps.size(), " candidats ", cands.size())

func _fill_elite(c: Dictionary) -> void:
	c["members"] = []
	var kinds: Array = c["kinds"]
	for i in kinds.size():
		var a := i * TAU / kinds.size() + 0.4
		var m := spawn_free_mob(kinds[i], (c["pos"] as Vector3) + Vector3(sin(a), 0, cos(a)) * 3.4)
		m.make_elite()
		m.leash_r = 18.0
		c["members"].append(m)
	c["state"] = "guarded"

func _camp_cleared(c: Dictionary) -> bool:
	for m in c["members"]:
		if not (m as Mob).dead and not (m as Mob).is_shadow:
			return false
	return true

func _open_elite_chest(c: Dictionary) -> void:
	var g := randi_range(180, 320)
	gold += g
	essence += 2
	rep += 8
	c["state"] = "cooldown"
	c["timer"] = 300.0
	var ch: Node3D = c["chest"]
	FX.burst(self, ch.global_position + Vector3(0, 1.2, 0), Color(1, 0.8, 0.2), 60, 0.12, 5.0, 1.0, 6.0)
	FX.damage_number(self, ch.global_position, "+%d or  +2 essences" % g, Color(1, 0.85, 0.3), true)
	system_msg("[ SYSTÈME ]\nCoffre d'élite ouvert : %d or, 2 essences.\nRéputation +8" % g)

# ---------------------------------------------------------------- récompenses
func _on_mob_died(u: Unit) -> void:
	var m := u as Mob
	if m.is_shadow:
		system_msg("Une ombre est tombée.")
		var tw := m.create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(m, "scale", Vector3(1, 0.01, 1), 0.6)
		tw.tween_callback(_remove_mob.bind(m))
		return
	if m.kind == "guard":
		rep = maxi(rep - 6, -50)
		_check_guards()
		return
	if m.boss:
		_on_boss_dead(m)
		return
	gold += m.reward_gold
	rep += 3 if m.elite else 1
	var xpv := {"goblin": 12.0, "shaman": 15.0, "orc": 35.0, "igris": 600.0}.get(m.kind, 10.0) as float
	hero.gain_xp(xpv * (3.0 if m.elite else 1.0))
	if randf() < (0.5 if m.elite else 0.12):
		essence += 1
	FX.damage_number(self, m.global_position + Vector3(0, -0.8, 0), "+%d or" % m.reward_gold, Color(1, 0.85, 0.3))

func _remove_mob(m: Mob) -> void:
	mobs.erase(m)
	for c in camps:
		(c["members"] as Array).erase(m)
	m.queue_free()

func on_shadow_raised(m: Mob) -> void:
	for c in camps:
		(c["members"] as Array).erase(m)
	system_msg("[ SYSTÈME ]\nExtraction réussie : %s" % m.display_name)

func rep_title() -> String:
	if rep >= 60:
		return "Célèbre"
	if rep >= REP_PASS:
		return "Reconnu"
	if rep >= 10:
		return "Remarqué"
	if rep < 0:
		return "Hors-la-loi"
	return "Inconnu"

# ================================================================ portail + gardes
func _spawn_gate(first: bool) -> void:
	var space := get_world_3d().direct_space_state
	var pos := spawn_point + Vector3(0, 0, -14)
	for tries in 300:
		var a := randf() * TAU
		var r := randf_range(25.0, 110.0) if not first else randf_range(22.0, 40.0)
		var p := spawn_point + Vector3(sin(a) * r, 0, cos(a) * r)
		if gate_pos != Vector3.ZERO and p.distance_to(gate_pos) < 40.0:
			continue
		if hero and p.distance_to(hero.global_position) < 18.0:
			continue
		if _is_open(space, p + Vector3(0, 80, 0)) and _is_open(space, p + Vector3(3, 80, 0)) and _is_open(space, p + Vector3(-3, 80, 0)):
			pos = p
			break
	gate_pos = pos
	if gate:
		gate.queue_free()
	gate = FX.portal(self, pos, Color(0.25, 0.55, 1.0), 2.4)
	gate_timer = GATE_PERIOD
	gate_open_for_me = false
	guards_hostile = false
	for g in guards:
		if is_instance_valid(g):
			mobs.erase(g)
			(g as Node).queue_free()
	guards.clear()
	for k in 2:
		var gp := pos + Vector3(-3.5 + 7.0 * k, 0, 2.5)
		var g := spawn_free_mob("guard", gp)
		g.patrol = [pos + Vector3(-5, 0, 4), pos + Vector3(5, 0, 4), pos + Vector3(5, 0, -4), pos + Vector3(-5, 0, -4)]
		g.patrol_i = k * 2
		guards.append(g)
	if not first:
		_build_dungeon()
		_build_hall()
		system_msg("[ SYSTÈME ]\nUn nouveau Portail s'est ouvert ailleurs en ville !")
	print("GATE ", pos)

func _check_guards() -> void:
	for g in guards:
		if is_instance_valid(g) and not (g as Mob).dead:
			return
	gate_open_for_me = true
	system_msg("[ SYSTÈME ]\nLes gardes sont hors de combat. Le portail est libre.\nRéputation en baisse.")

func _guards_greet() -> void:
	for g in guards:
		var gg := g as Mob
		if is_instance_valid(gg) and not gg.dead:
			gg.play("Salute", 0.2, 1.0, true)
			FX.speech(gg, "Respect, Chasseur. Le portail est à toi.", Color(0.7, 0.85, 1.0))

func _guard_dialogue() -> void:
	var g := _nearest_guard()
	if g == null:
		return
	g.face_to(hero.global_position, true)
	hero.face_to(g.global_position, true)
	var choices: Array = []
	choices.append(["« Je suis chasseur. Laissez-moi passer. »", _dlg_license])
	choices.append(["« 300 pièces d'or pour regarder ailleurs ? »" + ("" if gold >= 300 else "  (or insuffisant)"), _dlg_bribe])
	choices.append(["« Je passerai de force. »", _dlg_force])
	choices.append(["« Je repasserai. »", _dlg_leave])
	dialogue("Garde de l'Association", "Halte. Ce Portail de rang C est sous le contrôle de l'Association des Chasseurs. Personne n'entre sans autorisation.\n(Réputation : %d — il faut %d)" % [rep, REP_PASS], choices)

func _nearest_guard() -> Mob:
	var best: Mob = null
	var bd := 1e9
	for g in guards:
		var gg := g as Mob
		if is_instance_valid(gg) and not gg.dead:
			var d := gg.global_position.distance_to(hero.global_position)
			if d < bd:
				bd = d
				best = gg
	return best

func _dlg_license() -> void:
	if rep >= REP_PASS:
		dialogue("Garde de l'Association", "...Ton nom circule à l'Association. Passe. Et ne meurs pas là-dedans.", [["Entrer dans le portail", _close_and_open_gate]])
	else:
		guard_talk_cd = 12.0
		dialogue("Garde de l'Association", "Jamais entendu parler de toi. Nettoie les rues, ouvre les coffres d'élite, fais-toi un nom. Reviens avec %d de réputation." % REP_PASS, [["« Très bien. »", close_dialogue]])

func _dlg_bribe() -> void:
	if gold < 300:
		guard_talk_cd = 6.0
		dialogue("Garde de l'Association", "Avec quoi ? Tes poches sont vides, chasseur.", [["« ... »", close_dialogue]])
		return
	gold -= 300
	rep = maxi(rep - 3, -50)
	dialogue("Garde de l'Association", "(Il compte les pièces.) ...Je n'ai rien vu. Fais vite.", [["Entrer dans le portail", _close_and_open_gate]])

func _dlg_force() -> void:
	close_dialogue()
	guards_hostile = true
	rep = maxi(rep - 10, -50)
	for g in guards:
		var gg := g as Mob
		if is_instance_valid(gg) and not gg.dead:
			gg.team = 1
			gg.set_target(hero)
			gg.leash_r = 40.0
			gg.home = gate_pos
			FX.speech(gg, "Tu l'auras voulu !", Color(0.7, 0.85, 1.0))
	system_msg("[ SYSTÈME ]\nTu attaques l'Association. Réputation -10.")

func _dlg_leave() -> void:
	guard_talk_cd = 10.0
	close_dialogue()

func _close_and_open_gate() -> void:
	close_dialogue()
	gate_open_for_me = true

# ================================================================ donjon
func _build_dungeon() -> void:
	if dungeon:
		for r in dungeon.rooms:
			for m in r["mobs"]:
				if is_instance_valid(m) and not (m as Mob).is_shadow:
					mobs.erase(m)
					(m as Node).queue_free()
		dungeon.queue_free()
	dungeon = Dungeon.new()
	add_child(dungeon)
	dungeon.position = DUN_O
	dungeon.build(self)
	dungeon.visible = zone == "dungeon"
	await get_tree().physics_frame
	await get_tree().physics_frame
	dungeon.layout()

func _build_hall() -> void:
	if hall == null:
		hall = (load("res://assets/hall.glb") as PackedScene).instantiate()
		add_child(hall)
		hall.position = HALL_O
		for mi in hall.find_children("*", "MeshInstance3D", true, false):
			var m := mi as MeshInstance3D
			var sh := m.mesh.create_trimesh_shape()
			var body := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			cs.shape = sh
			body.add_child(cs)
			m.add_child(body)
		var lt := OmniLight3D.new()
		lt.light_color = Color(1, 0.7, 0.6)
		lt.light_energy = 1.8
		lt.omni_range = 40.0
		lt.position = Vector3(0, 14, 0)
		hall.add_child(lt)
		hall.visible = false
	if boss and is_instance_valid(boss) and not boss.is_shadow:
		mobs.erase(boss)
		boss.queue_free()
	boss = null
	boss_started = false
	boss_reward_taken = false
	if exit_portal:
		exit_portal.queue_free()
		exit_portal = null
	exit_pos = Vector3.INF
	if boss_chest:
		boss_chest.queue_free()
		boss_chest = null

func _hall_floor(x: float, z: float) -> Vector3:
	var space := get_world_3d().direct_space_state
	var p := HALL_O + Vector3(x, 40, z)
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -80, 0)))
	return (hit["position"] as Vector3) if not hit.is_empty() else HALL_O + Vector3(x, 5, z)

func _set_zone(z: String) -> void:
	zone = z
	city.visible = z == "city"
	dungeon.visible = z == "dungeon"
	hall.visible = z == "hall"
	if gate:
		gate.visible = z == "city"
	world_env.environment = env_city if z == "city" else (env_dun if z == "dungeon" else env_hall)
	moon.visible = true

func _teleport(p: Vector3, z: String) -> void:
	fade.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.25)
	await tw.finished
	_set_zone(z)
	hero.global_position = p + Vector3(0, 0.3, 0)
	hero.velocity = Vector3.ZERO
	for m in mobs:
		var mm := m as Mob
		if mm.is_shadow and not mm.dead:
			mm.global_position = p + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2))
	cam_pivot.global_position = hero.global_position + Vector3(0, 1.55, 0)
	var tw2 := create_tween()
	tw2.tween_property(fade, "modulate:a", 0.0, 0.35)

func enter_dungeon() -> void:
	await _teleport(dungeon.entry_point, "dungeon")
	var dn := dungeon.next_target() - dungeon.entry_point
	yaw = atan2(-dn.x, -dn.z)
	system_msg("[ SYSTÈME ]\nTu es entré dans le Portail.\nDonjon : la Forteresse du Commandant Écarlate.")

func enter_hall() -> void:
	hall_entry = _hall_floor(-17.0, 0.0)
	await _teleport(hall_entry, "hall")
	var bpos := _hall_floor(12.0, 0.0)
	boss = spawn_free_mob("igris", bpos)
	boss.home = bpos
	boss.leash_r = 200.0
	boss.dormant = true
	boss.face_to(hall_entry, true)
	yaw = -PI * 0.5
	var d := bpos - hall_entry
	yaw = atan2(-d.x, -d.z)
	await get_tree().create_timer(0.6).timeout
	_boss_dialogue()

func _boss_dialogue() -> void:
	boss.play("Talk", 0.2, 1.0, true)
	dialogue("Commandant Écarlate", "...Un humain. Dans MA salle. Ton espèce a toujours eu l'insolence des insectes qui ignorent le talon qui va les écraser.", [
		["« Je recule. Ce combat n'est pas pour moi. »", _boss_flee],
		["« Recule, toi. Ou tu finiras à genoux. »", _boss_taunt],
		["« Qui es-tu ? »", _boss_who],
	])

func _boss_who() -> void:
	dialogue("Commandant Écarlate", "Je suis le Commandant Écarlate. Mon Roi m'a confié ce trône il y a mille ans. Des milliers d'humains ont franchi ce seuil. Aucun n'en est ressorti debout.", [
		["« Alors je serai le premier. »", _boss_fight],
		["« Recule, toi. Ou tu finiras à genoux. »", _boss_taunt],
		["« ...Je m'en vais. »", _boss_flee],
	])

func _boss_flee() -> void:
	dialogue("Commandant Écarlate", "Sage. La peur est la seule intelligence de ta race. Rampe hors d'ici, et raconte aux tiens ce qui les attend.", [["Quitter le donjon", _boss_flee_go]])

func _boss_flee_go() -> void:
	close_dialogue()
	boss.queue_free()
	mobs.erase(boss)
	boss = null
	await _teleport(gate_pos + Vector3(0, 0, 5), "city")

func _boss_taunt() -> void:
	boss_enraged_choice = true
	boss.dmg *= 1.2
	boss.play("Taunt", 0.1, 1.0, true)
	dialogue("Commandant Écarlate", "À genoux ? ...HA. HAHAHA ! Je vais graver cette insolence dans tes os, humain. Lentement.", [["Dégainer", _boss_fight]])

func _boss_fight() -> void:
	close_dialogue()
	boss_started = true
	boss.dormant = false
	boss.set_target(hero)
	boss_bar_root.visible = true
	FX.speech(boss, "Viens. Montre-moi ce que vaut un humain.", Color(1, 0.4, 0.35), 3.5)
	shake(0.3)

func boss_phase2(b: Mob) -> void:
	system_msg("[ SYSTÈME ]\nLe Commandant Écarlate entre en rage !")
	for k in 2:
		var p := b.global_position + Vector3(sin(k * PI + 0.7) * 5.0, 0, cos(k * PI + 0.7) * 5.0)
		FX.portal(self, p, Color(1, 0.1, 0.1), 1.2)
		var m := spawn_free_mob("goblin", p)
		m.make_elite()
		m.set_target(hero)
		m.leash_r = 200.0

func _on_boss_dead(b: Mob) -> void:
	boss_bar_root.visible = false
	hero.gain_xp(600.0)
	rep += 25
	system_msg("[ SYSTÈME ]\nDonjon conquis ! Réputation +25.\nUne ombre d'une puissance exceptionnelle peut être extraite...")
	boss_chest = (load("res://assets/chest_gold.glb") as PackedScene).instantiate() as Node3D
	add_child(boss_chest)
	boss_chest.global_position = _hall_floor(16.0, 0.0)
	boss_chest.scale = Vector3.ONE * 1.3
	var lt := OmniLight3D.new()
	lt.light_color = Color(1, 0.8, 0.3)
	lt.light_energy = 2.5
	lt.omni_range = 7.0
	lt.position.y = 2.0
	boss_chest.add_child(lt)
	exit_pos = _hall_floor(-14.0, 0.0)
	exit_portal = FX.portal(self, exit_pos, Color(0.25, 0.55, 1.0), 1.8)

func _open_boss_chest() -> void:
	boss_reward_taken = true
	gold += 1500
	essence += 10
	hero.equip_blade()
	FX.burst(self, boss_chest.global_position + Vector3(0, 1.4, 0), Color(1, 0.8, 0.2), 90, 0.14, 6.0, 1.2, 6.0)
	system_msg("[ SYSTÈME ]\nTu obtiens : LAME DU COMMANDANT (+45 % dégâts)\n1500 or, 10 essences.")

func _leave_dungeon() -> void:
	await _teleport(gate_pos + Vector3(0, 0, 5), "city")
	_spawn_gate(false)

# ================================================================ dialogue
func dialogue(speaker: String, text: String, choices: Array) -> void:
	in_dialogue = true
	hero.move_input = Vector2.ZERO
	dlg_panel.visible = true
	dlg_name.text = speaker
	dlg_text.text = text
	dlg_text.visible_ratio = 0.0
	var tw := create_tween()
	tw.tween_property(dlg_text, "visible_ratio", 1.0, clampf(text.length() / 70.0, 0.4, 2.5))
	for c in dlg_choices.get_children():
		c.queue_free()
	for ch in choices:
		var b := Button.new()
		b.text = str(ch[0])
		b.alignment = HORIZONTAL_ALIGNMENT_LEFT
		b.add_theme_font_size_override("font_size", 22)
		b.add_theme_color_override("font_color", Color(0.85, 0.93, 1))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(0.05, 0.1, 0.25, 0.85)
		sb.border_color = Color(0.4, 0.7, 1.0)
		sb.set_border_width_all(1)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 14
		sb.content_margin_top = 8
		sb.content_margin_bottom = 8
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		var sp: StyleBoxFlat = sb.duplicate()
		sp.bg_color = Color(0.2, 0.35, 0.7, 0.95)
		b.add_theme_stylebox_override("pressed", sp)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(ch[1])
		dlg_choices.add_child(b)

func close_dialogue() -> void:
	in_dialogue = false
	dlg_panel.visible = false

func choose(i: int) -> void:
	var kids := dlg_choices.get_children()
	if i < kids.size():
		(kids[i] as Button).pressed.emit()

# ================================================================ boucle
func on_hero_died() -> void:
	system_msg("[ SYSTÈME ]\nTu es tombé... Résurrection en ville dans 4 s.")
	await get_tree().create_timer(4.0).timeout
	if zone == "hall" and boss and is_instance_valid(boss) and not boss.dead:
		boss_bar_root.visible = false
		mobs.erase(boss)
		boss.queue_free()
		boss = null
	hero.dead = false
	hero.hp = hero.max_hp
	hero.mp = hero.max_mp
	hero.busy = 0.0
	hero.collision_layer = 4
	hero.collision_mask = 3
	hero.ring.visible = true
	hero.play("Idle", 0.1, 1.0, true)
	await _teleport(spawn_point, "city")

func fov_kick(a: float) -> void:
	cam.fov = base_fov + a
	var tw := create_tween()
	tw.tween_property(cam, "fov", base_fov, 0.25)

func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)

func hit_stop(t: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	# camps normaux : réapparition
	for c in camps:
		var alive := false
		for m in c["members"]:
			if not (m as Mob).dead:
				alive = true
		if not alive:
			if c["respawn"] < 0.0:
				c["respawn"] = 35.0
			c["respawn"] -= delta
			if c["respawn"] <= 0.0:
				c["respawn"] = -1.0
				for m in (c["members"] as Array).duplicate():
					_remove_mob(m)
				_fill_camp(c)
	# camps d'élite : coffre + minuteur
	for c in elite_camps:
		var lb: Label3D = c["label"]
		match str(c["state"]):
			"guarded":
				lb.text = "Coffre d'élite — déverrouillé !" if _camp_cleared(c) else "Coffre gardé par l'élite"
			"cooldown":
				c["timer"] = float(c["timer"]) - delta
				var t := int(c["timer"])
				lb.text = "Réapparition %d:%02d" % [t / 60, t % 60]
				if float(c["timer"]) <= 0.0:
					for m in (c["members"] as Array):
						if is_instance_valid(m) and not (m as Mob).is_shadow:
							_remove_mob(m)
					_fill_elite(c)
	# portail : déplacement toutes les 15 min
	gate_timer -= delta
	guard_talk_cd -= delta
	if gate_timer <= 0.0 and zone == "city":
		_spawn_gate(false)
	if zone == "city" and not in_dialogue and gate:
		var dg := hero.global_position.distance_to(gate_pos)
		if dg < 10.0 and not gate_open_for_me and not guards_hostile:
			if rep >= REP_PASS:
				gate_open_for_me = true
				_guards_greet()
			elif guard_talk_cd <= 0.0 and _nearest_guard() != null:
				guard_talk_cd = 999.0
				_guard_dialogue()
	if zone == "dungeon" and dungeon:
		dungeon.update(hero)
	if boss and is_instance_valid(boss) and boss_bar_root.visible:
		boss_bar_fill.size.x = 600.0 * clampf(boss.hp / boss.max_hp, 0, 1)
	if focus_target and is_instance_valid(focus_target) and not focus_target.dead:
		focus_marker.visible = true
		focus_marker.global_position = focus_target.global_position + Vector3(0, 3.0 if (focus_target as Mob).kind == "orc" else 2.55, 0) + Vector3(0, sin(Time.get_ticks_msec() * 0.006) * 0.12, 0)
		focus_marker.rotation.y += delta * 3.0
	else:
		focus_marker.visible = false
		focus_target = null
	if menu_panel.visible:
		menu_refresh -= delta
		if menu_refresh <= 0.0:
			menu_refresh = 1.0
			_refresh_menu()
	_update_interact()
	_update_ui()

func _update_interact() -> void:
	var label := ""
	var act := Callable()
	if not in_dialogue and not hero.dead:
		if zone == "city":
			for c in elite_camps:
				if str(c["state"]) == "guarded" and _camp_cleared(c) and hero.global_position.distance_to((c["chest"] as Node3D).global_position) < 3.0:
					label = "OUVRIR LE COFFRE"
					act = _open_elite_chest.bind(c)
			if gate and hero.global_position.distance_to(gate_pos) < 4.0:
				if gate_open_for_me:
					label = "ENTRER DANS LE PORTAIL"
					act = enter_dungeon
				elif not guards_hostile and _nearest_guard() != null:
					label = "PARLER AU GARDE"
					act = _guard_dialogue
		elif zone == "dungeon":
			if hero.global_position.distance_to(dungeon.throne_door) < 4.5:
				if dungeon.all_cleared():
					label = "FRANCHIR LA PORTE DU TRÔNE"
					act = enter_hall
		elif zone == "hall":
			if boss_chest and not boss_reward_taken and hero.global_position.distance_to(boss_chest.global_position) < 3.2:
				label = "OUVRIR LE COFFRE DU COMMANDANT"
				act = _open_boss_chest
			elif exit_pos != Vector3.INF and hero.global_position.distance_to(exit_pos) < 3.0:
				label = "QUITTER LE DONJON"
				act = _leave_dungeon
	interact_btn.visible = label != ""
	interact_btn.text = label
	interact_action = act

func _on_interact() -> void:
	if interact_action.is_valid():
		interact_action.call()

func _physics_process(delta: float) -> void:
	if hero == null:
		return
	hero.cam_yaw = yaw
	cam_pivot.global_position = cam_pivot.global_position.lerp(hero.global_position + Vector3(0, 1.55, 0), clampf(12 * delta, 0, 1))
	cam_pivot.rotation = Vector3(pitch, yaw, 0)
	shake_amt = maxf(shake_amt - delta * 1.6, 0.0)
	cam.h_offset = randf_range(-1, 1) * shake_amt * 0.5
	cam.v_offset = randf_range(-1, 1) * shake_amt * 0.5

func _build_camera() -> void:
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 4.7
	spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	spring.collision_mask = 1
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = base_fov
	cam.far = 700.0
	spring.add_child(cam)
	cam.current = true

func _panel_style(bg: Color, border: Color) -> StyleBoxFlat:
	var ps := StyleBoxFlat.new()
	ps.bg_color = bg
	ps.border_color = border
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(8)
	ps.shadow_color = Color(border.r, border.g, border.b, 0.45)
	ps.shadow_size = 10
	ps.content_margin_left = 16
	ps.content_margin_right = 16
	ps.content_margin_top = 10
	ps.content_margin_bottom = 10
	return ps

func _bar(parent: Control, pos: Vector2, w: float, col: Color) -> ColorRect:
	var bg := ColorRect.new()
	bg.color = Color(0, 0, 0, 0.6)
	bg.position = pos
	bg.size = Vector2(w, 18)
	parent.add_child(bg)
	var f := ColorRect.new()
	f.color = col
	f.size = Vector2(w, 18)
	bg.add_child(f)
	return f

func _skill_button(layer: CanvasLayer, key: String, txt: String, off: Vector2, size: float, col: Color, cb: Callable) -> void:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", 24 if size > 150 else 18)
	b.add_theme_color_override("font_color", Color(0.9, 0.95, 1))
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.03, 0.05, 0.14, 0.78)
	sb.border_color = col
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(int(size / 2))
	sb.shadow_color = Color(col.r, col.g, col.b, 0.55)
	sb.shadow_size = 12
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	b.add_theme_stylebox_override("focus", sb)
	var sp: StyleBoxFlat = sb.duplicate()
	sp.bg_color = Color(col.r * 0.5, col.g * 0.5, col.b * 0.6, 0.95)
	b.add_theme_stylebox_override("pressed", sp)
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = off.x
	b.offset_top = off.y
	b.offset_right = off.x + size
	b.offset_bottom = off.y + size
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(cb)
	layer.add_child(b)
	var shade := Panel.new()
	var ss := StyleBoxFlat.new()
	ss.bg_color = Color(0, 0, 0, 0.62)
	ss.set_corner_radius_all(int(size / 2))
	shade.add_theme_stylebox_override("panel", ss)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	b.add_child(shade)
	var cdl := Label.new()
	cdl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cdl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cdl.add_theme_font_size_override("font_size", 40)
	cdl.add_theme_color_override("font_color", Color(1, 1, 1))
	cdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cdl)
	buttons[key] = {"btn": b, "shade": shade, "label": cdl}


# ================================================================ UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	joy_ui = Control.new()
	joy_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.draw.connect(_draw_joy)
	layer.add_child(joy_ui)
	var card := Panel.new()
	card.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.1, 0.78), Color(0.35, 0.65, 1.0)))
	card.position = Vector2(20, 18)
	card.size = Vector2(360, 104)
	card.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(card)
	var nm := Label.new()
	nm.text = "CHASSEUR  ·  Rang E"
	nm.position = Vector2(16, 8)
	nm.add_theme_font_size_override("font_size", 22)
	nm.add_theme_color_override("font_color", Color(0.8, 0.92, 1))
	card.add_child(nm)
	hp_fill = _bar(card, Vector2(16, 42), 328, Color(0.9, 0.18, 0.22))
	mp_fill = _bar(card, Vector2(16, 68), 328, Color(0.25, 0.5, 1.0))
	hp_txt = Label.new()
	hp_txt.position = Vector2(20, 38)
	hp_txt.add_theme_font_size_override("font_size", 15)
	card.add_child(hp_txt)
	shadow_txt = _outlined(layer, Vector2(24, 128), 20, Color(0.75, 0.55, 1))
	res_txt = _outlined(layer, Vector2(0, 0), 20, Color(1, 0.85, 0.45))
	res_txt.anchor_left = 1.0
	res_txt.anchor_right = 1.0
	res_txt.offset_left = -470
	res_txt.offset_right = -20
	res_txt.offset_top = 18
	res_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	gate_txt = _outlined(layer, Vector2(0, 0), 20, Color(0.55, 0.8, 1))
	gate_txt.anchor_left = 1.0
	gate_txt.anchor_right = 1.0
	gate_txt.offset_left = -470
	gate_txt.offset_right = -20
	gate_txt.offset_top = 76
	gate_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# boutons de combat
	_skill_button(layer, "attack", "ÉPÉE", Vector2(-235, -235), 180, Color(0.35, 0.7, 1.0), hero.attack)
	_skill_button(layer, "step", "PAS DE\nL'OMBRE", Vector2(-420, -165), 128, Color(0.6, 0.35, 1.0), _do_step)
	_skill_button(layer, "arise", "ARISE", Vector2(-205, -420), 128, Color(0.75, 0.3, 1.0), _do_arise)
	_skill_button(layer, "roll", "ESQUIVE", Vector2(-385, -330), 104, Color(0.4, 0.85, 1.0), hero.roll)
	_skill_button(layer, "jump", "SAUT", Vector2(-545, -130), 104, Color(0.5, 0.9, 0.7), hero.jump)
	unarmed_btn = _small_btn("MAINS NUES")
	unarmed_btn.anchor_left = 1.0
	unarmed_btn.anchor_right = 1.0
	unarmed_btn.anchor_top = 1.0
	unarmed_btn.anchor_bottom = 1.0
	unarmed_btn.offset_left = -560
	unarmed_btn.offset_right = -420
	unarmed_btn.offset_top = -205
	unarmed_btn.offset_bottom = -160
	unarmed_btn.pressed.connect(_toggle_unarmed)
	layer.add_child(unarmed_btn)
	buttons["unarmed"] = {"btn": unarmed_btn, "shade": null, "label": null}
	_build_menu(layer)
	# bouton contextuel
	interact_btn = Button.new()
	interact_btn.add_theme_font_size_override("font_size", 22)
	var isb := _panel_style(Color(0.25, 0.17, 0.02, 0.88), Color(1, 0.8, 0.3))
	interact_btn.add_theme_stylebox_override("normal", isb)
	interact_btn.add_theme_stylebox_override("hover", isb)
	interact_btn.add_theme_color_override("font_color", Color(1, 0.92, 0.7))
	interact_btn.anchor_left = 0.5
	interact_btn.anchor_right = 0.5
	interact_btn.anchor_top = 1.0
	interact_btn.anchor_bottom = 1.0
	interact_btn.offset_left = -210
	interact_btn.offset_right = 210
	interact_btn.offset_top = -200
	interact_btn.offset_bottom = -130
	interact_btn.focus_mode = Control.FOCUS_NONE
	interact_btn.visible = false
	interact_btn.pressed.connect(_on_interact)
	layer.add_child(interact_btn)
	buttons["interact"] = {"btn": interact_btn, "shade": null, "label": null}
	# message système
	msg_panel = PanelContainer.new()
	msg_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.05, 0.14, 0.85), Color(0.4, 0.75, 1)))
	msg_label = Label.new()
	msg_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	msg_label.add_theme_font_size_override("font_size", 24)
	msg_label.add_theme_color_override("font_color", Color(0.82, 0.93, 1))
	msg_panel.add_child(msg_label)
	msg_panel.anchor_left = 0.5
	msg_panel.anchor_right = 0.5
	msg_panel.offset_left = -290
	msg_panel.offset_right = 290
	msg_panel.offset_top = 24
	msg_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	msg_panel.modulate.a = 0.0
	layer.add_child(msg_panel)
	# barre de boss
	boss_bar_root = Control.new()
	boss_bar_root.anchor_left = 0.5
	boss_bar_root.anchor_right = 0.5
	boss_bar_root.offset_left = -300
	boss_bar_root.offset_right = 300
	boss_bar_root.offset_top = 150
	boss_bar_root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	boss_bar_root.visible = false
	layer.add_child(boss_bar_root)
	boss_bar_name = _outlined(boss_bar_root, Vector2(0, 0), 26, Color(1, 0.45, 0.4))
	boss_bar_name.text = "COMMANDANT ÉCARLATE — Boss de rang C"
	var bb := ColorRect.new()
	bb.color = Color(0, 0, 0, 0.7)
	bb.position = Vector2(0, 38)
	bb.size = Vector2(600, 22)
	boss_bar_root.add_child(bb)
	boss_bar_fill = ColorRect.new()
	boss_bar_fill.color = Color(0.85, 0.05, 0.1)
	boss_bar_fill.size = Vector2(600, 22)
	bb.add_child(boss_bar_fill)
	# boîte de dialogue
	dlg_panel = PanelContainer.new()
	dlg_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.12, 0.93), Color(0.45, 0.75, 1.0)))
	dlg_panel.anchor_left = 0.5
	dlg_panel.anchor_right = 0.5
	dlg_panel.anchor_top = 1.0
	dlg_panel.anchor_bottom = 1.0
	dlg_panel.offset_left = -470
	dlg_panel.offset_right = 470
	dlg_panel.offset_top = -380
	dlg_panel.offset_bottom = -20
	dlg_panel.visible = false
	layer.add_child(dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg_panel.add_child(vb)
	dlg_name = Label.new()
	dlg_name.add_theme_font_size_override("font_size", 26)
	dlg_name.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	vb.add_child(dlg_name)
	dlg_text = Label.new()
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(900, 0)
	dlg_text.add_theme_font_size_override("font_size", 23)
	dlg_text.add_theme_color_override("font_color", Color(0.9, 0.94, 1))
	vb.add_child(dlg_text)
	dlg_choices = VBoxContainer.new()
	dlg_choices.add_theme_constant_override("separation", 6)
	vb.add_child(dlg_choices)
	# fondu
	fade = ColorRect.new()
	fade.color = Color(0, 0, 0)
	fade.set_anchors_preset(Control.PRESET_FULL_RECT)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fade.modulate.a = 0.0
	layer.add_child(fade)

func _small_btn(t: String) -> Button:
	var b := Button.new()
	b.text = t
	b.add_theme_font_size_override("font_size", 17)
	b.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
	var sb := _panel_style(Color(0.03, 0.05, 0.14, 0.7), Color(0.45, 0.4, 0.9))
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	sb.content_margin_left = 12
	sb.content_margin_right = 12
	sb.shadow_size = 4
	b.add_theme_stylebox_override("normal", sb)
	b.add_theme_stylebox_override("hover", sb)
	var sp: StyleBoxFlat = sb.duplicate()
	sp.bg_color = Color(0.2, 0.15, 0.45, 0.9)
	b.add_theme_stylebox_override("pressed", sp)
	b.focus_mode = Control.FOCUS_NONE
	return b

func _toggle_unarmed() -> void:
	hero.toggle_unarmed()
	unarmed_btn.text = "ÉPÉE" if hero.unarmed_mode else "MAINS NUES"

# ---------------------------------------------------------------- menu discret : ombres + stats
func _build_menu(layer: CanvasLayer) -> void:
	var bx := HBoxContainer.new()
	bx.anchor_left = 1.0
	bx.anchor_right = 1.0
	bx.offset_left = -330
	bx.offset_right = -20
	bx.offset_top = 128
	bx.alignment = BoxContainer.ALIGNMENT_END
	bx.add_theme_constant_override("separation", 8)
	layer.add_child(bx)
	for k in [["OMBRES", "ombres"], ["STATS", "stats"]]:
		var b := _small_btn(str(k[0]))
		b.pressed.connect(_toggle_menu.bind(str(k[1])))
		bx.add_child(b)
		buttons["menu_" + str(k[1])] = {"btn": b, "shade": null, "label": null}
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.03, 0.1, 0.88), Color(0.5, 0.35, 1.0)))
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.offset_left = -290
	menu_panel.offset_right = 290
	menu_panel.offset_top = 110
	menu_panel.offset_bottom = 560
	menu_panel.visible = false
	layer.add_child(menu_panel)
	var sc := ScrollContainer.new()
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_panel.add_child(sc)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", 8)
	sc.add_child(menu_body)
	focus_marker = MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.28
	cm.bottom_radius = 0.0
	cm.height = 0.5
	focus_marker.mesh = cm
	focus_marker.material_override = FX.mat(Color(1, 0.2, 0.15), 3.0)
	focus_marker.visible = false
	add_child(focus_marker)

func _toggle_menu(tab: String) -> void:
	if menu_panel.visible and menu_tab == tab:
		menu_panel.visible = false
		return
	menu_tab = tab
	menu_panel.visible = true
	_refresh_menu()

func _lbl(t: String, size := 20, col := Color(0.85, 0.9, 1)) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return l

func _refresh_menu() -> void:
	for c in menu_body.get_children():
		c.queue_free()
	if menu_tab == "ombres":
		var sh := shadow_list()
		menu_body.add_child(_lbl("ARMÉE D'OMBRES   %d / %d" % [sh.size(), hero.max_shadows()], 24, Color(0.8, 0.65, 1)))
		menu_body.add_child(_lbl("Domaine d'ombre : %d m — coche les ombres à commander, puis donne l'ordre. Touche un ennemi à l'écran pour le cibler." % int(hero.domain_r()), 16, Color(0.7, 0.75, 0.9)))
		if sh.is_empty():
			menu_body.add_child(_lbl("Aucune ombre. Tue un monstre puis utilise ARISE.", 18))
		var names := {"auto": "Auto", "attack": "Attaque la cible", "follow": "Me suit", "hold": "Tient la position"}
		for m in sh:
			var mm := m as Mob
			var cb := CheckBox.new()
			cb.text = "%s  —  PV %d%%  —  %s" % [mm.display_name, int(100.0 * mm.hp / mm.max_hp), names.get(mm.order, mm.order)]
			cb.button_pressed = mm.selected
			cb.add_theme_font_size_override("font_size", 18)
			cb.toggled.connect(_set_sel.bind(mm))
			cb.focus_mode = Control.FOCUS_NONE
			menu_body.add_child(cb)
		var row1 := HBoxContainer.new()
		var row2 := HBoxContainer.new()
		for o in [["ATTAQUER LA CIBLE", "attack", row1], ["ME SUIVRE", "follow", row1], ["TENIR POSITION", "hold", row2], ["AUTO", "auto", row2]]:
			var b := _small_btn(str(o[0]))
			b.pressed.connect(_order.bind(str(o[1])))
			(o[2] as HBoxContainer).add_child(b)
		menu_body.add_child(row1)
		menu_body.add_child(row2)
	else:
		menu_body.add_child(_lbl("CHASSEUR — Niveau %d" % hero.level, 24, Color(1, 0.85, 0.5)))
		menu_body.add_child(_lbl("XP %d / %d      Points à répartir : %d" % [int(hero.xp), int(hero.xp_next()), hero.points], 18))
		var rows := [["force", "FORCE", "Dégâts %d" % int(hero.power())], ["agilite", "AGILITÉ", "Course %.1f m/s, escalade, Pas de l'ombre" % hero.run_speed()],
			["vitesse", "VITESSE D'ATTAQUE", "x%.2f" % hero.atk_speed()], ["domaine", "DOMAINE D'OMBRE", "Rayon %d m, %d ombres max" % [int(hero.domain_r()), hero.max_shadows()]]]
		for r in rows:
			var hb := HBoxContainer.new()
			hb.add_child(_lbl("%s  %d\n%s" % [r[1], hero.stats[r[0]], r[2]], 17))
			var b := _small_btn("+")
			b.disabled = hero.points <= 0
			b.custom_minimum_size = Vector2(56, 44)
			b.pressed.connect(_add_stat.bind(str(r[0])))
			hb.add_child(b)
			menu_body.add_child(hb)

func _set_sel(on: bool, m: Mob) -> void:
	m.selected = on

func _order(o: String) -> void:
	var n := 0
	for m in shadow_list():
		var mm := m as Mob
		if not mm.selected:
			continue
		mm.order = o
		mm.target = null
		mm.hold_pos = mm.global_position
		n += 1
		if o == "attack":
			FX.burst(self, mm.global_position + Vector3(0, 1.5, 0), Color(0.6, 0.3, 1.0), 10, 0.06, 2.0, 0.4, 0.0)
	if o == "attack" and (focus_target == null or not is_instance_valid(focus_target) or focus_target.dead):
		focus_target = hero.nearest_enemy(hero.domain_r())
	system_msg("%d ombre(s) : %s" % [n, {"attack": "à l'attaque !", "follow": "derrière toi.", "hold": "tiennent la position.", "auto": "mode autonome."}[o]])
	_refresh_menu()

func _add_stat(k: String) -> void:
	hero.add_stat(k)
	_refresh_menu()

func _try_select(p: Vector2) -> void:
	var from := cam.project_ray_origin(p)
	var to := from + cam.project_ray_normal(p) * 90.0
	var q := PhysicsRayQueryParameters3D.create(from, to)
	q.collision_mask = 2
	var hit := get_world_3d().direct_space_state.intersect_ray(q)
	if not hit.is_empty() and hit["collider"] is Mob and (hit["collider"] as Mob).team == 1:
		focus_target = hit["collider"]
		FX.burst(self, focus_target.global_position + Vector3(0, 2.2, 0), Color(1, 0.3, 0.2), 12, 0.06, 2.0, 0.3, 0.0)

func _outlined(parent: Node, pos: Vector2, size: int, col: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", col)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(l)
	return l

func _do_step() -> void:
	hero.shadow_step()

func _do_arise() -> void:
	hero.arise()

func _update_ui() -> void:
	if hero == null or hp_fill == null:
		return
	hp_fill.size.x = 328.0 * clampf(hero.hp / hero.max_hp, 0, 1)
	mp_fill.size.x = 328.0 * clampf(hero.mp / hero.max_mp, 0, 1)
	hp_txt.text = "PV %d / %d      PM %d" % [int(hero.hp), int(hero.max_hp), int(hero.mp)]
	shadow_txt.text = "Ombres  %d / 4" % shadow_count()
	res_txt.text = "Or %d    Essences %d\nRéputation %d  (%s)" % [gold, essence, rep, rep_title()]
	if zone == "city" and gate:
		var d := gate_pos - hero.global_position
		d.y = 0
		var rel := wrapf(atan2(-d.x, -d.z) - yaw, -PI, PI)
		var arrow := "↑"
		if absf(rel) > 2.4:
			arrow = "↓"
		elif rel > 0.6:
			arrow = "←"
		elif rel < -0.6:
			arrow = "→"
		var t := int(maxf(gate_timer, 0.0))
		gate_txt.text = "Portail rang C  %s  %d m\nSe déplace dans %d:%02d" % [arrow, int(d.length()), t / 60, t % 60]
	elif zone == "dungeon":
		var d2 := dungeon.next_target() - hero.global_position
		d2.y = 0
		var rel2 := wrapf(atan2(-d2.x, -d2.z) - yaw, -PI, PI)
		var ar := "↑"
		if absf(rel2) > 2.4:
			ar = "↓"
		elif rel2 > 0.6:
			ar = "←"
		elif rel2 < -0.6:
			ar = "→"
		var what := "Prochaine meute" if not dungeon.all_cleared() else "Portail du trône"
		gate_txt.text = "Marais du Portail — meutes %d / %d\n%s  %s  %d m" % [dungeon.cleared_count(), dungeon.rooms.size(), what, ar, int(d2.length())]
	else:
		gate_txt.text = "Salle du Trône"
	for k in buttons.keys():
		var d: Dictionary = buttons[k]
		if d["shade"] == null:
			continue
		var c: float = hero.cd[k]
		var mx: float = Hero.CD_MAX[k]
		var shade: Panel = d["shade"]
		var lab: Label = d["label"]
		var lacks_mp: bool = hero.mp < Hero.MP_COST.get(k, 0.0)
		shade.visible = c > 0.0 or lacks_mp
		shade.anchor_top = 1.0 - (c / mx if c > 0.0 else 1.0)
		shade.offset_top = 0
		lab.text = ("%d" % ceili(c)) if (c > 0.6 and k != "attack") else ""

func system_msg(t: String) -> void:
	msg_label.text = t
	if msg_tw:
		msg_tw.kill()
	msg_panel.modulate.a = 1.0
	msg_tw = create_tween()
	msg_tw.tween_interval(3.4)
	msg_tw.tween_property(msg_panel, "modulate:a", 0.0, 0.8)

func _draw_joy() -> void:
	var vp := joy_ui.get_viewport_rect().size
	var base := joy_center if joy_touch >= 0 else Vector2(200, vp.y - 200)
	var knob := joy_knob if joy_touch >= 0 else base
	joy_ui.draw_circle(base, JOY_R, Color(0.1, 0.25, 0.6, 0.22))
	joy_ui.draw_arc(base, JOY_R, 0, TAU, 48, Color(0.4, 0.75, 1, 0.7), 3.0)
	joy_ui.draw_circle(knob, 46, Color(0.35, 0.7, 1, 0.6))

func _on_button(p: Vector2) -> bool:
	for k in buttons.keys():
		var b: Button = buttons[k]["btn"]
		if b.visible and b.get_global_rect().grow(10).has_point(p):
			return true
	if dlg_panel.visible and dlg_panel.get_global_rect().has_point(p):
		return true
	if menu_panel and menu_panel.visible and menu_panel.get_global_rect().has_point(p):
		return true
	return false

func _input(event: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.45
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if _on_button(t.position):
				pass
			elif t.position.x < half and joy_touch < 0 and t.position.y > 150:
				joy_touch = t.index
				joy_center = t.position
				joy_knob = t.position
			elif t.position.x >= half and look_touch < 0:
				look_touch = t.index
				tap_pos = t.position
				tap_time = Time.get_ticks_msec() / 1000.0
		else:
			if t.index == look_touch and t.position.distance_to(tap_pos) < 16.0 and Time.get_ticks_msec() / 1000.0 - tap_time < 0.35:
				_try_select(t.position)
			if t.index == joy_touch:
				joy_touch = -1
				hero.move_input = Vector2.ZERO
			elif t.index == look_touch:
				look_touch = -1
		joy_ui.queue_redraw()
	elif event is InputEventScreenDrag:
		var dr := event as InputEventScreenDrag
		if dr.index == joy_touch:
			var d := dr.position - joy_center
			if d.length() > JOY_R:
				d = d.normalized() * JOY_R
			joy_knob = joy_center + d
			hero.move_input = d / JOY_R
			joy_ui.queue_redraw()
		elif dr.index == look_touch:
			yaw -= dr.relative.x * 0.006
			pitch = clampf(pitch - dr.relative.y * 0.004, -1.15, 0.2)

# ================================================================ captures CI (scénario complet)
func _snap(name: String, frames := 1) -> void:
	for i in frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	img.save_png("res://shots/%s.png" % name)
	print("SHOT ", name)

func _place_hero(p: Vector3, look_at_p: Vector3) -> void:
	hero.global_position = p + Vector3(0, 0.3, 0)
	var d := look_at_p - p
	yaw = atan2(-d.x, -d.z)
	cam_pivot.global_position = hero.global_position + Vector3(0, 1.55, 0)

func _kill_near(p: Vector3, r: float) -> void:
	for m in mobs.duplicate():
		var mm := m as Mob
		if not mm.dead and mm.team == 1 and mm.global_position.distance_to(p) < r:
			mm.take_damage(99999, hero)

func _run_shots() -> void:
	hero.max_hp = 99999
	hero.hp = 99999
	await _snap("00_depart", 20)
	# héros de face : épée rangée dans le dos, puis en main
	var y0 := yaw
	yaw = y0 + PI
	pitch = -0.1
	spring.spring_length = 2.6
	await _snap("01_heros_range", 20)
	hero.set_armed(true)
	await _snap("02_heros_arme", 20)
	yaw = y0 + PI * 0.5
	await _snap("02b_heros_profil", 10)
	hero.set_armed(false)
	pitch = -0.3
	spring.spring_length = 4.7
	# sprint
	yaw = y0
	hero.move_input = Vector2(0, -1)
	await _snap("03_sprint", 50)
	hero.move_input = Vector2.ZERO
	# escalade d'un immeuble
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	var bn := Vector3.ZERO
	for k in 24:
		var a := k * TAU / 24.0
		var d := Vector3(sin(a), 0, cos(a))
		var o := hero.global_position + Vector3(0, 1.2, 0)
		var q := PhysicsRayQueryParameters3D.create(o, o + d * 30.0)
		q.collision_mask = 1
		var hit := space.intersect_ray(q)
		if not hit.is_empty() and absf((hit["normal"] as Vector3).y) < 0.2:
			var top := space.intersect_ray(PhysicsRayQueryParameters3D.create((hit["position"] as Vector3) + d * 0.5 + Vector3(0, 6, 0), (hit["position"] as Vector3) + d * 0.5 + Vector3(0, 5, 0)))
			if not top.is_empty() or true:
				if best == Vector3.INF or (hit["position"] as Vector3).distance_to(o) < best.distance_to(o):
					best = hit["position"]
					bn = hit["normal"]
	if best != Vector3.INF:
		var start := best + bn * 4.0
		start.y = hero.global_position.y
		hero.global_position = start
		yaw = atan2(bn.x, bn.z)
		hero.move_input = Vector2(0, -1)
		await _snap("04_course_vers_mur", 14)
		hero.jump()
		await _snap("05_escalade", 30)
		await _snap("06_escalade_haut", 60)
		await _snap("07_toit", 60)
		hero.move_input = Vector2.ZERO
		print("CLIMB_TEST y=%.2f" % hero.global_position.y)
	# double saut
	hero.global_position = spawn_point + Vector3(0, 0.3, 0)
	await _snap("08_x", 15)
	hero.jump()
	await _snap("08_saut", 10)
	hero.cd["jump"] = 0.0
	hero.jump()
	await _snap("09_double_saut_salto", 8)
	# combat : Pas de l'ombre en chaîne
	_put_hero_near(2, 6.0)
	await _snap("10_combat", 50)
	hero.mp = 100
	hero.shadow_step()
	await _snap("11_pas_ombre_1", 8)
	await _snap("12_pas_ombre_2", 18)
	_kill_near(hero.global_position, 15.0)
	await _snap("13_cadavres", 50)
	hero.cd["arise"] = 0.0
	hero.mp = 100
	hero.arise()
	await _snap("14_arise_masse", 30)
	await _snap("15_ombres_levees", 80)
	# les ombres suivent derrière
	hero.move_input = Vector2(0, -0.7)
	await _snap("16_ombres_suivent", 90)
	hero.move_input = Vector2.ZERO
	await _snap("17_ombres_arret", 60)
	# panneaux
	_toggle_menu("ombres")
	await _snap("18_panneau_ombres", 10)
	hero.points = 3
	_toggle_menu("stats")
	await _snap("19_panneau_stats", 10)
	menu_panel.visible = false
	# combat des ombres + célébration
	_put_hero_near(3, 9.0)
	for m in shadow_list():
		(m as Mob).global_position = hero.global_position + Vector3(randf_range(-2, 2), 0.3, randf_range(-2, 2))
	await _snap("20_ombres_combat", 70)
	for m in mobs:
		var mm := m as Mob
		if mm.team == 1 and not mm.dead and mm.global_position.distance_to(hero.global_position) < 25.0:
			mm.hp = 1.0
	await _snap("21_ombres_finissent", 60)
	await _snap("22_celebration", 50)
	print("SHOTS_DONE niveau=%d ombres=%d" % [hero.level, shadow_count()])
	get_tree().quit()
