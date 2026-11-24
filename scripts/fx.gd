class_name Fx



static var monde: Node3D
static var _textes: Array[Label3D] = []
static var _i := 0
static var _sons: Array[AudioStreamPlayer] = []
static var _si := 0
static var _cache := {}

static func preparer(m: Node3D) -> void:
	monde = m
	for k in 40:
		var l := Label3D.new()
		l.font = Ui.police
		l.fixed_size = true
		l.pixel_size = 0.0016
		l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		l.no_depth_test = true
		l.outline_size = 10
		l.visible = false
		m.add_child(l)
		_textes.append(l)
	for k in 8:
		var s := AudioStreamPlayer.new()
		m.add_child(s)
		_sons.append(s)

static func _texte_libre() -> Label3D:
	var l := _textes[_i]
	_i = (_i + 1) % _textes.size()
	return l

static func texte(pos: Vector3, t: String, c: Color, ech := 1.0, duree := 1.0) -> void:
	var l := _texte_libre()
	var tw_ancien: Tween = l.get_meta("tw") if l.has_meta("tw") else null
	if tw_ancien and tw_ancien.is_valid():
		tw_ancien.kill()
	l.text = t
	l.modulate = c
	l.font_size = int(34 * ech)
	l.global_position = pos
	l.visible = true
	l.scale = Vector3.ONE * 0.4
	var tw := l.create_tween()
	l.set_meta("tw", tw)
	tw.tween_property(l, "scale", Vector3.ONE * 1.15, 0.08)
	tw.tween_property(l, "scale", Vector3.ONE, 0.08)
	tw.parallel().tween_property(l, "global_position", pos + Vector3(0, 0.9, 0), duree).set_ease(Tween.EASE_OUT)
	tw.tween_property(l, "modulate:a", 0.0, 0.25)
	tw.tween_callback(func (): l.visible = false)

static func court(v: float) -> String:
	if v >= 1000000000.0:
		return "%.2fG" % (v / 1000000000.0)
	if v >= 1000000.0:
		return "%.2fM" % (v / 1000000.0)
	if v >= 10000.0:
		return "%.1fk" % (v / 1000.0)
	return str(int(round(v)))

static func degats(pos: Vector3, v: float, crit: bool, ombre := false) -> void:
	var c := Color(1.0, 0.85, 0.2) if crit else(Color(0.78, 0.6, 1.0) if ombre else Color(1, 1, 1))
	texte(pos, court(v) + ("!" if crit else ""), c, 1.5 if crit else(0.85 if ombre else 1.0), 0.7)

static func pieces(pos: Vector3, n: int) -> void:
	texte(pos + Vector3(0, 0.5, 0), "+%s ●" % court(n), Color(1.0, 0.82, 0.25), 1.2, 1.3)

static func anneau(pos: Vector3, c: Color, rayon := 1.6) -> void:
	if monde == null:
		return
	var mi := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = 0.85
	t.outer_radius = 1.0
	t.rings = 24
	t.ring_segments = 6
	mi.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.albedo_color = c
	m.emission_enabled = true
	m.emission = c
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.08, 0)
	mi.scale = Vector3(0.2, 0.05, 0.2)
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3(rayon, 0.05, rayon), 0.45).set_ease(Tween.EASE_OUT)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, 0.45)
	tw.tween_callback(mi.queue_free)

static func son(nom: String, volume := 0.0, hauteur := 1.0) -> void:
	if _sons.is_empty():
		return
	var st: AudioStream = _cache.get(nom)
	if st == null:
		var p := "res://assets/sfx/%s.ogg" % nom
		if not ResourceLoader.exists(p):
			return
		st = load(p)
		_cache[nom] = st
	var s := _sons[_si]
	_si = (_si + 1) % _sons.size()
	s.stream = st
	s.volume_db = volume
	s.pitch_scale = hauteur
	s.play()


# ---------- Effets calés sur les animations ----------
static func _mat_add(tex: String, c: Color, billboard := false) -> StandardMaterial3D:
	var cle := "%s_%s_%s" % [tex, c.to_html(), billboard]
	if _cache.has(cle):
		return _cache[cle]
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.no_depth_test = false
	m.cull_mode = BaseMaterial3D.CULL_DISABLED
	m.albedo_color = c
	if ResourceLoader.exists("res://assets/fx/%s.png" % tex):
		m.albedo_texture = load("res://assets/fx/%s.png" % tex)
	if billboard:
		m.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	_cache[cle] = m
	return m

static var _pastille: Texture2D

# Petit disque doux (centre blanc, bord transparent) : évite les carrés blancs sur les particules sans texture
static func pastille() -> Texture2D:
	if _pastille == null:
		var g := Gradient.new()
		g.set_color(0, Color(1, 1, 1, 1))
		g.set_color(1, Color(1, 1, 1, 0))
		var t := GradientTexture2D.new()
		t.gradient = g
		t.width = 64
		t.height = 64
		t.fill = GradientTexture2D.FILL_RADIAL
		t.fill_from = Vector2(0.5, 0.5)
		t.fill_to = Vector2(1.0, 0.5)
		_pastille = t
	return _pastille

static func _quad(taille: Vector2) -> QuadMesh:
	var q := QuadMesh.new()
	q.size = taille
	return q

