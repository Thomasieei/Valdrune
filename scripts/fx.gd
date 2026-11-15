class_name FX
## Effets visuels réutilisables (compatibles renderer GL Compatibility).

static func mat(col: Color, energy := 2.0, alpha := 1.0, unshaded := true) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	if alpha < 1.0:
		m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.emission_enabled = true
	m.emission = col
	m.emission_energy_multiplier = energy
	if unshaded:
		m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	return m

static func soft_disc_tex(ring: bool) -> GradientTexture2D:
	var g := Gradient.new()
	if ring:
		g.offsets = PackedFloat32Array([0.0, 0.72, 0.86, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.0), Color(1, 1, 1, 0.05), Color(1, 1, 1, 1.0), Color(1, 1, 1, 0.0)])
	else:
		g.offsets = PackedFloat32Array([0.0, 0.8, 1.0])
		g.colors = PackedColorArray([Color(1, 1, 1, 0.55), Color(1, 1, 1, 0.8), Color(1, 1, 1, 0.0)])
	var t := GradientTexture2D.new()
	t.gradient = g
	t.fill = GradientTexture2D.FILL_RADIAL
	t.fill_from = Vector2(0.5, 0.5)
	t.fill_to = Vector2(1.0, 0.5)
	t.width = 128
	t.height = 128
	return t

## Cercle au sol (anneau doux ou disque plein).
static func ground_disc(radius: float, col: Color, alpha: float, ring := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(radius * 2.0, radius * 2.0)
	mi.mesh = pm
	var m := StandardMaterial3D.new()
	m.albedo_texture = soft_disc_tex(ring)
	m.albedo_color = Color(col.r, col.g, col.b, alpha)
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.no_depth_test = false
	m.render_priority = 1
	mi.material_override = m
	mi.position.y = 0.04
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return mi

## Zone d'alerte rouge qui se remplit puis disparaît (télégraphe des sorts ennemis).
static func telegraph(parent: Node, pos: Vector3, radius: float, dur: float, col := Color(1, 0.15, 0.1)) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.05, 0)
	var edge := ground_disc(radius, col, 0.85, true)
	root.add_child(edge)
	var fill := ground_disc(radius, col, 0.22, false)
	fill.scale = Vector3(0.05, 1, 0.05)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.tween_property(fill, "scale", Vector3.ONE, dur)
	tw.tween_callback(root.queue_free)

static func burst(parent: Node, pos: Vector3, col: Color, amount := 24, size := 0.12, spread := 3.0, life := 0.6, up := 2.0) -> void:
	var p := CPUParticles3D.new()
	parent.add_child(p)
	p.global_position = pos
	p.one_shot = true
	p.emitting = true
	p.amount = amount
	p.lifetime = life
	p.explosiveness = 0.95
	p.direction = Vector3(0, 1, 0)
	p.spread = 180.0
	p.initial_velocity_min = spread * 0.4
	p.initial_velocity_max = spread
	p.gravity = Vector3(0, -up, 0)
	p.scale_amount_min = size * 0.5
	p.scale_amount_max = size
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = mat(col, 3.0)
	p.mesh = sm
	var t := p.get_tree().create_timer(life + 0.3)
	t.timeout.connect(p.queue_free)

## Croissant de lame (mesh en arc, traînée qui s'efface).
static func arc_mesh(radius: float, width: float, span: float, flip: bool) -> ArrayMesh:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := 18
	var pts: Array = []
	for i in n + 1:
		var f := float(i) / n
		var a := -span * 0.5 + span * f
		if flip:
			a = -a
		var w := width * sin(f * PI) + 0.02
		pts.append([Vector3(sin(a), 0, cos(a)) * (radius - w), Vector3(sin(a), 0, cos(a)) * radius, f])
	for i in n:
		var p0: Array = pts[i]
		var p1: Array = pts[i + 1]
		var c0 := Color(1, 1, 1, p0[2] * p0[2])
		var c1 := Color(1, 1, 1, p1[2] * p1[2])
		st.set_color(c0); st.add_vertex(p0[0])
		st.set_color(c0); st.add_vertex(p0[1])
		st.set_color(c1); st.add_vertex(p1[1])
		st.set_color(c0); st.add_vertex(p0[0])
		st.set_color(c1); st.add_vertex(p1[1])
		st.set_color(c1); st.add_vertex(p1[0])
	return st.commit()

static func slash_arc(parent: Node, origin: Vector3, yaw: float, col: Color, radius := 1.6, flip := false) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = arc_mesh(radius, 0.45, deg_to_rad(150), flip)
	var m := mat(col, 3.5, 0.95)
	m.vertex_color_use_as_albedo = true
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
	mi.global_position = origin + Vector3(0, 1.05, 0)
	var sgn := -1.0 if flip else 1.0
	mi.rotation = Vector3(0, yaw + 0.5 * sgn, deg_to_rad(14.0) * sgn)
	var tw := mi.create_tween()
	tw.tween_property(mi, "rotation:y", yaw - 0.35 * sgn, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.16)
	tw.tween_callback(mi.queue_free)

