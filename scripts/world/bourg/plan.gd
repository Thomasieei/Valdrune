class_name BourgPlan
extends RefCounted
## PLAN DU BOURG DE VALMONT — tracé à la main.
## Place du marché pavée (36 x 31 m) au pied de la rampe du château ; Grand-Rue (nord et sud) avec trottoirs
## et bordures de pierre ; Rue de l'Est (vers la ferme, la forge), Rue de l'Ouest (église et parvis),
## Rue Basse (boucle vers la rivière), Rue Haute (quartier nord-ouest), Rue du Four (cul-de-sac nord-est),
## Impasse du Puits (cour fermée). Maisons mitoyennes en rangées, venelles, arrière-cours clôturées.

const SQ_MIN := Vector2(-18, -36)
const SQ_MAX := Vector2(18, -5)

var b := Bourg.new()
var mk := MK.new()
var mk_up := {}             # nom de maison visitable -> MK (étages + toit, masqués à l'intérieur)
var geo := Geo.new()        # pavés, trottoirs, soubassements, marches
var props: Node3D
var rng := RandomNumberGenerator.new()
var boxes: Array = []       # [centre Vector2, demi-taille Vector2, rot] emprises occupées
var built: Array = []       # maisons construites {spec + résultat}
var reserve: Array = []     # [centre, rayon] : rues et places (pas d'arbres ni de maison)
var specials := {}
var visits: Array = []      # maisons visitables {nom, base, w, d, mk}
var yards: Array = []
var lots := 0

## Rues : polyligne, demi-largeur de chaussée, largeur de trottoir, pavée ?
const STREETS := {
	"rue_basse": {"pts": [Vector2(5.0, 14.5), Vector2(-20, 15.5), Vector2(-45, 12), Vector2(-60, 2), Vector2(-64.5, -11)], "w": 2.4, "walk": 1.3},
	"rue_haute": {"pts": [Vector2(-58, -17.4), Vector2(-57.5, -38), Vector2(-55, -57)], "w": 2.2, "walk": 1.2},
	"rue_four": {"pts": [Vector2(36.6, -11.8), Vector2(36.2, -34), Vector2(35.2, -55)], "w": 2.2, "walk": 1.2},
	"impasse": {"pts": [Vector2(10.6, 30.5), Vector2(22, 28.5), Vector2(31, 27)], "w": 2.0, "walk": 1.0},
}

