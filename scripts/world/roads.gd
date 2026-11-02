class_name Roads
## Route royale pavée (ruban texturé qui épouse le relief), place du bourg, et ponts sur la rivière.

static func build(parent: Node3D) -> void:
	var g = Geo.new()
	var main: Dictionary = Layout.ROADS[0]
	_ribbon(g, main["pts"], main["w"], "paves")
	_disc(g, Layout.TOWN, 14.0, "paves")
	g.commit(parent, "RoutesPavees", 1, false)
	var gb = Geo.new()
	for r in Layout.ROADS:
		_bridges(gb, r["pts"], r["w"])
	gb.commit(parent, "Ponts", 2)

static func _skip(p: Vector2) -> bool:
	return Layout.poly_dist(p, Layout.RIVER) < Layout.RIVER_W + 6.0 or Layout.in_castle(p, -1.0) or absf(p.y - Layout.GATE.y) < 6.0 and absf(p.x) < 8.0

static func _ribbon(g: Geo, pts: Array, w: float, m: String) -> void:
	var samples = []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n = int(ceil(a.distance_to(b) / 2.0))
		for k in n:
			samples.append(a.lerp(b, float(k) / n))
	samples.append(pts[-1])
	for i in samples.size() - 1:
		var a: Vector2 = samples[i]
		var b: Vector2 = samples[i + 1]
		if _skip(a) or _skip(b):
			continue
		var da = ((samples[mini(i + 1, samples.size() - 1)] as Vector2) - (samples[maxi(i - 1, 0)] as Vector2)).normalized()
		var db = ((samples[mini(i + 2, samples.size() - 1)] as Vector2) - (samples[i] as Vector2)).normalized()
		var na = Vector2(-da.y, da.x) * w
		var nb = Vector2(-db.y, db.x) * w
		var cols = 4
		for k in cols:
			var t0 = -1.0 + 2.0 * k / cols
			var t1 = -1.0 + 2.0 * (k + 1) / cols
			g.quad(m, _p3(a + na * t0), _p3(a + na * t1), _p3(b + nb * t1), _p3(b + nb * t0), 1)

static func _p3(p: Vector2) -> Vector3:
	return Vector3(p.x, Terrain.height_at(p.x, p.y) + 0.1, p.y)

static func _disc(g: Geo, c: Vector2, r: float, m: String) -> void:
	var rings = 6
	var seg = 28
	for j in rings:
		var r0 = r * j / rings
		var r1 = r * (j + 1) / rings
		for i in seg:
			var a0 = TAU * i / seg
			var a1 = TAU * (i + 1) / seg
			var p00 = c + Vector2(cos(a0), sin(a0)) * r0
			var p01 = c + Vector2(cos(a1), sin(a1)) * r0
			var p10 = c + Vector2(cos(a0), sin(a0)) * r1
			var p11 = c + Vector2(cos(a1), sin(a1)) * r1
			g.quad(m, _p3(p00), _p3(p01), _p3(p11), _p3(p10), 1)

## Détecte les traversées de rivière et construit un pont en bois sur piles de pierre.
static func _bridges(g: Geo, pts: Array, w: float) -> void:
	var samples = []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		var n = int(ceil(a.distance_to(b)))
		for k in n:
			samples.append(a.lerp(b, float(k) / n))
	var run = []
	var runs = []
	for p in samples:
		if Layout.poly_dist(p, Layout.RIVER) < Layout.RIVER_W + 7.0:
			run.append(p)
		elif run.size() > 0:
			runs.append(run)
			run = []
	if run.size() > 0:
		runs.append(run)
	for r in runs:
		if r.size() < 4:
			continue
		var a: Vector2 = r[0]
		var b: Vector2 = r[-1]
		var dir = (b - a).normalized()
		a -= dir * 2.0
		b += dir * 2.0
		_bridge(g, a, b, w + 0.6)

static func _bridge(g: Geo, a: Vector2, b: Vector2, hw: float) -> void:
	var h0 = Layout.height(a.x, a.y)
	var h1 = Layout.height(b.x, b.y)
	var len = a.distance_to(b)
	var mid = (h0 + h1) * 0.5
	var arch = maxf(0.0, 2.4 - mid) + 0.8
	var n = int(ceil(len / 1.6))
	var dir3 = Vector3(b.x - a.x, 0, b.y - a.y).normalized()
	var yaw = atan2(dir3.x, dir3.z)
	var side = Vector3(dir3.z, 0, -dir3.x)
	var prev = Vector3(a.x, h0 + 0.05, a.y)
	for i in n:
		var t1 = float(i + 1) / n
		var p2 = a.lerp(b, t1)
		var y = lerpf(h0, h1, t1) + arch * sin(PI * t1) + 0.05
		var cur = Vector3(p2.x, y, p2.y)
		var seg = cur - prev
		var c = (prev + cur) * 0.5
		var basis = Basis.looking_at(seg.normalized(), Vector3.UP)
		g.obox("bois", Transform3D(basis, c - Vector3.UP * 0.18), Vector3(hw * 2.0, 0.36, seg.length() + 0.05), true)
		# garde-corps : poteaux + main courante
		for s in [-1.0, 1.0]:
			var post: Vector3 = c + side * s * (hw - 0.15)
			g.box("bois_sombre", post + Vector3.UP * 0.55, Vector3(0.22, 1.1, 0.22), yaw, i % 2 == 0)
			g.obox("bois_sombre", Transform3D(basis, post + Vector3.UP * 1.05), Vector3(0.16, 0.14, seg.length() + 0.05), false)
		prev = cur
	# piles de pierre dans l'eau
	for t in [0.33, 0.66]:
		var p = a.lerp(b, t)
		var y = lerpf(h0, h1, t) + arch * sin(PI * t) - 0.4
		var base = Layout.height(p.x, p.y) - 0.5
		g.box("pierre_base", Vector3(p.x, (base + y) * 0.5, p.y), Vector3(hw * 2.0 - 0.4, y - base, 1.6), yaw, true)
