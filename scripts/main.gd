extends Node3D
## Ville 1 — Igris dans la ville de nuit (Solo Leveling RP).

const SPEED := 3.2
const RUN_SPEED := 6.0
const GRAVITY := 18.0
const CITY_SCALE := 0.01
const JOY_R := 110.0

var player: CharacterBody3D
var model: Node3D
var ap: AnimationPlayer
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.32
var attacking := false
var move_dir := Vector2.ZERO
var joy_touch := -1
var joy_center := Vector2.ZERO
var joy_knob := Vector2.ZERO
var look_touch := -1
var joy_ui: Control
var sys_panel: PanelContainer
var shots_mode := false
var city: Node3D

func _ready() -> void:
	shots_mode = OS.get_cmdline_user_args().has("--shots")
	_build_env()
	_build_city()
	_build_player()
	_build_ui()
	await get_tree().physics_frame
	await get_tree().physics_frame
	var spawn := _find_spawn()
	player.global_position = spawn + Vector3(0, 0.2, 0)
	_place_gate(spawn)
	if shots_mode:
		_run_shots()

# ---------------------------------------------------------------- monde
func _build_env() -> void:
	var we := WorldEnvironment.new()
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
	add_child(we)
	var moon := DirectionalLight3D.new()
	moon.rotation_degrees = Vector3(-38, -35, 0)
	moon.light_color = Color(0.62, 0.7, 1.0)
	moon.light_energy = 0.75
	moon.shadow_enabled = true
	moon.directional_shadow_max_distance = 60.0
	add_child(moon)

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
		m.create_trimesh_collision()
	# sol de sécurité sous la ville
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(2000, 1, 2000)
	cs.shape = bs
	cs.position = Vector3(0, -0.55, 0)
	floor_body.add_child(cs)
	add_child(floor_body)

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

func _place_gate(spawn: Vector3) -> void:
	# Portail (Gate) bleu, signature Solo Leveling, à quelques mètres devant le joueur
	var space := get_world_3d().direct_space_state
	var off := Vector3(0, 0, -9)
	for k in 16:
		var a := k * TAU / 16.0
		var c := Vector3(sin(a) * 10.0, 0, cos(a) * 10.0)
		if _is_open(space, spawn + c + Vector3(0, 80, 0)):
			off = c
			break
	yaw = atan2(-off.x, -off.z)
	var gate := Node3D.new()
	gate.position = spawn + off + Vector3(0, 2.6, 0)
	gate.rotation.y = yaw
	add_child(gate)
	var ring := MeshInstance3D.new()
	var tm := TorusMesh.new()
	tm.inner_radius = 2.2
	tm.outer_radius = 2.55
	ring.mesh = tm
	ring.rotation_degrees = Vector3(90, 0, 0)
	var rm := StandardMaterial3D.new()
	rm.albedo_color = Color(0.2, 0.5, 1)
	rm.emission_enabled = true
	rm.emission = Color(0.25, 0.6, 1)
	rm.emission_energy_multiplier = 4.0
	ring.material_override = rm
	gate.add_child(ring)
	var disc := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 2.25
	cm.bottom_radius = 2.25
	cm.height = 0.05
	disc.mesh = cm
	disc.rotation_degrees = Vector3(90, 0, 0)
	var dm := StandardMaterial3D.new()
	dm.albedo_color = Color(0.05, 0.15, 0.6, 0.45)
	dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	dm.emission_enabled = true
	dm.emission = Color(0.1, 0.3, 1)
	dm.emission_energy_multiplier = 1.2
	dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	disc.material_override = dm
	gate.add_child(disc)
	var gl := OmniLight3D.new()
	gl.light_color = Color(0.3, 0.55, 1)
	gl.light_energy = 3.0
	gl.omni_range = 14.0
	gate.add_child(gl)
	var parts := CPUParticles3D.new()
	parts.amount = 60
	parts.lifetime = 2.0
	parts.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	parts.emission_ring_axis = Vector3(0, 0, 1)
	parts.emission_ring_radius = 2.4
	parts.emission_ring_inner_radius = 2.0
	parts.emission_ring_height = 0.1
	parts.gravity = Vector3(0, 0.6, 0)
	parts.scale_amount_min = 0.04
	parts.scale_amount_max = 0.09
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	var pmat := StandardMaterial3D.new()
	pmat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	pmat.albedo_color = Color(0.5, 0.8, 1)
	pm.material = pmat
	parts.mesh = pm
	gate.add_child(parts)
	var tw := create_tween().set_loops()
	tw.tween_property(ring, "rotation_degrees:z", 360.0, 6.0).from(0.0)

