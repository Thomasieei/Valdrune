class_name FX
## Effets visuels procéduraux, légers (CPUParticles3D, peu de particules, matériaux partagés).
## Chaque sort a une identité propre : comète de feu, onde et pics de glace, bulle runique, racines.

static var root: Node3D
static var _mats := {}
static var _tex := {}

static func tex(name: String) -> Texture2D:
	if not _tex.has(name):
		_tex[name] = load("res://assets/fx/%s.png" % name)
	return _tex[name]

## Matériau additif / transparent, teinté par la couleur de sommet (particules).
static func pmat(name: String, additive := true, billboard := true, tint := Color.WHITE) -> StandardMaterial3D:
	var key := "%s|%s|%s|%s" % [name, additive, billboard, tint.to_html()]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if additive:
			m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		m.vertex_color_use_as_albedo = true
		m.albedo_color = tint
		m.albedo_texture = tex(name)
		m.cull_mode = BaseMaterial3D.CULL_DISABLED
		m.no_depth_test = false
		m.disable_receive_shadows = true
		if billboard:
			m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		_mats[key] = m
	return _mats[key]

static func solid(color: Color, emissive := 0.0, alpha := 1.0) -> StandardMaterial3D:
	var key := "solid|%s|%s|%s" % [color.to_html(), emissive, alpha]
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.albedo_color = Color(color.r, color.g, color.b, alpha)
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		if alpha < 1.0:
			m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		if emissive > 0.0:
			m.emission_enabled = true
			m.emission = color
			m.emission_energy_multiplier = emissive
		_mats[key] = m
	return _mats[key]

static func _ramp(cols: Array) -> Gradient:
	var g := Gradient.new()
	var offs := PackedFloat32Array()
	var cs := PackedColorArray()
	for i in cols.size():
		offs.append(float(i) / maxf(cols.size() - 1, 1))
		cs.append(cols[i])
	g.offsets = offs
	g.colors = cs
	return g

static func particles(texname: String, amount: int, life: float, cols: Array, size: float, one_shot := true, additive := true) -> CPUParticles3D:
	var p := CPUParticles3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	q.material = pmat(texname, additive)
	p.mesh = q
	p.amount = amount
	p.lifetime = life
	p.one_shot = one_shot
	p.explosiveness = 1.0 if one_shot else 0.0
	p.color_ramp = _ramp(cols)
	var c := Curve.new()
	c.add_point(Vector2(0, 0.6))
	c.add_point(Vector2(0.3, 1.0))
	c.add_point(Vector2(1, 0.2))
	p.scale_amount_curve = c
	p.local_coords = false
	return p

static func _free_after(n: Node, t: float) -> void:
	if n.is_inside_tree():
		n.get_tree().create_timer(t).timeout.connect(func(): if is_instance_valid(n): n.queue_free())

static func _add(n: Node3D, pos: Vector3) -> Node3D:
	root.add_child(n)
	n.global_position = pos
	return n

# ---------------------------------------------------------------- impacts
static func damage_number(pos: Vector3, text: String, col: Color) -> void:
	if root == null:
		return
	var l := Label3D.new()
	l.text = text
	l.font_size = 56
	l.outline_size = 14
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.006
	_add(l, pos + Vector3(randf_range(-0.3, 0.3), 0, randf_range(-0.3, 0.3)))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "position:y", l.position.y + 1.1, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.3)
	tw.chain().tween_callback(l.queue_free)

static func hit_spark(pos: Vector3, col := Color(1.0, 0.9, 0.5)) -> void:
	var p := particles("spark_04", 10, 0.35, [col, Color(col.r, col.g * 0.5, 0.1, 0.0)], 0.5)
	p.direction = Vector3.UP
	p.spread = 180.0
	p.initial_velocity_min = 3.0
	p.initial_velocity_max = 6.0
	p.gravity = Vector3(0, -6, 0)
	_add(p, pos)
	p.emitting = true
	_free_after(p, 0.6)

