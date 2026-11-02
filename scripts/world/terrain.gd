class_name Terrain
## Génère le sol (maillage découpé en blocs pour le culling), sa collision et l'eau.

const STEP := 2.5
const CHUNK := 32   # quads par bloc (80 m)

static var grid := PackedFloat32Array()
static var gverts := 0

## Hauteur exacte du maillage affiché (mêmes triangles), pour poser routes et objets au ras du sol.
static func height_at(x: float, z: float) -> float:
	if gverts == 0:
		return Layout.height(x, z)
	var fx := (x + Layout.HALF) / STEP
	var fz := (z + Layout.HALF) / STEP
	var i := clampi(int(floor(fx)), 0, gverts - 2)
	var j := clampi(int(floor(fz)), 0, gverts - 2)
	var u := clampf(fx - i, 0.0, 1.0)
	var v := clampf(fz - j, 0.0, 1.0)
	var h00 := grid[j * gverts + i]
	var h10 := grid[j * gverts + i + 1]
	var h01 := grid[(j + 1) * gverts + i]
	var h11 := grid[(j + 1) * gverts + i + 1]
	if u + v <= 1.0:
		return h00 + (h10 - h00) * u + (h01 - h00) * v
	return h11 + (h01 - h11) * (1.0 - u) + (h10 - h11) * (1.0 - v)

static func build(parent: Node3D) -> void:
	var n := int(Layout.HALF * 2.0 / STEP)  # 256 quads
	var verts := n + 1
	var H := PackedFloat32Array()
	H.resize(verts * verts)
	var C := PackedColorArray()
	C.resize(verts * verts)
	var N := PackedVector3Array()
	N.resize(verts * verts)
	for j in verts:
		for i in verts:
			var x := -Layout.HALF + i * STEP
			var z := -Layout.HALF + j * STEP
			H[j * verts + i] = Layout.height(x, z)
	grid = H
	gverts = verts
	for j in verts:
		for i in verts:
			var hl := H[j * verts + maxi(i - 1, 0)]
			var hr := H[j * verts + mini(i + 1, n)]
			var hu := H[maxi(j - 1, 0) * verts + i]
			var hd := H[mini(j + 1, n) * verts + i]
			var nm := Vector3(hl - hr, 2.0 * STEP, hu - hd).normalized()
			N[j * verts + i] = nm
			C[j * verts + i] = _color(-Layout.HALF + i * STEP, -Layout.HALF + j * STEP, H[j * verts + i], nm)

	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/terrain.gdshader")
	var nt := NoiseTexture2D.new()
	nt.seamless = true
	nt.width = 256
	nt.height = 256
	var fn := FastNoiseLite.new()
	fn.frequency = 0.02
	nt.noise = fn
	mat.set_shader_parameter("noise_tex", nt)

	var chunks := n / CHUNK
	for cj in chunks:
		for ci in chunks:
			var st := SurfaceTool.new()
			st.begin(Mesh.PRIMITIVE_TRIANGLES)
			for j in range(cj * CHUNK, (cj + 1) * CHUNK + 1):
				for i in range(ci * CHUNK, (ci + 1) * CHUNK + 1):
					var k := j * verts + i
					st.set_color(C[k])
					st.set_normal(N[k])
					st.add_vertex(Vector3(-Layout.HALF + i * STEP, H[k], -Layout.HALF + j * STEP))
			var w := CHUNK + 1
			for j in CHUNK:
				for i in CHUNK:
					var a := j * w + i
					st.add_index(a); st.add_index(a + 1); st.add_index(a + w)
					st.add_index(a + 1); st.add_index(a + w + 1); st.add_index(a + w)
			var mi := MeshInstance3D.new()
			mi.mesh = st.commit()
			mi.material_override = mat
			mi.name = "Sol_%d_%d" % [ci, cj]
			parent.add_child(mi)

	# Collision : champ de hauteur (léger et précis)
	var body := StaticBody3D.new()
	body.name = "SolCollision"
	body.collision_layer = 1
	var cs := CollisionShape3D.new()
	var hm := HeightMapShape3D.new()
	hm.map_width = verts
	hm.map_depth = verts
	hm.map_data = H
	cs.shape = hm
	cs.scale = Vector3(STEP, 1.0, STEP)
	body.add_child(cs)
	parent.add_child(body)

	_build_water(parent, H, verts)

