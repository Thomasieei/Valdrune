class_name FX
## Effets visuels réutilisables (compatibles renderer GL Compatibility).

## Budget lumières : en rendu mobile (Compatibility) chaque lumière ajoute une passe complète
## sur tout ce qu'elle touche. Les lumières décoratives sont donc désactivées (l'émission + le glow suffisent).
static var light_budget := 0
static func new_light(important := false) -> OmniLight3D:
	var l := OmniLight3D.new()
	if not important:
		l.visible = false
	else:
		light_budget += 1
	l.shadow_enabled = false
	return l

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
	l.pixel_size = 0.0011
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.fixed_size = true
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
	var lt := FX.new_light()
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
	var lt := FX.new_light()
	lt.light_color = col
	lt.light_energy = 2.0
	lt.omni_range = 4.0
	mi.add_child(lt)
	return mi


## Zone d'alerte rectangulaire (charge du boss).
static func telegraph_line(parent: Node, from: Vector3, to: Vector3, width: float, dur: float, col := Color(1, 0.12, 0.1)) -> void:
	var d := to - from
	d.y = 0
	var L := maxf(d.length(), 0.5)
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = from + Vector3(0, 0.06, 0)
	root.rotation.y = atan2(d.x, d.z)
	var edge := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(width, L)
	edge.mesh = pm
	edge.material_override = mat(col, 1.5, 0.22)
	edge.position.z = L * 0.5
	root.add_child(edge)
	var fill := MeshInstance3D.new()
	var pm2 := PlaneMesh.new()
	pm2.size = Vector2(width, L)
	fill.mesh = pm2
	fill.material_override = mat(col, 2.0, 0.4)
	fill.position.z = 0.0
	fill.scale = Vector3(1, 1, 0.01)
	root.add_child(fill)
	var tw := root.create_tween()
	tw.set_parallel(true)
	tw.tween_property(fill, "scale:z", 1.0, dur)
	tw.tween_property(fill, "position:z", L * 0.5, dur)
	tw.chain().tween_callback(root.queue_free)