static func slash(pos: Vector3, yaw: float, flip := false) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	var m := pmat("slash_02", true, false, Color(1.0, 0.95, 0.8, 0.9))
	mi.mesh = q
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(mi, pos)
	mi.rotation = Vector3(-PI / 2.0 + 0.25, yaw, PI if flip else 0.0)
	mi.scale = Vector3.ONE * 0.6
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.05, 0.16)
	tw.tween_property(mi, "transparency", 1.0, 0.22)
	tw.chain().tween_callback(mi.queue_free)

# ---------------------------------------------------------------- FEU
static func fireball() -> Node3D:
	var n := Node3D.new()
	var core := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 0.22
	s.height = 0.44
	s.radial_segments = 8
	s.rings = 4
	core.mesh = s
	core.material_override = solid(Color(1.0, 0.75, 0.3), 4.0)
	core.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(core)
	var halo := particles("light_01", 1, 0.2, [Color(1, 0.55, 0.15, 0.9), Color(1, 0.4, 0.1, 0.9)], 1.3, false)
	halo.local_coords = true
	halo.gravity = Vector3.ZERO
	n.add_child(halo)
	var trail := particles("flame_01", 34, 0.45, [Color(1, 0.95, 0.6, 1), Color(1, 0.5, 0.12, 0.9), Color(0.5, 0.1, 0.05, 0)], 0.75, false)
	trail.gravity = Vector3(0, 1.5, 0)
	trail.initial_velocity_min = 0.3
	trail.initial_velocity_max = 0.8
	trail.spread = 180.0
	n.add_child(trail)
	var embers := particles("spark_04", 14, 0.6, [Color(1, 0.8, 0.3, 1), Color(1, 0.3, 0.1, 0)], 0.18, false)
	embers.gravity = Vector3(0, -3, 0)
	embers.initial_velocity_min = 1.0
	embers.initial_velocity_max = 2.5
	embers.spread = 180.0
	n.add_child(embers)
	return n

static func explosion(pos: Vector3, radius: float) -> void:
	var flash := particles("light_01", 1, 0.3, [Color(1, 0.9, 0.6, 1), Color(1, 0.4, 0.1, 0)], radius * 2.6)
	flash.gravity = Vector3.ZERO
	_add(flash, pos)
	flash.emitting = true
	var fire := particles("fire_01", 22, 0.55, [Color(1, 0.95, 0.6, 1), Color(1, 0.45, 0.1, 0.8), Color(0.3, 0.1, 0.05, 0)], 1.1)
	fire.spread = 180.0
	fire.initial_velocity_min = 2.5
	fire.initial_velocity_max = radius * 3.0
	fire.gravity = Vector3(0, 2, 0)
	fire.damping_min = 4.0
	fire.damping_max = 6.0
	_add(fire, pos)
	fire.emitting = true
	var smoke := particles("smoke_02", 8, 1.4, [Color(0.25, 0.22, 0.2, 0.7), Color(0.2, 0.2, 0.2, 0)], 1.6, true, false)
	smoke.spread = 180.0
	smoke.initial_velocity_min = 0.5
	smoke.initial_velocity_max = 1.5
	smoke.gravity = Vector3(0, 1.2, 0)
	_add(smoke, pos + Vector3.UP * 0.4)
	smoke.emitting = true
	var scorch := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(radius * 2.2, radius * 2.2)
	scorch.mesh = q
	var sm := pmat("scorch_02", false, false, Color(0.08, 0.06, 0.05, 0.85))
	scorch.material_override = sm
	scorch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gy := Terrain.height_at(pos.x, pos.z) + 0.06
	_add(scorch, Vector3(pos.x, gy, pos.z))
	scorch.rotation = Vector3(-PI / 2.0, randf() * TAU, 0)
	var tw := scorch.create_tween()
	tw.tween_interval(1.5)
	tw.tween_property(scorch, "transparency", 1.0, 1.5)
	tw.tween_callback(scorch.queue_free)
	_free_after(flash, 0.5)
	_free_after(fire, 0.9)
	_free_after(smoke, 1.8)