# ---------------------------------------------------------------- joueur
func _build_player() -> void:
	player = CharacterBody3D.new()
	add_child(player)
	var col := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.38
	cap.height = 1.85
	col.shape = cap
	col.position = Vector3(0, 0.93, 0)
	player.add_child(col)
	model = (load("res://assets/igris.glb") as PackedScene).instantiate()
	player.add_child(model)
	# aura rouge discrète sous Igris
	var aura := OmniLight3D.new()
	aura.light_color = Color(1, 0.15, 0.2)
	aura.light_energy = 1.4
	aura.omni_range = 4.0
	aura.position = Vector3(0, 1.0, 0.6)
	player.add_child(aura)
	var found := model.find_children("*", "AnimationPlayer", true, false)
	if found.size() > 0:
		ap = found[0] as AnimationPlayer
		for n in ["Walk", "Idle"]:
			if ap.has_animation(n):
				ap.get_animation(n).loop_mode = Animation.LOOP_LINEAR
		ap.animation_finished.connect(_on_anim_done)
		ap.play("Idle")
		print("IGRIS_ANIMS:", ap.get_animation_list())
	cam_pivot = Node3D.new()
	add_child(cam_pivot)
	spring = SpringArm3D.new()
	spring.spring_length = 5.0
	spring.margin = 0.3
	var sph := SphereShape3D.new()
	sph.radius = 0.25
	spring.shape = sph
	spring.add_excluded_object(player.get_rid())
	cam_pivot.add_child(spring)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.far = 700.0
	spring.add_child(cam)
	cam.current = true

func _on_anim_done(anim_name: StringName) -> void:
	if anim_name == &"Attack":
		attacking = false
		ap.play("Idle", 0.2)

func _attack() -> void:
	if attacking or ap == null or not ap.has_animation("Attack"):
		return
	attacking = true
	ap.play("Attack", 0.12)

func _physics_process(delta: float) -> void:
	if player == null:
		return
	var v := player.velocity
	v.y -= GRAVITY * delta
	var ml := move_dir.length()
	var moving := ml > 0.15 and not attacking
	if moving:
		var fwd := Vector3(-sin(yaw), 0, -cos(yaw))
		var right := Vector3(cos(yaw), 0, -sin(yaw))
		var dir := (right * move_dir.x - fwd * move_dir.y).normalized()
		var spd := RUN_SPEED if ml > 0.85 else SPEED
		v.x = dir.x * spd * minf(ml, 1.0)
		v.z = dir.z * spd * minf(ml, 1.0)
		model.rotation.y = lerp_angle(model.rotation.y, atan2(dir.x, dir.z), 12.0 * delta)
	else:
		v.x = move_toward(v.x, 0, 30 * delta)
		v.z = move_toward(v.z, 0, 30 * delta)
	player.velocity = v
	player.move_and_slide()
	if player.global_position.y < -20:
		player.global_position.y = 5
	if ap and not attacking:
		var want := "Walk" if moving else "Idle"
		if ap.current_animation != want:
			ap.play(want, 0.2)
		ap.speed_scale = clampf(ml * 1.6, 0.8, 1.7) if moving else 1.0
	elif ap:
		ap.speed_scale = 1.0
	cam_pivot.global_position = cam_pivot.global_position.lerp(player.global_position + Vector3(0, 1.6, 0), clampf(10 * delta, 0, 1))
	cam_pivot.rotation = Vector3(pitch, yaw, 0)

