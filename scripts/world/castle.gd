class_name Castle
## LE CHÂTEAU — enceinte (104 x 84 m), 4 tours d'angle, 3 tours carrées, châtelet à deux tours,
## cour intérieure, et donjon (42 x 34 m) dont l'intérieur se visite :
## grande salle du trône (18 x 31 m, 11 m sous plafond), salle du conseil, bibliothèque,
## armurerie et trésorerie (10 x 15 m chacune, 7 m sous plafond).

const Y0 := Layout.PLATEAU_H          # sol de la cour
const FLOOR := Layout.PLATEAU_H + 1.0 # sol du donjon (socle de 1 m)
const C := Layout.CASTLE
const H := Layout.CASTLE_HALF
const WALL_T := 3.0
const WALL_H := 13.0

# Donjon
const K_MIN := Vector2(-21, -162)
const K_MAX := Vector2(21, -128)
const KT := 1.5          # épaisseur des murs extérieurs du donjon
const HALL_X := 9.0      # la salle du trône occupe x ∈ [-9, 9]
const HALL_CEIL := 11.0
const WING_CEIL := 7.0
const WING_SPLIT_Z := -145.0

static var interior_lights: Array = []
static var guards: Array = []

static func build(parent: Node3D) -> void:
	interior_lights.clear()
	guards.clear()
	var g = Geo.new()
	_enceinte(g)
	_chatelet(g)
	_donjon_exterieur(g)
	_cour(g, parent)
	g.commit(parent, "Chateau")
	var gi = Geo.new()
	_donjon_interieur(gi)
	gi.commit(parent, "DonjonInterieur", 2, false)
	_mobilier(parent)
	_gardes(parent)
	_zone_interieure(parent)

# ------------------------------------------------------------------ ENCEINTE
static func _enceinte(g: Geo) -> void:
	var x0 = C.x - H.x
	var x1 = C.x + H.x
	var z0 = C.y - H.y
	var z1 = C.y + H.y
	var y = Y0 - 1.0  # fondations légèrement enterrées
	var h = WALL_H + 1.0
	# murs : nord, est, ouest, sud (deux tronçons autour du châtelet)
	var segs = [
		[Vector3(x0, y, z0), Vector3(x1, y, z0), Vector3(0, 0, -1)],
		[Vector3(x1, y, z0), Vector3(x1, y, z1), Vector3(1, 0, 0)],
		[Vector3(x0, y, z1), Vector3(x0, y, z0), Vector3(-1, 0, 0)],
		[Vector3(x0, y, z1), Vector3(-15, y, z1), Vector3(0, 0, 1)],
		[Vector3(15, y, z1), Vector3(x1, y, z1), Vector3(0, 0, 1)],
	]
	for s in segs:
		var a: Vector3 = s[0]
		var b: Vector3 = s[1]
		var out: Vector3 = s[2]
		g.wall("pierre", a, b, WALL_T, h)
		# soubassement plus large
		g.wall("pierre_base", a + out * 0.4, b + out * 0.4, WALL_T + 0.6, 2.6, false)
		# chemin de ronde (dalles claires) + créneaux côté extérieur
		var top = Y0 + WALL_H
		g.wall("pierre_claire", Vector3(a.x, top - 0.4, a.z) + out * 0.1, Vector3(b.x, top - 0.4, b.z) + out * 0.1, WALL_T + 0.5, 0.6, false)
		var ea = Vector3(a.x, top + 0.2, a.z) + out * (WALL_T * 0.5 - 0.15)
		var eb = Vector3(b.x, top + 0.2, b.z) + out * (WALL_T * 0.5 - 0.15)
		g.crenels("pierre_claire", ea, eb, 0.8)
		# parapet bas côté cour
		var ia = Vector3(a.x, top + 0.2, a.z) - out * (WALL_T * 0.5 - 0.2)
		var ib = Vector3(b.x, top + 0.2, b.z) - out * (WALL_T * 0.5 - 0.2)
		g.wall("pierre_claire", ia, ib, 0.5, 0.7, false)
	# tours d'angle rondes
	for cx in [x0, x1]:
		for cz in [z0, z1]:
			_tour_ronde(g, Vector3(cx, 0, cz), 7.5, Y0 + 23.0)
	# tours carrées au milieu des côtés est / ouest / nord
	for p in [Vector3(x0, 0, C.y), Vector3(x1, 0, C.y), Vector3(C.x, 0, z0)]:
		_tour_carree(g, p, 10.0, Y0 + 19.0)