## Bulle de dialogue au-dessus d'une unité.
static func speech(owner_node: Node3D, txt: String, col := Color(1, 0.85, 0.75), h := 2.6, dur := 2.8) -> void:
	for c in owner_node.get_children():
		if c is Label3D and (c as Label3D).has_meta("speech"):
			c.queue_free()
	var l := Label3D.new()
	l.set_meta("speech", true)
	l.text = txt
	l.font_size = 40
	l.pixel_size = 0.00095
	l.fixed_size = true
	l.outline_size = 12
	l.modulate = col
	l.outline_modulate = Color(0, 0, 0, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	l.no_depth_test = true
	l.width = 520
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.position.y = h
	owner_node.add_child(l)
	var tw := l.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(l, "modulate:a", 0.0, 0.4)
	tw.tween_callback(l.queue_free)

## Portail bleu (ou rouge) façon Solo Leveling.
static var VORTEX_SH: Shader = _sh("""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_mix, shadows_disabled;
uniform vec4 col : source_color = vec4(0.3, 0.55, 1.0, 1.0);
uniform vec4 col2 : source_color = vec4(0.75, 0.9, 1.0, 1.0);
void vertex() {
	MODELVIEW_MATRIX = VIEW_MATRIX * mat4(vec4(normalize(cross(vec3(0.0, 1.0, 0.0), INV_VIEW_MATRIX[2].xyz)), 0.0), vec4(0.0, 1.0, 0.0, 0.0), vec4(normalize(cross(INV_VIEW_MATRIX[0].xyz, vec3(0.0, 1.0, 0.0))), 0.0), MODEL_MATRIX[3]);
}
float ss(float e0, float e1, float x) { float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	p.x += sin(p.y * 6.0 + TIME * 2.0) * 0.012;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x);
	float lr = log(r + 0.03);
	float s1 = sin(a * 5.0 + lr * 7.0 - TIME * 3.2) * 0.5 + 0.5;
	float s2 = sin(a * 3.0 - lr * 4.5 + TIME * 1.9) * 0.5 + 0.5;
	float s3 = sin(a * 11.0 + lr * 13.0 - TIME * 5.0) * 0.5 + 0.5;
	vec3 c = mix(col.rgb * 0.12, col.rgb * 1.3, s1 * 0.65 + s2 * 0.35);
	c += col2.rgb * pow(s1 * s3, 5.0) * 2.4 * ss(0.15, 0.85, r);
	float core = ss(0.42, 0.0, r);
	c = mix(c, vec3(0.01, 0.0, 0.03), core * 0.9);
	float star = step(0.985, fract(sin(dot(floor(p * 40.0), vec2(12.9898, 78.233))) * 43758.5453));
	c += vec3(star) * core * (0.5 + 0.5 * sin(TIME * 4.0 + p.x * 30.0));
	float rim = ss(0.80, 0.97, r) * ss(1.0, 0.95, r);
	c += col2.rgb * rim * 3.2;
	ALBEDO = c;
	ALPHA = ss(1.0, 0.9, r) * 0.96;
}""")
static var RUNE_SH: Shader = _sh("""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.3, 0.55, 1.0, 1.0);
float ss(float e0, float e1, float x) { float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
void fragment() {
	vec2 p = UV * 2.0 - 1.0;
	float r = length(p);
	if (r > 1.0) discard;
	float a = atan(p.y, p.x) / 6.28318 + 0.5;
	float rings = ss(0.018, 0.0, abs(r - 0.96)) + ss(0.012, 0.0, abs(r - 0.83)) + ss(0.01, 0.0, abs(r - 0.5));
	float band = step(0.84, r) * step(r, 0.95);
	float runes = band * step(0.45, fract(a * 28.0 + TIME * 0.12)) * step(0.3, fract(a * 28.0 * 3.0 + TIME * 0.36));
	float spokes = step(r, 0.82) * step(0.5, r) * ss(0.012, 0.0, abs(fract(a * 6.0 - TIME * 0.08) - 0.5) * r * 6.0);
	float inner = step(r, 0.5) * step(0.38, r) * step(0.55, fract(a * 12.0 - TIME * 0.25));
	float glow = ss(1.0, 0.0, r) * 0.22;
	float pulse = 0.75 + 0.25 * sin(TIME * 2.2);
	ALBEDO = col.rgb * (rings * 2.6 + runes * 1.7 + spokes * 1.5 + inner * 1.2 + glow) * pulse;
	ALPHA = 1.0;
}""")
static var BEAM_SH: Shader = _sh("""shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, blend_add, shadows_disabled;
uniform vec4 col : source_color = vec4(0.3, 0.55, 1.0, 1.0);
float ss(float e0, float e1, float x) { float t = clamp((x - e0) / (e1 - e0), 0.0, 1.0); return t * t * (3.0 - 2.0 * t); }
void fragment() {
	float v = UV.y;
	float flick = 0.8 + 0.2 * sin(TIME * 3.0 + UV.x * 25.0 + v * 8.0);
	ALBEDO = col.rgb * pow(v, 2.2) * 0.9 * flick;
	ALPHA = 1.0;
}""")

static func _sh(code: String) -> Shader:
	var s := Shader.new()
	s.code = code
	return s

static func _smat(sh: Shader, col: Color, col2 := Color(1, 1, 1)) -> ShaderMaterial:
	var m := ShaderMaterial.new()
	m.shader = sh
	m.set_shader_parameter("col", col)
	if sh == VORTEX_SH:
		m.set_shader_parameter("col2", col2)
	return m

## Portail : vortex animé (shader), anneau, cercle de runes au sol, colonne de lumière, éclats en orbite.
static func portal(parent: Node, pos: Vector3, col: Color, r := 2.4) -> Node3D:
	var gate := Node3D.new()
	parent.add_child(gate)
	gate.global_position = pos + Vector3(0, r + 0.2, 0)
	var light_col := col.lightened(0.55)
	var vort := MeshInstance3D.new()
	var qm := QuadMesh.new()
	qm.size = Vector2(r * 2.0, r * 2.0)
	vort.mesh = qm
	vort.material_override = _smat(VORTEX_SH, col, light_col)
	vort.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(vort)
	# halo additif autour du vortex
	var halo := MeshInstance3D.new()
	var hq := QuadMesh.new()
	hq.size = Vector2(r * 3.0, r * 3.0)
	halo.mesh = hq
	var hm := mat(col, 1.5, 0.22)
	hm.billboard_mode = BaseMaterial3D.BILLBOARD_FIXED_Y
	hm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	hm.albedo_texture = _soft_tex()
	halo.material_override = hm
	halo.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(halo)
	# runes au sol
	var rune := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(r * 3.4, r * 3.4)
	rune.mesh = pm
	rune.material_override = _smat(RUNE_SH, col)
	rune.position = Vector3(0, -r - 0.12, 0)
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(rune)
	# colonne de lumière visible de loin
	var beam := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = r * 0.25
	cm.bottom_radius = r * 0.55
	cm.height = 34.0
	cm.cap_top = false
	cm.cap_bottom = false
	beam.mesh = cm
	beam.material_override = _smat(BEAM_SH, col)
	beam.position = Vector3(0, 17.0 - r, 0)
	beam.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	gate.add_child(beam)
	# éclats de roche/cristal en orbite
	var orbit := Node3D.new()
	gate.add_child(orbit)
	for k in 7:
		var sh := MeshInstance3D.new()
		var pr := PrismMesh.new()
		pr.size = Vector3(0.22, 0.5, 0.22) * randf_range(0.7, 1.4)
		sh.mesh = pr
		sh.material_override = mat(light_col, 2.6)
		var ang := k * TAU / 7.0
		sh.position = Vector3(cos(ang) * (r + 0.6), sin(ang * 2.0) * 0.5, sin(ang) * (r + 0.6))
		sh.rotation = Vector3(randf() * 3.0, randf() * 3.0, randf() * 3.0)
		orbit.add_child(sh)
	var tw := orbit.create_tween().set_loops()
	tw.tween_property(orbit, "rotation_degrees:y", 360.0, 9.0).from(0.0)
	# particules aspirées vers le centre
	var p := CPUParticles3D.new()
	p.amount = 36
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	p.emission_sphere_radius = r * 1.5
	p.gravity = Vector3.ZERO
	p.radial_accel_min = -6.0
	p.radial_accel_max = -4.0
	p.tangential_accel_min = 3.0
	p.tangential_accel_max = 5.0
	p.scale_amount_min = 0.03
	p.scale_amount_max = 0.07
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = mat(light_col, 3.0)
	p.mesh = sm
	gate.add_child(p)
	return gate

static var _soft: Texture2D
static func _soft_tex() -> Texture2D:
	if _soft == null:
		var g := Gradient.new()
		g.colors = PackedColorArray([Color(1, 1, 1, 1), Color(1, 1, 1, 0)])
		var gt := GradientTexture2D.new()
		gt.gradient = g
		gt.fill = GradientTexture2D.FILL_RADIAL
		gt.fill_from = Vector2(0.5, 0.5)
		gt.fill_to = Vector2(0.5, 0.0)
		gt.width = 128
		gt.height = 128
		_soft = gt
	return _soft


## Boule de feu : charge dans la main, projectile traçant, explosion avec fumée et brûlure au sol.
static func fireball(parent: Node, from: Vector3, to: Vector3, on_hit: Callable, charge := 0.35) -> void:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = from
	var core := MeshInstance3D.new()
	var sm := SphereMesh.new()
	sm.radius = 0.2
	sm.height = 0.4
	core.mesh = sm
	core.material_override = mat(Color(1.0, 0.55, 0.15), 6.0)
	root.add_child(core)
	var halo := MeshInstance3D.new()
	var hm := SphereMesh.new()
	hm.radius = 0.38
	hm.height = 0.76
	halo.mesh = hm
	halo.material_override = mat(Color(1.0, 0.25, 0.05), 3.0, 0.35)
	root.add_child(halo)
	var lt := FX.new_light()
	lt.light_color = Color(1, 0.5, 0.15)
	lt.light_energy = 3.0
	lt.omni_range = 5.0
	root.add_child(lt)
	var tr := CPUParticles3D.new()
	tr.amount = 40
	tr.lifetime = 0.45
	tr.local_coords = false
	tr.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE
	tr.emission_sphere_radius = 0.15
	tr.gravity = Vector3(0, 1.5, 0)
	tr.initial_velocity_min = 0.2
	tr.initial_velocity_max = 0.8
	tr.scale_amount_min = 0.06
	tr.scale_amount_max = 0.14
	var pm := SphereMesh.new()
	pm.radius = 0.5
	pm.height = 1.0
	pm.radial_segments = 6
	pm.rings = 3
	pm.material = mat(Color(1.0, 0.45, 0.1), 4.0, 0.8)
	tr.mesh = pm
	var grad := Gradient.new()
	grad.colors = PackedColorArray([Color(1, 0.9, 0.4), Color(1, 0.3, 0.05), Color(0.2, 0.05, 0.02, 0)])
	tr.color_ramp = grad
	root.add_child(tr)
	root.scale = Vector3.ONE * 0.15
	var tw := root.create_tween()
	tw.tween_property(root, "scale", Vector3.ONE, charge).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	var dur := clampf(from.distance_to(to) / 18.0, 0.15, 0.9)
	tw.tween_property(root, "global_position", to, dur).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN)
	tw.tween_callback(func(): FX._fire_explode(parent, root, on_hit))