func build(parent: Node3D) -> void:
	rng.seed = 1789
	mk.det = MK.new()
	b.mk = mk
	b.geo = geo
	props = Node3D.new()
	props.name = "BourgDecor"
	parent.add_child(props)
	_reserve_streets()
	# --- bâtiments remarquables posés à la main ---
	_church()
	# --- la place du marché ---
	var S := Vector2(0, 1)
	var N := Vector2(0, -1)
	var E := Vector2(1, 0)
	var W := Vector2(-1, 0)
	_row(Vector2(-18, -36), Vector2(-4.4, -36), S, {"depth": [4, 5], "floors": [2, 3], "specials": {0: {"w": 4, "d": 5, "floors": 3, "roof": "pignon", "quoins": true, "ground": "pierre", "name": "bailli", "plaster": Color(0.92, 0.9, 0.86), "lit": 0.35}}})
	_row(Vector2(6.3, -36), Vector2(18, -36), S, {"depth": [4, 5], "floors": [2, 3], "shop": 0.6})
	_row(Vector2(-18, -36), Vector2(-18, -25.6), E, {"depth": [4], "floors": [2, 3], "shop": 0.5})
	_row(Vector2(-18, -16.2), Vector2(-18, -5), E, {"depth": [4], "floors": [2, 3], "shop": 0.5})
	_row(Vector2(18, -36), Vector2(18, -21.0), W, {"depth": [4], "specials": {0: {"w": 7, "d": 5, "force": true, "floors": 2, "roof": "long", "visit": true, "balcony": true, "quoins": true, "ground": "pierre", "name": "taverne", "door_k": 3, "lit": 0.8, "plaster": Color(0.98, 0.9, 0.76), "tiles": Color(0.62, 0.48, 0.44)}}})
	_row(Vector2(18, -11.2), Vector2(18, -5), W, {"depth": [4], "floors": [2], "shop": 1.0})
	_row(Vector2(-18, -5), Vector2(-3.3, -5), N, {"depth": [4], "floors": [2, 3], "shop": 0.6})
	_row(Vector2(6.9, -5), Vector2(18, -5), N, {"depth": [4], "floors": [2], "specials": {0: {"w": 3, "d": 4, "floors": 2, "visit": true, "shop": true, "name": "apothicaire", "roof": "pignon", "lit": 0.6}}})
	# --- Grand-Rue Nord (vers le château) ---
	var r0: Array = Layout.ROADS[0]["pts"]
	_seg_row(r0[1], r0[2], 1.0, 5.4, 8.0, 21.5, {"depth": [4], "floors": [2, 3]})
	_seg_row(r0[1], r0[2], -1.0, 5.4, 8.0, 21.5, {"depth": [4], "floors": [2, 3]})
	# --- Grand-Rue Sud (vers le pont) ---
	_seg_row(r0[4], r0[5], 1.0, 5.4, 16.2, 22.6, {"depth": [4], "floors": [2]})
	_seg_row(r0[4], r0[5], -1.0, 5.4, 17.5, 32.5, {"depth": [4, 5], "floors": [2, 3], "shop": 0.4})
	_seg_row(r0[5], r0[6], 1.0, 5.4, 0.5, 27.0, {"depth": [4], "floors": [1, 2], "alley": 0.25})
	_seg_row(r0[5], r0[6], -1.0, 5.4, 2.5, 8.5, {"depth": [4], "floors": [2]})
	_seg_row(r0[5], r0[6], -1.0, 5.4, 17.5, 30.0, {"depth": [4], "specials": {0: {"w": 6, "d": 4, "floors": 3, "roof": "long", "balcony": true, "name": "relais", "ground": "pierre", "quoins": true, "lit": 0.5, "tiles": Color(0.56, 0.5, 0.5)}}})
	# --- Rue de l'Est (forge, vers la ferme) ---
	var r1: Array = Layout.ROADS[1]["pts"]
	_seg_row(r1[1], r1[2], -1.0, 4.4, 10.8, 18.5, {"depth": [4], "floors": [1, 2]})
	_seg_row(r1[1], r1[2], 1.0, 4.4, 0.6, 4.0, {"depth": [4], "floors": [1]})
	_seg_row(r1[1], r1[2], 1.0, 4.4, 11.5, 18.5, {"depth": [3, 4], "floors": [1, 2]})
	# --- Rue de l'Ouest (église) ---
	var r2: Array = Layout.ROADS[2]["pts"]
	_seg_row(r2[1], r2[2], 1.0, 4.4, 0.4, 6.0, {"depth": [4], "floors": [2]})
	_seg_row(r2[2], r2[3], 1.0, 4.4, 3.6, 20.0, {"depth": [4, 5], "floors": [1, 2]})
	_seg_row(r2[1], r2[2], -1.0, 4.4, 0.4, 24.0, {"depth": [4], "floors": [1, 2, 2], "alley": 0.2})
	_seg_row(r2[2], r2[3], -1.0, 4.4, 6.5, 16.0, {"depth": [4], "floors": [1, 2]})
	# --- Rue Basse (boucle vers la rivière) ---
	var rb: Array = STREETS["rue_basse"]["pts"]
	_seg_row(rb[0], rb[1], 1.0, 3.7, 18.5, 25.0, {"depth": [4], "floors": [1, 2]})
	_seg_row(rb[0], rb[1], -1.0, 3.7, 13.2, 25.0, {"depth": [4], "floors": [1, 2], "specials": {0: {"w": 3, "d": 4, "floors": 2, "visit": true, "name": "maison_mathis", "roof": "pignon", "lit": 0.7}}})
	_seg_row(rb[1], rb[2], -1.0, 3.7, 0.4, 25.0, {"depth": [4], "floors": [1, 2], "alley": 0.25})
	_seg_row(rb[1], rb[2], 1.0, 3.7, 0.4, 25.0, {"depth": [4], "floors": [1, 2], "alley": 0.2})
	_seg_row(rb[2], rb[3], -1.0, 3.7, 0.4, 17.0, {"depth": [4], "floors": [1, 2]})
	_seg_row(rb[2], rb[3], 1.0, 3.7, 0.4, 17.0, {"depth": [4], "floors": [1]})
	# --- Rue Haute (nord-ouest) ---
	var rh: Array = STREETS["rue_haute"]["pts"]
	_seg_row(rh[0], rh[1], -1.0, 3.4, 10.0, 20.6, {"depth": [4], "floors": [1, 2]})
	_seg_row(rh[1], rh[2], -1.0, 3.4, 0.4, 19.0, {"depth": [4], "floors": [1, 2]})
	_seg_row(rh[1], rh[2], 1.0, 3.4, 9.0, 19.0, {"depth": [3, 4], "floors": [1, 2]})
	# --- Rue du Four (nord-est, cul-de-sac) ---
	var rf: Array = STREETS["rue_four"]["pts"]
	_seg_row(rf[0], rf[1], -1.0, 3.4, 9.5, 22.2, {"depth": [3], "floors": [1, 2]})
	_seg_row(rf[1], rf[2], -1.0, 3.4, 0.4, 20.0, {"depth": [3], "floors": [1, 2]})
	_seg_row(rf[0], rf[1], 1.0, 3.4, 4.0, 22.2, {"depth": [4], "floors": [1, 2]})
	_seg_row(rf[1], rf[2], 1.0, 3.4, 0.4, 16.0, {"depth": [4], "floors": [1, 2]})
	# --- Impasse du Puits : cour fermée, maisons tournées vers le puits ---
	_impasse()
	print("[bourg] lots=%d maisons=%d triangles=%d refus=%s" % [lots, built.size(), mk.tris, why])
	# --- sols : place, rues, trottoirs ---
	_square()
	_streets()
	_yards()

