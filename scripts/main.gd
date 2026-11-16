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
var dlg_choices: HFlowContainer
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
# inventaire
const CD_TEX := preload("res://assets/ui/cd.png")
var potion_lbl: Label
var city_extras: Array = []
var dlg_scroll: ScrollContainer
var quick_menu: VBoxContainer
var inv: Array = []
var last_idle_line := ""
var squads: Array = []
var squad_t := 0.0
var equip := {"w": -1, "r": [], "tete": -1, "cape": -1, "plastron": -1, "bottes": -1}
var next_uid := 1
var loots: Array = []
var inv_filter := "w"
var inv_sel := -1
const INV_MAX := 40
const DROP_W := {"normal": [70, 25, 5, 0, 0, 0, 0], "elite": [8, 32, 35, 18, 6, 1, 0], "boss": [0, 0, 8, 28, 36, 22, 6]}
var speech_cd := 0.0
# audio, carte, économie, quête, sauvegarde
var audio: GameAudio
var minimap: Minimap
var merchant: Mob
var potions := 2
var mana_potions := 1
var potion_cd := 0.0
var shadow_lvl := 0
var hunter_rank := "E"
var quest := {}
var last_pos := Vector3.ZERO
var save_t := 30.0
var combat_t := 0.0
var rank_lbl: Label
var potion_btn: Button
const SAVE_PATH := "user://chasseur.json"
const RANKS := [["E", 1, -999], ["D", 5, 40], ["C", 10, 100], ["B", 18, 200], ["A", 28, 350], ["S", 40, 600]]
var info_box: VBoxContainer

func _ready() -> void:
	shots_mode = OS.get_cmdline_user_args().has("--shots")
	audio = GameAudio.new()
	add_child(audio)
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
	_make_patrols()
	for k in 2:
		_spawn_squad(k)
	await _build_dungeon()
	_build_hall()
	_spawn_gate(true)
	_spawn_merchant()
	if shots_mode:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	load_game()
	if inv.is_empty():
		var it := {"uid": next_uid, "t": "w", "id": "w1"}
		next_uid += 1
		inv.append(it)
		equip["w"] = int(it["uid"])
	recalc_gear()
	await _prewarm()
	last_pos = hero.global_position
	audio.music("city")
	system_msg("[ SYSTÈME ]\nUn Portail de rang C est apparu en ville.\nL'Association des Chasseurs le garde.")
	_check_daily()
	if shots_mode:
		_run_shots()

## Pré-compilation des shaders : chaque effet est joué une fois sous un écran de chargement.
## Sans ça, le rendu mobile compile au premier usage → gros à-coups en plein combat.
func _prewarm() -> void:
	fade.modulate.a = 1.0
	var title := Label.new()
	title.text = "A R I S E"
	title.add_theme_font_size_override("font_size", 64)
	title.add_theme_color_override("font_color", Color(0.7, 0.55, 1.0))
	title.set_anchors_preset(Control.PRESET_CENTER)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.position -= Vector2(150, 40)
	fade.add_child(title)
	var p := hero.global_position + hero.forward() * 4.0 + Vector3(0, 1.0, 0)
	var holder := Node3D.new()
	add_child(holder)
	holder.global_position = p
	FX.burst(self, p, Color(1, 0.4, 0.2))
	FX.slash_arc(self, p, 0.0, Color(0.4, 0.7, 1.0), 1.6, false)
	FX.telegraph(self, p, 1.5, 0.3)
	FX.telegraph_line(self, p, p + Vector3(3, 0, 0), 1.0, 0.3)
	FX.damage_number(self, p, "0", Color(1, 1, 1), true)
	FX.arise_pillar(self, p)
	FX.shadow_puff(self, p)
	FX.trail(self, p, p + Vector3(0, 0, 2), Color(0.6, 0.3, 1))
	var o := FX.orb(self, p, Color(1, 0.5, 0.1))
	FX.fireball(self, p, p + Vector3(1, 0, 0), Callable(), 0.05)
	FX.heal_zone(self, p, 2.0, 0.3)
	FX.taunt_aura(holder, 2.0, 0.3)
	FX.speech(holder, ".", Color(1, 1, 1), 1.0, 0.3)
	for w in ["katana", "lame", "hache", "dague", "chest_gold", "goblin", "orc"]:
		var n := (load("res://assets/%s.glb" % w) as PackedScene).instantiate() as Node3D
		holder.add_child(n)
		n.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	for k in 6:
		await RenderingServer.frame_post_draw
	o.queue_free()
	holder.queue_free()
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 0.5)
	tw.tween_callback(title.queue_free)

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
	moon_l.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	moon_l.directional_shadow_max_distance = 38.0
	moon_l.directional_shadow_fade_start = 0.75
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
## Listes d'équipes mises en cache une fois par image physique (évite des milliers d'allocations).
var _team_cache: Array = [[], [], []]
var _team_frame := -1
func units_of_team(t: int) -> Array:
	var f := Engine.get_physics_frames()
	if f != _team_frame:
		_team_frame = f
		_team_cache = [[], [], []]
		if hero:
			_team_cache[hero.team].append(hero)
		for m in mobs:
			if is_instance_valid(m):
				var tm: int = (m as Mob).team
				if tm >= 0 and tm <= 2:
					_team_cache[tm].append(m)
	if t < 0 or t > 2:
		return []
	return _team_cache[t]

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
	for r: float in [22.0, 32.0, 43.0, 55.0, 68.0, 82.0, 96.0, 112.0]:
		for k in 24:
			var a := k * TAU / 24.0 + r * 0.37
			var p := origin + Vector3(sin(a) * r, 0, cos(a) * r)
			if not _is_open(space, p + Vector3(0, 80, 0)):
				continue
			var ok := true
			for s in spots:
				if (s as Vector3).distance_to(p) < 20.0:
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
		var rr := randf_range(3.2, 4.6)
		spawn_mob(kinds[i], (camp["pos"] as Vector3) + Vector3(sin(a + randf_range(-0.3, 0.3)), 0, cos(a + randf_range(-0.3, 0.3))) * rr, camp)

# ---------------------------------------------------------------- patrouilles de monstres et groupes de chasseurs
func _route(k: int) -> Array:
	var pts: Array = []
	var n := camps.size()
	if n < 3:
		return pts
	for j in 4:
		var c: Vector3 = camps[(k * 3 + j * 2) % n]["pos"]
		pts.append(c + Vector3(6, 0, 4).rotated(Vector3.UP, j * 1.7))
	return pts

func _make_patrols() -> void:
	for k in 2:
		var route := _route(k + 5)
		if route.is_empty():
			return
		var kinds := ["goblin", "goblin", "orc"] if k == 0 else ["goblin", "shaman", "goblin"]
		for i in kinds.size():
			var m := spawn_free_mob(kinds[i], (route[0] as Vector3) + Vector3(i * 1.4, 0, 0))
			m.patrol = route
			m.patrol_off = Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.5
	print("PATROLS 2")

func _spawn_squad(k: int, at = null) -> Dictionary:
	var route := _route(k + 1)
	if route.is_empty():
		return {}
	var sq := {"members": [], "cd": 0.0, "last": "", "dead_t": 0.0, "k": k}
	var start: Vector3 = (route[0] as Vector3).lerp(route[1] as Vector3, 0.5) if at == null else at
	for i in 3:
		var m := spawn_free_mob("hunter", start + Vector3(i * 1.3, 0, 0))
		m.squad = sq
		m.patrol = route
		m.patrol_off = Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.6
		sq["members"].append(m)
		if m.hp_bar:
			for c in m.hp_bar.get_children():
				if c is Label3D:
					(c as Label3D).visible = i == 0
					if i == 0:
						(c as Label3D).text = "Escouade de chasseurs [D]"
	squads.append(sq)
	print("SQUAD ", k)
	return sq