static func _fire_explode(parent: Node, root: Node3D, on_hit: Callable) -> void:
	var p := root.global_position
	root.queue_free()
	burst(parent, p, Color(1.0, 0.6, 0.15), 40, 0.16, 6.0, 0.5, 2.0)
	burst(parent, p, Color(1.0, 0.25, 0.05), 25, 0.22, 3.5, 0.6, -1.0)
	burst(parent, p + Vector3(0, 0.4, 0), Color(0.12, 0.1, 0.1), 18, 0.35, 1.6, 1.1, -1.5)
	var scorch := ground_disc(1.6, Color(0.05, 0.02, 0.0), 0.75, false)
	parent.add_child(scorch)
	scorch.global_position = Vector3(p.x, p.y - 0.95, p.z)
	var tw := scorch.create_tween()
	tw.tween_interval(2.0)
	tw.tween_property(scorch, "scale", Vector3(0.01, 1, 0.01), 1.0)
	tw.tween_callback(scorch.queue_free)
	var fl := FX.new_light()
	fl.light_color = Color(1, 0.55, 0.2)
	fl.light_energy = 6.0
	fl.omni_range = 8.0
	parent.add_child(fl)
	fl.global_position = p
	var t2 := fl.create_tween()
	t2.tween_property(fl, "light_energy", 0.0, 0.35)
	t2.tween_callback(fl.queue_free)
	if on_hit.is_valid():
		on_hit.call(p)

