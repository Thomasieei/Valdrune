extends Node3D
## Studio Lab : arène de test des classes (déplacement, combat, toutes les animations).

const CHARS := ["Knight", "Barbarian", "Mage", "Rogue_Hooded"]
const NAMES := {"Knight":"Chevalier", "Barbarian":"Barbare", "Mage":"Mage", "Rogue_Hooded":"Assassin"}
const STYLE_FR := {"unarmed":"Mains nues","1h":"Épée/bouclier","2h":"Deux mains","dual":"Double lame","magic":"Bâton","xbow":"Arbalète","sneak":"Furtif"}

var actors: Array = []
var player: Actor
var dummy: Actor
var cam: Camera3D
var cam_dist := 9.0
var shake_t := 0.0
var ci := 0
var riposte := false
var sfx_lib := {}
var ui: CanvasLayer
var pad: Pad
var lbl_fps: Label
var btn_char: Button
var btn_style: Button
var panel: ItemList

func _ready() -> void:
	_extra_anims()
	_world()
	for f in ["swing1","swing2","hit1","hit2","hit3","jump","land","dash","slam"]:
		sfx_lib[f] = load("res://assets/sfx/%s.ogg" % f)
	player = _spawn("Knight", Vector3(0, 0, 0), 0)
	dummy = _spawn("Barbarian", Vector3(0, 0, 4), 1)
	dummy.rotation.y = PI; dummy.face = PI
	dummy.died.connect(func(a): get_tree().create_timer(2.5).timeout.connect(a.revive))
	_ui()
	if "--shots" in OS.get_cmdline_user_args(): _shots()

func _spawn(c: String, p: Vector3, team: int) -> Actor:
	var a := Actor.new()
	a.position = p; add_child(a)
	a.setup(c, self, team)
	actors.append(a)
	return a

# ---------- animations créées sur mesure ----------
func _extra_anims() -> void:
	var lib := Actor.LIB
	if lib.has_animation("Think"): return
	# Réfléchir : main au menton, tête penchée, sur la respiration d'Idle_A
	var th := _pose_from("Idle_A", {"upperarm.r": Vector3(1.2, 0, 0.9), "lowerarm.r": Vector3(0, 0, 2.6), "head": Vector3(-0.18, 0.25, 0.15), "upperarm.l": Vector3(0, 0, 0.6), "lowerarm.l": Vector3(0, 0, 1.8)})
	lib.add_animation("Think", th)
	# Garde basse fatiguée (blessé) : buste penché
	lib.add_animation("Hurt_Idle", _pose_from("Idle_B", {"spine": Vector3(0.35, 0, 0), "head": Vector3(-0.2, 0, 0), "upperarm.l": Vector3(0.3, 0, 0)}))

func _pose_from(src: String, rots: Dictionary) -> Animation:
	var a: Animation = Actor.LIB.get_animation(src).duplicate(true)
	a.loop_mode = Animation.LOOP_LINEAR
	for b in rots:
		var t := a.find_track(NodePath("Skeleton3D:" + b), Animation.TYPE_ROTATION_3D)
		if t < 0: continue
		var e: Vector3 = rots[b]
		var q := Quaternion.from_euler(e)
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
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(0.62, 0.66, 0.8); e.ambient_light_energy = 0.55
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC; e.tonemap_white = 1.4
	env.environment = e; add_child(env)
	var sun := DirectionalLight3D.new(); sun.rotation_degrees = Vector3(-52, 35, 0)
	sun.light_energy = 1.05; sun.light_color = Color(1, 0.95, 0.85)
	sun.shadow_enabled = true; sun.directional_shadow_mode = DirectionalLight3D.SHADOW_ORTHOGONAL
	sun.directional_shadow_max_distance = 28.0
	add_child(sun)
	# sol : un seul plan + shader (dalles + herbe), 1 draw call
	var g := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(120, 120); g.mesh = pm
	var sh := ShaderMaterial.new(); sh.shader = load("res://scripts/ground.gdshader"); g.material_override = sh
	add_child(g)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bs := BoxShape3D.new()
	bs.size = Vector3(120, 1, 120); cs.shape = bs; cs.position.y = -0.5; body.add_child(cs); add_child(body)
	# quelques piliers et marches (tester saut/chute/collision)
	var mat := StandardMaterial3D.new(); mat.albedo_color = Color(0.62, 0.58, 0.52); mat.roughness = 0.9
	for p in [[Vector3(-6,0.5,-3), Vector3(3,1,3)], [Vector3(-6,1.5,-3), Vector3(1.8,1,1.8)], [Vector3(7,1.6,2), Vector3(2.2,3.2,2.2)], [Vector3(-3,4,8), Vector3(4,0.5,4)]]:
		var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var x := BoxShape3D.new(); x.size = p[1]; c.shape = x; b.add_child(c)
		var mi := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = p[1]; mi.mesh = bm; mi.material_override = mat; b.add_child(mi)
		b.position = p[0]; add_child(b)
	cam = Camera3D.new(); cam.fov = 50; cam.far = 120; add_child(cam)

