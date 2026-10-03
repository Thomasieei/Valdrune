extends Node3D
# VALDRUNE 2.0 — boucle principale : monde, héros, caméra, ennemis, objectifs, forge

var world: World
var player: Player
var hud: Hud
var cam: Camera3D
var sun: DirectionalLight3D
var enemies: Array = []
var shake_amt := 0.0
var goal_target = null          # Vector3 ou null
var goal_text := ""
var arrow: MeshInstance3D
var beacon: MeshInstance3D
var boss_ref: Enemy
var camp_spawn := Vector3(0, 0, 86.0)
var t_goal := 0.0
var t_spawn := 0.0
var shot_mode := false
var shot_t := 0.0
var interact := ""             # "forge" / "shop" / ""
var gather_node := {}
var loots: Array = []
var chest_sp := {}
var last_goal_key := ""
var npcs: Array = []
var talk_npc: Npc
var cur_region := 0
var hidden_sel := {}
var env: Environment
var t_disc := 0.0
var cam_zoom := 1.0
var icons: Icons
var t_ah := 0.0
var allies: Array = []
var dungeon: Dungeon
var tower: Tower
var island: Island
var island_back := Vector3.ZERO
var isl_sel := {}
var tower_back := Vector3.ZERO
var tower_sel := {}
func in_instance() -> bool: return dungeon != null or tower != null or island != null
var dungeon_entries: Array = []   # portails de donjon dans le monde
var duel_enemy: Enemy
var duel_npc: Npc
var world_boss: Enemy
var world_boss_info := {}
var t_events := 3.0
var entry_sel := {}
var dungeon_back := Vector3.ZERO
var next_boss_at := 0.0
var bots: Array = []
var t_market := 60.0
var pvp_target: Node3D = null
var spawn_q: Array = []
var free_q: Array = []
var cine: Callable
var sky_mat: ProceduralSkyMaterial

func _ready() -> void:
	shot_mode = "shot" in OS.get_cmdline_user_args()
	_env()
	var t0 := Time.get_ticks_msec()
	var mid: int = clamp(int(Game.S.get("map", 1)), 1, 4)
	world = World.new(); add_child(world); world.build(mid)
	print("world build ms=", Time.get_ticks_msec() - t0, " map=", mid)
	if typeof(Game.S.get("seen")) != TYPE_DICTIONARY: Game.S["seen"] = {}
	Game.S.seen[str(mid)] = 1
	camp_spawn = Vector3(world.village.x, 0, world.village.y + 6.0)
	var start := camp_spawn
	var arr = Game.S.get("arrive", null)
	if arr is Array and arr.size() == 2: start = Vector3(float(arr[0]), 0, float(arr[1]))
	Game.S.erase("arrive")
	icons = Icons.new(); add_child(icons); icons.setup(self)
	player = Player.new(); add_child(player); player.setup(self)
	player.position = start + Vector3(0, world.height(start.x, start.z) + 0.3, 0)
	for d in world.npc_spots:
		var n := Npc.new(); add_child(n); n.setup(self, d); npcs.append(n)
	cam = Camera3D.new(); cam.fov = 48.0; cam.far = 170.0; add_child(cam)
	hud = Hud.new(); add_child(hud); hud.setup(self)
	hud.build_map(world.map_image())
	_make_guide()
	_make_ambient()
	_spawn_saved_mercs()
	_spawn_bots()
	next_boss_at = 240.0
	update_goal()
	_cam_update(1.0, true)
	_warmup()
	if Game.traveling:
		Game.traveling = false
		hud.region_banner(Maps.NAMES[mid], Maps.TIERS[mid][1], "Carte T%d-T%d · %s" % [Maps.TIERS[mid][0], Maps.TIERS[mid][1], world.MAP.terrain])
		if mid >= 2: get_tree().create_timer(3.0).timeout.connect(func(): hud.toast("Attention : sur cette carte, certains joueurs sont hostiles (JcJ). La ville est sûre.", Color("#ff9a7a"), true))
	elif not shot_mode: hud.show_title()
	if shot_mode:
		var tp = load("res://tests/plan.gd").new(); set_meta("plan", tp.plan(self))

# ——— Cycle jour / nuit (20 min) et météo ———
# Le jour dure ~11 min, crépuscule, nuit ~5 min (jamais noire : on doit toujours bien voir), aube.
const DAY_LEN := 1200.0
var night := 0.0
var danger := 0.0
var sky_tint := Color(1, 1, 1)
var rain_k := 0.0
var rain_until := 0.0
var next_weather := 240.0
var rain: CPUParticles3D
var rain_snd: AudioStreamPlayer
var tod_override := -1.0
func day_phase() -> float: return tod_override if tod_override >= 0.0 else fmod(Time.get_unix_time_from_system() / DAY_LEN, 1.0)
var was_night := false
func _sky_update(dt: float) -> void:
	if in_instance():
		if rain: rain.emitting = false
		if rain_snd: rain_snd.volume_db = -60.0
		return
	var ph := day_phase()
	var day := 1.0
	if ph > 0.55 and ph < 0.65: day = 1.0 - smoothstep(0.55, 0.65, ph)
	elif ph >= 0.65 and ph < 0.9: day = 0.0
	elif ph >= 0.9: day = smoothstep(0.9, 1.0, ph)
	var dusk: float = clamp(1.0 - abs(day - 0.5) * 2.0, 0.0, 1.0)
	night = 1.0 - day
	# météo : de temps en temps, une averse de 2 à 3 minutes
	var now := Time.get_ticks_msec() / 1000.0
	if now > next_weather:
		next_weather = now + randf_range(240.0, 480.0)
		if randf() < 0.35: rain_until = now + randf_range(110.0, 180.0); hud.toast("Il commence à pleuvoir…", Color("#a8c8ff"))
	rain_k = move_toward(rain_k, 1.0 if now < rain_until else 0.0, dt * 0.12)
	_rain_fx()
	var gray: float = rain_k * 0.45
	var day_col := Color("#fff1d8").lerp(Color("#ff9a5a"), dusk * 0.8)
	sun.light_color = Color(0.62, 0.72, 1.0).lerp(day_col, day)
	sun.light_energy = lerp(0.3, 0.95, day) * (1.0 - gray * 0.55)
	sun.rotation_degrees = Vector3(lerp(-30.0, -52.0, day), -38.0 + (ph - 0.3) * 40.0, 0)
	env.ambient_light_color = Color(0.4, 0.48, 0.78).lerp(Color("#a9b8cc"), day).lerp(Color(0.6, 0.62, 0.68), gray)
	env.ambient_light_energy = lerp(0.42, 0.38, day)
	env.adjustment_brightness = lerp(0.78, 0.9, day) - gray * 0.08
	env.adjustment_saturation = lerp(0.85, 1.08, day) - gray * 0.25
	env.fog_density = 0.0028 + gray * 0.006 + night * 0.0015
	sky_tint = Color(0.32, 0.38, 0.62).lerp(Color(1, 1, 1), day).lerp(Color(1.1, 0.8, 0.65), dusk * 0.6).lerp(Color(0.62, 0.66, 0.72), gray)
	# zones T3 et plus (hors ville) : ciel et brume rougeoyants — ici, on peut perdre son équipement
	var rt: int = World.REGIONS[max(1, cur_region)].tier if cur_region > 0 else 1
	var want_d: float = 0.0 if world.in_town(player.global_position) or world.map_id < 2 else {3: 0.4, 4: 0.65, 5: 0.9}.get(rt, 0.0)
	danger = move_toward(danger, want_d, dt * 0.3)
	sky_tint = sky_tint.lerp(Color(1.25, 0.55, 0.45), danger * 0.45)
	hud.set_danger(danger)
	sky_mat.sky_top_color = Color("#0d1530").lerp(Color("#5d9bd6"), day).lerp(Color("#556677"), gray).lerp(Color("#5a2020"), danger * 0.6)
	sky_mat.sky_horizon_color = Color("#2a3558").lerp(Color("#cfe3ea"), day).lerp(Color("#f0a070"), dusk * 0.7).lerp(Color("#8a96a2"), gray).lerp(Color("#c0503a"), danger * 0.55)
	env.ambient_light_color = env.ambient_light_color.lerp(Color(0.9, 0.55, 0.5), danger * 0.35)
	world.set_night(night)
	var is_night := night > 0.6
	if is_night != was_night:
		was_night = is_night
		if is_night: hud.toast("La nuit tombe : les monstres sont plus forts… et leur butin meilleur.", Color("#a8b8ff"), true)
		else: hud.toast("Le jour se lève sur %s." % Maps.NAMES[world.map_id], Color("#ffe2a0"))

func _rain_fx() -> void:
	if rain_k <= 0.01:
		if rain: rain.emitting = false
		if rain_snd: rain_snd.volume_db = -60.0
		return
	if rain == null:
		rain = CPUParticles3D.new(); rain.amount = 220; rain.lifetime = 0.7; rain.local_coords = false; rain.preprocess = 0.7
		rain.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; rain.emission_box_extents = Vector3(14, 0.5, 11)
		rain.direction = Vector3(0.15, -1, 0.05); rain.spread = 3.0; rain.gravity = Vector3.ZERO; rain.initial_velocity_min = 20.0; rain.initial_velocity_max = 24.0
		var q := QuadMesh.new(); q.size = Vector2(0.05, 0.9)
		var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_color = Color(0.8, 0.88, 1.0, 0.6); m.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y; q.material = m; rain.mesh = q
		add_child(rain)
		# bruit de pluie (souffle filtré, en boucle)
		var n := 22050 * 2; var data := PackedByteArray(); data.resize(n * 2); var lp := 0.0
		for i in n:
			var v := randf_range(-1, 1); lp += (v - lp) * 0.25
			data.encode_s16(i * 2, int(clamp(lp * 0.6 + v * 0.08, -1.0, 1.0) * 30000.0))
		var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = 22050; w.data = data; w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_end = n
		rain_snd = AudioStreamPlayer.new(); rain_snd.stream = w; rain_snd.volume_db = -60.0; add_child(rain_snd); rain_snd.play()
	rain.emitting = true
	(rain.mesh.material as StandardMaterial3D).albedo_color.a = 0.6 * rain_k
	rain.global_position = player.global_position + Vector3(0, 9.0, 2.0)
	rain_snd.volume_db = linear_to_db(max(0.001, rain_k * 0.35))

# ——— Préchauffage : chaque matériau est dessiné une fois, caché sous le sol, pendant l'écran titre.
# Sur mobile, un shader se compile la première fois qu'il apparaît : c'est ça qui faisait « freezer » l'image.
func _warmup() -> void:
	var root := Node3D.new(); add_child(root)
	var fwd := -cam.global_transform.basis.z; fwd.y = 0; fwd = fwd.normalized()
	var base := player.global_position + fwd * 2.0
	base.y = world.height(base.x, base.z) - 3.5
	root.position = base
	var seen := {}; var n := 0
	var stack: Array = [world]
	while not stack.is_empty() and n < 500:
		var nd: Node = stack.pop_back()
		for c in nd.get_children(): stack.append(c)
		if nd is MeshInstance3D and (nd as MeshInstance3D).mesh:
			var mi := nd as MeshInstance3D
			var key := "m%d_%d" % [mi.mesh.get_instance_id(), mi.material_override.get_instance_id() if mi.material_override else 0]
			if seen.has(key): continue
			seen[key] = 1; n += 1
			var w := MeshInstance3D.new(); w.mesh = mi.mesh; w.material_override = mi.material_override
			for i in mi.mesh.get_surface_count(): w.set_surface_override_material(i, mi.get_surface_override_material(i))
			w.cast_shadow = mi.cast_shadow; w.position = Vector3((n % 12) * 0.3, 0, (n / 12) * 0.3); w.scale = Vector3.ONE * 0.05; root.add_child(w)
		elif nd is MultiMeshInstance3D and (nd as MultiMeshInstance3D).multimesh:
			var mm := nd as MultiMeshInstance3D
			var key2 := "mm%d_%d" % [mm.multimesh.mesh.get_instance_id(), mm.material_override.get_instance_id() if mm.material_override else 0]
			if seen.has(key2): continue
			seen[key2] = 1; n += 1
			var w2 := MultiMeshInstance3D.new(); var m2 := MultiMesh.new(); m2.transform_format = MultiMesh.TRANSFORM_3D; m2.mesh = mm.multimesh.mesh; m2.instance_count = 1
			m2.set_instance_transform(0, Transform3D(Basis().scaled(Vector3.ONE * 0.05), Vector3.ZERO)); w2.multimesh = m2; w2.material_override = mm.material_override
			w2.position = Vector3((n % 12) * 0.3, 0, (n / 12) * 0.3); root.add_child(w2)
	# personnages animés, montures, armes, objets de donjon, effets
	var k := 0
	for path in ["res://assets/skeletons/Skeleton_Minion.glb", "res://assets/skeletons/Skeleton_Warrior.glb", "res://assets/skeletons/Skeleton_Rogue.glb", "res://assets/skeletons/Skeleton_Mage.glb",
			"res://assets/heroes/Knight.glb", "res://assets/heroes/Barbarian.glb", "res://assets/heroes/Rogue.glb", "res://assets/heroes/Ranger.glb", "res://assets/heroes/Mage.glb"]:
		var ch := Chars.make(path); ch.root.position = Vector3(-2.0 - k * 0.6, 0, 0); ch.root.scale = Vector3.ONE * 0.3; root.add_child(ch.root); ch.ap.play("Idle_A"); k += 1
	for an in ["fox", "wolf", "stag", "bull", "horse", "donkey"]:
		if not ResourceLoader.exists("res://assets/animals/%s.glb" % an): continue
		var a: Node3D = load("res://assets/animals/%s.glb" % an).instantiate(); a.position = Vector3(-2.0 - k * 0.6, 0, 1.0); a.scale = Vector3.ONE * 0.05; root.add_child(a); k += 1
	for path in ["res://assets/dungeon/floor_tile_large.gltf", "res://assets/dungeon/wall.gltf", "res://assets/dungeon/torch_mounted.gltf", "res://assets/dungeon/chest_gold.gltf", "res://assets/dungeon/pillar_decorated.gltf",
			"res://assets/dungeon/sword_shield_gold.gltf", "res://assets/dungeon/coin_stack_large.gltf", "res://assets/dungeon/candle_triple.gltf", "res://assets/skeletons/Skeleton_Blade.gltf", "res://assets/skeletons/Skeleton_Axe.gltf"]:
		var o: Node3D = load(path).instantiate(); o.position = Vector3(-2.0 - k * 0.6, 0, 2.0); o.scale = Vector3.ONE * 0.1; root.add_child(o); k += 1
	for t in range(1, 6):
		for wk in Game.WEAPON_KINDS:
			var wpn: Node3D = load(Game.weapon_model(wk, t)).instantiate(); wpn.position = Vector3(-2.0 - k * 0.3, 0, 3.0); wpn.scale = Vector3.ONE * 0.2; root.add_child(wpn); k += 1
	Fx.burst(root, Vector3(0, 0, -1), Color.WHITE, 12); Fx.burst(root, Vector3(0, 0, -1), Color.WHITE, 24); Fx.burst(root, Vector3(0, 0, -1), Color.WHITE, 40)
	Fx.number(root, Vector3(0, 0, -1), "0123456789+-", Color.WHITE)
	Fx.slash(root, Vector3(0, 0, -2), 0.0); Fx.disc(root, Vector3(1, 0, -2), 1.0, Color(1, 0, 0, 0.4), 0.3)
	for tn in ["it_loot_common", "it_loot_rare", "it_chest_open"]:
		var sp := Sprite3D.new(); sp.texture = hud.T(tn); sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sp.position = Vector3(2, 0, -1); sp.pixel_size = 0.001; root.add_child(sp)
	var tm := MeshInstance3D.new(); tm.mesh = TorusMesh.new(); tm.material_override = Bot._ring_mat(Color(0.2, 0.6, 1.0, 0.5)); tm.position = Vector3(3, 0, -1); tm.scale = Vector3.ONE * 0.1; root.add_child(tm)
	get_tree().create_timer(0.6).timeout.connect(func(): if is_instance_valid(root): root.queue_free())