static func _tour_ronde(g: Geo, c: Vector3, r: float, top: float) -> void:
	g.cylinder("pierre_base", c, r + 0.5, Y0 - 1.0, Y0 + 2.5, 20, false, false)
	g.cylinder("pierre", c, r, Y0 - 1.0, top, 20, true, true, "pierre_claire")
	g.cylinder("pierre_claire", c, r + 0.6, top - 0.6, top, 20, false, true)
	g.ring_crenels("pierre_claire", c, r + 0.25, top, 14)
	# toit conique en ardoise posé sur un tambour
	g.cylinder("pierre", c, r - 1.2, top, top + 2.2, 20, false, false)
	g.cone("ardoise", c + Vector3(0, 0, 0), r - 0.2, top + 2.2, r * 1.5)
	# meurtrières
	for i in 4:
		var a = TAU * i / 4.0 + PI / 4.0
		var p = c + Vector3(cos(a) * (r + 0.05), 0, sin(a) * (r + 0.05))
		g.box("fenetre_sombre", Vector3(p.x, Y0 + 9.0, p.z), Vector3(0.5, 2.2, 0.3), -a + PI / 2.0, false)
		g.box("fenetre_sombre", Vector3(p.x, Y0 + 14.0, p.z), Vector3(0.5, 2.2, 0.3), -a + PI / 2.0, false)

static func _tour_carree(g: Geo, c: Vector3, s: float, top: float) -> void:
	g.box("pierre", Vector3(c.x, (Y0 - 1.0 + top) * 0.5, c.z), Vector3(s, top - Y0 + 1.0, s))
	g.box("pierre_claire", Vector3(c.x, top - 0.3, c.z), Vector3(s + 1.0, 0.6, s + 1.0), 0.0, false)
	for side in 4:
		var rot = side * PI / 2.0
		var b = Basis(Vector3.UP, rot)
		var a = c + b * Vector3(-s * 0.5, 0, s * 0.5 + 0.2)
		var e = c + b * Vector3(s * 0.5, 0, s * 0.5 + 0.2)
		g.crenels("pierre_claire", Vector3(a.x, top, a.z), Vector3(e.x, top, e.z), 0.8, 2.2)
		var w = c + b * Vector3(0, 0, s * 0.5 + 0.05)
		g.box("fenetre_sombre", Vector3(w.x, Y0 + 10.0, w.z), Vector3(0.8, 2.4, 0.2), rot, false)
	g.hip_roof("ardoise", Vector3(c.x, top + 1.4, c.z), s * 0.5 - 0.6, s * 0.5 - 0.6, 6.5)
	g.box("pierre", Vector3(c.x, top + 0.7, c.z), Vector3(s - 1.6, 1.4, s - 1.6), 0.0, false)

# ------------------------------------------------------------------ CHÂTELET (porte)
static func _chatelet(g: Geo) -> void:
	var z = C.y + H.y   # -88
	var top = Y0 + 17.0
	# deux massifs latéraux et le linteau au-dessus du passage (6 m x 7 m)
	g.box("pierre", Vector3(-6.0, (Y0 - 1 + top) * 0.5, z), Vector3(6.0, top - Y0 + 1, 11.0))
	g.box("pierre", Vector3(6.0, (Y0 - 1 + top) * 0.5, z), Vector3(6.0, top - Y0 + 1, 11.0))
	g.box("pierre", Vector3(0, (Y0 + 7.2 + top) * 0.5, z), Vector3(6.2, top - Y0 - 7.2, 11.0))
	# encadrement du passage : piédroits et linteau en pierre claire, herse relevée
	for face in [-1.0, 1.0]:
		var zf = z + face * 5.55
		for sx in [-1.0, 1.0]:
			g.box("pierre_claire", Vector3(sx * 3.35, Y0 + 3.6, zf), Vector3(0.7, 7.2, 0.3), 0.0, false)
		g.box("pierre_claire", Vector3(0, Y0 + 7.55, zf), Vector3(7.4, 0.8, 0.35), 0.0, false)
		g.box("pierre_claire", Vector3(0, Y0 + 8.15, zf), Vector3(2.0, 0.5, 0.4), 0.0, false)
	# sol pavé du passage
	g.box("paves", Vector3(0, Y0 - 0.45, z), Vector3(6.0, 1.0, 11.0), 0.0, false)
	# couronnement
	g.box("pierre_claire", Vector3(0, top - 0.3, z), Vector3(19.0, 0.6, 12.0), 0.0, false)
	for face in [-1.0, 1.0]:
		var zf: float = z + face * 5.7
		g.crenels("pierre_claire", Vector3(-9, top, zf), Vector3(9, top, zf), 0.8, 2.2)
	g.box("pierre_claire", Vector3(0, top, z), Vector3(18.0, 0.1, 10.0), 0.0, true)  # sol praticable au sommet
	# deux tours rondes encadrant la porte
	for sx in [-1.0, 1.0]:
		_tour_ronde(g, Vector3(sx * 11.0, 0, z + 1.5), 5.5, Y0 + 22.0)
	# écu royal au-dessus de l'arc
	g.box("bleu_royal", Vector3(0, Y0 + 10.0, z + 5.6), Vector3(2.2, 2.6, 0.2), 0.0, false)
	g.box("or", Vector3(0, Y0 + 10.0, z + 5.72), Vector3(1.0, 1.4, 0.1), 0.0, false)

