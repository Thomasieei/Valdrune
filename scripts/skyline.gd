class_name Skyline
extends Node3D

# Horizon de tours géantes (un seul MultiMesh par palier) : la ville paraît énorme, et elle grandit avec le joueur.

const NIVEAUX := [1, 8, 18, 30]
const CODE := "
shader_type spatial;
render_mode diffuse_lambert, specular_disabled, fog_disabled;
varying vec3 lp;
varying vec3 ln;
varying vec4 cd;
float hh(vec2 p) { return fract(sin(dot(p, vec2(127.1, 311.7)) + 3.7) * 43758.5453); }
void vertex() {
	vec3 s = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	lp = VERTEX * s;
	ln = NORMAL;
	cd = INSTANCE_CUSTOM;
}
void fragment() {
	float dist = length(VERTEX);
	float brume = clamp(dist / 1300.0, 0.0, 0.62);
	ALBEDO = mix(mix(vec3(0.05, 0.07, 0.12), vec3(0.09, 0.07, 0.13), fract(cd.x * 7.0)), vec3(0.5, 0.48, 0.62), brume);
	ROUGHNESS = 0.8;
	float cote = 1.0 - step(0.5, abs(ln.y));
	float u = lp.x + lp.z;
	vec2 cell = vec2(u / 3.2, lp.y / 4.2);
	vec2 id = floor(cell) + vec2(floor(cd.x * 97.0), 0.0);
	vec2 f = fract(cell);
	float fen = step(0.18, f.x) * step(f.x, 0.82) * step(0.2, f.y) * step(f.y, 0.8);
	float on = step(0.62, hh(id));
	vec3 chaud = vec3(1.0, 0.8, 0.45);
	vec3 froid = vec3(0.45, 0.8, 1.0);
	vec3 col = mix(chaud, froid, step(0.72, hh(id + 7.0)));
	col = mix(col, vec3(1.0, 0.4, 0.8), step(0.95, hh(id + 3.0)));
	EMISSION = col * fen * on * cote * (1.0 - step(0.5, cd.b)) * 0.9 * (1.0 - brume);
}
"

static var _mat: ShaderMaterial

static func materiau() -> ShaderMaterial:
	if _mat == null:
		var sh := Shader.new()
		sh.code = CODE
		_mat = ShaderMaterial.new()
		_mat.shader = sh
	return _mat

var ville: Node3D
var tour_pos := Vector3.ZERO
var _segs: Array = [[], [], [], []]
var _tiers: Array = []
var _places: Array = []

func installer(v: Node3D, pts: Array) -> void:
	ville = v
	var etat := v.get_world_3d().direct_space_state
	var mnx := INF
	var mxx := -INF
	var mnz := INF
	var mxz := -INF
	for p in pts:
		mnx = minf(mnx, p.x)
		mxx = maxf(mxx, p.x)
		mnz = minf(mnz, p.z)
		mxz = maxf(mxz, p.z)
	var centre := Vector2((mnx + mxx) / 2.0, (mnz + mxz) / 2.0)
	var a := (mxx - mnx) / 2.0 + 45.0
	var b := (mxz - mnz) / 2.0 + 45.0
	_limites(mnx - 30.0, mxx + 30.0, mnz - 30.0, mxz + 30.0)
	seed(777)
	# sol sombre à l'infini (pas de vide autour de la ville)
	var sol := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(4200, 4200)
	sol.mesh = pl
	var sm := StandardMaterial3D.new()
	sm.albedo_color = Color(0.035, 0.04, 0.065)
	sm.roughness = 1.0
	sol.material_override = sm
	sol.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	sol.position = Vector3(centre.x, -0.75, centre.y)
	add_child(sol)
	# tours de l'horizon
	var n_ring := 40
	for i in n_ring:
		var tier := 0 if i < 16 else (1 if i < 26 else (2 if i < 34 else 3))
		for essai in 8:
			var th := TAU * (float(i) + randf_range(-0.3, 0.3)) / n_ring
			var f := randf_range(1.0, 1.45)
			var pos := centre + Vector2(a * cos(th) * f, b * sin(th) * f)
			if _places.any(func (q): return q.distance_to(pos) < 75.0):
				continue
			_places.append(pos)
			_tour(pos, randf_range(220.0, 540.0), randf_range(40.0, 90.0), tier, false)
			break
	# tours dans la ville, sur les terrains libres (avec collision : on peut courir sur les murs)
	var cible_int := 0
	var posees := 0
	var essais := 0
	var depart := Vector2(v.DEPART.x, v.DEPART.z)
	while posees < cible_int and essais < 700:
		essais += 1
		var pos := Vector2(randf_range(mnx, mxx), randf_range(mnz, mxz))
		if pos.distance_to(depart) < 60.0 or _places.any(func (q): return q.distance_to(pos) < 60.0):
			continue
		if pts.any(func (q): return Vector2(q.x, q.z).distance_to(pos) < 22.0):
			continue
		var sph := SphereShape3D.new()
		sph.radius = 12.0
		var q := PhysicsShapeQueryParameters3D.new()
		q.shape = sph
		q.transform = Transform3D(Basis.IDENTITY, Vector3(pos.x, 13.5, pos.y))
		if not etat.intersect_shape(q, 1).is_empty():
			continue
		var tier := 0 if posees < 6 else (1 if posees < 11 else (2 if posees < 15 else 3))
		_places.append(pos)
		posees += 1
		_tour(pos, randf_range(70.0, 190.0), randf_range(14.0, 22.0), tier, true)
	# multi-meshs
	for t in 4:
		var l: Array = _segs[t]
		if l.is_empty():
			continue
		var mm := MultiMesh.new()
		mm.transform_format = MultiMesh.TRANSFORM_3D
		mm.use_custom_data = true
		var bm := BoxMesh.new()
		bm.size = Vector3.ONE
		mm.mesh = bm
		mm.instance_count = l.size()
		for k in l.size():
			mm.set_instance_transform(k, l[k][0])
			mm.set_instance_custom_data(k, l[k][1])
		var mi := MultiMeshInstance3D.new()
		mi.multimesh = mm
		mi.material_override = materiau()
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.visible = Partie.niveau >= NIVEAUX[t]
		add_child(mi)
		_tiers.append([mi, NIVEAUX[t]])
	_tour_chasseurs(centre, a, b)
	_trafic(centre, a, b)
	Partie.niveau_gagne.connect(_niveau)