# ——— Voyage entre les cartes ———
var gate_sel := {}
func travel_to(id: int, arrive: Vector2) -> void:
	if in_instance(): hud.toast("Termine d'abord ce donjon / cette tour / ton île", Color("#ffb07a")); return
	hud.close_panel()
	Game.S.map = id; Game.S["arrive"] = [arrive.x, arrive.y]
	Game.traveling = true
	hud.loading("Voyage vers %s…" % Maps.label(id))
	Game.save_now()
	await get_tree().process_frame
	await get_tree().process_frame
	get_tree().reload_current_scene()

func _ask_gate(g: Dictionary) -> void:
	var to: int = g.to
	var lo: int = Maps.TIERS[to][0]; var hi: int = Maps.TIERS[to][1]
	var warn := ""
	if Game.power() < Game.power_needed(lo) * 0.8: warn = "\n\n[color=#ff8a7a]Ton équipement est faible pour cette carte (puissance %d, conseillé %d).[/color]" % [Game.power(), Game.power_needed(lo)]
	if to >= 2: warn += "\n[color=#ffb07a]Des joueurs hostiles (JcJ) y rôdent : s'ils te battent, ils te prennent une pièce d'équipement.[/color]"
	hud.confirm("Passage · %s" % g.dir, "Partir vers [b]%s[/b] — carte T%d-T%d (%s) ?%s" % [Maps.NAMES[to], lo, hi, Maps.def(to).terrain.to_lower(), warn], func(): travel_to(to, g.arrive))

func _talk_travel(n: Npc) -> void:
	var acts := []
	for id in range(1, 5):
		if id == world.map_id or not Game.S.get("seen", {}).has(str(id)): continue
		var T: Dictionary = Maps.def(id).town
		acts.append(["%s (T%d-T%d)" % [Maps.NAMES[id], Maps.TIERS[id][0], Maps.TIERS[id][1]], func(): travel_to(id, T.pos + Vector2(0, 6)), true])
	acts.append(["Au revoir", func(): hud.close_panel()])
	var line := "Je connais tous les chemins du royaume. Je t'emmène dans n'importe quelle ville que tu as déjà visitée — gratuitement, le voyage est un plaisir." if acts.size() > 1 else "Je t'emmènerai dans les autres villes… une fois que tu les auras visitées. Trouve les passages au bord de la carte (regarde les panneaux)."
	hud.show_dialog(n, line, acts)

func on_start() -> void:
	if not Game.S.tips.has("start"):
		Game.S.tips["start"] = 1; Game.save()
		hud.toast("Bienvenue à Valdrune ! Va parler à Aldric, l'Ancien ( ! doré).", Color("#ffd27a"), true)
		get_tree().create_timer(4.5).timeout.connect(func(): hud.toast("Pouce à gauche pour bouger · gros bouton : parler, frapper, récolter"))
		get_tree().create_timer(9.0).timeout.connect(func(): hud.toast("Touche la mini-carte pour voir la carte du monde"))

func _env() -> void:
	var we := WorldEnvironment.new(); var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color("#5d9bd6"); sm.sky_horizon_color = Color("#cfe3ea"); sm.ground_bottom_color = Color("#4b5a3c"); sm.ground_horizon_color = Color("#cfe3ea")
	sky.sky_material = sm; e.sky = sky; e.background_mode = Environment.BG_SKY
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color("#a9b8cc"); e.ambient_light_energy = 0.38
	# image un peu plus sombre et plus contrastée (moins « plastique »)
	e.tonemap_mode = Environment.TONE_MAPPER_LINEAR; e.tonemap_exposure = 1.0
	e.adjustment_enabled = true; e.adjustment_saturation = 1.08; e.adjustment_contrast = 1.14; e.adjustment_brightness = 0.9
	e.fog_enabled = true; e.fog_light_color = Color("#c9dde6"); e.fog_density = 0.0028; e.fog_sky_affect = 0.0
	we.environment = e; add_child(we); env = e; sky_mat = sm
	sun = DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, -38, 0); sun.light_energy = 0.95; sun.light_color = Color("#fff1d8")
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL; sun.directional_shadow_max_distance = 30.0; sun.shadow_opacity = 0.55
	sun.shadow_bias = 0.06; add_child(sun)

# Particules d'ambiance qui suivent le héros (pollen, lucioles, braises… selon la région)
var ambient: CPUParticles3D
const AMB_COL := [Color(1, 1, 0.8), Color(1.0, 0.95, 0.6, 0.8), Color(0.75, 1.0, 0.5, 0.8), Color(1.0, 0.85, 0.55, 0.6), Color(0.7, 1.0, 0.35, 0.9), Color(1.0, 0.45, 0.15, 0.95)]
func _make_ambient() -> void:
	ambient = CPUParticles3D.new(); ambient.amount = 36; ambient.lifetime = 6.0; ambient.local_coords = false; ambient.preprocess = 4.0
	ambient.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; ambient.emission_box_extents = Vector3(16, 2.5, 12)
	ambient.direction = Vector3(0.3, 1, 0.1); ambient.spread = 60.0; ambient.gravity = Vector3(0, 0.05, 0)
	ambient.initial_velocity_min = 0.15; ambient.initial_velocity_max = 0.5; ambient.scale_amount_min = 0.06; ambient.scale_amount_max = 0.14
	var g := Gradient.new(); g.set_color(0, Color(1, 1, 1, 0)); g.add_point(0.25, Color(1, 1, 1, 1)); g.add_point(0.75, Color(1, 1, 1, 1)); g.set_color(g.get_point_count() - 1, Color(1, 1, 1, 0)); ambient.color_ramp = g
	var q := QuadMesh.new(); q.material = Fx.add_mat(); ambient.mesh = q; add_child(ambient)

func _make_guide() -> void:
	arrow = MeshInstance3D.new()
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var pts := [Vector3(0, 0, 1.1), Vector3(0.62, 0, 0.2), Vector3(0.24, 0, 0.2), Vector3(0.24, 0, -0.6), Vector3(-0.24, 0, -0.6), Vector3(-0.24, 0, 0.2), Vector3(-0.62, 0, 0.2)]
	for tri in [[0, 1, 6], [2, 3, 4], [2, 4, 5]]:
		for i in tri: st.add_vertex(pts[i])
	arrow.mesh = st.commit()
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = Color(1, 0.82, 0.25, 0.9); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.no_depth_test = true; m.render_priority = 3
	arrow.material_override = m; arrow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(arrow)
	beacon = MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.35; cm.bottom_radius = 0.6; cm.height = 14.0; beacon.mesh = cm
	var bm := StandardMaterial3D.new(); bm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; bm.albedo_color = Color(1, 0.85, 0.3, 0.22); bm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; bm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	beacon.material_override = bm; beacon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(beacon)

# ——— Boucle ———
func _process(dt: float) -> void:
	var P := player
	Game.listener = P.global_position
	P.input_vec = hud.move_vec() if (not hud.panel_open or hud.cur_panel == "bag") else Vector2.ZERO
	if has_meta("force") and get_meta("force") != Vector2.ZERO: P.input_vec = get_meta("force")
	_context(dt)
	var o0 := Time.get_ticks_usec()
	world.update_nodes(dt)
	world.update_life(dt, P.global_position)
	if not in_instance(): world.update_occlusion(player.global_position, dt)
	if shot_mode and Time.get_ticks_usec() - o0 > 3000: print("OCC ", (Time.get_ticks_usec() - o0) / 1000.0)
	t_spawn -= dt
	if t_spawn <= 0.0:
		t_spawn = 0.5; var u0 := Time.get_ticks_usec(); _update_spawns(); var u1 := Time.get_ticks_usec()
		if shot_mode and u1 - u0 > 3000: print("SPAWN ", (u1 - u0) / 1000.0, "ms enemies=", enemies.size())
	t_goal -= dt
	if t_goal <= 0.0: t_goal = 0.5; update_goal()
	_update_loot(dt)
	if not spawn_q.is_empty():
		var q: Array = spawn_q.pop_front()
		if not in_instance(): _spawn_enemy(q[0], q[1], q[2], q[3])
	elif not free_q.is_empty():
		var fe = free_q.pop_front()
		if is_instance_valid(fe): fe.queue_free()
	t_disc -= dt
	if t_disc <= 0.0: t_disc = 0.4; _check_world()
	t_ah -= dt
	if t_ah <= 0.0: t_ah = 1.0; ah_check()
	t_events -= dt
	if t_events <= 0.0: t_events = 2.0; _update_events()
	var rc := Color(World.REGIONS[max(1, cur_region)].sky) if not in_instance() else (Color(0.08, 0.07, 0.09) if dungeon else Color(0.1, 0.16, 0.3))
	if not in_instance(): rc = rc * sky_tint
	env.fog_light_color = env.fog_light_color.lerp(rc, min(1.0, dt * 1.5))
	_sky_update(dt)
	_guide(dt)
	ambient.global_position = player.global_position + Vector3(0, 2.0, 3.0)
	ambient.color = AMB_COL[World.REGIONS[max(1, cur_region)].tier] if not in_instance() else Color(0.6, 0.8, 1.0, 0.6)
	if not in_instance() and night > 0.3: ambient.color = Color(0.75, 1.0, 0.35, 0.9 * night)   # lucioles la nuit
	if cine.is_valid(): cine.call(dt)   # caméra de cinéma (vidéo promo)
	else: _cam_update(dt)
	hud.update(dt)
	if shot_mode:
		_shot_logic(dt)
		var nu := Time.get_ticks_usec()
		if has_meta("lu") and shot_t > 2.0 and nu - int(get_meta("lu")) > 10000: print("FRAME %.1fms en=%d t=%.2f" % [(nu - int(get_meta("lu"))) / 1000.0, enemies.size(), shot_t])
		set_meta("lu", nu)

