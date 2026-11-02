class_name Magic
## Bibliothèque d'effets magiques : énergie translucide animée, cercles runiques, éclairs, éclats de lumière,
## débris, traînées. Pensée pour le téléphone : pas de post-traitement, seulement des matériaux et particules.

static var _mats := {}
static var _rune_shader: Shader
static var _energy_shader: Shader

static func energy(col: Color, alpha := 0.5, hex := 0.0, glow := 1.0) -> ShaderMaterial:
	var key := "%s|%.2f|%.1f|%.2f" % [col.to_html(), alpha, hex, glow]
	if not _mats.has(key):
		if _energy_shader == null:
			_energy_shader = load("res://shaders/energy.gdshader")
		var m := ShaderMaterial.new()
		m.shader = _energy_shader
		m.set_shader_parameter("color", col)
		m.set_shader_parameter("alpha", alpha)
		m.set_shader_parameter("hex", hex)
		m.set_shader_parameter("glow", glow)
		m.set_shader_parameter("noise", load("res://assets/fx/fx_noise.png"))
		_mats[key] = m
	return _mats[key]

## Cercle runique au sol qui se dessine depuis le centre, tourne, puis s'éteint
static func rune(pos: Vector3, r: float, col: Color, dur: float, spin := 0.6) -> MeshInstance3D:
	if _rune_shader == null:
		_rune_shader = load("res://shaders/rune_circle.gdshader")
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(r * 2.0, r * 2.0)
	mi.mesh = q
	var m := ShaderMaterial.new()
	m.shader = _rune_shader
	m.set_shader_parameter("color", col)
	m.set_shader_parameter("spin", spin)
	m.set_shader_parameter("progress", 0.0)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.root.add_child(mi)
	mi.global_position = pos + Vector3.UP * 0.08
	mi.rotation = Vector3(-PI / 2.0, 0, 0)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("progress", v), 0.0, 1.0, minf(0.35, dur * 0.4))
	tw.tween_interval(maxf(0.0, dur - 0.6))
	tw.tween_method(func(v: float): m.set_shader_parameter("intensity", v), 1.0, 0.0, 0.3)
	tw.tween_callback(mi.queue_free)
	return mi

## Halo lumineux (faux « bloom ») : billboard additif qui gonfle puis s'éteint
static func halo(pos: Vector3, size: float, col: Color, dur := 0.35) -> void:
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2.ONE * size
	mi.mesh = q
	mi.material_override = FX.pmat("light_01", true, true, col)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.root.add_child(mi)
	mi.global_position = pos
	mi.scale = Vector3.ONE * 0.4
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * 1.3, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "transparency", 1.0, dur)
	tw.chain().tween_callback(mi.queue_free)

## Gerbe d'étincelles
static func sparks(pos: Vector3, col: Color, n := 24, speed := 9.0, life := 0.6) -> void:
	var p := FX.particles("spark_04", n, life, [Color(1, 1, 1, 1), col, Color(col.r, col.g, col.b, 0)], 0.28)
	p.spread = 180.0
	p.initial_velocity_min = speed * 0.5
	p.initial_velocity_max = speed
	p.gravity = Vector3(0, -9, 0)
	p.scale_amount_min = 0.4
	p.scale_amount_max = 1.2
	FX.root.add_child(p)
	p.global_position = pos
	p.emitting = true
	FX._free_after(p, life + 0.3)

## Débris de pierre et de terre projetés (impacts lourds)
static func debris(pos: Vector3, n := 14, force := 7.0) -> void:
	var p := CPUParticles3D.new()
	var bm := BoxMesh.new()
	bm.size = Vector3(0.22, 0.18, 0.2)
	p.mesh = bm
	p.material_override = Geo.mat("pierre_base")
	p.amount = n
	p.one_shot = true
	p.explosiveness = 1.0
	p.lifetime = 1.3
	p.direction = Vector3.UP
	p.spread = 55.0
	p.initial_velocity_min = force * 0.5
	p.initial_velocity_max = force
	p.angular_velocity_min = -400.0
	p.angular_velocity_max = 400.0
	p.gravity = Vector3(0, -18, 0)
	p.scale_amount_min = 0.6
	p.scale_amount_max = 1.8
	FX.root.add_child(p)
	p.global_position = pos + Vector3.UP * 0.2
	p.emitting = true
	FX._free_after(p, 1.6)