# Barrière magnétique : murs invisibles solides + voile bleu visible de près
func _limites(x0: float, x1: float, z0: float, z1: float) -> void:
	var vm := StandardMaterial3D.new()
	vm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	vm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	vm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	vm.cull_mode = BaseMaterial3D.CULL_DISABLED
	vm.albedo_color = Color(0.3, 0.6, 1.0, 0.16)
	var cotes := [[Vector3((x0 + x1) / 2.0, 0, z0), Vector3(x1 - x0, 0, 0)], [Vector3((x0 + x1) / 2.0, 0, z1), Vector3(x1 - x0, 0, 0)],
		[Vector3(x0, 0, (z0 + z1) / 2.0), Vector3(0, 0, z1 - z0)], [Vector3(x1, 0, (z0 + z1) / 2.0), Vector3(0, 0, z1 - z0)]]
	for c in cotes:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		var lon: Vector3 = c[1]
		bs.size = Vector3(maxf(lon.x, 3.0), 120.0, maxf(lon.z, 3.0))
		cs.shape = bs
		sb.add_child(cs)
		sb.position = c[0] + Vector3(0, 55.0, 0)
		add_child(sb)
		var mi := MeshInstance3D.new()
		var q := QuadMesh.new()
		q.size = Vector2(maxf(lon.x, lon.z), 60.0)
		mi.mesh = q
		mi.material_override = vm
		mi.position = c[0] + Vector3(0, 28.0, 0)
		mi.rotation.y = 0.0 if lon.x > 0.0 else PI / 2.0
		mi.visibility_range_end = 70.0
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		add_child(mi)

func _tour(pos: Vector2, h: float, w: float, tier: int, collision: bool) -> void:
	var graine := randf()
	var y := -1.0
	var ww := w
	var hh := h * 0.62
	_seg(pos, y, ww, hh, tier, graine, 0.0)
	if collision:
		var sb := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = Vector3(ww, hh, ww)
		cs.shape = bs
		sb.add_child(cs)
		sb.position = Vector3(pos.x, y + hh / 2.0, pos.y)
		add_child(sb)
	y += hh
	ww *= 0.74
	hh = h * 0.27
	_seg(pos, y, ww, hh, tier, graine + 0.3, 0.0)
	y += hh
	ww *= 0.55
	hh = h * 0.11
	_seg(pos, y, ww, hh, tier, graine + 0.6, 0.0)
	y += hh
	_seg(pos, y, 1.4, h * 0.16, tier, graine, 1.0)

func _seg(pos: Vector2, y: float, w: float, h: float, tier: int, graine: float, metal: float) -> void:
	var bas := Basis.from_scale(Vector3(w, h, w))
	_segs[tier].append([Transform3D(bas, Vector3(pos.x, y + h / 2.0, pos.y)), Color(fmod(graine, 1.0), 0.0, metal, 0.0)])