func _context(_dt: float) -> void:
	var P := player
	if P.dead or hud.panel_open: return
	var pp := P.global_position
	# camp : forge / marché
	interact = ""
	talk_npc = null; var bd := 2.8
	for n in npcs:
		var dn := Vector2(n.position.x - pp.x, n.position.z - pp.z).length()
		if dn < bd: bd = dn; talk_npc = n
	if talk_npc: interact = "npc"
	hidden_sel = {}
	for hc in world.hidden_chests:
		if not Game.S.chests.has(hc.id) and Vector2(hc.pos.x - pp.x, hc.pos.z - pp.z).length() < 2.6: hidden_sel = hc
	chest_sp = {}
	for sp in world.spawns:
		if sp.has("chest") and sp.chest_ready and Vector2(pp.x - sp.pos.x, pp.z - sp.pos.z).length() < 2.8: chest_sp = sp
	var threat := _nearest_enemy(pp, 7.0, true)
	var nd: Dictionary = world.nearest_node(pp, 2.4) if threat == null and (not in_instance() or island != null) else {}
	entry_sel = {}
	var near_tower := not in_instance() and Vector2(world.tower_portal.x - pp.x, world.tower_portal.z - pp.z).length() < 3.0
	gate_sel = {}
	if not in_instance():
		for g in world.gates:
			if Vector2(g.pos.x - pp.x, g.pos.z - pp.z).length() < 3.4: gate_sel = g
	tower_sel = tower.near_chest(pp) if tower else {}
	var t_next := tower != null and tower.cleared and Vector2(tower.next_pos.x - pp.x, tower.next_pos.z - pp.z).length() < 2.0
	var t_exit := tower != null and Vector2(tower.exit_pos.x - pp.x, tower.exit_pos.z - pp.z).length() < 2.0
	isl_sel = island.near(pp) if island else {}
	if not in_instance():
		for en in dungeon_entries:
			if Vector2(en.pos.x - pp.x, en.pos.z - pp.z).length() < 2.8: entry_sel = en
	var d_chest := dungeon != null and not dungeon.chest_open and dungeon.chest != null and Vector2(dungeon.chest_pos.x - pp.x, dungeon.chest_pos.z - pp.z).length() < 2.8
	var d_exit := dungeon != null and dungeon.exit_open and Vector2(dungeon.exit_pos.x - pp.x, dungeon.exit_pos.z - pp.z).length() < 2.2
	gather_node = nd
	if interact == "npc": hud.set_main("talk", "PARLER", Color("#9fe0ff"), "talk"); hud.hint_lbl.text = "[right]%s · %s[/right]" % [talk_npc.nm, talk_npc.role]
	elif not isl_sel.is_empty():
		var lab: Dictionary = {"chest": ["OUVRIR", "Coffre de l'île"], "house": ["LOGIS", "Logis des ouvriers"], "field": ["CHAMP", "Parcelle cultivable"], "pen": ["ENCLOS", "Enclos d'élevage"], "boat": ["QUITTER", "Rentrer au port"]}[isl_sel.kind]
		hud.set_main("isl_" + isl_sel.kind, lab[0], Color("#ffd27a"), "chest"); hud.hint_lbl.text = "[right]%s[/right]" % lab[1]
	elif not gate_sel.is_empty():
		hud.set_main("gate", "VOYAGER", Color("#ffd27a"), "lock"); hud.hint_lbl.text = "[right]%s[/right]" % Maps.label(gate_sel.to)
	elif near_tower:
		hud.set_main("tower", "ENTRER", Color("#7fc0ff"), "lock")
		hud.hint_lbl.text = "[right]Tour Infinie · record : étage %d[/right]" % int(Game.S.tower.get("best", 0))
	elif not tower_sel.is_empty():
		if not tower.cleared: hud.set_main("guarded", "SCELLÉ", Color("#7fa8ff"), "lock"); hud.hint_lbl.text = "[right]Coffre scellé : bats le gardien de l'étage[/right]"
		else:
			var R0: Dictionary = Tower.RARITY[tower_sel.rarity]
			hud.set_main("tchest", "OUVRIR", R0.col, "chest"); hud.hint_lbl.text = "[right][color=#%s]Coffre %s[/color][/right]" % [R0.col.to_html(false), R0.name]
	elif t_next: hud.set_main("tnext", "MONTER", Color("#7fc0ff"), "lock"); hud.hint_lbl.text = "[right]Étage %d →[/right]" % (tower.floor_n + 1)
	elif t_exit: hud.set_main("texit", "SORTIR", Color("#bfe8ff"), "lock"); hud.hint_lbl.text = "[right]Quitter la tour[/right]"
	elif not entry_sel.is_empty():
		hud.set_main("enter", "ENTRER", Color("#c58bff"), "lock")
		hud.hint_lbl.text = "[right]Donjon %s · puissance conseillée %d (toi : %d)[/right]" % [hud.tier_tag(entry_sel.tier), Game.power_needed(entry_sel.tier), Game.power()]
	elif d_exit: hud.set_main("exit", "SORTIR", Color("#7fd0ff"), "lock"); hud.hint_lbl.text = "[right]Portail de sortie[/right]"
	elif d_chest:
		var guarded2 := dungeon.boss != null and is_instance_valid(dungeon.boss) and not dungeon.boss.dead
		hud.set_main("dchest" if not guarded2 else "guarded", "OUVRIR" if not guarded2 else "GARDÉ", Color("#ffd24a") if not guarded2 else Color("#ff7a6a"), "chest")
		hud.hint_lbl.text = "[right]%s[/right]" % ("Trésor du donjon !" if not guarded2 else "Bats le gardien du donjon d'abord")
	elif not hidden_sel.is_empty(): hud.set_main("hidden", "OUVRIR", Color("#ffd24a"), "chest"); hud.hint_lbl.text = "[right]Coffre caché ![/right]"
	elif not loot_sel.is_empty() and threat == null:
		hud.set_main("bag", "FOUILLER", Color("#ffd27a"), "chest"); hud.hint_lbl.text = "[right]%s[/right]" % {"boss": "Butin du boss", "elite": "Butin d'élite", "pvp": "Sac du joueur vaincu"}.get(loot_sel.kind, "Butin au sol")
	elif not chest_sp.is_empty():
		var guarded: bool = chest_sp.members.any(func(m): return is_instance_valid(m) and not m.dead)
		hud.set_main("chest" if not guarded else "guarded", "OUVRIR" if not guarded else "GARDÉ", Game.TIER_COL[chest_sp.tier] if not guarded else Color("#ff7a6a"), "lock")
		hud.hint_lbl.text = "[right]Coffre %s[/right]" % ("de la zone T%d" % chest_sp.tier if not guarded else "gardé : élimine les squelettes du camp")
	elif not nd.is_empty():
		var tool: String = Game.TOOL_OF[nd.type]
		var lv_ok: bool = Game.prof(tool).lvl >= Game.PROF_REQ[nd.tier]
		var ok: bool = (Game.S.gear[tool] >= nd.tier or nd.tier == 1) and lv_ok
		var col: Color = Game.TIER_COL[nd.tier]
		hud.set_main("gather" if ok else "locked", Game.RES[nd.type].verb if ok else "BLOQUÉ", col if ok else Color("#ff7a6a"), "gift" if ok else "lock")
		hud.hint_lbl.text = "[right]%s [color=#%s]%s T%d[/color] · %d/%d%s[/right]" % [Game.RES[nd.type].tiers[nd.tier], col.to_html(false), Game.RES[nd.type].name, nd.tier, nd.charges, nd.max, "" if ok else ("\n[color=#ff7a6a]Il te faut une %s T%d (%s, au village)[/color]" % [Game.TOOL_NAME[tool], nd.tier, Game.VENDOR_NAME[tool]] if lv_ok else "\n[color=#ff7a6a]%s niveau %d requis (tu es niveau %d)[/color]" % [Game.TOOL_NAME[tool], Game.PROF_REQ[nd.tier], Game.prof(tool).lvl])]
	else:
		hud.set_main("attack", "ATTAQUE", Hud.GOLD, "skull"); hud.hint_lbl.text = ""
	if hud.main_held():
		match hud.main_mode:
			"talk":
				hud.buttons.main.held = false; talk(talk_npc)
			"hidden":
				hud.buttons.main.held = false; open_hidden(hidden_sel)
			"bag":
				hud.buttons.main.held = false; open_bag(loot_sel)
			"enter":
				hud.buttons.main.held = false; enter_dungeon(entry_sel)
			"tower":
				hud.buttons.main.held = false; enter_tower(1)
			"gate":
				hud.buttons.main.held = false; _ask_gate(gate_sel)
			"isl_chest":
				hud.buttons.main.held = false; hud.show_island_chest()
			"isl_house":
				hud.buttons.main.held = false; hud.show_island()
			"isl_field":
				hud.buttons.main.held = false; island_field(isl_sel.i)
			"isl_pen":
				hud.buttons.main.held = false; hud.show_pen()
			"isl_boat":
				hud.buttons.main.held = false; leave_island()
			"tchest":
				hud.buttons.main.held = false; hud.show_loot(tower_sel)
			"tnext":
				hud.buttons.main.held = false; tower_next()
			"texit":
				hud.buttons.main.held = false; exit_tower()
			"exit":
				hud.buttons.main.held = false; exit_dungeon(true)
			"dchest":
				hud.buttons.main.held = false; open_dungeon_chest()
			"gather": P.gather(nd)
			"chest":
				hud.buttons.main.held = false; open_chest(chest_sp)
			"guarded":
				hud.buttons.main.held = false; Game.play("error")
			"locked":
				hud.buttons.main.held = false; Game.play("error")
				var tl: String = Game.TOOL_OF[nd.type]
				if Game.prof(tl).lvl < Game.PROF_REQ[nd.tier]: hud.toast("Métier trop faible : %s niveau %d requis pour le T%d" % [Game.TOOL_NAME[tl], Game.PROF_REQ[nd.tier], nd.tier], Color("#ff9a8a"))
				else: hud.toast("Il te faut une %s T%d : va voir %s au village" % [Game.TOOL_NAME[tl], nd.tier, Game.VENDOR_NAME[tl]], Color("#ff9a8a"))
			"attack":
				var wk: Dictionary = Game.wkind()
				var reach: float = float(wk.get("range", Player.REACH))
				var e = _nearest_enemy(pp, max(8.0, reach + 3.0))
				if e and pp.distance_to(e.global_position) > reach + e.radius - 0.2 and P.move_lock <= 0.0 and hud.move_vec().length() < 0.1:
					# s'approcher tout seul de la cible
					var d: Vector3 = e.global_position - pp; d.y = 0
					P.input_vec = Vector2(d.x, d.z).normalized()
				else: P.attack(e)

func _nearest_enemy(p: Vector3, r: float, only_aggro := false) -> Node3D:
	var best: Node3D = null; var bd := r
	for e in enemies:
		if e.dead: continue
		if only_aggro and e.state == "idle": continue
		var d := p.distance_to(e.global_position)
		if d < bd: bd = d; best = e
	return best

func on_gather_hit(nd: Dictionary) -> void:
	if nd.charges <= 0 or player.dead: return
	world.harvest(nd)
	if nd.has("isl") and island: Game.S.island.res.left[str(nd.isl)] = int(nd.charges)
	var tool: String = Game.TOOL_OF[nd.type]
	var lvl: int = Game.prof(tool).lvl
	var n := 1 + (1 if randf() < 0.03 + 0.01 * lvl + Game.TOOL_Q[Game.toolq(tool)].bonus else 0)
	Game.S.inv[nd.type][nd.tier] += n; Game.S.stats.gathered += n
	# XP de métier : plus le tier est haut, plus ça rapporte
	var xp: int = [0, 8, 14, 24, 40, 65][nd.tier]
	var ups := Game.add_prof_xp(tool, xp)
	hud.prof_gain(tool, xp)
	if ups > 0:
		var nl: int = Game.prof(tool).lvl
		player.level_glow(); Game.play("level", -2.0, 1.1)
		var unlock := ""
		for t in range(1, 6):
			if Game.PROF_REQ[t] == nl: unlock = " · tu peux récolter le T%d" % t
		hud.celebrate("%s NIVEAU %d !" % [Game.TOOL_NAME[tool].to_upper(), nl], "Récolte plus rapide%s" % unlock, "it_trophy")
	var col: Color = Game.TIER_COL[nd.tier]
	Fx.number(self, nd.pos + Vector3(0, 2.2, 0), "+%d %s T%d" % [n, Game.RES[nd.type].name, nd.tier], col, n > 1)
	var chip := {"wood": Color("#c99a56"), "ore": col, "fiber": Color("#e8f5a0")}[nd.type] as Color
	Fx.burst(self, nd.pos + Vector3(0, 1.0, 0), chip, 12, 4.0, 0.25, 0.5)
	Game.play({"wood": "chop", "ore": "mine", "fiber": "cut"}[nd.type], -3.0)
	shake(0.06)
	if nd.charges <= 0: hud.toast("Ressource épuisée — elle repoussera", Color(0.75, 0.75, 0.75))
	update_goal(); Game.save()

func gain_silver(n: int) -> int:
	n = int(n * (1.0 + Game.art_bonus("fortune"))); Game.S.silver += n; return n

# XP d'arme : chaque monstre tué près du héros fait progresser l'arme portée
func _weapon_xp(tier: int, mult: float) -> void:
	var kind: String = Game.S.get("weapon_kind", "epee")
	var xp := int([0, 6, 10, 16, 26, 40][clamp(tier, 1, 5)] * mult)
	var ups := Game.add_weapon_xp(kind, xp)
	hud.weapon_gain(kind, xp)
	if ups > 0:
		var lvl: int = Game.wxp(kind).lvl
		player.level_glow(Color(1.0, 0.55, 0.25)); Game.play("level", -2.0, 0.9)
		hud.celebrate("%s NIVEAU %d !" % [Game.WEAPON_KINDS[kind].name.to_upper(), lvl], "Maîtrise : +%.1f %% de dégâts" % (Game.weapon_bonus() * 100.0), "it_trophy")

# L'équipement porté gagne de l'expérience à chaque victoire et monte de niveau (+5 % par niveau, max 10)
func _gear_xp(tier: int, mult: float) -> void:
	var ups: Array = Game.gear_xp(int([0, 5, 8, 13, 20, 30][clamp(tier, 1, 5)] * mult))
	for sl in ups:
		var it := Game.equipped_item(sl)
		player.level_glow(Color(0.55, 0.85, 1.0)); Game.play("level", -4.0, 1.2)
		hud.celebrate("%s NIVEAU %d !" % [Game.SLOT_NAME[sl].to_upper(), int(Game.eqx(sl).lvl)], "%s gagne en puissance (+5 %%)" % Game.item_name(it), "it_trophy")
	if not ups.is_empty(): player.refresh_gear()

func on_enemy_death(e: Enemy) -> void:
	var killer = e.last_from
	var mine: bool = killer == null or not is_instance_valid(killer) or killer == player or killer is Ally or killer is Player
	var fam := "beast" if e.animal else ("man" if e.kind in ["bandit", "duel"] else "skel")
	if not mine:
		# tué par un autre joueur : le butin est à lui, pas à toi
		if killer is Bot and randf() < 0.4: drop_loot(e.global_position, "mob", e.tier, [{"silver": 1}], killer)
		for sp in world.spawns:
			if e in sp.members and sp.members.all(func(m): return not is_instance_valid(m) or m.dead): sp.dead_at = Time.get_ticks_msec() / 1000.0
		return
	Game.S.stats.kills += 1
	if e.global_position.distance_to(player.global_position) < 30.0 and not player.dead: _weapon_xp(e.tier, 10.0 if e.is_boss else (3.0 if e.elite else 1.0))
	if e.global_position.distance_to(player.global_position) < 30.0 and not player.dead: _gear_xp(e.tier, 10.0 if e.is_boss else (3.0 if e.elite else 1.0))
	if not e.is_boss and e.duel_info.is_empty():
		var silver := gain_silver(int(Game.money(e.tier) * (2.0 if e.elite else 0.7) * randf_range(0.6, 1.2)) + 1)
		Fx.number(self, e.global_position + Vector3(0, 2.6, 0), "+%s" % Game.fmt(silver), Color("#ffd86b"), false, true)
		Game.play("coin", -10.0)
	if e.duel_info.size() > 0: _duel_won(e)
	elif e.group_boss: _group_boss_down(e)
	elif e.is_boss and not (tower and e == tower.boss): drop_loot(e.global_position, "boss", e.tier, Game.roll_loot("elite" if dungeon and e == dungeon.boss else "boss", e.tier, fam))
	elif e.elite: drop_loot(e.global_position, "elite", e.tier, Game.roll_loot("elite", e.tier, fam))
	elif not e.is_boss and randf() < (0.22 if not e.animal else 0.15) * (1.6 if was_night else 1.0): drop_loot(e.global_position, "mob", e.tier, Game.roll_loot("mob", e.tier, fam))
	if e.kind == "boss" and not e.camp.get("dungeon", false):
		Game.S.stats.boss += 1; hud.celebrate("LE SEIGNEUR D'OS EST VAINCU !", "Ramasse son trésor — Valdrune est sauvée", "it_trophy"); Game.play("level")
		boss_ref = null
	if island and e.camp.has("bandit_group"): _bandit_down(e)
	if tower and e == tower.boss:
		if tower.floor_n >= 10 and randf() < 0.05: _rare_mount("Le gardien de la tour")
		hud.celebrate("GARDIEN DE L'ÉTAGE %d VAINCU !" % tower.floor_n, "Les coffres se libèrent…", "it_key"); Game.play("level")
		tower.on_boss_dead(); Game.save()
	if dungeon and e == dungeon.boss and randf() < 0.03: _rare_mount("Le gardien du donjon")
	if dungeon and e == dungeon.boss:
		hud.celebrate("GARDIEN VAINCU !", "Ouvre le coffre doré — le portail de sortie est ouvert", "it_key"); Game.play("level")
		dungeon.open_exit()
	for sp in world.spawns:
		if e in sp.members and sp.members.all(func(m): return not is_instance_valid(m) or m.dead): sp.dead_at = Time.get_ticks_msec() / 1000.0
	Game.save()

func on_boss_aggro(b: Enemy) -> void:
	boss_ref = b
	if b.camp.has("bandit_group"): hud.toast("Le chef des bandits entre dans la bataille !", Color("#ff6a5a"), true)
	elif b.camp.get("dungeon", false): hud.toast("Le gardien passe à l'attaque !", Color("#8fd0ff"), true)
	elif b.kind == "boss": hud.toast("Le Seigneur d'Os se réveille !", Color("#ff6a5a"), true)
	elif b.group_boss: hud.toast("%s vous a repérés !" % b.def.name, Color("#d58bff"), true)
	Game.play("roar")

func boss_summon(b: Enemy) -> void:
	hud.toast("Le Seigneur d'Os appelle ses serviteurs !", Color("#ff6a5a"))
	var sp: Dictionary = b.camp
	for i in 3:
		var p := b.global_position + World.polar(TAU * i / 3.0, 4.0)
		var e := _spawn_enemy("minion" if i < 2 else "warrior", 5, p, sp); e.state = "chase"

func on_player_death() -> void:
	var killer = player.last_attacker
	if killer is Bot and is_instance_valid(killer) and world.map_id >= 2 and not in_instance(): _robbed_by(killer)
	else: hud.toast("Tu es tombé… retour au camp. Tes ressources sont sauves.", Color("#ff8a7a"), true)
	if duel_enemy: hud.toast("Duel perdu ! %s t'attend pour une revanche." % duel_enemy.def.name, Color("#ffb07a"))
	get_tree().create_timer(2.6).timeout.connect(func():
		if dungeon: exit_dungeon(false)
		if tower: exit_tower(false)
		if island: leave_island(false)
		player.revive(camp_spawn + Vector3(0, world.height(0, 4.5) + 0.3, 0))
		for a in allies:
			if is_instance_valid(a) and not a.dead: a.global_position = player.global_position + Vector3(randf_range(-2, 2), 0.5, randf_range(-2, 2)); a.hp = a.max_hp
		for e in enemies:
			if not e.dead and e.state != "idle": e.state = "return"
	)