# ------------------------------------------------------------------ DONJON (extérieur)
static func _donjon_exterieur(g: Geo) -> void:
	var y0 = Y0 - 0.5
	var top = FLOOR + 19.0      # 32 m
	var cx = (K_MIN.x + K_MAX.x) * 0.5
	var cz = (K_MIN.y + K_MAX.y) * 0.5
	var hx = (K_MAX.x - K_MIN.x) * 0.5
	var hz = (K_MAX.y - K_MIN.y) * 0.5
	# socle
	g.box("pierre_base", Vector3(cx, (y0 + FLOOR) * 0.5, cz), Vector3(hx * 2 + 1.2, FLOOR - y0, hz * 2 + 1.2), 0.0, true, "dallage")
	# murs extérieurs avec ouvertures (porte principale au sud)
	var A = Vector3(K_MIN.x, FLOOR, K_MIN.y)
	var B = Vector3(K_MAX.x, FLOOR, K_MIN.y)
	var Cc = Vector3(K_MAX.x, FLOOR, K_MAX.y)
	var D = Vector3(K_MIN.x, FLOOR, K_MAX.y)
	var wh = top - FLOOR
	_wall_open(g, "pierre", A + Vector3(0, 0, KT * 0.5), B + Vector3(0, 0, KT * 0.5), KT, wh, [[21.0, 4.0, 4.5, 9.5, "vitre"]])  # nord : grand vitrail
	_wall_open(g, "pierre", D - Vector3(0, 0, KT * 0.5), Cc - Vector3(0, 0, KT * 0.5), KT, wh, [[21.0, 5.0, 0.0, 6.5, ""]])   # sud : grande porte
	_wall_open(g, "pierre", A + Vector3(KT * 0.5, 0, 0), D + Vector3(KT * 0.5, 0, 0), KT, wh, [])
	_wall_open(g, "pierre", B - Vector3(KT * 0.5, 0, 0), Cc - Vector3(KT * 0.5, 0, 0), KT, wh, [])
	# fenêtres de façade (sombres vues de dehors) : deux étages
	for i in 6:
		var x = K_MIN.x + 4.0 + i * 6.8
		if absf(x) < 4.0:
			continue
		for yy in [FLOOR + 3.5, FLOOR + 12.5]:
			g.box("fenetre_sombre", Vector3(x, yy, K_MAX.y + 0.02), Vector3(1.4, 2.8, 0.1), 0.0, false)
			g.box("pierre_claire", Vector3(x, yy + 1.6, K_MAX.y + 0.1), Vector3(1.9, 0.35, 0.3), 0.0, false)
			g.box("fenetre_sombre", Vector3(x, yy, K_MIN.y - 0.02), Vector3(1.4, 2.8, 0.1), 0.0, false)
	for j in 5:
		var z = K_MIN.y + 4.0 + j * 6.5
		for yy in [FLOOR + 3.5, FLOOR + 12.5]:
			for sx in [K_MIN.x - 0.02, K_MAX.x + 0.02]:
				g.box("fenetre_sombre", Vector3(sx, yy, z), Vector3(0.1, 2.8, 1.4), 0.0, false)
	# bandeau, parapet crénelé et toit
	g.box("pierre_claire", Vector3(cx, top - 0.3, cz), Vector3(hx * 2 + 1.0, 0.6, hz * 2 + 1.0), 0.0, false)
	g.crenels("pierre_claire", Vector3(K_MIN.x - 0.3, top, K_MAX.y + 0.3), Vector3(K_MAX.x + 0.3, top, K_MAX.y + 0.3), 0.7)
	g.crenels("pierre_claire", Vector3(K_MIN.x - 0.3, top, K_MIN.y - 0.3), Vector3(K_MAX.x + 0.3, top, K_MIN.y - 0.3), 0.7)
	g.crenels("pierre_claire", Vector3(K_MIN.x - 0.3, top, K_MIN.y - 0.3), Vector3(K_MIN.x - 0.3, top, K_MAX.y + 0.3), 0.7)
	g.crenels("pierre_claire", Vector3(K_MAX.x + 0.3, top, K_MIN.y - 0.3), Vector3(K_MAX.x + 0.3, top, K_MAX.y + 0.3), 0.7)
	g.box("pierre", Vector3(cx, top + 0.8, cz), Vector3(hx * 2 - 2.0, 1.6, hz * 2 - 2.0), 0.0, false)
	g.hip_roof("ardoise", Vector3(cx, top + 1.6, cz), hx - 0.4, hz - 0.4, 11.0)
	# tourelles d'angle
	for px in [K_MIN.x, K_MAX.x]:
		for pz in [K_MIN.y, K_MAX.y]:
			_tour_ronde(g, Vector3(px, 0, pz), 3.4, top + 5.0)
	# perron d'entrée (4 marches) et auvent de pierre au-dessus de la porte
	g.stairs("pierre_claire", Vector3(0, Y0 - 0.02, K_MAX.y + 4.6), 0.0, 9.0, 0.26, 0.55, 4)
	g.box("pierre_claire", Vector3(0, FLOOR - 0.1, K_MAX.y + 1.3), Vector3(9.0, 0.2, 2.6), 0.0, true)
	for i in 9:
		var a = PI * i / 8.0
		g.box("pierre_claire", Vector3(cos(a) * 2.9, FLOOR + 6.3 + sin(a) * 1.4, K_MAX.y + 0.15), Vector3(0.8, 0.8, 0.5), 0.0, false)
	# bannières de façade (bleu et or)
	for sx in [-6.5, 6.5]:
		g.box("bleu_royal", Vector3(sx, FLOOR + 9.0, K_MAX.y + 0.12), Vector3(2.0, 7.0, 0.08), 0.0, false)
		g.box("or", Vector3(sx, FLOOR + 9.5, K_MAX.y + 0.18), Vector3(0.8, 2.6, 0.05), 0.0, false)