# ---------------------------------------------------------------- GIVRE
static func frost_nova(pos: Vector3, r: float) -> void:
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	ring.mesh = q
	ring.material_override = pmat("twirl_02", true, false, Color(0.55, 0.85, 1.0))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var gy := Terrain.height_at(pos.x, pos.z) + 0.15
	if pos.y > gy + 0.5:
		gy = pos.y + 0.1
	_add(ring, Vector3(pos.x, gy, pos.z))
	ring.rotation = Vector3(-PI / 2.0, 0, 0)
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * r, 0.35).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "rotation:y", 1.5, 0.9)
	tw.tween_property(ring, "transparency", 1.0, 0.5).set_delay(0.4)
	tw.chain().tween_callback(ring.queue_free)
	# pics de glace qui jaillissent du sol en cercle
	var ice := solid(Color(0.65, 0.88, 1.0), 0.6, 0.8)
	var holder := Node3D.new()
	_add(holder, Vector3(pos.x, gy - 0.15, pos.z))
	for i in 12:
		var a := TAU * i / 12.0 + randf() * 0.3
		var d := r * randf_range(0.45, 0.9)
		var spike := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.0
		c.bottom_radius = randf_range(0.18, 0.3)
		c.height = randf_range(0.9, 1.6)
		c.radial_segments = 5
		c.rings = 1
		spike.mesh = c
		spike.material_override = ice
		spike.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		holder.add_child(spike)
		spike.position = Vector3(cos(a) * d, -1.0, sin(a) * d)
		spike.rotation = Vector3(randf_range(-0.35, 0.35), 0, randf_range(-0.35, 0.35))
		var t2 := spike.create_tween()
		t2.tween_property(spike, "position:y", c.height * 0.4, 0.12 + i * 0.012).set_ease(Tween.EASE_OUT)
		t2.tween_interval(0.9)
		t2.tween_property(spike, "position:y", -1.2, 0.4)
	_free_after(holder, 1.8)
	var snow := particles("star_06", 26, 1.1, [Color(0.9, 0.97, 1, 1), Color(0.6, 0.85, 1, 0)], 0.35)
	snow.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	snow.emission_sphere_radius = r * 0.6
	snow.direction = Vector3.UP
	snow.spread = 40.0
	snow.initial_velocity_min = 1.5
	snow.initial_velocity_max = 3.5
	snow.gravity = Vector3(0, -1.0, 0)
	_add(snow, Vector3(pos.x, gy + 0.4, pos.z))
	snow.emitting = true
	_free_after(snow, 1.4)

## Givre persistant sur une cible ralentie
static func frost_mark(target: Node3D, dur: float) -> void:
	var p := particles("star_06", 6, 0.8, [Color(0.85, 0.95, 1, 0.9), Color(0.6, 0.85, 1, 0)], 0.25, false)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.5
	p.gravity = Vector3(0, -0.5, 0)
	target.add_child(p)
	p.position = Vector3.UP * 1.0
	p.emitting = true
	_free_after(p, dur)

# ---------------------------------------------------------------- ÉGIDE (bouclier)
static var _shield_shader: Shader

