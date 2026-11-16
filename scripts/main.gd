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
var run: RoomRun
var nav: Nav
var entering_run := false
var load_lbl: Label
var world_static: Node3D
var ui_layer: CanvasLayer
var bench_running := false
var bars_hidden := false
var bench: Bench
var diag_on := false
var diag_t := 0.0
var diag_lbl: Label
var gate_kind := "goblin"
var tokens := {"orc": 0, "goblin": 0}
var env_run: Environment
const RUN_O := Vector3(-6000, 0, -3000)
const OFFICE_O := Vector3(-3000, 0, 1500)
const OFFICE_S := 0.013
var office: Node3D
var office_door := Vector3.INF
var office_entry := Vector3.ZERO
var office_exit := Vector3.ZERO
var changer: Mob
const TOK_TEX := {"orc": preload("res://assets/ui/tok_orc.png"), "goblin": preload("res://assets/ui/tok_goblin.png")}
const TOK_NAME := {"orc": "jeton orque", "goblin": "jeton gobelin"}
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
var play_t := 0.0
var bag_sort := "power"
var qpanel: PanelContainer
var qrows := {}
var qtrack_open := true
var cash_lbl: Label
var hud_money: Control
var ess_lbl: Label
var menu_title: Label
var menu_icon: TextureRect
var menu_chips: HBoxContainer
var menu_scroll: ScrollContainer
var menu_split: HBoxContainer
var sh_sel: Mob
const CASH_TEX := preload("res://assets/ui/cash.png")
const ESS_TEX := preload("res://assets/ui/essence.png")
var life: CityLife
var army_mode := "auto"
var army_t := 0.0
var parley_cd := 40.0
var parley_box: HBoxContainer
var parley_mob: Mob
var parley_data: Dictionary = {}
var parley_t := 0.0
var tk_menu: Array = []
var gfx_btn: Button
var gfx_fast := false
var fps_lbl: Label
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

func _on_node_added(n: Node) -> void:
	# les effets créés par code ne projettent pas d'ombre (gros gain sur la passe d'ombres)
	if n is GeometryInstance3D and n.owner == null:
		(n as GeometryInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF

func _ready() -> void:
	if OS.get_cmdline_user_args().has("--icons"):
		var ib := Node.new()
		ib.set_script(load("res://scripts/icon_baker.gd"))
		add_child(ib)
		set_process(false)
		set_physics_process(false)
		set_process_input(false)
		return
	get_tree().node_added.connect(_on_node_added)
	# pas d'« effet boule de neige » : si une image est lente, on ne rattrape pas 8 pas de physique d'un coup
	Engine.max_physics_steps_per_frame = 3
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
	_build_hall()
	_spawn_gate(true)
	_spawn_merchant()
	await get_tree().physics_frame
	life = CityLife.new()
	life.main = self
	add_child(life)
	life.setup()
	nav = Nav.new()
	add_child(nav)
	nav.setup(self)
	nav.bake("city", world_static, AABB(spawn_point - Vector3(150, 20, 150), Vector3(300, 70, 300)), [spawn_point])
	bench = Bench.new()
	bench.main = self
	add_child(bench)
	if shots_mode:
		DirAccess.remove_absolute(ProjectSettings.globalize_path(SAVE_PATH))
	load_game()
	if inv.is_empty():
		var it := {"uid": next_uid, "t": "w", "id": "w1"}
		next_uid += 1
		inv.append(it)
		equip["w"] = int(it["uid"])
	recalc_gear()
	if not shots_mode:
		_load_settings()
	await _prewarm()
	hint("start")
	last_pos = hero.global_position
	audio.music("city")
	system_msg("[ SYSTÈME ]\nUn Portail de rang %s est apparu en ville : %s.\nL'Association des Chasseurs le garde." % [gate_rank(), gate_name()])
	_check_daily()
	if shots_mode:
		_run_shots()

## Pré-compilation des shaders : chaque effet est joué une fois sous un écran de chargement.
## Sans ça, le rendu mobile compile au premier usage → gros à-coups en plein combat.
func _dbg_aabb(n: Node3D) -> String:
	var aabb := AABB()
	var first := true
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		var bb: AABB = m.global_transform * m.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	return str(aabb.position.round()) + " taille " + str(aabb.size.snapped(Vector3(0.01, 0.01, 0.01))) + " vis=" + str(n.is_visible_in_tree())

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
	var before := get_children()
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
	for w in ["katana", "lame", "hache", "dague", "coffre", "goblin", "orc", "chaman", "civ_coolman", "civ_woman"]:
		var n := (load("res://assets/%s.glb" % w) as PackedScene).instantiate() as Node3D
		holder.add_child(n)
		n.position = Vector3(randf_range(-1, 1), 0, randf_range(-1, 1))
	for k in 6:
		await RenderingServer.frame_post_draw
	o.queue_free()
	holder.queue_free()
	await get_tree().create_timer(0.4).timeout
	for c in get_children():
		if not before.has(c) and c is Node3D and not (c is Unit):
			c.queue_free()
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 0.0, 0.5)
	tw.tween_callback(title.queue_free)

## Coffre : base + couvercle monté sur charnière (s'ouvre vraiment).
func make_chest(pos: Vector3, s: float) -> Node3D:
	var root := Node3D.new()
	add_child(root)
	root.global_position = pos
	var inst := (load("res://assets/coffre.glb") as PackedScene).instantiate() as Node3D
	inst.scale = Vector3.ONE * s
	root.add_child(inst)
	var lid: Node3D = null
	for c in inst.get_children():
		if str(c.name).contains("haut"):
			lid = c
	if lid:
		var hinge := Node3D.new()
		hinge.name = "Hinge"
		inst.add_child(hinge)
		hinge.position = Vector3(-0.68, 0.8, 0)
		inst.remove_child(lid)
		hinge.add_child(lid)
		lid.position = -hinge.position
	var dir := hero.global_position - pos if hero else Vector3.FORWARD
	dir.y = 0
	if dir.length() > 0.1:
		root.rotation.y = atan2(dir.x, dir.z) - PI * 0.5
	var col := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(1.36, 0.9, 2.6) * s
	cs.shape = bs
	cs.position.y = 0.45 * s
	col.add_child(cs)
	root.add_child(col)
	return root

func open_chest_anim(ch: Node3D) -> void:
	var h := ch.find_child("Hinge", true, false) as Node3D
	if h == null:
		return
	var tw := h.create_tween()
	tw.tween_property(h, "rotation:z", 0.12, 0.08)
	tw.tween_property(h, "rotation:z", 1.9, 0.45).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	FX.burst(self, ch.global_position + Vector3(0, 0.8, 0), Color(1, 0.85, 0.4), 40, 0.08, 3.5, 0.9, 3.0)

func _build_other_envs() -> void:
	env_dun = env_city.duplicate() as Environment
	env_dun.background_mode = Environment.BG_COLOR
	env_dun.background_color = Color(0.02, 0.01, 0.02)
	env_dun.ambient_light_color = Color(0.55, 0.4, 0.35)
	env_dun.ambient_light_energy = 0.45
	env_dun.fog_light_color = Color(0.12, 0.05, 0.04)
	env_dun.fog_density = 0.03
	env_run = env_dun.duplicate() as Environment
	env_run.fog_density = 0.012
	env_run.ambient_light_energy = 0.6
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
	moon_l.directional_shadow_max_distance = 30.0
	moon_l.directional_shadow_fade_start = 0.75
	add_child(moon_l)

func _build_city() -> void:
	city = (load("res://assets/city.glb") as PackedScene).instantiate()
	city.scale = Vector3.ONE * CITY_SCALE
	add_child(city)
	# collisions du décor dans un repère sans échelle : sert aussi au calcul du maillage navigable
	world_static = Node3D.new()
	world_static.name = "WorldStatic"
	add_child(world_static)
	for mi in city.find_children("*", "MeshInstance3D", true, false):
		var m := mi as MeshInstance3D
		for i in m.mesh.get_surface_count():
			var mat := m.mesh.surface_get_material(i) as StandardMaterial3D
			if mat == null:
				continue
			var nm := mat.resource_name.to_lower()
			if nm.contains("glow") and mat.albedo_texture == null:
				# panneaux/cônes lumineux sans texture : rendus en lueur additive douce (sinon gros aplats blancs)
				var a := StandardMaterial3D.new()
				a.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
				a.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				a.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
				a.cull_mode = BaseMaterial3D.CULL_DISABLED
				var gc := Color(1, 0.92, 0.7)
				if nm.contains("red"):
					gc = Color(1, 0.2, 0.25)
				elif nm.contains("green"):
					gc = Color(0.3, 1, 0.5)
				var big := m.get_aabb().size.length() * CITY_SCALE > 1.5
				a.albedo_color = Color(gc.r, gc.g, gc.b, 0.12 if big else 0.85)
				m.set_surface_override_material(i, a)
				m.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			elif nm.contains("glow"):
				var g := mat.duplicate() as StandardMaterial3D
				g.emission_enabled = true
				g.emission_texture = g.albedo_texture
				g.emission = Color(1, 1, 1)
				g.emission_energy_multiplier = 0.45
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
	world_static.add_child(floor_body)

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
	shape.set_faces(m.global_transform * faces)
	var body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	cs.shape = shape
	body.add_child(cs)
	world_static.add_child(body)
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
var _team_cache: Array = [[], [], [], []]
var _team_frame := -1
func units_of_team(t: int) -> Array:
	var f := Engine.get_physics_frames()
	if f != _team_frame:
		_team_frame = f
		_team_cache = [[], [], [], []]
		if hero:
			_team_cache[hero.team].append(hero)
		for m in mobs:
			if is_instance_valid(m):
				var tm: int = (m as Mob).team
				if tm >= 0 and tm <= 3:
					_team_cache[tm].append(m)
	if t < 0 or t > 3:
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
	for r: float in [32.0, 42.0, 52.0, 63.0, 75.0, 88.0, 101.0, 115.0]:
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
	for j in 8:
		var c: Vector3 = camps[(k * 3 + j * 2) % n]["pos"]
		var q := c + Vector3(6, 0, 4).rotated(Vector3.UP, j * 1.7)
		if q.distance_to(spawn_point) > 38.0 and pts.size() < 4:
			pts.append(q)
	if pts.size() < 2:
		pts.clear()
		for j in 4:
			var a := k * 1.3 + j * TAU / 4.0
			pts.append(spawn_point + Vector3(sin(a), 0, cos(a)) * 60.0)
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
	var start: Vector3 = (route[0] as Vector3) if at == null else at
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
		var chest := make_chest(chosen[i], 0.45)
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
	open_chest_anim(ch)
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
	if m.kind == "civil" or m.kind == "police":
		var tc := m.create_tween()
		tc.tween_interval(15.0)
		tc.tween_property(m, "scale", Vector3(1, 0.01, 1), 0.8)
		tc.tween_callback(_remove_mob.bind(m))
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
	if run and m.has_meta("run"):
		run.on_kill(m)
	gold += int(m.reward_gold * (1.0 + hero.g("gold") / 100.0))
	hint("kill")
	quest_add("kills", 1)
	sfx("coins", m.global_position, -8.0)
	rep += 3 if m.elite else 1
	var xpv := {"goblin": 12.0, "shaman": 15.0, "orc": 35.0, "orc_warrior": 55.0, "igris": 600.0}.get(m.kind, 10.0) as float
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

## Paliers de réputation : chacun débloque quelque chose (boutique, portails, police, raids).
func rep_title() -> String:
	if rep < 0:
		return "Hors-la-loi"
	if rep >= 150:
		return "Légende"
	if rep >= 100:
		return "Héros du quartier"
	if rep >= 60:
		return "Respecté"
	if rep >= REP_PASS:
		return "Reconnu"
	if rep >= 10:
		return "Remarqué"
	return "Inconnu"

func rep_next() -> int:
	for t in [10, REP_PASS, 60, 100, 150]:
		if rep < t:
			return t
	return 0

func rep_perks() -> String:
	var p: Array = []
	if rep >= REP_PASS:
		p.append("portails gardés ouverts")
	if rep >= 60:
		p.append("boutique -10 %, salut de la police")
	if rep >= 100:
		p.append("boutique -20 %")
	if rep >= 150:
		p.append("raids")
	return "aucun pour l'instant" if p.is_empty() else ", ".join(p)

