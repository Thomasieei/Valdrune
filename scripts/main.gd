extends Node3D
## Studio Lab : arène de test des classes (Chronomancien, Druide, Vampire), vagues de squelettes.

var actors: Array = []
var player: Actor
var K                        # compétences (skills.gd)
var cam: Camera3D
var cam_dist := 11.0
var shake_t := 0.0
var tstop := false
var sfx_lib := {}
var ui: CanvasLayer
var pad: Pad
var lbl: Label
var btn_cls: Button
var btn_lvl: Button
var panel: ItemList
var overlay: ColorRect
var blade_mesh: Mesh
var _wave_t := 0.0
var town

var loading: CanvasLayer
func _ready() -> void:
	loading = CanvasLayer.new(); loading.layer = 10; add_child(loading)
	var bg := ColorRect.new(); bg.color = Color(0.06, 0.05, 0.08); bg.set_anchors_preset(Control.PRESET_FULL_RECT); loading.add_child(bg)
	var lt := Label.new(); lt.text = "BRUNEVAL\nchargement…"; lt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; lt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	lt.set_anchors_preset(Control.PRESET_FULL_RECT); lt.add_theme_font_size_override("font_size", 42); lt.add_theme_color_override("font_color", Color(1, 0.85, 0.5)); loading.add_child(lt)
	await get_tree().process_frame; await get_tree().process_frame
	_extra_anims()
	_world()
	for f in ["swing1","swing2","hit1","hit2","hit3","jump","land","dash","slam"]:
		sfx_lib[f] = load("res://assets/sfx/%s.ogg" % f)
	K = preload("res://scripts/skills.gd").new(); K.w = self; add_child(K)
	player = spawn("Knight", Vector3(0, 0, 44), 0)
	player.died.connect(func(a): get_tree().create_timer(2.5).timeout.connect(func(): a.global_position = Vector3(0, 0, 40); a.revive(); a.hp = a.hp_max))
	_ui()
	K.apply_class(); refresh_labels()
	_camps()
	await get_tree().create_timer(0.3).timeout
	loading.queue_free()
	if "--shots" in OS.get_cmdline_user_args(): _shots()

func spawn(c: String, p: Vector3, team: int) -> Actor:
	var a := Actor.new()
	a.position = p; add_child(a)
	a.setup(c, self, team)
	actors.append(a)
	return a

func remove_actor(a: Actor) -> void:
	if not is_instance_valid(a): return
	actors.erase(a); a.queue_free()

func on_basic(a: Actor, c: int) -> bool: return K.on_basic(a, c)

# ---------- animations créées sur mesure ----------
func _extra_anims() -> void:
	var lib := Actor.LIB
	if lib.has_animation("Think"): return
	lib.add_animation("Think", _pose_from("Idle_A", {"upperarm.r": Vector3(1.2, 0, 0.9), "lowerarm.r": Vector3(0, 0, 2.6), "head": Vector3(-0.18, 0.25, 0.15), "upperarm.l": Vector3(0, 0, 0.6), "lowerarm.l": Vector3(0, 0, 1.8)}))
	lib.add_animation("Hurt_Idle", _pose_from("Idle_B", {"spine": Vector3(0.35, 0, 0), "head": Vector3(-0.2, 0, 0), "upperarm.l": Vector3(0.3, 0, 0)}))

func _pose_from(src: String, rots: Dictionary) -> Animation:
	var a: Animation = Actor.LIB.get_animation(src).duplicate(true)
	a.loop_mode = Animation.LOOP_LINEAR
	for b in rots:
		var t := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if t < 0: continue
		var q := Quaternion.from_euler(rots[b])
		for k in a.track_get_key_count(t):
			a.track_set_key_value(t, k, (a.track_get_key_value(t, k) as Quaternion) * q)
	return a