func _update_squads(delta: float) -> void:
	squad_t -= delta
	if squad_t > 0.0:
		return
	squad_t = 2.0
	for i in range(squads.size() - 1, -1, -1):
		var sq: Dictionary = squads[i]
		var alive := 0
		for m in sq["members"]:
			if is_instance_valid(m) and not (m as Mob).dead:
				alive += 1
		if alive == 0:
			sq["dead_t"] = float(sq["dead_t"]) + 2.0
			if float(sq["dead_t"]) > 120.0:
				squads.remove_at(i)
				_spawn_squad(int(sq["k"]))

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
		var lt := FX.new_light()
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
	drop_loot((c["chest"] as Node3D).global_position + Vector3(1.2, 0, 0), "elite")
	var g := randi_range(180, 320)
	gold += g
	essence += 2
	rep += 8
	c["state"] = "cooldown"
	c["timer"] = 300.0
	var ch: Node3D = c["chest"]
	sfx("chest", ch.global_position)
	sfx("coins", ch.global_position)
	save_game()
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
	if m.kind == "hunter":
		var tw := m.create_tween()
		tw.tween_interval(20.0)
		tw.tween_property(m, "scale", Vector3(1, 0.01, 1), 0.8)
		tw.tween_callback(_remove_mob.bind(m))
		return
	if m.kind == "guard":
		rep = maxi(rep - 6, -50)
		_check_guards()
		return
	if m.boss:
		_on_boss_dead(m)
		return
	gold += int(m.reward_gold * (1.0 + hero.g("gold") / 100.0))
	quest_add("kills", 1)
	sfx("coins", m.global_position, -8.0)
	rep += 3 if m.elite else 1
	var xpv := {"goblin": 12.0, "shaman": 15.0, "orc": 35.0, "igris": 600.0}.get(m.kind, 10.0) as float
	hero.gain_xp(xpv * (3.0 if m.elite else 1.0))
	if randf() < (0.5 if m.elite else 0.12):
		essence += 1
	var luck := hero.g("luck")
	if randf() * 100.0 < (35.0 if m.elite else 7.0) + luck * 0.3:
		drop_loot(m.global_position, "elite" if m.elite else "normal")
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
		var lt := FX.new_light(true)
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
	if shop:
		shop.visible = z == "shop"
	for ce in city_extras:
		if is_instance_valid(ce):
			(ce as Node3D).visible = z == "city"
	if gate:
		gate.visible = z == "city"
	world_env.environment = env_city if z == "city" else (env_dun if z == "dungeon" else (env_shop if z == "shop" else env_hall))
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
	sfx("portal", null, 0.0)
	sfx("shadow")
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
	var lt := FX.new_light(true)
	lt.light_color = Color(1, 0.8, 0.3)
	lt.light_energy = 2.5
	lt.omni_range = 7.0
	lt.position.y = 2.0
	boss_chest.add_child(lt)
	exit_pos = _hall_floor(-14.0, 0.0)
	exit_portal = FX.portal(self, exit_pos, Color(0.25, 0.55, 1.0), 1.8)

func _open_boss_chest() -> void:
	boss_reward_taken = true
	drop_loot(boss_chest.global_position + Vector3(-1.5, 0, 0), "boss")
	drop_loot(boss_chest.global_position + Vector3(1.5, 0, 1.0), "boss")
	gold += 1500
	essence += 10
	hero.equip_blade()
	sfx("chest")
	sfx("victory")
	save_game()
	FX.burst(self, boss_chest.global_position + Vector3(0, 1.4, 0), Color(1, 0.8, 0.2), 90, 0.14, 6.0, 1.2, 6.0)
	system_msg("[ SYSTÈME ]\nTu obtiens : LAME DU COMMANDANT (+45 % dégâts)\n1500 or, 10 essences.")

func _leave_dungeon() -> void:
	await _teleport(gate_pos + Vector3(0, 0, 5), "city")
	_spawn_gate(false)

# ================================================================ dialogue
func dialogue(speaker: String, text: String, choices: Array) -> void:
	if not in_dialogue:
		sfx("open", null, -6.0)
	in_dialogue = true
	hero.move_input = Vector2.ZERO
	dlg_panel.visible = true
	dlg_name.text = speaker
	dlg_text.text = text
	var lines := 0
	for ln in text.split("\n"):
		lines += 1 + int(ln.length() / 78)
	dlg_scroll.custom_minimum_size = Vector2(890, minf(lines * 29.0 + 6.0, 300.0))
	dlg_scroll.scroll_vertical = 0
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
		b.pressed.connect(sfx.bind("click", null, -6.0))
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

func slow_mo(sc: float, dur: float) -> void:
	Engine.time_scale = sc
	await get_tree().create_timer(dur, true, false, true).timeout
	Engine.time_scale = 1.0

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
	potion_cd -= delta
	speech_cd -= delta
	_update_loot(delta)
	_update_squads(delta)
	msg_panel.visible = not (menu_panel and menu_panel.visible)
	var mv := hero.global_position - last_pos
	mv.y = 0
	if mv.length() < 5.0 and hero.is_on_floor():
		quest_add("run", mv.length())
	last_pos = hero.global_position
	save_t -= delta
	if save_t <= 0.0:
		save_t = 30.0
		save_game()
	_update_music(delta)
	_check_rank()
	if focus_target and is_instance_valid(focus_target) and not focus_target.dead:
		focus_marker.visible = true
		focus_marker.global_position = focus_target.global_position + Vector3(0, 3.0 if (focus_target as Mob).kind == "orc" else 2.55, 0) + Vector3(0, sin(Time.get_ticks_msec() * 0.006) * 0.12, 0)
		focus_marker.rotation.y += delta * 3.0
	else:
		focus_marker.visible = false
		focus_target = null
	if menu_panel.visible:
		menu_refresh -= delta
		if menu_refresh <= 0.0 and menu_tab != "sac":
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
			if hero.global_position.distance_to(shop_door_pos) < 3.0:
				label = "ENTRER — BOUTIQUE"
				act = enter_shop
			if gate and hero.global_position.distance_to(gate_pos) < 4.0:
				if gate_open_for_me:
					label = "ENTRER DANS LE PORTAIL"
					act = enter_dungeon
				elif not guards_hostile and _nearest_guard() != null:
					label = "PARLER AU GARDE"
					act = _guard_dialogue
		elif zone == "shop":
			if merchant and hero.global_position.distance_to(merchant.global_position) < 3.4:
				label = "PARLER À L'INTENDANT"
				act = _merchant_dialogue
			elif hero.global_position.distance_to(shop_exit) < 2.4:
				label = "SORTIR"
				act = leave_shop
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

## Bouton rond à miniature : icône, balayage de recharge circulaire, nom discret dessous.
func _skill_button(layer: CanvasLayer, key: String, txt: String, center: Vector2, size: float, cb: Callable) -> void:
	var b := Button.new()
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus", "disabled"]:
		b.add_theme_stylebox_override(st, empty)
	b.anchor_left = 1.0
	b.anchor_top = 1.0
	b.anchor_right = 1.0
	b.anchor_bottom = 1.0
	b.offset_left = center.x - size * 0.5
	b.offset_top = center.y - size * 0.5
	b.offset_right = center.x + size * 0.5
	b.offset_bottom = center.y + size * 0.5
	b.pivot_offset = Vector2(size, size) * 0.5
	b.focus_mode = Control.FOCUS_NONE
	b.button_down.connect(cb)
	b.button_down.connect(_press_anim.bind(b))
	layer.add_child(b)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/%s.png" % key)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	var shade := TextureProgressBar.new()
	shade.texture_progress = CD_TEX
	shade.fill_mode = TextureProgressBar.FILL_CLOCKWISE
	shade.nine_patch_stretch = true
	shade.set_anchors_preset(Control.PRESET_FULL_RECT)
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	shade.max_value = 1.0
	shade.step = 0.0
	b.add_child(shade)
	var cdl := Label.new()
	cdl.set_anchors_preset(Control.PRESET_FULL_RECT)
	cdl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	cdl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	cdl.add_theme_font_size_override("font_size", int(size * 0.34))
	cdl.add_theme_constant_override("outline_size", 8)
	cdl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	cdl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(cdl)
	if txt != "":
		var nl := Label.new()
		nl.text = txt
		nl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		nl.add_theme_font_size_override("font_size", 13)
		nl.add_theme_constant_override("outline_size", 5)
		nl.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
		nl.add_theme_color_override("font_color", Color(0.85, 0.88, 1, 0.9))
		nl.position = Vector2(-30, size - 6)
		nl.size = Vector2(size + 60, 18)
		nl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		b.add_child(nl)
	buttons[key] = {"btn": b, "shade": shade if Hero.CD_MAX.has(key) else null, "label": cdl}
	if not Hero.CD_MAX.has(key):
		shade.visible = false