# ---------------------------------------------------------------- outils

## Rangée de maisons mitoyennes : façades alignées sur a→e, tournées vers face.
func _row(a: Vector2, e: Vector2, face: Vector2, opt := {}) -> void:
	var dir := (e - a).normalized()
	var L := a.distance_to(e)
	var t := 0.0
	var i := 0
	var plan: Array = []
	var specs: Dictionary = opt.get("specials", {})
	while t < L - 3.6:
		var sp: Dictionary = specs.get(i, {}).duplicate()
		var gap := 0.0
		if rng.randf() < float(opt.get("alley", 0.12)) and i > 0 and not sp.has("name"):
			gap = rng.randf_range(2.0, 3.0)   # venelle
		var room := int(floor((L - t - gap + 0.3) / Bourg.M))
		if room < 2:
			break
		var d: int = sp.get("d", (opt.get("depth", [4]) as Array)[rng.randi() % (opt.get("depth", [4]) as Array).size()])
		var w: int = sp.get("w", 0)
		var roof: String = sp.get("roof", "")
		if w == 0:
			w = (opt.get("widths", [2, 2, 3, 3, 3, 4]) as Array)[rng.randi() % (opt.get("widths", [2, 2, 3, 3, 3, 4]) as Array).size()]
			w = mini(w, room)
			if room - w == 1:
				w = room if room <= 5 else w - 1
			w = maxi(w, 2)
		if roof == "":
			roof = "pignon" if (w <= 4 and rng.randf() < 0.6) else "long"
		var ok: bool = sp.get("force", false)
		for combo in ([] if ok else  [[d, roof], [d, "long" if roof == "pignon" else "pignon"], [4, "pignon"], [4, "long"], [3, "long"], [3, "pignon"]]):
			if Bourg.roof_ok(w, combo[0], combo[1]):
				d = combo[0]
				roof = combo[1]
				ok = true
				break
		if not ok:
			t += gap + w * Bourg.M
			i += 1
			continue
		var fl: Array = opt.get("floors", [1, 2])
		sp.merge({"w": w, "d": d, "roof": roof, "floors": fl[rng.randi() % fl.size()]})
		if not sp.has("shop") and rng.randf() < float(opt.get("shop", 0.0)):
			sp["shop"] = true
		var setback := rng.randf_range(0.0, 0.25) if not sp.has("name") else 0.0
		plan.append({"t": t + gap, "sp": sp, "setback": setback})
		t += gap + w * Bourg.M
		i += 1
	# construction (les côtés mitoyens n'ont pas de fenêtres)
	for k in plan.size():
		var lot: Dictionary = plan[k]
		var sp: Dictionary = lot["sp"]
		var w: int = sp["w"]
		var d: int = sp["d"]
		var c: Vector2 = a + dir * (float(lot["t"]) + w * Bourg.M * 0.5) - face * (d * Bourg.M * 0.5 + float(lot["setback"]))
		var rot := atan2(face.x, face.y)
		var xl := Vector2(face.y, -face.x)   # axe x local de la maison
		var blind := []
		var prev_adj: bool = k > 0 and absf(float(plan[k - 1]["t"]) + int(plan[k - 1]["sp"]["w"]) * Bourg.M - float(lot["t"])) < 0.05
		var next_adj: bool = k < plan.size() - 1 and absf(float(lot["t"]) + w * Bourg.M - float(plan[k + 1]["t"])) < 0.05
		var fwd := 3 if xl.dot(dir) > 0.0 else 2
		var bwd := 2 if fwd == 3 else 3
		if prev_adj: blind.append(bwd)
		if next_adj: blind.append(fwd)
		sp["blind"] = blind
		sp["pos"] = c
		sp["rot"] = rot
		_house(sp)