# ---------- monde ----------
func _world() -> void:
	var env := WorldEnvironment.new(); var e := Environment.new()
	var sky := Sky.new(); var sm := ProceduralSkyMaterial.new()
	sm.sky_top_color = Color(0.25, 0.45, 0.85); sm.sky_horizon_color = Color(0.85, 0.75, 0.65)
	sm.ground_horizon_color = Color(0.5, 0.45, 0.4); sky.sky_material = sm
	e.background_mode = Environment.BG_SKY; e.sky = sky
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.66, 0.8); e.ambient_light_energy = 0.42
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_white = 1.4
	e.fog_enabled = true; e.fog_light_color = Color(0.75, 0.8, 0.9); e.fog_density = 0.0022
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 0.95; sun.light_color = Color(1, 0.95, 0.85)
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 40.0
	add_child(sun)
	town = preload("res://scripts/town.gd").new(); add_child(town); town.build()
	var vr := RandomNumberGenerator.new(); vr.seed = 3
	var vp := preload("res://scripts/villager.gd")
	for path in town.walk_paths:
		for k in 2:
			var v := Node3D.new(); v.set_script(vp); add_child(v); v.setup(path, vr)
	for sp in town.spots.slice(0, 10):
		var v := Node3D.new(); v.set_script(vp); add_child(v); v.setup(PackedVector3Array([sp]), vr)
	cam = Camera3D.new(); cam.fov = 50; cam.far = 260; add_child(cam)
	var kn: Node = (load("res://assets/chars/Knight.glb") as PackedScene).instantiate()
	blade_mesh = (kn.find_child("2H_Sword", true, false).get_child(0) as MeshInstance3D).mesh
	kn.free()

var _perf_t := 0.0
func _process(dt: float) -> void:
	if not player or not pad: return
	_perf_t += dt
	if _perf_t > 5.0: _perf_t = 0; print("PERF fps=%d draw=%d obj=%d" % [Engine.get_frames_per_second(), Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), Performance.get_monitor(Performance.RENDER_TOTAL_OBJECTS_IN_FRAME)])
	player.move_in = pad.stick
	pad.cd = K.cd; pad.cd_max = K.cd_max; pad.chan = K.channel / K.channel_max if K.channel > 0 else 0.0
	pad.queue_redraw()
	var t := player.global_position + Vector3(0, 1.0, 0)
	var want := t + Vector3(0, cam_dist * 0.82, cam_dist * 0.58)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-8 * dt)) if cam.global_position != Vector3.ZERO else want
	cam.look_at(t)
	if shake_t > 0:
		shake_t -= dt
		cam.h_offset = randf_range(-1, 1) * shake_t * 0.6; cam.v_offset = randf_range(-1, 1) * shake_t * 0.6
	else: cam.h_offset = 0; cam.v_offset = 0
	_dir_t -= dt
	if _dir_t <= 0: _dir_t = 0.3; _director()
	pad.hp = player.hp / player.hp_max
	pad.boss = boss if is_instance_valid(boss) and boss.aware and boss.state != "dead" else null

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMagnifyGesture: cam_dist = clamp(cam_dist / ev.factor, 5, 26)
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: cam_dist = max(cam_dist - 0.6, 5)
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam_dist = min(cam_dist + 0.6, 18)

# ---------- effets ----------
func sfx(n: String, p: Vector3) -> void:
	var k := n
	if n == "hit": k = ["hit1","hit2","hit3"].pick_random()
	elif n == "swing": k = ["swing1","swing2"].pick_random()
	if not sfx_lib.has(k): return
	var s := AudioStreamPlayer3D.new(); s.stream = sfx_lib[k]; s.pitch_scale = randf_range(0.92, 1.08)
	add_child(s); s.global_position = p; s.play(); s.finished.connect(s.queue_free)

func shake(t: float) -> void: shake_t = max(shake_t, t)