func _press_anim(b: Control) -> void:
	var tw := b.create_tween()
	tw.tween_property(b, "scale", Vector2(0.88, 0.88), 0.05)
	tw.tween_property(b, "scale", Vector2.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _roll_btn() -> void:
	hero.roll()

func _toggle_sprint() -> void:
	hero.sprint_lock = not hero.sprint_lock
	(buttons["sprint"]["btn"] as Control).modulate = Color(1.35, 1.25, 0.8) if hero.sprint_lock else Color(1, 1, 1)

# ================================================================ inventaire
func item_by_uid(uid: int) -> Dictionary:
	for it in inv:
		if int(it["uid"]) == uid:
			return it
	return {}

func is_equipped(uid: int) -> bool:
	return equip["w"] == uid or (equip["r"] as Array).has(uid) or equip["tete"] == uid or equip["cape"] == uid or equip["plastron"] == uid or equip["bottes"] == uid

func relic_slots() -> int:
	return 4 if hero.level >= 20 else 3

func add_item(it: Dictionary) -> void:
	if inv.size() >= INV_MAX:
		# sac plein : on démantèle automatiquement l'objet le plus faible non équipé
		var worst := -1
		for i in inv.size():
			if not is_equipped(int(inv[i]["uid"])) and (worst < 0 or Items.rarity(inv[i]) < Items.rarity(inv[worst])):
				worst = i
		if worst >= 0:
			essence += Items.dismantle_value(inv[worst])
			inv.remove_at(worst)
	inv.append(it)

func grant_item(t: String, id: String, auto_equip := false) -> void:
	var it := {"uid": next_uid, "t": t, "id": id}
	next_uid += 1
	add_item(it)
	if auto_equip:
		equip_item(int(it["uid"]))
	_loot_popup(it)

func drop_loot(pos: Vector3, src: String) -> void:
	var rk := Items.roll_rank(DROP_W[src], hero.g("luck"))
	var it := Items.roll_item(rk, next_uid)
	next_uid += 1
	var col := Items.color(it)
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos + Vector3(randf_range(-0.6, 0.6), 0.1, randf_range(-0.6, 0.6))
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.02
	cm.bottom_radius = 0.16
	cm.height = 3.0 + rk * 0.8
	beam.mesh = cm
	beam.material_override = FX.mat(col, 2.5, 0.45)
	beam.position.y = cm.height * 0.5
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	root.add_child(beam)
	var gem := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.28, 0.28, 0.28)
	gem.mesh = bm
	gem.material_override = FX.mat(col, 3.0)
	gem.position.y = 0.7
	gem.rotation_degrees = Vector3(45, 0, 45)
	root.add_child(gem)
	var tw := gem.create_tween().set_loops()
	tw.tween_property(gem, "rotation_degrees:y", 360.0, 2.0).from(0.0)
	var lt := FX.new_light()
	lt.light_color = col
	lt.light_energy = 1.5
	lt.omni_range = 3.5
	lt.position.y = 0.8
	root.add_child(lt)
	var lb := Label3D.new()
	lb.text = "[%s] %s" % [Items.RAR[rk]["k"], Items.base_of(it)["n"]]
	lb.font_size = 30
	lb.pixel_size = 0.0008
	lb.fixed_size = true
	lb.outline_size = 8
	lb.modulate = col
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 1.3
	lb.visibility_range_end = 25.0
	root.add_child(lb)
	loots.append({"node": root, "item": it, "t": 90.0})
	if rk >= 3:
		sfx("levelup", pos, -6.0)
	print("LOOT [%s] %s" % [Items.RAR[rk]["k"], Items.base_of(it)["n"]])

func _update_loot(delta: float) -> void:
	for i in range(loots.size() - 1, -1, -1):
		var l: Dictionary = loots[i]
		var n: Node3D = l["node"]
		l["t"] = float(l["t"]) - delta
		if float(l["t"]) <= 0.0:
			n.queue_free()
			loots.remove_at(i)
			continue
		if not hero.dead and n.global_position.distance_to(hero.global_position) < 2.0:
			add_item(l["item"])
			_loot_popup(l["item"])
			FX.burst(self, n.global_position + Vector3(0, 0.7, 0), Items.color(l["item"]), 20, 0.07, 2.5, 0.5, 0.0)
			sfx("coins", n.global_position, -6.0)
			n.queue_free()
			loots.remove_at(i)

func _loot_popup(it: Dictionary) -> void:
	var rk := Items.rarity(it)
	FX.damage_number(self, hero.global_position + Vector3(0, 0.5, 0), "[%s] %s" % [Items.RAR[rk]["k"], Items.base_of(it)["n"]], Items.color(it), rk >= 3)

func equip_item(uid: int) -> void:
	var it := item_by_uid(uid)
	if it.is_empty():
		return
	match str(it["t"]):
		"w":
			equip["w"] = uid
		"r":
			var r: Array = equip["r"]
			if r.has(uid):
				return
			if r.size() >= relic_slots():
				r.remove_at(0)
			r.append(uid)
		"a":
			equip[str(Items.base_of(it)["slot"])] = uid
	sfx("draw" if it["t"] == "w" else "cloth")
	recalc_gear()

func unequip_item(uid: int) -> void:
	if equip["w"] == uid:
		equip["w"] = -1
	(equip["r"] as Array).erase(uid)
	for s in ["tete", "cape", "plastron", "bottes"]:
		if equip[s] == uid:
			equip[s] = -1
	recalc_gear()

func remove_item(uid: int, sell: bool) -> void:
	var it := item_by_uid(uid)
	if it.is_empty():
		return
	unequip_item(uid)
	if sell:
		gold += Items.sell_price(it)
		sfx("coins")
	else:
		essence += Items.dismantle_value(it)
		sfx("shadow", null, -6.0)
	inv.erase(it)

func recalc_gear() -> void:
	var tot := {}
	var ids: Array = [equip["w"], equip["tete"], equip["cape"], equip["plastron"], equip["bottes"]]
	ids.append_array(equip["r"])
	var w: Dictionary = {}
	for uid in ids:
		if int(uid) < 0:
			continue
		var it := item_by_uid(int(uid))
		if it.is_empty():
			continue
		var st := Items.stats(it)
		for k in st.keys():
			tot[k] = float(tot.get(k, 0.0)) + float(st[k])
		if it["t"] == "w":
			w = Items.base_of(it)
	if w.is_empty():
		w = Items.WEAPONS[0]
	hero.gear = tot
	hero.apply_gear(w)

# ================================================================ audio
func sfx(n: String, pos = null, vol := 0.0) -> void:
	if audio:
		audio.play(n, pos, vol)

func _update_music(delta: float) -> void:
	var fighting := false
	for u in units_of_team(1):
		var e := u as Mob
		if not e.dead and e.target != null and is_instance_valid(e.target) and e.global_position.distance_to(hero.global_position) < 25.0:
			fighting = true
			break
	combat_t = 6.0 if fighting else combat_t - delta
	var tr := "city"
	if zone == "hall":
		tr = "boss" if boss_started and boss and is_instance_valid(boss) and not boss.dead else "dungeon"
	elif zone == "dungeon":
		tr = "combat" if combat_t > 0.0 else "dungeon"
	elif combat_t > 0.0:
		tr = "combat"
	audio.music(tr)

# ================================================================ marchand
# ================================================================ boutique : porte en ville + intérieur (entrepôt)
const SHOP_O := Vector3(-3000, 0, 600)
var shop: Node3D
var shop_door_pos := Vector3.INF
var shop_door_dir := Vector3.FORWARD
var shop_entry := Vector3.ZERO
var shop_exit := Vector3.ZERO
var env_shop: Environment

func _spawn_merchant() -> void:
	_place_shop_door()
	_build_shop()

## Porte de boutique plaquée contre un bâtiment proche du point d'apparition.
func _place_shop_door() -> void:
	var space := get_world_3d().direct_space_state
	var best := Vector3.INF
	var bdir := Vector3.FORWARD
	for r: float in [9.0, 12.0, 15.0, 19.0, 24.0]:
		for k in 16:
			var a := k * TAU / 16.0
			var c := spawn_point + Vector3(sin(a), 0, cos(a)) * r
			if not _is_open(space, c + Vector3(0, 80, 0)):
				continue
			var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(c + Vector3(0, 30, 0), c + Vector3(0, -30, 0)))
			if g.is_empty():
				continue
			var fp: Vector3 = g["position"]
			for d in 8:
				var dv := Vector3(sin(d * TAU / 8.0), 0, cos(d * TAU / 8.0))
				var w := space.intersect_ray(PhysicsRayQueryParameters3D.create(fp + Vector3(0, 1.2, 0), fp + Vector3(0, 1.2, 0) + dv * 4.0))
				if w.is_empty():
					continue
				var n: Vector3 = w["normal"]
				if absf(n.y) > 0.3:
					continue
				var up := space.intersect_ray(PhysicsRayQueryParameters3D.create(fp + Vector3(0, 3.2, 0), fp + Vector3(0, 3.2, 0) + dv * 4.0))
				if up.is_empty():
					continue
				best = (w["position"] as Vector3) + n * 0.12
				best.y = fp.y
				bdir = Vector3(n.x, 0, n.z).normalized()
				break
			if best != Vector3.INF:
				break
		if best != Vector3.INF:
			break
	if best == Vector3.INF:
		best = spawn_point + Vector3(6, 0, 0)
		bdir = Vector3(-1, 0, 0)
	shop_door_pos = best
	shop_door_dir = bdir
	var door := Node3D.new()
	add_child(door)
	door.global_position = best
	door.look_at(best - bdir, Vector3.UP)
	city_extras.append(door)
	var frame_m := FX.mat(Color(0.12, 0.1, 0.16), 0.0, 1.0, false)
	var trim_m := FX.mat(Color(1.0, 0.72, 0.3), 2.2)
	for part in [[Vector3(-1.05, 1.45, 0.05), Vector3(0.22, 2.9, 0.3)], [Vector3(1.05, 1.45, 0.05), Vector3(0.22, 2.9, 0.3)], [Vector3(0, 2.95, 0.05), Vector3(2.32, 0.24, 0.32)]]:
		var bx := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		bx.mesh = bm
		bx.material_override = frame_m
		bx.position = part[0]
		door.add_child(bx)
		var tr := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = (part[1] as Vector3) + Vector3(0.04, 0.04, -0.26)
		tr.mesh = tm
		tr.material_override = trim_m
		tr.position = (part[0] as Vector3) + Vector3(0, 0, 0.17)
		door.add_child(tr)
	var panel := MeshInstance3D.new()
	var pq := QuadMesh.new()
	pq.size = Vector2(1.9, 2.8)
	panel.mesh = pq
	var pmat := FX.mat(Color(1.0, 0.62, 0.25), 1.6, 0.9)
	pmat.albedo_texture = FX._soft_tex()
	panel.material_override = pmat
	panel.position = Vector3(0, 1.4, 0.02)
	door.add_child(panel)
	var sign := Label3D.new()
	sign.text = "BOUTIQUE DE L'ASSOCIATION"
	sign.font_size = 64
	sign.pixel_size = 0.006
	sign.outline_size = 14
	sign.modulate = Color(1, 0.85, 0.45)
	sign.position = Vector3(0, 3.55, 0.12)
	door.add_child(sign)
	var sub := Label3D.new()
	sub.text = "▼  ENTRER  ▼"
	sub.font_size = 44
	sub.pixel_size = 0.005
	sub.outline_size = 10
	sub.modulate = Color(0.75, 1, 0.8)
	sub.position = Vector3(0, 3.12, 0.12)
	door.add_child(sub)
	var tw := sub.create_tween().set_loops()
	tw.tween_property(sub, "modulate:a", 0.35, 0.8)
	tw.tween_property(sub, "modulate:a", 1.0, 0.8)
	var mark := FX.ground_disc(1.3, Color(1, 0.75, 0.3), 0.6, true)
	add_child(mark)
	mark.global_position = best + bdir * 1.3 + Vector3(0, 0.05, 0)
	city_extras.append(mark)
	print("SHOP_DOOR ", best.round(), " dir ", bdir.round())