static func _color(x: float, z: float, h: float, nm: Vector3) -> Color:
	var p := Vector2(x, z)
	var n1 := Layout._n().get_noise_2d(x * 2.3, z * 2.3)
	var grass_a := Color(0.30, 0.47, 0.20)
	var grass_b := Color(0.40, 0.54, 0.23)
	var dry := Color(0.55, 0.55, 0.30)
	var c := grass_a.lerp(grass_b, clampf(n1 * 0.8 + 0.5, 0.0, 1.0))
	c = c.lerp(dry, clampf((n1 - 0.25) * 2.0, 0.0, 0.45))
	# prairies fleuries plus claires autour du bourg
	# rocaille sur les pentes
	var slope := 1.0 - nm.y
	var rock := Color(0.50, 0.48, 0.45).lerp(Color(0.42, 0.40, 0.38), clampf(n1 + 0.5, 0, 1))
	c = c.lerp(rock, smoothstep(0.16, 0.32, slope))
	# montagnes : roche puis neige
	c = c.lerp(rock, smoothstep(26.0, 38.0, h))
	c = c.lerp(Color(0.93, 0.95, 0.98), smoothstep(52.0, 62.0, h + n1 * 6.0))
	# berges : sable/boue
	var rd := Layout.river_dist(p)
	var sand := Color(0.66, 0.60, 0.44)
	c = c.lerp(sand, 1.0 - smoothstep(0.6, 1.6, h - Layout.WATER + n1 * 0.4))
	# chemins de terre
	var road := Layout.road_dist(p)
	var dirt := Color(0.55, 0.44, 0.30).lerp(Color(0.60, 0.50, 0.35), clampf(n1 + 0.5, 0, 1))
	c = c.lerp(dirt, 1.0 - smoothstep(-0.6, 1.4, road))
	# champs : terre labourée en bordure (les cultures sont posées par Fields)
	if Layout.in_fields(p, 0.0):
		c = c.lerp(Color(0.48, 0.38, 0.26), 0.55)
	# cour du château : herbe rase et terre battue
	if Layout.in_castle(p, -2.0):
		c = c.lerp(Color(0.56, 0.50, 0.38), 0.35)
	return c

static func _build_water(parent: Node3D, H: PackedFloat32Array, verts: int) -> void:
	var st := SurfaceTool.new()
	st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var n := verts - 1
	var count := 0
	for j in n:
		for i in n:
			var hs := [H[j * verts + i], H[j * verts + i + 1], H[(j + 1) * verts + i], H[(j + 1) * verts + i + 1]]
			if hs.min() > Layout.WATER + 0.4:
				continue
			var q := [Vector2i(i, j), Vector2i(i + 1, j), Vector2i(i, j + 1), Vector2i(i + 1, j), Vector2i(i + 1, j + 1), Vector2i(i, j + 1)]
			for v in q:
				var hh := H[v.y * verts + v.x]
				var depth := clampf((Layout.WATER - hh) / 2.5, 0.0, 1.0)
				st.set_color(Color(depth, 0, 0))
				st.add_vertex(Vector3(-Layout.HALF + v.x * STEP, Layout.WATER, -Layout.HALF + v.y * STEP))
				count += 1
	if count == 0:
		return
	st.index()
	var mi := MeshInstance3D.new()
	mi.name = "Eau"
	mi.mesh = st.commit()
	var mat := ShaderMaterial.new()
	mat.shader = load("res://shaders/water.gdshader")
	mi.material_override = mat
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(mi)