func _process(dt: float) -> void:
	if pad:
		player.move_in = pad.stick.rotated(-0.0)
		lbl_fps.text = "%d FPS · %s · PV %d" % [Engine.get_frames_per_second(), NAMES[player.char_name], player.hp]
	var t := player.global_position + Vector3(0, 1.0, 0)
	var want := t + Vector3(0, cam_dist * 0.7, cam_dist * 0.75)
	cam.global_position = cam.global_position.lerp(want, 1.0 - exp(-8 * dt)) if cam.global_position != Vector3.ZERO else want
	cam.look_at(t)
	if shake_t > 0:
		shake_t -= dt
		cam.h_offset = randf_range(-1, 1) * shake_t * 0.6; cam.v_offset = randf_range(-1, 1) * shake_t * 0.6
	else: cam.h_offset = 0; cam.v_offset = 0
	# mannequin
	if dummy.state != "dead":
		var d := player.global_position - dummy.global_position
		if d.length() < 8 and dummy.can_act(): dummy.face = atan2(d.x, d.z)
		if riposte and d.length() < 2.3 and dummy.can_act() and randf() < dt * 0.9:
			dummy.attack()

func _unhandled_input(ev: InputEvent) -> void:
	if ev is InputEventMagnifyGesture: cam_dist = clamp(cam_dist / ev.factor, 5, 18)
	if ev is InputEventMouseButton and ev.pressed:
		if ev.button_index == MOUSE_BUTTON_WHEEL_UP: cam_dist = max(cam_dist - 0.6, 5)
		if ev.button_index == MOUSE_BUTTON_WHEEL_DOWN: cam_dist = min(cam_dist + 0.6, 18)

# ---------- effets (pool léger, tout s'autodétruit) ----------
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
	m.albedo_color = c; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; return m

func burst(p: Vector3, c: Color, n: int) -> void:
	var pt := CPUParticles3D.new(); pt.one_shot = true; pt.amount = n; pt.lifetime = 0.5; pt.explosiveness = 0.95
	var q := QuadMesh.new(); q.size = Vector2(0.12, 0.12); pt.mesh = q
	var m := _unlit(c); m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; pt.material_override = m
	pt.direction = Vector3.UP; pt.spread = 180; pt.initial_velocity_min = 2; pt.initial_velocity_max = 5
	pt.gravity = Vector3(0, -9, 0); pt.scale_amount_min = 0.6; pt.scale_amount_max = 1.4
	add_child(pt); pt.global_position = p; pt.emitting = true
	get_tree().create_timer(0.8).timeout.connect(pt.queue_free)

func number(p: Vector3, v: float, c: Color) -> void:
	var l := Label3D.new(); l.text = str(int(round(v))); l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.font_size = 72; l.outline_size = 10; l.modulate = c; l.outline_modulate = Color(0, 0, 0, 0.9); l.no_depth_test = true; l.pixel_size = 0.006
	add_child(l); l.global_position = p + Vector3(randf_range(-0.3, 0.3), 2.1, 0)
	var tw := l.create_tween(); tw.set_parallel()
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.2, 0.7).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.7).set_delay(0.25)
	tw.chain().tween_callback(l.queue_free)