func _build_shop() -> void:
	shop = (load("res://assets/warehouse.glb") as PackedScene).instantiate()
	add_child(shop)
	shop.position = SHOP_O
	for mi in shop.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = m.mesh.create_trimesh_shape()
		body.add_child(cs)
		m.add_child(body)
	# sol de sécurité + sol visible (béton sombre)
	var fl := StaticBody3D.new()
	var fcs := CollisionShape3D.new()
	var fb := BoxShape3D.new()
	fb.size = Vector3(36, 1, 16)
	fcs.shape = fb
	fl.add_child(fcs)
	fl.position = SHOP_O + Vector3(2.5, -3.45, -6.2)
	add_child(fl)
	shop_floor_mesh(fl)
	var space := get_world_3d().direct_space_state
	var ctr := SHOP_O + Vector3(2.5, 1.0, -6.2)
	await get_tree().physics_frame
	var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(ctr, ctr + Vector3(0, -8, 0)))
	var fy: float = (hit["position"] as Vector3).y if not hit.is_empty() else SHOP_O.y - 2.95
	shop_entry = Vector3(SHOP_O.x - 5.0, fy, SHOP_O.z - 6.2)
	shop_exit = shop_entry + Vector3(-1.6, 0, 0)
	var desk := Vector3(SHOP_O.x + 8.0, fy, SHOP_O.z - 6.2)
	# comptoir + présentoirs lumineux
	var counter := MeshInstance3D.new()
	var cbm := BoxMesh.new()
	cbm.size = Vector3(0.9, 1.05, 3.4)
	counter.mesh = cbm
	counter.material_override = FX.mat(Color(0.22, 0.14, 0.08), 0.0, 1.0, false)
	shop.add_child(counter)
	counter.global_position = desk + Vector3(-1.3, 0.52, 0)
	for k in 5:
		var bt := MeshInstance3D.new()
		var cy := CylinderMesh.new()
		cy.top_radius = 0.05
		cy.bottom_radius = 0.09
		cy.height = 0.28
		bt.mesh = cy
		bt.material_override = FX.mat([Color(1, 0.2, 0.3), Color(0.3, 0.6, 1), Color(0.6, 0.3, 1), Color(1, 0.8, 0.3), Color(0.3, 1, 0.5)][k], 2.5)
		shop.add_child(bt)
		bt.global_position = desk + Vector3(-1.3, 1.2, -1.2 + k * 0.6)
	for lp: Vector3 in [Vector3(-2, 2.4, -6), Vector3(8, 2.4, -6)]:
		var lt := FX.new_light(true)
		lt.light_color = Color(1, 0.78, 0.5)
		lt.light_energy = 2.2
		lt.omni_range = 11.0
		shop.add_child(lt)
		lt.global_position = Vector3(SHOP_O.x + lp.x, fy + lp.y, SHOP_O.z + lp.z)
	merchant = spawn_free_mob("hunter", desk + Vector3(0.6, 0, 0))
	merchant.display_name = "Intendant de l'Association"
	merchant.rank = "PNJ"
	merchant.patrol = []
	merchant.team = 2
	for att in merchant.find_children("*", "BoneAttachment3D", true, false):
		att.queue_free()
	if merchant.hp_bar:
		merchant.hp_bar.queue_free()
		merchant.hp_bar = null
		merchant.hp_fill = null
	var lb := Label3D.new()
	lb.text = "Intendant — Boutique"
	lb.font_size = 34
	lb.pixel_size = 0.0009
	lb.fixed_size = true
	lb.outline_size = 8
	lb.modulate = Color(0.5, 1.0, 0.6)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 2.2
	merchant.add_child(lb)
	merchant.face_to(shop_entry, true)
	# sortie : porte lumineuse côté entrée
	var ex := FX.ground_disc(1.2, Color(0.4, 0.8, 1.0), 0.6, true)
	shop.add_child(ex)
	ex.global_position = shop_exit + Vector3(0, 0.05, 0)
	var exl := Label3D.new()
	exl.text = "SORTIE"
	exl.font_size = 40
	exl.pixel_size = 0.0045
	exl.outline_size = 10
	exl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	exl.modulate = Color(0.6, 0.85, 1)
	shop.add_child(exl)
	exl.global_position = shop_exit + Vector3(0, 2.2, 0)
	env_shop = env_city.duplicate() as Environment
	env_shop.fog_enabled = false
	env_shop.ambient_light_color = Color(0.75, 0.65, 0.55)
	env_shop.ambient_light_energy = 0.8
	shop.visible = false
	print("SHOP_BUILT floor=%.2f" % fy)

func shop_floor_mesh(fl: Node3D) -> void:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(36, 16)
	mi.mesh = pm
	mi.material_override = FX.mat(Color(0.2, 0.19, 0.21), 0.0, 1.0, false)
	mi.position.y = 0.5
	fl.add_child(mi)

func enter_shop() -> void:
	sfx("open")
	await _teleport(shop_entry, "shop")
	var d := merchant.global_position - shop_entry
	yaw = atan2(-d.x, -d.z)
	system_msg("Boutique de l'Association des Chasseurs")

func leave_shop() -> void:
	sfx("open")
	await _teleport(shop_door_pos + shop_door_dir * 2.2, "city")
	yaw = atan2(-shop_door_dir.x, -shop_door_dir.z)

func _merchant_dialogue() -> void:
	merchant.face_to(hero.global_position, true)
	var txt := "Bonsoir, chasseur. Tout ce qu'il faut pour survivre aux Portails.\nTu as %d or et %d essences. Potions : %d.  Niveau de tes ombres : %d." % [gold, essence, potions, shadow_lvl]
	dialogue("Marchand de l'Association", txt, [
		["Potion de soin — 50 or", _buy.bind("potion")],
		["Renforcer mes ombres (+12 %% PV et dégâts) — %d essences" % (4 + shadow_lvl * 2), _buy.bind("shadow")],
		["Affûter ma lame (+10 %% dégâts) — %d or" % (300 + int((hero.blade_mult - 1.0) * 2000)), _buy.bind("blade")],
		["« Rien, merci. »", close_dialogue],
	])

func _buy(what: String) -> void:
	match what:
		"potion":
			if gold >= 50:
				gold -= 50
				potions += 1
				sfx("coins")
			else:
				sfx("error")
		"shadow":
			var cost := 4 + shadow_lvl * 2
			if essence >= cost:
				essence -= cost
				shadow_lvl += 1
				for m in shadow_list():
					var mm := m as Mob
					mm.max_hp *= 1.12
					mm.hp = mm.max_hp
					mm.dmg *= 1.12
					FX.burst(self, mm.global_position + Vector3(0, 1.2, 0), Color(0.6, 0.3, 1.0), 20, 0.08, 2.0, 0.5, 0.0)
				sfx("levelup")
			else:
				sfx("error")
		"blade":
			var cost := 300 + int((hero.blade_mult - 1.0) * 2000)
			if gold >= cost and hero.blade_mult < 2.2:
				gold -= cost
				hero.blade_mult += 0.1
				sfx("clang_heavy")
			else:
				sfx("error")
	save_game()
	_merchant_dialogue()

