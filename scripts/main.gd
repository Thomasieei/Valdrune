extends Node3D
## Arise Ville — Chasseur, gobelins rang E, Pas de l'ombre et Arise.

const CITY_SCALE := 0.01
const JOY_R := 110.0

var city: Node3D
var hero: Hero
var mobs: Array = []
var camps: Array = []
var spawn_point := Vector3.ZERO
var cam_pivot: Node3D
var spring: SpringArm3D
var cam: Camera3D
var yaw := 0.0
var pitch := -0.34
var shake_amt := 0.0
var shots_mode := false
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
var msg_panel: PanelContainer
var msg_label: Label
var msg_tw: Tween
var buttons := {}

func _ready() -> void:
	shots_mode = OS.get_cmdline_user_args().has("--shots")
	_build_env()
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
	_place_gate(spawn_point)
	_make_camps(spawn_point)
	system_msg("[ SYSTÈME ]\nDes monstres de rang E rôdent en ville.\nÉlimine-les et relève leurs ombres.")
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

func _place_gate(spawn: Vector3) -> void:
	# Portail (Gate) bleu, signature Solo Leveling, à quelques mètres devant le joueur
	var space := get_world_3d().direct_space_state
	var off := Vector3(0, 0, -12)
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

# ---------------------------------------------------------------- unités
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

func shadow_count() -> int:
	var n := 0
	for m in mobs:
		var mm := m as Mob
		if mm.is_shadow and not mm.dead:
			n += 1
	return n

func spawn_mob(kind: String, pos: Vector3, camp: Dictionary) -> Mob:
	var m := Mob.new()
	m.world = self
	m.main = self
	add_child(m)
	m.configure(kind)
	m.global_position = pos + Vector3(0, 0.3, 0)
	m.home = pos
	m.died.connect(_on_mob_died)
	mobs.append(m)
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

func _on_mob_died(u: Unit) -> void:
	var m := u as Mob
	if m.is_shadow:
		system_msg("Une ombre est tombée.")
		var tw := m.create_tween()
		tw.tween_interval(1.8)
		tw.tween_property(m, "scale", Vector3(1, 0.01, 1), 0.6)
		tw.tween_callback(_remove_mob.bind(m))

func _remove_mob(m: Mob) -> void:
	mobs.erase(m)
	for c in camps:
		(c["members"] as Array).erase(m)
	m.queue_free()

func on_shadow_raised(m: Mob) -> void:
	for c in camps:
		(c["members"] as Array).erase(m)
	system_msg("[ SYSTÈME ]\nExtraction réussie : %s" % m.display_name)

func on_hero_died() -> void:
	system_msg("[ SYSTÈME ]\nTu es tombé... Résurrection dans 4 s.")
	await get_tree().create_timer(4.0).timeout
	hero.dead = false
	hero.hp = hero.max_hp
	hero.mp = hero.max_mp
	hero.busy = 0.0
	hero.collision_layer = 2
	hero.collision_mask = 3
	hero.ring.visible = true
	hero.global_position = spawn_point + Vector3(0, 0.3, 0)
	hero.play("Idle", 0.1, 1.0, true)

func shake(a: float) -> void:
	shake_amt = maxf(shake_amt, a)

func hit_stop(t: float) -> void:
	Engine.time_scale = 0.08
	await get_tree().create_timer(t, true, false, true).timeout
	Engine.time_scale = 1.0

func _process(delta: float) -> void:
	# camps : réapparition 35 s après qu'ils ont été vidés
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
	_update_ui()

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
	cam.fov = 64.0
	cam.far = 700.0
	spring.add_child(cam)
	cam.current = true

# ---------------------------------------------------------------- UI
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

func _build_ui() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	joy_ui = Control.new()
	joy_ui.set_anchors_preset(Control.PRESET_FULL_RECT)
	joy_ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	joy_ui.draw.connect(_draw_joy)
	layer.add_child(joy_ui)
	# cadre du héros
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
	shadow_txt = Label.new()
	shadow_txt.position = Vector2(24, 128)
	shadow_txt.add_theme_font_size_override("font_size", 20)
	shadow_txt.add_theme_color_override("font_color", Color(0.75, 0.55, 1))
	shadow_txt.add_theme_color_override("font_outline_color", Color.BLACK)
	shadow_txt.add_theme_constant_override("outline_size", 6)
	layer.add_child(shadow_txt)
	# boutons de combat (style Albion : attaque au centre, sorts autour)
	_skill_button(layer, "attack", "ÉPÉE", Vector2(-235, -235), 180, Color(0.35, 0.7, 1.0), hero.attack)
	_skill_button(layer, "step", "PAS DE\nL'OMBRE", Vector2(-420, -165), 128, Color(0.6, 0.35, 1.0), _do_step)
	_skill_button(layer, "arise", "ARISE", Vector2(-205, -420), 128, Color(0.75, 0.3, 1.0), _do_arise)
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

func _do_step() -> void:
	hero.shadow_step()

func _do_arise() -> void:
	hero.arise()

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

