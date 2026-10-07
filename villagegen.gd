extends RefCounted
class_name VillageGen
# Générateur de village pour le Mode Construction : on choisit l'endroit et les quantités,
# il trace les rues, aligne les maisons face à la rue, place les PNJ devant leur boutique,
# puis les arbres, les ressources et les camps autour. Chaque pièce reste un objet modifiable.

const TREES := ["Tree_1_A_Color1.gltf", "Tree_1_B_Color1.gltf", "Tree_1_C_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_2_B_Color1.gltf",
	"Tree_2_C_Color1.gltf", "Tree_3_A_Color1.gltf", "Tree_3_B_Color1.gltf", "Tree_4_A_Color1.gltf", "Tree_4_B_Color1.gltf"]
const HOUSES_BIG := ["@house:6:2:plaster", "@house:6:2:brick", "@house:6:3:brick", "@house:6:3:plaster"]
const HOUSES_SMALL := ["@house:6:1:plaster", "@house:4:1:plaster", "@house:4:2:plaster", "@house:6:2:plaster"]
const LANTERN := "res://assets/halloween/lantern_standing.gltf"

const DEFAULTS := {"rayon": 30, "maisons": 10, "boutiques": 2, "rues": 2, "pave": 1, "villageois": 4, "gardes": 1,
	"arbres": 20, "bois": 6, "minerai": 6, "fibre": 6, "tier": 1, "camps": 1, "decor": 1,
	"svc": {"quest": 1, "shop": 1, "forge": 1, "tools": 1, "auction": 0, "travel": 0, "mercs": 0, "tannery": 0, "sawmill": 0, "enchant": 0}}

var world: Node
var rng := RandomNumberGenerator.new()
var occ: Array = []          # [Vector2, rayon] déjà pris
var streets: Array = []      # [polyline Array[Vector2], largeur]
var out: Array = []          # [chemin, Vector2, rot, solide]

func _put(path: String, p: Vector2, rot: float, solid: bool) -> void:
	out.append([path, p, rot, solid])

func _ok(p: Vector2, r: float, street_margin := 0.4) -> bool:
	if abs(p.x) > 110.0 or abs(p.y) > 110.0: return false
	if not world.walkable(p.x, p.y): return false
	for o in occ:
		if p.distance_to(o[0]) < r + float(o[1]): return false
	for st in streets:
		if _poly_dist(p, st[0]) < float(st[1]) * 0.5 + street_margin + r * 0.5: return false
	return true

static func _poly_dist(p: Vector2, pl: Array) -> float:
	var best := 1e9
	for i in pl.size() - 1:
		var a: Vector2 = pl[i]; var b: Vector2 = pl[i + 1]
		var ab := b - a; var t: float = clamp((p - a).dot(ab) / max(0.0001, ab.length_squared()), 0.0, 1.0)
		best = min(best, p.distance_to(a + ab * t))
	return best

# une maison de 6×8 tient-elle ici (terrain praticable, pas trop pentu, pas sur une rue) ?
func _house_fits(c: Vector2, rot: float, w: float, d: float) -> bool:
	var hs: Array = []
	for q in [Vector2(-w, -d), Vector2(w, -d), Vector2(w, d), Vector2(-w, d), Vector2.ZERO]:
		var lp: Vector2 = q * 0.5
		var wp := c + Vector2(lp.x, lp.y).rotated(-rot)
		if not world.walkable(wp.x, wp.y) or abs(wp.x) > 110.0 or abs(wp.y) > 110.0: return false
		for st in streets:
			if _poly_dist(wp, st[0]) < float(st[1]) * 0.5 + 0.3: return false
		hs.append(world.ground_y(wp.x, wp.y))
	if hs.max() - hs.min() > 2.6: return false
	for o in occ:
		if c.distance_to(o[0]) < max(w, d) * 0.5 + float(o[1]) - 0.6: return false
	return true

