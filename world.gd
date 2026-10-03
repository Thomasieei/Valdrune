extends Node3D
# VALDRUNE — un vrai monde : 5 régions naturelles, rivière, falaises, routes, village, lieux à découvrir
class_name World

const HALF := 128.0
const CELL := 2.0
const WATER_Y := -0.7
var N := 0
var hs := PackedFloat32Array()
var noise := FastNoiseLite.new()
var noise2 := FastNoiseLite.new()
var pnoise := FastNoiseLite.new()   # plateaux et falaises
var volcano: Dictionary = {}
static var vol_img: Image
var pgrid := PackedFloat32Array()   # plateau (étage 1) sur la grille du terrain
var blocked := PackedByteArray()  # cases infranchissables (falaises, montagnes du bord)
var warp := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
var proto := {}
var nodes: Array = []
var spawns: Array = []
var pois: Array = []           # lieux à découvrir
var hidden_chests: Array = []
var npc_spots: Array = []      # PNJ à créer par main
var bridges: Array = []
var forge_pos := Vector3(-9, 0, 72)
var shop_pos := Vector3(9, 0, 72)
var boss_pos := Vector3(0, 0, -112)
var village := Vector2(0, 80)
var tower_portal := Vector3(9999, 0, 9999)
var mm_lists := {}

# ——— Carte courante (voir maps.gd) ———
var map_id := 1
var MAP: Dictionary = {}
static var REGIONS: Array = [{}, {"name": "", "tier": 1, "c": Vector2.ZERO, "bias": 0.0, "style": "meadow", "g0": "#5c9c40", "g1": "#7db04c", "sky": "#a9c9d8"}]
var ROADS: Array = []
var RIVERS: Array = []
var LAKES: Array = []
var BAY = null
var POI_DEFS: Array = []
var gates: Array = []          # passages vers les autres cartes {pos: Vector3, to, dir, arrive}
const RIVER_W := 4.2
func in_town(p: Vector3) -> bool: return Vector2(p.x, p.z).distance_to(village) < 32.0

func setup_map(id: int) -> void:
	map_id = id; MAP = Maps.def(id)
	REGIONS = MAP.regions; ROADS = MAP.roads; RIVERS = MAP.rivers; LAKES = MAP.lakes; BAY = MAP.bay; POI_DEFS = MAP.pois
	village = MAP.town.pos
	POI_DEFS = POI_DEFS.duplicate(true)
	rng.seed = 2024 + id * 7
	noise.seed = 11 + id * 101; noise.frequency = 0.02; noise.fractal_octaves = 3
	noise2.seed = 77 + id * 31; noise2.frequency = 0.05
	warp.seed = 5 + id * 13; warp.frequency = 0.012
	pnoise.seed = 4100 + id * 57; pnoise.frequency = 0.016; pnoise.fractal_octaves = 2
	volcano = MAP.get("volcano", {})
	if not volcano.is_empty() and vol_img == null: vol_img = load("res://assets/relief/volcano_h.res")
	_make_roads()
	_plan_hamlets()
	_plan_paths()
	dirt_spots = []; foot_paths = []
	if MAP.town.kind == "valdrune":
		for off in [Vector2(-13, -10), Vector2(13, -10), Vector2(-15, 8), Vector2(15, 10), Vector2(-25, -17), Vector2(-26, -2), Vector2(26, -1)]:
			var q: Vector2 = village + off
			foot_paths.append([village + off.normalized() * 8.5, q - off.normalized() * 3.2])
		# emplacements des PNJ (cercles de terre)
		for o in [Vector2(-8.4, -5.8), Vector2(8.4, -5.8), Vector2(-21, -13), Vector2(3.5, 3.0), Vector2(-11, 8), Vector2(-8, 16), Vector2(8, 16), Vector2(9, 2), Vector2(-19, 13), Vector2(-5, -22), Vector2(3, -24)]:
			dirt_spots.append([village + o, 2.2])
	else: _plan_town_slots()
	_plan_ramps()

# ——— Un monde moins vide : fermes isolées, chemins vers chaque lieu, allées dans les villes ———
const HAMLET_NAMES := ["Ferme des Tilleuls", "Ferme Brunel", "Les Trois Meules", "Mas du Ruisseau", "Ferme Haute", "Le Vieux Moulin", "Ferme des Corbeaux", "Bergerie du Col"]
func _plan_hamlets() -> void:
	var r := RandomNumberGenerator.new(); r.seed = 900 + map_id
	var n := 0; var tries := 0
	while n < 3 and tries < 400:
		tries += 1
		var p := Vector2(r.randf_range(-92, 92), r.randf_range(-92, 92))
		var dv := p.distance_to(village)
		if dv < 40.0 or dv > 95.0: continue
		if region_at(p.x, p.y) != 1 and REGIONS[region_at(p.x, p.y)].tier > REGIONS[1].tier: continue
		if raw_height(p.x, p.y) < WATER_Y + 0.8 or river_dist(p.x, p.y) < 14.0: continue
		var ok := true
		for q in POI_DEFS:
			if p.distance_to(q.p) < q.r + 22.0: ok = false; break
		if road_dist(p.x, p.y) < 8.0: ok = false
		if not ok: continue
		POI_DEFS.append({"id": "ferme%d_%d" % [map_id, n], "name": HAMLET_NAMES[(map_id * 3 + n) % HAMLET_NAMES.size()], "p": p, "r": 8.0, "kind": "hamlet"})
		n += 1

func _nearest_on_roads(p: Vector2) -> Vector2:
	var best := p; var bd := 1e9
	for rd in roads:
		for i in rd.size() - 1:
			var a: Vector2 = rd[i]; var b: Vector2 = rd[i + 1]; var ab := b - a
			var t: float = clamp((p - a).dot(ab) / max(0.0001, ab.length_squared()), 0.0, 1.0)
			var q := a + ab * t
			if q.distance_to(p) < bd: bd = q.distance_to(p); best = q
	return best

func _crosses_water(a: Vector2, b: Vector2) -> bool:
	var n := int(a.distance_to(b) / 2.0) + 1
	for k in n + 1:
		var q := a.lerp(b, float(k) / n)
		if river_dist(q.x, q.y) < RIVER_W + 2.0: return true
		for lk in LAKES:
			if q.distance_to(lk[0]) < lk[1] + 2.0: return true
	return false

var town_paths: Array = []
func _plan_paths() -> void:
	# un chemin de terre relie chaque lieu à la route la plus proche
	var spurs: Array = []
	for q in POI_DEFS:
		var P: Vector2 = q.p
		var e := _nearest_on_roads(P)
		var d := P.distance_to(e)
		if d < 6.0 or d > 70.0 or _crosses_water(P, e): continue
		var mid: Vector2 = P.lerp(e, 0.5) + Vector2(-(e - P).y, (e - P).x).normalized() * min(6.0, d * 0.12)
		spurs.append([P, mid, e])
	roads += spurs



# Routes : là où elles croisent la rivière, on les fait passer bien perpendiculairement (ponts droits)
var roads: Array = []
func _make_roads() -> void:
	roads = []
	for r in ROADS:
		var out: Array = [r[0]]
		for i in r.size() - 1:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]
			var hit = null
			for RV in RIVERS:
				for k in RV.size() - 1:
					var x = Geometry2D.segment_intersects_segment(a, b, RV[k], RV[k + 1])
					if x != null: hit = [x, (RV[k + 1] - RV[k]).normalized()]; break
				if hit != null: break
			if hit != null:
				var c: Vector2 = hit[0]; var tang: Vector2 = hit[1]
				var dir := Vector2(-tang.y, tang.x)
				if dir.dot(b - a) < 0.0: dir = -dir
				var L := RIVER_W + 5.0
				out.append(c - dir * L); out.append(c + dir * L)
			out.append(b)
		roads.append(out)


static func polar(a: float, r: float) -> Vector3: return Vector3(cos(a) * r, 0, sin(a) * r)

# ——— Régions (frontières naturelles, déformées par du bruit) ———
func region_weights(x: float, z: float) -> Array:
	var wx := x + warp.get_noise_2d(x, z) * 22.0; var wz := z + warp.get_noise_2d(z + 300.0, x) * 22.0
	var d := []
	for i in range(1, REGIONS.size()):
		var R: Dictionary = REGIONS[i]
		d.append([Vector2(wx, wz).distance_to(R.c) - R.bias, i])
	if d.size() < 2: d.append(d[0])
	d.sort_custom(func(a, b): return a[0] < b[0])
	var t: float = clamp((d[1][0] - d[0][0]) / 14.0, 0.0, 1.0)   # transition douce sur ~14 m
	return [d[0][1], d[1][1], 0.5 + 0.5 * t]

func region_at(x: float, z: float) -> int: return 1 if x > 300.0 else region_weights(x, z)[0]
func tier_at(p: Vector3) -> int: return REGIONS[region_at(p.x, p.z)].tier

static func seg_dist(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a; var t: float = clamp((p - a).dot(ab) / max(0.0001, ab.length_squared()), 0.0, 1.0)
	return p.distance_to(a + ab * t)
static func poly_dist(p: Vector2, pts: Array) -> float:
	var d := 1e9
	for i in pts.size() - 1: d = min(d, seg_dist(p, pts[i], pts[i + 1]))
	return d
# Distance à la route la plus proche — grille de segments pour aller vite (appelée des dizaines de milliers de fois)
var _seg_grid := {}
var _seg_n := -1
func _build_seg_grid() -> void:
	_seg_grid = {}; _seg_n = roads.size()
	for r in roads:
		for i in r.size() - 1:
			var a: Vector2 = r[i]; var b: Vector2 = r[i + 1]
			var x0 := int(floor((min(a.x, b.x) - 16.0) / 16.0)); var x1 := int(floor((max(a.x, b.x) + 16.0) / 16.0))
			var z0 := int(floor((min(a.y, b.y) - 16.0) / 16.0)); var z1 := int(floor((max(a.y, b.y) + 16.0) / 16.0))
			for gx in range(x0, x1 + 1):
				for gz in range(z0, z1 + 1):
					var k := Vector2i(gx, gz)
					if not _seg_grid.has(k): _seg_grid[k] = []
					_seg_grid[k].append([a, b])
func road_dist(x: float, z: float) -> float:
	if _seg_n != roads.size(): _build_seg_grid()
	var cell = _seg_grid.get(Vector2i(int(floor(x / 16.0)), int(floor(z / 16.0))))
	if cell == null: return 16.0   # aucune route à moins de ~16 m
	var d := 16.0; var p := Vector2(x, z)
	for sg in cell: d = min(d, seg_dist(p, sg[0], sg[1]))
	return d
func river_dist(x: float, z: float) -> float:
	var d := 1e9
	for RV in RIVERS: d = min(d, poly_dist(Vector2(x, z), RV))
	return d

# ——— Relief selon le style de la région ———
func _style_h(style: String, x: float, z: float) -> float:
	var n := noise.get_noise_2d(x, z); var n2 := noise2.get_noise_2d(x, z)
	match style:
		"meadow": return (n * 0.5 + 0.5) * 2.4 + n2 * 0.4 + 0.2
		"forest": return (n * 0.5 + 0.5) * 3.6 + n2 * 0.8 + 0.3
		"hills":
			var v: float = (n * 0.5 + 0.5) * 4.0
			return floor(v) * 1.5 + smoothstep(0.5, 1.0, v - floor(v)) * 1.5 + n2 * 0.3   # terrasses aux pentes douces (franchissables)
		"swamp":
			var p := noise2.get_noise_2d(x * 0.9 + 40.0, z * 0.9)
			return (n * 0.5 + 0.5) * 1.2 + -2.0 * smoothstep(0.3, 0.62, p) + 0.3
		"ash":
			var v2: float = (n * 0.5 + 0.5) * 4.0
			return floor(v2) * 1.9 + smoothstep(0.45, 1.0, v2 - floor(v2)) * 1.9 + abs(n2) * 0.9
		"desert":
			# longues dunes ondulées
			var dn: float = sin(x * 0.07 + z * 0.035 + n * 3.0) * 0.5 + 0.5
			return dn * dn * 2.6 + (n * 0.5 + 0.5) * 0.8 + n2 * 0.15 + 0.3
		"canyon":
			# terrasses rouges du canyon (falaises franchissables par les pentes)
			var v3: float = (n * 0.5 + 0.5) * 4.2
			return floor(v3) * 1.7 + smoothstep(0.5, 1.0, v3 - floor(v3)) * 1.7 + abs(n2) * 0.5
	return 0.0

func raw_height(x: float, z: float) -> float:
	var w := region_weights(x, z)
	var a: float = _style_h(REGIONS[w[0]].style, x, z); var b: float = _style_h(REGIONS[w[1]].style, x, z)
	var h: float = lerp(b, a, w[2])
	# plateaux à falaises + chaîne de montagnes autour de la carte + volcan
	var pk := _plateau_w(x, z, w, 1)
	_last_pk = pk
	if pk > 0.0:
		var ph: float = lerp(float(PLATEAU_H.get(REGIONS[w[1]].style, 4.0)), float(PLATEAU_H.get(REGIONS[w[0]].style, 4.0)), w[2])
		var f1 := 1.0; var f2 := 1.0
		for rp in ramps:
			var rf := _ramp_f(Vector2(x, z), rp)
			if rp.lv == 1: f1 = min(f1, rf)
			else: f2 = min(f2, rf)
		var p2 := _plateau_w(x, z, w, 2, _last_clear)
		h += pk * ph * f1 + p2 * ph * 0.8 * min(f1, f2)
	var bk := border_k(x, z)
	if bk > 0.0: h += bk * 9.0 * (0.8 + 0.4 * (noise2.get_noise_2d(x * 0.6, z * 0.6) * 0.5 + 0.5))
	h += volcano_h(x, z)
	# routes : pente douce (rampe) au lieu des falaises
	var rd := road_dist(x, z)
	# bonus de hauteur des routes, fondu entre les régions (avant : une marche de 2,4 m sur la route à la frontière des collines)
	var ba: float = 1.4 if REGIONS[w[0]].style in ["hills", "ash", "canyon"] else 0.0
	var bb: float = 1.4 if REGIONS[w[1]].style in ["hills", "ash", "canyon"] else 0.0
	var smooth_h: float = (noise.get_noise_2d(x, z) * 0.5 + 0.5) * 1.5 + 0.2 + lerp(bb, ba, w[2])
	h = lerp(smooth_h, h, smoothstep(3.0, 9.0, rd))
	# village plat
	var vd := Vector2(x, z).distance_to(village)
	h = lerp(0.25, h, smoothstep(20.0, 30.0, vd))
	# lieux aplanis
	for p in POI_DEFS:
		var pd := Vector2(x, z).distance_to(p.p)
		if pd < p.r + 6.0: h = lerp(h * 0.3 + 0.3, h, smoothstep(p.r, p.r + 6.0, pd))
	# rivière et lacs
	var rv := river_dist(x, z)
	if rv < RIVER_W + 3.0: h = lerp(-1.8, h, smoothstep(RIVER_W * 0.55, RIVER_W + 3.0, rv))
	for lk in LAKES:
		var ld := Vector2(x, z).distance_to(lk[0])
		if ld < lk[1] + 3.0: h = lerp(-1.6, h, smoothstep(lk[1] * 0.6, lk[1] + 3.0, ld))
	# bords du monde : collines infranchissables
	var e: float = max(abs(x), abs(z))
	if e > 116.0: h += pow(e - 116.0, 1.5) * 0.9
	if BAY != null:
		var bd := Vector2(x, z).distance_to(BAY)
		if bd < 27.0: h = lerp(-2.4, h, smoothstep(15.0, 27.0, bd))
	return h

var dungeon: Node = null   # donjon actif (construit loin du monde, x > 300)

func height(x: float, z: float) -> float:
	if x > 300.0: return 0.0
	if hs.is_empty(): return raw_height(x, z)
	var fx: float = clamp((x + HALF) / CELL, 0.0, N - 1.001); var fz: float = clamp((z + HALF) / CELL, 0.0, N - 1.001)
	var i := int(fx); var j := int(fz); var u := fx - i; var v := fz - j
	var k := j * N + i
	return hs[k] * (1 - u) * (1 - v) + hs[k + 1] * u * (1 - v) + hs[k + N] * (1 - u) * v + hs[k + N + 1] * u * v

func on_bridge(x: float, z: float) -> bool:
	for b in bridges:
		if seg_dist(Vector2(x, z), b.a, b.b) < 2.3: return true
	return false

# hauteur du sol « praticable » : tablier des ponts et du quai compris
func ground_y(x: float, z: float) -> float:
	if x > 300.0: return 0.0
	for b in bridges:
		if seg_dist(Vector2(x, z), b.a, b.b) < 2.3:
			if b.prof.is_empty(): return 0.5
			var ab: Vector2 = b.b - b.a; var t: float = clamp((Vector2(x, z) - b.a).dot(ab) / max(0.001, ab.length_squared()), 0.0, 1.0)
			var f: float = t * (b.prof.size() - 1); var i := int(f)
			var p0: Vector3 = b.prof[min(i, b.prof.size() - 1)]; var p1: Vector3 = b.prof[min(i + 1, b.prof.size() - 1)]
			return max(lerp(p0.y, p1.y, f - i), height(x, z))
	return height(x, z)

func walkable(x: float, z: float) -> bool:
	if x > 300.0: return dungeon != null and dungeon.walkable(x, z)
	if not blocked.is_empty():
		var i := int(round((x + HALF) / CELL)); var j := int(round((z + HALF) / CELL))
		if i < 0 or j < 0 or i >= N or j >= N or blocked[j * N + i] == 1: return false
	return height(x, z) > WATER_Y + 0.15 or on_bridge(x, z)

func slope(x: float, z: float) -> float:
	return abs(height(x + 1, z) - height(x - 1, z)) + abs(height(x, z + 1) - height(x, z - 1))

# ================= CONSTRUCTION =================
func build(id := 1) -> void:
	setup_map(id)
	_terrain()
	_water()
	_bridges()
	_compute_blocked()
	_compute_reach()
	if MAP.town.kind == "valdrune": _village()
	else: _town(MAP.town)
	_town_dressing()
	_ground_decals()
	_faubourgs()
	for p in POI_DEFS: _poi(p)
	_gates()
	_road_props()
	_cliffs()
	_volcano_fx()
	_resources()
	_duelists()
	_decor()
	_monster_camps()
	_hidden_chests()
	if BAY != null: _harbor()
	for path in mm_lists: _multi(path, mm_lists[path])
	_build_cliffs()
	_cull(self)

# Rien d'inutile à l'écran : chaque objet disparaît au-delà de ce que la caméra peut voir
func _cull(n: Node) -> void:
	if n is GeometryInstance3D:
		var g := n as GeometryInstance3D
		if g.visibility_range_end == 0.0:
			var big := false
			if g is MeshInstance3D and (g as MeshInstance3D).mesh:
				var sz: Vector3 = (g as MeshInstance3D).mesh.get_aabb().size * g.global_transform.basis.get_scale()
				big = max(sz.x, sz.z) > 60.0
			if not big: g.visibility_range_end = 30.0 if (g is Label3D or g is Sprite3D) else 48.0
		if g is Label3D or g is Sprite3D: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		elif g is MeshInstance3D and (g as MeshInstance3D).mesh:
			# seuls les grands bâtiments gardent une vraie ombre
			var ab: AABB = (g as MeshInstance3D).mesh.get_aabb(); var sc3: Vector3 = g.global_transform.basis.get_scale()
			if ab.size.y * sc3.y < 4.5 or max(ab.size.x * sc3.x, ab.size.z * sc3.z) < 3.0: g.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	for c in n.get_children(): _cull(c)

func _ground_color(x: float, z: float, h: float, sl: float) -> Color:
	var w := region_weights(x, z)
	var A: Dictionary = REGIONS[w[0]]; var B: Dictionary = REGIONS[w[1]]
	var n := noise2.get_noise_2d(x * 2.0, z * 2.0) * 0.5 + 0.5
	var ca := Color(A.g0).lerp(Color(A.g1), n); var cb := Color(B.g0).lerp(Color(B.g1), n)
	var c := cb.lerp(ca, w[2]).darkened(0.1)
	# grandes nappes de couleur (prés plus clairs, sous-bois plus sombres) : le sol n'est plus uniforme
	var tone := pnoise.get_noise_2d(x * 2.3 + 300.0, z * 2.3)
	c = c.lightened(clamp(tone, 0.0, 1.0) * 0.22).darkened(clamp(-tone, 0.0, 1.0) * 0.18)
	var gi := int(round((x + HALF) / CELL)); var gj := int(round((z + HALF) / CELL))
	if pgrid.size() == N * N and pgrid[clamp(gj, 0, N - 1) * N + clamp(gi, 0, N - 1)] > 0.5: c = c.lerp(Color(c.r * 1.08, c.g * 1.12, c.b * 0.9), 0.6)   # dessus des plateaux, herbe plus vive
	var rock := {"ash": Color("#4a3a38"), "canyon": Color("#8a3e2a"), "desert": Color("#b8925a")}.get(A.style, Color("#7a7064")) as Color
	if sl > 1.6: c = c.lerp(rock, clamp((sl - 1.6) * 0.4, 0.0, 0.9))   # roche des falaises
	var vk := volcano_k(x, z)
	if vk > 0.0:
		c = c.lerp(Color("#3a302e"), clamp(vk * 1.6, 0.0, 0.85))
		if vk > 0.78: c = c.lerp(Color("#ff5a1a"), clamp((vk - 0.78) * 6.0, 0.0, 1.0))   # lave du cratère
	var rd := road_dist(x, z)
	for rp in ramps: rd = min(rd, seg_dist(Vector2(x, z), rp.a, rp.b) + 0.4)
	if rd < 3.0: c = c.lerp(Color("#a8916a"), (1.0 - smoothstep(1.6, 3.0, rd)) * 0.95)
	var vd := Vector2(x, z).distance_to(village)
	if vd < 11.0: c = c.lerp(Color("#a8916a"), 1.0 - smoothstep(8.0, 11.0, vd))

	if h < WATER_Y + 0.6: c = c.lerp(Color("#c9b98a") if A.style != "swamp" else Color("#6a6a4a"), clamp((WATER_Y + 0.6 - h) * 1.2, 0.0, 0.8))   # berges
	return c

func _terrain() -> void:
	N = int(HALF * 2.0 / CELL) + 1
	hs.resize(N * N); pgrid.resize(N * N)
	for j in N:
		for i in N:
			_last_clear = -1.0
			hs[j * N + i] = raw_height(-HALF + i * CELL, -HALF + j * CELL)
			pgrid[j * N + i] = _last_pk
	var cols := PackedColorArray(); cols.resize(N * N)
	for j in N:
		for i in N:
			var x := -HALF + i * CELL; var z := -HALF + j * CELL
			cols[j * N + i] = _ground_color(x, z, hs[j * N + i], slope(x, z))
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for j in N - 1:
		for i in N - 1:
			var x0 := -HALF + i * CELL; var z0 := -HALF + j * CELL
			var k := [j * N + i, j * N + i + 1, (j + 1) * N + i, (j + 1) * N + i + 1]
			for id in [k[0], k[1], k[2], k[1], k[3], k[2]]:
				st.set_color(cols[id]); st.add_vertex(Vector3(-HALF + (id % N) * CELL, hs[id], -HALF + (id / N) * CELL))
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	mi.material_override = ground_mat(); add_child(mi)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var hm := HeightMapShape3D.new()
	hm.map_width = N; hm.map_depth = N; hm.map_data = hs
	cs.shape = hm; cs.scale = Vector3(CELL, 1, CELL); body.add_child(cs); add_child(body)

func _water() -> void:
	var mi := MeshInstance3D.new(); var pm := PlaneMesh.new(); pm.size = Vector2(HALF * 2, HALF * 2); mi.mesh = pm
	# carte de profondeur (pour l'écume des rives et la couleur du fond)
	var R := 256; var img := Image.create(R, R, false, Image.FORMAT_L8)
	for j in R:
		for i in R:
			var x := -HALF + (i + 0.5) * (HALF * 2.0 / R); var z := -HALF + (j + 0.5) * (HALF * 2.0 / R)
			var d: float = clamp((WATER_Y - height(x, z)) / 1.2, 0.0, 1.0)
			img.set_pixel(i, j, Color(d, d, d))
	var sh := Shader.new(); sh.code = """shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_schlick_ggx;
uniform sampler2D depth_map : filter_linear;
uniform float half_size = 128.0;
uniform vec3 shallow = vec3(0.32, 0.78, 0.82);
uniform vec3 deep = vec3(0.10, 0.36, 0.62);
void fragment(){
	vec3 wp = (INV_VIEW_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 uv = (wp.xz + half_size) / (half_size * 2.0);
	float dep = texture(depth_map, uv).r;
	float t = TIME;
	float w1 = sin(wp.x * 0.9 + t * 1.3) * sin(wp.z * 0.7 - t * 1.1);
	float w2 = sin(wp.x * 2.3 - t * 2.0 + wp.z * 1.7) * 0.5;
	float ripple = (w1 + w2) * 0.5 + 0.5;
	vec3 col = mix(shallow, deep, smoothstep(0.05, 0.85, dep));
	col += vec3(0.08, 0.1, 0.1) * ripple;
	float foam = smoothstep(0.22, 0.0, dep) * (0.55 + 0.45 * sin(t * 2.2 + wp.x * 1.3 + wp.z * 1.1));
	col = mix(col, vec3(0.95, 0.98, 1.0), foam * 0.8);
	ALBEDO = col;
	ROUGHNESS = 0.08; METALLIC = 0.0; SPECULAR = 0.7;
	NORMAL = normalize(NORMAL + vec3(w1 * 0.08, 0.0, w2 * 0.08));
	ALPHA = mix(0.62, 0.9, smoothstep(0.0, 0.6, dep)) + foam * 0.2;
}"""
	var m := ShaderMaterial.new(); m.shader = sh; m.set_shader_parameter("depth_map", ImageTexture.create_from_image(img)); m.set_shader_parameter("half_size", HALF)
	if map_id == 4: m.set_shader_parameter("shallow", Vector3(0.36, 0.5, 0.38)); m.set_shader_parameter("deep", Vector3(0.12, 0.24, 0.22))
	elif map_id == 3: m.set_shader_parameter("shallow", Vector3(0.3, 0.85, 0.8)); m.set_shader_parameter("deep", Vector3(0.06, 0.45, 0.55))
	mi.material_override = m; mi.position.y = WATER_Y; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)