## Rangée le long d'un segment de rue : côté (+1 = normale gauche), décalage depuis l'axe, abscisses s0..s1
func _seg_row(p0: Vector2, p1: Vector2, side: float, off: float, s0: float, s1: float, opt := {}) -> void:
	var dir := (p1 - p0).normalized()
	var n := Vector2(-dir.y, dir.x) * side
	var a := p0 + dir * s0 + n * off
	var e := p0 + dir * s1 + n * off
	_row(a, e, -n, opt)

func _house(sp: Dictionary) -> bool:
	lots += 1
	var c: Vector2 = sp["pos"]
	var hw: float = int(sp["w"]) * Bourg.M * 0.5
	var hd: float = int(sp["d"]) * Bourg.M * 0.5
	var rot: float = sp["rot"]
	var before := why.duplicate()
	if not _free(c, Vector2(hw, hd), rot):
		var r := ""
		for k in why:
			if why[k] != before.get(k, 0): r = k
		refused.append([c, Vector2(hw, hd), rot, r, _hit])
		return false
	sp["seed"] = rng.randi()
	var visit: bool = sp.get("visit", false)
	if visit:
		var up := MK.new()
		mk_up[sp["name"]] = up
		b.mk_up = up
	var res := b.build_house(sp)
	b.mk_up = null
	boxes.append([c, Vector2(hw, hd), rot])
	sp.merge(res, true)
	built.append(sp)
	if sp.has("name"):
		specials[sp["name"]] = sp
	if visit:
		visits.append(sp)
	_doorstep(sp)
	return true