func teleport_camp() -> void:
	player.revive(camp_spawn + Vector3(0, world.height(camp_spawn.x, camp_spawn.z) + 0.3, 0)); player.hp = player.max_hp

# ——— Apparition paresseuse des camps de monstres (performance) ———
func _update_spawns() -> void:
	var pp := player.global_position; var now := Time.get_ticks_msec() / 1000.0
	for sp in world.spawns:
		var d: float = pp.distance_to(sp.pos)
		var alive: Array = sp.members.filter(func(m): return is_instance_valid(m) and not m.dead)
		if alive.is_empty() and d < 46.0 and now - sp.dead_at > (90.0 if sp.get("boss", false) else 50.0):
			sp.members.clear()
			# le coffre d'un repaire ne se remplit qu'au bout de 20 minutes
			if sp.has("chest") and not sp.chest_ready and now - float(sp.get("chest_open_at", -9999.0)) > 1200.0:
				sp.chest_ready = true; sp.chest.scale = Vector3.ONE * 1.1
			# apparition étalée : un monstre par image (un camp entier d'un coup faisait geler l'image)
			sp.dead_at = now
			for i in sp.kinds.size():
				var p: Vector3 = sp.pos + World.polar(TAU * i / sp.kinds.size() + 0.5, 2.2 if sp.kinds.size() > 1 else 0.0)
				spawn_q.append([sp.kinds[i], sp.tier, p, sp])
		elif d > 62.0 and not alive.is_empty() and alive.all(func(m): return m.state == "idle"):
			for m in alive: enemies.erase(m); free_q.append(m)
			sp.members.clear(); sp.dead_at = -999.0
	enemies = enemies.filter(func(e): return is_instance_valid(e))

func _spawn_enemy(kind: String, tier: int, p: Vector3, sp: Dictionary, can_elite := true, extra := {}) -> Enemy:
	var e := Enemy.new(); add_child(e)
	p.y = world.height(p.x, p.z) + 0.3
	e.setup(self, kind, tier, p, sp, can_elite and kind != "boss" and tier >= 2 and randf() < (0.24 if was_night and not in_instance() else 0.14), extra); sp.members.append(e); enemies.append(e)
	if was_night and not in_instance() and sp.has("kinds"):
		# la nuit : +25 % de vie et de dégâts
		e.max_hp *= 1.25; e.hp = e.max_hp; e.def.dmg *= 1.25
	return e

# ——— Forge & marché ———
func craft(item: String, t: int, kind := "") -> void:
	var cost := Game.recipe(item, t)
	if not Game.has_cost(cost): Game.play("error"); return
	Game.pay(cost)
	# l'ancienne pièce va dans le sac (on peut la revendre à l'hôtel des ventes)
	var old := {"slot": item, "tier": Game.S.gear[item]}
	if item == "armure": old["kind"] = Game.S.get("armor_kind", "plate")
	if item == "epee": old["kind"] = Game.S.get("weapon_kind", "epee")
	Game.S.items.append(old)
	Game.S.gear[item] = t
	if item == "armure": Game.S.armor_kind = kind if kind != "" else Game.S.get("armor_kind", "plate")
	if item == "epee": Game.S.weapon_kind = kind if kind != "" else Game.S.get("weapon_kind", "epee")
	Game.play("craft"); Game.play("level", -6.0)
	var nm := Game.item_name({"slot": item, "tier": t, "kind": Game.S.get("weapon_kind", "epee") if item == "epee" else Game.S.get("armor_kind", "plate")})
	hud.celebrate("ÉTAPE ACCOMPLIE !", "%s : c'est fait ! L'ancien objet est dans ton sac" % nm, "it_quest")
	player.refresh_gear()
	if item == "armure": player.hp = player.max_hp
	Fx.burst(self, _brokk_pos() + Vector3(0, 1.2, 0), Game.TIER_COL[t], 26, 5.0, 0.35, 0.8)
	Game.save(); update_goal(); hud.show_forge("Et voilà du travail bien fait !")

func equip_from_bag(idx: int) -> void:
	var why: String = Game.equip_block(Game.S.items[idx])
	if why != "": Game.play("error"); hud.toast(why, Color("#ff9a8a")); return
	Game.equip(idx); player.refresh_gear(); Game.play("craft", -6.0, 1.3); Game.save(); update_goal(); hud.show_bag()

# ——— Hôtel des ventes ———
func now_s() -> float: return Time.get_unix_time_from_system()

func ah_refresh_stock(force := false) -> void:
	var ah: Dictionary = Game.S.ah
	if not force and now_s() - float(ah.stock_at) < 300.0 and not ah.stock.is_empty(): return
	var keep: Array = ah.stock.filter(func(x): return x.has("seller")).slice(0, 4)
	ah.stock = keep; ah.stock_at = now_s()
	var lvl := Game.gear_level()
	# vitrine : toujours quelques pièces haut de gamme qui font rêver
	for t2 in [min(5, max(lvl, 1) + 2), 5]:
		var hi := Game.random_item(t2) if randf() > 0.2 else Game.random_artefact(t2)
		if hi.slot in Game.ENCH_SLOTS and randf() < 0.5: hi["ench"] = randi_range(1, 3)
		hi["price"] = int(Game.item_price(hi) * randf_range(1.05, 1.35)); hi["seller"] = Bot.NAMES[randi() % Bot.NAMES.size()]
		ah.stock.append(hi)
	# montures : toujours un âne abordable, et quelques bêtes plus rares
	var donkey := {"slot": "monture", "tier": 1, "kind": "ane"}; donkey["price"] = int(Game.item_price(donkey) * randf_range(0.95, 1.2)); ah.stock.append(donkey)
	for k in 3:
		var mo := Game.random_mount(5); mo["price"] = int(Game.item_price(mo) * randf_range(0.95, 1.4)); mo["seller"] = Bot.NAMES[randi() % Bot.NAMES.size()]; ah.stock.append(mo)
	# beaucoup de choix, tous les tiers (même ceux qu'on ne peut pas encore porter)
	for i in 44:
		var t: int = clamp(lvl + randi_range(-1, 1) + (1 if randf() < 0.25 else 0), 1, Game.MAX_TIER) if randf() < 0.45 else randi_range(1, 5)
		var roll := randf()
		var e := {}
		if roll < 0.7:
			e = Game.random_item(t, true) if randf() > 0.07 else Game.random_artefact(t)
			if randf() < 0.3: e["seller"] = Bot.NAMES[randi() % Bot.NAMES.size()]
			if randf() < 0.12 and e.slot in Game.ENCH_SLOTS: e["ench"] = randi_range(1, 3)
			e["price"] = int(Game.item_price(e) * randf_range(0.95, 1.45))
		else:
			var k: String = Game.RES_KEYS[randi() % 3]
			e = {"res": k, "tier": t, "qty": 10, "price": int(Game.res_price(t) * 10 * randf_range(1.0, 1.5))}
		ah.stock.append(e)

func ah_buy(i: int) -> void:
	var e: Dictionary = Game.S.ah.stock[i]
	if Game.S.silver < e.price: Game.play("error"); hud.toast("Pas assez d'argent", Color("#ff9a8a")); return
	if e.has("res"):
		Game.S.inv[e.res][e.tier] += e.qty
	else:
		var it := {"slot": e.slot, "tier": e.tier}
		for key in ["kind", "ench", "bx", "lvl", "xp", "q", "nm"]:
			if e.has(key): it[key] = e[key]
		if not Game.add_item(it): hud.toast("Ton sac est plein (%d cases)" % Game.bag_size(), Color("#ff9a8a")); Game.play("error"); return
	Game.S.silver -= e.price; Game.S.ah.stock.remove_at(i)
	Game.play("coin"); hud.toast("Acheté !", Color("#9dffb0")); Game.save(); update_goal(); hud.show_auction("buy")

# Prix réel d'une entrée du sac
func real_price(e: Dictionary) -> int:
	if e.has("res"): return Game.res_price(e.tier) * e.qty
	return Game.item_price(e)

static func sell_chance(price: int, real: int) -> float:
	var r: float = float(price) / max(1.0, real)
	return clamp(1.6 - 0.9 * r, 0.03, 0.97)

func ah_list(e: Dictionary, price: int) -> void:
	# on retire l'objet du sac et on le met en vente (résultat dans 20 à 60 s)
	if e.has("res"):
		if Game.S.inv[e.res][e.tier] < e.qty: return
		Game.S.inv[e.res][e.tier] -= e.qty
	else:
		Game.S.items.remove_at(e.idx)
	var l := e.duplicate(); l.erase("idx")
	l["price"] = price; l["real"] = real_price(e); l["end"] = now_s() + randf_range(20.0, 60.0)
	Game.S.ah.listings.append(l)
	Game.play("coin", -4.0); hud.toast("Mis en vente à %d — résultat dans moins d'une minute" % price, Color("#ffe39a")); Game.save()
	hud.show_auction("mine")

func ah_check() -> void:
	var L: Array = Game.S.ah.listings
	var changed := false
	for l in L.duplicate():
		if l.has("done"): continue
		if now_s() < float(l.end): continue
		changed = true
		var sold := randf() < sell_chance(int(l.price), int(l.real))
		var nm: String = Game.res_name(l.res, int(l.tier)) + " ×%d" % int(l.qty) if l.has("res") else Game.item_name(l)
		if sold:
			var gain := int(l.price * 0.95)
			Game.S.silver += gain
			hud.celebrate("VENDU !", "%s · +%s argent (taxe 5 %%)" % [nm, Game.fmt(gain)], "it_coins"); Game.play("coin")
		else:
			if l.has("res"): Game.S.inv[l.res][int(l.tier)] += int(l.qty)
			else:
				var it := {"slot": l.slot, "tier": int(l.tier)}
				for key in ["kind", "ench", "bx", "lvl", "xp", "q", "nm"]:
					if l.has(key): it[key] = l[key]
				Game.S.items.append(it)
			hud.toast("Invendu : %s — rendu dans ton sac (prix trop élevé ?)" % nm, Color("#ffb59a"))
		L.erase(l)
	if changed:
		Game.save()
		if hud.panel_open and hud.cur_panel == "auction": hud.show_auction(hud.ah_tab)

func buy_potion() -> void:
	if Game.S.silver < 40: return
	Game.S.silver -= 40; Game.S.potions += 1; Game.play("coin"); Game.save(); hud.show_shop()

# Bric-à-brac : vendu sur-le-champ à la marchande (-1 = tout)
func sell_junk(idx: int) -> void:
	var gain := 0
	if idx >= 0:
		gain = Game.junk_price(Game.S.items[idx]); Game.S.items.remove_at(idx)
	else:
		for it in Game.S.items.filter(func(x): return x.slot == "junk"): gain += Game.junk_price(it)
		Game.S.items = Game.S.items.filter(func(x): return x.slot != "junk")
	Game.S.silver += gain; Game.play("coin")
	hud.toast("Bric-à-brac vendu : +%s argent" % Game.fmt(gain), Color("#ffe39a")); Game.save()
	if hud.cur_panel == "bag": hud.show_bag()
	elif hud.cur_panel == "shop": hud.show_shop()

func sell(k: String, t: int, n: int) -> void:
	n = min(n, Game.S.inv[k][t]); if n <= 0: return
	Game.S.inv[k][t] -= n; Game.S.silver += n * Game.res_price(t); Game.play("coin"); Game.save(); hud.show_shop()

# ——— Objectif : toujours UNE prochaine étape claire ———
func _brokk_pos() -> Vector3:
	for n in npcs:
		if n.act == "forge": return n.position
	return world.forge_pos

func _vendor(tl: String) -> Npc:
	for n in npcs:
		if (n.act == "tools" and n.data.get("tool", "") == tl) or n.act == "tools3": return n
	return null

# Passage de la carte actuelle qui mène (de proche en proche) vers la carte voulue
func _gate_toward(target_map: int):
	for g in world.gates:
		if (target_map > world.map_id and g.to > world.map_id) or (target_map < world.map_id and g.to < world.map_id): return g.pos
	return null

func _nearest_node(k: String, t: int):
	var best = null; var bd := 1e9
	for nd in world.nodes:
		if nd.type == k and nd.tier == t and nd.charges > 0:
			var d: float = nd.pos.distance_to(player.global_position)
			if d < bd: bd = d; best = nd.pos
	return best

func _npc_pos(id: String):
	for n in npcs:
		if n.id == id: return n.position
	return null

# Progression : les MÉTIERS ouvrent les tiers (XP), les marchands vendent les outils, Brokk fabrique l'équipement
func update_goal() -> void:
	var S := Game.S
	var txt := ""; var tgt = null
	# 1) outil le plus en retard
	var best_tool := ""; var best_score := 99.0
	for tl in Game.TOOL_SLOTS:
		var t: int = S.gear[tl]
		if t >= Game.MAX_TIER: continue
		var need: int = Game.PROF_REQ[t + 1]; var lv: int = Game.prof(tl).lvl
		var score: float = t + clamp(float(lv) / need, 0.0, 1.0) * 0.99
		if score < best_score: best_score = score; best_tool = tl
	var L := Game.gear_level()
	var wk: String = Game.S.get("weapon_kind", "epee")
	var nxt: int = int(Game.S.gear.epee) + 1
	var wblock: String = Game.equip_block({"slot": "epee", "tier": nxt, "kind": wk}) if nxt <= 5 else "max"
	if Game.S.gear.epee < L and wblock.begins_with("Maîtrise"):
		var wl: int = int(Game.wxp(wk).lvl)
		txt = "[b]Maîtrise %s : niveau %d / %d[/b]\n[color=#b8c0c8]Combats des monstres avec ton arme pour pouvoir porter le %s.[/color]" % [Game.WEAPON_KINDS[wk].name.to_lower(), wl, Game.WREQ[nxt], hud.tier_tag(nxt)]
	elif Game.S.gear.epee < L:
		txt = "[b]Équipe-toi : arme %s[/b]\n[color=#b8c0c8]L'armurier de la ville vend et fabrique les armes avec ton bois, ton minerai et ta fibre.[/color]" % hud.tier_tag(nxt)
		tgt = _brokk_pos()
	elif best_tool != "":
		var tl: String = best_tool; var t: int = S.gear[tl]; var nt := t + 1
		var k: String = {"hache": "wood", "pioche": "ore", "faucille": "fiber"}[tl]
		var p := Game.prof(tl)
		if int(p.lvl) < Game.PROF_REQ[nt]:
			txt = "[b]%s : niveau %d / %d[/b]\n[color=#b8c0c8]Récolte du %s %s pour gagner de l'XP. Au niveau %d tu pourras passer au %s.[/color]" % [Game.PROF_TITLE[tl], p.lvl, Game.PROF_REQ[nt], Game.RES[k].name, hud.tier_tag(t), Game.PROF_REQ[nt], hud.tier_tag(nt)]
			tgt = _nearest_node(k, t)
		else:
			var price := Game.tool_price(nt, 0)
			txt = "[b]Achète une %s %s[/b]\n[color=#b8c0c8]Chez %s, au village — à partir de %s argent (%s / %s)[/color]" % [Game.TOOL_NAME[tl], hud.tier_tag(nt), Game.VENDOR_NAME[tl], Game.fmt(price), Game.fmt(S.silver), Game.fmt(price)]
			tgt = _npc_pos(Game.VENDOR_OF[tl])
			if S.silver < price:
				txt += "\n[color=#ffd27a]Vends tes ressources au marché ou à l'hôtel des ventes pour réunir la somme.[/color]"
	elif S.stats.boss == 0 and L >= 4:
		txt = "[b]Dernière épreuve[/b]\nTerrasse le [color=#ff6a5a]Seigneur d'Os[/color] dans son antre — Pics de Cendre (carte T4-T5), tout au nord."
		tgt = world.boss_pos if world.map_id == 4 else _gate_toward(4)
	elif L < 5 and world.map_id < Maps.for_tier(L + 1) and Game.power() >= Game.power_needed(Maps.TIERS[Maps.for_tier(L + 1)][0]) * 0.8:
		var nm2 := Maps.for_tier(L + 1)
		txt = "[b]En route vers %s[/b]\n[color=#b8c0c8]Tu es prêt pour la carte T%d-T%d : suis la flèche jusqu'au passage.[/color]" % [Maps.NAMES[nm2], Maps.TIERS[nm2][0], Maps.TIERS[nm2][1]]
		tgt = _gate_toward(nm2)
	else:
		txt = "[b]Valdrune est sauvée ![/b]\nTour Infinie, donjons, duels : deviens le plus riche du royaume."
	if txt != goal_text:
		goal_text = txt; hud.goal_lbl.text = txt
		var key := "buy" if txt.begins_with("[b]Achète") else "x"
		if key == "buy" and last_goal_key != "buy" and last_goal_key != "": hud.celebrate("NIVEAU ATTEINT !", "Tu peux acheter un outil du tier suivant", "it_quest"); Game.play("level", -4.0)
		last_goal_key = key
	goal_target = tgt