func price_mult() -> float:
	return 0.8 if rep >= 100 else (0.9 if rep >= 60 else 1.0)

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
	if first:
		gate_kind = "goblin"
	else:
		var gr := randf()
		gate_kind = "goblin" if gr < 0.4 else ("orc" if gr < 0.82 else "igris")
	gate = FX.portal(self, pos, gate_color(), 2.4)
	gate_timer = GATE_PERIOD
	gate_open_for_me = false
	guards_hostile = false
	for g in guards:
		if is_instance_valid(g):
			mobs.erase(g)
			(g as Node).queue_free()
	guards.clear()
	for k in 2:
		var gp := pos + Vector3(-5.5 + 11.0 * k, 0, 4.0)
		var g := spawn_free_mob("guard", gp)
		g.patrol = [pos + Vector3(-7, 0, 6), pos + Vector3(7, 0, 6), pos + Vector3(7, 0, -6), pos + Vector3(-7, 0, -6)]
		g.patrol_i = k * 2
		guards.append(g)
	# le donjon n'est construit qu'à l'entrée (plus de chargement caché pendant qu'on joue en ville)
	if run:
		run.cleanup()
		run = null
	if gate_kind == "igris" and not first:
		_build_hall()
	if not first:
		system_msg("[ SYSTÈME ]\nUn nouveau Portail s'est ouvert ailleurs en ville !\n%s — rang %s." % [gate_name(), gate_rank()])
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
	dialogue("Garde de l'Association", ("Halte. Ce Portail de rang %s (%s) est sous" % [gate_rank(), gate_name()]) + " le contrôle de l'Association des Chasseurs. Personne n'entre sans autorisation.\n(Réputation : %d — il faut %d)" % [rep, REP_PASS], choices)

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
	hall.visible = z == "hall"
	if shop:
		shop.visible = z == "shop"
	if office:
		office.visible = z == "office"
	if run:
		run.visible = z == "run"
	for ce in city_extras:
		if is_instance_valid(ce):
			(ce as Node3D).visible = z == "city"
	if gate:
		gate.visible = z == "city"
	world_env.environment = env_city if z == "city" else (env_dun if z == "dungeon" else (env_shop if z == "shop" or z == "office" else (env_run if z == "run" else env_hall)))
	moon.visible = true

func _teleport(p: Vector3, z: String) -> void:
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
	enter_run()

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
	boss_bar_name.text = "COMMANDANT ÉCARLATE — Boss de rang C"
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
	boss_chest = make_chest(_hall_floor(16.0, 0.0), 0.65)
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
	open_chest_anim(boss_chest)
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
	var died_in_run := zone == "run"
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
	if died_in_run:
		boss_bar_root.visible = false
		boss = null
		system_msg("[ SYSTÈME ]\nLe Portail t'a rejeté et s'est refermé.\nLes jetons ramassés sont conservés.")
		_spawn_gate(false)

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

## Les unités trop proches de la caméra sont masquées (évite les grosses silhouettes qui bouchent l'écran).
func _hide_near_camera() -> void:
	if cam == null:
		return
	var cp := cam.global_position
	var hp := hero.global_position + Vector3(0, 1.0, 0)
	var seg := hp - cp
	var seg_l := seg.length()
	for m in mobs:
		var mm := m as Mob
		if mm.model == null or mm.sleeping_lod:
			continue
		var mp := mm.global_position + Vector3(0, 1.0, 0)
		var d2 := mp.distance_squared_to(cp)
		if d2 > 400.0:
			if not mm.model.visible:
				mm.model.visible = true
			continue
		var near := d2 < 2.6
		# un allié (ou un monstre) planté entre la caméra et le héros est masqué : on voit toujours le héros
		if not near and seg_l > 0.5:
			var t := clampf((mp - cp).dot(seg) / (seg_l * seg_l), 0.0, 1.0)
			if t < 0.92 and mp.distance_to(cp + seg * t) < mm.body_r + 0.45:
				near = true
		if mm.model.visible == near:
			mm.model.visible = not near
		if mm.hp_bar:
			var show := d2 > 9.0 and not bars_hidden and not mm.dead
			if mm.hp_bar.visible != show:
				mm.hp_bar.visible = show

func _process(delta: float) -> void:
	_hide_near_camera()
	play_t += delta
	if play_t > 100.0:
		hint("wall")
	_army_tick(delta)
	_population_tick(delta)
	if life:
		life.tick(delta)
	_parley_tick(delta)
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
	if zone == "run" and run:
		run.update(hero)
	if boss and is_instance_valid(boss) and boss_bar_root.visible:
		boss_bar_fill.size.x = 600.0 * clampf(boss.hp / boss.max_hp, 0, 1)
	potion_cd -= delta
	speech_cd -= delta
	_update_loot(delta)
	_update_squads(delta)
	msg_panel.visible = not (menu_panel and menu_panel.visible)
	if hud_money:
		hud_money.visible = not (menu_panel and menu_panel.visible)
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
					hint("gate")
					act = _guard_dialogue
		elif zone == "shop":
			if merchant and hero.global_position.distance_to(merchant.global_position) < 3.4:
				label = "PARLER À L'INTENDANT"
				act = _merchant_dialogue
			elif office_door != Vector3.INF and hero.global_position.distance_to(office_door) < 2.4:
				label = "ENTRER — BUREAU DU CHANGEUR"
				act = enter_office
			elif hero.global_position.distance_to(shop_exit) < 2.4:
				label = "SORTIR"
				act = leave_shop
		elif zone == "office":
			if changer and hero.global_position.distance_to(changer.global_position) < 3.0:
				label = "PARLER AU CHANGEUR"
				act = _changer_dialogue
			elif hero.global_position.distance_to(office_exit) < 2.0:
				label = "RETOUR À LA BOUTIQUE"
				act = leave_office
		elif zone == "run" and run and run.ready_ok:
			var rr: Dictionary = run.room()
			if run.boss_room():
				if run.chest and not run.chest_taken and hero.global_position.distance_to(run.chest.global_position) < 3.2:
					label = "OUVRIR LE COFFRE DU CHEF"
					act = run.open_chest
				elif run.exit_pos != Vector3.INF and hero.global_position.distance_to(run.exit_pos) < 3.0:
					label = "QUITTER LE DONJON"
					act = _leave_run
			elif rr["open"] and hero.global_position.distance_to(rr["exit"]) < 3.2:
				if str(rr["role"]) == "hall":
					label = "FRANCHIR LA PORTE DU TRÔNE"
					act = enter_hall
				else:
					label = "SALLE SUIVANTE"
					act = _next_room
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
	cam.far = 320.0
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

# ================================================================ ordres à l'armée
## « À l'attaque » : le Monarque pointe les monstres, les ombres s'élancent, chacune à sa place.
# ================================================================ population de monstres : toujours de quoi se battre, jamais les mêmes
var pop_t := 6.0
var roamers: Array = []
const GROUPS := [
	[["goblin", ""], ["goblin", ""], ["goblin", "eclaireur"]],
	[["goblin", ""], ["goblin", ""], ["shaman", ""]],
	[["goblin", "eclaireur"], ["goblin", "eclaireur"], ["goblin", "eclaireur"], ["goblin", "eclaireur"]],
	[["goblin", "berserker"], ["goblin", "berserker"]],
	[["orc", ""], ["shaman", ""], ["goblin", ""]],
	[["orc_warrior", ""], ["goblin", ""], ["goblin", ""]],
	[["orc_warrior", ""], ["shaman", ""], ["shaman", ""]],
	[["goblin", "berserker"], ["goblin", ""], ["shaman", ""], ["goblin", "eclaireur"]],
]

func _population_tick(delta: float) -> void:
	if zone != "city" or hero == null:
		return
	pop_t -= delta
	if pop_t > 0.0:
		return
	pop_t = 5.0
	var hp := hero.global_position
	for i in range(roamers.size() - 1, -1, -1):
		var r = roamers[i]
		if not is_instance_valid(r):
			roamers.remove_at(i)
			continue
		var m := r as Mob
		if m.dead or m.is_shadow:
			roamers.remove_at(i)
			continue
		if m.target == null and m.global_position.distance_to(hp) > 110.0:
			mobs.erase(m)
			m.queue_free()
			roamers.remove_at(i)
	var n := 0
	for u in units_of_team(1):
		var mm := u as Mob
		if mm and not mm.dead and not mm.dormant and mm.global_position.distance_to(hp) < 75.0:
			n += 1
	if n >= 11 or roamers.size() >= 14:
		return
	var space := get_world_3d().direct_space_state
	var camf := Vector3(-sin(yaw), 0, -cos(yaw))
	for tries in 10:
		var a := randf() * TAU
		var p := hp + Vector3(sin(a), 0, cos(a)) * randf_range(42.0, 62.0)
		if (p - hp).normalized().dot(camf) > 0.55 and tries < 7:
			continue
		if p.distance_to(spawn_point) < 30.0 or not _is_open(space, p + Vector3(0, 80, 0)):
			continue
		var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 40, 0), p + Vector3(0, -20, 0)))
		if g.is_empty():
			continue
		p = g["position"]
		var lvl_cap := 3 if hero.level < 3 else (6 if hero.level < 6 else GROUPS.size())
		var grp: Array = GROUPS[randi() % mini(lvl_cap, GROUPS.size())]
		var route: Array = []
		for k in 3:
			var b2 := randf() * TAU
			route.append(p + Vector3(sin(b2), 0, cos(b2)) * randf_range(10.0, 22.0))
		for i in grp.size():
			var m := spawn_free_mob(str(grp[i][0]), p + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 2.4)
			if str(grp[i][1]) != "":
				m.make_variant(str(grp[i][1]))
			m.patrol = route
			m.patrol_off = Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 1.8
			roamers.append(m)
		print("POP groupe ", grp.size(), " ", grp[0][0])
		return

func command_attack() -> void:
	if shadow_count() == 0 or hero.dead:
		return
	var foe := hero.nearest_enemy(30.0)
	if foe == null:
		system_msg("Aucun ennemi à portée.")
		return
	army_mode = "attack"
	army_t = 0.0
	hero.face_to(foe.global_position, true)
	hero.busy = 0.75
	hero.play("Point", 0.08, 1.0, true)
	FX.speech(hero, ["Allez-y.", "Écrasez-les.", "À vous."][randi() % 3], Color(0.75, 0.6, 1.0), 2.4, 1.4)
	sfx("shadow", hero.global_position, 0.0)
	var ring := FX.ground_disc(1.0, Color(0.6, 0.3, 1.0), 0.9, true)
	add_child(ring)
	ring.global_position = hero.global_position + Vector3(0, 0.06, 0)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(9, 1, 9), 0.5).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(ring, "transparency", 1.0, 0.5)
	tw.tween_callback(ring.queue_free)
	var i := 0
	for m in shadow_list():
		var mm := m as Mob
		mm.order = "auto"
		mm.target = null
		mm.boost_t = 2.2
		mm.later(0.25 + i * 0.08, mm.charge_fx)
		i += 1
	print("ARMY attack ombres=%d" % shadow_count())

## « Restez » : les ombres se rangent derrière le Monarque et l'encouragent.
func command_stay() -> void:
	if shadow_count() == 0:
		return
	army_mode = "stay" if army_mode != "stay" else "auto"
	hero.play("Talk", 0.1, 1.2, true)
	FX.speech(hero, "Restez en retrait." if army_mode == "stay" else "Protégez-moi.", Color(0.75, 0.6, 1.0), 2.4, 1.4)
	for m in shadow_list():
		(m as Mob).target = null
	print("ARMY ", army_mode)

func _army_tick(delta: float) -> void:
	if army_mode != "attack":
		return
	if hero.nearest_enemy(30.0) == null:
		army_t += delta
		if army_t > 2.5:
			army_mode = "auto"
	else:
		army_t = 0.0

# ================================================================ répliques des monstres (rares, avec du fond)
const PARLEYS := [
	{"k": "orc", "open": "Tu marches sur notre forêt, humain. Avant ta ville, il y avait des arbres ici. La Brèche nous a arrachés à un monde mourant... et toi, tu viens finir le travail.",
		"a": ["Ton monde est mort. Le mien se porte très bien.", "Alors je mourrai debout. Comme mes frères !"],
		"s": ["Personne ne vous a demandé de traverser. Repars, et je te laisse vivre.", "Repartir ? Derrière la Brèche, il n'y a plus que le silence."]},
	{"k": "shaman", "open": "Les esprits murmurent ton nom, chasseur. Ils disent que la Mort marche dans ton ombre. Qu'as-tu promis à ce qui te suit ?",
		"a": ["Rien. C'est lui qui me doit tout.", "L'arrogance... C'est ainsi que commencent les rois. Et que finissent les mondes."],
		"s": ["Je n'ai rien promis. Je survis.", "Tout le monde survit... jusqu'au jour où il faut choisir ce qu'on sacrifie."]},
	{"k": "goblin", "open": "Vous nous appelez « rang E ». Des miettes. Mais chaque cristal que tu revends au marché... il sort de nos cœurs.",
		"a": ["Alors ton cœur vaudra au moins huit pièces d'or.", "Rira bien qui saignera le dernier !"],
		"s": ["Je ne chasse pas pour l'or.", "...Alors pour quoi ? Les humains se racontent toujours de belles raisons."]},
	{"k": "elite", "open": "J'ai tué douze chasseurs dans cette rue. Ils avaient tous ce regard. Celui de quelqu'un qui se croit l'exception.",
		"a": ["Douze ? Tu vas enfin rencontrer un vrai chasseur.", "Prouve-le. Ou deviens le treizième."],
		"s": ["Je te crois. Mais eux ne commandaient pas aux morts.", "Les morts... ? Qu'est-ce que tu es, au juste ?"]},
	{"k": "orc", "open": "Mon clan a juré de planter son étendard au sommet de vos tours. Ce n'est pas de la haine, humain. C'est la loi du plus fort.",
		"a": ["Parfait. Selon ta loi, tu m'appartiens.", "HA ! Enfin un humain qui parle comme un orc !"],
		"s": ["Alors ta loi va te tuer aujourd'hui.", "Peut-être. Mais ce sera une mort qui a du sens."]},
	{"k": "goblin", "open": "Chut... Tu entends ? Les autres approchent. Tu crois vraiment que la Brèche ne s'ouvre qu'une fois ?",
		"a": ["Qu'ils viennent tous. Ça m'évitera de les chercher.", "Tu changeras de ton quand le ciel deviendra rouge."],
		"s": ["Combien êtes-vous ?", "Assez pour que vos villes brûlent... et pas assez pour la Chose qui nous chasse, nous."]},
	{"k": "shaman", "open": "Ton ombre a faim, chasseur. Je la sens qui nous regarde. Est-ce toi qui la nourris... ou elle qui te dévore ?",
		"a": ["Elle mange ce que je lui donne. Toi, par exemple.", "Alors que ton maître s'étouffe avec mes os !"],
		"s": ["Je ne sais pas encore.", "...Une réponse honnête. La première depuis que j'ai traversé."]},
]