## Mur percé d'ouvertures. openings : [position le long du mur (m depuis a), largeur, bas, haut, matériau de vitre ou ""]
static func _wall_open(g: Geo, m: String, a: Vector3, b: Vector3, t: float, h: float, openings: Array) -> void:
	var d = b - a
	var len = d.length()
	var dir = d / len
	var rot = Geo.rot_for(d)
	var cursor = 0.0
	var ops = openings.duplicate()
	ops.sort_custom(func(x, y): return x[0] < y[0])
	for o in ops:
		var c0: float = o[0] - o[1] * 0.5
		var c1: float = o[0] + o[1] * 0.5
		if c0 > cursor:
			var mid = a + dir * ((cursor + c0) * 0.5)
			g.box(m, Vector3(mid.x, a.y + h * 0.5, mid.z), Vector3(c0 - cursor, h, t), rot)
		var midw = a + dir * o[0]
		if o[2] > 0.01:
			g.box(m, Vector3(midw.x, a.y + o[2] * 0.5, midw.z), Vector3(o[1], o[2], t), rot)
		g.box(m, Vector3(midw.x, a.y + (o[3] + h) * 0.5, midw.z), Vector3(o[1], h - o[3], t), rot)
		if o[4] != "":
			g.box(o[4], Vector3(midw.x, a.y + (o[2] + o[3]) * 0.5, midw.z), Vector3(o[1], o[3] - o[2], 0.15), rot)
		cursor = c1
	if cursor < len:
		var mid = a + dir * ((cursor + len) * 0.5)
		g.box(m, Vector3(mid.x, a.y + h * 0.5, mid.z), Vector3(len - cursor, h, t), rot)