# Aldric résume la quête en mots simples
func quest_line() -> String:
	var plain := goal_text.replace("[b]", "").replace("[/b]", "").replace("\n", " — ")
	var rx := RegEx.new(); rx.compile("\\[/?color[^\\]]*\\]"); plain = rx.sub(plain, "", true)
	if Game.gear_level() <= 1 and Game.S.stats.gathered == 0:
		return "Bienvenue, jeune aventurier. Valdrune a besoin de toi. Commence par récolter des ressources autour du village, puis va voir Brokk à la forge pour de meilleurs outils. Chaque nouvel outil t'ouvre une région plus lointaine… et plus dangereuse.\n\n[color=#ffd27a]%s[/color]" % plain
	return "Ta prochaine tâche : [color=#ffd27a]%s[/color]\n\nSuis la flèche dorée, elle te guidera." % plain

# ——— Dialogues ———
func talk(n: Npc) -> void:
	if n == null: return
	Game.play("pickup", -8.0, 0.8)
	var first: bool = not Game.S.met.has(n.id)
	var line := n.next_line()
	if n.act == "duel": line = ""
	if first and n.act == "talk":
		Game.S.met[n.id] = 1; Game.S.silver += 15; line += "\n\n[color=#ffd86b]+15 argent (nouvelle rencontre)[/color]"; Game.save()
	elif first: Game.S.met[n.id] = 1; Game.save()
	var acts := []
	match n.act:
		"forge":
			acts.append(["Acheter des armes", func(): hud.show_armurier("buy"), true])
			acts.append(["Fabriquer", func(): hud.show_armurier("craft"), true])
		"tools": acts.append(["Voir les outils", func(): hud.show_tools(n.data.tool), true])
		"tools3":
			acts.append(["Haches", func(): hud.show_tools("hache"), true])
			acts.append(["Pioches", func(): hud.show_tools("pioche"), true])
			acts.append(["Faucilles", func(): hud.show_tools("faucille"), true])
		"travel":
			_talk_travel(n); return
		"harbor":
			if Game.S.island.owned: acts.append(["Embarquer pour mon île", func(): hud.close_panel(); go_island(), true])
			acts.append(["Voir les îles", func(): hud.show_harbor(), true])
		"shop": acts.append(["Voir les articles", func(): hud.show_shop(line), true])
		"auction": acts.append(["Ouvrir l'hôtel des ventes", func(): hud.show_auction(), true])
		"mercs": acts.append(["Engager des mercenaires", func(): hud.show_mercs(), true])
		"enchant": acts.append(["Enchanter mon équipement", func(): hud.show_enchant(), true])
		"duel":
			_talk_duel(n); return
	acts.append(["Au revoir", func(): hud.close_panel()])
	if n.act in ["talk", "quest"] and n.id != "aldric": acts.insert(0, ["Encore", func(): talk(n)])
	hud.show_dialog(n, line, acts)

# ——— Régions, découvertes ———
func _check_world() -> void:
	if in_instance(): return
	var pp := player.global_position
	var r := world.region_at(pp.x, pp.z)
	if r != cur_region:
		var first := cur_region == 0
		cur_region = r
		var R: Dictionary = World.REGIONS[r]
		hud.set_region(R.name, R.tier)
		if not first:
			hud.region_banner(R.name, R.tier)
			if R.tier >= 3 and world.map_id >= 2: get_tree().create_timer(1.2).timeout.connect(func(): hud.toast("ZONE ROUGE : des joueurs hostiles peuvent te prendre ton équipement à tout moment.", Color("#ff5a4a"), true))
			if R.tier > Game.S.gear.epee: get_tree().create_timer(2.0).timeout.connect(func(): hud.toast("Ton arme est T%d : les monstres d'ici sont T%d. Prudence !" % [Game.S.gear.epee, R.tier], Color("#ff9a7a")))
	for poi in world.pois:
		if Game.S.disc.has(poi.id): continue
		if Vector2(poi.pos.x - pp.x, poi.pos.z - pp.z).length() < poi.r:
			Game.S.disc[poi.id] = 1
			var reward: int = int(5 * Game.money(World.REGIONS[poi.region].tier)) + 20
			Game.S.silver += reward
			hud.celebrate("LIEU DÉCOUVERT", "%s  · +%s argent" % [poi.name, Game.fmt(reward)], "it_treasure_map")
			Game.play("level", -6.0); Game.save()

func open_hidden(hc: Dictionary) -> void:
	Game.S.chests[hc.id] = 1
	var c: Node3D = hc.node
	var tw := c.create_tween(); tw.tween_property(c, "scale", c.scale * 1.3, 0.12); tw.tween_property(c, "scale", c.scale * 0.0001, 0.3)
	Game.play("craft", -2.0, 0.8); Game.play("coin")
	Fx.burst(self, hc.pos + Vector3(0, world.height(hc.pos.x, hc.pos.z) + 1.0, 0), Color("#ffd24a"), 34, 6.0, 0.4, 0.8)
	hud.toast("Coffre caché ! %d / %d trouvés sur cette carte" % [_hidden_found(), world.hidden_chests.size()], Color("#ffd24a"), true)
	hud.show_loot({"title": "Coffre caché", "rarity": 1, "loot": Game.roll_loot("hidden", max(1, hc.tier), "man"), "pos": hc.pos, "opened": false})
	Game.save()

func _hidden_found() -> int:
	var n := 0
	for hc in world.hidden_chests:
		if Game.S.chests.has(hc.id): n += 1
	return n

func _guide(dt: float) -> void:
	var P := player
	if goal_target == null or P.dead:
		arrow.visible = false; beacon.visible = false; return
	var tg: Vector3 = goal_target
	var d := Vector2(tg.x - P.global_position.x, tg.z - P.global_position.z)
	beacon.visible = true; beacon.global_position = Vector3(tg.x, world.height(tg.x, tg.z) + 7.0, tg.z)
	if d.length() < 3.0: arrow.visible = false; return
	arrow.visible = true
	var u := d.normalized(); var pulse := 2.2 + sin(Time.get_ticks_msec() * 0.006) * 0.25
	var ap := P.global_position + Vector3(u.x, 0, u.y) * pulse
	arrow.global_position = Vector3(ap.x, world.height(ap.x, ap.z) + 0.15, ap.z)
	arrow.rotation.y = atan2(u.x, u.y)

# ——— Caméra ———
func shake(a: float) -> void: shake_amt = max(shake_amt, a)

func _cam_update(dt: float, snap := false) -> void:
	var P := player
	var target := P.global_position + Vector3(P.velocity.x, 0, P.velocity.z) * 0.12
	var off := Vector3(0, 14.5, 6.4) * cam_zoom * user_zoom   # un peu plus plongeante : moins d'obstacles devant le héros
	# inventaire ouvert : le héros glisse vers la gauche de l'écran pour rester visible à côté du parchemin
	bag_shift = lerp(bag_shift, 5.2 * cam_zoom * user_zoom if hud.cur_panel == "bag" else 0.0, 1.0 if snap else 1.0 - exp(-dt * 6.0))
	target.x += bag_shift
	if boss_ref and is_instance_valid(boss_ref) and not boss_ref.dead: off *= 1.25
	_update_fade(off.length())
	var want := target + off
	cam.global_position = want if snap else cam.global_position.lerp(want, 1.0 - exp(-dt * 8.0))
	cam.look_at(cam.global_position - off + Vector3(0, 1.0, 0))
	if shake_amt > 0.0:
		cam.global_position += Vector3(randf_range(-1, 1), randf_range(-1, 1), 0) * shake_amt * 0.5
		shake_amt = max(0.0, shake_amt - dt * 1.6)

# ——— Vision : tout ce qui passe entre la caméra et le héros devient transparent ———
var user_zoom := 1.0
var bag_shift := 0.0
var fade_mats: Array = []
var fade_seen := {}
var fade_d := -1.0
func fade_register(n: Node) -> void:
	return   # (remplacé par la disparition des arbres : le tramage coûtait trop cher sur mobile)
	if n is MeshInstance3D:
		var mi := n as MeshInstance3D
		if mi.material_override: _fade_mat(mi.material_override)
		if mi.mesh:
			for i in mi.mesh.get_surface_count():
				_fade_mat(mi.get_surface_override_material(i)); _fade_mat(mi.mesh.surface_get_material(i))
	elif n is MultiMeshInstance3D:
		var mm := n as MultiMeshInstance3D
		if mm.material_override: _fade_mat(mm.material_override)
		if mm.multimesh and mm.multimesh.mesh:
			for i in mm.multimesh.mesh.get_surface_count(): _fade_mat(mm.multimesh.mesh.surface_get_material(i))
	for c in n.get_children():
		if c is Player or c is Enemy or c is Npc or c is Ally or c is Bot: continue
		fade_register(c)

func _fade_mat(m) -> void:
	# seulement les modèles texturés (arbres, rochers, bâtiments, murs) — jamais le sol ni l'eau
	if not (m is BaseMaterial3D) or m.albedo_texture == null or fade_seen.has(m.get_instance_id()): return
	fade_seen[m.get_instance_id()] = true
	m.distance_fade_mode = BaseMaterial3D.DISTANCE_FADE_PIXEL_DITHER
	fade_mats.append(m)
	fade_d = -1.0

func _update_fade(d: float) -> void:
	if abs(d - fade_d) < 0.3: return
	fade_d = d
	for m in fade_mats:
		m.distance_fade_min_distance = d * 0.6
		m.distance_fade_max_distance = d * 0.82

func cycle_zoom() -> void:
	user_zoom = {1.0: 1.3, 1.3: 0.8, 0.8: 1.0}.get(user_zoom, 1.0)
	hud.toast("Zoom caméra : %s" % {1.0: "normal", 1.3: "large", 0.8: "proche"}[user_zoom], Color("#cfe8ff"))

# ——— Mode test (captures automatiques) ———
var shot_i := 0
func _shot_logic(dt: float) -> void:
	shot_t += dt
	var plan: Array = get_meta("plan", [])
	if shot_i >= plan.size(): get_tree().quit(); return
	var step: Dictionary = plan[shot_i]
	if shot_t >= step.t:
		if step.has("pos"): player.global_position = step.pos + Vector3(0, world.height(step.pos.x, step.pos.z) + 0.3, 0); _cam_update(1.0, true)
		if step.has("call"): (step.call as Callable).call()
		if step.has("png"): get_viewport().get_texture().get_image().save_png(step.png); print("SHOT ", step.png, " fps=", Engine.get_frames_per_second())
		shot_i += 1


# ——— Butin au sol : un sac (ou un coffre) qu'on fouille — la fenêtre montre ce qu'il contient ———
# Le butin d'un autre joueur reste à lui : impossible de passer derrière pour le prendre.
func drop_loot(p: Vector3, kind: String, tier: int, loot: Array, owner: Node = null) -> void:
	if loot.is_empty(): return
	var sp := Sprite3D.new(); sp.texture = hud.T({"mob": "it_loot_common", "elite": "it_loot_rare", "boss": "it_chest_open", "pvp": "it_loot_rare"}.get(kind, "it_loot_common"))
	sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sp.pixel_size = {"mob": 0.0075, "elite": 0.009, "boss": 0.012, "pvp": 0.009}.get(kind, 0.008); sp.no_depth_test = false; sp.shaded = false
	if owner != null: sp.modulate = Color(0.6, 0.6, 0.65, 0.85)
	var a := randf() * TAU; var tgt := p + Vector3(cos(a), 0, sin(a)) * randf_range(0.6, 1.4)
	if kind == "boss": tgt = p + Vector3(0, 0, 0.8)
	tgt.y = world.height(tgt.x, tgt.z) + 0.55
	sp.position = p + Vector3(0, 1.2, 0); add_child(sp)
	var glow := Sprite3D.new(); glow.texture = Fx.soft_tex(); glow.billboard = BaseMaterial3D.BILLBOARD_ENABLED; glow.pixel_size = 0.05 if kind != "boss" else 0.08
	glow.modulate = (Color(1, 0.8, 0.3, 0.7) if kind != "mob" else Color(1, 1, 1, 0.35)) if owner == null else Color(0.5, 0.5, 0.55, 0.25)
	glow.position = Vector3(0, -0.1, -0.01); glow.render_priority = -1; sp.add_child(glow)
	if owner != null:
		var l := Label3D.new(); l.text = "Butin de %s" % owner.nm; l.font_size = 30; l.outline_size = 8; l.modulate = Color(0.75, 0.75, 0.8); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.pixel_size = 0.0065; l.position.y = 0.7; l.no_depth_test = true; sp.add_child(l)
	var tw := sp.create_tween(); tw.tween_property(sp, "position", tgt + Vector3(0, 0.9, 0), 0.18); tw.tween_property(sp, "position", tgt, 0.25).set_trans(Tween.TRANS_BOUNCE).set_ease(Tween.EASE_OUT)
	loots.append({"node": sp, "kind": kind, "tier": tier, "pos": tgt, "t": randf() * 3.0, "age": 0.0, "loot": loot, "owner": owner, "bag": true, "rarity": {"mob": 0, "elite": 1, "pvp": 1, "boss": 2}.get(kind, 0)})