## Appelée quand un monstre repère le héros : parfois (rarement), il engage la parole.
func try_parley(m: Mob, force := false) -> void:
	if not force and (parley_cd > 0.0 or in_dialogue or parley_box.visible or randf() > 0.35):
		return
	var key := "elite" if m.elite else m.kind
	var pool: Array = []
	for p in PARLEYS:
		if p["k"] == key:
			pool.append(p)
	if pool.is_empty():
		return
	parley_cd = randf_range(70.0, 120.0)
	parley_mob = m
	parley_data = pool[randi() % pool.size()]
	parley_t = 7.0
	FX.speech(m, str(parley_data["open"]), Color(1, 0.8, 0.65), 2.8 if m.kind != "orc" else 3.3, 6.5)
	for c in parley_box.get_children():
		c.queue_free()
	for opt in [["Arrogant", "a", Color(1.0, 0.55, 0.35)], ["Sérieux", "s", Color(0.55, 0.75, 1.0)]]:
		var b := _small_btn(str(opt[0]) + " : « " + str((parley_data[opt[1]] as Array)[0]).substr(0, 28) + "… »")
		b.add_theme_font_size_override("font_size", 15)
		b.add_theme_color_override("font_color", opt[2])
		b.pressed.connect(_parley_answer.bind(str(opt[1])))
		parley_box.add_child(b)
	parley_box.visible = true
	parley_box.modulate.a = 0.0
	create_tween().tween_property(parley_box, "modulate:a", 1.0, 0.3)
	print("PARLEY ", m.kind)

func _parley_answer(which: String) -> void:
	parley_box.visible = false
	if parley_mob == null or not is_instance_valid(parley_mob) or parley_mob.dead:
		return
	var pair: Array = parley_data[which]
	FX.speech(hero, str(pair[0]), Color(0.8, 0.7, 1.0), 2.4, 3.5)
	parley_mob.later(1.6, parley_mob.parley_reply.bind(str(pair[1]), which))

func _parley_tick(delta: float) -> void:
	parley_cd -= delta
	if parley_box and parley_box.visible:
		parley_t -= delta
		if parley_t <= 0.0 or parley_mob == null or not is_instance_valid(parley_mob) or parley_mob.dead:
			parley_box.visible = false

func open_tk_menu() -> void:
	hint("tele")
	for i in tk_menu.size():
		var b: Control = tk_menu[i]
		b.visible = true
		b.scale = Vector2(0.2, 0.2)
		b.modulate.a = 0.0
		var tw := b.create_tween().set_parallel(true)
		tw.tween_property(b, "scale", Vector2.ONE, 0.22).set_delay(i * 0.05).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
		tw.tween_property(b, "modulate:a", 1.0, 0.15).set_delay(i * 0.05)

func close_tk_menu() -> void:
	for b in tk_menu:
		(b as Control).visible = false

func _tk_pick(mode: String) -> void:
	hero.tk_finish(mode)

func print_debug_tk(mode: String, n: int) -> void:
	print("TK %s cibles=%d" % [mode, n])

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
	var it := {"uid": next_uid, "t": t, "id": id, "new": true}
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
	var gp := ground_at(pos)
	root.global_position = safe_point(gp, gp + Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6))) + Vector3(0, 0.1, 0)
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.05
	cm.bottom_radius = 0.22
	cm.height = 2.0 + rk * 0.7
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.material_override = FX._smat(FX.BEAM_SH, col * (0.8 + rk * 0.15))
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
	hint("loot")
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
			(l["item"] as Dictionary)["new"] = true
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
			w = Items.weapon_of(it)
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
	elif zone == "run":
		tr = "boss" if run and run.chief_started and run.chief and is_instance_valid(run.chief) and not run.chief.dead else ("combat" if combat_t > 0.0 else "dungeon")
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
	_build_office()

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
	hint("shop")

func leave_shop() -> void:
	sfx("open")
	await _teleport(shop_door_pos + shop_door_dir * 2.2, "city")
	yaw = atan2(-shop_door_dir.x, -shop_door_dir.z)

func _merchant_dialogue() -> void:
	merchant.face_to(hero.global_position, true)
	var txt := "Bonsoir, chasseur. Tout ce qu'il faut pour survivre aux Portails.\nTu as %d or et %d essences. Potions : %d.  Niveau de tes ombres : %d." % [gold, essence, potions, shadow_lvl]
	dialogue("Intendant de l'Association", txt, [
		["Potion de soin — %d or" % int(50 * price_mult()), _buy.bind("potion")],
		["Renforcer mes ombres (+12 %% PV et dégâts) — %d essences" % (4 + shadow_lvl * 2), _buy.bind("shadow")],
		["Affûter ma lame (+10 %% dégâts) — %d or" % (300 + int((hero.blade_mult - 1.0) * 2000)), _buy.bind("blade")],
		["« Rien, merci. »", close_dialogue],
	])

func _buy(what: String) -> void:
	match what:
		"potion":
			var pc := int(50 * price_mult())
			if gold >= pc:
				gold -= pc
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
	rep += 10
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
		sh.append({"kind": mm.kind, "elite": mm.elite, "boss": mm.boss, "role": mm.role, "slv": mm.slv})
	var d := {"v": 1, "level": hero.level, "xp": hero.xp, "points": hero.points, "stats": hero.stats, "gold": gold, "essence": essence, "rep": rep,
		"blade": hero.blade_mult, "unarmed": hero.unarmed_mode, "potions": potions, "shadow_lvl": shadow_lvl, "rank": hunter_rank, "quest": quest, "shadows": sh,
		"base_hp": hero.base_hp, "base_mp": hero.base_mp, "powers": hero.powers, "inv": inv, "equip": equip, "next_uid": next_uid, "hints": hints_seen.keys(), "tokens": tokens}
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
	for h in d.get("hints", []):
		hints_seen[str(h)] = true
	var tk: Dictionary = d.get("tokens", {})
	for k in tokens.keys():
		tokens[k] = int(tk.get(k, 0))
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
		m.rise_as_shadow(str(sdat.get("role", "")), int(sdat.get("slv", 0)))
	print("LOAD niveau=%d or=%d ombres=%d" % [hero.level, gold, shadow_count()])
	return true

# ================================================================ UI
func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	ui_layer = layer
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
	fps_lbl = _outlined(layer, Vector2(250, 128), 15, Color(0.6, 0.65, 0.75))
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
	# suivi de la quête du jour (toujours visible, touche pour replier)
	qpanel = PanelContainer.new()
	qpanel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.04, 0.12, 0.62), Color(1.0, 0.75, 0.35, 0.6)))
	qpanel.position = Vector2(394, 18)
	layer.add_child(qpanel)
	var qv := VBoxContainer.new()
	qv.add_theme_constant_override("separation", 3)
	qpanel.add_child(qv)
	var qh := Button.new()
	qh.text = "QUÊTE DU JOUR  ▾"
	qh.flat = true
	qh.alignment = HORIZONTAL_ALIGNMENT_LEFT
	qh.add_theme_font_size_override("font_size", 15)
	qh.add_theme_color_override("font_color", Color(1, 0.85, 0.5))
	qh.focus_mode = Control.FOCUS_NONE
	qh.pressed.connect(_toggle_qtrack)
	qv.add_child(qh)
	buttons["qtrack"] = {"btn": qpanel, "shade": null, "label": null}
	for g in QUEST_GOALS.keys():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 6)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/q_%s.png" % g)
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(24, 24)
		row.add_child(ic)
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 1)
		var l := Label.new()
		l.add_theme_font_size_override("font_size", 13)
		l.add_theme_color_override("font_color", Color(0.85, 0.9, 1))
		col.add_child(l)
		var bar := ProgressBar.new()
		bar.custom_minimum_size = Vector2(150, 5)
		bar.show_percentage = false
		var bgs := StyleBoxFlat.new()
		bgs.bg_color = Color(0, 0, 0, 0.6)
		var fgs := StyleBoxFlat.new()
		fgs.bg_color = Color(1, 0.75, 0.3)
		bar.add_theme_stylebox_override("background", bgs)
		bar.add_theme_stylebox_override("fill", fgs)
		col.add_child(bar)
		row.add_child(col)
		qv.add_child(row)
		qrows[g] = [l, bar, row]
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
	res_txt.visible = false
	var rr := HBoxContainer.new()
	rr.alignment = BoxContainer.ALIGNMENT_END
	rr.add_theme_constant_override("separation", 16)
	rr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	info_box.add_child(rr)
	var c1 := UICards.chip(CASH_TEX, "0", Color(0.65, 1, 0.65), 30)
	var c2 := UICards.chip(ESS_TEX, "0", Color(0.85, 0.7, 1), 30)
	rr.add_child(c1)
	rr.add_child(c2)
	cash_lbl = c1.get_child(1)
	ess_lbl = c2.get_child(1)
	hud_money = rr
	# combat : grosse attaque + pouvoirs en arc (style action-RPG mobile)
	var C := Vector2(-140, -140)
	_skill_button(layer, "attack", "", C, 176, hero.attack)
	var arc := [["roll", "Esquive", 182.0, _roll_btn], ["step", "Pas de l'ombre", 148.0, _do_step], ["tele", "Télékinésie", 114.0, _do_tele], ["arise", "Arise", 80.0, _do_arise]]
	for it in arc:
		var ang := deg_to_rad(float(it[2]))
		_skill_button(layer, str(it[0]), str(it[1]), C + Vector2(cos(ang), -sin(ang)) * 212.0, 104, it[3])
	var ang2 := deg_to_rad(128.0)
	_skill_button(layer, "swap", "Échange", C + Vector2(cos(ang2), -sin(ang2)) * 338.0, 92, _do_swap)
	# mini-menu de télékinésie (apparaît autour du bouton pendant la prise)
	var tc := C + Vector2(cos(deg_to_rad(114.0)), -sin(deg_to_rad(114.0))) * 212.0
	tk_menu = []
	var opts := [["tk_eject", "Éjecter", "eject", 150.0], ["tk_crush", "Écraser", "crush", 105.0], ["tk_choke", "Étrangler", "choke", 60.0]]
	for o in opts:
		var a2 := deg_to_rad(float(o[3]))
		_skill_button(layer, str(o[0]), str(o[1]), tc + Vector2(cos(a2), -sin(a2)) * 128.0, 84, _tk_pick.bind(str(o[2])))
		var bt: Control = buttons[str(o[0])]["btn"]
		bt.visible = false
		tk_menu.append(bt)
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
	# ordres à l'armée d'ombres
	_skill_button(layer, "cmd_attack", "À l'attaque", C + Vector2(-560, -62), 80, command_attack)
	_skill_button(layer, "cmd_stay", "Restez", C + Vector2(-462, -62), 80, command_stay)
	# réponses rapides aux monstres (discrètes, temporaires)
	parley_box = HBoxContainer.new()
	parley_box.anchor_left = 0.5
	parley_box.anchor_right = 0.5
	parley_box.anchor_top = 1.0
	parley_box.anchor_bottom = 1.0
	parley_box.offset_left = -300
	parley_box.offset_right = 300
	parley_box.offset_top = -300
	parley_box.offset_bottom = -252
	parley_box.alignment = BoxContainer.ALIGNMENT_CENTER
	parley_box.add_theme_constant_override("separation", 10)
	parley_box.visible = false
	layer.add_child(parley_box)
	buttons["parley"] = {"btn": parley_box, "shade": null, "label": null}
	# déplacement : saut + sprint côte à côte, séparés des pouvoirs
	_skill_button(layer, "sprint", "Sprint", C + Vector2(-560, 70), 92, _toggle_sprint)
	_skill_button(layer, "jump", "Saut", C + Vector2(-450, 70), 92, hero.jump)
	_build_menu(layer)
	_build_hint_ui(layer)
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
	dlg_panel.grow_horizontal = Control.GROW_DIRECTION_BOTH
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
	load_lbl = Label.new()
	load_lbl.set_anchors_preset(Control.PRESET_FULL_RECT)
	load_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	load_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	load_lbl.add_theme_font_size_override("font_size", 34)
	load_lbl.add_theme_color_override("font_color", Color(0.75, 0.65, 1.0))
	load_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
	load_lbl.visible = false
	layer.add_child(load_lbl)

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

