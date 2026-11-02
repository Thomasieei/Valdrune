class_name Layout
## PLAN DU ROYAUME — source unique de vérité pour le relief, les routes, l'eau et les zones.
## Repère : x = est, z = sud (le nord est vers -z). 1 unité = 1 mètre.
##
##                         N (montagnes)
##        forêt profonde        CHÂTEAU (plateau)        collines + MINE
##             (ouest)            | bourg                    (nord-est)
##      rivière ~~~~~~~~~~~~~~~~~ + ~~~~~~ champs (est)
##             clairières         |pont      ~~~~ LAC (sud-est)
##                                 \
##                               PORTAIL (sud)  → royaume des nains

const HALF := 320.0          # carte de 640 m x 640 m
const WATER := 0.0           # niveau de l'eau

# --- Lieux clés ---
const CASTLE := Vector2(0, -130)       # centre de l'enceinte
const CASTLE_HALF := Vector2(52, 42)   # demi-taille de l'enceinte (104 m x 84 m)
const PLATEAU_H := 12.0
const GATE := Vector2(0, -88)          # porte principale (face au sud)
const TOWN := Vector2(0, -20)          # place du bourg
const FARM := Vector2(95, -5)          # ferme
const FIELDS_MIN := Vector2(55, -55)
const FIELDS_MAX := Vector2(165, 45)
const MINE := Vector2(175, -175)       # entrée de mine
const LUMBER := Vector2(-120, -10)     # camp de bûcherons
const PORTAL := Vector2(35, 235)
const PORTAL_H := 8.0       # portail vers le royaume nain
const LAKE := Vector2(175, 165)
const LAKE_R := 48.0

const RIVER := [Vector2(-300, -190), Vector2(-215, -150), Vector2(-160, -70), Vector2(-95, 0),
	Vector2(-40, 45), Vector2(25, 62), Vector2(85, 85), Vector2(130, 125), Vector2(160, 150)]
const RIVER_W := 7.0   # demi-largeur du lit

# Routes : chaque route = polyligne + demi-largeur
const ROADS := [
	{"pts": [Vector2(0, -92), Vector2(0, -70), Vector2(0, -48), Vector2(2, -30), Vector2(0, -12), Vector2(6, 20), Vector2(18, 48), Vector2(24, 62), Vector2(28, 80), Vector2(26, 120), Vector2(32, 170), Vector2(35, 222)], "w": 3.6, "pave": true},
	{"pts": [Vector2(4, -18), Vector2(30, -14), Vector2(55, -8), Vector2(80, -6), Vector2(95, -5)], "w": 2.6, "pave": false},
	{"pts": [Vector2(-4, -22), Vector2(-30, -20), Vector2(-60, -14), Vector2(-90, -10), Vector2(-120, -10)], "w": 2.6, "pave": false},
	{"pts": [Vector2(58, -120), Vector2(90, -128), Vector2(125, -140), Vector2(155, -160), Vector2(172, -170)], "w": 2.6, "pave": false},
	{"pts": [Vector2(0, -92), Vector2(30, -92), Vector2(55, -100), Vector2(58, -120)], "w": 2.6, "pave": false},
	{"pts": [Vector2(30, 120), Vector2(80, 135), Vector2(125, 150), Vector2(140, 158)], "w": 2.4, "pave": false},
]

static var _noise: FastNoiseLite
static var _noise2: FastNoiseLite