func _unlit(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED; return m

func _fade(n: Node3D, m: StandardMaterial3D, t: float, delay := 0.0) -> void:
	var tw := n.create_tween(); tw.tween_interval(delay); tw.tween_property(m, "albedo_color:a", 0.0, t); tw.tween_callback(n.queue_free)

func burst(p: Vector3, c: Color, n: int) -> void:
	var pt := CPUParticles3D.new(); pt.one_shot = true; pt.amount = n; pt.lifetime = 0.6; pt.explosiveness = 0.95
	var q := QuadMesh.new(); q.size = Vector2(0.12, 0.12); pt.mesh = q
	var m := _unlit(c); m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pt.material_override = m
	pt.direction = Vector3.UP; pt.spread = 180; pt.initial_velocity_min = 2; pt.initial_velocity_max = 5
	pt.gravity = Vector3(0, -9, 0); pt.scale_amount_min = 0.6; pt.scale_amount_max = 1.4
	add_child(pt); pt.global_position = p; pt.emitting = true
	get_tree().create_timer(0.9).timeout.connect(pt.queue_free)

func number(p: Vector3, v: float, c: Color, sz := 1.0) -> void:
	var l := Label3D.new(); l.text = str(int(round(v))); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = int(64 * sz); l.outline_size = int(10 * sz); l.modulate = c; l.outline_modulate = Color(0, 0, 0, 0.9)
	l.no_depth_test = true; l.pixel_size = 0.006
	add_child(l); l.global_position = p + Vector3(randf_range(-0.4, 0.4), 2.0, 0)
	var tw := l.create_tween(); tw.set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.1, 0.75).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

func ring(p: Vector3, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.9; t.outer_radius = 1.0; t.rings = 40; t.ring_segments = 4
	mi.mesh = t; var m := _unlit(c); mi.material_override = m; add_child(mi); mi.global_position = p + Vector3.UP * 0.1
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var tw := mi.create_tween(); tw.set_parallel()
	tw.tween_property(mi, "scale", Vector3(r, 0.3, r), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.5)
	tw.chain().tween_callback(mi.queue_free)

func beam_between(a: Actor, b: Actor, c: Color) -> void:
	var p1 := a.global_position + Vector3.UP * 1.2; var p2 := b.global_position + Vector3.UP * 1.0
	var mi := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.06; cy.bottom_radius = 0.06; cy.height = p1.distance_to(p2); cy.radial_segments = 6; cy.rings = 1
	mi.mesh = cy; var m := _unlit(c); mi.material_override = m; add_child(mi)
	mi.global_position = (p1 + p2) * 0.5
	if p1.distance_to(p2) > 0.1: mi.look_at(p2, Vector3.UP if abs((p2 - p1).normalized().y) < 0.99 else Vector3.RIGHT); mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	_fade(mi, m, 0.25)

func projectile(a: Actor, kind: String, act: Array) -> void:
	var col: Color = {"bolt": Color(0.4, 0.75, 1), "knife": Color(0.9, 0.9, 1), "rock": Color(0.6, 0.5, 0.4), "bomb": Color(1, 0.5, 0.1)}[kind]
	if a.team == 1: col = Color(0.7, 0.3, 1)
	var mi := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.16; s.height = 0.32; s.radial_segments = 8; s.rings = 4
	mi.mesh = s; mi.material_override = _unlit(col); add_child(mi)
	mi.global_position = a.global_position + Vector3.UP * 1.3 + a.fwd() * 0.6
	var dir := a.fwd()
	var t := a.target if a.brain != "" else a.nearest_foe(14)
	if t and is_instance_valid(t): dir = ((t.global_position + Vector3.UP) - mi.global_position).normalized()
	var proc := Node.new(); mi.add_child(proc)
	proc.set_script(preload("res://scripts/proj.gd"))
	proc.init(self, a, dir * (18.0 if kind != "bomb" else 11.0) + Vector3.UP * (0.0 if kind in ["bolt","knife"] else 4.5), act, kind, col)

func cluster(a: Actor, r: float) -> Vector3:
	var best := Vector3.INF; var bn := 0
	for o in actors:
		if not a.foe(o) or o.global_position.distance_to(a.global_position) > r: continue
		var n := 0
		for q in actors: if a.foe(q) and q.global_position.distance_to(o.global_position) < 3: n += 1
		if n > bn: bn = n; best = o.global_position
	return best

func time_stop(owner: Actor, dur: float) -> void:
	tstop = true
	for a in actors: if a != owner: a.freeze(true)
	owner.speed_mul *= 1.5
	ring(owner.global_position, 14.0, Color(0.5, 0.85, 1))
	overlay.visible = true
	var tw := overlay.create_tween(); (overlay.material as ShaderMaterial).set_shader_parameter("amt", 0.0)
	tw.tween_method(func(v): (overlay.material as ShaderMaterial).set_shader_parameter("amt", v), 0.0, 1.0, 0.25)
	get_tree().create_timer(dur).timeout.connect(func():
		tstop = false; owner.speed_mul /= 1.5
		overlay.visible = false
		shake(0.3); ring(owner.global_position, 10.0, Color(0.5, 0.85, 1))
		for a in actors.duplicate(): if is_instance_valid(a): a.freeze(false))

func portal(p: Vector3) -> void:
	var mi := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.75; t.outer_radius = 1.0; t.rings = 32; t.ring_segments = 8
	mi.mesh = t; var m := _unlit(Color(0.75, 0.45, 1, 0.95)); m.emission_enabled = true; mi.material_override = m
	add_child(mi); mi.global_position = p + Vector3.UP * 1.1; mi.rotation.x = PI / 2
	mi.scale = Vector3(0.1, 0.1, 0.1)
	var d := MeshInstance3D.new(); var dm := CylinderMesh.new(); dm.top_radius = 0.8; dm.bottom_radius = 0.8; dm.height = 0.02; dm.radial_segments = 24
	d.mesh = dm; var m2 := _unlit(Color(0.3, 0.1, 0.5, 0.75)); d.material_override = m2; mi.add_child(d)
	var tw := mi.create_tween(); tw.tween_property(mi, "scale", Vector3(1.3, 1.3, 1.3), 0.2).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_interval(0.6); tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 0.05), 0.25); tw.tween_callback(mi.queue_free)
	burst(p + Vector3.UP, Color(0.8, 0.5, 1), 24)