## Pluie de feu : plusieurs zones orange, puis des météores tombent du ciel.
static func fire_rain(parent: Node, spots: Array, on_hit: Callable) -> void:
	for i in spots.size():
		var sp: Vector3 = spots[i]
		telegraph(parent, sp, 2.2, 1.0 + i * 0.12, Color(1.0, 0.45, 0.05))
		var t := parent.get_tree().create_timer(0.55 + i * 0.12)
		var a := sp + Vector3(randf_range(-3, 3), 16, randf_range(-3, 3))
		var b := sp + Vector3(0, 0.9, 0)
		t.timeout.connect(func(): FX.fireball(parent, a, b, on_hit, 0.05))

## Zone de soin au sol : cercle vert et particules qui montent.
static func heal_zone(parent: Node, pos: Vector3, r: float, dur: float) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.global_position = pos + Vector3(0, 0.05, 0)
	root.add_child(ground_disc(r, Color(0.3, 1.0, 0.45), 0.35, false))
	root.add_child(ground_disc(r, Color(0.5, 1.0, 0.6), 0.9, true))
	var p := CPUParticles3D.new()
	p.amount = 45
	p.lifetime = 1.6
	p.emission_shape = CPUParticles3D.EMISSION_SHAPE_RING
	p.emission_ring_axis = Vector3(0, 1, 0)
	p.emission_ring_radius = r * 0.9
	p.emission_ring_inner_radius = 0.2
	p.emission_ring_height = 0.1
	p.direction = Vector3(0, 1, 0)
	p.spread = 5.0
	p.gravity = Vector3.ZERO
	p.initial_velocity_min = 0.8
	p.initial_velocity_max = 1.8
	p.scale_amount_min = 0.04
	p.scale_amount_max = 0.09
	var sm := SphereMesh.new()
	sm.radius = 0.5
	sm.height = 1.0
	sm.radial_segments = 6
	sm.rings = 3
	sm.material = mat(Color(0.5, 1.0, 0.55), 3.0)
	p.mesh = sm
	root.add_child(p)
	var lt := FX.new_light()
	lt.light_color = Color(0.4, 1.0, 0.5)
	lt.light_energy = 1.6
	lt.omni_range = r * 2.0
	lt.position.y = 1.0
	root.add_child(lt)
	var tw := root.create_tween()
	tw.tween_interval(dur)
	tw.tween_property(root, "scale", Vector3(0.01, 1, 0.01), 0.4)
	tw.tween_callback(root.queue_free)
	return root

## Aura rouge de provocation (tank) : anneau qui s'étend + lueur.
static func taunt_aura(owner_node: Node3D, r: float, dur: float) -> void:
	var ring := ground_disc(1.0, Color(1, 0.12, 0.08), 0.9, true)
	owner_node.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_property(ring, "scale", Vector3(r * 0.65, 1, r * 0.65), 0.45).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(ring, "scale", Vector3(r * 0.7, 1, r * 0.7), 0.3)
	tw.tween_callback(ring.queue_free)
	var aura := ground_disc(1.2, Color(1, 0.1, 0.05), 0.35, false)
	owner_node.add_child(aura)
	var lt := FX.new_light()
	lt.light_color = Color(1, 0.15, 0.1)
	lt.light_energy = 2.5
	lt.omni_range = 4.0
	lt.position.y = 1.2
	owner_node.add_child(lt)
	var t2 := lt.create_tween()
	t2.tween_interval(dur)
	t2.tween_property(lt, "light_energy", 0.0, 0.4)
	t2.tween_callback(lt.queue_free)
	t2.tween_callback(aura.queue_free)