func _use_potion() -> void:
	if potions <= 0 or potion_cd > 0.0 or hero.dead:
		return
	potions -= 1
	potion_cd = 8.0
	hero.hp = minf(hero.max_hp, hero.hp + hero.max_hp * 0.45)
	sfx("confirm")
	FX.burst(self, hero.global_position + Vector3(0, 1.0, 0), Color(0.4, 1.0, 0.5), 30, 0.08, 2.0, 0.7, -1.5)
	FX.damage_number(self, hero.global_position, "+%d" % int(hero.max_hp * 0.45), Color(0.4, 1.0, 0.5))

# ================================================================ quête quotidienne + rang
const QUEST_GOALS := {"run": [3000.0, "Courir", "m"], "kills": [30.0, "Vaincre des monstres", ""], "climb": [5.0, "Escalader des bâtiments", ""], "skills": [10.0, "Utiliser tes compétences", ""]}

func _today() -> String:
	var d := Time.get_date_dict_from_system()
	return "%04d-%02d-%02d" % [d["year"], d["month"], d["day"]]

func _check_daily() -> void:
	if quest.get("date", "") != _today():
		quest = {"date": _today(), "run": 0.0, "kills": 0.0, "climb": 0.0, "skills": 0.0, "done": false}
		if not shots_mode:
			await get_tree().create_timer(4.5).timeout
		_show_quest()

func quest_add(k: String, v: float) -> void:
	if quest.is_empty() or quest.get("done", false):
		return
	quest[k] = float(quest.get(k, 0.0)) + v
	for g in QUEST_GOALS.keys():
		if float(quest.get(g, 0.0)) < float(QUEST_GOALS[g][0]):
			return
	quest["done"] = true
	hero.points += 3
	gold += 300
	hero.hp = hero.max_hp
	hero.mp = hero.max_mp
	sfx("victory")
	sfx("levelup")
	system_msg("[ SYSTÈME ]\nQuête quotidienne accomplie !\nRécompenses : +3 points de compétence, 300 or, récupération complète.")
	save_game()

func _quest_text() -> String:
	var t := "[ QUÊTE QUOTIDIENNE : l'entraînement pour devenir fort ]\n"
	for g in QUEST_GOALS.keys():
		var goal: Array = QUEST_GOALS[g]
		var v := minf(float(quest.get(g, 0.0)), float(goal[0]))
		t += "\n%s  %s : %d / %d %s" % ["[OK]" if v >= float(goal[0]) else "[  ]", goal[1], int(v), int(goal[0]), goal[2]]
	t += "\n\nRécompense : +3 points de compétence, 300 or, récupération complète."
	if quest.get("done", false):
		t += "\n\nQUÊTE ACCOMPLIE."
	else:
		t += "\nAttention : les quêtes du Système doivent être accomplies chaque jour."
	return t

func _show_quest() -> void:
	if in_dialogue:
		return
	dialogue("[ SYSTÈME ]", _quest_text(), [["Accepter", close_dialogue]])

func _check_rank() -> void:
	var best := "E"
	for r in RANKS:
		if hero.level >= int(r[1]) and rep >= int(r[2]):
			best = str(r[0])
	if best != hunter_rank and "EDCBAS".find(best) > "EDCBAS".find(hunter_rank):
		hunter_rank = best
		sfx("victory")
		FX.arise_pillar(self, hero.global_position)
		system_msg("[ SYSTÈME ]\nRéévaluation de l'Association des Chasseurs :\ntu es désormais Chasseur de RANG %s !" % best)
		print("RANK ", best)
		save_game()

# ================================================================ sauvegarde
func save_game() -> void:
	var sh: Array = []
	for m in shadow_list():
		var mm := m as Mob
		sh.append({"kind": mm.kind, "elite": mm.elite, "boss": mm.boss, "role": mm.role})
	var d := {"v": 1, "level": hero.level, "xp": hero.xp, "points": hero.points, "stats": hero.stats, "gold": gold, "essence": essence, "rep": rep,
		"blade": hero.blade_mult, "unarmed": hero.unarmed_mode, "potions": potions, "shadow_lvl": shadow_lvl, "rank": hunter_rank, "quest": quest, "shadows": sh,
		"base_hp": hero.base_hp, "base_mp": hero.base_mp, "powers": hero.powers, "inv": inv, "equip": equip, "next_uid": next_uid}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify(d))
		f.close()

func load_game() -> bool:
	if not FileAccess.file_exists(SAVE_PATH):
		return false
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		return false
	var d = JSON.parse_string(f.get_as_text())
	f.close()
	if typeof(d) != TYPE_DICTIONARY:
		return false
	hero.level = int(d.get("level", 1))
	hero.xp = float(d.get("xp", 0))
	hero.points = int(d.get("points", 0))
	var st: Dictionary = d.get("stats", {})
	for k in hero.stats.keys():
		hero.stats[k] = int(st.get(k, 0))
	hero.base_hp = float(d.get("base_hp", 420.0 + 40.0 * (hero.level - 1)))
	hero.base_mp = float(d.get("base_mp", 100.0 + 10.0 * (hero.level - 1)))
	inv = d.get("inv", [])
	for it in inv:
		it["uid"] = int(it["uid"])
	var eq: Dictionary = d.get("equip", {})
	for k in equip.keys():
		if eq.has(k):
			if k == "r":
				equip["r"] = []
				for u in eq["r"]:
					equip["r"].append(int(u))
			else:
				equip[k] = int(eq[k])
	next_uid = int(d.get("next_uid", 1))
	gold = int(d.get("gold", 0))
	essence = int(d.get("essence", 0))
	rep = int(d.get("rep", 0))
	potions = int(d.get("potions", 2))
	shadow_lvl = int(d.get("shadow_lvl", 0))
	hunter_rank = str(d.get("rank", "E"))
	var pw: Dictionary = d.get("powers", {})
	for k in hero.powers.keys():
		if pw.has(k):
			hero.powers[k] = int(pw[k])
	quest = d.get("quest", {})
	hero.blade_mult = minf(float(d.get("blade", 1.0)), 2.2)
	recalc_gear()
	hero.hp = hero.max_hp
	hero.mp = hero.max_mp
	if bool(d.get("unarmed", false)):
		hero.toggle_unarmed()
	(hero.domain_ring.mesh as PlaneMesh).size = Vector2(hero.domain_r() * 2.0, hero.domain_r() * 2.0)
	for sdat in d.get("shadows", []):
		var m := spawn_free_mob(str(sdat.get("kind", "goblin")), hero.global_position - hero.forward() * 2.0)
		if bool(sdat.get("elite", false)):
			m.make_elite()
		m.dead = true
		m.rise_as_shadow(str(sdat.get("role", "")))
	print("LOAD niveau=%d or=%d ombres=%d" % [hero.level, gold, shadow_count()])
	return true

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
	rank_lbl = nm
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
	minimap = Minimap.new()
	minimap.main = self
	minimap.position = Vector2(20, 160)
	minimap.size = Vector2(164, 164)
	minimap.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(minimap)
	# objectif courant (portail / meutes) : petit encart sous la minimap
	var obj := PanelContainer.new()
	obj.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.12, 0.62), Color(0.35, 0.55, 1.0, 0.6)))
	obj.position = Vector2(20, 334)
	obj.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(obj)
	gate_txt = Label.new()
	gate_txt.add_theme_font_size_override("font_size", 16)
	gate_txt.add_theme_color_override("font_color", Color(0.65, 0.85, 1))
	obj.add_child(gate_txt)
	# ressources : pastille discrète en haut à droite
	info_box = VBoxContainer.new()
	info_box.anchor_left = 1.0
	info_box.anchor_right = 1.0
	info_box.offset_left = -420
	info_box.offset_right = -112
	info_box.offset_top = 22
	info_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(info_box)
	res_txt = _outlined(info_box, Vector2(0, 0), 19, Color(1, 0.85, 0.45))
	res_txt.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# combat : grosse attaque + pouvoirs en arc (style action-RPG mobile)
	var C := Vector2(-140, -140)
	_skill_button(layer, "attack", "", C, 176, hero.attack)
	var arc := [["roll", "Esquive", 182.0, _roll_btn], ["step", "Pas de l'ombre", 148.0, _do_step], ["tele", "Télékinésie", 114.0, _do_tele], ["arise", "Arise", 80.0, _do_arise]]
	for it in arc:
		var ang := deg_to_rad(float(it[2]))
		_skill_button(layer, str(it[0]), str(it[1]), C + Vector2(cos(ang), -sin(ang)) * 212.0, 104, it[3])
	var ang2 := deg_to_rad(128.0)
	_skill_button(layer, "swap", "Échange", C + Vector2(cos(ang2), -sin(ang2)) * 338.0, 92, _do_swap)
	# potion : petite, à part
	_skill_button(layer, "potion", "", C + Vector2(-330, 62), 82, _use_potion)
	potion_btn = buttons["potion"]["btn"]
	potion_lbl = Label.new()
	potion_lbl.add_theme_font_size_override("font_size", 18)
	potion_lbl.add_theme_constant_override("outline_size", 6)
	potion_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
	potion_lbl.position = Vector2(52, -6)
	potion_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	potion_btn.add_child(potion_lbl)
	# déplacement : saut + sprint côte à côte, séparés des pouvoirs
	_skill_button(layer, "sprint", "Sprint", C + Vector2(-560, 70), 92, _toggle_sprint)
	_skill_button(layer, "jump", "Saut", C + Vector2(-450, 70), 92, hero.jump)
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
	interact_btn.offset_left = -330
	interact_btn.offset_right = 20
	interact_btn.offset_top = -205
	interact_btn.offset_bottom = -140
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
	dlg_panel.offset_top = -40
	dlg_panel.offset_bottom = -18
	dlg_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	dlg_panel.visible = false
	layer.add_child(dlg_panel)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 8)
	dlg_panel.add_child(vb)
	dlg_name = Label.new()
	dlg_name.add_theme_font_size_override("font_size", 26)
	dlg_name.add_theme_color_override("font_color", Color(1, 0.7, 0.4))
	vb.add_child(dlg_name)
	dlg_scroll = ScrollContainer.new()
	dlg_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vb.add_child(dlg_scroll)
	dlg_text = Label.new()
	dlg_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dlg_text.custom_minimum_size = Vector2(880, 0)
	dlg_text.add_theme_font_size_override("font_size", 21)
	dlg_text.add_theme_color_override("font_color", Color(0.9, 0.94, 1))
	dlg_scroll.add_child(dlg_text)
	dlg_choices = HFlowContainer.new()
	dlg_choices.add_theme_constant_override("h_separation", 8)
	dlg_choices.add_theme_constant_override("v_separation", 6)
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
	unarmed_btn.text = "        " + ("Reprendre l'épée" if hero.unarmed_mode else "Mains nues")