var loot_sel := {}
func _update_loot(dt: float) -> void:
	var pp := player.global_position
	loot_sel = {}; var bd := 2.2
	for l in loots.duplicate():
		l.age += dt; l.t += dt
		var n: Sprite3D = l.node
		if not is_instance_valid(n): loots.erase(l); continue
		if l.age > 0.45: n.position.y = l.pos.y + sin(l.t * 3.0) * 0.12
		if l.owner != null:
			# l'autre joueur ramasse son butin
			if l.age > 3.0:
				loots.erase(l)
				var tw := n.create_tween(); tw.tween_property(n, "scale", Vector3.ONE * 0.01, 0.3); tw.tween_callback(n.queue_free)
			continue
		var d := Vector2(n.position.x - pp.x, n.position.z - pp.z).length()
		if l.age > 0.5 and d < bd and not player.dead: bd = d; loot_sel = l
		if l.age > 150.0: loots.erase(l); n.queue_free()

# Fouiller : les sacs proches sont réunis dans une seule fenêtre
func open_bag(l: Dictionary) -> void:
	for o in loots.duplicate():
		if o == l or o.owner != null or not is_instance_valid(o.node): continue
		if Vector2(o.pos.x - l.pos.x, o.pos.z - l.pos.z).length() < 4.0:
			l.loot += o.loot; l.rarity = max(l.rarity, o.rarity); loots.erase(o); o.node.queue_free()
	l["title"] = {"boss": "Butin du boss", "elite": "Butin d'élite", "pvp": "Butin du joueur vaincu"}.get(l.kind, "Butin")
	Game.play("pickup", -6.0, 0.9)
	hud.show_loot(l)

func open_chest(sp: Dictionary) -> void:
	sp.chest_ready = false; sp.chest_open_at = Time.get_ticks_msec() / 1000.0
	var c: Node3D = sp.chest
	var tw := c.create_tween(); tw.tween_property(c, "scale", c.scale * 1.25, 0.12); tw.tween_property(c, "scale", c.scale * 0.0001, 0.3)
	Game.play("craft", -2.0, 0.8); Game.play("coin")
	Fx.burst(self, sp.pos + Vector3(0, world.height(sp.pos.x, sp.pos.z) + 1.0, 0), Game.TIER_COL[sp.tier], 30, 6.0, 0.4, 0.8)
	hud.show_loot({"title": "Coffre du camp · T%d" % sp.tier, "rarity": 0, "loot": Game.roll_loot("chest", sp.tier, "skel"), "pos": sp.pos, "opened": false})


# ================= ÉVÉNEMENTS : portails de donjon & boss de groupe =================
func _update_events() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	# 3 portails de donjon toujours ouverts quelque part ; ils se referment au bout de 20 min
	for en in dungeon_entries.duplicate():
		if now > en.expires and (dungeon == null or dungeon.entry != en): _remove_entry(en)
	while dungeon_entries.size() < 3: _add_entry()
	# boss de groupe aléatoire (toutes les ~8 à 12 min)
	if world_boss and is_instance_valid(world_boss) and not world_boss.dead:
		if now > world_boss_info.expires and world_boss.state == "idle":
			enemies.erase(world_boss); world_boss.queue_free(); world_boss = null; world_boss_info = {}
			hud.toast("Le boss de groupe a disparu dans la nature…", Color("#c9a8e8"))
	elif now > next_boss_at and not in_instance():
		_spawn_world_boss()
	_island_tick()
	# les faux joueurs mettent des objets en vente
	t_market -= 2.0
	if t_market <= 0.0: t_market = randf_range(70.0, 140.0); _bot_listing()

func _random_spot(reg: int) -> Vector3:
	for k in 300:
		var p := Vector3(randf_range(-100, 100), 0, randf_range(-100, 100))
		if world.region_at(p.x, p.z) != reg or not world._free_spot(p, 3.0, true) or world.slope(p.x, p.z) > 1.4: continue
		if world.near_decor(p, 4.5) or world._near_node_grid(p, 4.0) or world._near_duel(p, 8.0): continue
		if Vector2(p.x, p.z).distance_to(world.village) < 30.0: continue
		if p.distance_to(player.global_position) < 20.0: continue
		return p
	return Vector3.INF