# ------------------------------------------------------------------ DONJON (intérieur)
static func _donjon_interieur(g: Geo) -> void:
	var ix0 = K_MIN.x + KT
	var ix1 = K_MAX.x - KT
	var iz0 = K_MIN.y + KT
	var iz1 = K_MAX.y - KT
	# sols : dallage dans la salle, parquet dans les ailes
	g.box("dallage", Vector3(0, FLOOR - 0.05, (iz0 + iz1) * 0.5), Vector3(HALL_X * 2, 0.1, iz1 - iz0), 0.0, false)
	for sx in [-1.0, 1.0]:
		var wx = sx * (HALL_X + (ix1 - HALL_X) * 0.5)
		g.box("parquet", Vector3(wx, FLOOR - 0.04, (iz0 + iz1) * 0.5), Vector3(ix1 - HALL_X, 0.1, iz1 - iz0), 0.0, false)
	# cloisons salle / ailes (portes vers chaque pièce)
	for sx in [-1.0, 1.0]:
		var x = sx * (HALL_X + 0.5)
		var a = Vector3(x, FLOOR, iz0)
		var b = Vector3(x, FLOOR, iz1)
		var front = (WING_SPLIT_Z + iz1) * 0.5 - iz0
		var back = (iz0 + WING_SPLIT_Z) * 0.5 - iz0
		_wall_open(g, "pierre", a, b, 1.0, HALL_CEIL, [[back, 2.8, 0.0, 4.2, ""], [front, 2.8, 0.0, 4.2, ""]])
		# encadrements de portes
		for zc in [iz0 + back, iz0 + front]:
			g.box("pierre_claire", Vector3(x, FLOOR + 4.45, zc), Vector3(1.2, 0.5, 3.6), 0.0, false)
		# mur entre les deux pièces de l'aile
		var wx0 = sx * (HALL_X + 1.0)
		var wx1 = sx * ix1
		g.wall("pierre", Vector3(minf(wx0, wx1), FLOOR, WING_SPLIT_Z), Vector3(maxf(wx0, wx1), FLOOR, WING_SPLIT_Z), 1.0, WING_CEIL)
		# plafond des ailes (poutres + planches)
		var wcx = sx * (HALL_X + 1.0 + (ix1 - HALL_X - 1.0) * 0.5)
		g.box("bois_sombre", Vector3(wcx, FLOOR + WING_CEIL + 0.25, (iz0 + iz1) * 0.5), Vector3(ix1 - HALL_X - 1.0, 0.5, iz1 - iz0))
		for k in 7:
			var z = iz0 + 2.0 + k * 4.4
			g.box("bois", Vector3(wcx, FLOOR + WING_CEIL - 0.25, z), Vector3(ix1 - HALL_X - 1.0, 0.5, 0.5), 0.0, false)
		# fenêtres lumineuses (côté extérieur des ailes)
		for k in 5:
			var z = iz0 + 2.5 + k * 6.5
			_window_in(g, Vector3(sx * (ix1 - 0.05), FLOOR + 3.4, z), PI / 2.0, 1.1, 2.2)
		# claire-voie de la grande salle (au-dessus des ailes)
		for k in 5:
			var z = iz0 + 3.5 + k * 6.0
			_window_in(g, Vector3(sx * (HALL_X - 0.45), FLOOR + 8.8, z), PI / 2.0, 1.1, 2.4)
	# plafond à caissons de la grande salle
	g.box("bois_sombre", Vector3(0, FLOOR + HALL_CEIL + 0.3, (iz0 + iz1) * 0.5), Vector3(HALL_X * 2 + 0.2, 0.6, iz1 - iz0))
	for k in 8:
		var z = iz0 + 1.8 + k * 4.0
		g.box("bois", Vector3(0, FLOOR + HALL_CEIL - 0.35, z), Vector3(HALL_X * 2, 0.7, 0.6), 0.0, false)
	g.box("bois", Vector3(-4.5, FLOOR + HALL_CEIL - 0.3, (iz0 + iz1) * 0.5), Vector3(0.5, 0.5, iz1 - iz0), 0.0, false)
	g.box("bois", Vector3(4.5, FLOOR + HALL_CEIL - 0.3, (iz0 + iz1) * 0.5), Vector3(0.5, 0.5, iz1 - iz0), 0.0, false)
	# piliers (deux rangées)
	for sx in [-5.5, 5.5]:
		for k in 4:
			var z = -135.0 - k * 6.0
			g.box("pierre_claire", Vector3(sx, FLOOR + 0.35, z), Vector3(1.6, 0.7, 1.6))
			g.cylinder("pierre_claire", Vector3(sx, 0, z), 0.55, FLOOR + 0.7, FLOOR + HALL_CEIL - 1.0, 10, true, false)
			g.box("pierre_claire", Vector3(sx, FLOOR + HALL_CEIL - 0.85, z), Vector3(1.5, 0.5, 1.5), 0.0, false)
	# estrade du trône (au nord) + marches
	var dz0 = iz0
	var dz1 = iz0 + 5.0
	g.box("pierre_claire", Vector3(0, FLOOR + 0.45, (dz0 + dz1) * 0.5), Vector3(11.0, 0.9, dz1 - dz0), 0.0, true, "tapis")
	g.stairs("pierre_claire", Vector3(0, FLOOR - 0.02, dz1 + 1.5), 0.0, 6.0, 0.3, 0.5, 3)
	# tapis rouge de la porte jusqu'aux marches, bord doré
	var tz0 = dz1 + 1.6
	var tz1 = iz1 - 0.2
	g.box("tapis", Vector3(0, FLOOR + 0.02, (tz0 + tz1) * 0.5), Vector3(3.4, 0.04, tz1 - tz0), 0.0, false)
	g.box("tapis_bord", Vector3(-1.75, FLOOR + 0.025, (tz0 + tz1) * 0.5), Vector3(0.12, 0.05, tz1 - tz0), 0.0, false)
	g.box("tapis_bord", Vector3(1.75, FLOOR + 0.025, (tz0 + tz1) * 0.5), Vector3(0.12, 0.05, tz1 - tz0), 0.0, false)
	# grand vitrail derrière le trône (encadrement)
	g.box("pierre_claire", Vector3(0, FLOOR + 9.8, iz0 + 0.1), Vector3(5.0, 0.5, 0.4), 0.0, false)
	g.box("pierre_claire", Vector3(0, FLOOR + 4.3, iz0 + 0.1), Vector3(5.0, 0.4, 0.4), 0.0, false)
	g.box("bleu_royal", Vector3(0, FLOOR + 7.0, iz0 + 0.12), Vector3(0.25, 5.0, 0.1), 0.0, false)
	g.box("bleu_royal", Vector3(0, FLOOR + 7.0, iz0 + 0.12), Vector3(3.9, 0.25, 0.1), 0.0, false)
	# trésorerie : tas d'or
	var tc = Vector3(14.5, FLOOR, -137.0)
	var rng = RandomNumberGenerator.new()
	rng.seed = 9
	for i in 5:
		var off = Vector3((i % 3 - 1) * 1.7 + rng.randf_range(-0.3, 0.3), 0, (i / 3 - 0.5) * 1.8)
		var r = rng.randf_range(0.6, 0.9)
		g.cone("or", tc + off, r, FLOOR, r * 0.55, 18)
		for k in 14:
			var a = rng.randf() * TAU
			var d = rng.randf_range(0.2, r * 1.5)
			var p = tc + off + Vector3(cos(a) * d, 0, sin(a) * d)
			var hh = maxf(0.0, (1.0 - d / r) * r * 0.55)
			g.cylinder("or", p, 0.09, FLOOR + hh, FLOOR + hh + 0.025, 8, false, true)
	# conseil : carte sur la table
	g.box("blanc", Vector3(-14.5, FLOOR + 1.06, -153.0), Vector3(2.4, 0.02, 1.4), 0.0, false)
	g.box("bleu_royal", Vector3(-14.2, FLOOR + 1.075, -153.2), Vector3(0.7, 0.01, 0.5), 0.0, false)