func _icon_btn(key: String, size: float) -> Button:
	var b := Button.new()
	var empty := StyleBoxEmpty.new()
	for st in ["normal", "hover", "pressed", "focus"]:
		b.add_theme_stylebox_override(st, empty)
	b.focus_mode = Control.FOCUS_NONE
	b.pivot_offset = Vector2(size, size) * 0.5
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/%s.png" % key)
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	ic.set_anchors_preset(Control.PRESET_FULL_RECT)
	ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	b.add_child(ic)
	b.button_down.connect(_press_anim.bind(b))
	return b

func _toggle_quick() -> void:
	var qp := quick_menu.get_parent() as Control
	sfx("click", null, -8.0)
	if qp.visible:
		qp.visible = false
		return
	menu_panel.visible = false
	qp.visible = true
	qp.pivot_offset = Vector2(qp.size.x, 0)
	qp.scale = Vector2(0.6, 0.2)
	qp.modulate.a = 0.0
	var tw := qp.create_tween().set_parallel(true)
	tw.tween_property(qp, "scale", Vector2.ONE, 0.18).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(qp, "modulate:a", 1.0, 0.12)

func _quick_open(tab: String) -> void:
	(quick_menu.get_parent() as Control).visible = false
	_toggle_menu(tab)

func _quick_quest() -> void:
	(quick_menu.get_parent() as Control).visible = false
	_show_quest()

# ---------------------------------------------------------------- menu discret : ombres + stats
func _build_menu(layer: CanvasLayer) -> void:
	# miniature de menu : un seul bouton qui déroule un petit menu rapide
	var mb := _icon_btn("menu", 74)
	mb.anchor_left = 1.0
	mb.anchor_right = 1.0
	mb.offset_left = -96
	mb.offset_right = -22
	mb.offset_top = 14
	mb.offset_bottom = 88
	mb.pressed.connect(_toggle_quick)
	layer.add_child(mb)
	buttons["menu_btn"] = {"btn": mb, "shade": null, "label": null}
	var qp := PanelContainer.new()
	qp.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.03, 0.1, 0.86), Color(0.55, 0.4, 1.0, 0.8)))
	qp.anchor_left = 1.0
	qp.anchor_right = 1.0
	qp.offset_left = -262
	qp.offset_right = -22
	qp.offset_top = 96
	qp.visible = false
	layer.add_child(qp)
	quick_menu = VBoxContainer.new()
	quick_menu.add_theme_constant_override("separation", 4)
	qp.add_child(quick_menu)
	for k in [["quest", "Quête du jour", ""], ["sac", "Sac", "sac"], ["grimoire", "Grimoire", "grimoire"], ["ombres", "Ombres", "ombres"], ["stats", "Statistiques", "stats"], ["unarmed", "Mains nues", ""]]:
		var row := Button.new()
		row.text = "        " + str(k[1])
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.add_theme_font_size_override("font_size", 18)
		row.add_theme_color_override("font_color", Color(0.88, 0.9, 1))
		var rs := StyleBoxFlat.new()
		rs.bg_color = Color(0.1, 0.08, 0.25, 0.0)
		rs.set_corner_radius_all(22)
		rs.content_margin_left = 8
		rs.content_margin_top = 4
		rs.content_margin_bottom = 4
		row.add_theme_stylebox_override("normal", rs)
		row.add_theme_stylebox_override("hover", rs)
		var rp: StyleBoxFlat = rs.duplicate()
		rp.bg_color = Color(0.35, 0.25, 0.8, 0.5)
		row.add_theme_stylebox_override("pressed", rp)
		row.focus_mode = Control.FOCUS_NONE
		row.custom_minimum_size = Vector2(230, 50)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/%s.png" % str(k[0]))
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		ic.position = Vector2(4, 2)
		ic.size = Vector2(46, 46)
		ic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		row.add_child(ic)
		if str(k[0]) == "quest":
			row.pressed.connect(_quick_quest)
		elif str(k[0]) == "unarmed":
			row.pressed.connect(_toggle_unarmed)
			unarmed_btn = row
		else:
			row.pressed.connect(_quick_open.bind(str(k[2])))
		quick_menu.add_child(row)
	buttons["quick"] = {"btn": qp, "shade": null, "label": null}
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
	elif menu_tab == "sac":
		_refresh_bag()
	elif menu_tab == "grimoire":
		menu_body.add_child(_lbl("GRIMOIRE DES POUVOIRS", 24, Color(0.8, 0.65, 1)))
		menu_body.add_child(_lbl("Essences : %d — améliore un pouvoir jusqu'au niveau 5." % essence, 16, Color(0.7, 0.75, 0.9)))
		var lv: Dictionary = hero.powers
		var info := [
			["step", "PAS DE L'OMBRE", "Enchaîne %d ennemis dans le dos, %d %% de dégâts." % [2 + int(lv["step"]) + int(hero.stats["domaine"] / 2), int(100 * (2.1 + 0.2 * lv["step"]))]],
			["arise", "ARISE", "Relève tous les cadavres du domaine. Recharge %d s." % int(Hero.CD_MAX["arise"] - (lv["arise"] - 1))],
			["tele", "AUTORITÉ DU SOUVERAIN", "Télékinésie : soulève les ennemis devant toi (%d m) puis les écrase, %d %% de dégâts." % [int(9 + lv["tele"] * 1.5), int(100 * (1.6 + 0.3 * lv["tele"]))]],
			["plunge", "FRAPPE PLONGEANTE", "En l'air, ATTAQUE : tu plonges et frappes une zone de %.1f m." % (3.6 + 0.4 * lv["plunge"])],
			["perfect", "ESQUIVE PARFAITE", "Esquive juste avant un coup : ralenti, puis CONTRE à x2,5."],
			["swap", "ÉCHANGE D'OMBRE", "Échange ta place avec une ombre (celle proche de ta cible)." if lv["swap"] > 0 else "Verrouillé — se débloque au niveau 4."],
		]
		for r in info:
			var hb := HBoxContainer.new()
			var lvl := int(lv[r[0]])
			var title := "%s  —  %s" % [r[1], ("niv. %d / 5" % lvl) if lvl > 0 else "verrouillé"]
			hb.add_child(_lbl("%s\n%s" % [title, r[2]], 16, Color(0.88, 0.85, 1) if lvl > 0 else Color(0.55, 0.55, 0.65)))
			if lvl > 0 and lvl < 5 and r[0] != "perfect":
				var b := _small_btn("+ (%d)" % hero.power_cost(r[0]))
				b.disabled = essence < hero.power_cost(r[0])
				b.custom_minimum_size = Vector2(86, 44)
				b.pressed.connect(_upgrade_power.bind(str(r[0])))
				hb.add_child(b)
			menu_body.add_child(hb)
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