static func damage_number(parent: Node, pos: Vector3, txt: String, col: Color, big := false) -> void:
	var l := Label3D.new()
	l.text = txt
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.9)
	l.outline_size = 10
	l.font_size = 64 if big else 44
	l.pixel_size = 0.006
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = false
	parent.add_child(l)
	l.global_position = pos + Vector3(randf_range(-0.3, 0.3), 2.2, randf_range(-0.3, 0.3))
	var tw := l.create_tween()
	tw.set_parallel(true)
	tw.tween_property(l, "global_position:y", l.global_position.y + 1.1, 0.8).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_property(l, "modulate:a", 0.0, 0.8).set_delay(0.35)
	tw.chain().tween_callback(l.queue_free)

## Colonne d'ombre violette (Arise).
static func arise_pillar(parent: Node, pos: Vector3) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos
	var cyl := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = 0.9
	cm.bottom_radius = 1.2
	cm.height = 5.0
	cm.cap_top = false
	cm.cap_bottom = false
	cyl.mesh = cm
	cyl.material_override = mat(Color(0.45, 0.1, 1.0), 3.0, 0.35)
	cyl.position.y = 2.5
	cyl.scale = Vector3(0.2, 0.01, 0.2)
	root.add_child(cyl)
	var disc := ground_disc(2.4, Color(0.55, 0.15, 1.0), 0.9, true)
	root.add_child(disc)
	var lt := OmniLight3D.new()
	lt.light_color = Color(0.55, 0.2, 1)
	lt.light_energy = 0.0
	lt.omni_range = 9.0
	lt.position.y = 1.5
	root.add_child(lt)
	var p := CPUParticles3D.new()
	root.add_child(p)
	p.amount = 70
	p.lifetime = 1.4
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0, 1, 0)
	p.emission_ring_radius = 1.6
	p.emission_ring_inner_radius = 0.3
	p.emission_ring_height = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 8.0
	p.initial_velocity_min = 2.0
	p.initial_velocity_max = 4.5
	p.gravity = Vector3.ZERO
	p.scale_amount_min = 0.05
	p.scale_amount_max = 0.14
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = mat(Color(0.6, 0.25, 1.0), 4.0)
	p.mesh = sm
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(cyl, "scale", Vector3(1, 1, 1), 0.35).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(lt, "light_energy", 6.0, 0.35)
	tw.chain().tween_interval(1.0)
	tw.chain().set_parallel(true)
	tw.tween_property(cyl, "scale", Vector3(0.05, 1.3, 0.05), 0.5)
	tw.tween_property(lt, "light_energy", 0.0, 0.5)
	tw.tween_property(disc, "scale", Vector3(0.1, 1, 0.1), 0.5)
	tw.chain().tween_callback(func(): p.emitting = false)
	tw.chain().tween_interval(1.2)
	tw.chain().tween_callback(root.queue_free)

## Fumée d'ombre (départ / arrivée du pas de l'ombre).
static func shadow_puff(parent: Node, pos: Vector3) -> void:
	burst(parent, pos + Vector3(0, 0.9, 0), Color(0.35, 0.1, 0.8), 40, 0.32, 2.5, 0.55, -0.5)
	burst(parent, pos + Vector3(0, 0.9, 0), Color(0.02, 0.0, 0.05), 25, 0.45, 1.5, 0.7, -0.3)

## Traînée entre deux points.
static func trail(parent: Node, a: Vector3, b: Vector3, col: Color) -> void:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	var d := a.distance_to(b)
	bm.size = Vector3(0.12, 0.12, maxf(d, 0.1))
	mi.mesh = bm
	mi.material_override = mat(col, 5.0, 0.8)
	parent.add_child(mi)
	mi.global_position = (a + b) * 0.5 + Vector3(0, 1.0, 0)
	if d > 0.05:
		mi.look_at(b + Vector3(0, 1.0, 0), Vector3.UP)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(0.05, 0.05, 1), 0.3)
	tw.tween_callback(mi.queue_free)

## Projectile simple vers une cible (orbe de feu du chaman).
static func orb(parent: Node, from: Vector3, col: Color) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.22
	sm.height = 0.44
	mi.mesh = sm
	mi.material_override = mat(col, 5.0)
	parent.add_child(mi)
	mi.global_position = from
	var lt := OmniLight3D.new()
	lt.light_color = col
	lt.light_energy = 2.0
	lt.omni_range = 4.0
	mi.add_child(lt)
	return mi
