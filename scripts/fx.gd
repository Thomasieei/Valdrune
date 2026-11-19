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