func _refresh_bag() -> void:
	var wn := "aucune"
	if equip["w"] >= 0 and not item_by_uid(equip["w"]).is_empty():
		wn = Items.base_of(item_by_uid(equip["w"]))["n"]
	menu_body.add_child(_lbl("SAC  %d / %d      Arme : %s" % [inv.size(), INV_MAX, wn], 20, Color(1, 0.85, 0.5)))
	menu_body.add_child(_lbl("Reliques %d / %d — dégâts %d, vitesse d'attaque x%.2f, critique %d %%" % [(equip["r"] as Array).size(), relic_slots(), int(hero.power()), hero.atk_speed(), int(hero.crit_chance())], 15, Color(0.75, 0.8, 0.95)))
	var fr := HBoxContainer.new()
	for f in [["ARMES", "w"], ["RELIQUES", "r"], ["ÉQUIPEMENT", "a"]]:
		var b := _small_btn(("» " if inv_filter == f[1] else "") + str(f[0]))
		b.pressed.connect(_set_filter.bind(str(f[1])))
		fr.add_child(b)
	menu_body.add_child(fr)
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	var shown := 0
	var sorted := inv.duplicate()
	sorted.sort_custom(func(a, b): return Items.rarity(a) > Items.rarity(b))
	for it in sorted:
		if it["t"] != inv_filter:
			continue
		shown += 1
		var b := Button.new()
		var nm := str(Items.base_of(it)["n"])
		if nm.length() > 17:
			nm = nm.substr(0, 16) + "."
		b.text = "[%s] %s%s" % [Items.RAR[Items.rarity(it)]["k"], nm, " [É]" if is_equipped(int(it["uid"])) else ""]
		b.add_theme_font_size_override("font_size", 14)
		var col := Items.color(it)
		b.add_theme_color_override("font_color", col.lightened(0.3))
		var sb := StyleBoxFlat.new()
		sb.bg_color = Color(col.r * 0.18, col.g * 0.18, col.b * 0.22, 0.9) if int(it["uid"]) != inv_sel else Color(col.r * 0.4, col.g * 0.4, col.b * 0.45, 0.95)
		sb.border_color = col
		sb.set_border_width_all(2 if not is_equipped(int(it["uid"])) else 3)
		sb.set_corner_radius_all(6)
		sb.content_margin_left = 6
		sb.content_margin_right = 6
		sb.content_margin_top = 6
		sb.content_margin_bottom = 6
		b.add_theme_stylebox_override("normal", sb)
		b.add_theme_stylebox_override("hover", sb)
		b.add_theme_stylebox_override("pressed", sb)
		b.custom_minimum_size = Vector2(176, 42)
		b.focus_mode = Control.FOCUS_NONE
		b.pressed.connect(_select_item.bind(int(it["uid"])))
		grid.add_child(b)
	menu_body.add_child(grid)
	if shown == 0:
		menu_body.add_child(_lbl("Rien ici. Les monstres, les coffres d'élite et les boss lâchent du butin (rayon de couleur au sol).", 15))
	var sel := item_by_uid(inv_sel)
	if not sel.is_empty() and sel["t"] == inv_filter:
		var rk := Items.rarity(sel)
		menu_body.add_child(_lbl("%s  —  %s (%s)" % [Items.base_of(sel)["n"], Items.RAR[rk]["n"], Items.RAR[rk]["k"]], 20, Items.color(sel).lightened(0.2)))
		var extra := ""
		if sel["t"] == "w":
			var cur: Dictionary = hero.weapon
			extra = "\nComparé à ton arme : dégâts x%.2f → x%.2f, vitesse x%.2f → x%.2f" % [float(cur.get("mult", 1.0)), float(Items.base_of(sel)["mult"]), float(cur.get("spd", 1.0)), float(Items.base_of(sel)["spd"])]
		menu_body.add_child(_lbl(Items.describe(sel) + extra, 15, Color(0.85, 0.88, 1)))
		var ar := HBoxContainer.new()
		var eqd := is_equipped(inv_sel)
		var be := _small_btn("RETIRER" if eqd else "ÉQUIPER")
		be.pressed.connect(_toggle_equip.bind(inv_sel))
		ar.add_child(be)
		var bs := _small_btn("VENDRE +%d or" % Items.sell_price(sel))
		bs.pressed.connect(_remove_sel.bind(true))
		ar.add_child(bs)
		var bd := _small_btn("DÉMANTELER +%d ess." % Items.dismantle_value(sel))
		bd.pressed.connect(_remove_sel.bind(false))
		ar.add_child(bd)
		menu_body.add_child(ar)

func _set_filter(f: String) -> void:
	inv_filter = f
	inv_sel = -1
	sfx("click", null, -8.0)
	_refresh_menu()

func _select_item(uid: int) -> void:
	inv_sel = uid
	sfx("select", null, -8.0)
	_refresh_menu()

func _toggle_equip(uid: int) -> void:
	if is_equipped(uid):
		unequip_item(uid)
	else:
		equip_item(uid)
	save_game()
	_refresh_menu()

func _remove_sel(sell: bool) -> void:
	if inv_sel < 0:
		return
	if equip["w"] == inv_sel:
		sfx("error")
		system_msg("Impossible : c'est ton arme équipée.")
		return
	remove_item(inv_sel, sell)
	inv_sel = -1
	save_game()
	_refresh_menu()

func _upgrade_power(k: String) -> void:
	if hero.upgrade_power(k):
		sfx("levelup")
		save_game()
	else:
		sfx("error")
	_refresh_menu()

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

func _do_tele() -> void:
	hero.telekinesis()

func _do_swap() -> void:
	hero.shadow_swap()

func _do_step() -> void:
	hero.shadow_step()

func _do_arise() -> void:
	hero.arise()

func _update_ui() -> void:
	if hero == null or hp_fill == null:
		return
	hp_fill.size.x = 328.0 * clampf(hero.hp / hero.max_hp, 0, 1)
	mp_fill.size.x = 328.0 * clampf(hero.mp / hero.max_mp, 0, 1)
	hp_txt.text = "PV %d / %d      PM %d      Niv. %d" % [int(hero.hp), int(hero.max_hp), int(hero.mp), hero.level]
	rank_lbl.text = "CHASSEUR  ·  Rang %s" % hunter_rank
	potion_lbl.text = "x%d" % potions
	for k in ["attack", "roll", "step", "tele", "arise", "potion", "sprint", "jump"]:
		(buttons[k]["btn"] as Control).visible = not in_dialogue
	(buttons["swap"]["btn"] as Button).visible = hero.powers["swap"] > 0 and not in_dialogue
	potion_btn.modulate = Color(1, 1, 1, 1.0 if potions > 0 and potion_cd <= 0.0 else 0.45)
	shadow_txt.text = "Ombres  %d / 4" % shadow_count()
	res_txt.text = "%d or   ·   %d essences" % [gold, essence]
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
		gate_txt.text = "Portail rang C  %s  %d m   (%d:%02d)" % [arrow, int(d.length()), t / 60, t % 60]
		var ds := shop_door_pos - hero.global_position
		ds.y = 0
		if shop_door_pos != Vector3.INF and ds.length() > 3.0:
			gate_txt.text += "\nBoutique  %s  %d m" % [_arrow(ds), int(ds.length())]
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
	elif zone == "shop":
		gate_txt.text = "Boutique de l'Association"
	else:
		gate_txt.text = "Salle du Trône"
	for k in buttons.keys():
		var d: Dictionary = buttons[k]
		if d["shade"] == null:
			continue
		var c: float = hero.cd[k]
		var mx: float = Hero.CD_MAX[k]
		var shade: TextureProgressBar = d["shade"]
		var lab: Label = d["label"]
		var lacks_mp: bool = hero.mp < Hero.MP_COST.get(k, 0.0)
		shade.value = 1.0 if lacks_mp and c <= 0.0 else clampf(c / mx, 0.0, 1.0)
		lab.text = ("%d" % ceili(c)) if (c > 0.6 and k != "attack") else ""

func _arrow(d: Vector3) -> String:
	var rel := wrapf(atan2(-d.x, -d.z) - yaw, -PI, PI)
	if absf(rel) > 2.4:
		return "↓"
	elif rel > 0.6:
		return "←"
	elif rel < -0.6:
		return "→"
	return "↑"

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

func _put_hero_near(camp_i: int, dist: float) -> void:
	var c: Dictionary = camps[mini(camp_i, camps.size() - 1)]
	var p: Vector3 = c["pos"]
	var dir := spawn_point - p
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, 1)
	_place_hero(p + dir * dist, p)