func wings(a: Actor) -> void:
	var ba := BoneAttachment3D.new(); ba.bone_name = "chest"; a.skel.add_child(ba)
	var m := _unlit(Color(1, 0.97, 0.85, 0.92)); m.emission_enabled = true; m.emission = Color(1, 0.9, 0.6); m.emission_energy_multiplier = 0.6
	for sgn in [-1, 1]:
		var piv := Node3D.new(); piv.position = Vector3(0.12 * sgn, 0.25, -0.25); ba.add_child(piv)
		for k in 3:
			var f := MeshInstance3D.new(); var pr := PrismMesh.new(); pr.size = Vector3(0.35, 1.3 - k * 0.3, 0.04); pr.left_to_right = 0.0 if sgn > 0 else 1.0
			f.mesh = pr; f.material_override = m; f.position = Vector3(0.5 * sgn + 0.1 * k * sgn, 0.25 - k * 0.22, -0.05 * k); f.rotation.z = -0.5 * sgn - k * 0.25 * sgn
			piv.add_child(f)
		var tw := piv.create_tween().set_loops(); tw.tween_property(piv, "rotation:y", 0.5 * sgn, 0.35).set_trans(Tween.TRANS_SINE); tw.tween_property(piv, "rotation:y", -0.1 * sgn, 0.35).set_trans(Tween.TRANS_SINE)

func unbubble(a: Actor) -> void:
	var b := a.get_node_or_null("Bubble")
	if b: b.queue_free()

func bubble(a: Actor, t: float) -> void:
	var mi := MeshInstance3D.new(); mi.name = "Bubble"; var s := SphereMesh.new(); s.radius = 1.2; s.height = 2.4; s.radial_segments = 20; s.rings = 10
	mi.mesh = s; var m := _unlit(Color(1, 0.92, 0.5, 0.28)); mi.material_override = m; a.add_child(mi); mi.position.y = 1.0 * a.size_k; mi.scale = Vector3.ONE * a.size_k
	_fade(mi, m, 0.3, t)