# Marque au sol qui s'étend et s'efface (onde, sceau…)
static func sol(pos: Vector3, tex: String, c: Color, rayon: float, duree := 0.6, tourne := 0.0) -> MeshInstance3D:
	if monde == null:
		return null
	var mi := MeshInstance3D.new()
	mi.mesh = _quad(Vector2.ONE * 2.0)
	var m := _mat_add(tex, c).duplicate() as StandardMaterial3D
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(mi)
	mi.global_position = pos + Vector3(0, 0.06, 0)
	mi.rotation = Vector3(-PI / 2, randf() * TAU, 0)
	mi.scale = Vector3.ONE * rayon * 0.3
	var tw := mi.create_tween()
	tw.tween_property(mi, "scale", Vector3.ONE * rayon, duree * 0.6).set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	if tourne != 0.0:
		tw.parallel().tween_property(mi, "rotation:y", mi.rotation.y + tourne, duree)
	tw.parallel().tween_property(m, "albedo_color:a", 0.0, duree).set_ease(Tween.EASE_IN)
	tw.tween_callback(mi.queue_free)
	return mi

# Point d'accroche sur la main droite d'un modèle (créé une fois)
static func main_droite(corps: Node3D) -> Node3D:
	if corps == null or not is_instance_valid(corps):
		return null
	if corps.has_meta("main_fx"):
		var n: Node3D = corps.get_meta("main_fx")
		if is_instance_valid(n):
			return n
	var sk: Skeleton3D = corps.find_child("Skeleton3D", true, false)
	var noeud: Node3D = corps
	if sk:
		for i in sk.get_bone_count():
			var nom := sk.get_bone_name(i)
			if nom.contains("RightHand") and not nom.contains("Thumb") and not nom.contains("Index") and not nom.contains("Middle") and not nom.contains("Ring") and not nom.contains("Pinky"):
				var ba := BoneAttachment3D.new()
				ba.bone_idx = i
				sk.add_child(ba)
				noeud = ba
				break
	var pivot := Node3D.new()
	noeud.add_child(pivot)
	pivot.top_level = false
	corps.set_meta("main_fx", pivot)
	return pivot

# Éclairs qui crépitent dans la main
static func eclairs(ancre: Node3D, c: Color, duree: float, taille := 1.2) -> void:
	if ancre == null or not is_instance_valid(ancre):
		return
	var mi := MeshInstance3D.new()
	mi.mesh = _quad(Vector2(taille * 0.5, taille))
	mi.material_override = _mat_add("eclair", c, true)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ancre.add_child(mi)
	mi.top_level = true
	var lum := OmniLight3D.new()
	lum.light_color = c
	lum.omni_range = 4.0
	lum.light_energy = 2.0
	mi.add_child(lum)
	var n := int(duree / 0.05)
	for k in n:
		ancre.get_tree().create_timer(k * 0.05).timeout.connect(func ():
			if is_instance_valid(mi) and is_instance_valid(ancre):
				mi.global_position = ancre.global_position
				mi.scale = Vector3.ONE * randf_range(0.6, 1.3)
				mi.rotation.z = randf() * TAU
				lum.light_energy = randf_range(1.0, 3.0))
	ancre.get_tree().create_timer(duree).timeout.connect(func ():
		if is_instance_valid(mi):
			mi.queue_free())

# Sphère d'énergie tournoyante dans la main
static func sphere(ancre: Node3D, c: Color, duree: float, rayon := 0.45) -> void:
	if ancre == null or not is_instance_valid(ancre):
		return
	var mi := MeshInstance3D.new()
	var s := SphereMesh.new()
	s.radius = rayon
	s.height = rayon * 2.0
	s.radial_segments = 16
	s.rings = 8
	mi.mesh = s
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_color = Color(c.r, c.g, c.b, 0.8)
	mi.material_override = m
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ancre.add_child(mi)
	mi.top_level = true
	var halo := MeshInstance3D.new()
	halo.mesh = _quad(Vector2.ONE * rayon * 4.0)
	halo.material_override = _mat_add("anneau", c, true)
	mi.add_child(halo)
	var lum := OmniLight3D.new()
	lum.light_color = c
	lum.omni_range = 5.0
	lum.light_energy = 2.5
	mi.add_child(lum)
	mi.scale = Vector3.ONE * 0.1
	var n := int(duree / 0.04)
	for k in n:
		ancre.get_tree().create_timer(k * 0.04).timeout.connect(func ():
			if is_instance_valid(mi) and is_instance_valid(ancre):
				mi.global_position = ancre.global_position
				var f := minf(1.0, float(k) / 10.0)
				mi.scale = Vector3.ONE * f * (1.0 + 0.12 * sin(k * 1.7))
				halo.rotation.z = k * 0.6)
	ancre.get_tree().create_timer(duree).timeout.connect(func ():
		if is_instance_valid(mi):
			mi.queue_free())

# Explosion d'impact : éclair de lumière, onde au sol, étoile
static func explosion(pos: Vector3, c: Color, rayon := 3.0) -> void:
	if monde == null:
		return
	sol(pos, "onde", c, rayon * 1.3, 0.7)
	anneau(pos, c, rayon)
	var st := MeshInstance3D.new()
	st.mesh = _quad(Vector2.ONE * rayon * 1.4)
	var m := _mat_add("etoile", c, true).duplicate() as StandardMaterial3D
	st.material_override = m
	st.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	monde.add_child(st)
	st.global_position = pos + Vector3(0, 1.0, 0)
	st.scale = Vector3.ONE * 0.3
	var lum := OmniLight3D.new()
	lum.light_color = c
	lum.omni_range = rayon * 3.0
	lum.light_energy = 4.0
	st.add_child(lum)
	var tw := st.create_tween()
	tw.tween_property(st, "scale", Vector3.ONE * 1.2, 0.12).set_ease(Tween.EASE_OUT)
	tw.tween_property(m, "albedo_color:a", 0.0, 0.3)
	tw.parallel().tween_property(lum, "light_energy", 0.0, 0.3)
	tw.tween_callback(st.queue_free)