func _bridges() -> void:
	for road in roads:
		for i in road.size() - 1:
			var a: Vector2 = road[i]; var b: Vector2 = road[i + 1]
			var n := int(a.distance_to(b)); var inside := false; var start := Vector2.ZERO
			for k in n + 1:
				var p := a.lerp(b, float(k) / n)
				var wet := river_dist(p.x, p.y) < RIVER_W + 1.2
				if wet and not inside: inside = true; start = p
				elif not wet and inside:
					inside = false
					# pont bien droit : perpendiculaire à la rivière, centré sur la traversée
					var mid := (start + p) * 0.5
					var tang := _river_tangent(mid)
					var dir := Vector2(-tang.y, tang.x)
					if dir.dot(p - start) < 0.0: dir = -dir
					var e0 := mid - dir * (RIVER_W * 0.8); var e1 := mid + dir * (RIVER_W * 0.8)
					# prolonge jusqu'à un sol bien sec des deux côtés
					var k0 := 0; var k1 := 0
					while raw_height(e0.x, e0.y) < WATER_Y + 0.6 and k0 < 30: e0 -= dir * 0.5; k0 += 1
					while raw_height(e1.x, e1.y) < WATER_Y + 0.6 and k1 < 30: e1 += dir * 0.5; k1 += 1
					_bridge(e0 - dir * 1.0, e1 + dir * 1.0)

func _river_tangent(p: Vector2) -> Vector2:
	var best := Vector2.RIGHT; var bd := 1e9
	for RV in RIVERS:
		for i in RV.size() - 1:
			var d := seg_dist(p, RV[i], RV[i + 1])
			if d < bd: bd = d; best = (RV[i + 1] - RV[i]).normalized()
	return best

func _bridge(a: Vector2, b: Vector2) -> void:
	for ob in bridges:
		if ((ob.a + ob.b) * 0.5).distance_to((a + b) * 0.5) < 10.0: return   # pas deux ponts au même endroit
	# Tablier en rampe : il part du sol de chaque berge (aucune marche à franchir) et passe au-dessus de l'eau
	var ha := raw_height(a.x, a.y) - 0.05; var hb := raw_height(b.x, b.y) - 0.05
	var len := a.distance_to(b); var dir := (b - a) / len; var right := Vector3(dir.y, 0, -dir.x)
	var n := int(len / 0.8) + 1
	var prof := []
	for k in n + 1:
		var t := float(k) / n
		var y: float = lerp(ha, hb, t)
		var mid_lift: float = max(0.0, WATER_Y + 0.9 - y) * sin(PI * t) + 0.35 * sin(PI * t)   # arche au-dessus de l'eau
		prof.append(Vector3(a.x + (b.x - a.x) * t, y + mid_lift, a.y + (b.y - a.y) * t))
	bridges.append({"a": a, "b": b, "prof": prof})
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var faces := PackedVector3Array()
	for k in n:
		var p0: Vector3 = prof[k]; var p1: Vector3 = prof[k + 1]
		var q := [p0 - right * 2.0, p0 + right * 2.0, p1 - right * 2.0, p1 + right * 2.0]
		for v in [q[0], q[2], q[1], q[1], q[2], q[3]]: st.add_vertex(v); faces.append(v)
		# épaisseur (côtés)
		for sd in [-2.0, 2.0]:
			var e0: Vector3 = p0 + right * sd; var e1: Vector3 = p1 + right * sd
			for v in [e0, e1, e0 - Vector3(0, 0.3, 0), e1, e1 - Vector3(0, 0.3, 0), e0 - Vector3(0, 0.3, 0)]: st.add_vertex(v)
	st.generate_normals()
	var deck := MeshInstance3D.new(); deck.mesh = st.commit()
	var wood := StandardMaterial3D.new(); wood.albedo_color = Color("#9a6a40"); wood.roughness = 0.9; wood.cull_mode = BaseMaterial3D.CULL_DISABLED; deck.material_override = wood
	add_child(deck)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var shape := ConcavePolygonShape3D.new(); shape.set_faces(faces); shape.backface_collision = true
	cs.shape = shape; body.add_child(cs); add_child(body)
	# garde-corps (visuels + physiques)
	var dm := StandardMaterial3D.new(); dm.albedo_color = Color("#6b4428")
	var rst := SurfaceTool.new(); rst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for sd in [-1.9, 1.9]:
		var wall := PackedVector3Array()
		for k in n + 1:
			var p: Vector3 = prof[k] + right * sd
			if k % 3 == 0 or k == n:
				var pb := BoxMesh.new(); pb.size = Vector3(0.18, 0.95, 0.18)
				rst.append_from(pb, 0, Transform3D(Basis(), p + Vector3(0, 0.45, 0)))
			if k < n:
				var p1: Vector3 = prof[k + 1] + right * sd
				var rm := BoxMesh.new(); rm.size = Vector3(0.12, 0.12, p.distance_to(p1) + 0.05)
				var mid: Vector3 = (p + p1) * 0.5 + Vector3(0, 0.9, 0)
				rst.append_from(rm, 0, Transform3D(Basis.looking_at(p1 - p, Vector3.UP), mid))
				for v in [p, p1, p + Vector3(0, 1.4, 0), p1, p1 + Vector3(0, 1.4, 0), p + Vector3(0, 1.4, 0)]: wall.append(v)
		var wb := StaticBody3D.new(); var wc := CollisionShape3D.new(); var ws := ConcavePolygonShape3D.new(); ws.set_faces(wall); ws.backface_collision = true
		wc.shape = ws; wb.add_child(wc); add_child(wb)
	var rails := MeshInstance3D.new(); rails.mesh = rst.commit(); rails.material_override = dm; add_child(rails)

func place(path: String, pos: Vector3, rot := 0.0, sc := 1.0, ground := true) -> Node3D:
	if not proto.has(path): proto[path] = load(path)
	var o: Node3D = proto[path].instantiate()
	if ground: pos.y = height(pos.x, pos.z) - 0.05
	o.position = pos; o.rotation.y = rot; o.scale = Vector3.ONE * sc; add_child(o); _last_placed = o
	if sc >= 0.8 and not path.ends_with("chest.gltf") and not path.ends_with("chest_gold.gltf"):
		var gk := Vector2i(int(floor(pos.x / 8.0)), int(floor(pos.z / 8.0)))
		if not placed_grid.has(gk): placed_grid[gk] = []
		placed_grid[gk].append(o)
	return o

func blocker(pos: Vector3, radius: float, h := 3.0) -> StaticBody3D:
	var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var cy := CylinderShape3D.new(); cy.radius = radius; cy.height = h
	c.shape = cy; b.add_child(c); b.position = Vector3(pos.x, height(pos.x, pos.z) + h * 0.5, pos.z); add_child(b)
	return b

func box_blocker(pos: Vector3, size: Vector3, rot := 0.0) -> void:
	var b := StaticBody3D.new(); var c := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = size
	c.shape = bx; b.add_child(c); b.position = Vector3(pos.x, height(pos.x, pos.z) + size.y * 0.5, pos.z); b.rotation.y = rot; add_child(b)

func building(path: String, p: Vector2, rot: float, sc: float, foot: float) -> void:
	place(path, Vector3(p.x, 0, p.y), rot, sc); box_blocker(Vector3(p.x, 0, p.y), Vector3(foot, 5, foot), rot)

func label(txt: String, pos: Vector3, col: Color, size := 48) -> Label3D:
	var l := Label3D.new(); l.text = txt; l.font_size = size; l.outline_size = 14; l.modulate = col; l.outline_modulate = Color(0, 0, 0, 0.8)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.008; l.position = pos; add_child(l); return l

# ——— Le village de Valdrune ———
func _village() -> void:
	var V := village
	var H := "res://assets/hex/"
	building(H + "building_blacksmith_blue.gltf", V + Vector2(-13, -10), PI * 0.1, 5.0, 6.0)
	building(H + "building_market_blue.gltf", V + Vector2(13, -10), -PI * 0.1, 5.0, 7.0)
	building(H + "building_tavern_blue.gltf", V + Vector2(-15, 8), PI * 0.5, 5.0, 6.5)
	building(H + "building_church_blue.gltf", V + Vector2(15, 10), -PI * 0.5, 5.0, 6.5)
	building(H + "building_home_A_blue.gltf", V + Vector2(-26, -2), PI * 0.3, 4.6, 5.0)
	building(H + "building_home_B_blue.gltf", V + Vector2(26, -1), -PI * 0.3, 4.6, 5.0)
	building(H + "building_home_A_blue.gltf", V + Vector2(-20, 22), PI * 0.7, 4.6, 5.0)
	building(H + "building_home_B_blue.gltf", V + Vector2(-8, 28), -PI * 0.2, 4.6, 5.0)   # (avant : posée sur le ponton du port)
	building(H + "building_well_blue.gltf", V + Vector2(0, 0), 0.0, 3.0, 2.2)
	# Hôtel des ventes
	building(H + "building_barracks_blue.gltf", V + Vector2(-25, -17), PI * 0.25, 5.0, 6.5)
	label("HÔTEL DES VENTES", Vector3(V.x - 25, 8.0, V.y - 17), Color("#ffd27a"), 60)
	for q in [V + Vector2(-20, -12), V + Vector2(-29, -11)]: place("res://assets/dungeon/banner_patternA_red.gltf", Vector3(q.x, 0, q.y), PI * 0.25, 1.0)
	forge_pos = Vector3(V.x - 9, 0, V.y - 7); shop_pos = Vector3(V.x + 9, 0, V.y - 7)
	place("res://assets/dungeon/table_medium_decorated_A.gltf", forge_pos + Vector3(-1.6, 0, -0.6), 0.2, 0.9); blocker(forge_pos + Vector3(-1.6, 0, -0.6), 0.8)
	place(H + "weaponrack.gltf", forge_pos + Vector3(-3.4, 0, 0.4), 0.4, 6.0)
	place("res://assets/dungeon/barrel_large.gltf", shop_pos + Vector3(2.4, 0, -0.6), 0.0, 0.6); blocker(shop_pos + Vector3(2.4, 0, -0.6), 0.6)
	place("res://assets/dungeon/crates_stacked.gltf", shop_pos + Vector3(3.6, 0, 1.0), 0.4, 0.6); blocker(shop_pos + Vector3(3.6, 0, 1.0), 0.8)
	place(H + "sack.gltf", shop_pos + Vector3(-2.0, 0, -0.8), 0.0, 6.0)
	# lanternes le long des chemins
	for p in [V + Vector2(-4, -14), V + Vector2(4, -14), V + Vector2(-4, 14), V + Vector2(4, 14), V + Vector2(-3, -26), V + Vector2(3, -26)]:
		place("res://assets/halloween/lantern_standing.gltf", Vector3(p.x, 0, p.y), 0.0, 1.6); blocker(Vector3(p.x, 0, p.y), 0.3)
		_light(Vector3(p.x, height(p.x, p.y) + 2.5, p.y), Color("#ffbf66"), 2.0, 2.5)
	# champs clôturés
	house_spots.append([V + Vector2(-32, 20), 11.0])
	for row in 4:
		for k in 7:
			_mm("res://assets/forest/Grass_2_D_Color1.gltf", Vector3(V.x - 40 + k * 2.4, 0, V.y + 16 + row * 2.6), 1.3, 0.0)
	for p in [V + Vector2(-6, -18), V + Vector2(6, -18)]:
		place("res://assets/dungeon/banner_patternB_blue.gltf", Vector3(p.x, 0, p.y), 0.0, 1.0)
	label("VALDRUNE", Vector3(V.x, 7.0, V.y - 18), Color("#ffe2a0"), 90)
	# zone sûre
	npc_spots.append({"id": "brokk", "model": "Barbarian", "name": "Brokk", "role": "Armurier · forge", "pos": forge_pos + Vector3(0.6, 0, 1.2), "act": "forge"})
	npc_spots.append({"id": "mara", "model": "Rogue", "name": "Mara", "role": "Marchande", "pos": shop_pos + Vector3(-0.6, 0, 1.2), "act": "shop"})
	npc_spots.append({"id": "corvin", "model": "Rogue", "name": "Corvin", "role": "Hôtel des ventes", "pos": Vector3(V.x - 21, 0, V.y - 13), "act": "auction"})
	npc_spots.append({"id": "aldric", "model": "Mage", "name": "Aldric", "role": "Ancien du village", "pos": Vector3(V.x + 3.5, 0, V.y + 3.0), "act": "quest"})
	npc_spots.append({"id": "hilda", "model": "Rogue", "name": "Hilda", "role": "Aubergiste", "pos": Vector3(V.x - 11, 0, V.y + 8), "act": "talk"})
	npc_spots.append({"id": "gael", "model": "Knight", "name": "Sire Gaël", "role": "Garde", "pos": Vector3(V.x + 3, 0, V.y - 24), "act": "talk"})
	npc_spots.append({"id": "lina", "model": "Ranger", "name": "Lina", "role": "Villageoise", "pos": Vector3(V.x - 6, 0, V.y + 4), "act": "talk", "path": [V + Vector2(-6, 4), V + Vector2(-6, -6), V + Vector2(6, -6), V + Vector2(6, 6)]})
	npc_spots.append({"id": "pip", "model": "Rogue", "name": "Pip", "role": "Gamin du village", "pos": Vector3(V.x + 5, 0, V.y + 16), "act": "talk", "scale": 0.75, "path": [V + Vector2(5, 16), V + Vector2(-8, 18), V + Vector2(-2, 26)]})
	npc_spots.append({"id": "bram", "model": "Barbarian", "name": "Bram", "role": "Fermier", "pos": Vector3(V.x - 32, 0, V.y + 20), "act": "talk", "path": [V + Vector2(-38, 18), V + Vector2(-26, 18), V + Vector2(-26, 24), V + Vector2(-38, 24)]})
	npc_spots.append({"id": "bjorn", "model": "Barbarian", "name": "Bjorn", "role": "Haches · bûcheron", "pos": Vector3(V.x - 8, 0, V.y + 16), "act": "tools", "tool": "hache"})
	npc_spots.append({"id": "gorm", "model": "Knight", "name": "Gorm", "role": "Pioches · mineur", "pos": Vector3(V.x + 8, 0, V.y + 16), "act": "tools", "tool": "pioche"})
	npc_spots.append({"id": "sylve", "model": "Ranger", "name": "Sylve", "role": "Faucilles · herboriste", "pos": Vector3(V.x + 9, 0, V.y + 2), "act": "tools", "tool": "faucille"})
	for q in [V + Vector2(-10.5, 17.5)]: place("res://assets/hex/resource_lumber.gltf", Vector3(q.x, 0, q.y), 0.3, 3.0)
	for q in [V + Vector2(10.5, 17.5)]: place("res://assets/forest/Rock_1_J_Color1.gltf", Vector3(q.x, 0, q.y), 0.3, 0.45)
	npc_spots.append({"id": "rhea", "model": "Knight", "name": "Rhéa", "role": "Capitaine des mercenaires", "pos": Vector3(V.x - 19, 0, V.y + 13), "act": "mercs"})
	npc_spots.append({"id": "passeur_1", "model": "Ranger", "name": "Fenn", "role": "Passeur · voyages rapides", "pos": Vector3(V.x - 5, 0, V.y - 22), "act": "travel"})