func divine_blade(c: Vector3, r: float, dmg: float, st: float) -> void:
	# faisceau de lumière
	var col := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 0.9; cy.bottom_radius = 0.9; cy.height = 30; cy.radial_segments = 16; cy.rings = 1
	col.mesh = cy; var cm := _unlit(Color(1, 0.92, 0.55, 0.0)); col.material_override = cm; add_child(col); col.global_position = c + Vector3.UP * 15
	var tw := col.create_tween(); tw.tween_property(cm, "albedo_color:a", 0.45, 0.5); tw.tween_interval(0.7); tw.tween_property(cm, "albedo_color:a", 0.0, 0.6); tw.tween_callback(col.queue_free)
	var dust := CPUParticles3D.new(); dust.amount = 60; dust.lifetime = 1.4; var q := QuadMesh.new(); q.size = Vector2(0.08, 0.08); dust.mesh = q
	var dm := _unlit(Color(1, 0.95, 0.6)); dm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; dust.material_override = dm
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; dust.emission_sphere_radius = 1.2; dust.direction = Vector3.DOWN; dust.gravity = Vector3(0, -1.5, 0)
	dust.initial_velocity_min = 0.5; dust.initial_velocity_max = 2; add_child(dust); dust.global_position = c + Vector3.UP * 5
	get_tree().create_timer(2.2).timeout.connect(dust.queue_free)
	ring(c, r, Color(1, 0.85, 0.4))
	# l'épée tombe
	var sw := MeshInstance3D.new(); sw.mesh = blade_mesh; var smat := StandardMaterial3D.new(); smat.albedo_color = Color(1, 0.95, 0.8)
	smat.emission_enabled = true; smat.emission = Color(1, 0.85, 0.45); smat.emission_energy_multiplier = 1.2; sw.material_override = smat
	add_child(sw); sw.global_position = c + Vector3.UP * 16; sw.rotation.z = PI; sw.scale = Vector3.ONE * 3.2
	var tw2 := sw.create_tween(); tw2.tween_interval(0.55); tw2.tween_property(sw, "global_position:y", c.y + 2.3, 0.22).set_ease(Tween.EASE_IN)
	tw2.tween_callback(func():
		shake(0.45); ring(c, r, Color(1, 0.95, 0.6)); ring(c, r * 0.6, Color(1, 1, 1)); burst(c + Vector3.UP * 0.5, Color(1, 0.9, 0.5), 50); sfx("slam", c)
		for o in actors:
			if o.team == 1 and o.state != "dead" and o.global_position.distance_to(c) < r:
				o.hurt(dmg * player.dmg_mul, c, 4, player); o.stun(st))
	tw2.tween_interval(1.6); tw2.tween_property(sw, "scale", Vector3.ZERO, 0.4); tw2.tween_callback(sw.queue_free)

func lightning(p: Vector3) -> void:
	var m := _unlit(Color(0.75, 0.85, 1, 1)); m.emission_enabled = true
	var root := Node3D.new(); add_child(root); root.global_position = p
	var y := 12.0; var x := Vector3.ZERO
	while y > 0:
		var ny: float = max(y - randf_range(1.2, 2.4), 0.0)
		var nx := Vector3(randf_range(-0.6, 0.6), 0, randf_range(-0.6, 0.6)) if ny > 0 else Vector3.ZERO
		var a := Vector3(x.x, y, x.z); var b := Vector3(nx.x, ny, nx.z)
		var seg := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(0.12, a.distance_to(b), 0.12); seg.mesh = bm; seg.material_override = m
		root.add_child(seg); seg.position = (a + b) * 0.5
		seg.look_at(root.global_position + b, Vector3.RIGHT); seg.rotate_object_local(Vector3.RIGHT, PI / 2)
		y = ny; x = nx
	ring(p, 1.6, Color(0.7, 0.85, 1)); burst(p + Vector3.UP * 0.3, Color(0.8, 0.9, 1), 16); shake(0.12); sfx("hit", p)
	_fade(root, m, 0.25, 0.08)

func roots(a: Actor) -> void:
	var m := StandardMaterial3D.new(); m.albedo_color = Color(0.35, 0.25, 0.12); m.roughness = 1
	var root := Node3D.new(); a.add_child(root)
	for i in 6:
		var mi := MeshInstance3D.new(); var cn := CylinderMesh.new(); cn.top_radius = 0.0; cn.bottom_radius = 0.09; cn.height = 0.9; cn.radial_segments = 5; cn.rings = 1
		mi.mesh = cn; mi.material_override = m; root.add_child(mi)
		var ang := i * TAU / 6
		mi.position = Vector3(cos(ang) * 0.45, 0.3, sin(ang) * 0.45); mi.rotation = Vector3(sin(ang) * 0.5, 0, -cos(ang) * 0.5)
	root.scale = Vector3(1, 0.1, 1)
	var tw := root.create_tween(); tw.tween_property(root, "scale", Vector3.ONE, 0.2); tw.tween_interval(max(a.root_t - 0.4, 0.3)); tw.tween_property(root, "scale", Vector3(1, 0.05, 1), 0.2); tw.tween_callback(root.queue_free)