## Éclat complet : halo, étincelles, onde de choc, lumière, secousse — la « signature » d'un impact
static func burst(pos: Vector3, col: Color, size := 1.0, heavy := false) -> void:
	halo(pos + Vector3.UP * 0.8, 5.0 * size, col, 0.3 + 0.1 * size)
	sparks(pos + Vector3.UP * 0.6, col, int(18 * size) + 8, 7.0 + 3.0 * size)
	FX.shockwave(pos, 2.0 * size)
	FX.impact_light(pos + Vector3.UP, col, 3.0 + 3.0 * size, 6.0 * size + 4.0)
	if heavy:
		debris(pos, int(10 * size) + 4, 6.0 + 2.0 * size)
	if Combat.player:
		Combat.player.shake(0.12 + 0.18 * size)

## Éclair zigzagant de a vers b (épais, cœur blanc, halo coloré)
static func lightning(a: Vector3, b: Vector3, col: Color, width := 0.16, dur := 0.18) -> void:
	var n := Node3D.new()
	FX.root.add_child(n)
	var core := energy(Color(1, 1, 1, 1), 1.0, 0.0, 1.0)
	var glow := energy(col, 0.7, 0.0, 1.0)
	var segs := 9
	var p := a
	var dir := b - a
	var side := dir.cross(Vector3.UP).normalized()
	if side.length() < 0.1:
		side = Vector3.RIGHT
	var up2 := dir.cross(side).normalized()
	for i in segs:
		var f := float(i + 1) / segs
		var q := a + dir * f
		if i < segs - 1:
			q += side * randf_range(-1.0, 1.0) * dir.length() * 0.05 + up2 * randf_range(-1.0, 1.0) * dir.length() * 0.05
		for layer in 2:
			var seg := MeshInstance3D.new()
			var bm := BoxMesh.new()
			var w := width * (1.0 if layer == 0 else 3.2)
			bm.size = Vector3(w, w, p.distance_to(q) + w)
			seg.mesh = bm
			seg.material_override = core if layer == 0 else glow
			seg.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			n.add_child(seg)
			var mid := (p + q) * 0.5
			seg.global_position = mid
			var fwd := (q - p).normalized()
			seg.global_basis = Basis.looking_at(fwd, Vector3.FORWARD if absf(fwd.y) > 0.98 else Vector3.UP)
		# branches
		if i in [2, 5] and randf() < 0.8:
			var br := q + (side * randf_range(-1, 1) + Vector3.DOWN) * dir.length() * 0.12
			var bseg := MeshInstance3D.new()
			var bb := BoxMesh.new()
			bb.size = Vector3(width * 0.7, width * 0.7, q.distance_to(br))
			bseg.mesh = bb
			bseg.material_override = core
			n.add_child(bseg)
			bseg.global_position = (q + br) * 0.5
			var bf := (br - q).normalized()
			bseg.global_basis = Basis.looking_at(bf, Vector3.FORWARD if absf(bf.y) > 0.98 else Vector3.UP)
		p = q
	halo(b + Vector3.UP * 0.3, 4.0, col, 0.25)
	var tw := n.create_tween()
	tw.tween_interval(dur)
	tw.tween_callback(n.queue_free)

## Traînée lumineuse qui suit un objet en mouvement (projectiles, épées)
static func trail(target: Node3D, col: Color, size := 0.5, tex := "spark_04", amount := 24) -> CPUParticles3D:
	var p := FX.particles(tex, amount, 0.35, [Color(1, 1, 1, 0.9), col, Color(col.r, col.g, col.b, 0)], size, false)
	p.local_coords = false
	p.gravity = Vector3.ZERO
	p.spread = 10.0
	p.initial_velocity_min = 0.2
	p.initial_velocity_max = 0.8
	target.add_child(p)
	p.emitting = true
	return p

## Colonne de lumière qui s'élève du sol (invocations, apparitions)
static func pillar(pos: Vector3, col: Color, h := 6.0, dur := 0.6, w := 1.2) -> void:
	var mi := MeshInstance3D.new()
	var cm := CylinderMesh.new()
	cm.top_radius = w * 0.3
	cm.bottom_radius = w
	cm.height = h
	cm.radial_segments = 16
	cm.cap_top = false
	cm.cap_bottom = false
	mi.mesh = cm
	mi.material_override = energy(col, 0.35, 0.0, 1.0)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX.root.add_child(mi)
	mi.global_position = pos + Vector3.UP * h * 0.5
	mi.scale = Vector3(0.2, 0.05, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(1, 1, 1), 0.18).set_ease(Tween.EASE_OUT)
	tw.tween_interval(maxf(0.0, dur - 0.4))
	tw.tween_property(mi, "scale", Vector3(0.02, 1.2, 0.02), 0.22)
	tw.tween_callback(mi.queue_free)