## Fenêtre vue de l'intérieur : vitre lumineuse, meneaux, encadrement et appui de pierre
static func _window_in(g: Geo, c: Vector3, rot: float, w: float, h: float) -> void:
	var b = Basis(Vector3.UP, rot)
	g.box("vitre", c, Vector3(w, h, 0.06), rot, false)
	g.box("bois_sombre", c + b * Vector3(0, 0, 0.05), Vector3(0.09, h, 0.06), rot, false)
	g.box("bois_sombre", c + b * Vector3(0, h * 0.18, 0.05), Vector3(w, 0.09, 0.06), rot, false)
	for s2 in [-1.0, 1.0]:
		g.box("pierre_claire", c + b * Vector3(s2 * (w * 0.5 + 0.12), 0, 0.06), Vector3(0.24, h + 0.3, 0.14), rot, false)
	g.box("pierre_claire", c + b * Vector3(0, h * 0.5 + 0.18, 0.06), Vector3(w + 0.5, 0.3, 0.16), rot, false)
	g.box("pierre_claire", c + b * Vector3(0, -h * 0.5 - 0.12, 0.12), Vector3(w + 0.6, 0.22, 0.3), rot, false)

# ------------------------------------------------------------------ COUR
static func _cour(g: Geo, parent: Node3D) -> void:
	# allée pavée de la porte au donjon
	var z0 = K_MAX.y + 5.0
	var z1 = C.y + H.y - 5.0
	g.box("paves", Vector3(0, Y0 + 0.02, (z0 + z1) * 0.5), Vector3(7.0, 0.04, z1 - z0), 0.0, false)
	g.box("paves", Vector3(0, Y0 + 0.02, K_MAX.y + 5.5), Vector3(24.0, 0.04, 4.0), 0.0, false)
	# écuries (est) et caserne (ouest) adossées à l'enceinte
	for sx in [-1.0, 1.0]:
		var x = sx * (H.x - WALL_T * 0.5 - 4.0)
		var zc = -112.0
		var ln = 24.0
		g.box("pierre_base", Vector3(x, Y0 + 0.4, zc), Vector3(8.0, 0.8, ln), 0.0, false)
		for k in 5:
			var zz = zc - ln * 0.5 + k * ln / 4.0
			g.box("bois_sombre", Vector3(x - sx * 3.6, Y0 + 2.2, zz), Vector3(0.45, 4.4, 0.45))
		g.box("bois", Vector3(x + sx * 3.4, Y0 + 2.4, zc), Vector3(0.4, 4.8, ln), 0.0, false)
		var b = Basis(Vector3.UP, 0.0)
		# toit en appentis (tuiles)
		var hi = Vector3(x + sx * 4.2, Y0 + 5.6, 0)
		var lo = Vector3(x - sx * 4.4, Y0 + 4.2, 0)
		var p0 = Vector3(hi.x, hi.y, zc - ln * 0.5 - 0.5)
		var p1 = Vector3(hi.x, hi.y, zc + ln * 0.5 + 0.5)
		var p2 = Vector3(lo.x, lo.y, zc + ln * 0.5 + 0.5)
		var p3 = Vector3(lo.x, lo.y, zc - ln * 0.5 - 0.5)
		if sx > 0:
			g.quad("tuile", p3, p2, p1, p0)
			g.quad("tuile", p0, p1, p2, p3)
		else:
			g.quad("tuile", p0, p1, p2, p3)
			g.quad("tuile", p3, p2, p1, p0)
	# puits de la cour (pierre)
	g.cylinder("pierre_base", Vector3(-16, 0, -100), 1.3, Y0, Y0 + 1.0, 12, true, true, "fenetre_sombre")
	for sx in [-1.0, 1.0]:
		g.box("bois_sombre", Vector3(-16 + sx * 1.1, Y0 + 1.9, -100), Vector3(0.2, 1.8, 0.2), 0.0, false)
	g.gable_roof("tuile", Vector3(-16, Y0 + 2.8, -100), 1.6, 1.2, 0.9, PI / 2.0)