func afterimage(a: Actor) -> void:
	burst(a.global_position + Vector3.UP, Color(0.8, 0.1, 0.2), 12)

# ---------- monstres : camps, directeur de combat, attaques annoncées ----------
var camps: Array = []          # [centre, types, monstres, minuterie de réapparition]
var boss: Monster
var _dir_t := 0.0

func spawn_mob(k: String, p: Vector3) -> Monster:
	var m := Monster.new(); m.position = p; add_child(m)
	m.setup({"brute": "Skeleton_Rogue", "archer": "Skeleton_Mage", "rodeur": "Skeleton_Rogue", "boss": "Knight"}[k], self, 1)
	m.init_mob(k, p); actors.append(m)
	return m

func _camps() -> void:
	camps = [[Vector3(0, 0, 80), ["brute", "archer", "rodeur"]], [Vector3(-30, 0, 98), ["archer", "rodeur", "archer"]], [Vector3(40, 0, 74), ["brute", "brute", "archer"]]]
	for c in camps: c.append([]); c.append(0.0); _fill_camp(c)
	_arena()

func _fill_camp(c: Array) -> void:
	c[2].clear()
	var i := 0
	for k in c[1]:
		c[2].append(spawn_mob(k, c[0] + Vector3(cos(i * 2.1), 0, sin(i * 2.1)) * 2.5)); i += 1

func _arena() -> void:
	var ctr := Vector3(0, 0, 128)
	var floor := MeshInstance3D.new(); var cy := CylinderMesh.new(); cy.top_radius = 17; cy.bottom_radius = 17.5; cy.height = 0.12; cy.radial_segments = 40
	floor.mesh = cy; floor.material_override = town._pave(Color(0.5, 0.47, 0.5), Color(0.3, 0.28, 0.3), 0.9); add_child(floor); floor.position = ctr + Vector3.UP * 0.04
	var sm := StandardMaterial3D.new(); sm.albedo_color = Color(0.55, 0.52, 0.55); sm.roughness = 0.9
	for k in 4:
		var pp := ctr + Vector3(cos(k * PI / 2 + PI / 4), 0, sin(k * PI / 2 + PI / 4)) * 9.0
		var b := StaticBody3D.new(); b.add_to_group("pillar"); add_child(b); b.position = pp
		var cs := CollisionShape3D.new(); var sh := CylinderShape3D.new(); sh.radius = 1.2; sh.height = 7; cs.shape = sh; cs.position.y = 3.5; b.add_child(cs)
		var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.25; cm.height = 7; cm.radial_segments = 10
		mi.mesh = cm; mi.material_override = sm; mi.position.y = 3.5; b.add_child(mi)
	for k in 14:
		var a := k * TAU / 14
		town.put("Rock_1_%s_Color1" % ["A", "B", "C", "D"][k % 4], ctr + Vector3(cos(a), 0, sin(a)) * 18.5, a, 6.0)
	boss = spawn_mob("boss", ctr)

func on_mob_dead(m: Monster) -> void:
	get_tree().create_timer(3.0).timeout.connect(func(): remove_actor(m))
	if m == boss:
		flash_text(m.global_position, "VICTOIRE", Color(1, 0.85, 0.3), 3.0)
		get_tree().create_timer(90.0).timeout.connect(func(): boss = spawn_mob("boss", Vector3(0, 0, 128)))

