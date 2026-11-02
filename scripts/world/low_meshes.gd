class_name LowMeshes
## Maillages ultra-légers à couleurs de sommets : touffes d'herbe, fleurs, silhouettes d'arbres lointains.

static var _cache := {}
static var _vc := {}

static func vc_material(double_sided: bool) -> StandardMaterial3D:
	if not _vc.has(double_sided):
		var m := StandardMaterial3D.new()
		m.vertex_color_use_as_albedo = true
		m.specular_mode = BaseMaterial3D.SPECULAR_DISABLED
		m.roughness = 1.0
		if double_sided:
			m.cull_mode = BaseMaterial3D.CULL_DISABLED
		_vc[double_sided] = m
	return _vc[double_sided]

static func _tri(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color) -> void:
	var n := (b - a).cross(c - a).normalized()
	if n.y < 0:
		n = -n
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)

static func grass() -> Mesh:
	if _cache.has("g"):
		return _cache["g"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for k in 5:
		var a := TAU * k / 5.0
		var d := Vector3(cos(a), 0, sin(a))
		var side := Vector3(-d.z, 0, d.x) * 0.06
		var base := d * 0.08
		var tip := d * 0.22 + Vector3.UP * (0.42 + 0.08 * (k % 2))
		_tri(st, base - side, base + side, tip, Color(0.30, 0.50, 0.20).lerp(Color(0.52, 0.66, 0.28), 0.5 + 0.1 * k))
	var m := st.commit()
	_cache["g"] = m
	return m

static func flowers() -> Mesh:
	if _cache.has("f"):
		return _cache["f"]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cols := [Color(0.95, 0.85, 0.25), Color(0.85, 0.30, 0.35), Color(0.55, 0.55, 0.95), Color(0.98, 0.98, 0.95)]
	for k in 4:
		var a := TAU * k / 4.0 + 0.4
		var d := Vector3(cos(a), 0, sin(a)) * 0.12
		var top := d + Vector3.UP * 0.32
		_tri(st, d - Vector3(0.015, 0, 0), d + Vector3(0.015, 0, 0), top, Color(0.32, 0.52, 0.22))
		var c: Color = cols[k]
		_tri(st, top + Vector3(-0.06, 0, -0.05), top + Vector3(0.06, 0, -0.05), top + Vector3(0, 0.02, 0.07), c)
	var m := st.commit()
	_cache["f"] = m
	return m

static func _blob(st: SurfaceTool, c: Vector3, r: Vector3, col: Color, seg := 6) -> void:
	var rings := [-1.0, -0.35, 0.45, 1.0]
	var pts := []
	for j in rings.size():
		var y: float = rings[j]
		var rr := sqrt(maxf(0.0, 1.0 - y * y))
		var ring := []
		for i in seg:
			var a := TAU * (i + 0.5 * j) / seg
			ring.append(c + Vector3(cos(a) * rr * r.x, y * r.y, sin(a) * rr * r.z))
		pts.append(ring)
	for j in rings.size() - 1:
		for i in seg:
			var a: Vector3 = pts[j][i]
			var b: Vector3 = pts[j][(i + 1) % seg]
			var cc: Vector3 = pts[j + 1][(i + 1) % seg]
			var d: Vector3 = pts[j + 1][i]
			var shade := col.darkened(0.12 * (1.0 - float(j) / rings.size()))
			_tri_out(st, a, b, cc, shade, c)
			_tri_out(st, a, cc, d, shade, c)

static func _tri_out(st: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, col: Color, center: Vector3) -> void:
	var n := (b - a).cross(c - a).normalized()
	var out := ((a + b + c) / 3.0 - center).normalized()
	if n.dot(out) < 0:
		n = -n
		var t := b
		b = c
		c = t
	for p in [a, c, b]:
		st.set_color(col)
		st.set_normal(n)
		st.add_vertex(p)

static func _trunk(st: SurfaceTool, h: float, r: float, col: Color) -> void:
	for i in 4:
		var a0 := TAU * i / 4.0
		var a1 := TAU * (i + 1) / 4.0
		var p0 := Vector3(cos(a0) * r, 0, sin(a0) * r)
		var p1 := Vector3(cos(a1) * r, 0, sin(a1) * r)
		var q0 := p0 * 0.6 + Vector3.UP * h
		var q1 := p1 * 0.6 + Vector3.UP * h
		_tri_out(st, p0, p1, q1, col, Vector3(0, h * 0.5, 0))
		_tri_out(st, p0, q1, q0, col, Vector3(0, h * 0.5, 0))

## Silhouette d'arbre lointain (dimensions de l'arbre Avramania à l'échelle 1)
static func tree_proxy(kind: String) -> Mesh:
	if _cache.has(kind):
		return _cache[kind]
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	match kind:
		"pine":
			_trunk(st, 1.6, 0.22, Color(0.40, 0.28, 0.18))
			for t in 3:
				var y0 := 1.2 + t * 1.8
				var r := 1.8 - t * 0.45
				var apex := Vector3(0, y0 + 2.6, 0)
				for i in 6:
					var a0 := TAU * i / 6.0
					var a1 := TAU * (i + 1) / 6.0
					_tri_out(st, Vector3(cos(a0) * r, y0, sin(a0) * r), Vector3(cos(a1) * r, y0, sin(a1) * r), apex, Color(0.20, 0.42, 0.34).lightened(0.05 * t), Vector3(0, y0 + 0.8, 0))
		"birch":
			_trunk(st, 3.2, 0.14, Color(0.90, 0.88, 0.82))
			_blob(st, Vector3(0, 3.6, 0), Vector3(1.3, 1.2, 1.3), Color(0.66, 0.78, 0.40))
		_:
			_trunk(st, 2.2, 0.32, Color(0.45, 0.32, 0.22))
			_blob(st, Vector3(0.2, 3.2, 0.0), Vector3(1.5, 1.0, 1.4), Color(0.34, 0.56, 0.26))
			_blob(st, Vector3(-0.5, 2.8, 0.6), Vector3(1.0, 0.8, 1.0), Color(0.38, 0.60, 0.28))
	var m := st.commit()
	_cache[kind] = m
	return m