static func shield(target: Node3D) -> Node3D:
	var n := Node3D.new()
	if _shield_shader == null:
		_shield_shader = Shader.new()
		_shield_shader.code = """shader_type spatial;
render_mode blend_add, unshaded, cull_back, depth_draw_never, shadows_disabled;
uniform vec4 col : source_color = vec4(0.35, 0.8, 1.0, 1.0);
void fragment() {
	float f = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 2.2);
	float bands = 0.5 + 0.5 * sin(UV.y * 40.0 - TIME * 3.0);
	ALBEDO = col.rgb * (f * 1.3 + bands * 0.08);
}"""
	var bubble := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = 1.05
	s.height = 2.3
	s.radial_segments = 16
	s.rings = 8
	bubble.mesh = s
	var sm := ShaderMaterial.new()
	sm.shader = _shield_shader
	bubble.material_override = sm
	bubble.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	bubble.position = Vector3.UP * 1.0
	n.add_child(bubble)
	var rune := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2.6, 2.6)
	rune.mesh = q
	rune.material_override = pmat("symbol_01", true, false, Color(0.45, 0.85, 1.0))
	rune.rotation = Vector3(-PI / 2.0, 0, 0)
	rune.position = Vector3.UP * 0.08
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	n.add_child(rune)
	var spin := Spinner.new()
	spin.speed = 1.2
	rune.add_child(spin)
	target.add_child(n)
	n.scale = Vector3.ONE * 0.2
	var tw := n.create_tween()
	tw.tween_property(n, "scale", Vector3.ONE, 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var burst := particles("star_06", 16, 0.6, [Color(0.7, 0.95, 1, 1), Color(0.3, 0.7, 1, 0)], 0.35)
	burst.spread = 180.0
	burst.initial_velocity_min = 2.0
	burst.initial_velocity_max = 3.5
	burst.gravity = Vector3.ZERO
	_add(burst, target.global_position + Vector3.UP)
	burst.emitting = true
	_free_after(burst, 0.8)
	return n

# ---------------------------------------------------------------- RACINES
static func roots(target: Node3D, dur: float) -> void:
	var pos := target.global_position
	var holder := Node3D.new()
	_add(holder, Vector3(pos.x, Terrain.height_at(pos.x, pos.z) - 0.05, pos.z))
	var bark := solid(Color(0.36, 0.26, 0.16))
	var moss := solid(Color(0.32, 0.52, 0.22))
	for i in 8:
		var a := TAU * i / 8.0 + randf() * 0.4
		var root_mi := MeshInstance3D.new()
		var c := CylinderMesh.new()
		c.top_radius = 0.02
		c.bottom_radius = randf_range(0.1, 0.16)
		c.height = randf_range(1.3, 1.9)
		c.radial_segments = 5
		c.rings = 2
		root_mi.mesh = c
		root_mi.material_override = bark if i % 3 != 0 else moss
		root_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var pivot := Node3D.new()
		holder.add_child(pivot)
		pivot.position = Vector3(cos(a) * 0.75, 0, sin(a) * 0.75)
		pivot.rotation = Vector3(0, -a, 0)
		pivot.add_child(root_mi)
		root_mi.position = Vector3(0, c.height * 0.5, 0)
		# les racines s'enroulent vers la cible
		pivot.rotation.z = 0.0
		pivot.scale = Vector3(1, 0.01, 1)
		var tw := pivot.create_tween()
		tw.set_parallel(true)
		tw.tween_property(pivot, "scale", Vector3.ONE, 0.25 + i * 0.03).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
		tw.tween_property(pivot, "rotation:z", 0.45, 0.4)
		tw.chain().tween_interval(maxf(dur - 0.7, 0.1))
		tw.chain().tween_property(pivot, "scale", Vector3(1, 0.01, 1), 0.35)
	var leaves := particles("magic_02", 14, 1.0, [Color(0.6, 0.95, 0.4, 1), Color(0.3, 0.7, 0.2, 0)], 0.3)
	leaves.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	leaves.emission_sphere_radius = 0.8
	leaves.direction = Vector3.UP
	leaves.initial_velocity_min = 1.0
	leaves.initial_velocity_max = 2.0
	leaves.gravity = Vector3(0, -0.6, 0)
	_add(leaves, pos + Vector3.UP * 0.5)
	leaves.emitting = true
	_free_after(leaves, 1.3)
	_free_after(holder, dur + 0.5)

# ---------------------------------------------------------------- divers
static func cast_glow(at: Node3D, col: Color) -> void:
	var p := particles("magic_02", 12, 0.5, [Color(col.r, col.g, col.b, 1), Color(col.r, col.g, col.b, 0)], 0.35)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = 0.3
	p.spread = 180.0
	p.initial_velocity_min = 0.5
	p.initial_velocity_max = 1.5
	p.gravity = Vector3(0, 1, 0)
	_add(p, at.global_position + Vector3.UP * 1.3)
	p.emitting = true
	_free_after(p, 0.7)

static func level_up(target: Node3D) -> void:
	var p := particles("star_06", 40, 1.4, [Color(1, 0.95, 0.6, 1), Color(1, 0.75, 0.2, 0)], 0.4)
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3.UP
	p.emission_ring_radius = 0.9
	p.emission_ring_inner_radius = 0.6
	p.emission_ring_height = 0.1
	p.direction = Vector3.UP
	p.spread = 8.0
	p.initial_velocity_min = 2.5
	p.initial_velocity_max = 4.0
	p.gravity = Vector3.ZERO
	target.add_child(p)
	p.emitting = true
	_free_after(p, 1.6)

## Ombre ronde bon marché sous les créatures (pas de calcul d'ombre réelle)
static func blob_shadow(parent: Node3D, size: float) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(size, size)
	mi.mesh = q
	var key := "blob"
	if not _mats.has(key):
		var m := StandardMaterial3D.new()
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		m.albedo_texture = tex("light_01")
		m.albedo_color = Color(0, 0, 0, 0.45)
		_mats[key] = m
	mi.material_override = _mats[key]
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.rotation = Vector3(-PI / 2.0, 0, 0)
	mi.position = Vector3.UP * 0.05
	parent.add_child(mi)
	return mi

## Onde de choc au sol (attaques lourdes) : poussière et anneau clair
static func shockwave(pos: Vector3, r: float) -> void:
	var dust := particles("smoke_02", 14, 0.9, [Color(0.75, 0.65, 0.5, 0.75), Color(0.6, 0.55, 0.45, 0)], 1.4, true, false)
	dust.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	dust.emission_ring_axis = Vector3.UP
	dust.emission_ring_radius = r * 0.8
	dust.emission_ring_inner_radius = r * 0.3
	dust.emission_ring_height = 0.1
	dust.direction = Vector3.UP
	dust.spread = 60.0
	dust.initial_velocity_min = 1.5
	dust.initial_velocity_max = 3.0
	dust.gravity = Vector3(0, -2, 0)
	_add(dust, pos + Vector3.UP * 0.2)
	dust.emitting = true
	var ring := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(2, 2)
	ring.mesh = q
	ring.material_override = pmat("circle_05", true, false, Color(1.0, 0.9, 0.7, 0.9))
	ring.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_add(ring, pos + Vector3.UP * 0.12)
	ring.rotation = Vector3(-PI / 2.0, 0, 0)
	ring.scale = Vector3.ONE * 0.3
	var tw := ring.create_tween()
	tw.set_parallel(true)
	tw.tween_property(ring, "scale", Vector3.ONE * r * 1.2, 0.3)
	tw.tween_property(ring, "transparency", 1.0, 0.35)
	tw.chain().tween_callback(ring.queue_free)
	_free_after(dust, 1.2)

## Bulle de parole au-dessus d'un personnage
static func bark(target: Node3D, text: String, height := 2.3, dur := 3.0) -> void:
	var old := target.get_node_or_null("Bulle")
	if old:
		old.queue_free()
	var l := Label3D.new()
	l.name = "Bulle"
	l.text = text
	l.font_size = 40
	l.outline_size = 12
	l.modulate = Color(1, 1, 0.92)
	l.outline_modulate = Color(0.1, 0.08, 0.06, 0.9)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.pixel_size = 0.0055
	l.width = 520
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position = Vector3.UP * height
	target.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)