## Tests inventaire, rôles d'ombres et chasseurs (CI).
func _test_gear_roles() -> void:
	var y0 := yaw
	for id in ["w3", "w2", "w8"]:
		grant_item("w", id)
	grant_item("r", "r4")
	grant_item("r", "r8")
	grant_item("a", "a5")
	var s0 := hero.atk_speed()
	equip_item(int(inv[inv.size() - 6]["uid"]))
	var s_axe := hero.atk_speed()
	equip_item(int(inv[inv.size() - 5]["uid"]))
	var s_dag := hero.atk_speed()
	equip_item(int(inv[inv.size() - 4]["uid"]))
	for k in 3:
		equip_item(int(inv[inv.size() - 3 + k]["uid"]))
	print("GEAR_TEST katana=%.2f hache=%.2f dague=%.2f supreme=%.2f power=%d crit=%d hp=%d inv=%d" % [s0, s_axe, s_dag, hero.atk_speed(), int(hero.power()), int(hero.crit_chance()), int(hero.max_hp), inv.size()])
	hero.set_armed(true)
	yaw = y0 + PI * 0.8
	await _snap("03_arme_supreme", 25)
	yaw = y0 + PI
	pitch = -0.35
	for k in 3:
		drop_loot(hero.global_position + Vector3(-sin(yaw), 0, -cos(yaw)) * 5.0, "boss")
	await _snap("03b_butin", 15)
	_toggle_menu("sac")
	inv_sel = int(inv[inv.size() - 4]["uid"])
	_refresh_menu()
	await _snap("03c_sac", 10)
	_set_filter("r")
	await _snap("03d_sac_reliques", 8)
	menu_panel.visible = false
	# rôles d'ombres contre une meute
	var arena := spawn_point + Vector3(0, 0, -14)
	var foes: Array = []
	for i in 5:
		var g := spawn_free_mob("goblin" if i != 2 else "orc", arena + Vector3(i * 1.5 - 3.0, 0, -4.0))
		g.max_hp = 2000
		g.hp = 2000
		foes.append(g)
	var roles := [["orc", "tank"], ["shaman", "heal"], ["shaman", "fire"], ["goblin", "melee"]]
	var made: Array = []
	for r in roles:
		var m := spawn_free_mob(str(r[0]), arena + Vector3(randf_range(-2, 2), 0, 3.0))
		m.dead = true
		m.rise_as_shadow(str(r[1]))
		m.busy = 0.0
		m.skill_cd = 0.5
		m.skill2_cd = 1.5
		made.append(m)
	_place_hero(arena + Vector3(0, 0, 6), arena)
	hero.hp = hero.max_hp * 0.5
	pitch = -0.45
	spring.spring_length = 9.0
	await _snap("04_roles_a", 70)
	await _snap("04_roles_b", 45)
	await _snap("04_roles_c", 45)
	var line := "ROLES"
	for m in made:
		line += " %s:%s pv=%d" % [(m as Mob).kind, (m as Mob).role, int((m as Mob).hp)]
	var hp_foes := 0
	for f in foes:
		hp_foes += int((f as Mob).hp)
	print(line, " foes_hp=", hp_foes, " hero_hp=", int(hero.hp))
	for f in foes:
		if is_instance_valid(f) and not (f as Mob).dead:
			(f as Mob).take_damage(99999, hero)
	for m in made:
		mobs.erase(m)
		(m as Mob).queue_free()
	# chasseurs
	var hp0 := arena
	var sq := _spawn_squad(9, hp0)
	if not sq.is_empty():
		for m in sq["members"]:
			(m as Mob).patrol = []
		for i in 2:
			var g := spawn_free_mob("goblin", hp0 + Vector3(i * 1.5 - 0.7, 0, -4.5))
			g.max_hp = 110
			g.hp = 110
		_place_hero(hp0 + Vector3(2, 0, 6), hp0)
		hero.set_armed(false)
		spring.spring_length = 5.5
		pitch = -0.25
		await _snap("05_chasseurs_combat", 60)
		await _snap("05b_chasseurs_combat", 90)
		await _snap("05c_chasseurs_victoire", 120)
		await _snap("05d_chasseurs_check", 40)
	spring.spring_length = 4.7
	pitch = -0.3
	hero.max_hp = 99999
	hero.hp = 99999

func _perf(tag: String, frames: int) -> void:
	var t0 := Time.get_ticks_usec()
	var dc := 0
	var worst := 0
	var last := t0
	for i in frames:
		await RenderingServer.frame_post_draw
		var now := Time.get_ticks_usec()
		worst = maxi(worst, now - last)
		last = now
		dc += RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
	var avg := float(Time.get_ticks_usec() - t0) / frames / 1000.0
	print("PERF %s frame=%.1fms pire=%.1fms drawcalls=%d objets=%d lumieres=%d mobs=%d" % [tag, avg, worst / 1000.0, dc / frames, RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME), FX.light_budget, mobs.size()])

func _run_shots() -> void:
	await _snap("00_quete_quotidienne", 25)
	close_dialogue()
	await _perf("ville", 180)
	moon.shadow_enabled = false
	await _perf("sans_ombres", 90)
	moon.shadow_enabled = true
	world_env.environment.glow_enabled = false
	await _perf("sans_glow", 90)
	world_env.environment.glow_enabled = true
	hero.max_hp = 99999
	hero.hp = 99999
	await _snap("00_depart", 20)
	_toggle_quick()
	await _snap("00a_menu_rapide", 15)
	_toggle_quick()
	# portail de près
	_place_hero(gate_pos + Vector3(0, 0, 9), gate_pos)
	pitch = -0.12
	await _snap("00p_portail", 30)
	# porte de la boutique puis intérieur
	_place_hero(shop_door_pos + shop_door_dir * 6.0, shop_door_pos)
	pitch = -0.15
	await _snap("00b_porte_boutique", 25)
	gold = 600
	essence = 10
	await enter_shop()
	await _snap("00b2_boutique", 40)
	_place_hero(merchant.global_position + (shop_entry - merchant.global_position).normalized() * 2.4, merchant.global_position)
	await _snap("00b3_intendant", 20)
	_merchant_dialogue()
	await _snap("00c_marchand_dialogue", 25)
	_buy("potion")
	_buy("shadow")
	close_dialogue()
	await leave_shop()
	await get_tree().create_timer(0.7).timeout
	hero.hp = 30000
	_use_potion()
	await _snap("00d_potion", 12)
	print("SHOP_TEST or=%d potions=%d niveau_ombres=%d" % [gold, potions, shadow_lvl])
	# rang
	hero.level = 5
	rep = 45
	await _snap("00e_rang", 30)
	_place_hero(spawn_point, spawn_point + Vector3(0, 0, -10))
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
	await _test_gear_roles()
	_place_hero(spawn_point, spawn_point + Vector3(0, 0, -10))
	yaw = y0 + PI * 0.5
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
		# bond vertical sur le mur puis rebond
		hero.global_position = start + Vector3(0, 0.3, 0)
		hero.move_input = Vector2(0, -1)
		await _snap("07b_x", 10)
		hero.jump()
		for i in 14:
			await get_tree().physics_frame
		var y1 := hero.global_position.y
		hero.cd["jump"] = 0.0
		hero.jump()
		await _snap("07c_bond_mural", 12)
		print("WALL_LEAP grimpe=%s y_avant=%.2f y_apres=%.2f" % [str(hero.climbing), y1, hero.global_position.y])
		hero.move_input = Vector2.ZERO
		hero.cd["jump"] = 0.0
		hero.jump()
		await _snap("07d_rebond", 10)
		print("WALL_KICK vitesse=%s" % str(hero.velocity.snapped(Vector3(0.1, 0.1, 0.1))))
		await _snap("07e_x", 50)
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
	var victim := hero.nearest_enemy(20.0)
	if victim:
		victim.take_damage(25, hero)
		await get_tree().physics_frame
		print("HPBAR pv=%.0f/%.0f fill=%.2f" % [victim.hp, victim.max_hp, float((victim.hp_fill.material_override as ShaderMaterial).get_shader_parameter("fill"))])
	hero.mp = 100
	hero.telekinesis()
	await _snap("10b_telekinesie", 22)
	await _snap("10c_telekinesie_impact", 50)
	# esquive parfaite
	hero.cd["roll"] = 0.0
	hero.roll()
	hero.take_damage(10, victim)
	await _snap("10d_esquive_parfaite", 10)
	# frappe plongeante
	hero.global_position += Vector3(0, 7, 0)
	hero.airborne = true
	hero.cd["attack"] = 0.0
	await get_tree().physics_frame
	hero.attack()
	await _snap("10e_plongeon", 8)
	await _snap("10f_plongeon_impact", 20)
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
	essence = 20
	_toggle_menu("grimoire")
	await _snap("19b_grimoire", 10)
	_upgrade_power("tele")
	print("GRIMOIRE tele=%d essences=%d" % [hero.powers["tele"], essence])
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
	save_game()
	var saved_shadows := shadow_count()
	for m in shadow_list():
		_remove_mob(m)
	gold = 0
	hero.level = 1
	var ok := load_game()
	await _snap("23_apres_chargement", 30)
	print("SAVE_TEST ok=%s niveau=%d or=%d ombres=%d/%d quete=%s" % [ok, hero.level, gold, shadow_count(), saved_shadows, str(quest.get("run", 0))])
	print("SHOTS_DONE niveau=%d ombres=%d" % [hero.level, shadow_count()])
	get_tree().quit()