static func _mobilier(parent: Node3D) -> void:
	var y = FLOOR
	var root = Node3D.new()
	root.name = "Mobilier"
	parent.add_child(root)
	# trône sur l'estrade
	Kit.dungeon(root, "Throne", Vector3(0, y + 0.9, -158.2), 0.0, 1.8)
	# bannières aux murs de la salle (entre les piliers)
	for k in 4:
		var z = -132.0 - k * 6.0
		Kit.dungeon(root, "Banner", Vector3(-HALL_X + 0.1, y + 10.2, z), PI / 2.0, 1.0)
		Kit.dungeon(root, "Banner", Vector3(HALL_X - 0.1, y + 10.2, z), -PI / 2.0, 1.0)
	# lustres
	for z in [-138.0, -150.0]:
		Kit.dungeon(root, "Chandelier", Vector3(0, y + HALL_CEIL - 0.6, z), 0.0, 1.8)
	# torches murales sur les piliers
	for sx in [-4.9, 4.9]:
		for k in [0, 2]:
			var z = -135.0 - k * 6.0
			Kit.dungeon(root, "Torch_Wall", Vector3(sx, y + 3.2, z), PI / 2.0 if sx > 0 else -PI / 2.0, 1.3)
	# tables de banquet de part et d'autre du tapis
	for sx in [-3.6, 3.6]:
		Kit.dungeon(root, "Table_Big", Vector3(sx * 0.0 + sx, y, -142.0), PI / 2.0, 1.0)
		Kit.dungeon(root, "Bench", Vector3(sx + signf(sx) * 1.5, y, -142.0), -PI / 2.0 * signf(sx), 1.0)
		for k in 3:
			Kit.dungeon(root, "Goblet", Vector3(sx, y + 0.83, -143.2 + k * 1.2), 0.0, 2.0)
	# --- salle du conseil (ouest, fond)
	Kit.dungeon(root, "Table_Big", Vector3(-14.5, y, -153.0), 0.0, 1.25)
	for i in 3:
		Kit.dungeon(root, "Chair", Vector3(-16.5 + i * 2.0, y, -155.4), 0.0, 1.0)
		Kit.dungeon(root, "Chair", Vector3(-16.5 + i * 2.0, y, -150.6), PI, 1.0)
	Kit.dungeon(root, "Candlestick_Triple", Vector3(-13.0, y + 1.04, -153.0), 0.0, 1.0)
	Kit.dungeon(root, "Fireplace", Vector3(-19.4, y, -152.0), PI / 2.0, 1.0)
	Kit.dungeon(root, "Shelf", Vector3(-14.5, y, -159.9), 0.0, 1.0)
	# --- bibliothèque (ouest, devant)
	for i in 3:
		Kit.dungeon(root, "Shelf", Vector3(-17.5 + i * 2.6, y, -144.0), PI, 1.15)
	for k in 3:
		Kit.dungeon(root, "Shelf", Vector3(-19.2, y, -135.0 - k * 2.4), PI / 2.0, 1.15)
	Kit.dungeon(root, "Desk", Vector3(-12.5, y, -134.0), -PI / 2.0, 1.0)
	Kit.dungeon(root, "Chair", Vector3(-11.4, y, -134.0), -PI / 2.0, 1.0)
	Kit.dungeon(root, "CrystalBall_Stand", Vector3(-15.0, y, -137.0), 0.0, 2.2)
	Kit.dungeon(root, "Scroll_Stack", Vector3(-16.0, y, -132.0), 0.3, 1.2)
	Kit.dungeon(root, "Book_Open", Vector3(-12.6, y + 0.82, -134.2), 0.2, 1.0)
	# --- armurerie (est, fond)
	for i in 4:
		Kit.dungeon(root, "WeaponRack_Big", Vector3(12.0 + i * 2.0, y, -159.6), 0.0, 1.2)
		for k in 3:
			var w = Kit.dungeon(root, "Spear" if (i + k) % 2 == 0 else "Sword", Vector3(11.55 + i * 2.0 + k * 0.45, y + 1.2, -159.45), 0.0, 1.0 if (i + k) % 2 == 0 else 1.3)
			w.rotation_degrees.x = -12.0
	for k in 3:
		Kit.dungeon(root, "WeaponRack_Small", Vector3(19.0, y, -156.0 + k * 3.0), -PI / 2.0, 1.2)
	for i in 4:
		Kit.dungeon(root, "Shield", Vector3(12.0 + i * 2.2, y + 3.4, -160.2), 0.0, 2.2)
	Kit.dungeon(root, "Table_Small", Vector3(14.5, y, -151.0), 0.0, 1.0)
	for i in 3:
		Kit.dungeon(root, "Sword", Vector3(13.5 + i * 0.9, y + 0.88, -151.0), 0.0, 1.0).rotation_degrees.x = 90
	# --- trésorerie (est, devant)
	for i in 4:
		Kit.dungeon(root, "Chest", Vector3(12.0 + i * 2.0, y, -143.4), PI, 1.5)
		Kit.dungeon(root, "Chest_Lid", Vector3(12.0 + i * 2.0, y + 0.7, -143.0), PI, 1.5)
	Kit.dungeon(root, "Scales", Vector3(17.5, y + 0.0, -133.0), 0.0, 1.5)
	for p in [Vector3(18.8, y, -131.2), Vector3(18.8, y, -140.4), Vector3(17.6, y, -140.6)]:
		Kit.dungeon(root, "Barrel_Closed", p, randf() * TAU, 1.0)
	Kit.dungeon(root, "ChestSmall", Vector3(17.5, y + 0.0, -134.6), 0.4, 1.6)
	Kit.dungeon(root, "Key_Golden", Vector3(17.6, y + 0.3, -134.6), 0.0, 2.0)
	# --- cour : tonneaux, caisses, charrettes, foin (hors du donjon)
	root = Node3D.new()
	root.name = "CourDecor"
	parent.add_child(root)
	# herse relevée dans le passage de la porte
	Kit.dungeon(root, "Portcullis_Metal", Vector3(0, Y0 + 4.9, C.y + H.y + 2.5), 0.0, 1.5)
	for p in [Vector3(-40, Y0, -100), Vector3(-38.5, Y0, -101.5), Vector3(40, Y0, -122), Vector3(41.2, Y0, -123.5)]:
		Kit.dungeon(root, "Barrel_Closed", p, randf() * TAU, 1.1)
	Kit.village(root, "Prop_Cart_1_Hay", Vector3(36, Y0, -98), 2.2, 1.3)
	Kit.village(root, "Prop_Crate_1", Vector3(-36, Y0, -118), 0.3, 1.3)
	Kit.village(root, "Prop_Hay_1", Vector3(42, Y0, -106), 0.0, 1.3)
	_lumieres(parent.get_node("Mobilier"))