func ring(p: Vector3, r: float, c: Color) -> void:
	var mi := MeshInstance3D.new(); var t := TorusMesh.new(); t.inner_radius = 0.85; t.outer_radius = 1.0; t.rings = 32; t.ring_segments = 6
	mi.mesh = t; mi.material_override = _unlit(c); add_child(mi); mi.global_position = p + Vector3.UP * 0.1
	mi.scale = Vector3(0.2, 0.2, 0.2)
	var tw := mi.create_tween(); tw.set_parallel()
	tw.tween_property(mi, "scale", Vector3(r, 0.3, r), 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.45)
	tw.chain().tween_callback(mi.queue_free)

func beam(a: Actor, r: float) -> void:
	var mi := MeshInstance3D.new(); var c := CylinderMesh.new(); c.top_radius = 0.12; c.bottom_radius = 0.12; c.height = r; c.radial_segments = 8
	mi.mesh = c; mi.material_override = _unlit(Color(0.5, 0.8, 1, 0.8)); add_child(mi)
	mi.global_position = a.global_position + Vector3.UP * 1.2 + a._fwd() * r * 0.5
	mi.look_at(mi.global_position + a._fwd(), Vector3.UP); mi.rotate_object_local(Vector3.RIGHT, PI / 2)
	var tw := mi.create_tween(); tw.tween_property(mi.material_override, "albedo_color:a", 0.0, 0.2); tw.tween_callback(mi.queue_free)

func projectile(a: Actor, kind: String, act: Array) -> void:
	var col: Color = {"bolt": Color(0.4, 0.75, 1), "knife": Color(0.9, 0.9, 1), "rock": Color(0.6, 0.5, 0.4), "bomb": Color(1, 0.5, 0.1)}[kind]
	var mi := MeshInstance3D.new(); var s := SphereMesh.new(); s.radius = 0.16; s.height = 0.32; s.radial_segments = 8; s.rings = 4
	mi.mesh = s; mi.material_override = _unlit(col); add_child(mi)
	mi.global_position = a.global_position + Vector3.UP * 1.3 + a._fwd() * 0.6
	var dir := a._fwd(); var spd := 18.0 if kind != "bomb" else 11.0
	var vy := 0.0 if kind in ["bolt","knife"] else 4.5
	var proc := Node.new(); mi.add_child(proc)
	proc.set_script(preload("res://scripts/proj.gd"))
	proc.init(self, a, dir * spd + Vector3.UP * vy, act, kind, col)