func _update_ui() -> void:
	if hero == null or hp_fill == null:
		return
	hp_fill.size.x = 328.0 * clampf(hero.hp / hero.max_hp, 0, 1)
	mp_fill.size.x = 328.0 * clampf(hero.mp / hero.max_mp, 0, 1)
	hp_txt.text = "PV %d / %d      PM %d" % [int(hero.hp), int(hero.max_hp), int(hero.mp)]
	shadow_txt.text = "Ombres  %d / 4" % shadow_count()
	for k in buttons.keys():
		var d: Dictionary = buttons[k]
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
	msg_tw.tween_interval(3.2)
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
		if b.get_global_rect().grow(10).has_point(p):
			return true
	return false

func _input(event: InputEvent) -> void:
	var half := get_viewport().get_visible_rect().size.x * 0.45
	if event is InputEventScreenTouch:
		var t := event as InputEventScreenTouch
		if t.pressed:
			if t.position.x < half and joy_touch < 0 and t.position.y > 150:
				joy_touch = t.index
				joy_center = t.position
				joy_knob = t.position
			elif t.position.x >= half and look_touch < 0 and not _on_button(t.position):
				look_touch = t.index
		else:
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

# ---------------------------------------------------------------- captures CI (scénario de combat)
func _snap(name: String, frames := 1) -> void:
	for i in frames:
		await get_tree().physics_frame
	await RenderingServer.frame_post_draw
	var img := get_viewport().get_texture().get_image()
	var p := "res://shots/%s.png" % name
	img.save_png(p)
	print("SHOT ", name)

func _put_hero_near(camp_i: int, dist: float) -> void:
	var c: Dictionary = camps[mini(camp_i, camps.size() - 1)]
	var p: Vector3 = c["pos"]
	var dir := (spawn_point - p)
	dir.y = 0
	dir = dir.normalized() if dir.length() > 0.1 else Vector3(0, 0, 1)
	hero.global_position = p + dir * dist + Vector3(0, 0.3, 0)
	yaw = atan2(dir.x, dir.z)
	cam_pivot.global_position = hero.global_position + Vector3(0, 1.55, 0)

func _run_shots() -> void:
	hero.max_hp = 99999
	hero.hp = 99999
	await _snap("00_depart", 20)
	var y0 := yaw
	yaw = y0 + PI
	pitch = -0.12
	spring.spring_length = 2.4
	hero.play("SwordIdle", 0.0, 1.0, true)
	await _snap("00b_heros", 25)
	yaw = y0
	pitch = -0.34
	spring.spring_length = 4.7
	_put_hero_near(1, 7.0)
	await _snap("01_approche", 70)
	hero.attack()
	await _snap("02_epee", 7)
	await _snap("02b", 20)
	hero.attack()
	await _snap("03_combo", 9)
	hero.attack()
	await _snap("04_combo3", 12)
	hero.cd["step"] = 0.0
	hero.mp = 100
	hero.shadow_step()
	await _snap("05_pas_ombre", 10)
	for m in mobs:
		var mm := m as Mob
		if not mm.dead and mm.global_position.distance_to(hero.global_position) < 8.0:
			mm.take_damage(9999, hero)
			break
	await _snap("06_cadavre", 70)
	hero.cd["arise"] = 0.0
	hero.mp = 100
	hero.arise()
	await _snap("07_arise", 22)
	await _snap("08_ombre", 100)
	var oi := 3
	for i in camps.size():
		if (camps[i]["kinds"] as Array).has("orc"):
			oi = i
			break
	_put_hero_near(oi, 4.0)
	await _snap("09_orc", 60)
	for m in mobs:
		var mm := m as Mob
		if mm.kind == "orc" and not mm.dead:
			mm.skill_cd = 0.0
			mm.target = hero
	await _snap("10_fracas", 40)
	await _snap("11_suite", 60)
	await _step_test()
	get_tree().quit()

## Test automatique : le héros doit monter sur un trottoir proche.
func _step_test() -> void:
	var space := get_world_3d().direct_space_state
	hero.global_position = spawn_point + Vector3(0, 0.3, 0)
	await get_tree().physics_frame
	var target := Vector3.INF
	for r in [3.0, 5.0, 7.0, 9.0, 12.0]:
		for k in 16:
			var a: float = k * TAU / 16.0
			var p: Vector3 = spawn_point + Vector3(sin(a) * r, 30, cos(a) * r)
			var hit := space.intersect_ray(PhysicsRayQueryParameters3D.create(p, p + Vector3(0, -60, 0)))
			if not hit.is_empty():
				var y: float = (hit["position"] as Vector3).y
				if y > 0.08 and y < 0.4:
					target = hit["position"]
					break
		if target != Vector3.INF:
			break
	if target == Vector3.INF:
		print("STEP_TEST aucun trottoir trouvé")
		return
	var d := target - hero.global_position
	yaw = atan2(-d.x, -d.z)
	hero.move_input = Vector2(0, -0.6)
	for i in 180:
		await get_tree().physics_frame
		var dd := target - hero.global_position
		dd.y = 0
		if dd.length() < 0.6:
			break
	hero.move_input = Vector2.ZERO
	print("STEP_TEST cible_y=%.2f héros_y=%.2f distance_restante=%.2f" % [target.y, hero.global_position.y, Vector2(target.x - hero.global_position.x, target.z - hero.global_position.z).length()])
