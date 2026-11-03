class_name Juice
## Les « ingrédients » qui donnent du poids aux coups et aux sorts (inspirés de Brèche Écarlate) :
## ondes au sol, lueurs, arcs de taille, gerbes de poussière, ralentis d'impact. Tous très légers.

static var _shader: Shader
static var _quad: QuadMesh

static func _mat(col: Color, inner: float, open_ang := TAU, lead := 0.0) -> ShaderMaterial:
	if _shader == null:
		_shader = load("res://shaders/fx_ring.gdshader")
	var m := ShaderMaterial.new()
	m.shader = _shader
	m.set_shader_parameter("col", col)
	m.set_shader_parameter("inner", inner)
	m.set_shader_parameter("open_ang", open_ang)
	m.set_shader_parameter("lead", lead)
	return m

static func _plane(m: ShaderMaterial, pos: Vector3, size: float) -> MeshInstance3D:
	if _quad == null:
		_quad = QuadMesh.new()
		_quad.size = Vector2(2, 2)
		_quad.orientation = PlaneMesh.FACE_Y
	var mi := MeshInstance3D.new()
	mi.mesh = _quad
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	FX._add(mi, pos)
	mi.scale = Vector3.ONE * size
	return mi

static func _ground_y(pos: Vector3) -> float:
	return Powers.ground(pos + Vector3.UP * 0.8) + 0.08

## Onde : anneau qui s'élargit en s'effaçant
static func onde(pos: Vector3, col: Color, r := 3.0, dur := 0.45) -> void:
	var m := _mat(col, 0.86)
	var mi := _plane(m, Vector3(pos.x, _ground_y(pos), pos.z), 0.3)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "scale", Vector3.ONE * r, dur).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, dur)
	tw.chain().tween_callback(mi.queue_free)

## Lueur au sol : disque doux qui pulse puis s'éteint
static func lueur(pos: Vector3, col: Color, r := 2.5, dur := 0.5, intens := 1.0) -> void:
	var m := _mat(Color(col.r, col.g, col.b, intens), 0.0)
	var mi := _plane(m, Vector3(pos.x, _ground_y(pos), pos.z), r)
	var tw := mi.create_tween()
	tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, dur)
	tw.tween_callback(mi.queue_free)

## Arc de taille : croissant lumineux qui balaie devant le héros
static func arc(pos: Vector3, yaw: float, r: float, col: Color, open_deg := 150.0, dur := 0.26, sweep := 0.9, tilt := 0.0) -> void:
	var m := _mat(col, 0.42, deg_to_rad(open_deg), 1.0)
	var mi := _plane(m, pos, r)
	mi.rotation = Vector3(tilt, yaw - sweep * 0.5, 0)
	var tw := mi.create_tween()
	tw.set_parallel(true)
	tw.tween_property(mi, "rotation:y", yaw + sweep * 0.5, dur).set_ease(Tween.EASE_OUT)
	tw.tween_property(mi, "scale", Vector3.ONE * r * 1.15, dur)
	tw.tween_method(func(v: float): m.set_shader_parameter("fade", v), 1.0, 0.0, dur).set_ease(Tween.EASE_IN)
	tw.chain().tween_callback(mi.queue_free)

## Gerbe de poussière / gravats (impact au sol)
static func dust(pos: Vector3, n := 16, force := 5.0, col := Color(0.82, 0.76, 0.65)) -> void:
	var p := FX.particles("smoke_02", n, 0.7, [Color(col.r, col.g, col.b, 0.75), Color(col.r * 0.8, col.g * 0.8, col.b * 0.8, 0.0)], 0.9, true, false)
	p.direction = Vector3.UP
	p.spread = 75.0
	p.initial_velocity_min = force * 0.4
	p.initial_velocity_max = force
	p.gravity = Vector3(0, -6, 0)
	p.damping_min = 2.0
	p.damping_max = 4.0
	FX._add(p, Vector3(pos.x, _ground_y(pos), pos.z))
	p.emitting = true
	FX._free_after(p, 1.0)

## Coup qui porte : onde rapide, étincelles, micro-arrêt, tremblement
static func impact(pos: Vector3, col: Color, heavy := false) -> void:
	onde(pos, col, 2.6 if heavy else 1.5, 0.3 if heavy else 0.22)
	Magic.sparks(pos + Vector3.UP * 1.0, col, 16 if heavy else 9, 8.0 if heavy else 6.0, 0.4)
	if heavy:
		lueur(pos, col, 2.2, 0.35, 0.8)
		dust(pos, 14, 5.0)
	FX.hitstop(0.07 if heavy else 0.035)