## Qualité graphique : « Rapide » coupe ombres, glow et anticrénelage (gros gain sur téléphone).
func _toggle_gfx() -> void:
	set_gfx(not gfx_fast)
	_save_settings()

func set_gfx(fast: bool) -> void:
	gfx_fast = fast
	moon.shadow_enabled = not fast
	for e in [env_city, env_dun, env_hall, env_shop]:
		if e:
			(e as Environment).glow_enabled = not fast
	get_viewport().msaa_3d = Viewport.MSAA_DISABLED if fast else Viewport.MSAA_2X
	if gfx_btn:
		gfx_btn.text = "        Graphismes : " + ("Rapide" if fast else "Haute")

func _save_settings() -> void:
	var f := FileAccess.open("user://reglages.json", FileAccess.WRITE)
	if f:
		f.store_string(JSON.stringify({"fast": gfx_fast}))

func _load_settings() -> void:
	if not FileAccess.file_exists("user://reglages.json"):
		return
	var d = JSON.parse_string(FileAccess.get_file_as_string("user://reglages.json"))
	if d is Dictionary:
		set_gfx(bool(d.get("fast", false)))

func _toggle_qtrack() -> void:
	qtrack_open = not qtrack_open
	sfx("click", null, -10.0)

# ================================================================ conseils (une seule fois chacun, discrets)
const HINTS := {
	"run": "Donjon à salles : élimine toutes les meutes pour ouvrir le passage. Les monstres lâchent des JETONS, à échanger chez le Changeur (bureau au fond de la boutique).",
	"office": "Le Changeur échange tes jetons de donjon contre des améliorations d'arme, d'ombres et des objets uniques.",
	"anomaly": "Chef ANORMAL : il frappe plusieurs fois plus fort. Garde tes esquives, laisse tes ombres encaisser. Mourir = sortir du donjon.",
	"start": "Ta quête du jour est en haut à gauche. Le menu couronne (en haut à droite) ouvre le sac, les ombres et le guide.",
	"combat": "Touche l'épée pour attaquer. ESQUIVE juste avant un coup = esquive parfaite et contre-attaque.",
	"kill": "Approche-toi du corps et touche ARISE : le monstre devient ton ombre.",
	"shadow": "Tes ombres te suivent. « À l'attaque » les envoie au combat, « Restez » les garde derrière toi.",
	"red": "Zone ROUGE au sol : une attaque arrive. Sors-en !",
	"green": "Zone VERTE : un soin. Reste dedans.",
	"yellow": "Flaque JAUNE : poison. Ne reste pas dedans.",
	"loot": "Un rayon de couleur marque un objet : passe dessus. La couleur indique le rang (gris → rose).",
	"bag": "Flèche verte ▲ = meilleur que ce que tu portes. « Équiper le meilleur » fait tout pour toi.",
	"chase": "Un civil est poursuivi : rejoins-le et abats ses poursuivants avant qu'ils ne l'attrapent.",
	"wall": "Cours droit contre un mur pour l'escalader. SAUT contre un mur pour rebondir.",
	"gate": "Portail gardé : il faut 30 de réputation (ou négocier avec les gardes).",
	"tele": "Choisis vite : Éjecter, Écraser ou Étrangler. Sans choix, la cible est écrasée.",
	"level": "Niveau supérieur ! Dépense tes points dans STATS (menu couronne).",
	"shop": "Boutique : potions, renforcement des ombres, affûtage. Les prix baissent avec ta réputation.",
}
var hints_seen := {}
var hint_panel: PanelContainer
var hint_lbl: Label
var hint_q: Array = []

func hint(id: String) -> void:
	if id == "" or hints_seen.has(id) or not HINTS.has(id) or shots_mode and id != "combat":
		return
	hints_seen[id] = true
	hint_q.append(str(HINTS[id]))
	if hint_q.size() == 1:
		_show_next_hint()

func _show_next_hint() -> void:
	if hint_q.is_empty() or hint_panel == null:
		return
	hint_lbl.text = hint_q[0]
	hint_panel.visible = true
	hint_panel.modulate.a = 0.0
	var tw := create_tween()
	tw.tween_property(hint_panel, "modulate:a", 1.0, 0.25)
	tw.tween_interval(clampf(float(str(hint_q[0]).length()) / 18.0, 3.0, 6.0))
	tw.tween_property(hint_panel, "modulate:a", 0.0, 0.4)
	tw.tween_callback(_hint_done)

func _hint_done() -> void:
	hint_panel.visible = false
	if not hint_q.is_empty():
		hint_q.remove_at(0)
	_show_next_hint()

func _build_hint_ui(layer: CanvasLayer) -> void:
	hint_panel = PanelContainer.new()
	hint_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.08, 0.06, 0.02, 0.85), Color(1, 0.8, 0.35, 0.8)))
	hint_panel.anchor_left = 0.5
	hint_panel.anchor_right = 0.5
	hint_panel.anchor_top = 1.0
	hint_panel.anchor_bottom = 1.0
	hint_panel.offset_left = -330
	hint_panel.offset_right = 230
	hint_panel.offset_top = -420
	hint_panel.offset_bottom = -370
	hint_panel.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hint_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_panel.visible = false
	layer.add_child(hint_panel)
	var hb := HBoxContainer.new()
	hb.add_theme_constant_override("separation", 8)
	hint_panel.add_child(hb)
	var ic := TextureRect.new()
	ic.texture = load("res://assets/ui/guide.png")
	ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ic.custom_minimum_size = Vector2(36, 36)
	hb.add_child(ic)
	hint_lbl = Label.new()
	hint_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint_lbl.custom_minimum_size = Vector2(500, 0)
	hint_lbl.add_theme_font_size_override("font_size", 17)
	hint_lbl.add_theme_color_override("font_color", Color(1, 0.93, 0.75))
	hb.add_child(hint_lbl)

func _guide_ui() -> void:
	var rows := [
		["attack", "Attaque", "Combo d'épée. En l'air : frappe plongeante. La vitesse dépend de ton arme."],
		["roll", "Esquive", "Roulade invulnérable. Juste avant un coup : esquive parfaite, ralenti et contre-attaque x2,5."],
		["step", "Pas de l'ombre", "Téléportation dans le dos de plusieurs ennemis du domaine, avec un coup à chacun."],
		["tele", "Télékinésie", "Soulève les ennemis devant toi, puis Éjecter, Écraser ou Étrangler."],
		["arise", "Arise", "Relève les cadavres proches en ombres. Plus le monstre est fort, plus l'ombre est forte."],
		["cmd_attack", "À l'attaque", "Envoie l'armée : tanks devant, lames sur les flancs, mages et soigneurs derrière."],
		["cmd_stay", "Restez", "Les ombres restent derrière toi et t'encouragent."],
		["sprint", "Sprint", "Course rapide (ou pousse le joystick à fond). Contre un mur : escalade."],
		["q_run", "Quête du jour", "Courir, vaincre, escalader, utiliser tes pouvoirs. Récompense : points, or, soins."],
		["role_tank", "Rangs E → S", "Plus le rang est haut, plus c'est fort. Ombres, objets et monstres suivent le même code couleur."],
		["cash", "Billets", "Améliorer l'équipement, potions, boutique."],
		["essence", "Essences", "Améliorer et faire monter de rang tes ombres, démanteler rend des essences."],
	]
	menu_body.add_child(_lbl("Zones au sol : ROUGE = attaque ennemie (sors-en) · VERT = soin · JAUNE = poison", 16, Color(1, 0.8, 0.5)))
	for r in rows:
		var hb := HBoxContainer.new()
		hb.add_theme_constant_override("separation", 10)
		var ic := TextureRect.new()
		ic.texture = load("res://assets/ui/%s.png" % r[0])
		ic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ic.custom_minimum_size = Vector2(44, 44)
		hb.add_child(ic)
		var vb := VBoxContainer.new()
		vb.add_child(_lbl(str(r[1]), 17, Color(1, 0.88, 0.6)))
		var d := _lbl(str(r[2]), 14, Color(0.82, 0.86, 1))
		d.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		d.custom_minimum_size = Vector2(900, 0)
		vb.add_child(d)
		hb.add_child(vb)
		menu_body.add_child(hb)

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
	for k in [["quest", "Quête du jour", ""], ["sac", "Sac", "sac"], ["grimoire", "Grimoire", "grimoire"], ["ombres", "Ombres", "ombres"], ["stats", "Statistiques", "stats"], ["unarmed", "Mains nues", ""], ["guide", "Guide", "guide"], ["gfx", "Graphismes : Haute", ""], ["diag", "Diagnostic", ""], ["bench", "Test de performance", ""]]:
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
		elif str(k[0]) == "gfx":
			row.pressed.connect(_toggle_gfx)
			gfx_btn = row
		elif str(k[0]) == "diag":
			row.pressed.connect(_toggle_diag)
		elif str(k[0]) == "bench":
			row.pressed.connect(_start_bench)
		else:
			row.pressed.connect(_quick_open.bind(str(k[2])))
		quick_menu.add_child(row)
	buttons["quick"] = {"btn": qp, "shade": null, "label": null}
	menu_panel = PanelContainer.new()
	menu_panel.add_theme_stylebox_override("panel", _panel_style(Color(0.02, 0.03, 0.1, 0.88), Color(0.5, 0.35, 1.0)))
	menu_panel.anchor_left = 0.5
	menu_panel.anchor_right = 0.5
	menu_panel.anchor_bottom = 1.0
	menu_panel.offset_left = -600
	menu_panel.offset_right = 600
	menu_panel.offset_top = 14
	menu_panel.offset_bottom = -14
	menu_panel.visible = false
	layer.add_child(menu_panel)
	var mroot := VBoxContainer.new()
	mroot.add_theme_constant_override("separation", 6)
	menu_panel.add_child(mroot)
	var head := HBoxContainer.new()
	head.add_theme_constant_override("separation", 10)
	mroot.add_child(head)
	menu_icon = TextureRect.new()
	menu_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	menu_icon.custom_minimum_size = Vector2(44, 44)
	head.add_child(menu_icon)
	menu_title = _lbl("", 26, Color(1, 0.88, 0.6))
	menu_title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(menu_title)
	menu_chips = HBoxContainer.new()
	menu_chips.add_theme_constant_override("separation", 14)
	head.add_child(menu_chips)
	var xb := _icon_btn("close", 46)
	xb.custom_minimum_size = Vector2(46, 46)
	xb.pressed.connect(_close_menu)
	head.add_child(xb)
	menu_scroll = ScrollContainer.new()
	menu_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	menu_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	mroot.add_child(menu_scroll)
	menu_body = VBoxContainer.new()
	menu_body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	menu_body.add_theme_constant_override("separation", 8)
	menu_scroll.add_child(menu_body)
	menu_split = HBoxContainer.new()
	menu_split.size_flags_vertical = Control.SIZE_EXPAND_FILL
	menu_split.add_theme_constant_override("separation", 12)
	mroot.add_child(menu_split)
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
	if tab == "sac":
		hint("bag")
	_refresh_menu()

func _close_menu() -> void:
	menu_panel.visible = false
	sfx("click", null, -8.0)

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
	for c in menu_split.get_children():
		c.queue_free()
	for c in menu_chips.get_children():
		c.queue_free()
	var titles := {"guide": ["Guide du chasseur", "guide"], "sac": ["Inventaire", "sac"], "ombres": ["Armée d'ombres", "ombres"], "grimoire": ["Grimoire des pouvoirs", "grimoire"], "stats": ["Chasseur", "stats"]}
	var t: Array = titles.get(menu_tab, ["", "menu"])
	menu_title.text = str(t[0])
	menu_icon.texture = load("res://assets/ui/%s.png" % str(t[1]))
	menu_chips.add_child(UICards.chip(CASH_TEX, str(gold), Color(0.6, 1, 0.6), 26))
	menu_chips.add_child(UICards.chip(ESS_TEX, str(essence), Color(0.85, 0.7, 1), 26))
	for tk in ["orc", "goblin"]:
		if int(tokens[tk]) > 0:
			menu_chips.add_child(UICards.chip(TOK_TEX[tk], str(tokens[tk]), Color(1, 0.85, 0.4), 26))
	var split := menu_tab == "sac" or menu_tab == "ombres"
	menu_scroll.visible = not split
	menu_split.visible = split
	if menu_tab == "ombres":
		_shadows_ui()
		return
	if menu_tab == "ombres_old":
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
		_bag_ui()
	elif menu_tab == "guide":
		_guide_ui()
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
		var nt := rep_next()
		menu_body.add_child(_lbl("RÉPUTATION %d — %s%s" % [rep, rep_title(), ("   (prochain palier : %d)" % nt) if nt > 0 else ""], 18, Color(1, 0.85, 0.45)))
		menu_body.add_child(_lbl("Avantages : %s\nRaids : réputation 150 requise — bientôt." % rep_perks(), 15, Color(0.8, 0.85, 1)))
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

