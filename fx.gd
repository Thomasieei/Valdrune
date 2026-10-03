extends Node
class_name Fx
# Effets : nombres de dégâts, éclats, arcs d'épée, télégraphes, secousses

static var _soft: Texture2D
static func soft_tex() -> Texture2D:
	if _soft: return _soft
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d: float = Vector2(x - 31.5, y - 31.5).length() / 32.0
			var a: float = clamp(1.0 - d, 0.0, 1.0); a = a * a
			img.set_pixel(x, y, Color(1, 1, 1, a))
	_soft = ImageTexture.create_from_image(img); return _soft

static var _add_mat: StandardMaterial3D
static func add_mat() -> StandardMaterial3D:
	if _add_mat: return _add_mat
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; m.vertex_color_use_as_albedo = true
	m.albedo_texture = soft_tex(); _add_mat = m; return m

# Éclats one-shot (CPU, compatible tous mobiles)
# Réserve d'émetteurs réutilisés : créer/détruire un émetteur à chaque coup provoquait des à-coups
static var _pool: Array = []
static var _grads := {}
static var _quad: QuadMesh
static func _grad(col: Color) -> Gradient:
	var key := col.to_html()
	if _grads.has(key): return _grads[key]
	var g := Gradient.new(); g.set_color(0, col); g.set_color(1, Color(col.r, col.g, col.b, 0.0))
	if _grads.size() > 120: _grads.clear()
	_grads[key] = g; return g

static func burst(parent: Node, pos: Vector3, col: Color, n := 14, speed := 4.0, size := 0.28, life := 0.55, grav := 9.0) -> void:
	var amt := 12 if n <= 14 else (24 if n <= 28 else 40)
	var now := Time.get_ticks_msec()
	var p: CPUParticles3D = null
	for e in _pool:
		if not is_instance_valid(e[0]): continue
		if e[1] == amt and now > e[2] and e[0].get_parent() == parent: p = e[0]; e[2] = now + int((life + 0.25) * 1000.0); break
	if p == null:
		_pool = _pool.filter(func(e): return is_instance_valid(e[0]))
		p = CPUParticles3D.new(); p.one_shot = true; p.emitting = false; p.amount = amt; p.explosiveness = 1.0
		if _quad == null: _quad = QuadMesh.new(); _quad.size = Vector2(1, 1); _quad.material = add_mat()
		p.mesh = _quad; p.direction = Vector3.UP; p.spread = 70.0
		parent.add_child(p)
		if _pool.size() < 48: _pool.append([p, amt, now + int((life + 0.25) * 1000.0)])
		else: parent.get_tree().create_timer(life + 0.3).timeout.connect(p.queue_free)
	p.lifetime = life; p.initial_velocity_min = speed * 0.5; p.initial_velocity_max = speed; p.gravity = Vector3(0, -grav, 0)
	p.scale_amount_min = size * 0.6; p.scale_amount_max = size
	p.color_ramp = _grad(col)
	p.position = pos; p.restart(); p.emitting = true

# Nombre flottant (étiquettes réutilisées, même taille de police : pas de nouveau rendu de glyphes)
static var _labels: Array = []
static func number(parent: Node, pos: Vector3, txt: String, col: Color, big := false, small := false) -> void:
	var l: Label3D = null
	for e in _labels:
		if is_instance_valid(e) and not e.visible and e.get_parent() == parent: l = e; break
	if l == null:
		_labels = _labels.filter(func(e): return is_instance_valid(e))
		l = Label3D.new(); l.font_size = 60; l.outline_size = 18; l.outline_modulate = Color(0, 0, 0, 0.9)
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.no_depth_test = true; l.render_priority = 10
		parent.add_child(l)
		if _labels.size() < 40: _labels.append(l)
	if l.has_meta("tw"):
		var old: Tween = l.get_meta("tw")
		if old and old.is_valid(): old.kill()
	l.visible = true; l.text = txt; l.modulate = col
	l.pixel_size = 0.0108 if big else (0.006 if small else 0.0081)
	l.position = pos + Vector3(randf_range(-0.3, 0.3), 0, 0)
	var tw := l.create_tween(); tw.set_parallel(true); l.set_meta("tw", tw)
	l.scale = Vector3.ONE * 0.4
	tw.tween_property(l, "scale", Vector3.ONE, 0.12).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "position:y", pos.y + 1.4, 0.8).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.35).set_delay(0.5)
	var keep := _labels.has(l)
	tw.chain().tween_callback(func():
		if not is_instance_valid(l): return
		if keep: l.visible = false
		else: l.queue_free())

# Arc de coup d'épée (croissant lumineux qui s'efface)
static var _arc_mesh: ArrayMesh
static func slash(parent: Node, pos: Vector3, yaw: float, col := Color(1, 0.95, 0.8), radius := 1.9, flip := false) -> void:
	if not _arc_mesh:
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var seg := 18
		for i in seg:
			var a0: float = lerp(-1.25, 1.25, float(i) / seg); var a1: float = lerp(-1.25, 1.25, float(i + 1) / seg)
			var w0 := sin(PI * float(i) / seg); var w1 := sin(PI * float(i + 1) / seg)
			var p := [Vector3(sin(a0) * 0.55, 0, cos(a0) * 0.55), Vector3(sin(a0), 0, cos(a0)), Vector3(sin(a1) * 0.55, 0, cos(a1) * 0.55), Vector3(sin(a1), 0, cos(a1))]
			var c0 := Color(1, 1, 1, 0.0); var c1 := Color(1, 1, 1, w0); var c3 := Color(1, 1, 1, w1)
			for v in [[p[0], c0], [p[1], c1], [p[2], c0], [p[2], c0], [p[1], c1], [p[3], c3]]:
				st.set_color(v[1]); st.add_vertex(v[0])
		_arc_mesh = st.commit()
	var mi := MeshInstance3D.new(); mi.mesh = _arc_mesh
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD; m.vertex_color_use_as_albedo = true; m.albedo_color = col; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos; mi.rotation = Vector3(0.0, yaw, 0.35 if flip else -0.35); mi.scale = Vector3.ONE * radius * 0.7
	parent.add_child(mi)
	var tw := mi.create_tween(); tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * radius, 0.12)
	tw.tween_property(mi, "rotation:y", yaw + (-0.6 if flip else 0.6), 0.16)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.2).set_delay(0.05)
	tw.chain().tween_callback(mi.queue_free)

# Disque au sol (télégraphe d'attaque ennemie, onde de choc…)
static func disc(parent: Node, pos: Vector3, radius: float, col: Color, dur: float, grow := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 1.0; cm.bottom_radius = 1.0; cm.height = 0.02; cm.radial_segments = 32; mi.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = col
	m.no_depth_test = false; mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mi.position = pos + Vector3(0, 0.08, 0); parent.add_child(mi)
	var tw := mi.create_tween()
	if grow:
		mi.scale = Vector3(0.05, 1, 0.05) * radius
		tw.tween_property(mi, "scale", Vector3(radius, 1, radius), dur)
		tw.tween_callback(mi.queue_free)
	else:
		mi.scale = Vector3(radius * 0.3, 1, radius * 0.3)
		tw.set_parallel(true); tw.tween_property(mi, "scale", Vector3(radius, 1, radius), dur); tw.tween_property(m, "albedo_color:a", 0.0, dur)
		tw.chain().tween_callback(mi.queue_free)
	return mi