## Marches devant la porte quand la maison est surélevée (pente)
func _doorstep(sp: Dictionary) -> void:
	var dp: Vector3 = sp["door"]
	var face: Vector2 = sp["face"]
	var y0: float = sp["y0"]
	var out := Vector2(dp.x, dp.z) + face * 0.2
	var g := Terrain.height_at(out.x + face.x, out.y + face.y) + 0.12
	var rise := y0 - g
	if rise < 0.12:
		return
	var n := clampi(int(ceil(rise / 0.2)), 1, 6)
	var run := 0.32
	var st := Vector3(out.x + face.x * run * n, g - 0.02, out.y + face.y * run * n)
	geo.stairs("pierre_base", st, atan2(face.x, face.y), 1.7, rise / n, run, n)

var why := {}
var refused: Array = []   # [centre, demi, rot] (diagnostic)
var _hit := Vector2.ZERO
func _free(c: Vector2, h: Vector2, rot: float) -> bool:
	var r := h.length()
	if Layout.river_dist(c) < Layout.RIVER_W + r + 1.5:
		why["riviere"] = why.get("riviere", 0) + 1
		return false
	if Layout.in_fields(c, r * 0.6) or Layout.in_castle(c, 20.0):
		why["champs"] = why.get("champs", 0) + 1
		return false
	if absf(c.x - Layout.GATE.x) < 6.0 + h.x and c.y < -63.0:
		return false
	for z in Spawner.ZONES:
		if c.distance_to(z["pos"]) < float(z["r"]) + r + 3.0:
			why["repaire"] = why.get("repaire", 0) + 1
			return false
	for bx in boxes:
		if _obb(c, h, rot, bx[0], bx[1], bx[2]):
			_hit = bx[0]
			why["chevauche"] = why.get("chevauche", 0) + 1
			return false
	# pas sur une chaussée ni sur la place
	for k in 9:
		var q := c + Vector2((k % 3 - 1) * h.x * 0.9, (k / 3 - 1) * h.y * 0.9).rotated(-rot)
		if Layout.road_dist(q) < 0.6 or _on_street(q, 0.4) or _in_square(q, -0.3):
			why["rue"] = why.get("rue", 0) + 1
			return false
	return true

static func _axes(rot: float) -> Array:
	return [Vector2(cos(rot), -sin(rot)), Vector2(sin(rot), cos(rot))]

static func _obb(c1: Vector2, h1: Vector2, r1: float, c2: Vector2, h2: Vector2, r2: float) -> bool:
	var a1 := _axes(r1)
	var a2 := _axes(r2)
	var d := c2 - c1
	for ax in a1 + a2:
		var p1: float = h1.x * absf(ax.dot(a1[0])) + h1.y * absf(ax.dot(a1[1]))
		var p2: float = h2.x * absf(ax.dot(a2[0])) + h2.y * absf(ax.dot(a2[1]))
		if absf(d.dot(ax)) > p1 + p2 - 0.02:
			return false
	return true

func _in_square(p: Vector2, m := 0.0) -> bool:
	return p.x > SQ_MIN.x - m and p.x < SQ_MAX.x + m and p.y > SQ_MIN.y - m and p.y < SQ_MAX.y + m

func _on_street(p: Vector2, m := 0.0) -> bool:
	for k in STREETS:
		var s: Dictionary = STREETS[k]
		if Layout.poly_dist(p, s["pts"]) < float(s["w"]) + m:
			return true
	return false

func _reserve_streets() -> void:
	for k in STREETS:
		var s: Dictionary = STREETS[k]
		var pts: Array = s["pts"]
		for i in pts.size() - 1:
			var a: Vector2 = pts[i]
			var e: Vector2 = pts[i + 1]
			var n := int(ceil(a.distance_to(e) / 3.0))
			for j in n + 1:
				reserve.append([a.lerp(e, float(j) / n), float(s["w"]) + float(s["walk"])])
	for x in range(-16, 18, 6):
		for z in range(-34, -5, 6):
			reserve.append([Vector2(x, z), 4.5])

# ---------------------------------------------------------------- lieux