# ================================================================ SAC (façon UMBRA)
func _item_card(it: Dictionary, small := false) -> Button:
	var rk := Items.rarity(it)
	var b := Items.base_of(it)
	var sub := ""
	if not small:
		if it["t"] == "w":
			sub = "⚔ x%.2f" % float(Items.weapon_of(it)["mult"])
		elif Items.lv(it) > 0:
			sub = "Niv. %d" % Items.lv(it)
		else:
			sub = Items.RAR[rk]["n"]
	if Items.stars(it) > 0 and not small:
		sub = "★".repeat(Items.stars(it)) + "  " + sub
	var w := 70.0 if small else 108.0
	var c := UICards.card(Items.icon(it), UICards.rar_color(rk), str(Items.RAR[rk]["k"]), "" if small else str(b["n"]), sub, is_equipped(int(it["uid"])) and not small, int(it["uid"]) == inv_sel, null, -1.0, w, 86.0 if small else 138.0)
	c.pressed.connect(_select_item.bind(int(it["uid"])))
	if small:
		return c
	# flèche : meilleur (vert) / moins bon (rouge) que ce que tu portes
	var cmp := _cmp(it)
	if cmp != 0:
		var ar := Label.new()
		ar.text = "▲" if cmp > 0 else "▼"
		ar.add_theme_font_size_override("font_size", 22)
		ar.add_theme_color_override("font_color", Color(0.3, 1, 0.4) if cmp > 0 else Color(1, 0.35, 0.3))
		ar.add_theme_constant_override("outline_size", 6)
		ar.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		ar.position = Vector2(w - 26, 52)
		ar.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(ar)
	if bool(it.get("lock", false)):
		var lk := TextureRect.new()
		lk.texture = load("res://assets/ui/lock.png")
		lk.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		lk.position = Vector2(6, 52)
		lk.size = Vector2(22, 22)
		lk.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(lk)
	if bool(it.get("new", false)):
		var dot := Panel.new()
		var ds := StyleBoxFlat.new()
		ds.bg_color = Color(1, 0.2, 0.25)
		ds.set_corner_radius_all(6)
		dot.add_theme_stylebox_override("panel", ds)
		dot.position = Vector2(w - 16, 4)
		dot.size = Vector2(12, 12)
		dot.mouse_filter = Control.MOUSE_FILTER_IGNORE
		c.add_child(dot)
	return c

func _bag_ui() -> void:
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	menu_split.add_child(left)
	# équipement porté : arme, reliques, tête, cape, plastron, bottes
	var load_row := HBoxContainer.new()
	load_row.add_theme_constant_override("separation", 6)
	left.add_child(load_row)
	var slots: Array = [["w", "Arme"]]
	for i in relic_slots():
		slots.append(["r%d" % i, "Relique"])
	for sl in Items.SLOTS:
		slots.append([sl[0], sl[1]])
	for sl in slots:
		var uid := -1
		var key: String = sl[0]
		if key == "w":
			uid = equip["w"]
		elif key.begins_with("r") and key.length() == 2:
			var rl: Array = equip["r"]
			var ri := int(key.substr(1))
			uid = rl[ri] if ri < rl.size() else -1
		else:
			uid = equip[key]
		var it := item_by_uid(uid) if uid >= 0 else {}
		var vb := VBoxContainer.new()
		vb.add_theme_constant_override("separation", 0)
		vb.add_child(_item_card(it, true) if not it.is_empty() else UICards.empty_slot(str(sl[1])))
		var cap := _lbl(str(sl[1]), 11, Color(0.6, 0.65, 0.8))
		cap.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		vb.add_child(cap)
		load_row.add_child(vb)
	# onglets
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 8)
	left.add_child(tabs)
	for f in [["tab_w", "Armes", "w"], ["tab_r", "Reliques", "r"], ["tab_a", "Équipement", "a"]]:
		var n := 0
		for it in inv:
			if it["t"] == f[2]:
				n += 1
		var tb := _small_btn("      %s  (%d)" % [f[1], n])
		tb.custom_minimum_size = Vector2(170, 40)
		if inv_filter == f[2]:
			tb.add_theme_color_override("font_color", Color(1, 0.9, 0.55))
			var sp: StyleBoxFlat = (tb.get_theme_stylebox("normal") as StyleBoxFlat).duplicate()
			sp.bg_color = Color(0.25, 0.15, 0.45, 0.95)
			sp.border_color = Color(1, 0.8, 0.4)
			tb.add_theme_stylebox_override("normal", sp)
		var ti := TextureRect.new()
		ti.texture = load("res://assets/ui/%s.png" % f[0])
		ti.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		ti.position = Vector2(6, 4)
		ti.size = Vector2(32, 32)
		ti.mouse_filter = Control.MOUSE_FILTER_IGNORE
		tb.add_child(ti)
		tb.pressed.connect(_set_filter.bind(str(f[2])))
		tabs.add_child(tb)
	# tri + actions rapides
	var tools := HBoxContainer.new()
	tools.add_theme_constant_override("separation", 8)
	left.add_child(tools)
	for so in [["power", "Puissance"], ["rank", "Rang"], ["new", "Récents"]]:
		var sb2 := _small_btn(("» " if bag_sort == so[0] else "") + str(so[1]))
		sb2.pressed.connect(_sort_bag.bind(str(so[0])))
		tools.add_child(sb2)
	for ac in [["best", "Équiper le meilleur", _equip_best], ["clean", "Nettoyer (%d)" % _junk_list().size(), _clean_bag]]:
		var abt := _small_btn("      " + str(ac[1]))
		var aic := TextureRect.new()
		aic.texture = load("res://assets/ui/%s.png" % ac[0])
		aic.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		aic.position = Vector2(6, 3)
		aic.size = Vector2(28, 28)
		aic.mouse_filter = Control.MOUSE_FILTER_IGNORE
		abt.add_child(aic)
		abt.pressed.connect(ac[2])
		tools.add_child(abt)
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var list: Array = []
	for it in inv:
		if it["t"] == inv_filter:
			list.append(it)
	match bag_sort:
		"rank":
			list.sort_custom(func(a, b): return Items.rarity(a) * 1000 + Items.power(a) > Items.rarity(b) * 1000 + Items.power(b))
		"new":
			list.sort_custom(func(a, b): return int(a["uid"]) > int(b["uid"]))
		_:
			list.sort_custom(func(a, b): return Items.power(a) > Items.power(b))
	for it in list:
		grid.add_child(_item_card(it))
	if list.is_empty():
		left.add_child(_lbl("Rien ici pour l'instant. Monstres, coffres d'élite et boss lâchent du butin : un rayon de lumière de la couleur du rang marque l'objet au sol.", 15, Color(0.7, 0.75, 0.9)))
	# détail à droite
	var det := PanelContainer.new()
	det.custom_minimum_size = Vector2(330, 0)
	det.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.09, 0.9), Color(0.35, 0.3, 0.6)))
	menu_split.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	det.add_child(dv)
	var sel := item_by_uid(inv_sel)
	if sel.is_empty() and not list.is_empty():
		sel = list[0]
		inv_sel = int(sel["uid"])
	if sel.is_empty():
		dv.add_child(_lbl("Sélectionne un objet.", 16))
		return
	var rk := Items.rarity(sel)
	var col := UICards.rar_color(rk)
	var cc := CenterContainer.new()
	cc.add_child(UICards.card(Items.icon(sel), col, str(Items.RAR[rk]["k"]), "", "", false, true, null, -1.0, 150.0, 150.0))
	dv.add_child(cc)
	var nm := _lbl(str(Items.base_of(sel)["n"]), 21, col.lightened(0.25))
	nm.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dv.add_child(nm)
	dv.add_child(_lbl("Rang %s — %s   ·   Niveau %d / 10" % [Items.RAR[rk]["k"], Items.RAR[rk]["n"], Items.lv(sel)], 14, col))
	var ds := _lbl(Items.describe(sel), 14, Color(0.85, 0.88, 1))
	ds.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ds.custom_minimum_size = Vector2(300, 0)
	dv.add_child(ds)
	# comparaison chiffrée avec l'équipement porté
	if not is_equipped(inv_sel):
		var sp := _slot_power(sel)
		var mine := Items.power(sel)
		if sp <= 0.0:
			dv.add_child(_lbl("▲ Emplacement libre : équipe-le !", 15, Color(0.4, 1, 0.5)))
		else:
			var pct := (mine - sp) / sp * 100.0
			dv.add_child(_lbl("%s Puissance %s%d %% par rapport à ton équipement" % ["▲" if pct >= 0 else "▼", "+" if pct >= 0 else "", int(pct)], 15, Color(0.4, 1, 0.5) if pct >= 0 else Color(1, 0.45, 0.4)))
	else:
		dv.add_child(_lbl("✓ Porté actuellement", 15, Color(0.5, 0.9, 1)))
	var eqd := is_equipped(inv_sel)
	var row0 := HBoxContainer.new()
	var be := _small_btn("RETIRER" if eqd else "ÉQUIPER")
	be.pressed.connect(_toggle_equip.bind(inv_sel))
	be.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row0.add_child(be)
	var lb2 := _small_btn("DÉVERROUILLER" if bool(sel.get("lock", false)) else "VERROUILLER")
	lb2.pressed.connect(_toggle_lock.bind(inv_sel))
	row0.add_child(lb2)
	dv.add_child(row0)
	var dn := _dupes(sel).size()
	if dn >= 1 and Items.stars(sel) < 5:
		var fb := _small_btn("FUSIONNER (%d / 3 identiques)  →  ★%d" % [mini(dn + 1, 3), Items.stars(sel) + 1])
		fb.disabled = dn < 2
		fb.pressed.connect(_fuse.bind(inv_sel))
		dv.add_child(fb)
	if Items.lv(sel) < 10:
		var cost := Items.upgrade_cost(sel)
		var ub := _small_btn("AMÉLIORER  →  Niv. %d" % (Items.lv(sel) + 1))
		ub.pressed.connect(_upgrade_item.bind(inv_sel))
		dv.add_child(ub)
		var cr := HBoxContainer.new()
		cr.add_theme_constant_override("separation", 12)
		cr.add_child(UICards.chip(CASH_TEX, str(cost[0]), Color(0.6, 1, 0.6) if gold >= int(cost[0]) else Color(1, 0.45, 0.4), 22))
		cr.add_child(UICards.chip(ESS_TEX, str(cost[1]), Color(0.85, 0.7, 1) if essence >= int(cost[1]) else Color(1, 0.45, 0.4), 22))
		dv.add_child(cr)
	var ar := HBoxContainer.new()
	var bs := _small_btn("VENDRE")
	bs.pressed.connect(_remove_sel.bind(true))
	ar.add_child(bs)
	ar.add_child(UICards.chip(CASH_TEX, "+%d" % Items.sell_price(sel), Color(0.6, 1, 0.6), 20))
	var bd := _small_btn("DÉMANTELER")
	bd.pressed.connect(_remove_sel.bind(false))
	ar.add_child(bd)
	ar.add_child(UICards.chip(ESS_TEX, "+%d" % Items.dismantle_value(sel), Color(0.85, 0.7, 1), 20))
	dv.add_child(ar)

func _upgrade_item(uid: int) -> void:
	var it := item_by_uid(uid)
	if it.is_empty() or Items.lv(it) >= 10:
		return
	var cost := Items.upgrade_cost(it)
	if gold < int(cost[0]) or essence < int(cost[1]):
		sfx("error")
		system_msg("Pas assez d'or ou d'essences.")
		return
	gold -= int(cost[0])
	essence -= int(cost[1])
	it["lv"] = Items.lv(it) + 1
	sfx("levelup")
	FX.burst(self, hero.global_position + Vector3(0, 1.2, 0), UICards.rar_color(Items.rarity(it)), 30, 0.08, 3.0, 0.7, -1.0)
	recalc_gear()
	save_game()
	_refresh_menu()

# ================================================================ OMBRES (façon UMBRA)
const ROLE_TEX := {"tank": "role_tank", "heal": "role_heal", "fire": "role_fire", "melee": "role_melee"}
const ROLE_DESC := {"tank": "Se place devant toi, provoque les monstres et encaisse.", "heal": "Reste en retrait et soigne toi et tes ombres quand c'est nécessaire.", "fire": "Ligne arrière : boules de feu et pluie de feu.", "melee": "Contourne les ennemis et frappe dans le dos."}