# ---------- interface ----------
func _ui() -> void:
	ui = CanvasLayer.new(); add_child(ui)
	var th := Theme.new(); th.default_font_size = 22
	var sb := StyleBoxFlat.new(); sb.bg_color = Color(0.08, 0.07, 0.1, 0.78); sb.set_corner_radius_all(12)
	sb.border_color = Color(0.95, 0.75, 0.3); sb.set_border_width_all(2); sb.set_content_margin_all(8)
	var sp := sb.duplicate(); sp.bg_color = Color(0.35, 0.25, 0.08, 0.9)
	th.set_stylebox("normal", "Button", sb); th.set_stylebox("hover", "Button", sb); th.set_stylebox("pressed", "Button", sp)
	th.set_stylebox("panel", "ItemList", sb)
	var root := Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.theme = th
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE; ui.add_child(root)
	pad = Pad.new(); pad.set_anchors_preset(Control.PRESET_FULL_RECT); pad.main = self; root.add_child(pad)
	var mk := func(t: String, pos: Vector2, w: float) -> Button:
		var b := Button.new(); b.text = t; b.position = pos; b.size = Vector2(w, 54); b.focus_mode = Control.FOCUS_NONE; root.add_child(b); return b
	btn_char = mk.call("", Vector2(12, 12), 200)
	btn_style = mk.call("", Vector2(220, 12), 230)
	var b_aim: Button = mk.call("Visée : non", Vector2(458, 12), 160)
	var b_rip: Button = mk.call("Riposte : non", Vector2(626, 12), 180)
	var b_anim: Button = mk.call("Animations", Vector2(814, 12), 170)
	lbl_fps = Label.new(); lbl_fps.position = Vector2(14, 74); lbl_fps.add_theme_font_size_override("font_size", 18)
	lbl_fps.add_theme_color_override("font_outline_color", Color.BLACK); lbl_fps.add_theme_constant_override("outline_size", 6); root.add_child(lbl_fps)
	panel = ItemList.new(); panel.visible = false; panel.focus_mode = Control.FOCUS_NONE
	panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_bottom = 1
	panel.offset_left = -400; panel.offset_right = -10; panel.offset_top = 80; panel.offset_bottom = -10
	root.add_child(panel)
	var names: Array = Array(Actor.LIB.get_animation_list()); names.sort()
	for n in names: panel.add_item(n)
	panel.item_selected.connect(func(i): player.play_any(panel.get_item_text(i)))
	btn_char.pressed.connect(func():
		ci = (ci + 1) % CHARS.size(); player.set_char(CHARS[ci]); player.shot("Spawn_Air", true); _labels())
	btn_style.pressed.connect(func():
		var i := player.styles.find(player.style); player.set_style(player.styles[(i + 1) % player.styles.size()]); _labels())
	b_aim.pressed.connect(func():
		player.aim_target = null if player.aim_target else dummy; b_aim.text = "Visée : " + ("oui" if player.aim_target else "non"))
	b_rip.pressed.connect(func():
		riposte = not riposte; b_rip.text = "Riposte : " + ("oui" if riposte else "non"))
	b_anim.pressed.connect(func(): panel.visible = not panel.visible; pad.blocked_rect = panel.get_global_rect() if panel.visible else Rect2())
	_labels()

func _labels() -> void:
	btn_char.text = "◀ " + NAMES[player.char_name] + " ▶"
	btn_style.text = "Style : " + STYLE_FR[player.style]
	pad.labels = {"1h":["Bond","Coup bouclier","Défi"], "2h":["Tourbillon","Toupie","Cri"], "dual":["Ombre","Lancer","Furtif"],
		"magic":["Rayon","Nova","Invoquer"], "xbow":["Recharger","Bombe","Saut arrière"], "unarmed":["Pierre","Provoquer","Coup de pied"]}.get(player.style, ["S1","S2","S3"])
	pad.queue_redraw()

# ---------- captures automatiques (CI) ----------
func _shots() -> void:
	DirAccess.make_dir_recursive_absolute("res://shots")
	var plan := [["Knight","1h","Idle_A"],["Knight","1h","Think"],["Barbarian","2h","Melee_2H_Attack_Spin"],["Mage","magic","Ranged_Magic_Spellcasting_Long"],
		["Rogue_Hooded","dual","Melee_Dualwield_Attack_Stab"],["Rogue_Hooded","xbow","Ranged_2H_Aiming"],["Knight","1h","Melee_Blocking"],["Mage","magic","Hurt_Idle"]]
	cam_dist = 5.5
	for i in plan.size():
		var p: Array = plan[i]
		player.set_char(p[0]); player.set_style(p[1]); player.play_any(p[2]); _labels()
		await get_tree().create_timer(0.55).timeout
		get_viewport().get_texture().get_image().save_png("res://shots/%02d_%s.png" % [i, p[2]])
		print("SHOT ", i, " ", p[2], " pos=", player.global_position, " st=", player.state)
	# combat : coups + projection
	player.set_char("Barbarian"); player.set_style("2h"); player.global_position = Vector3(0, 0, 2.6); player.face = 0
	player.skill(1)
	await get_tree().create_timer(0.75).timeout
	get_viewport().get_texture().get_image().save_png("res://shots/90_combat.png")
	print("SHOT combat dummy=", dummy.state, " hp=", dummy.hp)
	await get_tree().create_timer(1.2).timeout
	get_viewport().get_texture().get_image().save_png("res://shots/91_down.png")
	print("SHOTS_DONE ", Actor.LIB.get_animation_list().size())
	get_tree().quit()
