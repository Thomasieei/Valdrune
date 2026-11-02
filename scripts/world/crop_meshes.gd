class_name CropMeshes
## Maillages procéduraux des cultures (origine au pied, hauteur 1 = maturité) et leur shader.

static var _wheat: ArrayMesh
static var _cab: ArrayMesh
static var _mat: ShaderMaterial

static func material() -> ShaderMaterial:
	if _mat == null:
		_mat = ShaderMaterial.new()
		_mat.shader = load("res://shaders/crop.gdshader")
	return _mat

static func wheat() -> ArrayMesh:
	if _wheat:
		return _wheat
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for k in 7:
		var a := TAU * k / 7.0 + rng.randf() * 0.4
		var lean := Vector3(cos(a), 0, sin(a)) * rng.randf_range(0.04, 0.12)
		var h := rng.randf_range(0.95, 1.15)
		var side := Vector3(-sin(a), 0, cos(a)) * 0.025
		var base := Vector3(cos(a), 0, sin(a)) * 0.05
		var top := base + lean + Vector3.UP * h
		# tige (ruban) — UV.y = hauteur relative (0 pied, 1 sommet) pour le dégradé
		_tri(st, base - side, base + side, top, 0.0, 0.0, 1.0)
		_tri(st, base + side, base - side, top, 0.0, 0.0, 1.0)
		# épi (losange épais)
		var e0 := top - (lean.normalized() * 0.0) - Vector3.UP * 0.22
		var w := side * 2.2
		var e1 := top + Vector3.UP * 0.05
		_tri(st, e0 - w, e0 + w, e1, 0.85, 0.85, 1.0, true)
		_tri(st, e0 + w, e0 - w, e1, 0.85, 0.85, 1.0, true)
		var w2 := Vector3(side.z, 0, -side.x) * 2.2
		_tri(st, e0 - w2, e0 + w2, e1, 0.85, 0.85, 1.0, true)
		_tri(st, e0 + w2, e0 - w2, e1, 0.85, 0.85, 1.0, true)
	st.generate_normals()
	_wheat = st.commit()
	return _wheat

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, ua: float, ub: float, uc: float, ear := false) -> void:
	var col := Color(1, 0, 0) if ear else Color(0, 0, 0)
	for p in [[a, ua], [c, uc], [b, ub]]:
		st.set_color(col)
		st.set_uv(Vector2(0, p[1]))
		st.add_vertex(p[0])

static func cabbage() -> ArrayMesh:
	if _cab:
		return _cab
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	# coeur : sphère basse résolution
	var r := 0.28
	var rings := 4
	var seg := 7
	for j in rings:
		var t0 := PI * j / rings
		var t1 := PI * (j + 1) / rings
		for i in seg:
			var a0 := TAU * i / seg
			var a1 := TAU * (i + 1) / seg
			var p := func(t: float, a: float) -> Vector3: return Vector3(sin(t) * cos(a) * r, 0.26 + cos(t) * r * 0.85, sin(t) * sin(a) * r)
			var q := [p.call(t0, a0), p.call(t0, a1), p.call(t1, a1), p.call(t1, a0)]
			for v in [q[0], q[1], q[2], q[0], q[2], q[3]]:
				st.set_color(Color(0, 1, 0))
				st.set_uv(Vector2(0, (v as Vector3).y / 0.55))
				st.add_vertex(v)
	# feuilles extérieures
	for k in 6:
		var a := TAU * k / 6.0
		var d := Vector3(cos(a), 0, sin(a))
		var sd := Vector3(-sin(a), 0, cos(a)) * 0.2
		var base := d * 0.08 + Vector3.UP * 0.05
		var tip := d * 0.5 + Vector3.UP * 0.32
		for tri in [[base - sd, tip, base + sd], [base + sd, tip, base - sd]]:
			for v in tri:
				st.set_color(Color(0, 0.5, 0))
				st.set_uv(Vector2(0, (v as Vector3).y / 0.55))
				st.add_vertex(v)
	st.generate_normals()
	_cab = st.commit()
	return _cab