# ——— Lieux ———
func _poi(p: Dictionary) -> void:
	var P: Vector2 = p.p; var y := height(P.x, P.y)
	var H := "res://assets/hex/"; var HW := "res://assets/halloween/"; var DG := "res://assets/dungeon/"
	match p.kind:
		"shrine":
			for i in 6:
				var q := P + Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 4.0
				place(DG + "pillar.gltf", Vector3(q.x, 0, q.y), 0.0, 0.8); blocker(Vector3(q.x, 0, q.y), 0.5)
			place(HW + "shrine_candles.gltf", Vector3(P.x, 0, P.y), 0.0, 1.8); blocker(Vector3(P.x, 0, P.y), 0.8)
			_light(Vector3(P.x, y + 1.6, P.y), Color("#ffcf7a"), 1.5, 6.0)
		"windmill":
			building(H + "building_windmill_blue.gltf", P, 0.4, 5.0, 4.0); _spin_windmill()
			place(H + "wheelbarrow.gltf", Vector3(P.x + 4, 0, P.y + 2), 0.6, 5.0)
		"pond":
			for i in 5:
				var q := P + Vector2(cos(i * 1.3) * 9.0, sin(i * 1.3) * 9.0)
				_mm("res://assets/forest/Tree_2_A_Color1.gltf", Vector3(q.x, 0, q.y), 1.2, rng.randf() * TAU)
		"lumbercamp":
			building(H + "building_lumbermill_blue.gltf", P, PI * 0.5, 5.0, 6.0)
			for k in 4: place(H + "resource_lumber.gltf", Vector3(P.x + 5 + k * 1.8, 0, P.y + 5), k, 4.0)
			place(H + "tent.gltf", Vector3(P.x - 6, 0, P.y + 4), 0.6, 5.0); blocker(Vector3(P.x - 6, 0, P.y + 4), 1.2)
			npc_spots.append({"id": "tomas", "model": "Barbarian", "name": "Tomas", "role": "Bûcheron", "pos": Vector3(P.x + 2, 0, P.y + 5), "act": "talk"})
		"bigtree":
			place("res://assets/forest/Tree_1_C_Color1.gltf", Vector3(P.x, 0, P.y), 0.3, 3.0); blocker(Vector3(P.x, 0, P.y), 2.0, 8.0)
			for i in 8:
				var q := P + Vector2(cos(i * 0.8), sin(i * 0.8)) * 6.0
				_mm("res://assets/forest/Bush_1_E_Color1.gltf", Vector3(q.x, 0, q.y), 1.5, i)
		"camp":
			for i in 3: place(H + "tent.gltf", Vector3(P.x + cos(i * 2.1) * 5.0, 0, P.y + sin(i * 2.1) * 5.0), -i * 2.1, 5.0)
			place(DG + "banner_patternA_red.gltf", Vector3(P.x, 0, P.y - 6), 0.0, 1.0)
			_light(Vector3(P.x, y + 0.8, P.y), Color("#ff8a40"), 2.0, 7.0)
		"mine":
			building(H + "building_mine_blue.gltf", P, -PI * 0.5, 5.0, 6.0)
			for k in 3: place(DG + "box_stacked.gltf", Vector3(P.x - 5, 0, P.y - 2 + k * 2.2), k, 0.5)
			_light(Vector3(P.x - 3, y + 2.2, P.y), Color("#ffa040"), 1.6, 6.0)
			npc_spots.append({"id": "ilse", "model": "Ranger", "name": "Ilse", "role": "Prospectrice", "pos": Vector3(P.x - 4, 0, P.y + 4), "act": "talk"})
		"tower":
			building(H + "building_tower_B_blue.gltf", P, 0.3, 5.0, 4.0)
			for i in 5: place(DG + "rubble_large.gltf", Vector3(P.x + cos(i) * 5.0, 0, P.y + sin(i) * 5.0), i, 0.45)
		"stones":
			for i in 9:
				var q := P + Vector2(cos(i * TAU / 9.0), sin(i * TAU / 9.0)) * 6.0
				place("res://assets/forest/Rock_3_M_Color1.gltf", Vector3(q.x, 0, q.y), i, 0.9); blocker(Vector3(q.x, 0, q.y), 1.0)
			_light(Vector3(P.x, y + 1.0, P.y), Color("#8ad6ff"), 2.0, 8.0)
		"castle":
			building(H + "building_destroyed.gltf", P, 0.2, 6.0, 6.0)
			for i in 10:
				if i == 3: continue
				var q := P + Vector2(cos(i * TAU / 10.0), sin(i * TAU / 10.0)) * 11.0
				place(DG + "wall_broken.gltf", Vector3(q.x, 0, q.y), -i * TAU / 10.0 + PI / 2, 1.0); blocker(Vector3(q.x, 0, q.y), 1.2)
		"graveyard":
			for k in 16:
				var q := P + Vector2((k % 4 - 1.5) * 3.2, (k / 4 - 1.5) * 3.2)
				place(HW + ["gravestone.gltf", "grave_A.gltf", "grave_B.gltf", "gravemarker_A.gltf"][k % 4], Vector3(q.x, 0, q.y), rng.randf_range(-0.3, 0.3), 1.2)
			place(HW + "crypt.gltf", Vector3(P.x, 0, P.y - 9), 0.0, 1.2); box_blocker(Vector3(P.x, 0, P.y - 9), Vector3(5, 4, 5))
			for q in [P + Vector2(-7, 7), P + Vector2(7, 7)]: place(HW + "post_lantern.gltf", Vector3(q.x, 0, q.y), 0.0, 1.4)
		"hut":
			building(H + "building_home_B_blue.gltf", P, 0.8, 4.4, 4.5)
			npc_spots.append({"id": "ermite", "model": "Mage", "name": "Fenwick", "role": "Ermite", "pos": Vector3(P.x + 3, 0, P.y + 3), "act": "talk"})
		"altar":
			place(HW + "shrine_candles.gltf", Vector3(P.x, 0, P.y), 0.0, 2.2); blocker(Vector3(P.x, 0, P.y), 1.0)
			for i in 6: place(HW + "skull_candle.gltf", Vector3(P.x + cos(i) * 3.5, 0, P.y + sin(i) * 3.5), i, 1.5)
			_light(Vector3(P.x, y + 1.5, P.y), Color("#ff5030"), 2.5, 8.0)
		"deadforge":
			building(H + "building_destroyed.gltf", P, 1.1, 5.0, 5.0)
			place(DG + "sword_shield_broken.gltf", Vector3(P.x + 4, 0, P.y + 3), 0.4, 1.0)
		"tower_inf":
			# château de la Tour Infinie + grand portail bleu
			building("res://assets/hex/building_castle_blue.gltf", P + Vector2(0, -3.5), 0.0, 6.5, 7.5)
			for sx in [-1.0, 1.0]:
				building("res://assets/hex/building_tower_A_blue.gltf", P + Vector2(sx * 7.5, -1.5), 0.0, 5.0, 3.6)
				place("res://assets/dungeon/banner_patternB_blue.gltf", Vector3(P.x + sx * 3.4, 0, P.y + 2.6), 0.0, 1.3)
			tower_portal = Vector3(P.x, height(P.x, P.y + 4.0), P.y + 4.0)
			_blue_portal(tower_portal)
			beam(Vector3(P.x, y, P.y - 3.5), Color(0.45, 0.75, 1.0), self)
			_signpost(village + (P - village).normalized() * 20.0, P, "TOUR INFINIE →", Color("#9fd4ff"))
			label("TOUR INFINIE", Vector3(P.x, y + 11.5, P.y), Color("#9fd4ff"), 84)
		"enchant":
			for i in 6:
				var q := P + Vector2(cos(i * TAU / 6.0), sin(i * TAU / 6.0)) * 4.2
				place(DG + "pillar_decorated.gltf", Vector3(q.x, 0, q.y), -i * TAU / 6.0, 0.55); blocker(Vector3(q.x, 0, q.y), 0.5)
			place(HW + "shrine_candles.gltf", Vector3(P.x, 0, P.y - 0.8), 0.0, 1.6); blocker(Vector3(P.x, 0, P.y - 0.8), 0.8)
			for i in 3:
				var cr := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.25; cm.height = 1.1; cm.radial_segments = 6; cr.mesh = cm
				var mm := StandardMaterial3D.new(); mm.albedo_color = Color("#c77dff"); mm.emission_enabled = true; mm.emission = Color("#b45cff"); mm.emission_energy_multiplier = 1.4; cr.material_override = mm
				cr.position = Vector3(P.x + cos(i * 2.1) * 1.2, y + 2.4, P.y - 0.8 + sin(i * 2.1) * 1.2); add_child(cr)
				var tw := cr.create_tween().set_loops(); tw.tween_property(cr, "position:y", y + 2.9, 1.4 + i * 0.2).set_trans(Tween.TRANS_SINE); tw.tween_property(cr, "position:y", y + 2.4, 1.4 + i * 0.2).set_trans(Tween.TRANS_SINE)
			_ring(Vector3(P.x, 0, P.y), 3.0, Color(0.75, 0.4, 1.0, 0.6), 0.1)
			_light(Vector3(P.x, y + 2.6, P.y - 0.8), Color("#b45cff"), 2.6, 7.0)
			label("ENCHANTEMENTS", Vector3(P.x, y + 5.0, P.y), Color("#e3b8ff"), 56)
			npc_spots.append({"id": "ysaline", "model": "Mage", "name": "Ysaline", "role": "Enchanteresse", "pos": Vector3(P.x + 1.8, 0, P.y + 1.8), "act": "enchant"})
		"hamlet":
			# petite ferme isolée : maison, grange à grain, clôtures, foin, puits
			building(H + "building_home_A_blue.gltf", P + Vector2(-3, -2), rng.randf() * TAU, 4.2, 4.8)
			building(H + "building_grain.gltf", P + Vector2(5, 1), 0.3, 3.4, 3.0)
			for q in [P + Vector2(4, 5), P + Vector2(6, 4)]: place(H + "sack.gltf", Vector3(q.x, 0, q.y), rng.randf() * TAU, 4.0)
			place("res://assets/dungeon/crates_stacked.gltf", Vector3(P.x - 7, 0, P.y + 2), 0.4, 0.6); blocker(Vector3(P.x - 7, 0, P.y + 2), 0.7)
			place(H + "wheelbarrow.gltf", Vector3(P.x + 1, 0, P.y + 4), 1.1, 4.0)
			for k in 10: _mm("res://assets/forest/Grass_2_D_Color1.gltf", Vector3(P.x - 5 + (k % 5) * 2.4, 0, P.y + 9 + int(k / 5) * 2.4), 1.3, 0.0)
			_light(Vector3(P.x - 3, y + 2.4, P.y + 1), Color("#ffbf66"), 1.6, 2.5)
			npc_spots.append({"id": p.id, "model": ["Barbarian", "Ranger", "Knight"][rng.randi() % 3], "name": ["Fermier Joss", "Fermière Ada", "Vieux Bastien", "Fermière Mila"][rng.randi() % 4], "role": "Fermier", "pos": Vector3(P.x + 1, 0, P.y + 2), "act": "talk"})
		"arena":
			# arène : cercle de poteaux, bannières, sable tassé
			for i in 14:
				var a := TAU * i / 14.0
				if sin(a) > 0.9: continue   # ouverture côté caméra
				var q := P + Vector2(cos(a), sin(a)) * 13.0
				if i % 2 == 0: place(crystal("ROCK_Ancient_02_RuinedPillar"), Vector3(q.x, 0, q.y), -a, 1.15); blocker(Vector3(q.x, 0, q.y), 0.6)
				else: place(crystal("ROCK_Ancient_03_PlinthMedium"), Vector3(q.x, 0, q.y), -a, 0.9)
			for q in [P + Vector2(-13, -4), P + Vector2(13, -4)]: place(DG + "banner_patternC_red.gltf", Vector3(q.x, 0, q.y), 0.0, 1.2)
			_ring(Vector3(P.x, 0, P.y), 12.0, Color(1.0, 0.6, 0.25, 0.35), 0.15)
			label("ARÈNE", Vector3(P.x, y + 5.5, P.y - 12.0), Color("#ffb07a"), 70)
		"lair":
			for i in 12:
				if i == 3: continue
				var q := P + Vector2(cos(i * TAU / 12.0), sin(i * TAU / 12.0)) * 10.0
				place(DG + "pillar.gltf", Vector3(q.x, 0, q.y), 0.0, 1.2); blocker(Vector3(q.x, 0, q.y), 0.7)
			for i in 8: place(HW + "skull.gltf", Vector3(P.x + cos(i) * 4.0, 0, P.y + sin(i) * 4.0), i, 1.6)
			_light(Vector3(P.x, y + 2.0, P.y), Color("#ff3a20"), 3.0, 14.0)
	pois.append({"id": p.id, "name": p.name, "pos": Vector3(P.x, y, P.y), "r": p.r + 6.0, "region": region_at(P.x, P.y)})

# Lanternes et clôtures le long des routes autour de la ville : on sent qu'on approche d'un lieu habité
func _road_props() -> void:
	var nl := 0
	for rd in roads:
		var side := 1.0
		for i in rd.size() - 1:
			var a: Vector2 = rd[i]; var b: Vector2 = rd[i + 1]; var L := a.distance_to(b)
			if L < 8.0: continue
			var dir := (b - a) / L; var nrm := Vector2(-dir.y, dir.x)
			var k := 6.0
			while k < L - 4.0:
				var c := a + dir * k; var dv := c.distance_to(village)
				var q := c + nrm * 3.6 * side
				if dv > 28.0 and dv < 64.0 and walkable(q.x, q.y) and river_dist(q.x, q.y) > RIVER_W + 3.0 and road_dist(q.x, q.y) > 3.0:
					_mm("res://assets/halloween/post_lantern.gltf", Vector3(q.x, 0, q.y), 1.3, atan2(nrm.x, nrm.y))
					if nl < 14: _light(Vector3(q.x, height(q.x, q.y) + 2.2, q.y), Color("#ffbf66"), 1.6, 2.2); nl += 1
				side = -side
				k += 15.0

# ——— Passages vers les autres cartes : arche, lueur dorée, grand panneau ———
func _gates() -> void:
	for g in MAP.gates:
		var P: Vector2 = g.pos; var y := height(P.x, P.y)
		var inward := Vector2(-sign(P.x), 0) if abs(P.x) > abs(P.y) else Vector2(0, -sign(P.y))
		var side := Vector2(-inward.y, inward.x)
		var rot := atan2(side.x, side.y)
		for sd in [-3.2, 3.2]:
			var q: Vector2 = P + side * sd
			place("res://assets/dungeon/pillar_decorated.gltf", Vector3(q.x, 0, q.y), rot, 1.15); blocker(Vector3(q.x, 0, q.y), 0.7)
			place("res://assets/dungeon/banner_patternB_blue.gltf", Vector3(q.x + inward.x * 0.8, 0, q.y + inward.y * 0.8), rot + PI * 0.5, 1.2)
		var col: Color = Game.TIER_COL[Maps.TIERS[g.to][1]]
		_ring(Vector3(P.x, 0, P.y), 2.6, Color(1.0, 0.85, 0.4, 0.7), 0.12)
		var disc := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.4; cm.bottom_radius = 2.4; cm.height = 0.04; disc.mesh = cm
		var dm := StandardMaterial3D.new(); dm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; dm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; dm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		dm.albedo_color = Color(col.r, col.g, col.b, 0.35); disc.material_override = dm; disc.position = Vector3(P.x, y + 0.08, P.y); add_child(disc)
		var tw := disc.create_tween().set_loops(); tw.tween_property(dm, "albedo_color:a", 0.6, 1.1).set_trans(Tween.TRANS_SINE); tw.tween_property(dm, "albedo_color:a", 0.25, 1.1).set_trans(Tween.TRANS_SINE)
		_light(Vector3(P.x, y + 2.5, P.y), Color("#ffd27a"), 2.6, 9.0)
		var gl := label("PASSAGE %s\nCarte T%d-T%d · %s" % [g.dir, Maps.TIERS[g.to][0], Maps.TIERS[g.to][1], Maps.NAMES[g.to]], Vector3(P.x, y + 4.2, P.y), col.lightened(0.3), 56)
		gl.no_depth_test = true; gl.outline_modulate = Color(0.1, 0.06, 0.0, 0.95)
		gates.append({"pos": Vector3(P.x, y, P.y), "to": g.to, "dir": g.dir, "arrive": g.arrive})
		# panneau indicateur à la sortie de la ville, sur la route du passage
		var sp := village + (P - village).normalized() * 22.0
		_signpost(sp, P, "%s → %s (T%d-T%d)" % [g.dir, Maps.NAMES[g.to], Maps.TIERS[g.to][0], Maps.TIERS[g.to][1]], col)

func _signpost(p: Vector2, toward: Vector2, txt: String, col: Color) -> void:
	for k in 20:
		if road_dist(p.x, p.y) > 2.6: break
		p += Vector2((toward - p).normalized().y, -(toward - p).normalized().x) * 0.5
	var y := height(p.x, p.y)
	var root := Node3D.new(); root.position = Vector3(p.x, y, p.y); add_child(root)
	var post := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.09; cm.bottom_radius = 0.11; cm.height = 2.6; post.mesh = cm
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color("#6b4428"); post.material_override = wm; post.position.y = 1.3; root.add_child(post)
	var board := MeshInstance3D.new(); var bm := BoxMesh.new(); bm.size = Vector3(1.9, 0.42, 0.08); board.mesh = bm
	var bw := StandardMaterial3D.new(); bw.albedo_color = Color("#a8763e"); board.material_override = bw; board.position.y = 2.25
	var d := toward - p; board.rotation.y = atan2(d.x, d.y) - PI * 0.5; root.add_child(board)
	var l := Label3D.new(); l.text = txt; l.font_size = 56; l.outline_size = 14; l.modulate = col.lightened(0.3); l.outline_modulate = Color(0.15, 0.08, 0.02, 0.95)
	l.billboard = BaseMaterial3D.BILLBOARD_ENABLED; l.pixel_size = 0.009; l.position.y = 2.9; l.no_depth_test = true; root.add_child(l)
	blocker(Vector3(p.x, 0, p.y), 0.25)

# ——— Ville générique (cartes 2 à 4) : place centrale, bâtiments en cercle, chaque PNJ devant SA boutique ———
# Allées de la ville (calculées avant le terrain, pour qu'elles soient dessinées au sol)
var town_slots: Array = []
var dirt_spots: Array = []    # [centre, rayon] : cercles de terre sous les PNJ
var foot_paths: Array = []    # [a, b] : sentiers des villes
func _plan_town_slots() -> void:
	var V: Vector2 = MAP.town.pos
	town_slots = []
	for ring in [[15.0, 10], [24.0, 14]]:
		for i in ring[1]:
			var a: float = TAU * i / ring[1] + (0.2 if ring[0] > 20 else 0.0)
			var q: Vector2 = V + Vector2(cos(a), sin(a)) * ring[0]
			if road_dist(q.x, q.y) < 7.0 or raw_height(q.x, q.y) < WATER_Y + 0.6: continue
			town_slots.append(q)
	for i in min(10, town_slots.size()):
		var q: Vector2 = town_slots[i]
		var to_c := (V - q).normalized()
		var np: Vector2 = q + to_c * 5.2
		if i < 7: dirt_spots.append([np, 2.2])
		foot_paths.append([q + to_c * 2.6, V - to_c * 8.5])

func _town(T: Dictionary) -> void:
	var V: Vector2 = T.pos; var H := "res://assets/hex/"; var mid := map_id
	label(T.name, Vector3(V.x, height(V.x, V.y) + 8.0, V.y - 4.0), Color("#ffe2a0"), 90)
	building(H + "building_well_blue.gltf", V, 0.0, 3.0, 2.2)
	_tint_last(T.tint)
	# emplacements autour de la place, loin des routes (calculés avant le terrain)
	var slots: Array = town_slots
	var shops := [
		["building_blacksmith_blue.gltf", "forge", "Armurier · forge", "Barbarian", 6.0],
		["building_market_blue.gltf", "shop", "Marchande", "Rogue", 7.0],
		["building_barracks_blue.gltf", "auction", "Hôtel des ventes", "Rogue", 6.5],
		["building_tavern_blue.gltf", "mercs", "Capitaine des mercenaires", "Knight", 6.5],
		["building_home_A_blue.gltf", "tools3", "Outilleur · haches, pioches, faucilles", "Barbarian", 5.0],
		["building_church_blue.gltf", "quest", "Chef de la ville", "Mage", 6.5],
		["building_home_B_blue.gltf", "travel", "Passeur · voyages rapides", "Ranger", 5.0],
		["building_home_A_blue.gltf", "", "", "", 5.0],
		["building_home_B_blue.gltf", "", "", "", 5.0],
		["building_tower_A_blue.gltf", "", "", "", 3.6],
	]
	var names := {2: ["Hrolf", "Brisa", "Tancrède", "Solène", "Odo", "Maître Elwin", "Fenn"], 3: ["Kadir", "Samira", "Yazid", "Nour", "Faris", "Sage Imran", "Leïla"], 4: ["Gunnar", "Morwen", "Aldo", "Ivra", "Baldr", "Doyenne Sigrid", "Corbin"]}
	var nm: Array = names.get(mid, names[2])
	for i in min(shops.size(), slots.size()):
		var sh: Array = shops[i]; var q: Vector2 = slots[i]
		var to_c := (V - q).normalized()
		building(H + sh[0], q, atan2(to_c.x, to_c.y), 4.8, sh[4])
		_tint_last(T.tint)
		if sh[1] == "": continue
		var np: Vector2 = q + to_c * 5.2
		var d := {"id": "%s_%d" % [sh[1], mid], "model": sh[3], "name": nm[i], "role": sh[2], "pos": Vector3(np.x, 0, np.y), "act": sh[1]}
		npc_spots.append(d)
		if sh[1] == "auction": label("HÔTEL DES VENTES", Vector3(q.x, height(q.x, q.y) + 7.5, q.y), Color("#ffd27a"), 54)
		if sh[1] == "forge":
			forge_pos = Vector3(np.x, 0, np.y)
			place("res://assets/hex/weaponrack.gltf", Vector3(np.x + to_c.y * 2.2, 0, np.y - to_c.x * 2.2), 0.4, 5.0)
	# étals de marché sur la place : tentes, caisses, tonneaux, fanions
	for i in 3:
		var a := TAU * i / 3.0 + 1.1
		var q := V + Vector2(cos(a), sin(a)) * 6.0
		if road_dist(q.x, q.y) < 1.2: q = V + Vector2(cos(a + 0.5), sin(a + 0.5)) * 6.0
		place(H + "tent.gltf", Vector3(q.x, 0, q.y), a + PI, 3.4); _tint_last(T.tint); blocker(Vector3(q.x, 0, q.y), 1.0)
		var side := Vector2(-sin(a), cos(a))
		var c1 := q + side * 1.8; var c2 := q - side * 1.8
		place(H + ["crate_A_big.gltf", "barrel.gltf", "sack.gltf"][i], Vector3(c1.x, 0, c1.y), a, 4.0)
		place(H + ["crate_open.gltf", "crate_long_A.gltf", "barrel.gltf"][i], Vector3(c2.x, 0, c2.y), a + 0.5, 4.0)
	# lanternes autour de la place
	for i in 6:
		var a := TAU * i / 6.0 + 0.5
		var q := V + Vector2(cos(a), sin(a)) * 9.0
		if road_dist(q.x, q.y) < 2.5: continue
		place("res://assets/halloween/lantern_standing.gltf", Vector3(q.x, 0, q.y), 0.0, 1.6); blocker(Vector3(q.x, 0, q.y), 0.3)
		_light(Vector3(q.x, height(q.x, q.y) + 2.5, q.y), Color("#ffbf66"), 2.0, 2.5)