func _add_entry() -> void:
	# un portail près du niveau du joueur, les autres au hasard
	# donjons : seulement dans les zones T2 et plus
	var regs := []
	for i in range(1, World.REGIONS.size()):
		if World.REGIONS[i].tier >= 2: regs.append(i)
	if regs.is_empty(): return
	var reg: int = regs[randi() % regs.size()]
	var p := _random_spot(reg)
	if p == Vector3.INF: return
	var t: int = World.REGIONS[reg].tier
	p.y = world.height(p.x, p.z)
	var node := Node3D.new(); node.position = p; add_child(node)
	world.cave_portal(node, Game.TIER_COL[t].lerp(Color(0.7, 0.35, 1.0), 0.6))
	fade_register(node)
	var l := Label3D.new(); l.text = "DONJON T%d" % t; l.font_size = 60; l.outline_size = 14; l.modulate = Game.TIER_COL[t]; l.outline_modulate = Color(0, 0, 0, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.008; l.position.y = 4.4; l.no_depth_test = true; node.add_child(l)
	var b := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = Vector3(4.2, 3.0, 1.0); cs.shape = bx; cs.position.y = 1.5; b.add_child(cs); node.add_child(b)
	var bm := World.beam(Vector3.ZERO, Game.TIER_COL[t].lerp(Color(0.7, 0.35, 1.0), 0.5), node); bm.position.y = 23.0
	var en := {"pos": p + Vector3(0, 0, 1.6), "tier": t, "node": node, "expires": Time.get_ticks_msec() / 1000.0 + 1200.0, "seed": randi()}
	dungeon_entries.append(en)

func _remove_entry(en: Dictionary) -> void:
	if is_instance_valid(en.node): en.node.queue_free()
	dungeon_entries.erase(en)

func enter_dungeon(en: Dictionary) -> void:
	if in_instance(): return
	if Game.power() < Game.power_needed(en.tier) * 0.7:
		hud.toast("Attention : ce donjon est très dangereux pour ton équipement (puissance %d / %d conseillée)" % [Game.power(), Game.power_needed(en.tier)], Color("#ff9a7a"), true)
	dungeon_back = player.global_position
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.group_boss and e != duel_enemy: enemies.erase(e); e.queue_free()
	for sp in world.spawns: sp.members.clear(); sp.dead_at = -999.0
	dungeon = Dungeon.new(); add_child(dungeon); world.dungeon = dungeon
	dungeon.build(self, en.tier, en.seed, en); fade_register(dungeon)
	_teleport_group(dungeon.spawn_pos)
	hud.region_banner("Donjon des profondeurs", en.tier, "Donjon T%d — le gardien et son trésor t'attendent au fond" % en.tier); hud.set_region("Donjon", en.tier)
	hud.set_map_mode(dungeon.map_image(), true, Vector2(Dungeon.ORIGIN.x, Dungeon.ORIGIN.z), 0.5, Vector2(26, 26))
	sun.light_energy = 0.55; env.ambient_light_energy = 0.3
	Game.play("roar", -10.0, 0.6)

func exit_dungeon(cleared: bool) -> void:
	if dungeon == null: return
	var en := dungeon.entry
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.camp.get("dungeon", false): enemies.erase(e); e.queue_free()
	for l in loots.duplicate():
		if l.pos.x > 300.0: loots.erase(l); l.node.queue_free()
	dungeon.queue_free(); dungeon = null; world.dungeon = null
	hud.set_map_mode(world.map_image(), false)
	sun.light_energy = 0.95; env.ambient_light_energy = 0.38
	if cleared:
		_remove_entry(en)
		_teleport_group(dungeon_back)
		hud.toast("Donjon terminé ! Un nouveau portail s'ouvrira ailleurs.", Color("#c58bff"), true)
	cur_region = 0

func _teleport_group(p: Vector3) -> void:
	player.global_position = p + Vector3(0, world.height(p.x, p.z) + 0.4, 0); player.velocity = Vector3.ZERO
	var i := 0
	for a in allies:
		if is_instance_valid(a) and not a.dead:
			var q: Vector3 = p + World.polar(i * 2.1, 2.0); a.global_position = q + Vector3(0, world.height(q.x, q.z) + 0.4, 0); i += 1
	_cam_update(1.0, true)

func open_dungeon_chest() -> void:
	if dungeon == null or dungeon.chest_open: return
	dungeon.chest_open = true
	var t := dungeon.tier
	var c := dungeon.chest
	var tw := c.create_tween(); tw.tween_property(c, "scale", c.scale * 1.25, 0.12); tw.tween_property(c, "scale", c.scale * 0.0001, 0.3)
	Game.play("craft", -2.0, 0.8); Game.play("coin"); Game.play("level", -4.0)
	Fx.burst(self, dungeon.chest_pos + Vector3(0, 1.0, 0), Color("#ffd24a"), 40, 7.0, 0.4, 0.9)
	var loot := Game.roll_loot("dungeon", t, "man")
	if randf() < 0.3: loot.append({"item": Game.random_artefact(t)})
	hud.show_loot({"title": "Trésor du donjon T%d" % t, "rarity": 2, "loot": loot, "pos": dungeon.chest_pos, "opened": false})
	Game.save()

func _spawn_world_boss() -> void:
	next_boss_at = Time.get_ticks_msec() / 1000.0 + randf_range(480.0, 720.0)
	var reg := World.REGIONS.size() - 1
	if World.REGIONS[reg].tier < 2: return
	var p := _random_spot(reg)
	if p == Vector3.INF: return
	var t: int = World.REGIONS[reg].tier
	var k: String = ["alpha", "taureau_guerre", "roi_cerf"][randi() % 3]
	var sp := {"pos": p, "members": []}
	world_boss = _spawn_enemy(k, t, p, sp, false)
	world_boss_info = {"pos": p, "expires": Time.get_ticks_msec() / 1000.0 + 900.0, "name": world_boss.def.name, "tier": t, "region": World.REGIONS[reg].name}
	hud.celebrate("BOSS DE GROUPE !", "%s T%d · %s — il faut être 4 (toi + 3 mercenaires)" % [world_boss.def.name, t, World.REGIONS[reg].name], "it_hunt")
	Game.play("roar", -2.0, 0.7)

func _group_boss_down(e: Enemy) -> void:
	Game.S.stats.boss += 1
	var t := e.tier
	var loot := Game.roll_loot("group", t, "beast")
	if randf() < 0.08: loot.append({"item": Game.random_mount(5)})
	drop_loot(e.global_position, "boss", t, loot)
	hud.celebrate("%s TERRASSÉ !" % e.def.name.to_upper(), "Son butin t'attend au sol — fouille-le", "it_hunt"); Game.play("level")
	world_boss = null; world_boss_info = {}; boss_ref = null

# Nombre de combattants du groupe près d'un point (héros + mercenaires vivants)
func group_near(p: Vector3, r: float) -> int:
	var n := 1 if not player.dead and player.global_position.distance_to(p) < r else 0
	for a in allies:
		if is_instance_valid(a) and not a.dead and a.global_position.distance_to(p) < r: n += 1
	return n

# ================= MERCENAIRES =================
const MERC_BASE := 45
static func merc_price(t: int) -> int: return [0, 150, 1200, 15000, 200000, 2500000][clamp(t, 1, 5)]

func _spawn_saved_mercs() -> void:
	for i in Game.S.mercs.size():
		_spawn_merc(Game.S.mercs[i], i)

func _spawn_merc(d: Dictionary, i: int) -> Ally:
	var a := Ally.new(); add_child(a)
	var p := player.global_position + World.polar(i * 2.1, 2.2)
	a.position = p + Vector3(0, world.height(p.x, p.z) + 0.4, 0)
	a.setup(self, d, i); allies.append(a)
	return a

func hire_merc(type: String, t: int) -> void:
	if Game.S.mercs.size() >= 3: hud.toast("Ton groupe est complet (3 mercenaires max)", Color("#ff9a8a")); return
	var price := merc_price(t)
	if Game.S.silver < price: Game.play("error"); hud.toast("Pas assez d'argent", Color("#ff9a8a")); return
	Game.S.silver -= price
	var used := []
	for m in Game.S.mercs: used.append(m.name)
	var nm: String = Ally.NAMES[randi() % Ally.NAMES.size()]
	while nm in used: nm = Ally.NAMES[randi() % Ally.NAMES.size()]
	var d := {"type": type, "tier": t, "name": nm}
	Game.S.mercs.append(d); _spawn_merc(d, Game.S.mercs.size() - 1)
	Game.play("coin"); hud.toast("%s le %s T%d rejoint ton groupe !" % [nm, Ally.TYPES[type].name, t], Color("#9dffb0"), true)
	Game.save(); hud.show_mercs()

func dismiss_merc(i: int) -> void:
	if i >= Game.S.mercs.size(): return
	var nm: String = Game.S.mercs[i].name
	Game.S.mercs.remove_at(i)
	for a in allies.duplicate():
		if is_instance_valid(a) and a.nm == nm: allies.erase(a); a.queue_free()
	for k in allies.size(): allies[k].slot = k
	Game.save(); hud.show_mercs()

func on_ally_death(a: Ally) -> void:
	allies.erase(a)
	for i in Game.S.mercs.size():
		if Game.S.mercs[i].name == a.nm: Game.S.mercs.remove_at(i); break
	for k in allies.size(): allies[k].slot = k
	Game.save()

# ================= DUELS =================
func duel_reward(t: int) -> int: return int(Game.ITEM_BASE[t] * 0.35)

func _talk_duel(n: Npc) -> void:
	var t: int = n.data.tier
	var now := Time.get_unix_time_from_system()
	var won_at: float = float(Game.S.duels.get(n.id, 0))
	var wait := 900.0 - (now - won_at)
	var acts := []
	var line := ""
	if won_at > 0 and wait > 0:
		line = "Tu m'as battu à la loyale… Laisse-moi reprendre des forces. Reviens dans [b]%d min[/b] pour une revanche." % ceili(wait / 60.0)
	else:
		var p := Game.power(); var need := Game.power_needed(t)
		var warn := "[color=#8dffa0]Tu es de taille.[/color]" if p >= need else ("[color=#ffb07a]Ce sera serré…[/color]" if p >= need * 0.75 else "[color=#ff7a6a]Tu n'as aucune chance avec cet équipement.[/color]")
		line = "Je suis [b]%s[/b], duelliste %s. Un duel, toi contre moi, sans aide.\n\nSi tu gagnes : [color=#ffd86b]~%s argent[/color] + [color=#d58bff]un artefact T%d[/color].\nPuissance conseillée : %d — la tienne : %d. %s" % [n.nm, hud.tier_tag(t), Game.fmt(duel_reward(t)), t, need, p, warn]
		acts.append(["Accepter le duel", func(): start_duel(n), true])
	acts.append(["Refuser", func(): hud.close_panel()])
	hud.show_dialog(n, line, acts)

func start_duel(n: Npc) -> void:
	hud.close_panel()
	if duel_enemy: return
	var t: int = n.data.tier
	var hero := "res://assets/heroes/%s.glb" % n.data.model
	var extra := {"model": hero, "weapon": Game.weapon_model(n.data.wkind, t), "name": n.nm, "id": n.id}
	if n.data.model in ["Knight", "Barbarian"] and n.data.wkind != "baton": extra["shield"] = Game.shield_model(t)
	var p := n.home
	n.hide_for_duel(true); duel_npc = n
	duel_enemy = _spawn_enemy("duel", t, p, {"members": []}, false, extra)
	duel_enemy.state = "wait"; duel_enemy.atk_cd = 0.8
	hud.region_banner("DUEL !", t, "%s · un contre un, sans aide" % n.nm)
	var de := duel_enemy
	hud.countdown(func():
		if is_instance_valid(de) and not de.dead and de.state == "wait": de.state = "chase")

func _duel_won(e: Enemy) -> void:
	var t := e.tier
	var loot := [{"silver": int(duel_reward(t) * randf_range(0.9, 1.2))}, {"item": Game.random_artefact(t)}]
	if randf() < 0.3: loot.append({"item": Game.random_junk(t, Game.JUNK_MAN)})
	Game.S.duels[e.duel_info.id] = Time.get_unix_time_from_system()
	hud.celebrate("DUEL GAGNÉ !", "Ton adversaire te laisse sa bourse et son artefact", "it_seal"); Game.play("level")
	drop_loot(e.global_position, "boss", t, loot)
	var n := duel_npc
	duel_enemy = null; duel_npc = null
	if n: get_tree().create_timer(4.0).timeout.connect(func(): n.hide_for_duel(false))

func duel_reset(e: Enemy) -> void:
	if e != duel_enemy: return
	enemies.erase(e); e.queue_free(); duel_enemy = null
	if duel_npc: duel_npc.hide_for_duel(false); duel_npc = null
	hud.toast("Le duel est terminé (abandon ou défaite).", Color("#ffb07a"))


# ================= TOUR INFINIE =================
func enter_tower(n: int) -> void:
	if dungeon: return
	if tower == null:
		tower_back = player.global_position
		for e in enemies.duplicate():
			if is_instance_valid(e) and not e.group_boss and e != duel_enemy: enemies.erase(e); e.queue_free()
		for sp in world.spawns: sp.members.clear(); sp.dead_at = -999.0
	else:
		_clear_tower()
	tower = Tower.new(); add_child(tower); world.dungeon = tower
	tower.build(self, n); fade_register(tower)
	_teleport_group(tower.spawn_pos)
	var t := Tower.tier_of(n)
	hud.region_banner("Tour Infinie — Étage %d" % n, t, "Gardien T%d · %d coffre%s scellé%s" % [t, Tower.chest_count(n), "s" if Tower.chest_count(n) > 1 else "", "s" if Tower.chest_count(n) > 1 else ""])
	hud.set_region("Tour · étage %d" % n, t)
	hud.set_map_mode(tower.map_image(), true, Vector2(Tower.ORIGIN.x, Tower.ORIGIN.z), 1.5, Vector2(32, 32))
	sun.light_energy = 0.6; env.ambient_light_energy = 0.34
	Game.play("roar", -10.0, 0.8)

func _clear_tower() -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.camp.get("dungeon", false): enemies.erase(e); e.queue_free()
	for l in loots.duplicate():
		if l.pos.x > 300.0: loots.erase(l); l.node.queue_free()
	tower.queue_free(); tower = null; world.dungeon = null

func _loot_left() -> bool:
	for c in tower.chests:
		if not c.loot.is_empty(): return true
	return false

func tower_next() -> void:
	if tower == null or not tower.cleared: return
	var n := tower.floor_n + 1
	if _loot_left():
		hud.confirm("Butin oublié", "Il reste du butin dans les coffres de cet étage. Monter quand même ? (il sera perdu)", func(): enter_tower(n))
	else: enter_tower(n)

func exit_tower(to_entrance := true) -> void:
	if tower == null: return
	if to_entrance and _loot_left():
		hud.confirm("Butin oublié", "Il reste du butin dans les coffres. Sortir quand même ?", func(): _do_exit_tower(true)); return
	_do_exit_tower(to_entrance)

func _do_exit_tower(to_entrance: bool) -> void:
	hud.close_panel()
	_clear_tower()
	hud.set_map_mode(world.map_image(), false)
	sun.light_energy = 0.95; env.ambient_light_energy = 0.38
	if to_entrance: _teleport_group(world.tower_portal + Vector3(0, 0, 3.5))
	cur_region = 0; Game.save()

# Prend un objet du coffre (ou tout) ; renvoie false si le sac est plein
func take_loot(c: Dictionary, i: int) -> bool:
	if i < 0 or i >= c.loot.size(): return false
	var l: Dictionary = c.loot[i]
	if l.has("item"):
		if not Game.add_item(l.item): hud.toast("Sac plein ! Fais de la place (vends ou équipe).", Color("#ff9a8a")); Game.play("error"); return false
	elif l.has("silver"): gain_silver(l.silver)
	elif l.has("potion"): Game.S.potions += int(l.potion)
	elif l.has("res"): Game.S.inv[l.res][l.tier] += int(l.qty)
	c.loot.remove_at(i)
	return true

func take_all(c: Dictionary) -> void:
	var i := 0
	while i < c.loot.size():
		if not take_loot(c, i): i += 1
	Game.play("coin"); Game.play("pickup", -4.0, 1.2)
	if c.loot.is_empty(): _chest_emptied(c)
	Game.save(); update_goal()

func _chest_emptied(c: Dictionary) -> void:
	c.opened = true
	if c.get("bag", false):
		loots.erase(c)
		if is_instance_valid(c.node): c.node.queue_free()
	if c.has("beam") and is_instance_valid(c.beam): c.beam.create_tween().tween_property(c.beam, "scale", Vector3(0.01, 1, 0.01), 0.6)
	if c.has("label") and is_instance_valid(c.label): c.label.text = "vide"; c.label.modulate = Color(0.7, 0.7, 0.7)

# ================= BOUTIQUE =================
func shop_claim(id: String) -> void:
	var msg := ""
	var named := {
		"lame": {"slot": "epee", "tier": 5, "kind": "epee", "ench": 5, "nm": "Lame de l'Aube"},
		"fendeuse": {"slot": "epee", "tier": 5, "kind": "hache", "ench": 5, "nm": "Fendeuse du Néant"},
		"sceptre": {"slot": "epee", "tier": 5, "kind": "baton", "ench": 5, "nm": "Sceptre Astral"},
		"titan": {"slot": "bouclier", "tier": 5, "ench": 5, "nm": "Rempart du Titan"},
		"set_plate": {"slot": "armure", "tier": 5, "kind": "plate", "ench": 5, "nm": "Plates du Dragon"},
		"set_cuir": {"slot": "armure", "tier": 5, "kind": "cuir", "ench": 5, "nm": "Cuir de l'Ombre"},
		"set_tissu": {"slot": "armure", "tier": 5, "kind": "tissu", "ench": 5, "nm": "Robe Céleste"},
		"bottes": {"slot": "bottes", "tier": 5, "ench": 5, "nm": "Bottes de Vent"},
		"art_rage": {"slot": "artefact", "tier": 5, "kind": "rage", "ench": 3},
		"art_vie": {"slot": "artefact", "tier": 5, "kind": "vie", "ench": 3},
		"art_fortune": {"slot": "artefact", "tier": 5, "kind": "fortune", "ench": 3},
		"pegase": {"slot": "monture", "tier": 5, "kind": "pegase"},
		"m_roi_cerf": {"slot": "monture", "tier": 5, "kind": "roi_cerf"},
		"m_taureau": {"slot": "monture", "tier": 5, "kind": "taureau"},
		"m_loup": {"slot": "monture", "tier": 4, "kind": "loup"},
		"m_cheval": {"slot": "monture", "tier": 2, "kind": "cheval"},
	}
	if named.has(id): msg = _give(named[id].duplicate())
	else:
		match id:
			"or1": gain_silver(100000); msg = "+100 k argent"
			"or2": gain_silver(2000000); msg = "+2 M argent"
			"or3": gain_silver(50000000); msg = "+50 M argent"
			"or4": Game.S.silver += 500000000; msg = "+500 M argent"
			"leg":
				var tw := Tower.new(); tw.floor_n = 30; tw.tier = 5; tw.rng.randomize()
				var c := {"rarity": 3, "loot": tw._make_loot(3), "pos": player.global_position, "opened": false}
				tw.free(); hud.show_loot(c); Game.play("level"); return
			"res2", "res3", "res4", "res5":
				var t := int(id.substr(3))
				for k in Game.RES_KEYS: Game.S.inv[k][t] += 120
				msg = "+120 de chaque ressource T%d" % t
			"enchant":
				var n := 0
				for sl in Game.ENCH_SLOTS:
					if Game.S.gear.get(sl, 0) > 0 and Game.ench(sl) < Game.ENCH_MAX: Game.S.ench[sl] = Game.ench(sl) + 1; n += 1
				msg = "+1 enchantement sur %d pièce(s)" % n if n > 0 else "Tout est déjà au maximum"
				player.level_glow(Color(0.75, 0.4, 1.0))
			"metier":
				for tl in ["hache", "pioche", "faucille"]:
					var p := Game.prof(tl); p.lvl = min(Game.PROF_MAX, int(p.lvl) + 5); p.xp = 0
				msg = "+5 niveaux à tous les métiers"; player.level_glow()
			"maitrise":
				var w := Game.wxp(Game.S.get("weapon_kind", "epee")); w.lvl = min(Game.WXP_MAX, int(w.lvl) + 5); w.xp = 0
				msg = "+5 niveaux de maîtrise"; player.level_glow(Color(1.0, 0.55, 0.25))
			"potions": Game.S.potions += 25; msg = "+25 potions"
			"sac":
				if int(Game.S.get("bag_bonus", 0)) >= 24: hud.toast("Ton sac est déjà au maximum", Color("#ffb07a")); return
				Game.S.bag_bonus = int(Game.S.get("bag_bonus", 0)) + 8; msg = "Sac : %d cases" % Game.bag_size()
			"garde":
				var n2 := 0
				while Game.S.mercs.size() < 3:
					var ty: String = ["guerrier", "rodeuse", "clerc"][Game.S.mercs.size()]
					var d := {"type": ty, "tier": 5, "name": Ally.NAMES[randi() % Ally.NAMES.size()]}
					Game.S.mercs.append(d); _spawn_merc(d, Game.S.mercs.size() - 1); n2 += 1
				msg = "%d mercenaire(s) T5 rejoignent ton groupe" % n2 if n2 > 0 else "Ton groupe est déjà complet"
	if msg == "": return
	Game.play("coin"); Game.play("level", -6.0)
	hud.celebrate("BOUTIQUE", msg, "it_chest_open")
	player.refresh_gear(); Game.save(); update_goal()
	if hud.cur_panel == "boutique": hud.show_boutique()

func _give(it: Dictionary) -> String:
	if Game.add_item(it): return "%s ajouté à ton sac" % Game.item_name(it)
	hud.toast("Sac plein : fais de la place !", Color("#ff9a8a")); Game.play("error"); return ""

# ================= OUTILS & ARTISANAT =================
func buy_tool(tool: String, t: int, q: int) -> void:
	if Game.prof(tool).lvl < Game.PROF_REQ[t]: Game.play("error"); hud.toast("Niveau de %s trop bas" % Game.PROF_TITLE[tool].to_lower(), Color("#ff9a8a")); return
	var price := Game.tool_price(t, q)
	if Game.S.silver < price: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(price - Game.S.silver), Color("#ff9a8a")); return
	Game.S.silver -= price
	var old := Game.equipped_item(tool)
	if int(old.tier) > 0 and not Game.add_item(old): hud.toast("Sac plein : l'ancien outil est revendu", Color("#ffb07a")); Game.S.silver += int(Game.item_price(old) * 0.5)
	Game.S.gear[tool] = t; Game.S.toolq[tool] = q
	Game.play("craft"); Game.play("coin")
	hud.celebrate("NOUVEL OUTIL !", "%s" % Game.item_name(Game.equipped_item(tool)), "it_trophy")
	player.level_glow(Color(Game.TOOL_Q[q].col))
	Game.save(); update_goal(); hud.show_tools(tool)

func craft_gear(ci: int, t: int) -> void:
	var c: Dictionary = Game.CRAFTS[ci]
	if t > Game.unlocked(c.slot) + 1: Game.play("error"); hud.toast("Tier verrouillé : porte d'abord le T%d" % (t - 1), Color("#ff9a8a")); return
	var cost := Game.craft_cost(c, t)
	if not Game.has_cost(cost): Game.play("error"); return
	if Game.bag_used() >= Game.bag_size(): hud.toast("Sac plein", Color("#ff9a8a")); Game.play("error"); return
	Game.pay(cost)
	var it := Game.roll_bx(Game.craft_item(c, t))
	Game.add_item(it)
	Game.play("craft"); Game.play("level", -6.0)
	Fx.burst(self, _brokk_pos() + Vector3(0, 1.2, 0), Game.TIER_COL[t], 26, 5.0, 0.35, 0.8)
	hud.celebrate("FABRIQUÉ !", "%s · T%d — dans ton sac (équipe-le ou revends-le)" % [Game.item_name(it), t], "it_quest")
	Game.save(); update_goal(); hud.show_armurier("craft")

func buy_gear(it: Dictionary) -> void:
	if int(it.tier) > Game.unlocked(it.slot) + 1: Game.play("error"); hud.toast("Tier verrouillé : porte d'abord le T%d" % (int(it.tier) - 1), Color("#ff9a8a")); return
	var price := int(Game.item_price(it) * 1.3)
	if Game.S.silver < price: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(price - Game.S.silver), Color("#ff9a8a")); return
	if not Game.add_item(Game.roll_bx(it.duplicate())): hud.toast("Sac plein", Color("#ff9a8a")); Game.play("error"); return
	Game.S.silver -= price; Game.play("coin")
	hud.toast("Acheté : %s" % Game.item_name(it), Color("#9dffb0")); Game.save(); hud.show_armurier("buy")

# ================= ENCHANTEMENT =================
func enchant(slot: String) -> void:
	var t: int = Game.S.gear.get(slot, 0); var cur := Game.ench(slot)
	if t <= 0 or cur >= Game.ENCH_MAX: Game.play("error"); return
	var cost := Game.ench_cost(slot, t, cur + 1)
	if Game.S.silver < cost: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(cost - Game.S.silver), Color("#ff9a8a")); return
	Game.S.silver -= cost; Game.S.ench[slot] = cur + 1
	player.refresh_gear(); player.level_glow(Color(0.75, 0.4, 1.0))
	Game.play("craft"); Game.play("level", -4.0, 1.3)
	hud.celebrate("ENCHANTEMENT +%d !" % (cur + 1), "%s : +%d %% de puissance" % [Game.item_name(Game.equipped_item(slot)), 12 * (cur + 1)], "art_rage")
	Game.save(); hud.show_enchant()

# ================= FAUX JOUEURS =================
func _spawn_bots() -> void:
	var names := Bot.NAMES.duplicate(); names.shuffle()
	# 8 joueurs par carte : moitié dans chaque zone ; hostiles possibles dès la carte T2-T3
	for i in 8:
		var b := Bot.new(); add_child(b)
		var reg: int = 1 + (i % (World.REGIONS.size() - 1))
		var t: int = World.REGIONS[reg].tier
		b.setup(self, names[i], t, reg, world.map_id >= 2 and randf() < 0.5)
		var p := b.goal
		b.position = p + Vector3(0, world.height(p.x, p.z) + 0.5, 0); b._new_goal()
		bots.append(b)