## Directeur : places en cercle autour du joueur, 2 assaillants au contact maximum (combat lisible, pas de mêlée confuse)
func _director() -> void:
	for c in camps:
		var alive: Array = c[2].filter(func(x): return is_instance_valid(x) and x.state != "dead")
		if alive.is_empty():
			c[3] += 0.3
			if c[3] > 40 and player.global_position.distance_to(c[0]) > 25: c[3] = 0.0; _fill_camp(c)
	var eng: Array = []
	for a in actors:
		if a is Monster and a.aware and a.state != "dead" and a.kind != "boss": eng.append(a)
	if eng.is_empty(): return
	var pp := player.global_position
	eng.sort_custom(func(x, y): return x.global_position.distance_to(pp) < y.global_position.distance_to(pp))
	var tokens := 0
	var angs: Array = []
	for m in eng:
		var melee: bool = m.kind != "archer"
		m.token = melee and tokens < 2
		if m.token: tokens += 1
		var d: Vector3 = m.global_position - pp
		angs.append(atan2(d.z, d.x))
	# écarte les angles trop proches pour encercler au lieu de s'empiler
	for it in 4:
		for i in angs.size():
			for j in angs.size():
				if i == j: continue
				var df := wrapf(angs[j] - angs[i], -PI, PI)
				if abs(df) < 0.9: angs[i] -= sign(df) * 0.12 if df != 0 else 0.12
	for i in eng.size():
		var m: Monster = eng[i]
		var r := 2.2 if m.token else (8.0 if m.kind == "archer" else 5.0)
		m.slot = pp + Vector3(cos(angs[i]), 0, sin(angs[i])) * r

func _tele_mesh(mode: int, size: Vector2, col: Color, half := 0.8) -> Array:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = size; mi.mesh = pm
	var m := ShaderMaterial.new(); m.shader = preload("res://scripts/tele.gdshader")
	m.set_shader_parameter("mode", mode); m.set_shader_parameter("col", col); m.set_shader_parameter("half_ang", half)
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)
	return [mi, m]

func _tele_run(o: Monster, mm: Array, T: float, resolve: Callable) -> void:
	var tw: Tween = mm[0].create_tween()
	tw.tween_method(func(v): mm[1].set_shader_parameter("prog", v), 0.0, 1.0, T)
	tw.tween_callback(func():
		mm[0].queue_free()
		if is_instance_valid(o) and o.state != "dead" and o.stun_t <= 0 and not o.frozen: resolve.call())

func _hit_team0(o: Monster, test: Callable, dmg: float, force: float, from: Vector3) -> void:
	if dmg <= 0: return
	for a in actors:
		if a.team == 0 and a.state != "dead" and a.iframes <= 0 and test.call(a.global_position): a.hurt(dmg * o.dmg_mul, from, force, o)

func tele_circle(o: Monster, c: Vector3, r: float, T: float, dmg: float, force: float) -> void:
	var mm := _tele_mesh(0, Vector2(r * 2, r * 2), Color(1, 0.15, 0.1)); mm[0].global_position = c + Vector3.UP * 0.07
	_tele_run(o, mm, T, func():
		ring(c, r, Color(1, 0.5, 0.3)); burst(c + Vector3.UP * 0.3, Color(0.9, 0.8, 0.7), 16); shake(0.15); sfx("slam", c)
		_hit_team0(o, func(p: Vector3): return Vector2(p.x - c.x, p.z - c.z).length() < r + 0.3, dmg, force, c))

func tele_cone(o: Monster, c: Vector3, dir: Vector3, r: float, half_deg: float, T: float, dmg: float, force: float) -> void:
	var mm := _tele_mesh(1, Vector2(r * 2, r * 2), Color(1, 0.15, 0.1), deg_to_rad(half_deg))
	mm[0].global_position = c + Vector3.UP * 0.07; mm[0].rotation.y = atan2(dir.x, dir.z)
	_tele_run(o, mm, T, func():
		burst(c + dir * r * 0.6 + Vector3.UP, Color(1, 0.6, 0.4), 14); sfx("swing", c)
		_hit_team0(o, func(p: Vector3):
			var d := p - c; d.y = 0
			return d.length() < r + 0.3 and rad_to_deg(dir.angle_to(d.normalized())) < half_deg + 6, dmg, force, c))