var _last_placed: Node3D
func _tint_last(c: Color) -> void:
	if _last_placed == null or c == Color(1, 1, 1): return
	_tint_mul_n(_last_placed, c)
func _tint_mul_n(n: Node, c: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is BaseMaterial3D:
				var key := str(src.get_instance_id()) + c.to_html()
				if not _tint_cache.has(key):
					var m: BaseMaterial3D = src.duplicate(); m.albedo_color = m.albedo_color * c; _tint_cache[key] = m
				mi.set_surface_override_material(i, _tint_cache[key])
	for ch in n.get_children(): _tint_mul_n(ch, c)
var _tint_cache := {}

# Colonne de lumière visible de loin (Tour Infinie, donjons) : on sait où aller
static func beam(p: Vector3, col: Color, parent: Node) -> MeshInstance3D:
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.5; cm.bottom_radius = 1.4; cm.height = 46.0; cm.cap_top = false; cm.cap_bottom = false; cm.radial_segments = 12; mi.mesh = cm
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(col.r, col.g, col.b, 0.22); m.cull_mode = BaseMaterial3D.CULL_DISABLED; mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mi.visibility_range_end = 400.0
	mi.position = p + Vector3(0, 23.0, 0); parent.add_child(mi)
	return mi

# Portail bleu magnifique : anneau lumineux, voile tourbillonnant, étincelles
func _blue_portal(p: Vector3) -> void:
	var root := Node3D.new(); root.position = p; add_child(root)
	var ring := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 2.0; tm.outer_radius = 2.45; tm.rings = 48; tm.ring_segments = 12; ring.mesh = tm
	var rm := StandardMaterial3D.new(); rm.albedo_color = Color("#9ad8ff"); rm.emission_enabled = true; rm.emission = Color("#3f9cff"); rm.emission_energy_multiplier = 2.2; rm.metallic = 0.4; rm.roughness = 0.3
	ring.material_override = rm; ring.rotation.x = PI / 2; ring.position.y = 2.5; root.add_child(ring)
	var veil := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(4.2, 4.2); veil.mesh = q; veil.position.y = 2.5
	var sh := Shader.new(); sh.code = """shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, shadows_disabled;
void fragment(){
	vec2 c = UV - 0.5; float r = length(c) * 2.0; float a = atan(c.y, c.x);
	float sw = sin(a * 5.0 + r * 9.0 - TIME * 3.0) * 0.5 + 0.5;
	float core = smoothstep(1.0, 0.0, r);
	vec3 col = mix(vec3(0.1, 0.35, 1.0), vec3(0.6, 0.9, 1.0), sw * core);
	ALBEDO = col; ALPHA = core * (0.45 + 0.4 * sw) * step(r, 0.98);
}"""
	var vm := ShaderMaterial.new(); vm.shader = sh; veil.material_override = vm; root.add_child(veil)
	var base := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 2.6; cm.bottom_radius = 2.8; cm.height = 0.3; base.mesh = cm
	var bm := StandardMaterial3D.new(); bm.albedo_color = Color("#6f7d92"); base.material_override = bm; base.position.y = 0.1; root.add_child(base)
	var sp := CPUParticles3D.new(); sp.amount = 40; sp.lifetime = 2.2; sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_SPHERE; sp.emission_sphere_radius = 2.0
	sp.direction = Vector3.UP; sp.gravity = Vector3(0, 0.8, 0); sp.initial_velocity_min = 0.2; sp.initial_velocity_max = 0.8; sp.scale_amount_min = 0.12; sp.scale_amount_max = 0.25
	var pq := QuadMesh.new(); pq.material = Fx.add_mat(); sp.mesh = pq; sp.color = Color(0.5, 0.8, 1.0, 0.9); sp.position.y = 2.5; root.add_child(sp)
	_light(p + Vector3(0, 2.5, 0.3), Color("#5fb0ff"), 2.8, 9.0)
	var tw := ring.create_tween().set_loops(); tw.tween_property(rm, "emission_energy_multiplier", 3.2, 1.2).set_trans(Tween.TRANS_SINE); tw.tween_property(rm, "emission_energy_multiplier", 1.8, 1.2).set_trans(Tween.TRANS_SINE)

# Entrée de grotte : amas de rochers en arche, bouche sombre et voile magique qui tourbillonne
const CAVE_ROCKS := ["Rock_3_A_Color1", "Rock_3_M_Color1", "Rock_1_E_Color1", "Rock_3_K_Color1", "Rock_1_N_Color1"]
func cave_portal(root: Node3D, col: Color) -> void:
	var r := RandomNumberGenerator.new(); r.seed = int(root.position.x * 13.0 + root.position.z * 7.0)
	for i in 9:
		var a := PI * (0.05 + 0.9 * i / 8.0)          # demi-cercle derrière l'entrée
		var rk: Node3D = load("res://assets/forest/%s.gltf" % CAVE_ROCKS[i % CAVE_ROCKS.size()]).instantiate()
		var rad := 2.3 + r.randf() * 0.3
		rk.position = Vector3(cos(a) * rad, -0.15 + (0.9 if i in [3, 4, 5] else 0.0), -sin(a) * 1.5 - 0.6)
		rk.scale = Vector3.ONE * r.randf_range(0.75, 1.05); rk.rotation.y = r.randf() * TAU
		_tint(rk, Color("#8f8a80"), Color(0, 0, 0)); root.add_child(rk)
	var top: Node3D = load("res://assets/forest/Rock_3_M_Color1.gltf").instantiate(); top.position = Vector3(0, 2.3, -1.5); top.scale = Vector3(1.3, 0.8, 1.0); _tint(top, Color("#7d786f"), Color(0, 0, 0)); root.add_child(top)
	var mouth := MeshInstance3D.new(); var q := QuadMesh.new(); q.size = Vector2(3.4, 3.2); mouth.mesh = q
	var sh := Shader.new(); sh.code = """shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;
uniform vec4 col : source_color;
void fragment(){
	vec2 c = (UV - vec2(0.5, 0.62)) * vec2(1.0, 1.25); float r = length(c) * 2.0; float a = atan(c.y, c.x);
	float sw = sin(a * 4.0 + r * 8.0 - TIME * 2.5) * 0.5 + 0.5;
	float inside = smoothstep(1.0, 0.85, r);
	vec3 cc = mix(vec3(0.01, 0.0, 0.03), col.rgb, sw * smoothstep(0.95, 0.2, r) * 0.9);
	ALBEDO = cc; ALPHA = inside * step(UV.y, 0.98);
}"""
	var mm := ShaderMaterial.new(); mm.shader = sh; mm.set_shader_parameter("col", col); mouth.material_override = mm
	mouth.position = Vector3(0, 1.3, 0.0); mouth.rotation.x = -0.55; root.add_child(mouth)   # penché vers la caméra
	var sp := CPUParticles3D.new(); sp.amount = 24; sp.lifetime = 1.8; sp.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX; sp.emission_box_extents = Vector3(1.2, 0.2, 0.3)
	sp.direction = Vector3.UP; sp.gravity = Vector3(0, 0.6, 0); sp.initial_velocity_min = 0.2; sp.initial_velocity_max = 0.6; sp.scale_amount_min = 0.1; sp.scale_amount_max = 0.2
	var pq := QuadMesh.new(); pq.material = Fx.add_mat(); sp.mesh = pq; sp.color = Color(col.r, col.g, col.b, 0.9); sp.position = Vector3(0, 0.3, 0.6); root.add_child(sp)
	var g := Sprite3D.new(); g.texture = Fx.soft_tex(); g.billboard = BaseMaterial3D.BILLBOARD_ENABLED; g.pixel_size = 0.045; g.modulate = Color(col.r, col.g, col.b, 0.5); g.shaded = false; g.position = Vector3(0, 1.4, 0.6); root.add_child(g)
	for sx in [-1.6, 1.6]:
		var torch: Node3D = load("res://assets/dungeon/torch_mounted.gltf").instantiate(); torch.position = Vector3(sx, 1.7, 0.2); root.add_child(torch)
		_light(root.position + Vector3(sx, 2.3, 0.5), Color("#ffa040"), 2.0, 2.4)

# ——— Port : quai en bois, bateau amarré, capitaine ———
var harbor_pos := Vector3.ZERO
func _harbor() -> void:
	var a := Vector2(18, 103); var bay: Vector2 = BAY; var dir := (bay - a).normalized()
	var s := a
	for k in 60:
		if raw_height(s.x, s.y) < WATER_Y + 0.4: break
		s += dir * 0.5
	var e := s + dir * 13.0
	var y := 0.35
	var right := Vector3(dir.y, 0, -dir.x)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var deck := BoxMesh.new(); deck.size = Vector3(4.2, 0.3, (e - s).length() + 4.0)
	var mid := (s + e) * 0.5 - dir * 2.0
	var basis := Basis.looking_at(Vector3(dir.x, 0, dir.y), Vector3.UP)
	st.append_from(deck, 0, Transform3D(basis, Vector3(mid.x, y, mid.y)))
	var n := int((e - s).length() / 2.5) + 1
	for k in n + 1:
		var p := s.lerp(e, float(k) / n)
		for sd in [-1.9, 1.9]:
			var post := CylinderMesh.new(); post.top_radius = 0.16; post.bottom_radius = 0.18; post.height = 3.2
			st.append_from(post, 0, Transform3D(Basis(), Vector3(p.x, y - 1.2, p.y) + right * sd))
	var pier := MeshInstance3D.new(); pier.mesh = st.commit()
	var wm := StandardMaterial3D.new(); wm.albedo_color = Color("#8a5a34"); wm.roughness = 0.9; pier.material_override = wm; add_child(pier)
	var body := StaticBody3D.new(); var cs := CollisionShape3D.new(); var bx := BoxShape3D.new(); bx.size = deck.size; cs.shape = bx
	body.add_child(cs); body.transform = Transform3D(basis, Vector3(mid.x, y, mid.y)); add_child(body)
	bridges.append({"a": s - dir * 2.0, "b": e, "prof": []})
	for q in [e + Vector2(-dir.y, dir.x) * 1.4, e + Vector2(dir.y, -dir.x) * 1.4]:
		var o: Node3D = load("res://assets/dungeon/barrel_small_stack.gltf").instantiate(); o.position = Vector3(q.x, y + 0.15, q.y); o.scale = Vector3.ONE * 0.5; add_child(o)
	_light(Vector3(e.x, y + 2.2, e.y), Color("#ffbf66"), 2.0, 3.0)
	# le bateau, amarré le long du quai
	var bp := s.lerp(e, 0.6) + Vector2(dir.y, -dir.x) * 4.6
	add_child(make_boat(Vector3(bp.x, WATER_Y + 0.15, bp.y), atan2(dir.x, dir.y)))
	harbor_pos = Vector3(e.x, 0, e.y)
	label("PORT", Vector3(s.x, y + 5.0, s.y), Color("#9fd4ff"), 70)
	var cap := s.lerp(e, 0.45) + Vector2(-dir.y, dir.x) * 0.9
	npc_spots.append({"id": "marlo", "model": "Barbarian", "name": "Capitaine Marlo", "role": "Îles à vendre · traversées", "pos": Vector3(cap.x, 0, cap.y), "act": "harbor"})
	pois.append({"id": "port", "name": "Port de Valdrune", "pos": Vector3(s.x, 0, s.y), "r": 8.0, "region": 1})

# Bateau low-poly fait main (aucun modèle de navire dans les packs)
static func make_boat(pos: Vector3, rot: float) -> Node3D:
	var root := Node3D.new(); root.position = pos; root.rotation.y = rot
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var L := 9.0; var seg := 12
	var prof := []
	for i in seg + 1:
		var t := float(i) / seg; var z := (t - 0.5) * L
		var w: float = 1.7 * sin(PI * clamp(t * 1.05, 0.0, 1.0)) + 0.15
		if t > 0.8: w *= 1.0 - (t - 0.8) * 3.5
		prof.append([z, max(0.1, w)])
	for i in seg:
		var a: Array = prof[i]; var b: Array = prof[i + 1]
		for sd in [-1.0, 1.0]:
			var p0 := Vector3(a[1] * sd, 1.1, a[0]); var p1 := Vector3(b[1] * sd, 1.1, b[0])
			var q0 := Vector3(a[1] * sd * 0.45, -0.4, a[0]); var q1 := Vector3(b[1] * sd * 0.45, -0.4, b[0])
			for v in [p0, q0, p1, p1, q0, q1]: st.add_vertex(v)
		for v in [Vector3(-a[1] * 0.45, -0.4, a[0]), Vector3(a[1] * 0.45, -0.4, a[0]), Vector3(-b[1] * 0.45, -0.4, b[0]), Vector3(-b[1] * 0.45, -0.4, b[0]), Vector3(a[1] * 0.45, -0.4, a[0]), Vector3(b[1] * 0.45, -0.4, b[0])]: st.add_vertex(v)
	st.generate_normals()
	var hull := MeshInstance3D.new(); hull.mesh = st.commit()
	var hm := StandardMaterial3D.new(); hm.albedo_color = Color("#6b3f22"); hm.cull_mode = BaseMaterial3D.CULL_DISABLED; hull.material_override = hm; root.add_child(hull)
	var dst := SurfaceTool.new(); dst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in seg:
		var a: Array = prof[i]; var b: Array = prof[i + 1]
		for v in [Vector3(-a[1], 0.95, a[0]), Vector3(a[1], 0.95, a[0]), Vector3(-b[1], 0.95, b[0]), Vector3(-b[1], 0.95, b[0]), Vector3(a[1], 0.95, a[0]), Vector3(b[1], 0.95, b[0])]: dst.add_vertex(v)
	dst.generate_normals()
	var deck := MeshInstance3D.new(); deck.mesh = dst.commit(); var dm := StandardMaterial3D.new(); dm.albedo_color = Color("#b07a48"); dm.cull_mode = BaseMaterial3D.CULL_DISABLED; deck.material_override = dm; root.add_child(deck)
	var rail := MeshInstance3D.new(); var tm := TorusMesh.new(); tm.inner_radius = 0.95; tm.outer_radius = 1.05; rail.mesh = tm; rail.scale = Vector3(1.6, 1.0, L * 0.52); rail.position.y = 1.15; rail.material_override = hm; root.add_child(rail)
	var mast := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.1; cm.bottom_radius = 0.16; cm.height = 7.5; mast.mesh = cm; mast.position = Vector3(0, 4.6, 0.4); mast.material_override = hm; root.add_child(mast)
	var yard := MeshInstance3D.new(); var ym := CylinderMesh.new(); ym.top_radius = 0.07; ym.bottom_radius = 0.07; ym.height = 4.6; yard.mesh = ym; yard.rotation.z = PI / 2; yard.position = Vector3(0, 7.0, 0.4); yard.material_override = hm; root.add_child(yard)
	var sail := MeshInstance3D.new(); var sst := SurfaceTool.new(); sst.begin(Mesh.PRIMITIVE_TRIANGLES)
	for r in 6:
		var y0 := 7.0 - r * 0.9; var y1 := y0 - 0.9; var bulge0 := sin(PI * r / 6.0) * 0.5; var bulge1 := sin(PI * (r + 1) / 6.0) * 0.5
		var col := Color("#f1e6cc") if r % 2 == 0 else Color("#b8322a")
		for v in [Vector3(-2.2, y0, 0.4 + bulge0), Vector3(2.2, y0, 0.4 + bulge0), Vector3(-2.2, y1, 0.4 + bulge1), Vector3(-2.2, y1, 0.4 + bulge1), Vector3(2.2, y0, 0.4 + bulge0), Vector3(2.2, y1, 0.4 + bulge1)]:
			sst.set_color(col); sst.add_vertex(v)
	sst.generate_normals(); sail.mesh = sst.commit()
	var sm := StandardMaterial3D.new(); sm.vertex_color_use_as_albedo = true; sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sail.material_override = sm; root.add_child(sail)
	var flag := MeshInstance3D.new(); var fq := QuadMesh.new(); fq.size = Vector2(1.0, 0.6); flag.mesh = fq; flag.position = Vector3(0.5, 8.2, 0.4)
	var fm := StandardMaterial3D.new(); fm.albedo_color = Color("#3f7fd9"); fm.cull_mode = BaseMaterial3D.CULL_DISABLED; flag.material_override = fm; root.add_child(flag)
	var tw := root.create_tween().set_loops(); tw.tween_property(root, "rotation:z", 0.035, 2.2).set_trans(Tween.TRANS_SINE); tw.tween_property(root, "rotation:z", -0.035, 2.2).set_trans(Tween.TRANS_SINE)
	return root

# Lueur sans lumière dynamique (une OmniLight coûte une passe de rendu en plus sur mobile)
static var glow_mat: StandardMaterial3D
var glows: Array = []          # [sprite, alpha de jour] — elles brillent plus fort la nuit
func _light(p: Vector3, c: Color, e: float, r: float) -> void:
	var sp := Sprite3D.new(); sp.texture = Fx.soft_tex(); sp.billboard = BaseMaterial3D.BILLBOARD_ENABLED; sp.pixel_size = 0.012 * r
	var a: float = clamp(0.25 * e, 0.2, 0.7)
	sp.modulate = Color(c.r, c.g, c.b, a); sp.position = p; sp.shaded = false
	if glow_mat == null:
		glow_mat = StandardMaterial3D.new(); glow_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; glow_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glow_mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		glow_mat.albedo_texture = Fx.soft_tex(); glow_mat.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; glow_mat.vertex_color_use_as_albedo = true
	sp.material_override = glow_mat; add_child(sp)
	glows.append([sp, a, sp.pixel_size])

var night_k := -1.0
func set_night(k: float) -> void:
	if abs(k - night_k) < 0.02: return
	night_k = k
	for g in glows:
		if not is_instance_valid(g[0]): continue
		var sp: Sprite3D = g[0]
		sp.modulate.a = lerp(float(g[1]), min(1.0, float(g[1]) * 2.2 + 0.15), k)
		sp.pixel_size = float(g[2]) * (1.0 + 0.6 * k)

# ——— Ressources : là où la nature les met (forêts, rochers, prairies) ———
const TREE_VARIANTS := [[],
	["res://assets/forest/Tree_1_A_Color1.gltf", "res://assets/forest/Tree_1_B_Color1.gltf", "res://assets/forest/Tree_1_C_Color1.gltf", "res://assets/forest/Tree_2_A_Color1.gltf"],
	["res://assets/forest/Tree_4_B_Color1.gltf", "res://assets/forest/Tree_4_A_Color1.gltf", "res://assets/forest/Tree_4_C_Color1.gltf", "res://assets/forest/Tree_2_D_Color1.gltf"],
	["res://assets/forest/Tree_3_A_Color1.gltf", "res://assets/forest/Tree_3_B_Color1.gltf", "res://assets/forest/Tree_2_B_Color1.gltf"],
	["res://assets/forest/Tree_Bare_1_A_Color1.gltf", "res://assets/forest/Tree_Bare_1_B_Color1.gltf", "res://assets/forest/Tree_Bare_2_A_Color1.gltf"],
	["res://assets/halloween/tree_dead_large.gltf", "res://assets/halloween/tree_dead_medium.gltf"]]
const NODE_MODEL := {
	"wood": ["", "res://assets/forest/Tree_1_A_Color1.gltf", "res://assets/forest/Tree_4_B_Color1.gltf", "res://assets/forest/Tree_3_A_Color1.gltf", "res://assets/forest/Tree_Bare_1_A_Color1.gltf", "res://assets/halloween/tree_dead_large.gltf"],
	"ore": ["", "res://assets/forest/Rock_1_J_Color1.gltf", "res://assets/forest/Rock_1_J_Color1.gltf", "res://assets/forest/Rock_3_E_Color1.gltf", "res://assets/forest/Rock_3_E_Color1.gltf", "res://assets/forest/Rock_1_J_Color1.gltf"],
	"fiber": ["", "res://assets/forest/Bush_1_C_Color1.gltf", "res://assets/forest/Bush_2_B_Color1.gltf", "res://assets/forest/Bush_4_C_Color1.gltf", "res://assets/forest/Bush_1_C_Color1.gltf", "res://assets/forest/Bush_4_A_Color1.gltf"],
}
func _free_spot(p: Vector3, r: float, keep_village := true) -> bool:
	if abs(p.x) > 106 or abs(p.z) > 106: return false
	if not reachable(p.x, p.z): return false
	if near_house(Vector2(p.x, p.z), r): return false
	for g in gates:
		if Vector2(p.x - g.pos.x, p.z - g.pos.z).length() < 10.0 + r: return false
	if not walkable(p.x, p.z) or height(p.x, p.z) < WATER_Y + 0.5: return false
	if road_dist(p.x, p.z) < 3.0 + r: return false
	if keep_village and Vector2(p.x, p.z).distance_to(village) < 34.0: return false
	for q in POI_DEFS:
		if Vector2(p.x, p.z).distance_to(q.p) < q.r + 3.0 + r: return false
	return true

func _resources() -> void:
	var biome := FastNoiseLite.new(); biome.seed = 909 + map_id; biome.frequency = 0.035
	for reg in range(1, REGIONS.size()):
		var R: Dictionary = REGIONS[reg]; var t: int = R.tier
		# bois : tous les arbres de la carte sont récoltables, regroupés en bosquets
		var want_w: int = {"forest": 62, "meadow": 32, "hills": 26, "swamp": 22, "ash": 14, "desert": 10, "canyon": 12}.get(R.style, 24)
		var placed := 0; var tries := 0
		while placed < want_w and tries < 3000:
			tries += 1
			var c := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
			if region_at(c.x, c.z) != reg or not _free_spot(c, 2.0, false): continue
			if Vector2(c.x, c.z).distance_to(village) < 30.0: continue
			if R.style in ["forest", "meadow"] and biome.get_noise_2d(c.x, c.z) < -0.15: continue
			var n := rng.randi_range(3, 6 if R.style == "forest" else 4)
			for k in n:
				if placed >= want_w: break
				var p := c + Vector3(rng.randf_range(-6, 6), 0, rng.randf_range(-6, 6))
				if region_at(p.x, p.z) != reg or not _free_spot(p, 1.0, false) or _near_node_grid(p, 3.0): continue
				_add_node("wood", t, p); placed += 1
		for k in ["ore", "fiber"]:
			var want := 16; placed = 0; tries = 0
			while placed < want and tries < 4000:
				tries += 1
				var p := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
				if region_at(p.x, p.z) != reg: continue
				if not _free_spot(p, 1.0, false): continue
				if Vector2(p.x, p.z).distance_to(village) < 26.0: continue
				var b := biome.get_noise_2d(p.x, p.z)
				if k == "fiber" and b > 0.1: continue
				# le minerai aime le pied des falaises et les hauteurs
				if k == "ore" and plateau(p.x, p.z) < 0.5 and not _near_cliff(p, 7.0) and rng.randf() < 0.7: continue
				if _near_node_grid(p, 3.6): continue
				_add_node(k, t, p); placed += 1

func _near_cliff(p: Vector3, r: float) -> bool:
	for a in 8:
		var q := Vector2(p.x, p.z) + Vector2(cos(a * TAU / 8.0), sin(a * TAU / 8.0)) * r
		if not walkable(q.x, q.y): return true
	return false

var node_grid := {}
func _near_node_grid(p: Vector3, r: float) -> bool:
	var cx := int(floor(p.x / 8.0)); var cz := int(floor(p.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in node_grid.get(Vector2i(cx + dx, cz + dz), []):
				if Vector2(q.x - p.x, q.z - p.z).length() < r: return true
	return false

func _add_node(k: String, t: int, p: Vector3, parent: Node = null) -> Dictionary:
	var gk := Vector2i(int(floor(p.x / 8.0)), int(floor(p.z / 8.0)))
	if not node_grid.has(gk): node_grid[gk] = []
	node_grid[gk].append(p)
	p.y = height(p.x, p.z)
	var root := Node3D.new(); root.position = p; add_child(root)
	var sc := {"wood": 1.0, "ore": 0.5, "fiber": 1.5}[k] as float
	if k == "ore" and t in [3, 4]: sc = 1.45
	if k == "wood" and t == 5: sc = 1.2
	var mpath: String = NODE_MODEL[k][t]
	if k == "wood": mpath = TREE_VARIANTS[t][rng.randi() % TREE_VARIANTS[t].size()]; sc *= rng.randf_range(0.85, 1.15)
	if k == "ore" and t >= 4: mpath = crystal("PROP_11_CrystalRock" if t == 4 else "PROP_18_DarkCursedCrystal"); sc = 1.0
	var model: Node3D = load(mpath).instantiate(); model.scale = Vector3.ONE * sc * (1.0 + 0.04 * t); model.rotation.y = rng.randf() * TAU
	root.add_child(model)
	var col: Color = Game.TIER_COL[t]
	if k == "ore" and t >= 4:
		_light(p + Vector3(0, 1.2, 0), col, 1.4, 2.2)
	elif k == "ore":
		_tint(model, Color(0.8, 0.78, 0.75).lerp(col, 0.25), Color(0, 0, 0))
		# 4 cristaux fusionnés en un seul maillage (1 seul appel de dessin)
		var cst := SurfaceTool.new(); cst.begin(Mesh.PRIMITIVE_TRIANGLES)
		var cm := CylinderMesh.new(); cm.top_radius = 0.0; cm.bottom_radius = 0.22; cm.height = 0.9 + 0.15 * t; cm.radial_segments = 6
		for i in 4:
			var a := i * TAU / 4.0 + rng.randf() * 0.5
			cst.append_from(cm, 0, Transform3D(Basis.from_euler(Vector3(cos(a) * 0.5, 0, -sin(a) * 0.5)), Vector3(cos(a) * 0.55, 0.55 + rng.randf() * 0.3, sin(a) * 0.55)))
		var cr := MeshInstance3D.new(); cr.mesh = cst.commit()
		var mm := StandardMaterial3D.new(); mm.albedo_color = col; mm.emission_enabled = true; mm.emission = col; mm.emission_energy_multiplier = 0.6; mm.roughness = 0.3
		cr.material_override = mm; cr.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; root.add_child(cr)
	elif k == "fiber":
		_tint(model, Color(1, 1, 1).lerp(col, 0.55), col * 0.12)
	elif k == "wood" and t == 3:
		_tint(model, Color("#ffb070"), Color(0, 0, 0))
	# petit marqueur discret : anneau fin de la couleur du tier + badge
	var ring := _ring(p, 1.15 if k == "wood" else 0.95, Color(col.r, col.g, col.b, 0.75), 0.07)
	var badge := Label3D.new(); badge.text = "T%d" % t; badge.font_size = 44; badge.outline_size = 12; badge.modulate = col; badge.outline_modulate = Color(0, 0, 0, 0.8)
	badge.billboard = BaseMaterial3D.BILLBOARD_ENABLED; badge.no_depth_test = true; badge.render_priority = 2; badge.pixel_size = 0.0065
	badge.position = Vector3(0, 2.6 if k == "wood" else 1.9, 0); root.add_child(badge)
	badge.visibility_range_end = 14.0; ring.visibility_range_end = 16.0
	var nd := {"type": k, "tier": t, "pos": p, "root": root, "model": model, "ring": ring, "badge": badge, "max": 4 + t, "charges": 4 + t, "respawn": 0.0, "shake": 0.0, "base_scale": model.scale}
	var blk: StaticBody3D = blocker(p, 0.75 if k == "wood" else 0.9) if k != "fiber" else null
	nodes.append(nd)
	if parent:
		# ressource d'une instance (île) : rangée dans l'instance, libérée avec elle
		root.reparent(parent); ring.reparent(parent)
		if blk: blk.reparent(parent)
	return nd

func _tint(n: Node, c: Color, em: Color) -> void:
	if n is MeshInstance3D and (n as MeshInstance3D).mesh:
		var mi := n as MeshInstance3D
		for i in mi.mesh.get_surface_count():
			var src = mi.mesh.surface_get_material(i)
			if src is StandardMaterial3D:
				var m: StandardMaterial3D = src.duplicate(); m.albedo_color = c
				if em != Color(0, 0, 0): m.emission_enabled = true; m.emission = em
				mi.set_surface_override_material(i, m)
	for ch in n.get_children(): _tint(ch, c, em)

func _ring(c: Vector3, r: float, col: Color, w := 0.18) -> MeshInstance3D:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var seg := int(max(24.0, r * 3.0))
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		var pts := []
		for a in [a0, a1]:
			for rr in [r - w, r + w]:
				var x: float = c.x + cos(a) * rr; var z: float = c.z + sin(a) * rr
				pts.append(Vector3(x, height(x, z) + 0.06, z))
		for v in [pts[0], pts[2], pts[1], pts[1], pts[2], pts[3]]: st.add_vertex(v)
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.albedo_color = col
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.cull_mode = BaseMaterial3D.CULL_DISABLED
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi); return mi

# ——— Décor instancié par morceaux de 32 m (culling efficace) ———
var decor_grid := {}
func near_decor(p: Vector3, r: float) -> bool:
	var cx := int(floor(p.x / 8.0)); var cz := int(floor(p.z / 8.0))
	for dx in [-1, 0, 1]:
		for dz in [-1, 0, 1]:
			for q in decor_grid.get(Vector2i(cx + dx, cz + dz), []):
				if Vector2(q.x - p.x, q.z - p.z).length() < r + q.y: return true
	return false

func _mm(path: String, p: Vector3, s: float, rot: float, col := Color(1, 1, 1)) -> void:
	if "Tree" in path or "tree_" in path or "Rock" in path:
		if _near_duel(p, 10.0): return
		var gk := Vector2i(int(floor(p.x / 8.0)), int(floor(p.z / 8.0)))
		if not decor_grid.has(gk): decor_grid[gk] = []
		decor_grid[gk].append(Vector3(p.x, 1.5 * s, p.z))
	var key := path + "|" + col.to_html() + "|" + str(int(floor((p.x + HALF) / 64.0))) + "," + str(int(floor((p.z + HALF) / 64.0)))
	if not mm_lists.has(key): mm_lists[key] = []
	p.y = height(p.x, p.z) - 0.05
	mm_lists[key].append(Transform3D(Basis(Vector3.UP, rot).scaled(Vector3.ONE * s), p))

# Décors hauts (arbres, gros rochers) : on peut les faire disparaître un par un quand ils cachent le héros
var occluders: Array = []      # {pos, xf, mms: [[multimesh, offset]], k}
var occ_grid := {}
var occ_state := {}            # id → facteur d'échelle actuel (1 = visible, 0 = caché)

func _multi(key: String, xforms: Array) -> void:
	if xforms.is_empty(): return
	var parts := key.split("|"); var path := parts[0]; var col := Color(parts[1])
	var sc: Node3D = load(path).instantiate()
	var meshes: Array = []
	_collect(sc, Transform3D.IDENTITY, meshes)
	var tall := "Tree" in path or "tree_" in path or "Rock_3" in path
	var recs: Array = []
	if tall:
		for i in xforms.size():
			var rec := {"pos": xforms[i].origin, "xf": xforms[i], "mms": [], "i": i}
			recs.append(rec); occluders.append(rec)
			var gk := Vector2i(int(floor(xforms[i].origin.x / 8.0)), int(floor(xforms[i].origin.z / 8.0)))
			if not occ_grid.has(gk): occ_grid[gk] = []
			occ_grid[gk].append(rec)
	for m in meshes:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = m[0]; mm.instance_count = xforms.size()
		for i in xforms.size(): mm.set_instance_transform(i, xforms[i] * m[1])
		for rec in recs: rec.mms.append([mm, m[1]])
		var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm
		mmi.visibility_range_end = 95.0
		mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var src = m[0].surface_get_material(0)
		var wamp := wind_amp(path)
		if path.ends_with(".dae"): mmi.material_override = cliff_mat(col); mmi.visibility_range_end = 110.0
		elif wamp > 0.0 and src is StandardMaterial3D: mmi.material_override = wind_mat(src, col, wamp)
		elif col != Color(1, 1, 1):
			if src is StandardMaterial3D:
				var mat: StandardMaterial3D = src.duplicate(); mat.albedo_color = col; mmi.material_override = mat
		add_child(mmi)
	sc.free()
	if tall:
		var bm: MultiMesh = _blobs(xforms, 1.7 if "Tree" in path or "tree_" in path else 1.2)
		for rec in recs: rec["blob"] = [bm, bm.get_instance_transform(rec.i)]

# Ombres douces peintes au sol sous les arbres et rochers (bien moins coûteux que l'ombre en temps réel)
static var blob_mat: StandardMaterial3D
func _blobs(xforms: Array, k: float) -> MultiMesh:
	if blob_mat == null:
		var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
		for y in 64:
			for x in 64:
				var d := Vector2(x - 31.5, y - 31.5).length() / 32.0
				img.set_pixel(x, y, Color(0.02, 0.05, 0.02, clamp(1.15 - d, 0.0, 1.0) * 0.6))
		blob_mat = StandardMaterial3D.new(); blob_mat.albedo_texture = ImageTexture.create_from_image(img)
		blob_mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; blob_mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; blob_mat.render_priority = -2
	var q := PlaneMesh.new(); q.size = Vector2(2, 2); q.material = blob_mat
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = q; mm.instance_count = xforms.size()
	for i in xforms.size():
		var xf: Transform3D = xforms[i]; var s: float = xf.basis.get_scale().x * k
		var o := xf.origin + Vector3(0.5 * s, 0.16, 0.35 * s)   # décalée dans le sens du soleil
		mm.set_instance_transform(i, Transform3D(Basis().scaled(Vector3(s, 1, s)), o))
	var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; mmi.visibility_range_end = 95.0; add_child(mmi)
	return mm

func _collect(n: Node, xf: Transform3D, out: Array) -> void:
	var x := xf
	if n is Node3D: x = xf * (n as Node3D).transform
	if n is MeshInstance3D and (n as MeshInstance3D).mesh: out.append([(n as MeshInstance3D).mesh, x])
	for c in n.get_children(): _collect(c, x, out)

func _decor() -> void:
	var F := "res://assets/forest/"
	var biome := FastNoiseLite.new(); biome.seed = 909; biome.frequency = 0.035
	for i in 9000:
		var p := Vector3(rng.randf_range(-118, 118), 0, rng.randf_range(-118, 118))
		var h := height(p.x, p.z)
		if h < WATER_Y + 0.35 or not walkable(p.x, p.z): continue
		var rd := road_dist(p.x, p.z)
		if rd < 2.6: continue
		var vd := Vector2(p.x, p.z).distance_to(village)
		if vd < 32.0: continue
		var near_poi := false
		for g in gates:
			if Vector2(p.x - g.pos.x, p.z - g.pos.z).length() < 9.0: near_poi = true
		for sp in duel_spots:
			if Vector2(p.x - sp.x, p.z - sp.z).length() < 4.0: near_poi = true
		for q in POI_DEFS:
			if Vector2(p.x, p.z).distance_to(q.p) < q.r + 2.0: near_poi = true; break
		if near_poi: continue
		if near_house(Vector2(p.x, p.z), 0.5): continue
		var near_node := _near_node_grid(p, 2.4)
		# bas-côtés fleuris le long des chemins
		if rd > 3.0 and rd < 4.8 and rng.randf() < 0.22 and REGIONS[region_at(p.x, p.z)].style in ["meadow", "forest", "hills"]:
			_mm("res://assets/forest/" + ["Bush_1_A_Color1.gltf", "Grass_1_C_Color1.gltf", "Bush_3_A_Color1.gltf", "Grass_2_B_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU)
			continue
		var reg := region_at(p.x, p.z); var b := biome.get_noise_2d(p.x, p.z); var sl := slope(p.x, p.z)
		var roll := rng.randf(); var edge: bool = max(abs(p.x), abs(p.z)) > 104.0
		var CR: Array = ROCK_SET.get(REGIONS[reg].style, ROCK_SET.meadow)
		var top := plateau(p.x, p.z) > 0.9
		match REGIONS[reg].style:
			"meadow":
				if roll < 0.12: _mm(F + ["Grass_1_A_Color1.gltf", "Grass_2_B_Color1.gltf", "Grass_1_C_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.2, 1.8), rng.randf() * TAU)
				elif roll < 0.16: _mm(F + ["Bush_1_A_Color1.gltf", "Bush_2_A_Color1.gltf", "Bush_3_A_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.0, 1.6), rng.randf() * TAU)
				elif roll < (0.185 if top else 0.168): _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.6, 1.3), rng.randf() * TAU)
			"forest":
				if roll < 0.3: _mm(F + ["Grass_2_A_Color1.gltf", "Bush_1_E_Color1.gltf", "Grass_1_D_Color1.gltf", "Bush_2_D_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(1.0, 1.7), rng.randf() * TAU)
				elif roll < 0.312: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.6, 1.2), rng.randf() * TAU)
			"hills":
				if sl > 2.4 and roll < 0.25: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.8, 1.5), rng.randf() * TAU, Color("#f0e0c0"))
				elif roll < 0.2: _mm(F + ["Grass_1_B_Color1.gltf", "Grass_2_C_Color1.gltf"][rng.randi() % 2], p, rng.randf_range(1.0, 1.5), rng.randf() * TAU, Color("#f0d890"))
				elif roll < 0.215: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.6, 1.2), rng.randf() * TAU, Color("#f0e0c0"))
			"swamp":
				if roll < 0.3: _mm(F + ["Grass_2_D_Color1.gltf", "Grass_1_D_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.2, 1.9), rng.randf() * TAU, Color("#a8b090"))
				elif roll < 0.315: _mm("res://assets/halloween/gravestone.gltf", p, 1.1, rng.randf() * TAU)
				elif roll < 0.33: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.7, 1.3), rng.randf() * TAU)
				elif roll < 0.334: _mm(crystal(["PROP_18_DarkCursedCrystal", "PROP_09_FloatingMagicCrystal", "PROP_06_CrystalSpikes"][rng.randi() % 3]), p, rng.randf_range(0.7, 1.1), rng.randf() * TAU)
			"ash":
				if sl > 2.4 and roll < 0.35: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(1.0, 1.8), rng.randf() * TAU)
				elif roll < 0.06: _mm(["res://assets/halloween/bone_A.gltf", "res://assets/halloween/skull.gltf", "res://assets/halloween/ribcage.gltf"][rng.randi() % 3], p, 1.2, rng.randf() * TAU)
				elif roll < 0.1: _ember(p)
				elif roll < 0.13: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.8, 1.6), rng.randf() * TAU)
				elif roll < 0.136: _mm(crystal(["PROP_20_EmberCrystalFormation", "PROP_03_LargeCrystalCluster"][rng.randi() % 2]), p, rng.randf_range(0.8, 1.2), rng.randf() * TAU, Color("#ffb080"))
			"desert":
				if sl > 2.0 and roll < 0.3: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.8, 1.4), rng.randf() * TAU, Color("#f2d49a"))
				elif roll < 0.07: _mm(F + ["Grass_1_B_Color1.gltf", "Grass_2_C_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU, Color("#e6cf8a"))
				elif roll < 0.08: _mm(["res://assets/halloween/bone_A.gltf", "res://assets/halloween/skull.gltf", "res://assets/halloween/ribcage.gltf"][rng.randi() % 3], p, 1.3, rng.randf() * TAU)
				elif roll < 0.1: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.7, 1.3), rng.randf() * TAU, Color("#f0d29a"))
			"canyon":
				if sl > 2.2 and roll < 0.4: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(1.0, 1.9), rng.randf() * TAU, Color("#d07a55"))
				elif roll < 0.09: _mm(F + ["Grass_1_B_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 2], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU, Color("#a85a30"))
				elif roll < 0.11: _mm(CR[rng.randi() % CR.size()], p, rng.randf_range(0.7, 1.3), rng.randf() * TAU, Color("#c87a50"))
	# massifs de fleurs (couleurs de la palette Simple Polygon)
	var FL := [Color("#f08cd8"), Color("#f7e06a"), Color("#c090d8"), Color("#ffffff"), Color("#ff8a7a")]
	for i in 160:
		var c := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
		var st: String = REGIONS[region_at(c.x, c.z)].style
		if not st in ["meadow", "forest", "hills", "swamp"] or not walkable(c.x, c.z) or road_dist(c.x, c.z) < 3.0 or near_house(Vector2(c.x, c.z), 1.0): continue
		if Vector2(c.x, c.z).distance_to(village) < 26.0: continue
		var fc: Color = FL[rng.randi() % FL.size()]
		if st == "swamp": fc = fc.darkened(0.25)
		fc.a = 0.98
		for k in rng.randi_range(4, 9):
			var q := c + Vector3(rng.randf_range(-2.2, 2.2), 0, rng.randf_range(-2.2, 2.2))
			if not walkable(q.x, q.z): continue
			_mm("res://assets/forest/Bush_1_A_Color1.gltf" if k % 3 else "res://assets/forest/Grass_1_C_Color1.gltf", q, rng.randf_range(0.55, 0.9), rng.randf() * TAU, fc)
	# roseaux au bord de l'eau
	for i in 1500:
		var p := Vector3(rng.randf_range(-118, 118), 0, rng.randf_range(-118, 118))
		var h := height(p.x, p.z)
		if h > WATER_Y + 0.2 and h < WATER_Y + 0.9 and road_dist(p.x, p.z) > 3.0: _mm(F + "Grass_2_A_Color1.gltf", p, rng.randf_range(1.2, 1.8), rng.randf() * TAU, Color("#c8d890"))

var ember_count := 0
func _ember(p: Vector3) -> void:
	if ember_count > 40: return
	ember_count += 1
	var mi := MeshInstance3D.new(); var cm := CylinderMesh.new(); cm.top_radius = 0.9; cm.bottom_radius = 1.0; cm.height = 0.05; mi.mesh = cm
	var m := StandardMaterial3D.new(); m.albedo_color = Color(1.0, 0.35, 0.1); m.emission_enabled = true; m.emission = Color(1.0, 0.3, 0.05); m.emission_energy_multiplier = 1.6
	mi.material_override = m; mi.position = Vector3(p.x, height(p.x, p.z) + 0.03, p.z); mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)

# ——— Camps de monstres ———
# Seuls les repaires nommés (sur la carte) gardent un coffre — et il met longtemps à se remplir.
const KINDS_BY_T := {1: ["minion", "minion"], 2: ["minion", "minion", "rogue"], 3: ["minion", "warrior", "rogue"], 4: ["warrior", "rogue", "mage"], 5: ["warrior", "mage", "rogue", "minion"]}
func _monster_camps() -> void:
	for q in POI_DEFS:
		if q.has("chest"):
			var t: int = int(q.chest)
			_camp(Vector3(q.p.x, 0, q.p.y), t, KINDS_BY_T[t] + ([KINDS_BY_T[t][0]] if t >= 2 else []), true)
	for reg in range(1, REGIONS.size()):
		var R: Dictionary = REGIONS[reg]; var placed := 0; var tries := 0
		var want := 6 if R.tier > 1 else 4
		while placed < want and tries < 1500:
			tries += 1
			var p := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
			if region_at(p.x, p.z) != reg or not _free_spot(p, 3.0) or slope(p.x, p.z) > 1.4: continue
			if _near_duel(p, 20.0) or Vector2(p.x, p.z).distance_to(village) < 40.0: continue
			var ok := true
			for sp in spawns:
				if sp.pos.distance_to(p) < 18.0: ok = false; break
			if not ok: continue
			_camp(p, R.tier, KINDS_BY_T[R.tier], false); placed += 1
	for q in POI_DEFS:
		if q.kind == "lair":
			boss_pos = Vector3(q.p.x, 0, q.p.y)
			spawns.append({"pos": boss_pos, "tier": 5, "kinds": ["boss"], "members": [], "dead_at": -999.0, "boss": true})
	# meutes d'animaux sauvages
	var packs := {1: [["renard", "renard"], ["renard"], ["cerf"]], 2: [["loup", "loup", "loup"], ["cerf", "cerf"], ["renard", "renard"]], 3: [["taureau", "taureau"], ["loup", "loup"], ["cerf", "taureau"]],
		4: [["loup", "loup", "loup"], ["taureau", "loup"]], 5: [["loup", "loup", "taureau"], ["taureau", "taureau"]]}
	for reg in range(1, REGIONS.size()):
		var R: Dictionary = REGIONS[reg]; var placed := 0; var tries := 0
		while placed < 5 and tries < 1500:
			tries += 1
			var p := Vector3(rng.randf_range(-100, 100), 0, rng.randf_range(-100, 100))
			if region_at(p.x, p.z) != reg or not _free_spot(p, 3.0) or slope(p.x, p.z) > 1.6: continue
			if Vector2(p.x, p.z).distance_to(village) < 40.0: continue
			if _near_duel(p, 20.0): continue
			var ok := true
			for sp in spawns:
				if sp.pos.distance_to(p) < 16.0: ok = false; break
			if not ok: continue
			var opts: Array = packs[R.tier]
			spawns.append({"pos": p, "tier": R.tier, "kinds": opts[placed % opts.size()], "members": [], "dead_at": -999.0, "animal": true})
			placed += 1

func _camp(p: Vector3, t: int, kinds: Array, chest: bool) -> void:
	var sp := {"pos": p, "tier": t, "kinds": kinds, "members": [], "dead_at": -999.0, "chest_ready": true, "chest_open_at": -9999.0}
	if chest:
		sp["chest"] = place("res://assets/dungeon/chest.gltf", p, rng.randf() * TAU, 1.1); blocker(p, 0.6, 1.0)
	_mm("res://assets/dungeon/barrel_small_stack.gltf", p + Vector3(3.0, 0, -2.0), 0.6, 0.3)
	spawns.append(sp)

# ——— Duellistes : des combattants dispersés qui défient le héros ———
var duel_spots: Array = []
func _near_duel(p: Vector3, r: float) -> bool:
	for q in duel_spots:
		if Vector2(q.x - p.x, q.z - p.z).length() < r: return true
	return false

# Les duellistes attendent tous à l'arène de la carte, chacun dans son cercle
func _duelists() -> void:
	var arena := village + Vector2(20, 20)
	for q in POI_DEFS:
		if q.kind == "arena": arena = q.p
	var L: Array = MAP.duelists
	for i in L.size():
		var d: Dictionary = L[i]
		var a := PI * 0.5 + (i - (L.size() - 1) * 0.5) * 1.15
		var p := Vector3(arena.x + cos(a) * 9.5, 0, arena.y - sin(a) * 9.5)
		duel_spots.append(p)
		# petit cercle de duel au sol
		_ring(p, 3.2, Color(1.0, 0.55, 0.2, 0.55), 0.08)
		place("res://assets/dungeon/banner_patternC_red.gltf", p + Vector3(2.6, 0, -2.6), 0.6, 0.9)
		npc_spots.append({"id": d.id, "model": d.model, "name": d.name, "role": "Duelliste T%d" % d.tier, "pos": p, "act": "duel", "tier": d.tier, "wkind": d.wkind})

# ——— Coffres cachés (à découvrir, une seule fois) ———
func _hidden_chests() -> void:
	var i := 0
	for s in MAP.hidden:
		var p := Vector3(s.x, 0, s.y)
		for k in 200:
			if reachable(p.x, p.z) and slope(p.x, p.z) < 1.6 and not _near_cliff(p, 1.5): break
			var rr := 6.0 + k * 0.2
			p = Vector3(clamp(s.x + rng.randf_range(-rr, rr), -98, 98), 0, clamp(s.y + rng.randf_range(-rr, rr), -98, 98))
		var c := place("res://assets/dungeon/chest_gold.gltf", p, rng.randf() * TAU, 1.1)
		blocker(p, 0.6, 1.0)
		hidden_chests.append({"id": "m%d_hc%d" % [map_id, i], "pos": p, "node": c, "tier": tier_at(p)})
		i += 1

# Cache les arbres/rochers entre la caméra (au sud) et le héros, ou collés à lui
var placed_grid := {}       # modèles posés (murs, bâtiments…) qu'on peut masquer
var occ_active := {}
var occ_tick := 0.0
var hidden_placed := {}
func update_occlusion(pp: Vector3, dt: float) -> void:
	var want := {}
	var cx := int(floor(pp.x / 8.0)); var cz := int(floor(pp.z / 8.0))
	for dx in range(-1, 2):
		for dz in range(-1, 3):
			for rec in occ_grid.get(Vector2i(cx + dx, cz + dz), []):
				var d: Vector3 = rec.pos - pp
				# couloir vers la caméra (+z) ou tout près du héros
				if (abs(d.x) < 3.2 and d.z > -1.2 and d.z < 9.0) or Vector2(d.x, d.z).length() < 2.6: want[rec] = true
	for rec in want:
		if not occ_active.has(rec): occ_active[rec] = 1.0
	for rec in occ_active.keys():
		var target := 0.0 if want.has(rec) else 1.0
		var prev: float = occ_active[rec]
		var f: float = move_toward(prev, target, dt * 5.0)
		occ_active[rec] = f
		if f == prev:
			if f >= 1.0: occ_active.erase(rec)
			continue
		var s: float = max(0.001, f)
		for pair in rec.mms:
			var xf: Transform3D = rec.xf
			pair[0].set_instance_transform(rec.i, Transform3D(xf.basis.scaled(Vector3.ONE * s), xf.origin) * pair[1])
		if rec.has("blob"):
			var bx: Transform3D = rec.blob[1]
			rec.blob[0].set_instance_transform(rec.i, Transform3D(bx.basis.scaled(Vector3(s, 1, s)), bx.origin))
		if f >= 1.0 and target >= 1.0: occ_active.erase(rec)
	# arbres à récolter (modèles séparés) : même règle
	occ_tick -= dt
	if occ_tick > 0.0: return
	occ_tick = 0.12
	# murs, bâtiments, décors posés : masqués s'ils sont entre la caméra et le héros
	for dx in range(-2, 3):
		for dz in range(-1, 3):
			for o in placed_grid.get(Vector2i(cx + dx, cz + dz), []):
				if not is_instance_valid(o): continue
				var d3: Vector3 = o.position - pp
				var hide3: bool = abs(d3.x) < 4.5 and d3.z > 0.5 and d3.z < 10.0
				if o.visible == hide3: o.visible = not hide3
				if hide3: hidden_placed[o] = true
	for o in hidden_placed.keys():
		if not is_instance_valid(o): hidden_placed.erase(o); continue
		var d4: Vector3 = o.position - pp
		if not (abs(d4.x) < 4.5 and d4.z > 0.5 and d4.z < 10.0): o.visible = true; hidden_placed.erase(o)
	for nd in nodes:
		if nd.type != "wood" or not is_instance_valid(nd.model): continue
		var d2: Vector3 = nd.pos - pp
		var hide: bool = abs(d2.x) < 2.6 and d2.z > 0.8 and d2.z < 8.0
		nd.root.visible = not hide or nd.charges <= 0

# ——— Récolte ———
func nearest_node(p: Vector3, rmax := 2.6) -> Dictionary:
	var best := {}; var bd := rmax
	for nd in nodes:
		if nd.charges <= 0: continue
		var d: float = Vector2(nd.pos.x - p.x, nd.pos.z - p.z).length() - (0.6 if nd.type == "wood" else 0.3)
		if d < bd: bd = d; best = nd
	return best

func harvest(nd: Dictionary) -> void:
	nd.charges -= 1; nd.shake = 0.3
	if nd.charges <= 0:
		nd.respawn = 45.0 + nd.tier * 8.0
		nd.ring.visible = false; nd.badge.visible = false

func update_nodes(dt: float) -> void:
	for nd in nodes:
		var m: Node3D = nd.model
		if nd.shake > 0.0:
			nd.shake = max(0.0, nd.shake - dt)
			m.rotation.z = sin(nd.shake * 50.0) * nd.shake * 0.25
		if nd.charges <= 0:
			m.scale = m.scale.lerp(nd.base_scale * 0.25, min(1.0, dt * 6.0))
			nd.respawn -= dt
			if nd.respawn <= 0.0:
				nd.charges = nd.max; nd.ring.visible = true; nd.badge.visible = true
		elif m.scale.x < nd.base_scale.x * 0.99:
			m.scale = m.scale.lerp(nd.base_scale, min(1.0, dt * 4.0))

# ——— Image de la carte (mini-carte et carte du monde) ———
func map_image() -> Image:
	var R := 128; var img := Image.create(R, R, false, Image.FORMAT_RGBA8)
	for j in R:
		for i in R:
			var x := -HALF + (i + 0.5) * (HALF * 2.0 / R); var z := -HALF + (j + 0.5) * (HALF * 2.0 / R)
			var h := height(x, z)
			var reg := region_at(x, z)
			var c := Color(REGIONS[reg].g1).lerp(Color(REGIONS[reg].g0), 0.3)
			var sl := slope(x, z)
			if sl > 2.4: c = c.darkened(0.35)
			c = c.lightened(clamp(h * 0.03, -0.15, 0.2))
			if road_dist(x, z) < 2.2: c = Color("#d8c39a")
			if Vector2(x, z).distance_to(village) < 12.0: c = Color("#c9a978")
			if h < WATER_Y: c = Color("#4f93b8")
			img.set_pixel(i, j, c)
	return img


# ——— Le vent : les arbres, buissons et herbes ondulent (dans le shader, presque gratuit) ———
static func wind_amp(path: String) -> float:
	if "Grass" in path: return 0.32
	if "Bush" in path: return 0.5
	if "Tree_Bare" in path or "tree_dead" in path: return 0.004
	if "Tree" in path: return 0.0075
	return 0.0
static var _wind_sh: Shader
static var _wind_cache := {}
static func wind_mat(src: StandardMaterial3D, col: Color, amp: float) -> ShaderMaterial:
	var key := "%d|%s|%.4f" % [src.get_instance_id(), col.to_html(), amp]
	if _wind_cache.has(key): return _wind_cache[key]
	if _wind_sh == null:
		_wind_sh = Shader.new(); _wind_sh.code = """shader_type spatial;
render_mode cull_back;
uniform sampler2D tex : source_color, filter_linear_mipmap;
uniform vec4 tint : source_color = vec4(1.0);
uniform float amp = 0.01;
uniform float repl = 0.0;
void vertex() {
	vec3 o = (MODEL_MATRIX * vec4(0.0, 0.0, 0.0, 1.0)).xyz;
	float h = max(VERTEX.y, 0.0);
	float ph = TIME * 1.6 + o.x * 0.23 + o.z * 0.17;
	float w = sin(ph) * 0.7 + sin(ph * 2.7 + 1.3) * 0.3;
	float g = 0.6 + 0.4 * sin(TIME * 0.35 + o.x * 0.02);   // rafales lentes
	VERTEX.x += w * g * amp * h * h;
	VERTEX.z += w * g * amp * h * h * 0.45;
}
void fragment() {
	vec4 c = texture(tex, UV);
	ALBEDO = mix(c.rgb * tint.rgb, tint.rgb * (0.6 + 0.8 * dot(c.rgb, vec3(0.33))), repl);
	ROUGHNESS = 1.0;
}"""
	var m := ShaderMaterial.new(); m.shader = _wind_sh
	m.set_shader_parameter("tex", src.albedo_texture); m.set_shader_parameter("tint", Color(col.r, col.g, col.b) * src.albedo_color); m.set_shader_parameter("amp", amp)
	m.set_shader_parameter("repl", 1.0 if col.a < 0.99 else 0.0)   # fleurs : couleur franche au lieu d'une teinte
	_wind_cache[key] = m
	return m

# ——— Sol : couleurs du terrain + ombres de nuages qui glissent lentement ———
static var _ground_sh: Shader
var _ground_m: ShaderMaterial
func ground_mat() -> ShaderMaterial:
	if _ground_m: return _ground_m
	if _ground_sh == null:
		_ground_sh = Shader.new(); _ground_sh.code = """shader_type spatial;
uniform sampler2D clouds : filter_linear_mipmap, repeat_enable;
uniform float cloud_k = 0.22;
varying vec3 wp;
void vertex() { wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz; }
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
void fragment() {
	vec3 c = lin(COLOR.rgb);
	vec2 uv = wp.xz * 0.006 + vec2(TIME * 0.0016, TIME * 0.0009);
	float n = texture(clouds, uv).r * 0.65 + texture(clouds, uv * 2.3 + vec2(0.31, 0.17)).r * 0.35;
	float sh = smoothstep(0.5, 0.68, n);
	ALBEDO = c * (1.0 - cloud_k * sh);
	ROUGHNESS = 1.0;
}"""
	var nz := FastNoiseLite.new(); nz.seed = 4242; nz.frequency = 0.012; nz.fractal_octaves = 3
	var nt := NoiseTexture2D.new(); nt.width = 256; nt.height = 256; nt.seamless = true; nt.noise = nz; nt.generate_mipmaps = true
	_ground_m = ShaderMaterial.new(); _ground_m.shader = _ground_sh; _ground_m.set_shader_parameter("clouds", nt)
	return _ground_m

# ——— Faubourgs : des maisons de toutes les couleurs le long des routes qui quittent la ville ———
var house_spots: Array = []     # [Vector2, rayon]
var herds: Array = []           # bêtes des enclos {node, ap, pen: Vector2, r, tgt, wait, walk}
var smoke_n := 0
const HOUSES := ["building_home_A_blue", "building_home_B_blue", "building_home_A_red", "building_home_B_red", "building_home_A_green", "building_home_B_green", "building_home_A_yellow", "building_home_B_yellow"]
const VILLAGER_NAMES := ["Odette", "Gaspard", "Marthe", "Anselme", "Berthe", "Lucien", "Rosalie", "Firmin", "Agathe", "Hugues", "Clémence", "Barnabé"]

func near_house(q: Vector2, r: float) -> bool:
	for hs in house_spots:
		if q.distance_to(hs[0]) < float(hs[1]) + r: return true
	return false

func _house_ok(q: Vector2, rr: float) -> bool:
	if abs(q.x) > 100 or abs(q.y) > 100: return false
	if raw_height(q.x, q.y) < WATER_Y + 0.9 or not walkable(q.x, q.y) or not reachable(q.x, q.y): return false
	if river_dist(q.x, q.y) < RIVER_W + 4.0 or road_dist(q.x, q.y) < rr + 1.6: return false
	if slope(q.x, q.y) > 1.5: return false
	for lk in LAKES:
		if q.distance_to(lk[0]) < lk[1] + rr + 3.0: return false
	for g in MAP.gates:
		if q.distance_to(g.pos) < 14.0: return false
	for pd in POI_DEFS:
		if q.distance_to(pd.p) < pd.r + rr + 4.0: return false
	if BAY != null and q.distance_to(Vector2(18, 103)) < 16.0: return false
	if near_house(q, rr): return false
	return true


func _faubourgs() -> void:
	var H := "res://assets/hex/"; var F := "res://assets/forest/"
	var r := RandomNumberGenerator.new(); r.seed = 4400 + map_id
	var V := village
	var made: Array = []
	for rd in roads:
		for i in rd.size() - 1:
			var a: Vector2 = rd[i]; var b: Vector2 = rd[i + 1]; var L := a.distance_to(b)
			if L < 6.0: continue
			var dir := (b - a) / L; var nrm := Vector2(-dir.y, dir.x)
			var k := 3.0
			while k < L - 3.0:
				var c := a + dir * k; var dv := c.distance_to(V)
				k += r.randf_range(7.5, 9.5)
				if dv < 31.0 or dv > 54.0 or made.size() >= 8: continue
				for side: float in [-1.0, 1.0]:
					if r.randf() < 0.3 or made.size() >= 8: continue
					var q := c + nrm * side * r.randf_range(7.4, 8.8)
					if not _house_ok(q, 4.2): continue
					var to_rd := -nrm * side
					building(H + HOUSES[r.randi() % HOUSES.size()] + ".gltf", q, atan2(to_rd.x, to_rd.y), 4.4, 4.6)
					house_spots.append([q, 5.2]); made.append(q)
					var door := q + to_rd * 3.4
					# devant la porte : un tonneau, des caisses ou des sacs
					var pk := r.randi() % 4
					var pp := door + dir * r.randf_range(1.6, 2.4) * (1.0 if r.randf() < 0.5 else -1.0)
					match pk:
						0: place(H + "barrel.gltf", Vector3(pp.x, 0, pp.y), r.randf() * TAU, 4.5); blocker(Vector3(pp.x, 0, pp.y), 0.5)
						1: place(H + "crate_A_big.gltf", Vector3(pp.x, 0, pp.y), r.randf() * TAU, 4.5); blocker(Vector3(pp.x, 0, pp.y), 0.6)
						2: place(H + "sack.gltf", Vector3(pp.x, 0, pp.y), r.randf() * TAU, 4.5)
						3: place(H + "bucket_water.gltf", Vector3(pp.x, 0, pp.y), r.randf() * TAU, 4.5)
					# fleurs au pied des murs
					for f in 2:
						var fq := q + to_rd * 2.6 + dir * (2.6 if f == 0 else -2.6)
						_mm(F + ["Bush_1_A_Color1.gltf", "Bush_3_A_Color1.gltf", "Grass_1_C_Color1.gltf"][r.randi() % 3], Vector3(fq.x, 0, fq.y), r.randf_range(1.0, 1.4), r.randf() * TAU, [Color(1, 1, 1), Color("#ffd0e0"), Color("#fff0b0")][r.randi() % 3])
					# potager clôturé sur le côté
					var gs := 1.0 if r.randf() < 0.5 else -1.0
					var gq := q + dir * 6.2 * gs - to_rd * 0.6
					if _house_ok(gq, 2.6):
						house_spots.append([gq, 3.2])
						for row in 2:
							for col in 3:
								var cq := gq + dir * (col - 1) * 1.5 + to_rd * (row - 0.5) * 1.6
								_mm(F + ("Grass_2_D_Color1.gltf" if (row + col) % 2 == 0 else "Bush_2_A_Color1.gltf"), Vector3(cq.x, 0, cq.y), 1.1, r.randf() * TAU, Color("#e8ffb0") if row == 0 else Color(1, 1, 1))
					# fumée de cheminée et fenêtres éclairées la nuit
					if smoke_n < 9 and r.randf() < 0.65:
						_smoke(Vector3(q.x - to_rd.x * 1.0, height(q.x, q.y) + 4.6, q.y - to_rd.y * 1.0))
					_light(Vector3(door.x, height(door.x, door.y) + 1.6, door.y), Color("#ffb85a"), 1.2, 1.6)
	# des villageois qui vont d'une maison à l'autre
	var nv := 0
	for j in range(0, made.size() - 1, 2):
		if nv >= 4: break
		var p0: Vector2 = made[j]; var p1: Vector2 = made[j + 1]
		if p0.distance_to(p1) > 30.0: continue
		var w0 := _nearest_on_roads(p0); var w1 := _nearest_on_roads(p1)
		npc_spots.append({"id": "villageois_%d_%d" % [map_id, nv], "model": ["Rogue", "Ranger", "Barbarian", "Mage"][(nv + map_id) % 4], "name": VILLAGER_NAMES[(nv + map_id * 3) % VILLAGER_NAMES.size()], "role": "Villageois" if nv % 2 == 0 else "Villageoise", "pos": Vector3(w0.x, 0, w0.y), "act": "villager", "path": [w0, w0.lerp(w1, 0.5), w1, w0.lerp(w1, 0.5)]})
		nv += 1
	# un enclos avec des bêtes et un moulin à la sortie de la ville
	_pen_near_town(r)

func _pen_near_town(r: RandomNumberGenerator) -> void:
	var H := "res://assets/hex/"
	for tries in 60:
		var a := r.randf() * TAU; var d := r.randf_range(38.0, 58.0)
		var q := village + Vector2(cos(a), sin(a)) * d
		if not _house_ok(q, 8.0): continue
		house_spots.append([q, 9.0])
		_pen(q, 6.0, ["bull", "horse", "donkey"] if map_id != 3 else ["donkey", "donkey"], r)
		var mq := q + Vector2(cos(a), sin(a)) * 11.0
		if _house_ok(mq, 4.0):
			building(H + "building_windmill_blue.gltf", mq, r.randf() * TAU, 4.6, 4.5); house_spots.append([mq, 5.0])
			_spin_windmill()
		return

func _spin_windmill() -> void:
	# les ailes du moulin tournent doucement (le nœud des ailes, s'il existe dans le modèle)
	if _last_placed == null: return
	for n in _last_placed.find_children("*", "Node3D", true, false):
		if "fan" in n.name.to_lower() or "blade" in n.name.to_lower():
			var tw := n.create_tween().set_loops(); tw.tween_property(n, "rotation:z", n.rotation.z - TAU, 9.0).from(n.rotation.z)
			return

# Enclos rond de piquets avec quelques bêtes qui broutent et se déplacent tranquillement
func _pen(c: Vector2, rad: float, kinds: Array, r: RandomNumberGenerator) -> void:
	var seg := 2.1; var nseg := int(round(rad * 2.0 / seg))
	var half := nseg * seg * 0.5
	place("res://assets/hex/bucket_water.gltf", Vector3(c.x - half + 1.0, 0, c.y - half + 1.0), 0.0, 4.0)
	place("res://assets/hex/building_grain.gltf", Vector3(c.x + half + 2.6, 0, c.y - half + 1.0), r.randf() * TAU, 2.2)
	for k in kinds:
		var mdl: Node3D = load("res://assets/animals/%s.glb" % k).instantiate()
		var sc: float = {"bull": 0.5, "horse": 0.52, "donkey": 0.5}.get(k, 0.5)
		mdl.scale = Vector3.ONE * sc
		var p0 := c + Vector2(r.randf_range(-1, 1), r.randf_range(-1, 1)) * rad * 0.45
		mdl.position = Vector3(p0.x, height(p0.x, p0.y), p0.y); mdl.rotation.y = r.randf() * TAU
		add_child(mdl)
		for mi in mdl.find_children("*", "MeshInstance3D", true, false): (mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mdl.add_child(Chars.blob(1.4 / sc))
		var ap: AnimationPlayer = mdl.find_child("AnimationPlayer", true, false)
		if ap:
			for an in ["Idle", "Walk"]:
				if ap.has_animation(an): ap.get_animation(an).loop_mode = Animation.LOOP_LINEAR
			ap.play("Idle"); ap.seek(r.randf() * 2.0, true)
		herds.append({"node": mdl, "ap": ap, "pen": c, "r": rad * 0.6, "tgt": p0, "wait": r.randf_range(1.0, 6.0), "walk": false})

func _smoke(p: Vector3) -> void:
	smoke_n += 1
	var pt := CPUParticles3D.new(); pt.amount = 7; pt.lifetime = 4.5; pt.preprocess = 4.0
	pt.direction = Vector3(0.25, 1, 0); pt.spread = 12.0; pt.gravity = Vector3(0.12, 0.35, 0); pt.initial_velocity_min = 0.35; pt.initial_velocity_max = 0.6
	pt.scale_amount_min = 0.7; pt.scale_amount_max = 1.1
	var cv := Curve.new(); cv.add_point(Vector2(0, 0.35)); cv.add_point(Vector2(1, 1.6)); pt.scale_amount_curve = cv
	var g := Gradient.new(); g.set_color(0, Color(0.85, 0.85, 0.85, 0.0)); g.set_color(1, Color(0.7, 0.7, 0.72, 0.0)); g.add_point(0.2, Color(0.82, 0.82, 0.84, 0.42)); pt.color_ramp = g
	var q := QuadMesh.new(); q.size = Vector2(0.9, 0.9)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Fx.soft_tex(); m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; m.vertex_color_use_as_albedo = true
	q.material = m; pt.mesh = q; pt.position = p; pt.visibility_range_end = 55.0
	add_child(pt)

# Bêtes des enclos : animées seulement quand le joueur est proche
func update_life(dt: float, pp: Vector3) -> void:
	for h in herds:
		var nd: Node3D = h.node
		var near := Vector2(nd.position.x - pp.x, nd.position.z - pp.z).length() < 42.0
		var ap: AnimationPlayer = h.ap
		if ap and ap.active != near: ap.active = near
		if not near: continue
		if h.walk:
			var t: Vector2 = h.tgt; var to := Vector2(t.x - nd.position.x, t.y - nd.position.z)
			if to.length() < 0.3:
				h.walk = false; h.wait = randf_range(3.0, 9.0)
				if ap: ap.play("Idle", 0.3)
			else:
				var v := to.normalized() * 0.9 * dt
				nd.position.x += v.x; nd.position.z += v.y; nd.position.y = height(nd.position.x, nd.position.z)
				nd.rotation.y = lerp_angle(nd.rotation.y, atan2(to.x, to.y), 1.0 - exp(-dt * 3.0))
		else:
			h.wait -= dt
			if h.wait <= 0.0:
				var c: Vector2 = h.pen
				h.tgt = c + Vector2(randf_range(-1, 1), randf_range(-1, 1)).limit_length(1.0) * float(h.r)
				h.walk = true
				if ap and ap.has_animation("Walk"): ap.play("Walk", 0.3)


# ================= RELIEF =================
# Plateaux à falaises : un bruit seuillé dessine des massifs aux bords nets, que l'on habille de vraies falaises.
const PLATEAU_T := {"meadow": 0.2, "forest": 0.15, "hills": 0.05, "desert": 0.2, "canyon": 0.0, "swamp": 0.3, "ash": 0.04}
const PLATEAU_2 := {"forest": 0.2, "hills": 0.17, "canyon": 0.18, "ash": 0.2, "meadow": 0.24}   # second étage (au-dessus du seuil + écart)
const PLATEAU_H := {"meadow": 4.0, "forest": 4.6, "hills": 5.2, "desert": 3.6, "canyon": 6.0, "swamp": 3.2, "ash": 6.0}
const CLIFF_PAL := {"canyon": "Red", "desert": "Red", "ash": "Grey"}

func _clear_k(x: float, z: float) -> float:
	# 0 = interdit (ville, lieux, eau, passages), 1 = libre
	var q := Vector2(x, z)
	var k: float = smoothstep(40.0, 48.0, q.distance_to(village))
	if k <= 0.0: return 0.0
	for pd in POI_DEFS:
		k = min(k, smoothstep(pd.r + 6.0, pd.r + 12.0, q.distance_to(pd.p)))
	for g in MAP.gates: k = min(k, smoothstep(14.0, 22.0, q.distance_to(g.pos)))
	k = min(k, smoothstep(RIVER_W + 5.0, RIVER_W + 11.0, river_dist(x, z)))
	for lk in LAKES: k = min(k, smoothstep(lk[1] + 5.0, lk[1] + 11.0, q.distance_to(lk[0])))
	if BAY != null: k = min(k, smoothstep(30.0, 40.0, q.distance_to(BAY)))
	if not volcano.is_empty(): k = min(k, smoothstep(float(volcano.r) * 0.95, float(volcano.r) * 1.15, q.distance_to(volcano.pos)))
	return k

var _last_pk := 0.0
var _last_clear := -1.0
func plateau(x: float, z: float, lv := 1) -> float:
	if abs(x) > 112.0 or abs(z) > 112.0: return 0.0
	return _plateau_w(x, z, region_weights(x, z), lv)
func _plateau_w(x: float, z: float, w: Array, lv: int, clear := -1.0) -> float:
	if abs(x) > 112.0 or abs(z) > 112.0: return 0.0
	var t: float = lerp(float(PLATEAU_T.get(REGIONS[w[1]].style, 0.3)), float(PLATEAU_T.get(REGIONS[w[0]].style, 0.3)), w[2])
	if lv == 2:
		var a: String = REGIONS[w[0]].style
		if not PLATEAU_2.has(a): return 0.0
		t += float(PLATEAU_2[a])
	var n := pnoise.get_noise_2d(x, z)
	var k := smoothstep(t, t + 0.022, n)
	if k <= 0.0: return 0.0
	if clear < 0.0: clear = _clear_k(x, z); _last_clear = clear
	return k * clear

# chaîne de montagnes tout autour : on ne sort que par les cols des passages
func border_k(x: float, z: float) -> float:
	var e: float = max(abs(x), abs(z)) + noise.get_noise_2d(x * 1.7, z * 1.7) * 5.0
	var k := smoothstep(101.0, 106.0, e)
	if k <= 0.0: return 0.0
	for g in MAP.gates: k = min(k, smoothstep(9.0, 15.0, Vector2(x, z).distance_to(g.pos)))
	if BAY != null: k = min(k, smoothstep(26.0, 34.0, Vector2(x, z).distance_to(BAY)))
	for rv in RIVERS:
		for pt in [rv[0], rv[rv.size() - 1]]: k = min(k, smoothstep(RIVER_W + 3.0, RIVER_W + 8.0, Vector2(x, z).distance_to(pt)))
	k = min(k, smoothstep(RIVER_W + 2.0, RIVER_W + 6.0, river_dist(x, z)))
	return k

# Volcan : le relief vient du modèle fourni (cratère, coulée), mis à l'échelle du monde
func volcano_k(x: float, z: float) -> float:
	if volcano.is_empty() or vol_img == null: return 0.0
	var c: Vector2 = volcano.pos; var r: float = volcano.r
	var u := (x - c.x) / (r * 2.0) + 0.5; var v := (z - c.y) / (r * 2.0) + 0.5
	if u <= 0.0 or v <= 0.0 or u >= 1.0 or v >= 1.0: return 0.0
	var fx := u * 128.0; var fz := v * 128.0
	var i := int(fx); var j := int(fz); var a := fx - i; var b := fz - j
	var h00 := vol_img.get_pixel(i, j).r; var h10 := vol_img.get_pixel(min(i + 1, 128), j).r
	var h01 := vol_img.get_pixel(i, min(j + 1, 128)).r; var h11 := vol_img.get_pixel(min(i + 1, 128), min(j + 1, 128)).r
	var h: float = lerp(lerp(h00, h10, a), lerp(h01, h11, a), b)
	# fondu sur les bords de la tuile
	var edge: float = min(min(u, 1.0 - u), min(v, 1.0 - v))
	return h * smoothstep(0.0, 0.12, edge)
func volcano_h(x: float, z: float) -> float:
	var k := volcano_k(x, z)
	return 0.0 if k <= 0.0 else max(0.0, k - 0.03) * float(volcano.h)

func _compute_blocked() -> void:
	blocked.resize(N * N); blocked.fill(0)
	for j in N:
		for i in N:
			var x := -HALF + i * CELL; var z := -HALF + j * CELL
			var hh := hs[j * N + i]
			# pente du sol réel : une marche de plus de 2,2 m sur 2 m = falaise
			var sl := 0.0
			if i > 0: sl = max(sl, abs(hh - hs[j * N + i - 1]))
			if i < N - 1: sl = max(sl, abs(hh - hs[j * N + i + 1]))
			if j > 0: sl = max(sl, abs(hh - hs[(j - 1) * N + i]))
			if j < N - 1: sl = max(sl, abs(hh - hs[(j + 1) * N + i]))
			var blk := sl > 2.2 and road_dist(x, z) > 4.5 and not _near_ramp(Vector2(x, z), 2.6)
			if border_k(x, z) > 0.45 and road_dist(x, z) > 5.0: blk = true
			if volcano_k(x, z) > 0.55: blk = true
			if blk: blocked[j * N + i] = 1

# Palette Simple Polygon : l'herbe du haut des falaises prend la couleur de la région
var _cliff_mats := {}
func cliff_mat(grass: Color) -> StandardMaterial3D:
	var key := grass.to_html()
	if _cliff_mats.has(key): return _cliff_mats[key]
	var pal: String = _pal_for.get(key, "Grey")
	var rock_t: Color = _rock_tint.get(key, Color(1, 1, 1))
	var img: Image = (load("res://assets/relief/Colorscheme %s.png" % pal) as Texture2D).get_image()
	img = img.duplicate(); if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			if c.g > c.r + 0.03 and c.g > c.b + 0.15: img.set_pixel(xx, yy, grass)   # case verte = herbe
			else: img.set_pixel(xx, yy, Color(c.r * rock_t.r, c.g * rock_t.g, c.b * rock_t.b, c.a))
	var m := StandardMaterial3D.new(); m.albedo_texture = ImageTexture.create_from_image(img); m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_NEAREST; m.roughness = 1.0
	_cliff_mats[key] = m
	return m
var _pal_for := {}
var _rock_tint := {}
const ROCK_TINT := {"canyon": Color(0.95, 0.62, 0.48), "desert": Color(1.0, 0.82, 0.62), "ash": Color(0.62, 0.55, 0.55), "swamp": Color(0.78, 0.82, 0.76), "hills": Color(1.0, 0.95, 0.85)}

const CLIFFS := ["res://assets/relief/clifftile_straight_1.dae", "res://assets/relief/clifftile_straight_2.dae", "res://assets/relief/clifftile_straight_3.dae"]
const KR := "res://assets/forest/"
const CR_ := "res://assets/crystal/"
const ROCK_SET := {
	"meadow": [KR + "Rock_1_A_Color1.gltf", KR + "Rock_1_E_Color1.gltf", KR + "Rock_3_A_Color1.gltf", KR + "Rock_1_N_Color1.gltf"],
	"forest": [KR + "Rock_1_A_Color1.gltf", KR + "Rock_3_K_Color1.gltf", KR + "Rock_1_E_Color1.gltf", KR + "Rock_3_M_Color1.gltf"],
	"hills": [KR + "Rock_3_A_Color1.gltf", KR + "Rock_3_M_Color1.gltf", KR + "Rock_1_E_Color1.gltf", KR + "Rock_3_K_Color1.gltf"],
	"desert": [CR_ + "ROCK_Ancient_02_RuinedPillar.glb", KR + "Rock_3_A_Color1.gltf", KR + "Rock_1_E_Color1.gltf", CR_ + "ROCK_Ancient_05_CarvedRubble.glb"],
	"canyon": [CR_ + "ROCK_Volcanic_01_LargeCrag.glb", CR_ + "ROCK_Volcanic_04_BasaltPillar.glb", KR + "Rock_3_M_Color1.gltf", CR_ + "ROCK_Volcanic_05_DebrisCluster.glb"],
	"swamp": [CR_ + "ROCK_Corrupted_02_MediumHorn.glb", CR_ + "ROCK_Corrupted_04_TwistedPinnacle.glb", KR + "Rock_1_N_Color1.gltf", CR_ + "ROCK_Corrupted_05_VoidFragments.glb"],
	"ash": [CR_ + "ROCK_Volcanic_01_LargeCrag.glb", CR_ + "ROCK_Volcanic_04_BasaltPillar.glb", CR_ + "ROCK_Volcanic_02_MediumBlock.glb", CR_ + "ROCK_Corrupted_04_TwistedPinnacle.glb"],
}
static func crystal(nm: String) -> String: return "res://assets/crystal/%s.glb" % nm

func _mm_xf(path: String, xf: Transform3D, col := Color(1, 1, 1)) -> void:
	var key := path + "|" + col.to_html() + "|" + str(int(floor((xf.origin.x + HALF) / 64.0))) + "," + str(int(floor((xf.origin.z + HALF) / 64.0)))
	if not mm_lists.has(key): mm_lists[key] = []
	mm_lists[key].append(xf)

# Habillage des falaises : on suit le contour des plateaux et de la chaîne de bord, une tuile tous les ~5,5 m
func _cliffs() -> void:
	var r := RandomNumberGenerator.new(); r.seed = 7700 + map_id
	_cliff_level(r, 1)
	_cliff_level(r, 2)

func _field(x: float, z: float, lv: int) -> float:
	return max(plateau(x, z), border_k(x, z)) if lv == 1 else plateau(x, z, 2)

func _cliff_level(r: RandomNumberGenerator, lv: int) -> void:
	var G := 2.5
	var nx := int(224.0 / G)
	var vals := PackedFloat32Array(); vals.resize((nx + 1) * (nx + 1))
	for j in nx + 1:
		for i in nx + 1:
			var x := -112.0 + i * G; var z := -112.0 + j * G
			vals[j * (nx + 1) + i] = _field(x, z, lv)
	var pts: Array = []
	var iso := 0.1
	for j in nx:
		for i in nx:
			var v00 := vals[j * (nx + 1) + i]; var v10 := vals[j * (nx + 1) + i + 1]; var v01 := vals[(j + 1) * (nx + 1) + i]; var v11 := vals[(j + 1) * (nx + 1) + i + 1]
			var lo: float = min(min(v00, v10), min(v01, v11)); var hi: float = max(max(v00, v10), max(v01, v11))
			if lo > iso or hi < iso: continue
			# point du contour dans la case (moyenne des croisements)
			var acc := Vector2.ZERO; var n := 0
			var x0 := -112.0 + i * G; var z0 := -112.0 + j * G
			for e in [[v00, v10, Vector2(0, 0), Vector2(1, 0)], [v01, v11, Vector2(0, 1), Vector2(1, 1)], [v00, v01, Vector2(0, 0), Vector2(0, 1)], [v10, v11, Vector2(1, 0), Vector2(1, 1)]]:
				var a: float = e[0]; var b: float = e[1]
				if (a - iso) * (b - iso) < 0.0:
					var t := (iso - a) / (b - a); var pa: Vector2 = e[2]; var pb: Vector2 = e[3]
					acc += pa.lerp(pb, t); n += 1
			if n == 0: continue
			pts.append(Vector2(x0, z0) + acc / n * G)
	# on garde des points espacés
	var grid := {}; var kept: Array = []
	pts.shuffle()
	for q: Vector2 in pts:
		var gk := Vector2i(int(floor(q.x / 6.0)), int(floor(q.y / 6.0)))
		var ok := true
		for dx in range(-1, 2):
			for dz in range(-1, 2):
				for o in grid.get(gk + Vector2i(dx, dz), []):
					if q.distance_to(o) < 3.7: ok = false
		if not ok: continue
		if not grid.has(gk): grid[gk] = []
		grid[gk].append(q); kept.append(q)
	var nc := 0
	for q: Vector2 in kept:
		if road_dist(q.x, q.y) < 6.5 or _near_ramp(q, 5.5): continue
		# normale vers l'extérieur (le plateau monte vers l'intérieur)
		var e := 1.2
		var gx: float = _field(q.x + e, q.y, lv) - _field(q.x - e, q.y, lv)
		var gz: float = _field(q.x, q.y + e, lv) - _field(q.x, q.y - e, lv)
		var g := Vector2(gx, gz)
		if g.length() < 0.01: continue
		var out := -g.normalized()
		var top := height(q.x - out.x * 4.0, q.y - out.y * 4.0); var bot := height(q.x + out.x * 2.5, q.y + out.y * 2.5)
		var drop := top - bot
		if drop < 1.1: continue
		var reg: Dictionary = REGIONS[region_at(q.x, q.y)]
		var grass := Color(reg.g0).lerp(Color(reg.g1), 0.5).darkened(0.16)
		_pal_for[grass.to_html()] = CLIFF_PAL.get(reg.style, "Grey"); _rock_tint[grass.to_html()] = ROCK_TINT.get(reg.style, Color(1, 1, 1))
		var sxz := r.randf_range(0.29, 0.33)
		var sy := (drop + 1.8) / 12.4
		var tan := Vector2(out.y, -out.x)   # repère direct (sinon la tuile est retournée, faces à l'envers)
		var bas := Basis(Vector3(tan.x, 0, tan.y) * sxz, Vector3(0, sy, 0), Vector3(out.x, 0, out.y) * sxz)
		# tuile : origine au bout gauche, face avant vers +Z à ~z=+3,5 → on la centre sur le contour
		var o3 := Vector3(q.x, bot - 1.8, q.y) - bas * Vector3(10.0, 0, 3.0)
		var tq := q - out * 2.5
		var top_col := _ground_color(tq.x, tq.y, top, 0.5)
		var ck: String = CLIFFS[r.randi() % CLIFFS.size()] + "|" + str(reg.style) + "|" + str(int(floor((q.x + HALF) / 64.0))) + "," + str(int(floor((q.y + HALF) / 64.0)))
		if not cliff_lists.has(ck): cliff_lists[ck] = []
		cliff_lists[ck].append([Transform3D(bas, o3), top_col])
		nc += 1
		cliff_dbg.append([Vector3(q.x, bot, q.y), out, drop])
		# rochers au pied, pour casser les raccords
		if r.randf() < 0.45:
			var rs: Array = ROCK_SET.get(reg.style, ROCK_SET.meadow)
			var rp := q + out * r.randf_range(1.2, 2.4) + tan * r.randf_range(-2.5, 2.5)
			_mm(rs[r.randi() % rs.size()], Vector3(rp.x, 0, rp.y), r.randf_range(0.8, 1.5), r.randf() * TAU)
	cliff_count += nc
var cliff_count := 0
var cliff_dbg: Array = []

# Volcan : fumée et lueur au sommet, lave qui rougeoie la nuit
func _volcano_fx() -> void:
	if volcano.is_empty(): return
	# sommet = point le plus haut de la zone
	var c: Vector2 = volcano.pos; var r: float = volcano.r
	var best := Vector3.ZERO
	for j in 40:
		for i in 40:
			var x := c.x - r + i * r / 20.0; var z := c.y - r + j * r / 20.0
			var hh := height(x, z)
			if hh > best.y: best = Vector3(x, hh, z)
	var pt := CPUParticles3D.new(); pt.amount = 14; pt.lifetime = 7.0; pt.preprocess = 6.0
	pt.direction = Vector3(0.2, 1, 0); pt.spread = 18.0; pt.gravity = Vector3(0.25, 0.4, 0); pt.initial_velocity_min = 1.0; pt.initial_velocity_max = 1.8
	pt.scale_amount_min = 3.0; pt.scale_amount_max = 4.5
	var cv := Curve.new(); cv.add_point(Vector2(0, 0.4)); cv.add_point(Vector2(1, 2.2)); pt.scale_amount_curve = cv
	var gr := Gradient.new(); gr.set_color(0, Color(1.0, 0.45, 0.2, 0.0)); gr.add_point(0.12, Color(0.45, 0.38, 0.36, 0.55)); gr.set_color(1, Color(0.3, 0.28, 0.28, 0.0)); pt.color_ramp = gr
	var qm := QuadMesh.new(); qm.size = Vector2(1.6, 1.6)
	var m := StandardMaterial3D.new(); m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_texture = Fx.soft_tex(); m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES; m.vertex_color_use_as_albedo = true
	qm.material = m; pt.mesh = qm; pt.position = best + Vector3(0, 1.0, 0); pt.visibility_range_end = 160.0
	add_child(pt)
	for k in 5:
		var a := TAU * k / 5.0
		_light(best + Vector3(cos(a) * 3.0, 0.8, sin(a) * 3.0), Color("#ff6a2a"), 2.8, 7.0)
	label(str(volcano.get("name", "Volcan")), best + Vector3(0, 5.0, 0), Color("#ffb07a"), 80).visibility_range_end = 160.0


# ——— Rampes : chaque plateau a au moins une montée douce, reliée à la route la plus proche ———
var ramps: Array = []   # {a: bas, b: haut, lv}
func _ramp_f(q: Vector2, rp: Dictionary) -> float:
	var ab: Vector2 = rp.b - rp.a
	var t: float = clamp((q - rp.a).dot(ab) / ab.length_squared(), 0.0, 1.0)
	var d := q.distance_to(rp.a + ab * t)
	var w := 1.0 - smoothstep(2.6, 5.0, d)
	if w <= 0.0: return 1.0
	# au-delà du haut de la rampe : plein plateau
	var tt: float = (q - rp.a).dot(ab) / ab.length_squared()
	if tt >= 1.0: return 1.0
	return lerp(1.0, clamp(tt, 0.0, 1.0), w)
func _near_ramp(q: Vector2, r: float) -> bool:
	for rp in ramps:
		if seg_dist(q, rp.a, rp.b) < r: return true
	return false

func _plan_ramps() -> void:
	ramps = []
	for lv in [1, 2]:
		var G := 4.0; var n := int(208.0 / G)
		var lab := {}
		var comps: Array = []
		for j in n:
			for i in n:
				var c := Vector2i(i, j)
				if lab.has(c): continue
				var q := Vector2(-104.0 + i * G, -104.0 + j * G)
				if plateau(q.x, q.y, lv) < 0.5: continue
				# composante connexe
				var cells: Array = []; var stack := [c]; lab[c] = comps.size()
				while not stack.is_empty():
					var cc: Vector2i = stack.pop_back(); cells.append(cc)
					for d in [Vector2i(1, 0), Vector2i(-1, 0), Vector2i(0, 1), Vector2i(0, -1)]:
						var nb: Vector2i = cc + d
						if nb.x < 0 or nb.y < 0 or nb.x >= n or nb.y >= n or lab.has(nb): continue
						var nq := Vector2(-104.0 + nb.x * G, -104.0 + nb.y * G)
						if plateau(nq.x, nq.y, lv) < 0.5: continue
						lab[nb] = comps.size(); stack.append(nb)
				comps.append(cells)
		for cells in comps:
			if cells.size() < 4: continue
			var ctr := Vector2.ZERO
			for cc in cells: ctr += Vector2(-104.0 + cc.x * G, -104.0 + cc.y * G)
			ctr /= cells.size()
			# déjà traversé par une route ? alors accessible
			var crossed := false
			for cc in cells:
				if road_dist(-104.0 + cc.x * G, -104.0 + cc.y * G) < 4.0: crossed = true; break
			var target := _nearest_on_roads(ctr)
			if crossed:
				# la route coupe le plateau : la rampe part du bord le plus proche du centre de la ville
				target = village
			if lv == 2:
				# le pied de la rampe doit être sur le premier étage
				target = ctr
			# case du bord la plus proche de la cible
			var best := Vector2.ZERO; var bd := 1e9
			for cc in cells:
				var q := Vector2(-104.0 + cc.x * G, -104.0 + cc.y * G)
				var edge := false
				for d in [Vector2(G, 0), Vector2(-G, 0), Vector2(0, G), Vector2(0, -G)]:
					if plateau(q.x + d.x, q.y + d.y, lv) < 0.5: edge = true
				if not edge: continue
				var dd := q.distance_to(target) if lv == 1 else -q.distance_to(ctr) + randf() * 0.01
				if dd < bd: bd = dd; best = q
			if best == Vector2.ZERO: continue
			var inward := (ctr - best).normalized()
			if inward.length() < 0.5: continue
			var top := best + inward * 5.0
			var bot := best - inward * 13.0
			if lv == 2 and plateau(bot.x, bot.y, 1) < 0.6: continue
			if lv == 1 and (not _ramp_ground_ok(bot) or _crosses_water(bot, best)): continue
			ramps.append({"a": bot, "b": top, "lv": lv})
			if lv == 1:
				var e := _nearest_on_roads(bot)
				if e.distance_to(bot) > 4.0 and e.distance_to(bot) < 80.0 and not _crosses_water(bot, e): roads.append([e, bot])

func _ramp_ground_ok(q: Vector2) -> bool:
	if abs(q.x) > 100 or abs(q.y) > 100: return false
	if plateau(q.x, q.y) > 0.2 or border_k(q.x, q.y) > 0.1: return false
	if river_dist(q.x, q.y) < RIVER_W + 3.0: return false
	return true

var reach := PackedByteArray()
func _compute_reach() -> void:
	reach.resize(N * N); reach.fill(0)
	var si := int(round((village.x + HALF) / CELL)); var sj := int(round((village.y + HALF) / CELL))
	var stack := PackedInt32Array([sj * N + si]); reach[sj * N + si] = 1
	while stack.size() > 0:
		var k := stack[stack.size() - 1]; stack.resize(stack.size() - 1)
		var i := k % N; var j := k / N
		for d in [[1, 0], [-1, 0], [0, 1], [0, -1]]:
			var ii: int = i + d[0]; var jj: int = j + d[1]
			if ii < 0 or jj < 0 or ii >= N or jj >= N: continue
			var kk := jj * N + ii
			if reach[kk] == 1: continue
			if not walkable(-HALF + ii * CELL, -HALF + jj * CELL): continue
			reach[kk] = 1; stack.append(kk)
func reachable(x: float, z: float) -> bool:
	if reach.is_empty(): return true
	var i := int(round((x + HALF) / CELL)); var j := int(round((z + HALF) / CELL))
	if i < 0 or j < 0 or i >= N or j >= N: return false
	return reach[j * N + i] == 1


# Falaises : un seul maillage par type de tuile, le dessus prend exactement la couleur du sol à cet endroit
var cliff_lists := {}
static var _cliff_sh: Shader
var _cliff_style_mats := {}
func _cliff_style_mat(style: String) -> ShaderMaterial:
	if _cliff_style_mats.has(style): return _cliff_style_mats[style]
	if _cliff_sh == null:
		_cliff_sh = Shader.new(); _cliff_sh.code = """shader_type spatial;
uniform sampler2D pal : source_color, filter_nearest;
uniform sampler2D gmask : filter_nearest;
uniform vec3 rock_tint = vec3(1.0);
varying vec3 gcol;
void vertex() { gcol = INSTANCE_CUSTOM.rgb; }
vec3 lin(vec3 c) { return mix(pow((c + 0.055) / 1.055, vec3(2.4)), c / 12.92, lessThan(c, vec3(0.04045))); }
void fragment() {
	vec3 p = texture(pal, UV).rgb;
	float g = texture(gmask, UV).r;
	ALBEDO = mix(p * rock_tint, lin(gcol), g);
	ROUGHNESS = 1.0;
}"""
	var palname: String = CLIFF_PAL.get(style, "Grey")
	var img: Image = (load("res://assets/relief/Colorscheme %s.png" % palname) as Texture2D).get_image()
	img = img.duplicate(); if img.is_compressed(): img.decompress()
	img.convert(Image.FORMAT_RGBA8)
	var mk := Image.create(img.get_width(), img.get_height(), false, Image.FORMAT_L8)
	for yy in img.get_height():
		for xx in img.get_width():
			var c := img.get_pixel(xx, yy)
			if c.g > c.r + 0.03 and c.g > c.b + 0.15: mk.set_pixel(xx, yy, Color(1, 1, 1))
	var m := ShaderMaterial.new(); m.shader = _cliff_sh
	m.set_shader_parameter("pal", ImageTexture.create_from_image(img)); m.set_shader_parameter("gmask", ImageTexture.create_from_image(mk))
	var rt: Color = ROCK_TINT.get(style, Color(1, 1, 1))
	m.set_shader_parameter("rock_tint", Vector3(rt.r, rt.g, rt.b))
	_cliff_style_mats[style] = m
	return m

func _build_cliffs() -> void:
	for key in cliff_lists:
		var parts: PackedStringArray = key.split("|")
		var items: Array = cliff_lists[key]
		var sc: Node3D = load(parts[0]).instantiate()
		var meshes: Array = []
		_collect(sc, Transform3D.IDENTITY, meshes)
		for m in meshes:
			var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_custom_data = true; mm.mesh = m[0]; mm.instance_count = items.size()
			for i in items.size():
				mm.set_instance_transform(i, items[i][0] * m[1])
				var c: Color = items[i][1]
				mm.set_instance_custom_data(i, Color(c.r, c.g, c.b, 1.0))
			var mmi := MultiMeshInstance3D.new(); mmi.multimesh = mm; mmi.material_override = _cliff_style_mat(parts[1])
			mmi.visibility_range_end = 110.0; mmi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
			add_child(mmi)
		sc.free()


# ——— Villes : portes gardées sur chaque route, petits arbres et massifs autour de la place ———
const GUARD_NAMES := ["Garde Aubin", "Garde Mathis", "Garde Ysolde", "Garde Bertrand", "Garde Elise", "Garde Roland", "Garde Clovis", "Garde Maëlle", "Garde Tristan", "Garde Agnès"]
func _town_dressing() -> void:
	var V := village; var H := "res://assets/hex/"; var F := "res://assets/forest/"
	var r := RandomNumberGenerator.new(); r.seed = 5150 + map_id
	var tint: Color = MAP.town.get("tint", Color(1, 1, 1))
	# portes : là où chaque route sort de la ville
	var gates_done: Array = []; var gi := 0
	for rd in roads:
		if rd.size() < 2 or (rd[0] as Vector2).distance_to(V) > 6.0: continue
		var R := 31.0
		var gp := Vector2.INF; var dir := Vector2.ZERO
		for i in rd.size() - 1:
			var a: Vector2 = rd[i]; var b: Vector2 = rd[i + 1]
			if a.distance_to(V) <= R and b.distance_to(V) > R:
				var t := 0.0
				for k in 40:
					t = k / 40.0
					if a.lerp(b, t).distance_to(V) > R: break
				gp = a.lerp(b, t); dir = (b - a).normalized(); break
		if gp == Vector2.INF: continue
		var dup := false
		for g in gates_done:
			if gp.distance_to(g) < 9.0: dup = true
		if dup or not walkable(gp.x, gp.y) or river_dist(gp.x, gp.y) < RIVER_W + 2.0: continue
		gates_done.append(gp)
		var side := Vector2(-dir.y, dir.x)
		var rot := atan2(side.x, side.y)
		for sd in [-3.4, 3.4]:
			var q: Vector2 = gp + side * sd
			place("res://assets/dungeon/pillar_decorated.gltf", Vector3(q.x, 0, q.y), rot, 1.0); blocker(Vector3(q.x, 0, q.y), 0.6)
			_tint_last(tint)
			var bq: Vector2 = q - dir * 0.6
			place("res://assets/dungeon/banner_patternB_blue.gltf", Vector3(bq.x, 0, bq.y), rot + PI * 0.5, 1.1)
			_light(Vector3(q.x, height(q.x, q.y) + 2.9, q.y), Color("#ffbf66"), 1.8, 2.2)
		for k in 2:
			var sd2 := -2.0 if k == 0 else 2.0
			var gq: Vector2 = gp + side * sd2 + dir * 0.8
			npc_spots.append({"id": "garde_%d_%d" % [map_id, gi], "model": "Knight", "name": GUARD_NAMES[(gi + map_id * 3) % GUARD_NAMES.size()], "role": "Garde de la ville", "pos": Vector3(gq.x, 0, gq.y), "act": "guard", "yaw": atan2(dir.x, dir.y)})
			gi += 1
	# petits arbres d'ornement et massifs de fleurs entre les étals, autour de la place
	var FL := [Color("#f08cd8"), Color("#f7e06a"), Color("#c090d8"), Color("#ffffff")]
	for i in 12:
		var a := TAU * i / 12.0 + 0.13
		var q := V + Vector2(cos(a), sin(a)) * 12.5
		var ok := road_dist(q.x, q.y) > 2.5
		for ds in dirt_spots:
			if q.distance_to(ds[0]) < 3.6: ok = false
		for fp in foot_paths:
			if seg_dist(q, fp[0], fp[1]) < 2.2: ok = false
		if not ok or not walkable(q.x, q.y): continue
		if i % 2 == 0:
			place(F + ["Tree_1_A_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_1_C_Color1.gltf"][r.randi() % 3], Vector3(q.x, 0, q.y), r.randf() * TAU, r.randf_range(0.5, 0.62)); blocker(Vector3(q.x, 0, q.y), 0.5)
			house_spots.append([q, 1.5])
		var fc: Color = FL[r.randi() % FL.size()]; fc.a = 0.98
		for k in 6:
			var fq := q + Vector2(r.randf_range(-1.6, 1.6), r.randf_range(-1.6, 1.6))
			_mm(F + ("Bush_1_A_Color1.gltf" if k % 2 else "Grass_1_C_Color1.gltf"), Vector3(fq.x, 0, fq.y), r.randf_range(0.55, 0.85), r.randf() * TAU, fc)
	# un banc de caisses et des tonneaux près du puits
	for k in 3:
		var a := TAU * k / 3.0 + 0.6
		var q := V + Vector2(cos(a), sin(a)) * 3.2
		place(H + ["barrel.gltf", "crate_A_big.gltf", "sack.gltf"][k], Vector3(q.x, 0, q.y), a, 3.6)


# Cercles de terre et sentiers : un maillage plaqué au sol (net, contrairement à la couleur du terrain)
func _ground_decals() -> void:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rn := RandomNumberGenerator.new(); rn.seed = 99 + map_id
	var dirt := Color("#8a6a45"); var path := Color("#a08660"); var stone := Color("#a8a29a")
	st.set_normal(Vector3.UP)
	var Y := func(q: Vector2) -> Vector3: return Vector3(q.x, height(q.x, q.y) + 0.05, q.y)
	# disques : centre plein, bord qui s'estompe
	for ds in dirt_spots:
		var c: Vector2 = ds[0]; var r: float = ds[1]
		var n := 28
		for i in n:
			var a0 := TAU * i / n; var a1 := TAU * (i + 1) / n
			var p0 := c + Vector2(cos(a0), sin(a0)) * r; var p1 := c + Vector2(cos(a1), sin(a1)) * r
			var o0 := c + Vector2(cos(a0), sin(a0)) * (r + 0.5); var o1 := c + Vector2(cos(a1), sin(a1)) * (r + 0.5)
			var cc := dirt.lightened(rn.randf() * 0.06)
			st.set_color(cc); st.add_vertex(Y.call(c)); st.set_color(cc); st.add_vertex(Y.call(p0)); st.set_color(cc); st.add_vertex(Y.call(p1))
			var t := Color(dirt.r, dirt.g, dirt.b, 0.0)
			st.set_color(cc); st.add_vertex(Y.call(p0)); st.set_color(t); st.add_vertex(Y.call(o0)); st.set_color(cc); st.add_vertex(Y.call(p1))
			st.set_color(cc); st.add_vertex(Y.call(p1)); st.set_color(t); st.add_vertex(Y.call(o0)); st.set_color(t); st.add_vertex(Y.call(o1))
		# petites pierres en couronne
		for k in 9:
			var a := TAU * k / 9.0 + rn.randf() * 0.3
			var q := c + Vector2(cos(a), sin(a)) * (r + 0.15)
			_mm("res://assets/forest/Rock_1_A_Color1.gltf", Vector3(q.x, 0, q.y), rn.randf_range(0.16, 0.24), rn.randf() * TAU)
	# sentiers : bande de 1,3 m, bords fondus
	for fp in foot_paths:
		var a: Vector2 = fp[0]; var b: Vector2 = fp[1]
		var L := a.distance_to(b)
		if L < 0.5: continue
		var dir := (b - a) / L; var nr := Vector2(-dir.y, dir.x)
		var steps := int(L / 1.0) + 1
		for i in steps:
			var t0 := float(i) / steps; var t1 := float(i + 1) / steps
			var m0 := a.lerp(b, t0); var m1 := a.lerp(b, t1)
			var w := 0.7
			var cc := path.lightened(rn.randf() * 0.07)
			# centre (même sens d'enroulement que les disques, sinon la face est vue de dos et paraît noire)
			for tri in [[m0 - nr * w, m0 + nr * w, m1 + nr * w], [m0 - nr * w, m1 + nr * w, m1 - nr * w]]:
				var A: Vector2 = tri[0]; var B: Vector2 = tri[1]; var C: Vector2 = tri[2]
				if (B - A).cross(C - A) < 0.0: var tmp := B; B = C; C = tmp
				st.set_color(cc); st.add_vertex(Y.call(A)); st.set_color(cc); st.add_vertex(Y.call(B)); st.set_color(cc); st.add_vertex(Y.call(C))
			# pavés de pierre çà et là
			if rn.randf() < 0.35:
				var q := m0 + nr * rn.randf_range(-0.4, 0.4)
				_mm("res://assets/forest/Rock_1_A_Color1.gltf", Vector3(q.x, -0.06, q.y), rn.randf_range(0.12, 0.18), rn.randf() * TAU, stone)
	if dirt_spots.is_empty() and foot_paths.is_empty(): return
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.roughness = 1.0; m.render_priority = -1
	mi.material_override = m; mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(mi)
