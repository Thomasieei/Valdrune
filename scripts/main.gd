extends Node3D
## Test rig auto Igris : joystick gauche + bouton attaque.

const SPEED := 2.4
var hero: Node3D
var ap: AnimationPlayer
var cam: Camera3D
var attacking := false
var move_dir := Vector2.ZERO
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var joy_touch := -1
var joy_ui: Control
var status: Label
const JOY_R := 110.0

func _ready() -> void:
	_build_world()
	hero = (load("res://assets/igris.glb") as PackedScene).instantiate()
	add_child(hero)
	var found := hero.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		ap = found[0] as AnimationPlayer
		print("IGRIS_ANIMS:", ap.get_animation_list())
		for n in ["Walk", "Idle"]:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		if ap.has_animation("Attack"):
			ap.get_animation("Attack").loop_mode = Animation.LOOP_NONE
		ap.animation_finished.connect(_on_anim_done)
		ap.play("Idle")
	cam = Camera3D.new()
	cam.fov = 55.0
	add_child(cam)
	cam.current = true
	_build_ui()
	_update_cam(1.0)

func _build_world() -> void:
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_COLOR
	e.background_color = Color(0.07, 0.05, 0.1)
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.55, 0.5, 0.65)
	e.ambient_light_energy = 0.7
	e.fog_enabled = true
	e.fog_light_color = Color(0.25, 0.08, 0.12)
	e.fog_density = 0.025
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	add_child(env)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-50, 35, 0)
	sun.light_energy = 1.3
	sun.light_color = Color(1.0, 0.92, 0.85)
	sun.shadow_enabled = true
	add_child(sun)
	var rim := OmniLight3D.new()
	rim.position = Vector3(0, 3, -4)
	rim.light_color = Color(1, 0.15, 0.2)
	rim.light_energy = 2.0
	rim.omni_range = 12.0
	add_child(rim)
	# sol dallé
	var floor_mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(60, 60)
	floor_mi.mesh = pm
	var fm := StandardMaterial3D.new()
	fm.albedo_color = Color(0.16, 0.14, 0.17)
	fm.roughness = 0.9
	floor_mi.material_override = fm
	add_child(floor_mi)
	# piliers + dalles pour sentir le mouvement
	var pillar_mat := StandardMaterial3D.new()
	pillar_mat.albedo_color = Color(0.28, 0.25, 0.3)
	var tile_mat := StandardMaterial3D.new()
	tile_mat.albedo_color = Color(0.45, 0.06, 0.1)
	tile_mat.emission_enabled = true
	tile_mat.emission = Color(0.6, 0.05, 0.1)
	tile_mat.emission_energy_multiplier = 0.6
	for i in range(-3, 4):
		for s in [-1, 1]:
			var p := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(0.9, 5.0, 0.9)
			p.mesh = bm
			p.material_override = pillar_mat
			p.position = Vector3(s * 6.0, 2.5, i * 6.0)
			add_child(p)
		var t := MeshInstance3D.new()
		var tm := BoxMesh.new()
		tm.size = Vector3(2.2, 0.03, 2.2)
		t.mesh = tm
		t.material_override = tile_mat
		t.position = Vector3(0, 0.015, i * 6.0)
		add_child(t)

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	joy_ui = Control.new()
	joy_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.draw.connect(_draw_joy)
	layer.add_child(joy_ui)
	var btn := Button.new()
	btn.text = "ATTAQUE"
	btn.add_theme_font_size_override("font_size", 30)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.55, 0.05, 0.1, 0.85)
	sb.border_color = Color(1, 0.75, 0.3)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(90)
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(0.9, 0.15, 0.2, 0.95)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.anchor_left = 1.0
	btn.anchor_top = 1.0
	btn.anchor_right = 1.0
	btn.anchor_bottom = 1.0
	btn.offset_left = -230
	btn.offset_top = -230
	btn.offset_right = -50
	btn.offset_bottom = -50
	btn.button_down.connect(_attack)
	layer.add_child(btn)
	status = Label.new()
	status.text = "IGRIS — test rig auto (squelette UAL)"
	status.position = Vector2(24, 16)
	status.add_theme_font_size_override("font_size", 26)
	status.add_theme_color_override("font_color", Color(1, 0.8, 0.5))
	status.add_theme_color_override("font_outline_color", Color.BLACK)
	status.add_theme_constant_override("outline_size", 6)
	layer.add_child(status)

func _draw_joy() -> void:
	var vp := joy_ui.get_viewport_rect().size
	var base := joy_center if joy_touch >= 0 else Vector2(200, vp.y - 200)
	var knob := joy_knob if joy_touch >= 0 else base
	joy_ui.draw_circle(base, JOY_R, Color(1, 1, 1, 0.12))
	joy_ui.draw_arc(base, JOY_R, 0, TAU, 48, Color(1, 0.8, 0.5, 0.6), 3.0)
	joy_ui.draw_circle(knob, 48, Color(0.85, 0.15, 0.2, 0.75))

func _input(event: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed and joy_touch < 0 and t.position.x < half:
			joy_touch = t.index
			joy_center = t.position
			joy_knob = t.position
		elif not t.pressed and t.index == joy_touch:
			joy_touch = -1
			move_dir = Vector2.ZERO
		joy_ui.queue_redraw()
	elif event is InputEventScreenDrag and (event as InputEventScreenDrag).index == joy_touch:
		var d: Vector2 = (event as InputEventScreenDrag).position - joy_center
		if d.length() > JOY_R:
			d = d.normalized() * JOY_R
		joy_knob = joy_center + d
		move_dir = d / JOY_R
		joy_ui.queue_redraw()

func _attack() -> void:
	if attacking or ap == null or not ap.has_animation("Attack"):
		return
	attacking = true
	ap.play("Attack", 0.12)

func _on_anim_done(anim_name: StringName) -> void:
	if anim_name == &"Attack":
		attacking = false
		ap.play("Idle", 0.2)

func _process(delta: float) -> void:
	if hero == null:
		return
	var moving := move_dir.length() > 0.15 and not attacking
	if moving:
		# caméra derrière (+Z) : haut du joystick = avancer vers -Z
		var dir := Vector3(move_dir.x, 0, move_dir.y)
		hero.position += dir * SPEED * minf(move_dir.length(), 1.0) * delta
		var target_yaw := atan2(dir.x, dir.z)
		hero.rotation.y = lerp_angle(hero.rotation.y, target_yaw, 12.0 * delta)
	if ap and not attacking:
		var want := "Walk" if moving else "Idle"
		if ap.current_animation != want:
			ap.play(want, 0.2)
		if moving:
			ap.speed_scale = clampf(move_dir.length() * 1.15, 0.6, 1.15)
		else:
			ap.speed_scale = 1.0
	elif ap:
		ap.speed_scale = 1.0
	_update_cam(delta)

func _update_cam(delta: float) -> void:
	var target := hero.position + Vector3(0, 3.0, 5.2)
	cam.position = cam.position.lerp(target, clampf(6.0 * delta, 0.0, 1.0))
	cam.look_at(hero.position + Vector3(0, 1.1, 0), Vector3.UP)