# ---------------------------------------------------------------- UI
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
	btn.add_theme_font_size_override("font_size", 28)
	var sb := StyleBoxFlat.new()
	sb.bg_color = Color(0.04, 0.08, 0.2, 0.75)
	sb.border_color = Color(0.35, 0.7, 1.0)
	sb.set_border_width_all(4)
	sb.set_corner_radius_all(90)
	sb.shadow_color = Color(0.2, 0.5, 1, 0.6)
	sb.shadow_size = 12
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	var sbp: StyleBoxFlat = sb.duplicate()
	sbp.bg_color = Color(0.15, 0.35, 0.8, 0.9)
	btn.add_theme_stylebox_override("pressed", sbp)
	btn.add_theme_color_override("font_color", Color(0.75, 0.9, 1))
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
	# fenêtre « Système » façon Solo Leveling
	sys_panel = PanelContainer.new()
	var ps := StyleBoxFlat.new()
	ps.bg_color = Color(0.02, 0.05, 0.14, 0.82)
	ps.border_color = Color(0.4, 0.75, 1)
	ps.set_border_width_all(2)
	ps.set_corner_radius_all(6)
	ps.shadow_color = Color(0.25, 0.6, 1, 0.5)
	ps.shadow_size = 14
	ps.content_margin_left = 28
	ps.content_margin_right = 28
	ps.content_margin_top = 14
	ps.content_margin_bottom = 14
	sys_panel.add_theme_stylebox_override("panel", ps)
	var lb := Label.new()
	lb.text = "[ SYSTÈME ]\nBienvenue, Chasseur.\nUn Portail s'est ouvert en ville."
	lb.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lb.add_theme_font_size_override("font_size", 30)
	lb.add_theme_color_override("font_color", Color(0.8, 0.92, 1))
	sys_panel.add_child(lb)
	sys_panel.anchor_left = 0.5
	sys_panel.anchor_right = 0.5
	sys_panel.offset_left = -300
	sys_panel.offset_right = 300
	sys_panel.offset_top = 40
	layer.add_child(sys_panel)
	if not shots_mode:
		var tw := create_tween()
		tw.tween_interval(4.5)
		tw.tween_property(sys_panel, "modulate:a", 0.0, 1.2)

func _draw_joy() -> void:
	var vp := joy_ui.get_viewport_rect().size
	var base := joy_center if joy_touch >= 0 else Vector2(200, vp.y - 200)
	var knob := joy_knob if joy_touch >= 0 else base
	joy_ui.draw_circle(base, JOY_R, Color(0.1, 0.25, 0.6, 0.25))
	joy_ui.draw_arc(base, JOY_R, 0, TAU, 48, Color(0.4, 0.75, 1, 0.7), 3.0)
	joy_ui.draw_circle(knob, 46, Color(0.35, 0.7, 1, 0.6))

func _input(event: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.5
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < half and joy_touch < 0:
				joy_touch = t.index
				joy_center = t.position
				joy_knob = t.position
			elif t.position.x >= half and look_touch < 0:
				look_touch = t.index
		else:
			if t.index == joy_touch:
				joy_touch = -1
				move_dir = Vector2.ZERO
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
			move_dir = Vector2(d.x, d.y) / JOY_R
			joy_ui.queue_redraw()
		elif dr.index == look_touch:
			yaw -= dr.relative.x * 0.006
			pitch = clampf(pitch - dr.relative.y * 0.004, -1.1, 0.25)

# ---------------------------------------------------------------- captures (CI)
func _run_shots() -> void:
	var dir := "res://shots/" if DirAccess.dir_exists_absolute("res://shots") else "user://"
	var views := [[0.0, -0.32, 5.0, "rue_dos"], [2.4, -0.2, 4.0, "rue_face"], [-1.2, -0.12, 3.0, "rue_cote"], [0.7, -0.85, 30.0, "aerien"]]
	for v in views:
		yaw = v[0]
		pitch = v[1]
		spring.spring_length = v[2]
		for i in 30:
			await get_tree().process_frame
		var img := get_viewport().get_texture().get_image()
		var p: String = dir + str(v[3]) + ".png"
		img.save_png(p)
		print("SHOT ", ProjectSettings.globalize_path(p))
	get_tree().quit()
