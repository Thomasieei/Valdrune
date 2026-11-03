class_name Roads
## Route royale pavée (ruban texturé qui épouse le relief), place du bourg, et ponts sur la rivière.

static func build(parent: Node3D) -> void:
	var g = Geo.new()
	var main: Dictionary = Layout.ROADS[0]
	_ribbon(g, main["pts"], main["w"], "paves")
	_disc(g, Layout.TOWN, 14.0, "paves")
	g.commit(parent, "RoutesPavees", 1, false)
	bridges.clear()
	var gb = Geo.new()
	_lamps = Node3D.new()
	_lamps.name = "LieuxDecorPonts"
	for r in Layout.ROADS:
		_bridges(gb, r["pts"], r["w"])
	var ponts: Node3D = gb.commit(parent, "Ponts", 2)
	ponts.add_child(_lamps)

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
## Ponts construits (extrémités a, b) : la garde y tient des postes
static var bridges: Array = []
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
		bridges.append([a, b])
		_bridge(g, a, b, w + 0.6)

## Pont de pierre en dos d'âne : arches en plein cintre sur piles à avant-becs, tablier pavé,
## parapets à chaperon, bornes et lanternes aux deux têtes.
static func _bridge(g: Geo, a: Vector2, b: Vector2, hw: float) -> void:
	var h0 := Layout.height(a.x, a.y)
	var h1 := Layout.height(b.x, b.y)
	var len := a.distance_to(b)
	var arch := maxf(0.0, 2.6 - (h0 + h1) * 0.5) + 1.7
	var dir2 := (b - a) / len
	var yaw := atan2(dir2.x, dir2.y)
	var side := Vector3(dir2.y, 0, -dir2.x)
	var deck := func(t: float) -> float: return lerpf(h0, h1, t) + arch * sin(PI * t) + 0.05
	var water := Layout.WATER - 0.6
	# arches : 3 travées entre culées, piles aux tiers
	var piers := [0.0, 0.34, 0.66, 1.0]
	var n := int(ceil(len / 0.5))
	for i in n:
		var t0 := float(i) / n
		var t1 := float(i + 1) / n
		var tm := (t0 + t1) * 0.5
		var p := a.lerp(b, tm)
		var y0: float = deck.call(t0)
		var y1: float = deck.call(t1)
		var ym := (y0 + y1) * 0.5
		var seg := Vector3((b.x - a.x) * (t1 - t0), y1 - y0, (b.y - a.y) * (t1 - t0))
		var bas := Basis.looking_at(seg.normalized(), Vector3.UP)
		# chaussée pavée
		g.obox("paves", Transform3D(bas, Vector3(p.x, ym - 0.12, p.y)), Vector3(hw * 2.0 - 0.7, 0.24, seg.length() + 0.04), true)
		# parapets (0,9 m) et chaperon
		for sd in [-1.0, 1.0]:
			var q: Vector3 = Vector3(p.x, ym, p.y) + side * sd * (hw - 0.22)
			g.obox("pierre_base", Transform3D(bas, q + Vector3.UP * 0.35), Vector3(0.44, 1.0, seg.length() + 0.04), true)
			g.obox("pierre_claire", Transform3D(bas, q + Vector3.UP * 0.9), Vector3(0.56, 0.12, seg.length() + 0.06), false)
		# tympans : maçonnerie pleine du tablier jusqu'à l'intrados de l'arche
		var span := 0
		for k in piers.size() - 1:
			if tm >= float(piers[k]) and tm <= float(piers[k + 1]):
				span = k
		var u: float = (tm - float(piers[span])) / (float(piers[span + 1]) - float(piers[span]))
		var spring := water + 0.7
		var top_arch: float = spring + (ym - 0.9 - spring) * sin(PI * u)
		var bot := minf(top_arch, ym - 0.4)
		if ym - 0.25 - bot > 0.05:
			g.box("pierre_base", Vector3(p.x, (ym - 0.25 + bot) * 0.5, p.y), Vector3(hw * 2.0, ym - 0.25 - bot, (t1 - t0) * len + 0.03), yaw, false)
		# voussoirs : bandeau plus clair qui souligne l'arche
		for sd in [-1.0, 1.0]:
			var q2: Vector3 = Vector3(p.x, bot - 0.12, p.y) + side * sd * (hw + 0.02)
			g.box("pierre_claire", q2, Vector3(0.12, 0.3, (t1 - t0) * len + 0.04), yaw, false)
	# piles avec avant-becs (côté amont et aval)
	for t in [0.34, 0.66]:
		var p: Vector2 = a.lerp(b, t)
		var top: float = deck.call(t) - 0.3
		var base := Layout.height(p.x, p.y) - 1.0
		g.box("pierre_base", Vector3(p.x, (base + top) * 0.5, p.y), Vector3(hw * 2.0, top - base, 1.3), yaw, true)
		for sd in [-1.0, 1.0]:
			var c: Vector3 = Vector3(p.x, 0, p.y) + side * sd * (hw + 0.35)
			g.obox("pierre_base", Transform3D(Basis(Vector3.UP, yaw + PI / 4.0), Vector3(c.x, (base + water + 1.4) * 0.5, c.z)), Vector3(0.92, water + 1.4 - base, 0.92), false)
	# culées : bornes de pierre aux quatre angles
	for t in [0.0, 1.0]:
		var p: Vector2 = a.lerp(b, t)
		var y: float = deck.call(t)
		for sd in [-1.0, 1.0]:
			var q: Vector3 = Vector3(p.x, y, p.y) + side * sd * (hw - 0.22)
			g.box("pierre_base", q + Vector3.UP * 0.6, Vector3(0.6, 1.3, 0.6), yaw, true)
			g.box("pierre_claire", q + Vector3.UP * 1.3, Vector3(0.72, 0.14, 0.72), yaw, false)
		var gp := Vector3(p.x, y, p.y)
		var lamp := Kit.village(g_root(), "Prop_Lamp_Street", gp + side * (hw - 0.22) + Vector3.UP * 1.35, yaw, 0.9)
		lamp.name = "LanternePont"

static var _lamps: Node3D
static func g_root() -> Node3D:
	return _lamps