## Église de Valmont sur la Rue de l'Ouest, parvis pavé ouvert sur la rue
func _church() -> void:
	var c := Vector2(-44.5, -40.0)
	var rot := 0.18   # façade (clocher) tournée vers la rue, au sud
	Town._church(geo, c, rot)
	boxes.append([c + Vector2(sin(rot), cos(rot)) * 1.5, Vector2(6.0, 12.5), rot])
	specials["eglise"] = {"pos": c, "rot": rot}
	# parvis
	var f := c + Vector2(sin(rot), cos(rot)) * 15.0
	for i in 5:
		for j in 3:
			var q := f + Vector2(-4.0 + i * 2.0, -2.0 + j * 2.0).rotated(-rot)
			var y := Terrain.height_at(q.x, q.y) + 0.08
			_flat_quad("dallage", q, 1.0, rot, y)
	reserve.append([f, 6.0])

## Cour de l'Impasse du Puits : 5 maisons en demi-cercle autour d'un puits
func _impasse() -> void:
	var cc := Vector2(36.5, 26.0)
	var specs := [[150.0, 3, 4, 2], [105.0, 3, 4, 1], [60.0, 2, 4, 2], [15.0, 3, 4, 2], [-30.0, 3, 4, 1], [-75.0, 2, 4, 2]]
	for s in specs:
		var a := deg_to_rad(float(s[0]))
		var dist := 6.5 + int(s[2]) * Bourg.M * 0.5
		var c := cc + Vector2(cos(a), sin(a)) * dist
		var face := (cc - c).normalized()
		var sp := {"pos": c, "rot": atan2(face.x, face.y), "w": s[1], "d": s[2], "floors": s[3], "roof": "pignon", "lit": 0.35}
		_house(sp)
	specials["puits_impasse"] = cc
	reserve.append([cc, 6.0])

## Place du marché : grand dallage, bordure de pierre
func _square() -> void:
	var step := 3.0
	var nx := int((SQ_MAX.x - SQ_MIN.x) / step)
	var nz := int((SQ_MAX.y - SQ_MIN.y) / step)
	for i in nx + 1:
		for j in nz + 1:
			var x0 := minf(SQ_MIN.x + i * step, SQ_MAX.x)
			var z0 := minf(SQ_MIN.y + j * step, SQ_MAX.y)
			var x1 := minf(x0 + step, SQ_MAX.x)
			var z1 := minf(z0 + step, SQ_MAX.y)
			if x1 - x0 < 0.01 or z1 - z0 < 0.01:
				continue
			var a := Vector3(x0, Terrain.height_at(x0, z0) + 0.1, z0)
			var bb := Vector3(x1, Terrain.height_at(x1, z0) + 0.1, z0)
			var cc := Vector3(x1, Terrain.height_at(x1, z1) + 0.1, z1)
			var dd := Vector3(x0, Terrain.height_at(x0, z1) + 0.1, z1)
			geo.quad("dallage", dd, cc, bb, a, 1)

func _flat_quad(m: String, c: Vector2, h: float, rot: float, y: float) -> void:
	var ax := Vector2(cos(rot), -sin(rot)) * h
	var az := Vector2(sin(rot), cos(rot)) * h
	var p := [c - ax - az, c + ax - az, c + ax + az, c - ax + az]
	geo.quad(m, Vector3(p[3].x, y, p[3].y), Vector3(p[2].x, y, p[2].y), Vector3(p[1].x, y, p[1].y), Vector3(p[0].x, y, p[0].y), 1)