func tele_line(o: Monster, c: Vector3, dir: Vector3, L: float, wd: float, T: float, dmg: float, force: float) -> void:
	var mm := _tele_mesh(2, Vector2(wd, L), Color(1, 0.25, 0.1))
	mm[0].global_position = c + dir * L * 0.5 + Vector3.UP * 0.07; mm[0].rotation.y = atan2(dir.x, dir.z)
	_tele_run(o, mm, T, func():
		_hit_team0(o, func(p: Vector3):
			var d := p - c; d.y = 0; var along := d.dot(dir)
			return along > 0 and along < L and (d - dir * along).length() < wd * 0.5 + 0.3, dmg, force, c))

func mob_bolt(o: Monster, aimp: Vector3, spd: float, dmg: float) -> void:
	var mi := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.2; s.height = 0.4; s.radial_segments = 8; s.rings = 4
	mi.mesh = s; mi.material_override = _unlit(Color(0.75, 0.3, 1)); add_child(mi)
	mi.global_position = o.global_position + Vector3.UP * 1.4 + o.fwd() * 0.6
	var dir := (aimp + Vector3.UP - mi.global_position).normalized()
	var proc := Node.new(); mi.add_child(proc); proc.set_script(preload("res://scripts/proj.gd"))
	proc.init(self, o, dir * spd, ["", dmg, 0, 0, 2, false, "bolt"], "bolt", Color(0.75, 0.3, 1))

func flash_text(p: Vector3, t: String, c: Color, sz := 1.0) -> void:
	var l := Label3D.new(); l.text = t; l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.font_size = int(46 * sz); l.outline_size = 10
	l.modulate = c; l.outline_modulate = Color(0, 0, 0, 0.9); l.no_depth_test = true; l.pixel_size = 0.006
	add_child(l); l.global_position = p + Vector3(0, 2.8, 0)
	var tw := l.create_tween(); tw.set_parallel(); tw.tween_property(l, "global_position:y", l.global_position.y + 0.8, 0.9)
	tw.tween_property(l, "modulate:a", 0.0, 0.5).set_delay(0.5); tw.chain().tween_callback(l.queue_free)

func boss_intro(m: Monster) -> void:
	shake(0.4); flash_text(m.global_position + Vector3.UP * 3, m.display_name.to_upper(), Color(0.9, 0.5, 1), 2.2)

# ---------- interface ----------
func refresh_labels() -> void:
	pad.labels = K.labels()

func _ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	overlay = ColorRect.new(); overlay.set_anchors_preset(Control.PRESET_FULL_RECT); overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var osh := ShaderMaterial.new(); osh.shader = load("res://scripts/timestop.gdshader"); overlay.material = osh; overlay.visible = false
	ui.add_child(overlay)
	var th := Theme.new(); th.default_font_size = 22
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.07, 0.1, 0.78); sb.set_corner_radius_all(12)
	sb.border_color = Color(0.95, 0.75, 0.3); sb.set_border_width_all(2); sb.set_content_margin_all(8)
	var sp := sb.duplicate(); sp.bg_color = Color(0.35, 0.25, 0.08, 0.9)
	th.set_stylebox("normal", "Button", sb); th.set_stylebox("hover", "Button", sb); th.set_stylebox("pressed", "Button", sp)
	th.set_stylebox("panel", "ItemList", sb)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = th
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	pad = Pad.new(); pad.set_anchors_preset(Control.PRESET_FULL_RECT); pad.main = self; root.add_child(pad)
	var mini := preload("res://scripts/minimap.gd").new(); mini.main = self; root.add_child(mini)
	pad.minimap_rect = Rect2(Vector2(1280 - 250, 12), Vector2(238, 238))

# ---------- captures automatiques ----------
func _snap(n: String) -> void:
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % n); print("SHOT ", n)

func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	while is_instance_valid(loading): await get_tree().process_frame
	var views := [[Vector3(0, 0, 70), 13.0, "camp_a", 2.5], [Vector3(0, 0, 70), 13.0, "camp_b", 1.5], [Vector3(0, 0, 116), 18.0, "boss_a", 2.5], [Vector3(0, 0, 116), 18.0, "boss_b", 1.6]]
	for v in views:
		player.global_position = v[0]; cam_dist = v[1]; player.hp = player.hp_max
		await get_tree().create_timer(v[3]).timeout
		_snap(v[2])
	print("SHOTS_DONE")
	get_tree().quit()