func _shadow_portrait(m: Mob) -> Texture2D:
	var k := m.kind
	if m.boss:
		k = "igris"
	var p := "res://assets/ui/items/sh_%s.png" % k
	if ResourceLoader.exists(p):
		return load(p)
	return load("res://assets/ui/ombres.png")

func _shadow_card(m: Mob, big := false) -> Button:
	var col := UICards.grade_color(m.grade)
	var short := str({"goblin": "Gobelin", "shaman": "Chaman", "orc": "Orc", "orc_warrior": "Orc guerrier", "igris": "Igris"}.get(m.kind, m.kind))
	var c := UICards.card(_shadow_portrait(m), col, Mob.GRADES[m.grade], "" if big else short, "" if big else "⚔ %d  Niv.%d" % [int(m.dmg), m.slv], false, m == sh_sel and not big, load("res://assets/ui/%s.png" % ROLE_TEX.get(m.role, "role_melee")), m.hp / maxf(m.max_hp, 1.0), 150.0 if big else 108.0, 160.0 if big else 138.0)
	if not big:
		c.pressed.connect(_select_shadow.bind(m))
	return c

func _shadows_ui() -> void:
	var sh := shadow_list()
	var left := VBoxContainer.new()
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	left.add_theme_constant_override("separation", 8)
	menu_split.add_child(left)
	var top := HBoxContainer.new()
	top.add_theme_constant_override("separation", 14)
	left.add_child(top)
	top.add_child(_lbl("Armée %d / %d" % [sh.size(), hero.max_shadows()], 18, Color(0.85, 0.7, 1)))
	var counts := {"tank": 0, "heal": 0, "fire": 0, "melee": 0}
	for m in sh:
		counts[(m as Mob).role] = int(counts.get((m as Mob).role, 0)) + 1
	for r in ["tank", "heal", "fire", "melee"]:
		top.add_child(UICards.chip(load("res://assets/ui/%s.png" % ROLE_TEX[r]), str(counts[r]), Color(1, 1, 1), 26))
	top.add_child(_lbl("Domaine %d m" % int(hero.domain_r()), 15, Color(0.7, 0.75, 0.9)))
	var sc := ScrollContainer.new()
	sc.size_flags_vertical = Control.SIZE_EXPAND_FILL
	sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	left.add_child(sc)
	var grid := GridContainer.new()
	grid.columns = 6
	grid.add_theme_constant_override("h_separation", 8)
	grid.add_theme_constant_override("v_separation", 8)
	sc.add_child(grid)
	var ordered := sh.duplicate()
	ordered.sort_custom(func(a, b): return (a as Mob).grade * 100 + (a as Mob).slv > (b as Mob).grade * 100 + (b as Mob).slv)
	for m in ordered:
		grid.add_child(_shadow_card(m as Mob))
	for k in maxi(hero.max_shadows() - sh.size(), 0):
		grid.add_child(UICards.empty_slot("Place libre\nARISE", 108, 138))
	if sh.is_empty():
		left.add_child(_lbl("Aucune ombre. Abats un monstre, puis utilise ARISE près de son corps pour en faire ton soldat.", 15, Color(0.7, 0.75, 0.9)))
	var det := PanelContainer.new()
	det.custom_minimum_size = Vector2(330, 0)
	det.add_theme_stylebox_override("panel", _panel_style(Color(0.03, 0.03, 0.09, 0.9), Color(0.35, 0.3, 0.6)))
	menu_split.add_child(det)
	var dv := VBoxContainer.new()
	dv.add_theme_constant_override("separation", 6)
	det.add_child(dv)
	if sh_sel == null or not is_instance_valid(sh_sel) or not sh.has(sh_sel):
		sh_sel = ordered[0] if not ordered.is_empty() else null
	if sh_sel == null:
		dv.add_child(_lbl("Sélectionne une ombre.", 16))
		return
	var m := sh_sel
	var col := UICards.grade_color(m.grade)
	var cc := CenterContainer.new()
	cc.add_child(_shadow_card(m, true))
	dv.add_child(cc)
	dv.add_child(_lbl(m.display_name, 19, col.lightened(0.25)))
	dv.add_child(_lbl("Rang %s   ·   Niveau %d / 10   ·   %s" % [Mob.GRADES[m.grade], m.slv, Mob.ROLE_NAME.get(m.role, m.role)], 14, col))
	var rd := _lbl(str(ROLE_DESC.get(m.role, "")), 13, Color(0.75, 0.8, 0.95))
	rd.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rd.custom_minimum_size = Vector2(300, 0)
	dv.add_child(rd)
	var extra := ""
	match m.role:
		"tank":
			extra = "Provocation réussie : %d %%" % int(Mob.TAUNT_P[m.grade] * 100)
		"heal":
			extra = "Soin de zone : %.1f %% PV toutes les 0,5 s" % (Mob.HEAL_PCT[m.grade] * 100.0)
	dv.add_child(_lbl("PV %d / %d     Dégâts %d\n%s" % [int(m.hp), int(m.max_hp), int(m.dmg), extra], 15, Color(0.9, 0.92, 1)))
	var orow := HBoxContainer.new()
	for o in [["Auto", "auto"], ["Suivre", "follow"], ["Tenir", "hold"], ["Cible", "attack"]]:
		var ob := _small_btn(str(o[0]))
		if m.order == o[1]:
			ob.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
		ob.pressed.connect(_shadow_order.bind(m, str(o[1])))
		orow.add_child(ob)
	dv.add_child(orow)
	if m.slv < 10:
		var ub := _small_btn("AMÉLIORER  →  Niv. %d%s" % [m.slv + 1, "  (rang ↑)" if (m.slv + 1) % 5 == 0 else ""])
		ub.pressed.connect(_upgrade_shadow.bind(m))
		dv.add_child(ub)
		dv.add_child(UICards.chip(ESS_TEX, str(_shadow_cost(m)), Color(0.85, 0.7, 1) if essence >= _shadow_cost(m) else Color(1, 0.45, 0.4), 22))
	var rb := _small_btn("LIBÉRER L'OMBRE")
	rb.pressed.connect(_release_shadow.bind(m))
	dv.add_child(rb)
	dv.add_child(UICards.chip(ESS_TEX, "+%d" % (2 + m.grade * 2 + m.slv), Color(0.85, 0.7, 1), 18))

func _select_shadow(m: Mob) -> void:
	sh_sel = m
	sfx("select", null, -8.0)
	_refresh_menu()

func _shadow_order(m: Mob, o: String) -> void:
	m.order = o
	m.hold_pos = m.global_position
	m.target = null
	sfx("click", null, -8.0)
	_refresh_menu()

func _shadow_cost(m: Mob) -> int:
	return 2 + m.slv * 2 + m.grade * 2

func _upgrade_shadow(m: Mob) -> void:
	var c := _shadow_cost(m)
	if essence < c or m.slv >= 10:
		sfx("error")
		system_msg("Pas assez d'essences.")
		return
	essence -= c
	m.level_up()
	sfx("levelup")
	FX.arise_pillar(self, m.global_position)
	save_game()
	_refresh_menu()

func _release_shadow(m: Mob) -> void:
	essence += 2 + m.grade * 2 + m.slv
	FX.shadow_puff(self, m.global_position)
	sfx("shadow")
	mobs.erase(m)
	m.queue_free()
	sh_sel = null
	save_game()
	_refresh_menu()

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

## Puissance de ce qui est porté dans l'emplacement qu'occuperait cet objet.
func _slot_power(it: Dictionary) -> float:
	match str(it["t"]):
		"w":
			return Items.power(item_by_uid(equip["w"]))
		"r":
			var rl: Array = equip["r"]
			if rl.size() < relic_slots():
				return 0.0
			var worst := 1e9
			for u in rl:
				worst = minf(worst, Items.power(item_by_uid(int(u))))
			return worst
		_:
			return Items.power(item_by_uid(equip[str(Items.base_of(it)["slot"])]))

## +1 meilleur, -1 moins bon, 0 équivalent ou déjà porté.
func _cmp(it: Dictionary) -> int:
	if is_equipped(int(it["uid"])):
		return 0
	var d := Items.power(it) - _slot_power(it)
	if d > 0.5:
		return 1
	if d < -0.5:
		return -1
	return 0

func _sort_bag(mode: String) -> void:
	bag_sort = mode
	sfx("click", null, -8.0)
	_refresh_menu()

## Équipe automatiquement le meilleur objet de chaque emplacement.
func _equip_best() -> void:
	var best_w: Dictionary = {}
	var best_a := {}
	var relics: Array = []
	for it in inv:
		match str(it["t"]):
			"w":
				if best_w.is_empty() or Items.power(it) > Items.power(best_w):
					best_w = it
			"a":
				var sl := str(Items.base_of(it)["slot"])
				if not best_a.has(sl) or Items.power(it) > Items.power(best_a[sl]):
					best_a[sl] = it
			"r":
				relics.append(it)
	if not best_w.is_empty():
		equip["w"] = int(best_w["uid"])
	for sl in best_a.keys():
		equip[sl] = int(best_a[sl]["uid"])
	relics.sort_custom(func(a, b): return Items.power(a) > Items.power(b))
	var seen := {}
	var rl: Array = []
	for r in relics:
		if rl.size() >= relic_slots():
			break
		if seen.has(r["id"]):
			continue
		seen[r["id"]] = true
		rl.append(int(r["uid"]))
	equip["r"] = rl
	recalc_gear()
	sfx("draw")
	system_msg("Meilleur équipement porté.")
	save_game()
	_refresh_menu()

## Objets qu'on peut démanteler sans rien perdre : ni équipés, ni verrouillés, et moins bons que ce qu'on porte.
func _junk_list() -> Array:
	var out: Array = []
	for it in inv:
		if is_equipped(int(it["uid"])) or bool(it.get("lock", false)):
			continue
		if _cmp(it) < 0:
			out.append(it)
	return out

func _clean_bag() -> void:
	var j := _junk_list()
	if j.is_empty():
		system_msg("Rien à nettoyer : tout est utile ou verrouillé.")
		return
	var ess := 0
	for it in j:
		ess += Items.dismantle_value(it)
	dialogue("Nettoyer le sac", "Démanteler %d objet(s) moins bons que ton équipement (non verrouillés) ?\nTu récupères %d essences." % [j.size(), ess], [
		["Oui, démanteler", _clean_confirm],
		["Annuler", close_dialogue],
	])

func _clean_confirm() -> void:
	var j := _junk_list()
	for it in j:
		essence += Items.dismantle_value(it)
		inv.erase(it)
	close_dialogue()
	sfx("shadow")
	system_msg("%d objets démantelés." % j.size())
	inv_sel = -1
	save_game()
	if menu_panel.visible:
		_refresh_menu()

func _toggle_lock(uid: int) -> void:
	var it := item_by_uid(uid)
	if it.is_empty():
		return
	it["lock"] = not bool(it.get("lock", false))
	sfx("click", null, -6.0)
	_refresh_menu()

func _dupes(it: Dictionary) -> Array:
	var out: Array = []
	for o in inv:
		if o != it and o["id"] == it["id"] and Items.stars(o) == Items.stars(it) and not is_equipped(int(o["uid"])) and not bool(o.get("lock", false)):
			out.append(o)
	return out

## Fusion : 3 exemplaires identiques → 1 exemplaire avec une étoile de plus (+15 % de stats).
func _fuse(uid: int) -> void:
	var it := item_by_uid(uid)
	var d := _dupes(it)
	if it.is_empty() or d.size() < 2 or Items.stars(it) >= 5:
		sfx("error")
		return
	inv.erase(d[0])
	inv.erase(d[1])
	it["star"] = Items.stars(it) + 1
	sfx("levelup")
	FX.arise_pillar(self, hero.global_position)
	system_msg("Fusion réussie : %s ★%d" % [Items.base_of(it)["n"], Items.stars(it)])
	recalc_gear()
	save_game()
	_refresh_menu()

func _set_filter(f: String) -> void:
	inv_filter = f
	inv_sel = -1
	sfx("click", null, -8.0)
	_refresh_menu()