func _tour_chasseurs(centre: Vector2, a: float, b: float) -> void:
	var portail: Vector3 = ville.PORTAIL
	var th := atan2((portail.z - centre.y) / b, (portail.x - centre.x) / a)
	var pos := centre + Vector2(a * cos(th) * 1.12, b * sin(th) * 1.12)
	tour_pos = Vector3(pos.x, 0.0, pos.y)
	var h := 420.0
	var w := 60.0
	var mats := [[w, h * 0.55], [w * 0.7, h * 0.28], [w * 0.42, h * 0.17]]
	var y := -1.0
	for m in mats:
		var mi := MeshInstance3D.new()
		var bm := BoxMesh.new()
		bm.size = Vector3(m[0], m[1], m[0])
		mi.mesh = bm
		var sm := ShaderMaterial.new()
		sm.shader = materiau().shader
		mi.material_override = sm
		mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		mi.position = Vector3(pos.x, y + m[1] / 2.0, pos.y)
		add_child(mi)
		y += m[1]
	# faisceau doré au sommet + inscription
	var fa := MeshInstance3D.new()
	var cy := CylinderMesh.new()
	cy.top_radius = 3.0
	cy.bottom_radius = 3.0
	cy.height = 500.0
	cy.cap_top = false
	cy.cap_bottom = false
	cy.radial_segments = 8
	fa.mesh = cy
	var fm := StandardMaterial3D.new()
	fm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	fm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	fm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	fm.cull_mode = BaseMaterial3D.CULL_DISABLED
	fm.albedo_color = Color(1.0, 0.8, 0.3, 0.35)
	fa.material_override = fm
	fa.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	fa.position = Vector3(pos.x, y + 250.0, pos.y)
	add_child(fa)
	var lb := Label3D.new()
	lb.text = "TOUR DES CHASSEURS"
	lb.font = Ui.police
	lb.font_size = 40
	lb.outline_size = 10
	lb.pixel_size = 0.0018
	lb.fixed_size = true
	lb.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	lb.no_depth_test = true
	lb.modulate = Color(1.0, 0.85, 0.4)
	lb.position = Vector3(pos.x, y * 0.55, pos.y)
	add_child(lb)

# Circulation aérienne : des traînées lumineuses glissent à haute altitude (animées par le shader, aucun coût CPU)
const CODE_TRAFIC := "
shader_type spatial;
render_mode unshaded, fog_disabled;
varying vec3 col;
void vertex() {
	float t = fract(INSTANCE_CUSTOM.x + TIME * INSTANCE_CUSTOM.y);
	VERTEX.x += (t - 0.5) * 1700.0;
	col = mix(vec3(1.0, 0.7, 0.35), vec3(0.4, 0.85, 1.0), step(0.5, INSTANCE_CUSTOM.z));
}
void fragment() {
	ALBEDO = col * 1.8;
}
"
var _trafic_mi: MultiMeshInstance3D

func _trafic(centre: Vector2, a: float, b: float) -> void:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.use_custom_data = true
	var bm := BoxMesh.new()
	bm.size = Vector3(9.0, 0.9, 0.9)
	mm.mesh = bm
	mm.instance_count = 70
	mm.custom_aabb = AABB(Vector3(-1500, 0, -1500), Vector3(3000, 600, 3000))
	var angles := [0.0, 0.9, 2.1]
	for k in 70:
		var ang: float = angles[k % 3]
		var pos := Vector3(randf_range(-a, a), randf_range(70.0, 280.0), randf_range(-b, b))
		var bas := Basis(Vector3.UP, ang)
		mm.set_instance_transform(k, Transform3D(bas, pos))
		mm.set_instance_custom_data(k, Color(randf(), randf_range(0.015, 0.045), randf(), 0.0))
	var sh := Shader.new()
	sh.code = CODE_TRAFIC
	var mt := ShaderMaterial.new()
	mt.shader = sh
	_trafic_mi = MultiMeshInstance3D.new()
	_trafic_mi.multimesh = mm
	_trafic_mi.material_override = mt
	_trafic_mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	_trafic_mi.position = Vector3(centre.x, 0.0, centre.y)
	add_child(_trafic_mi)

var _vis_t := 0.0

func _process(dt: float) -> void:
	_vis_t -= dt
	if _vis_t > 0.0 or ville == null:
		return
	_vis_t = 0.5
	visible = ville.donjon == null and ville.chateau == null and ville.abime == null and not ville.chez_soi and ville.arene == null

func _niveau(n: int) -> void:
	var nouveau := false
	for t in _tiers:
		if n >= int(t[1]) and not (t[0] as MeshInstance3D).visible:
			(t[0] as MeshInstance3D).visible = true
			nouveau = true
	if nouveau and ville and ville.hud:
		ville.hud.systeme("LA VILLE S'ÉTEND", ["De nouvelles tours s'élèvent à l'horizon.", "Ta renommée attire les investisseurs."])