static func _n() -> FastNoiseLite:
	if _noise == null:
		_noise = FastNoiseLite.new()
		_noise.seed = 1234
		_noise.frequency = 0.006
		_noise.fractal_octaves = 4
		_noise2 = FastNoiseLite.new()
		_noise2.seed = 99
		_noise2.frequency = 0.035
	return _noise

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var t := clampf((p - a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	return p.distance_to(a + ab * t)

static func poly_dist(p: Vector2, pts: Array) -> float:
	var d := INF
	for i in pts.size() - 1:
		d = minf(d, seg_dist(p, pts[i], pts[i + 1]))
	return d

static func river_dist(p: Vector2) -> float:
	var n := _n()
	# méandres et largeur variable : la rive n'est jamais une ligne droite
	var d := poly_dist(p, RIVER) + n.get_noise_2d(p.x * 3.0 + 50.0, p.y * 3.0) * 4.0
	return minf(d, lake_dist(p) + RIVER_W)

## Distance au bord du lac (<0 = dans le lac), rive irrégulière
static func lake_dist(p: Vector2) -> float:
	var v := p - LAKE
	var ang := atan2(v.y, v.x)
	var r := LAKE_R * (1.0 + 0.18 * sin(ang * 3.0 + 1.0) + 0.1 * sin(ang * 5.0 + 2.0))
	return v.length() - r

## Distance à la route la plus proche, moins sa demi-largeur (<0 = sur la route)
static func road_dist(p: Vector2) -> float:
	var d := INF
	for r in ROADS:
		d = minf(d, poly_dist(p, r["pts"]) - r["w"])
	return d

static func paved_dist(p: Vector2) -> float:
	var r = ROADS[0]
	var d: float = poly_dist(p, r["pts"]) - r["w"]
	# place du bourg pavée
	d = minf(d, p.distance_to(TOWN) - 14.0)
	return d

static func in_castle(p: Vector2, margin := 0.0) -> bool:
	var q := (p - CASTLE).abs()
	return q.x < CASTLE_HALF.x + margin and q.y < CASTLE_HALF.y + margin

static func in_fields(p: Vector2, margin := 0.0) -> bool:
	return p.x > FIELDS_MIN.x - margin and p.x < FIELDS_MAX.x + margin and p.y > FIELDS_MIN.y - margin and p.y < FIELDS_MAX.y + margin

static func _smooth(e0: float, e1: float, x: float) -> float:
	return smoothstep(e0, e1, x)

## Relief : collines douces + plateau du château + montagnes en bordure + lit de rivière et lac.
static func height(x: float, z: float) -> float:
	var p := Vector2(x, z)
	var n := _n()
	var h := 3.0 + n.get_noise_2d(x, z) * 5.0 + _noise2.get_noise_2d(x, z) * 0.35
	# collines nommées
	h += 22.0 * exp(-p.distance_squared_to(Vector2(165, -150)) / (2.0 * 70.0 * 70.0))
	h += 10.0 * exp(-p.distance_squared_to(Vector2(-150, 160)) / (2.0 * 55.0 * 55.0))
	h += 7.0 * exp(-p.distance_squared_to(Vector2(-60, -150)) / (2.0 * 40.0 * 40.0))
	h += 5.0 * exp(-p.distance_squared_to(PORTAL) / (2.0 * 30.0 * 30.0))
	# champs : plaine adoucie
	var fk := 1.0 - _smooth(0.0, 25.0, _box_dist(p, FIELDS_MIN, FIELDS_MAX))
	h = lerpf(h, 3.2 + n.get_noise_2d(x, z) * 1.0, fk)
	# bourg : terrain plat
	var tk := 1.0 - _smooth(18.0, 45.0, p.distance_to(TOWN))
	h = lerpf(h, 3.0, tk)
	# plateau du château avec rampe au sud
	var cd := _box_dist(p, CASTLE - CASTLE_HALF - Vector2(8, 8), CASTLE + CASTLE_HALF + Vector2(8, 8))
	h = lerpf(h, PLATEAU_H, 1.0 - _smooth(0.0, 24.0, cd))
	# rampe d'accès (pente douce ~20 %) de la porte jusqu'au bourg
	if p.y > GATE.y - 2.0 and p.y < GATE.y + 56.0:
		var ramp_t := clampf((p.y - (GATE.y + 6.0)) / 46.0, 0.0, 1.0)
		var ramp_h := lerpf(PLATEAU_H, 3.0, ramp_t * ramp_t * (3.0 - 2.0 * ramp_t))
		var on_ramp := 1.0 - _smooth(5.0, 13.0, absf(p.x - GATE.x))
		on_ramp *= 1.0 - _smooth(50.0, 56.0, p.y - GATE.y)
		h = lerpf(h, ramp_h, on_ramp)
	# montagnes en bordure
	var edge := maxf(absf(x), absf(z)) + n.get_noise_2d(x * 1.7, z * 1.7) * 25.0
	h += pow(_smooth(235.0, 320.0, edge), 1.4) * (55.0 + 25.0 * n.get_noise_2d(x * 3.0, z * 3.0))
	# rivière et lac
	var rd := river_dist(p)
	var bed := -2.2
	var bank := _smooth(RIVER_W * 0.6, RIVER_W + 9.0, rd)
	h = lerpf(minf(h, bed), h, bank)
	var ld := lake_dist(p)
	h = lerpf(-3.5, h, _smooth(-LAKE_R * 0.25, 14.0, ld))
	# routes : légèrement aplanies (pas de bosses absurdes)
	var rdist := road_dist(p)
	if rdist < 4.0 and rd > RIVER_W + 1.0:
		var s := _smooth(-2.0, 4.0, rdist)
		var flat := 3.0 + n.get_noise_2d(x, z) * 3.5
		if cd < 2.0 or (p.y > GATE.y - 2 and p.y < GATE.y + 50 and absf(p.x) < 6):
			flat = h
		h = lerpf(lerpf(h, flat, 0.35), h, s)
	# léger creux sous la route pavée pour que le pavage ne soit jamais recouvert par l'herbe
	var pv := paved_dist(p)
	if pv < 1.5:
		h -= 0.12 * (1.0 - smoothstep(-1.0, 1.5, pv))
	# esplanade du portail : plate et franchissable (après routes et pavés)
	h = lerpf(h, PORTAL_H, 1.0 - _smooth(13.0, 24.0, p.distance_to(PORTAL)))
	# cachots creusés sous la cour du château (recouverts par leur voûte)
	if Justice.dug(p):
		h = PLATEAU_H - 5.0
	return h

static func _box_dist(p: Vector2, mn: Vector2, mx: Vector2) -> float:
	var c := (mn + mx) * 0.5
	var e := (mx - mn) * 0.5
	var q := (p - c).abs() - e
	return Vector2(maxf(q.x, 0), maxf(q.y, 0)).length() + minf(maxf(q.x, q.y), 0.0)

static func normal(x: float, z: float) -> Vector3:
	var e := 0.8
	var hx := height(x + e, z) - height(x - e, z)
	var hz := height(x, z + e) - height(x, z - e)
	return Vector3(-hx, 2.0 * e, -hz).normalized()

## Zones où l'on ne pose PAS de décor (routes, eau, bâtiments, champs, place, portail)
static func reserved(p: Vector2, margin := 0.0) -> bool:
	if road_dist(p) < 2.5 + margin:
		return true
	if river_dist(p) < RIVER_W + 3.0 + margin:
		return true
	if in_castle(p, 18.0 + margin):
		return true
	if absf(p.x - GATE.x) < 14.0 and p.y > GATE.y and p.y < GATE.y + 55.0:
		return true
	if p.distance_to(TOWN) < 20.0 + margin:
		return true
	for z in Spawner.ZONES:
		if p.distance_to(z["pos"]) < float(z["r"]) + 6.0 + margin:
			return true
	if in_fields(p, 6.0 + margin):
		return true
	if p.distance_to(PORTAL) < 28.0 + margin:
		return true
	if p.distance_to(MINE) < 22.0 + margin:
		return true
	if p.distance_to(LUMBER) < 16.0 + margin:
		return true
	for h in Town.houses:
		if (h[0] as Vector2).distance_to(p) < (h[1] as float) + 1.0 + margin:
			return true
	return false

## Abscisse de la polyligne à une profondeur z donnée (routes nord-sud)
static func poly_point_x(pts: Array, z: float) -> float:
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]
		var b: Vector2 = pts[i + 1]
		if (z - a.y) * (z - b.y) <= 0.0 and a.y != b.y:
			return lerpf(a.x, b.x, (z - a.y) / (b.y - a.y))
	return pts[0].x