func _select_item(uid: int) -> void:
	inv_sel = uid
	var it := item_by_uid(uid)
	if not it.is_empty():
		it.erase("new")
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
	if bool(item_by_uid(inv_sel).get("lock", false)):
		sfx("error")
		system_msg("Objet verrouillé : déverrouille-le d'abord.")
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
	var hud_on := not in_dialogue and not (menu_panel and menu_panel.visible)
	for k in ["attack", "roll", "step", "tele", "arise", "potion", "sprint", "jump"]:
		(buttons[k]["btn"] as Control).visible = hud_on
	var has_sh := shadow_count() > 0
	(buttons["cmd_attack"]["btn"] as Control).visible = has_sh and hud_on
	(buttons["cmd_stay"]["btn"] as Control).visible = has_sh and hud_on
	(buttons["cmd_attack"]["btn"] as Control).modulate = Color(1.3, 1.2, 1.2) if army_mode == "attack" else Color(1, 1, 1)
	(buttons["cmd_stay"]["btn"] as Control).modulate = Color(1.2, 1.2, 1.4) if army_mode == "stay" else Color(1, 1, 1)
	(buttons["swap"]["btn"] as Button).visible = hero.powers["swap"] > 0 and hud_on
	potion_btn.modulate = Color(1, 1, 1, 1.0 if potions > 0 and potion_cd <= 0.0 else 0.45)
	shadow_txt.text = "Ombres  %d / 4" % shadow_count()
	fps_lbl.text = "%d FPS" % Engine.get_frames_per_second()
	if diag_on:
		diag_t -= get_process_delta_time()
		if diag_t <= 0.0:
			diag_t = 0.5
			_update_diag()
	cash_lbl.text = str(gold)
	for g in qrows.keys():
		var goal: Array = QUEST_GOALS[g]
		var v := minf(float(quest.get(g, 0.0)), float(goal[0]))
		var done := v >= float(goal[0])
		var r: Array = qrows[g]
		(r[0] as Label).text = "%s  %d / %d %s%s" % [goal[1], int(v), int(goal[0]), goal[2], "  ✓" if done else ""]
		(r[0] as Label).add_theme_color_override("font_color", Color(0.5, 1, 0.6) if done else Color(0.85, 0.9, 1))
		(r[1] as ProgressBar).value = v / float(goal[0]) * 100.0
		(r[2] as Control).visible = qtrack_open
	qpanel.visible = zone == "city" and not quest.get("done", false) and hud_on
	ess_lbl.text = str(essence)
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
		gate_txt.text = "Portail rang %s  %s  %d m   (%d:%02d)" % [gate_rank(), arrow, int(d.length()), t / 60, t % 60]
		var ds := shop_door_pos - hero.global_position
		ds.y = 0
		if shop_door_pos != Vector3.INF and ds.length() > 3.0:
			gate_txt.text += "\nBoutique  %s  %d m" % [_arrow(ds), int(ds.length())]
	elif zone == "shop":
		gate_txt.text = "Boutique de l'Association"
	elif zone == "office":
		gate_txt.text = "Bureau du Changeur"
	elif zone == "run" and run:
		var d3 := run.next_target() - hero.global_position
		d3.y = 0
		var rm: Dictionary = run.room()
		gate_txt.text = "%s — %s (%d/%d)\n%s  %s  %d m" % [run.def["name"], rm["name"], run.cur + 1, run.rooms.size(), "Chef" if run.boss_room() else ("Passage" if rm["open"] else "Prochaine meute"), _arrow(d3), int(d3.length())]
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
	for k in 3:
		grant_item("w", "w3")
	inv_filter = "w"
	inv_sel = int(inv[inv.size() - 1]["uid"])
	_refresh_menu()
	await _snap("03c2_sac_fusion", 8)
	_equip_best()
	print("BEST arme=%s junk=%d" % [Items.base_of(item_by_uid(equip["w"]))["n"], _junk_list().size()])
	_set_filter("r")
	await _snap("03d_sac_reliques", 8)
	_toggle_menu("guide")
	await _snap("03e_guide", 8)
	_toggle_menu("guide")
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
	for m in mobs:
		var mm := m as Mob
		if mm.global_position.distance_to(spawn_point) < 25.0:
			print("NEAR_SPAWN %s d=%.1f home_d=%.1f patrol=%d team=%d" % [mm.kind, mm.global_position.distance_to(spawn_point), mm.home.distance_to(spawn_point), mm.patrol.size(), mm.team])
	await _snap("00_quete_quotidienne", 25)
	close_dialogue()
	await _perf("ville", 180)
	await bench.run(false)
	print("NAV_STATE ville pret=%s" % str(nav.baked.get("city", false)))
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
	set_gfx(true)
	await _perf("rapide", 90)
	set_gfx(false)
	# vie de la ville : vue large, civils, coffre, poursuite, police
	_place_hero(spawn_point, spawn_point + Vector3(0, 0, -10))
	spring.spring_length = 9.0
	pitch = -0.35
	await _snap("00v_ville_vivante", 30)
	var cfw := Vector3(-sin(yaw), 0, -cos(yaw))
	var ch := make_chest(hero.global_position + cfw * 3.0 + Vector3(cfw.z, 0, -cfw.x) * 1.5 - Vector3(0, 0.3, 0), 0.45)
	print("CHEST_DBG ", _dbg_aabb(ch))
	spring.spring_length = 4.5
	pitch = -0.25
	await _snap("00w_coffre", 10)
	open_chest_anim(ch)
	await _snap("00w2_coffre_ouvert", 40)
	ch.queue_free()
	var civ := spawn_free_mob("civil", hero.global_position + cfw * 14.0)
	print("CIV_DBG ", civ.global_position, " ", _dbg_aabb(civ.model), " hero ", hero.global_position)
	life.civs.append(civ)
	await get_tree().physics_frame
	life.start_chase(civ)
	spring.spring_length = 8.0
	await _snap("00x_poursuite", 40)
	await _snap("00x2_poursuite_proche", 90)
	for m in life.chase.get("chasers", []):
		if is_instance_valid(m):
			(m as Mob).take_damage(9999, hero)
	await _snap("00x3_civil_sauve", 60)
	life.notoriety = 1
	life.police_cd = 0.0
	if not life.police.is_empty():
		var pol := life.police[0] as Mob
		pol.global_position = hero.global_position + hero.forward() * 3.0
		await _snap("00y_police_controle", 30)
		close_dialogue()
		life.notoriety = 0
	spring.spring_length = 4.7
	# portail de près
	var gd := spawn_point - gate_pos
	gd.y = 0
	_place_hero(gate_pos + gd.normalized() * 9.0, gate_pos)
	pitch = -0.12
	await _snap("00p_portail", 30)
	# porte de la boutique puis intérieur
	_place_hero(shop_door_pos + shop_door_dir * 6.0, shop_door_pos)
	pitch = -0.15
	close_dialogue()
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
	var cp: Vector3 = camps[mini(2, camps.size() - 1)]["pos"]
	for i in 3:
		spawn_free_mob("goblin" if i < 2 else "shaman", cp + Vector3(sin(i * 2.1), 0, cos(i * 2.1)) * 3.5)
	await _snap("10_combat", 50)
	var victim := hero.nearest_enemy(20.0)
	if victim:
		victim.take_damage(25, hero)
		await get_tree().physics_frame
		print("HPBAR pv=%.0f/%.0f fill=%.2f" % [victim.hp, victim.max_hp, float((victim.hp_fill.material_override as ShaderMaterial).get_shader_parameter("fill"))])
	hero.mp = 100
	for i in 2:
		spawn_free_mob("goblin", hero.global_position + hero.forward() * (3.0 + i) + Vector3(i - 0.5, 0, 0))
	await get_tree().physics_frame
	hero.telekinesis()
	await _snap("10b_telekinesie", 22)
	_tk_pick("eject")
	await _snap("10c_tk_ejecter", 14)
	await _snap("10c1_tk_ejecter_impact", 20)
	for mode in ["crush", "choke"]:
		for i in 2:
			spawn_free_mob("goblin", hero.global_position + hero.forward() * (3.0 + i) + Vector3(i - 0.5, 0, 0))
		await get_tree().physics_frame
		hero.cd["tele"] = 0.0
		hero.mp = 100
		hero.busy = 0.0
		hero.telekinesis()
		await _snap("10c2_tk_prise_" + mode, 25)
		_tk_pick(mode)
		await _snap("10c3_tk_" + mode, 10 if mode == "crush" else 40)
		await _snap("10c4_tk_" + mode + "_fin", 30)
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
	# ordres : à l'attaque / restez
	for i in 3:
		spawn_free_mob("goblin" if i < 2 else "shaman", hero.global_position + hero.forward() * 12.0 + Vector3(i * 1.6 - 1.6, 0, 0))
	await get_tree().physics_frame
	hero.hp = hero.max_hp * 0.45
	command_attack()
	await _snap("15b_ordre_attaque", 12)
	await _snap("15c_ombres_chargent", 40)
	await _snap("15d_ombres_positions", 60)
	command_stay()
	await _snap("15e_ombres_restent", 90)
	command_stay()
	var orc := spawn_free_mob("orc", hero.global_position + hero.forward() * 7.0)
	orc.target = null
	try_parley(orc, true)
	await _snap("15f_replique_monstre", 30)
	_parley_answer("a")
	await _snap("15g_reponse", 60)
	_kill_near(hero.global_position, 25.0)
	hero.hp = hero.max_hp
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
	await _shots_runs()
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

# ================================================================ donjons à salles + jetons
func gate_name() -> String:
	return "Marais du Commandant Écarlate" if gate_kind == "igris" else str(RoomRun.DEFS[gate_kind]["name"])

func gate_rank() -> String:
	return "C" if gate_kind == "igris" else RoomRun.RANKS[int(RoomRun.DEFS[gate_kind]["rank"])]

func gate_color() -> Color:
	match gate_kind:
		"goblin":
			return Color(0.3, 0.95, 0.45)
		"orc":
			return Color(1.0, 0.5, 0.15)
	return Color(0.25, 0.55, 1.0)

func _build_run() -> void:
	if run:
		run.cleanup()
		run = null
	run = RoomRun.new()
	add_child(run)
	run.build(self, gate_kind, RUN_O)
	await get_tree().physics_frame
	await get_tree().physics_frame
	await run.layout()

func enter_run() -> void:
	if entering_run:
		return
	entering_run = true
	sfx("portal", null, 0.0)
	sfx("shadow")
	# écran noir + texte pendant la construction des salles (2-4 s sur téléphone)
	var tw := create_tween()
	tw.tween_property(fade, "modulate:a", 1.0, 0.3)
	await tw.finished
	load_lbl.text = "Ouverture du portail…\n%s" % gate_name()
	load_lbl.visible = true
	await get_tree().process_frame
	if run == null or run.kind != gate_kind:
		await _build_run()
	load_lbl.visible = false
	entering_run = false
	run.show_room(0)
	await _teleport(run.room()["entry"], "run")
	_face(run.next_target())
	run.enter_room_msg()
	hint("run")

func _face(p: Vector3) -> void:
	var d := p - hero.global_position
	yaw = atan2(-d.x, -d.z)

func _next_room() -> void:
	if run.cur + 1 >= run.rooms.size():
		return
	sfx("portal", null, -3.0)
	run.show_room(run.cur + 1)
	await _teleport(run.room()["entry"], "run")
	_face(run.next_target())
	run.enter_room_msg()
	if run.boss_room() and run.over > 0:
		hint("anomaly")

func _leave_run() -> void:
	await _teleport(gate_pos + Vector3(0, 0, 5), "city")
	_spawn_gate(false)

func add_tokens(k: String, n: int, at: Vector3) -> void:
	tokens[k] = int(tokens[k]) + n
	FX.damage_number(self, at + Vector3(0, 0.4, 0), "+%d %s%s" % [n, TOK_NAME[k], "s" if n > 1 else ""], Color(1, 0.82, 0.3))
	sfx("coins", at, -6.0)