func on_bot_death(b: Bot, killer) -> void:
	if killer == player or killer is Ally:
		_weapon_xp(b.tier, 4.0)
		var loot := Game.roll_loot("pvp", b.tier, "man")
		var back := ""
		for it in b.stolen: loot.push_front({"item": it}); back = " — ton objet volé est dedans !"
		b.stolen.clear()
		# un joueur vaincu lâche une partie de son équipement
		if randf() < 0.35: loot.append({"item": b.gear_drop()})
		drop_loot(b.global_position, "pvp", b.tier, loot)
		hud.celebrate("%s VAINCU !" % b.nm.to_upper(), "Fouille son sac%s" % back, "it_seal"); Game.play("level", -6.0)
		Game.save()

func _robbed_by(b: Bot) -> void:
	var slots := []
	for s in Game.COMBAT_SLOTS:
		if Game.S.gear.get(s, 0) > 0: slots.append(s)
	var lost := ""
	if not slots.is_empty():
		var s: String = slots[randi() % slots.size()]
		var it := Game.equipped_item(s)
		Game.S.gear[s] = 0; Game.S.ench[s] = 0
		b.stolen.append(it); lost = Game.item_name(it)
		player.refresh_gear()
	var taken := int(Game.S.silver * 0.1); Game.S.silver -= taken
	b.say(["merci pour le stuff", "gg ez", "trop facile", "à la prochaine"][randi() % 4])
	hud.toast("%s t'a dépouillé : %s%s perdu(e) · −%s argent" % [b.nm, lost if lost != "" else "", "" if lost != "" else "rien", Game.fmt(taken)], Color("#ff6a5a"), true)
	hud.toast("Tue-le pour récupérer ton objet… ou rachète-le à l'hôtel des ventes !", Color("#ffb07a"))
	Game.save()

func _bot_listing() -> void:
	var alive := bots.filter(func(x): return not x.dead)
	if alive.is_empty(): return
	var b: Bot = alive[randi() % alive.size()]
	var e: Dictionary
	if not b.stolen.is_empty() and randf() < 0.7:
		e = b.stolen.pop_front()   # il revend ce qu'il t'a pris !
	else:
		e = Game.random_item(clamp(b.tier + (1 if randf() < 0.3 else 0), 1, 5), true) if randf() > 0.08 else Game.random_artefact(b.tier)
		if e.slot in Game.ENCH_SLOTS and randf() < 0.3: e["ench"] = randi_range(1, 4)
	e["price"] = int(Game.item_price(e) * randf_range(1.05, 1.6)); e["seller"] = b.nm
	Game.S.ah.stock.insert(0, e)
	if Game.S.ah.stock.size() > 20: Game.S.ah.stock.pop_back()
	if not in_instance(): hud.toast("[Marché] %s vend %s — %s" % [b.nm, Game.item_name(e), Game.fmt(e.price)], Color("#9fd4ff"))

# ================= ÎLE PRIVÉE =================
const RAID_WINDOW := 900.0   # 15 minutes pour défendre l'île

func _rare_mount(src: String) -> void:
	var mo := Game.random_mount(5)
	if Game.add_item(mo): hud.celebrate("MONTURE RARE !", "%s a laissé : %s — élève-la dans l'enclos de ton île" % [src, Game.item_name(mo)], "it_trophy"); Game.play("level")

func _chest_add(e: Dictionary) -> void:
	var L: Array = Game.S.island.chest.loot
	if e.has("res"):
		for x in L:
			if x.has("res") and x.res == e.res and int(x.tier) == int(e.tier): x.qty = int(x.qty) + int(e.qty); return
	if e.has("silver"):
		for x in L:
			if x.has("silver"): x.silver = int(x.silver) + int(e.silver); return
	L.append(e)

func _island_produce() -> void:
	var lvl: int = Game.S.island.lvl
	for p in Game.island_prod(lvl):
		for k in Game.RES_KEYS: _chest_add({"res": k, "tier": p[0], "qty": int(p[1] * (1.0 - Game.WORKER_CUT))})

func _island_tick() -> void:
	var I: Dictionary = Game.S.island
	if not I.owned: return
	if not I.chest.has("loot"): I.chest = {"loot": []}
	var d := Game.day_index()
	var n := 0
	while int(I.last_day) < d and n < 7:
		I.last_day = int(I.last_day) + 1; n += 1; _island_produce()
	I.last_day = d
	if n > 0: hud.toast("Minuit : tes ouvriers ont rempli le coffre de ton île !", Color("#ffe39a"), true)
	var now := Time.get_unix_time_from_system()
	if int(I.raid_day) != d:
		I.raid_day = d; I.raids = []
		var bias: float = Time.get_time_zone_from_system().bias * 60.0
		for k in 2:
			var at: float = d * 86400.0 - bias + randf_range(8.0, 23.5) * 3600.0
			if at < now + 120.0: at = now + randf_range(600.0, 7200.0)
			if at < (d + 1) * 86400.0 - bias: I.raids.append({"at": at, "st": "wait"})
	for r in I.raids:
		if r.st == "wait" and now >= float(r.at):
			if float(I.guard_until) > now:
				r.st = "guard"; _bandit_loot(0.5)
				hud.toast("Des bandits ont attaqué ton île… tes gardes les ont repoussés ! Butin dans le coffre.", Color("#9dffb0"), true)
			else:
				r.st = "active"
				hud.celebrate("ATTAQUE DE BANDITS !", "Ton île est attaquée ! 15 min pour la défendre — bouton MON ÎLE", "it_hunt"); Game.play("roar")
				if island: island.start_raid()
		elif r.st == "active" and now > float(r.at) + RAID_WINDOW and not (island and island.raid_on):
			r.st = "lost"; I.chest.loot.clear()
			hud.celebrate("ÎLE PILLÉE…", "Les bandits ont vidé le coffre de ton île. Engage des gardes !", "it_hunt")
			Game.play("death", -2.0, 0.7)
	Game.save()

func raid_active() -> bool:
	for r in Game.S.island.raids:
		if r.st == "active": return true
	return false

func go_island() -> void:
	if not Game.S.island.owned: return
	if dungeon or tower: hud.toast("Termine d'abord ce donjon / cette tour", Color("#ffb07a")); return
	if island: return
	if enemies.any(func(e): return not e.dead and e.state != "idle" and e.global_position.distance_to(player.global_position) < 10.0):
		hud.toast("Impossible de partir en plein combat", Color("#ff9a8a")); return
	if player.mounted: player.dismount()
	island_back = player.global_position
	for e in enemies.duplicate():
		if is_instance_valid(e) and not e.group_boss and e != duel_enemy: enemies.erase(e); e.queue_free()
	for sp in world.spawns: sp.members.clear(); sp.dead_at = -999.0
	island = Island.new(); add_child(island); world.dungeon = island
	island.build(self, Game.S.island.lvl)
	_teleport_group(island.spawn_pos)
	hud.region_banner(Game.ISLAND_NAME[Game.S.island.lvl], 1, "Ton île privée")
	hud.set_region("Mon île", 1)
	hud.set_map_mode(island.map_image(), true, Vector2(Island.ORIGIN.x, Island.ORIGIN.z), 0.9, Vector2(32, 32))
	if raid_active(): island.start_raid(); hud.toast("Les bandits sont là ! Élimine les 10 groupes.", Color("#ff6a5a"), true)
	var R0: Dictionary = island.res_state()
	hud.toast("Ressources sauvages de l'île : T%d — elles changent dans %d min" % [int(R0.tier), int(Island.period_left() / 60.0) + 1], Game.TIER_COL[int(R0.tier)], true)

func leave_island(to_back := true) -> void:
	if island == null: return
	if island.raid_on and to_back:
		hud.confirm("Raid en cours", "Si tu pars et que le temps s'écoule, les bandits videront ton coffre. Partir quand même ?", func(): _do_leave_island()); return
	_do_leave_island(to_back)

func _do_leave_island(to_back := true) -> void:
	for e in enemies.duplicate():
		if is_instance_valid(e) and e.camp.get("dungeon", false): enemies.erase(e); e.queue_free()
	for l in loots.duplicate():
		if l.pos.x > 300.0: loots.erase(l); l.node.queue_free()
	island.clear_res(); island.queue_free(); island = null; world.dungeon = null
	hud.set_map_mode(world.map_image(), false)
	if to_back: _teleport_group(island_back if island_back != Vector3.ZERO else world.harbor_pos)
	cur_region = 0; Game.save()

func _bandit_down(e: Enemy) -> void:
	var g := island.groups_cleared()
	if e.camp.members.all(func(m): return not is_instance_valid(m) or m.dead):
		hud.toast("Groupe de bandits éliminé : %d / 10" % g, Color("#ffe39a"))
	if g >= 10 and island.raid_on:
		island.raid_on = false
		for r in Game.S.island.raids:
			if r.st == "active": r.st = "won"
		_bandit_loot(1.0)
		hud.celebrate("ÎLE DÉFENDUE !", "Les 10 groupes sont tombés — leur butin est dans ton coffre", "it_trophy"); Game.play("level")
		Game.save()

# Butin des bandits : le RNG est dur, les beaux objets sont rares
func _bandit_loot(share: float) -> void:
	var lvl: int = Game.S.island.lvl
	_chest_add({"silver": int(Game.money(Game.bandit_tier(lvl)) * 300 * share * randf_range(0.7, 1.3))})
	var weights := [0, 40, 30, 18, 9, 3]
	var rolls := int(round(10 * share))
	for k in rolls:
		if randf() > 0.35: continue
		var r := randf() * 100.0; var t := 1
		for i in range(1, 6):
			r -= weights[i]
			if r <= 0: t = i; break
		var it := Game.random_item(t) if randf() > 0.1 else Game.random_artefact(t)
		_chest_add({"item": it})
	if randf() < 0.04 * share: _chest_add({"item": Game.random_mount(5)})

func buy_island() -> void:
	var I: Dictionary = Game.S.island
	if I.owned: return
	if Game.S.silver < Game.ISLAND_PRICE: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(Game.ISLAND_PRICE - Game.S.silver), Color("#ff9a8a")); return
	Game.S.silver -= Game.ISLAND_PRICE
	I.owned = true; I.lvl = 1; I.chest = {"loot": []}; I.last_day = Game.day_index(); I.raid_day = -1
	_island_produce()
	hud.celebrate("TU POSSÈDES UNE ÎLE !", "Tes ouvriers travaillent déjà — premier coffre prêt", "it_treasure_map"); Game.play("level")
	Game.save(); hud.close_panel(); go_island()

func upgrade_island() -> void:
	var I: Dictionary = Game.S.island
	if int(I.lvl) >= 5: return
	var cost: int = Game.ISLAND_UP[int(I.lvl) + 1]
	if Game.S.silver < cost: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(cost - Game.S.silver), Color("#ff9a8a")); return
	Game.S.silver -= cost; I.lvl = int(I.lvl) + 1
	hud.celebrate("ÎLE AGRANDIE !", "%s — production augmentée" % Game.ISLAND_NAME[I.lvl], "it_trophy"); Game.play("level")
	Game.save(); hud.show_island()

func hire_guards(days: int) -> void:
	var I: Dictionary = Game.S.island
	var cost: int = Game.guard_price(int(I.lvl)) * days
	if Game.S.silver < cost: Game.play("error"); hud.toast("Il te manque %s argent" % Game.fmt(cost - Game.S.silver), Color("#ff9a8a")); return
	Game.S.silver -= cost
	var now := Time.get_unix_time_from_system()
	I.guard_until = max(float(I.guard_until), now) + days * 86400.0
	Game.play("coin"); hud.toast("Gardes engagés pour %d jour(s)" % days, Color("#9dffb0")); Game.save(); hud.show_island()

func island_field(i: int) -> void:
	var I: Dictionary = Game.S.island
	var now := Time.get_unix_time_from_system(); var t0: float = float(I.farm[i])
	if t0 <= 0.0:
		if Game.S.silver < Game.FARM_COST: Game.play("error"); hud.toast("Semer coûte %s argent" % Game.fmt(Game.FARM_COST), Color("#ff9a8a")); return
		Game.S.silver -= Game.FARM_COST; I.farm[i] = now; Game.play("pickup")
		hud.toast("Parcelle semée : récolte dans 3 h", Color("#e9ffb0"))
	elif now - t0 >= Game.FARM_TIME:
		I.farm[i] = 0
		var silver := gain_silver(120000 * int(I.lvl)); Game.S.potions += 2
		Game.S.inv.fiber[min(5, int(I.lvl) + 2)] += 6
		hud.celebrate("RÉCOLTE !", "+%s argent · +2 potions · +6 fibre" % Game.fmt(silver), "it_quest"); Game.play("coin")
	else:
		var left := Game.FARM_TIME - (now - t0)
		hud.toast("Ça pousse… prêt dans %d h %02d" % [int(left / 3600), int(fmod(left, 3600.0) / 60)], Color("#e9ffb0"))
	if island: island.refresh()
	Game.save()

func pen_add(idx: int) -> void:
	var I: Dictionary = Game.S.island
	if I.pen.size() >= 2: return
	var it: Dictionary = Game.S.items[idx]
	Game.S.items.remove_at(idx); I.pen.append({"kind": it.get("kind", "ane"), "tier": int(it.tier)})
	if I.pen.size() == 2: I.pen_t = Time.get_unix_time_from_system()
	if island: island.refresh()
	Game.save(); hud.show_pen()

func pen_remove(k: int) -> void:
	var I: Dictionary = Game.S.island
	var a: Dictionary = I.pen[k]
	if not Game.add_item({"slot": "monture", "tier": a.tier, "kind": a.kind}): hud.toast("Sac plein", Color("#ff9a8a")); return
	I.pen.remove_at(k); I.pen_t = 0
	if island: island.refresh()
	Game.save(); hud.show_pen()

func pen_collect() -> void:
	var I: Dictionary = Game.S.island
	if I.pen.size() < 2 or I.pen[0].kind != I.pen[1].kind: return
	var now := Time.get_unix_time_from_system()
	if now - float(I.pen_t) < Game.BREED_TIME: return
	var a: Dictionary = I.pen[0]
	var baby := {"slot": "monture", "tier": a.tier, "kind": a.kind, "bebe": true, "nm": "Bébé " + Game.MOUNTS[a.kind].name.to_lower()}
	if not Game.add_item(baby): hud.toast("Sac plein", Color("#ff9a8a")); return
	I.pen_t = now
	hud.celebrate("NAISSANCE !", "%s — se revend très cher" % baby.nm, "it_trophy"); Game.play("level")
	Game.save(); hud.show_pen()

# (tests) un point devant une falaise, pour les captures
func _find_cliff_view() -> Vector3:
	var w: World = world
	for tries in 4000:
		var p := Vector3(randf_range(-90, 90), 0, randf_range(-90, 90))
		if not w.walkable(p.x, p.z) or w.road_dist(p.x, p.z) < 3.0: continue
		if w.height(p.x, p.z - 6.0) - w.height(p.x, p.z) < 3.0: continue
		if not w.walkable(p.x, p.z + 3.0) or w.river_dist(p.x, p.z) < 8.0: continue
		return Vector3(p.x, w.height(p.x, p.z) + 0.5, p.z)
	return player.global_position
