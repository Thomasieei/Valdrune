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
	_make_roads()
	_plan_hamlets()
	_plan_paths()
	if MAP.town.kind == "valdrune":
		for off in [Vector2(-13, -10), Vector2(13, -10), Vector2(-15, 8), Vector2(15, 10), Vector2(-25, -17), Vector2(-26, -2), Vector2(26, -1)]:
			var q: Vector2 = village + off
			roads.append([village + off.normalized() * 5.0, q - off.normalized() * 4.0])
	else: _plan_town_slots()

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
	if e > 112.0: h += pow(e - 112.0, 1.5) * 0.9
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
	return height(x, z) > WATER_Y + 0.15 or on_bridge(x, z)

func slope(x: float, z: float) -> float:
	return abs(height(x + 1, z) - height(x - 1, z)) + abs(height(x, z + 1) - height(x, z - 1))

# ================= CONSTRUCTION =================
func build(id := 1) -> void:
	setup_map(id)
	_terrain()
	_water()
	_bridges()
	if MAP.town.kind == "valdrune": _village()
	else: _town(MAP.town)
	for p in POI_DEFS: _poi(p)
	_gates()
	_road_props()
	_resources()
	_duelists()
	_decor()
	_monster_camps()
	_hidden_chests()
	if BAY != null: _harbor()
	for path in mm_lists: _multi(path, mm_lists[path])
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
	var rock := {"ash": Color("#4a3a38"), "canyon": Color("#8a3e2a"), "desert": Color("#b8925a")}.get(A.style, Color("#7a7064")) as Color
	if sl > 2.2: c = c.lerp(rock, clamp((sl - 2.2) * 0.35, 0.0, 0.85))   # roche des falaises
	var rd := road_dist(x, z)
	if rd < 3.0: c = c.lerp(Color("#a8916a"), (1.0 - smoothstep(1.6, 3.0, rd)) * 0.95)
	var vd := Vector2(x, z).distance_to(village)
	if vd < 11.0: c = c.lerp(Color("#a8916a"), 1.0 - smoothstep(8.0, 11.0, vd))
	if h < WATER_Y + 0.6: c = c.lerp(Color("#c9b98a") if A.style != "swamp" else Color("#6a6a4a"), clamp((WATER_Y + 0.6 - h) * 1.2, 0.0, 0.8))   # berges
	return c

func _terrain() -> void:
	N = int(HALF * 2.0 / CELL) + 1
	hs.resize(N * N)
	for j in N:
		for i in N:
			hs[j * N + i] = raw_height(-HALF + i * CELL, -HALF + j * CELL)
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
	st.generate_normals()
	var mi := MeshInstance3D.new(); mi.mesh = st.commit()
	var m := StandardMaterial3D.new(); m.vertex_color_use_as_albedo = true; m.vertex_color_is_srgb = true; m.roughness = 1.0
	mi.material_override = m; add_child(mi)
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
	for row in 4:
		for k in 7:
			_mm("res://assets/forest/Grass_2_D_Color1.gltf", Vector3(V.x - 40 + k * 2.4, 0, V.y + 16 + row * 2.6), 1.3, 0.0)
	for k in 9:
		place(H + "fence_wood_straight.gltf", Vector3(V.x - 41 + k * 2.1, 0, V.y + 13.5), 0.0, 2.2)
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
			building(H + "building_windmill_blue.gltf", P, 0.4, 5.0, 4.0)
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
			for k in 5: place(H + "fence_wood_straight.gltf", Vector3(P.x - 6 + k * 2.2, 0, P.y + 6.5), 0.0, 2.0)
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
				place("res://assets/halloween/fence.gltf", Vector3(q.x, 0, q.y), -a + PI * 0.5, 1.6)
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
					# quelques clôtures entre deux lanternes
					var f := c + dir * 7.0 - nrm * 3.4 * side
					if walkable(f.x, f.y) and road_dist(f.x, f.y) > 2.6: _mm("res://assets/halloween/fence.gltf", Vector3(f.x, 0, f.y), 1.4, atan2(dir.x, dir.y))
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
func _plan_town_slots() -> void:
	var V: Vector2 = MAP.town.pos
	town_slots = []
	for ring in [[15.0, 10], [24.0, 14]]:
		for i in ring[1]:
			var a: float = TAU * i / ring[1] + (0.2 if ring[0] > 20 else 0.0)
			var q: Vector2 = V + Vector2(cos(a), sin(a)) * ring[0]
			if road_dist(q.x, q.y) < 7.0 or raw_height(q.x, q.y) < WATER_Y + 0.6: continue
			town_slots.append(q)
	for i in min(7, town_slots.size()):
		var q: Vector2 = town_slots[i]
		roads.append([V + (q - V).normalized() * 5.0, q + (V - q).normalized() * 4.0])

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
const NODE_MODEL := {
	"wood": ["", "res://assets/forest/Tree_1_A_Color1.gltf", "res://assets/forest/Tree_4_B_Color1.gltf", "res://assets/forest/Tree_3_A_Color1.gltf", "res://assets/forest/Tree_Bare_1_A_Color1.gltf", "res://assets/halloween/tree_dead_large.gltf"],
	"ore": ["", "res://assets/forest/Rock_1_J_Color1.gltf", "res://assets/forest/Rock_1_J_Color1.gltf", "res://assets/forest/Rock_3_E_Color1.gltf", "res://assets/forest/Rock_3_E_Color1.gltf", "res://assets/forest/Rock_1_J_Color1.gltf"],
	"fiber": ["", "res://assets/forest/Bush_1_C_Color1.gltf", "res://assets/forest/Bush_2_B_Color1.gltf", "res://assets/forest/Bush_4_C_Color1.gltf", "res://assets/forest/Bush_1_C_Color1.gltf", "res://assets/forest/Bush_4_A_Color1.gltf"],
}
func _free_spot(p: Vector3, r: float, keep_village := true) -> bool:
	if abs(p.x) > 106 or abs(p.z) > 106: return false
	for g in gates:
		if Vector2(p.x - g.pos.x, p.z - g.pos.z).length() < 10.0 + r: return false
	if not walkable(p.x, p.z) or height(p.x, p.z) < WATER_Y + 0.5: return false
	if road_dist(p.x, p.z) < 3.0 + r: return false
	if keep_village and Vector2(p.x, p.z).distance_to(village) < 34.0: return false
	for q in POI_DEFS:
		if Vector2(p.x, p.z).distance_to(q.p) < q.r + 3.0 + r: return false
	return true