static func _lumieres(root: Node3D) -> void:
	var y = FLOOR
	var pts = [
		[Vector3(0, y + 8.5, -138), 16.0, 1.6], [Vector3(0, y + 8.5, -150), 16.0, 1.6],
		[Vector3(-14.5, y + 5.0, -152), 11.0, 1.3], [Vector3(-14.5, y + 5.0, -137), 11.0, 1.2],
		[Vector3(14.5, y + 5.0, -152), 11.0, 1.2], [Vector3(14.5, y + 5.0, -137), 11.0, 1.4],
	]
	for p in pts:
		var l = OmniLight3D.new()
		l.position = p[0]
		l.omni_range = p[1]
		l.light_energy = p[2]
		l.light_color = Color(1.0, 0.78, 0.5)
		l.shadow_enabled = false
		l.visible = false
		root.add_child(l)
		interior_lights.append(l)

# ------------------------------------------------------------------ GARDES
static func _gardes(parent: Node3D) -> void:
	var gate_z = C.y + H.y
	var spots = [
		[Vector3(-4.6, Y0, gate_z + 7.0), 0.0],      # devant la porte, dehors
		[Vector3(4.6, Y0, gate_z + 7.0), 0.0],
		[Vector3(-3.6, Y0, gate_z - 7.5), PI],       # derrière la porte, dans la cour
		[Vector3(3.6, Y0, gate_z - 7.5), PI],
		[Vector3(-4.0, Y0 + 1.0, K_MAX.y + 2.0), 0.0],  # perron du donjon
		[Vector3(4.0, Y0 + 1.0, K_MAX.y + 2.0), 0.0],
		[Vector3(-4.0, FLOOR, -156.0), 0.0],           # au pied du trône
		[Vector3(4.0, FLOOR, -156.0), 0.0],
		[Vector3(-12.0, FLOOR, -139.0), PI / 2],       # trésorerie... (garde à la porte)
		[Vector3(-5.0, Y0 + 17.0, gate_z + 4.0), 0.0],     # au sommet du châtelet
		[Vector3(5.0, Y0 + 17.0, gate_z + 4.0), 0.0],
	]
	spots[8] = [Vector3(10.6, FLOOR, -137.0), -PI / 2]
	for s in spots:
		var gd = Guard.new()
		gd.position = s[0]
		gd.rotation.y = s[1]
		parent.add_child(gd)
		guards.append(gd)
	# deux patrouilles dans la cour
	var p1 = Guard.new()
	p1.patrol = [Vector3(-30, Y0, -96), Vector3(-30, Y0, -122), Vector3(-26, Y0, -124), Vector3(-26, Y0, -96)]
	parent.add_child(p1)
	var p2 = Guard.new()
	p2.patrol = [Vector3(28, Y0, -124), Vector3(28, Y0, -97), Vector3(12, Y0, -97), Vector3(12, Y0, -124)]
	parent.add_child(p2)

static func _zone_interieure(parent: Node3D) -> void:
	var area = Area3D.new()
	area.name = "ZoneDonjon"
	area.collision_layer = 0
	area.collision_mask = 8
	var cs = CollisionShape3D.new()
	var bs = BoxShape3D.new()
	bs.size = Vector3(K_MAX.x - K_MIN.x - 2.0 * KT, 12.0, K_MAX.y - K_MIN.y - 2.0 * KT)
	cs.shape = bs
	cs.position = Vector3((K_MIN.x + K_MAX.x) * 0.5, FLOOR + 6.0, (K_MIN.y + K_MAX.y) * 0.5)
	area.add_child(cs)
	parent.add_child(area)