func plan(w: Node, C: Vector2, P: Dictionary, seed_v: int) -> Array:
	world = w; rng.seed = seed_v; out = []; occ = []; streets = []
	var R: float = float(P.rayon)
	var pave: bool = int(P.pave) == 1
	var rw: float = 3.6 if pave else 3.0
	var pr: float = 6.0 if R < 34.0 else 10.0
	var deco: bool = int(P.decor) == 1
	# ——— la place ———
	_put("@plaza:%d" % int(pr), C, 0.0, false); occ.append([C, pr + 0.3])
	if deco: _put("@fountain", C, 0.0, true)
	# ——— les rues, du bord de la place jusqu'à la sortie du village ———
	var k: int = int(P.rues)
	var a0 := rng.randf() * TAU
	var dirs: Array = []
	for i in k: dirs.append(Vector2.from_angle(a0 + i * TAU / max(1, k) + rng.randf_range(-0.12, 0.12)))
	for d: Vector2 in dirs:
		var nrm := Vector2(-d.y, d.x); var bend := rng.randf_range(-1.0, 1.0) * R * 0.07
		var pl: Array = []
		var s := pr - 0.8
		while s <= R + 4.0:
			var t: float = (s - pr) / max(1.0, R + 4.0 - pr)
			var q: Vector2 = C + d * s + nrm * sin(t * PI) * bend
			if not world.walkable(q.x, q.y) or abs(q.x) > 110.0 or abs(q.y) > 110.0: break
			pl.append(q); s += 2.0
		if pl.size() < 3: continue
		var cen := Vector2.ZERO
		for q: Vector2 in pl: cen += q
		cen /= pl.size()
		var rel: Array = []
		for q: Vector2 in pl: rel.append(q - cen)
		_put(Prefab.road_path("pave" if pave else "dirt", rw, rel), cen, 0.0, false)
		streets.append([pl, rw, d])
	# ——— emplacements de bâtiments : le long des rues, face à la rue ———
	var slots: Array = []
	for st in streets:
		var pl: Array = st[0]
		var s := pr + 6.0
		while s < R:
			var i := int(s / 2.0 - (pr - 0.8) / 2.0)
			if i >= pl.size() - 1: break
			var a: Vector2 = pl[i]; var b: Vector2 = pl[i + 1]
			var t := (b - a).normalized(); var n := Vector2(-t.y, t.x)
			for side in [-1.0, 1.0]:
				var c: Vector2 = a + n * side * (rw * 0.5 + 2.6 + 4.0)
				var f: Vector2 = -n * side
				slots.append([c, atan2(f.x, f.y), a.distance_to(C)])
			s += 8.0
	# puis en couronne autour de la place (sans rue, ou s'il faut plus de place)
	var ring := pr + 10.0
	while ring < R + 2.0:
		var n_arc := int(TAU * ring / 8.5)
		var off := rng.randf() * TAU
		for j in n_arc:
			var an := off + j * TAU / n_arc
			var c := C + Vector2.from_angle(an) * ring
			var f := (C - c).normalized()
			slots.append([c, atan2(f.x, f.y), ring + 40.0])
		ring += 13.0
	slots.sort_custom(func(x, y): return float(x[2]) < float(y[2]))
	var take_slot := func(w2: float, d2: float):
		for sl in slots:
			if sl.size() > 3: continue
			if _house_fits(sl[0], sl[1], w2 + 0.4, d2 + 0.4):
				sl.append(true); occ.append([sl[0], max(w2, d2) * 0.5 + 0.2])
				return sl
		return null
	var front := func(sl: Array, dist: float) -> Vector2: return (sl[0] as Vector2) + Vector2(0, dist).rotated(-float(sl[1]))
	var svc: Dictionary = P.svc
	var npcs_todo: Array = []     # [clé, position, yaw]
	# bâtiments de service
	if int(svc.get("shop", 0)) == 1:
		var sl = take_slot.call(6.4, 8.4)
		if sl != null: _put("@shop:blue", sl[0], sl[1], true); npcs_todo.append(["shop", front.call(sl, 5.9), sl[1]])
		else: npcs_todo.append(["shop", null, 0.0])
	if int(svc.get("auction", 0)) == 1:
		var sl = take_slot.call(6.4, 8.4)
		if sl != null: _put("@shop:purple", sl[0], sl[1], true); npcs_todo.append(["auction", front.call(sl, 5.9), sl[1]])
		else: npcs_todo.append(["auction", null, 0.0])
	if int(svc.get("forge", 0)) == 1:
		var sl = take_slot.call(5.6, 4.2)
		if sl != null: _put("@forge", sl[0], sl[1], true); npcs_todo.append(["forge", front.call(sl, 3.2), sl[1]])
		else: npcs_todo.append(["forge", null, 0.0])
	var cols := ["green", "red", "blue", "green"]
	for i in max(0, int(P.boutiques) - int(svc.get("shop", 0))):
		var sl = take_slot.call(6.4, 8.4)
		if sl == null: break
		_put("@shop:" + cols[i % cols.size()], sl[0], sl[1], true)
	var houses_done := 0
	for i in int(P.maisons):
		var big := rng.randf() < (0.65 if i < int(P.maisons) / 2 else 0.35)
		var hp: String = (HOUSES_BIG if big else HOUSES_SMALL)[rng.randi() % 4]
		var hw := 4.0 if hp.begins_with("@house:4") else 6.0
		var sl = take_slot.call(hw + 0.4, 8.4)
		if sl == null: break
		_put(hp, sl[0], sl[1], true); houses_done += 1
	# ——— PNJ autour de la place (sauf devant les rues) ———
	var plaza_spots: Array = []
	var nsp := int(TAU * (pr + 2.2) / 3.2)
	for j in nsp:
		var an := j * TAU / nsp
		var dd := Vector2.from_angle(an)
		var clear := true
		for st in streets:
			if abs(dd.angle_to(st[2])) < 0.45: clear = false
		if clear: plaza_spots.append(C + dd * (pr + 2.2))
	plaza_spots.shuffle()
	var plaza_npc := func(key: String, stall: bool) -> void:
		while not plaza_spots.is_empty():
			var p: Vector2 = plaza_spots.pop_back()
			if not _ok(p, 1.0, 0.0): continue
			var f := (C - p).normalized()
			npcs_todo.append([key, p, atan2(f.x, f.y)]); occ.append([p, 1.0])
			if stall:
				var q: Vector2 = p - f * 2.2
				if _ok(q, 1.4, 0.0): _put("@stall", q, atan2(f.x, f.y), true); occ.append([q, 1.5])
			return
	for e in npcs_todo:
		if e[1] == null: e[1] = Vector2.INF
	var fixed: Array = npcs_todo.filter(func(e): return e[1] != Vector2.INF)
	var later: Array = npcs_todo.filter(func(e): return e[1] == Vector2.INF)
	npcs_todo.clear(); npcs_todo.append_array(fixed)
	for e in later: plaza_npc.call(e[0], true)
	if int(svc.get("quest", 0)) == 1: plaza_npc.call("quest", false)
	if int(svc.get("tools", 0)) == 1:
		for tl in ["tools:hache", "tools:pioche", "tools:faucille"]: plaza_npc.call(tl, true)
	for key in ["travel", "mercs", "tannery", "sawmill", "enchant"]:
		if int(svc.get(key, 0)) == 1: plaza_npc.call(key, key in ["tannery", "sawmill"])
	# gardes aux entrées du village
	for i in int(P.gardes):
		if i < streets.size():
			var pl: Array = streets[i][0]
			var e2: Vector2 = pl[pl.size() - 1]; var t2 := ((pl[pl.size() - 1] as Vector2) - (pl[pl.size() - 2] as Vector2)).normalized()
			var p := e2 + Vector2(-t2.y, t2.x) * (rw * 0.5 + 1.0)
			npcs_todo.append(["guard", p, atan2(t2.x, t2.y)])
		else: plaza_npc.call("guard", false)
	# villageois qui flânent dans les rues
	for i in int(P.villageois):
		var p := Vector2.INF
		for tries in 20:
			var q: Vector2
			if streets.is_empty(): q = C + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(pr + 1.0, R)
			else:
				var pl: Array = streets[rng.randi() % streets.size()][0]
				var a: Vector2 = pl[rng.randi() % pl.size()]
				q = a + Vector2(rng.randf_range(-1, 1), rng.randf_range(-1, 1)).normalized() * (rw * 0.5 + 0.8)
			if world.walkable(q.x, q.y): p = q; break
		if p != Vector2.INF: npcs_todo.append(["talk", p, rng.randf() * TAU])
	for e in npcs_todo: _put("@npc:" + str(e[0]), e[1], float(e[2]), false)
	# ——— décor sobre : bancs sur la place, puits, lanternes le long des rues ———
	if deco:
		for j in 2:
			var an: float = a0 + PI / max(1, k) + j * PI
			var p := C + Vector2.from_angle(an) * (pr - 2.2)
			var f := (C - p).normalized()
			_put("@bench", p, atan2(f.x, f.y), true)
		for tries in 30:
			var p := C + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(pr + 4.0, R * 0.8)
			if _ok(p, 1.6): _put("@well", p, 0.0, true); occ.append([p, 1.6]); break
		for st in streets:
			var pl: Array = st[0]
			var side := 1.0
			for i in range(3, pl.size() - 1, 5):
				var a: Vector2 = pl[i]; var t := ((pl[i + 1] as Vector2) - a).normalized()
				var p := a + Vector2(-t.y, t.x) * side * (rw * 0.5 + 0.7)
				if world.walkable(p.x, p.y): _put(LANTERN, p, 0.0, true); occ.append([p, 0.6])
				side = -side
	# ——— nature : arbres en lisière et dans les trous ———
	var placed := 0
	for tries in int(P.arbres) * 12:
		if placed >= int(P.arbres): break
		var p := C + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(R * 0.55, R + 16.0)
		if not _ok(p, 1.8, 1.5): continue
		_put("res://assets/forest/" + TREES[rng.randi() % TREES.size()], p, rng.randf() * TAU, true)
		occ.append([p, 1.8]); placed += 1
	# ——— ressources récoltables, en bosquets / filons autour du village ———
	var t_res: int = clamp(int(P.tier), 1, 5)
	for kk in [["wood", "bois"], ["ore", "minerai"], ["fiber", "fibre"]]:
		var n_left: int = int(P[kk[1]])
		var guard := 0
		while n_left > 0 and guard < 12:
			guard += 1
			var cc := C + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(R + 6.0, R + 32.0)
			for i in min(n_left, rng.randi_range(3, 6)) * 6:
				if n_left <= 0: break
				var p := cc + Vector2(rng.randf_range(-6, 6), rng.randf_range(-6, 6))
				if not _ok(p, 1.3, 1.0): continue
				_put("@res:%s:%d" % [kk[0], t_res], p, 0.0, false); occ.append([p, 1.3]); n_left -= 1
	# ——— camps de monstres, un peu à l'écart ———
	var camps: Array = []
	for tries in int(P.camps) * 30:
		if camps.size() >= int(P.camps): break
		var p := C + Vector2.from_angle(rng.randf() * TAU) * rng.randf_range(R + 22.0, R + 46.0)
		if not _ok(p, 5.0, 3.0): continue
		var far := true
		for q: Vector2 in camps:
			if p.distance_to(q) < 16.0: far = false
		if not far: continue
		camps.append(p); occ.append([p, 5.0])
		_put("@camp:%d" % t_res, p, 0.0, false)
	return out