func _resources() -> void:
	var biome := FastNoiseLite.new(); biome.seed = 909; biome.frequency = 0.035
	for reg in range(1, REGIONS.size()):
		var R: Dictionary = REGIONS[reg]; var t: int = R.tier
		for k in Game.RES_KEYS:
			var want := 20; var placed := 0; var tries := 0
			while placed < want and tries < 4000:
				tries += 1
				var p := Vector3(rng.randf_range(-104, 104), 0, rng.randf_range(-104, 104))
				if region_at(p.x, p.z) != reg: continue
				if not _free_spot(p, 1.0, false): continue
				if Vector2(p.x, p.z).distance_to(village) < 26.0: continue
				var b := biome.get_noise_2d(p.x, p.z)
				# bois en forêt, minerai sur les hauteurs rocheuses, fibre dans les prés
				if k == "wood" and b < 0.05: continue
				if k == "fiber" and b > -0.05: continue
				if k == "ore" and slope(p.x, p.z) < 0.6 and abs(b) > 0.25: continue
				if _near_node_grid(p, 3.6): continue
				_add_node(k, t, p); placed += 1

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
	var model: Node3D = load(NODE_MODEL[k][t]).instantiate(); model.scale = Vector3.ONE * sc * (1.0 + 0.04 * t); model.rotation.y = rng.randf() * TAU
	root.add_child(model)
	var col: Color = Game.TIER_COL[t]
	if k == "ore":
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
		if col != Color(1, 1, 1):
			var src = m[0].surface_get_material(0)
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
		if h < WATER_Y + 0.35: continue
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
		var near_node := _near_node_grid(p, 2.4)
		# bas-côtés fleuris le long des chemins
		if rd > 3.0 and rd < 4.8 and rng.randf() < 0.22 and REGIONS[region_at(p.x, p.z)].style in ["meadow", "forest", "hills"]:
			_mm("res://assets/forest/" + ["Bush_1_A_Color1.gltf", "Grass_1_C_Color1.gltf", "Bush_3_A_Color1.gltf", "Grass_2_B_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU)
			continue
		var reg := region_at(p.x, p.z); var b := biome.get_noise_2d(p.x, p.z); var sl := slope(p.x, p.z)
		var roll := rng.randf(); var edge: bool = max(abs(p.x), abs(p.z)) > 104.0
		var tree_ok := not near_node and rd > 4.0
		match REGIONS[reg].style:
			"meadow":
				if tree_ok and (b > 0.18 or edge) and roll < 0.35: _mm(F + ["Tree_1_A_Color1.gltf", "Tree_2_A_Color1.gltf", "Tree_1_B_Color1.gltf", "Tree_3_B_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(0.9, 1.3), rng.randf() * TAU)
				elif roll < 0.22: _mm(F + ["Grass_1_A_Color1.gltf", "Grass_2_B_Color1.gltf", "Grass_1_C_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.2, 1.8), rng.randf() * TAU)
				elif roll < 0.27: _mm(F + ["Bush_1_A_Color1.gltf", "Bush_2_A_Color1.gltf", "Bush_3_A_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.0, 1.6), rng.randf() * TAU)
				elif roll < 0.29: _mm(F + "Rock_1_A_Color1.gltf", p, rng.randf_range(0.6, 1.2), rng.randf() * TAU)
			"forest":
				if tree_ok and (b > -0.1 or edge) and roll < 0.42: _mm(F + ["Tree_4_A_Color1.gltf", "Tree_4_B_Color1.gltf", "Tree_2_D_Color1.gltf", "Tree_4_C_Color1.gltf", "Tree_2_C_Color1.gltf"][rng.randi() % 5], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU)
				elif roll < 0.75: _mm(F + ["Grass_2_A_Color1.gltf", "Bush_1_E_Color1.gltf", "Grass_1_D_Color1.gltf", "Bush_2_D_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(1.0, 1.7), rng.randf() * TAU)
			"hills":
				if sl > 2.4 and roll < 0.5: _mm(F + ["Rock_3_A_Color1.gltf", "Rock_3_M_Color1.gltf", "Rock_1_E_Color1.gltf", "Rock_3_K_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(0.8, 1.6), rng.randf() * TAU, Color("#e8d0a8"))
				elif tree_ok and (b > 0.1 or edge) and roll < 0.3: _mm(F + ["Tree_1_A_Color1.gltf", "Tree_3_A_Color1.gltf", "Tree_2_B_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(0.9, 1.3), rng.randf() * TAU, Color("#ffb070"))
				elif roll < 0.35: _mm(F + ["Grass_1_B_Color1.gltf", "Grass_2_C_Color1.gltf"][rng.randi() % 2], p, rng.randf_range(1.0, 1.5), rng.randf() * TAU, Color("#f0d890"))
			"swamp":
				if tree_ok and roll < 0.16: _mm(["res://assets/halloween/tree_dead_medium.gltf", F + "Tree_Bare_2_A_Color1.gltf", F + "Tree_Bare_1_B_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.0, 1.6), rng.randf() * TAU)
				elif roll < 0.45: _mm(F + ["Grass_2_D_Color1.gltf", "Grass_1_D_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.2, 1.9), rng.randf() * TAU, Color("#a8b090"))
				elif roll < 0.47: _mm("res://assets/halloween/gravestone.gltf", p, 1.1, rng.randf() * TAU)
			"ash":
				if sl > 2.4 and roll < 0.5: _mm(F + ["Rock_3_M_Color1.gltf", "Rock_3_A_Color1.gltf", "Rock_1_N_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(1.0, 2.0), rng.randf() * TAU, Color("#8a7070"))
				elif tree_ok and roll < 0.14: _mm(["res://assets/halloween/tree_dead_large.gltf", "res://assets/halloween/tree_dead_medium.gltf"][rng.randi() % 2], p, rng.randf_range(1.2, 1.8), rng.randf() * TAU)
				elif roll < 0.2: _mm(["res://assets/halloween/bone_A.gltf", "res://assets/halloween/skull.gltf", "res://assets/halloween/ribcage.gltf"][rng.randi() % 3], p, 1.2, rng.randf() * TAU)
				elif roll < 0.24: _ember(p)
			"desert":
				if sl > 2.0 and roll < 0.4: _mm(F + ["Rock_3_A_Color1.gltf", "Rock_1_E_Color1.gltf", "Rock_3_K_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(0.8, 1.5), rng.randf() * TAU, Color("#f2d49a"))
				elif tree_ok and roll < 0.03: _mm(["res://assets/halloween/tree_dead_medium.gltf", F + "Tree_Bare_1_B_Color1.gltf"][rng.randi() % 2], p, rng.randf_range(0.9, 1.3), rng.randf() * TAU, Color("#e8c890"))
				elif roll < 0.1: _mm(F + ["Grass_1_B_Color1.gltf", "Grass_2_C_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 3], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU, Color("#e6cf8a"))
				elif roll < 0.115: _mm(["res://assets/halloween/bone_A.gltf", "res://assets/halloween/skull.gltf", "res://assets/halloween/ribcage.gltf"][rng.randi() % 3], p, 1.3, rng.randf() * TAU)
				elif roll < 0.13: _mm(F + "Rock_1_A_Color1.gltf", p, rng.randf_range(0.5, 1.0), rng.randf() * TAU, Color("#f0d29a"))
			"canyon":
				if sl > 2.2 and roll < 0.55: _mm(F + ["Rock_3_M_Color1.gltf", "Rock_3_A_Color1.gltf", "Rock_1_N_Color1.gltf", "Rock_3_K_Color1.gltf"][rng.randi() % 4], p, rng.randf_range(1.0, 2.1), rng.randf() * TAU, Color("#d07a55"))
				elif tree_ok and roll < 0.06: _mm(["res://assets/halloween/tree_dead_large.gltf", "res://assets/halloween/tree_dead_medium.gltf"][rng.randi() % 2], p, rng.randf_range(1.1, 1.6), rng.randf() * TAU, Color("#c8906a"))
				elif roll < 0.14: _mm(F + ["Grass_1_B_Color1.gltf", "Bush_4_D_Color1.gltf"][rng.randi() % 2], p, rng.randf_range(0.9, 1.4), rng.randf() * TAU, Color("#a85a30"))
				elif roll < 0.16: _mm(F + "Rock_1_A_Color1.gltf", p, rng.randf_range(0.6, 1.2), rng.randf() * TAU, Color("#c87a50"))
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
		for k in 30:
			if walkable(p.x, p.z) and slope(p.x, p.z) < 1.6: break
			p = Vector3(s.x + rng.randf_range(-8, 8), 0, s.y + rng.randf_range(-8, 8))
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