# ---------------------------------------------------------------- bureau du Changeur
func _build_office() -> void:
	office_door = shop_entry + Vector3(6.0, 0, 3.6)
	var dm := FX.ground_disc(1.0, Color(1.0, 0.8, 0.3), 0.6, true)
	shop.add_child(dm)
	dm.global_position = office_door + Vector3(0, 0.05, 0)
	var dl := Label3D.new()
	dl.text = "BUREAU DU CHANGEUR"
	dl.font_size = 40
	dl.pixel_size = 0.0045
	dl.outline_size = 10
	dl.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	dl.modulate = Color(1, 0.85, 0.45)
	shop.add_child(dl)
	dl.global_position = office_door + Vector3(0, 2.2, 0)
	office = Node3D.new()
	add_child(office)
	office.position = OFFICE_O
	var mdl := (load("res://assets/rooms/office.glb") as PackedScene).instantiate() as Node3D
	mdl.scale = Vector3.ONE * OFFICE_S
	office.add_child(mdl)
	for mi in mdl.find_children("*", "MeshInstance3D", true, false):
		var mm := mi as MeshInstance3D
		var body := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		cs.shape = mm.mesh.create_trimesh_shape()
		body.add_child(cs)
		mm.add_child(body)
	# la maquette n'a que deux murs : on ferme la pièce (murs + plafond)
	var W := 500.0 * OFFICE_S
	var H := 400.0 * OFFICE_S
	var wm := FX.mat(Color(0.32, 0.33, 0.36), 0.0, 1.0, false)
	for part in [[Vector3(W * 0.5 + 0.1, H * 0.5, 0), Vector3(0.2, H, W + 0.4)], [Vector3(0, H * 0.5, W * 0.5 + 0.1), Vector3(W + 0.4, H, 0.2)],
			[Vector3(-W * 0.5 - 0.1, H * 0.5, 0), Vector3(0.2, H, W + 0.4)], [Vector3(0, H * 0.5, -W * 0.5 - 0.1), Vector3(W + 0.4, H, 0.2)], [Vector3(0, H + 0.1, 0), Vector3(W + 0.4, 0.2, W + 0.4)]]:
		var b := StaticBody3D.new()
		var c := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = part[1]
		c.shape = bs
		b.add_child(c)
		var vis := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = part[1]
		vis.mesh = bm
		vis.material_override = wm
		b.add_child(vis)
		office.add_child(b)
		b.position = part[0]
	var lt := FX.new_light(true)
	lt.light_color = Color(1, 0.88, 0.7)
	lt.light_energy = 1.6
	lt.omni_range = 9.0
	office.add_child(lt)
	lt.position = Vector3(0, H - 0.8, 0)
	office_entry = OFFICE_O + Vector3(-60, 0, 195) * OFFICE_S
	office_exit = office_entry + Vector3(-0.9, 0, 0.6)
	var ex := FX.ground_disc(0.7, Color(0.4, 0.8, 1.0), 0.6, true)
	office.add_child(ex)
	ex.global_position = office_exit + Vector3(0, 0.04, 0)
	changer = spawn_free_mob("hunter", OFFICE_O + Vector3(165, 0, 35) * OFFICE_S)
	changer.display_name = "Le Changeur"
	changer.rank = "PNJ"
	changer.patrol = []
	changer.team = 2
	for att in changer.find_children("*", "BoneAttachment3D", true, false):
		att.queue_free()
	if changer.hp_bar:
		changer.hp_bar.queue_free()
		changer.hp_bar = null
		changer.hp_fill = null
	var lb := Label3D.new()
	lb.text = "Le Changeur — Jetons"
	lb.font_size = 34
	lb.pixel_size = 0.0009
	lb.fixed_size = true
	lb.outline_size = 8
	lb.modulate = Color(1, 0.85, 0.4)
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.position.y = 2.2
	changer.add_child(lb)
	changer.face_to(office_entry, true)
	office.visible = false
	changer.visible = false

func enter_office() -> void:
	sfx("open")
	await _teleport(office_entry, "office")
	changer.visible = true
	_face(changer.global_position)
	hint("office")

func leave_office() -> void:
	sfx("open")
	changer.visible = false
	await _teleport(office_door + Vector3(-1.2, 0, 0), "shop")

func _changer_dialogue() -> void:
	changer.face_to(hero.global_position, true)
	var w := item_by_uid(int(equip["w"]))
	var wl := Items.lv(w) if not w.is_empty() else 10
	var txt := "Des jetons de Portail... Je ne prends pas l'or, chasseur. L'or, tout le monde en a. Ça, seuls ceux qui sortent vivants en ont.\nTes jetons : %d orques, %d gobelins." % [tokens["orc"], tokens["goblin"]]
	var ch: Array = []
	if wl < 10:
		ch.append(["Forger mon arme (+1 niveau, actuel %d) — 6 jetons orques" % wl, _changer_buy.bind("weapon")])
	ch.append(["Renforcer une ombre (+1 niveau) — 5 jetons gobelins", _changer_shadows])
	if not _owns("w9"):
		ch.append(["Hache du Chef de Guerre (unique) — 40 jetons orques", _changer_buy.bind("w9")])
	if not _owns("a11"):
		ch.append(["Masque de Kragg (unique) — 30 jetons gobelins", _changer_buy.bind("a11")])
	ch.append(["« Pas maintenant. »", close_dialogue])
	dialogue("Le Changeur", txt, ch)

func _owns(id: String) -> bool:
	for it in inv:
		if str(it["id"]) == id:
			return true
	return false

func _pay(k: String, n: int) -> bool:
	if int(tokens[k]) < n:
		sfx("error")
		dialogue("Le Changeur", "Il te manque %d %ss. Les Portails ne vont pas se vider tout seuls." % [n - int(tokens[k]), TOK_NAME[k]], [["« Je reviendrai. »", _changer_dialogue]])
		return false
	tokens[k] = int(tokens[k]) - n
	return true

func _changer_buy(what: String) -> void:
	match what:
		"weapon":
			var w := item_by_uid(int(equip["w"]))
			if w.is_empty() or not _pay("orc", 6):
				return
			w["lv"] = Items.lv(w) + 1
			recalc_gear()
			sfx("levelup")
			FX.burst(self, hero.global_position + Vector3(0, 1.2, 0), Color(1, 0.6, 0.2), 30, 0.08, 3.0, 0.7, -1.0)
			system_msg("%s passe au niveau %d." % [Items.base_of(w)["n"], Items.lv(w)])
		"w9":
			if not _pay("orc", 40):
				return
			grant_item("w", "w9")
			sfx("victory")
			system_msg("Tu obtiens : HACHE DU CHEF DE GUERRE (unique).")
		"a11":
			if not _pay("goblin", 30):
				return
			grant_item("a", "a11")
			sfx("victory")
			system_msg("Tu obtiens : MASQUE DE KRAGG (unique).")
	save_game()
	_changer_dialogue()

func _changer_shadows() -> void:
	var ch: Array = []
	var lst := shadow_list()
	lst.sort_custom(func(a, b): return (a as Mob).grade * 20 + (a as Mob).slv > (b as Mob).grade * 20 + (b as Mob).slv)
	for m in lst:
		var mm := m as Mob
		if mm.slv >= 10:
			continue
		ch.append(["%s — rang %s, niv. %d" % [mm.display_name, Mob.GRADES[mm.grade], mm.slv], _changer_shadow.bind(mm)])
		if ch.size() >= 5:
			break
	if ch.is_empty():
		dialogue("Le Changeur", "Tu n'as aucune ombre à renforcer.", [["« Retour »", _changer_dialogue]])
		return
	ch.append(["« Retour »", _changer_dialogue])
	dialogue("Le Changeur", "Laquelle ? (5 jetons gobelins — tu en as %d)" % tokens["goblin"], ch)

func _changer_shadow(m: Mob) -> void:
	if not is_instance_valid(m) or not _pay("goblin", 5):
		return
	m.level_up()
	sfx("levelup")
	FX.arise_pillar(self, m.global_position)
	save_game()
	_changer_shadows()

func _shots_runs() -> void:
	hero.max_hp = 99999
	hero.hp = 99999
	for kd in ["goblin", "orc", "igris"]:
		if gate_kind != kd or run == null:
			gate_kind = kd
			await _build_run()
		while not run.ready_ok:
			await get_tree().physics_frame
		await enter_run()
		await _snap("30_%s_salle1_entree" % kd, 40)
		for i in run.rooms.size():
			var r: Dictionary = run.room()
			if run.boss_room():
				_place_hero(run.chief.global_position + (r["entry"] - run.chief.global_position).normalized() * 10.0, run.chief.global_position)
				await _snap("33_%s_chef%s" % [kd, "_anomalie" if run.over > 0 else ""], 40)
				print("RUN_CHIEF %s rang=%s pv=%d degats=%.0f" % [run.chief.display_name, run.chief.rank, int(run.chief.max_hp), run.chief.dmg])
				run.chief.take_damage(9999999, hero)
				await _snap("34_%s_coffre_chef" % kd, 60)
				if run.chest:
					_place_hero(run.chest.global_position + Vector3(0, 0, 3), run.chest.global_position)
					run.open_chest()
					await _snap("35_%s_coffre_ouvert" % kd, 50)
				break
			var k := 0
			for p in r["packs"]:
				var c: Vector3 = p["center"]
				_place_hero(c + (r["entry"] - c).normalized() * 9.0, c)
				await _snap("31_%s_s%d_meute%d" % [kd, i + 1, k], 30 if k == 0 else 10)
				for m in p["mobs"]:
					if is_instance_valid(m) and not (m as Mob).dead:
						(m as Mob).take_damage(9999999, hero)
				k += 1
				await get_tree().create_timer(0.5).timeout
			await _snap("32_%s_s%d_passage" % [kd, i + 1], 30)
			print("RUN_STEP %s salle=%d ouverte=%s jetons=%s" % [kd, i + 1, str(r["open"]), str(tokens)])
			await _next_room()
			await _snap("30_%s_salle%d_entree" % [kd, i + 2], 40)
		close_dialogue()
		if kd == "igris":
			print("RUN_STEP igris porte_trone=%s" % str(run.room()["open"]))
			await enter_hall()
			await _snap("35b_igris_salle_trone", 40)
			_boss_flee_go()
			await get_tree().create_timer(1.0).timeout
		else:
			await _leave_run()
	# bureau du Changeur
	tokens = {"orc": 50, "goblin": 40}
	await enter_shop()
	_place_hero(office_door + Vector3(-4, 0, -2), office_door)
	await _snap("36_porte_bureau", 20)
	await enter_office()
	await _snap("37_bureau", 30)
	_place_hero(changer.global_position + (office_entry - changer.global_position).normalized() * 2.2, changer.global_position)
	await _snap("37b_changeur", 15)
	_changer_dialogue()
	await _snap("38_changeur_dialogue", 20)
	_changer_buy("w9")
	await _snap("38b_achat", 15)
	close_dialogue()
	_toggle_menu("sac")
	await _snap("39_sac_jetons", 15)
	_toggle_menu("sac")
	await leave_office()
	await leave_shop()

# ================================================================ sol valide (anti « hors décor »)
## Point sûr pour aller de « from » vers « to » : on s'arrête avant un mur, on se pose sur le sol
## (jamais sur un toit ni dans un bâtiment) et, si le maillage navigable existe, on s'y raccroche.
func safe_point(from: Vector3, to: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var a := from + Vector3(0, 0.9, 0)
	var b := Vector3(to.x, a.y, to.z)
	var p := Vector3(to.x, from.y, to.z)
	if a.distance_to(b) > 0.05:
		var q := PhysicsRayQueryParameters3D.create(a, b, 1)
		var hit := space.intersect_ray(q)
		if not hit.is_empty():
			var dir := (b - a).normalized()
			p = (hit["position"] as Vector3) - dir * 0.7
			p.y = from.y
	var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 1.4, 0), p + Vector3(0, -4.0, 0), 1))
	if g.is_empty() or absf((g["position"] as Vector3).y - from.y) > 1.6:
		p = from
	else:
		p = g["position"]
	if nav and nav.covers(p):
		var c := nav.closest(p)
		if c.distance_to(p) < 3.0:
			p = c
	return p

## Sol sous un point (pour le butin, les cadavres) : jamais en l'air.
func ground_at(p: Vector3) -> Vector3:
	var space := get_world_3d().direct_space_state
	var g := space.intersect_ray(PhysicsRayQueryParameters3D.create(p + Vector3(0, 0.5, 0), p + Vector3(0, -30.0, 0), 1))
	return (g["position"] as Vector3) if not g.is_empty() else p

## Direction « devant la caméra » à plat (pour placer les ombres hors du champ caméra-héros).
func cam_forward() -> Vector3:
	return Vector3(-sin(yaw), 0, -cos(yaw))

# ================================================================ diagnostic (mesures sur le téléphone)
func _toggle_diag() -> void:
	diag_on = not diag_on
	if diag_lbl == null:
		diag_lbl = Label.new()
		diag_lbl.position = Vector2(250, 150)
		diag_lbl.add_theme_font_size_override("font_size", 15)
		diag_lbl.add_theme_color_override("font_color", Color(0.7, 1.0, 0.85))
		diag_lbl.add_theme_color_override("font_outline_color", Color(0, 0, 0))
		diag_lbl.add_theme_constant_override("outline_size", 5)
		diag_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		ui_layer.add_child(diag_lbl)
	diag_lbl.visible = diag_on
	_toggle_quick()

func _update_diag() -> void:
	var s := Bench.frame_stats()
	var awake := 0
	for m in mobs:
		if not (m as Mob).sleeping_lod and not (m as Mob).dead:
			awake += 1
	var fps := Engine.get_frames_per_second()
	diag_lbl.text = "image %.1f ms (%d FPS)\nscripts %.1f ms · physique %.1f ms\nappels %d · objets %d · triangles %dk\nunités actives %d / %d · particules %d\nlumières %d · ombres portées %s · %s" % [
		1000.0 / maxf(fps, 1), fps, float(s["proc"]), float(s["phys"]), int(s["dc"]), int(s["obj"]), int(s["prim"]) / 1000,
		awake, mobs.size(), get_tree().get_nodes_in_group("fx_burst").size(), FX.light_budget, "oui" if moon.shadow_enabled else "non", "Rapide" if gfx_fast else "Haute"]

func _start_bench() -> void:
	_toggle_quick()
	if zone != "city":
		system_msg("Le test se lance en ville.")
		return
	bench.run(true)