## Chaussées pavées (rues secondaires, Rue de l'Est/Ouest dans le bourg) et trottoirs bordés
func _streets() -> void:
	for k in STREETS:
		var s: Dictionary = STREETS[k]
		Roads._ribbon(geo, s["pts"], float(s["w"]), "paves")
	# Rue de l'Est et de l'Ouest : pavées dans la traversée du bourg
	var r1: Array = Layout.ROADS[1]["pts"]
	Roads._ribbon(geo, [r1[0], r1[1], r1[2]], 2.6, "paves")
	var r2: Array = Layout.ROADS[2]["pts"]
	Roads._ribbon(geo, [r2[0], r2[1], r2[2], r2[3]], 2.6, "paves")
	# trottoirs : devant chaque maison, de la façade jusqu'à la bordure
	for h in built:
		if not h.has("face"):
			continue
		var face: Vector2 = h["face"]
		var c: Vector2 = h["pos"]
		var hd: float = int(h["d"]) * Bourg.M * 0.5
		var hw: float = int(h["w"]) * Bourg.M * 0.5
		var front: Vector2 = c + face * hd
		var walk := _walk_width(front, face, Vector2(face.y, -face.x), hw)
		if walk < 0.5:
			continue
		var xl := Vector2(face.y, -face.x)
		var rot := atan2(face.x, face.y)
		# dalle du trottoir
		var p0 := front - xl * hw
		var p1 := front + xl * hw
		var p2 := p1 + face * walk
		var p3 := p0 + face * walk
		var ys := [Terrain.height_at(p0.x, p0.y), Terrain.height_at(p1.x, p1.y), Terrain.height_at(p2.x, p2.y), Terrain.height_at(p3.x, p3.y)]
		var y := (ys.max() as float) + 0.14
		geo.quad("dallage", Vector3(p3.x, y, p3.y), Vector3(p2.x, y, p2.y), Vector3(p1.x, y, p1.y), Vector3(p0.x, y, p0.y), 1)
		# bordure de pierre (2 m) le long de la chaussée
		var n := int(round(hw))
		for i in n:
			var q: Vector2 = p3 + xl * (Bourg.M * (i + 0.5))
			mk.add("Prop_ExteriorBorder_Straight1", Transform3D(Basis(Vector3.UP, atan2(-face.x, -face.y)), Vector3(q.x, y - 0.13, q.y)))
		# rive du trottoir : petit muret vers la chaussée
		geo.obox("pierre_base", Transform3D(Basis(Vector3.UP, rot), Vector3((p2.x + p3.x) * 0.5, y - 0.35, (p2.y + p3.y) * 0.5)), Vector3(hw * 2.0, 0.5, 0.2), false)

## Largeur de trottoir devant une façade : jusqu'à la chaussée la plus proche (max 2,6 m), mesurée en 3 points
func _walk_width(front: Vector2, face: Vector2, xl := Vector2.ZERO, hw := 0.0) -> float:
	var best := 0.0
	for o in [0.0, -0.7, 0.7]:
		var f0: Vector2 = front + xl * hw * o
		for k in 27:
			var t := k * 0.1
			var q := f0 + face * (t + 0.05)
			if Layout.road_dist(q) < 0.0 or _on_street(q) or _in_square(q):
				if t > 0.3:
					best = t if best == 0.0 else minf(best, t)
				break
	return best

## Arrière-cours : potager clôturé, tas de bois, linge, tonneaux — derrière les maisons, si la place est libre
func _yards() -> void:
	for h in built:
		if not h.has("face") or h.get("name", "") == "taverne":
			continue
		var face: Vector2 = h["face"]
		var c: Vector2 = h["pos"]
		var hd: float = int(h["d"]) * Bourg.M * 0.5
		var hw: float = int(h["w"]) * Bourg.M * 0.5
		var depth := 0.0
		for k in range(8, 1, -1):
			var yc := c - face * (hd + 0.5 + k * 0.5)
			if _free(yc, Vector2(maxf(hw - 0.3, 1.5), k * 0.5), atan2(face.x, face.y)) and Layout.road_dist(c - face * (hd + k + 0.5)) > 1.0:
				depth = k
				break
		if depth < 3.0:
			continue
		var yc := c - face * (hd + 0.4 + depth * 0.5)
		boxes.append([yc, Vector2(hw, depth * 0.5), atan2(face.x, face.y)])
		yards.append({"c": yc, "face": face, "hw": hw, "depth": depth, "house": h})
