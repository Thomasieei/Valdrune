class_name Donjon
extends Node3D





signal termine(victoire: bool)

const ORIGINE := Vector3(600, 0, 0)
const PAS := 36.0
const DEMI := 11.0
const HAUT_MUR := 7.0
const LARGE_PASSAGE := 6.0
const DUREE := 270.0
const RANG := 0
const PUISSANCE_CONSEILLEE := 120.0


const SALLES := [
	[["gobelin", -4.5, 1.0, false], ["gobelin", 4.5, 1.0, false], ["gobelin", -2.0, 5.5, false], ["gobelin", 2.5, 5.5, false]],
	[["puglin", -5.0, 2.0, false], ["puglin", 5.0, 2.0, false], ["puglin", 0.0, 6.5, false], ["gobelin", 0.0, 1.0, true]],
	[["gobelin_chef", -4.0, 4.0, false], ["gobelin_chef", 4.0, 4.0, false], ["gobelin", -6.5, 0.0, false], ["gobelin", 6.5, 0.0, false]],
	[["puglin", -5.5, 0.5, false], ["puglin", 5.5, 0.5, false], ["puglin", -2.5, 6.0, false], ["puglin", 2.5, 6.0, true]],
	[["puglin_brute", -4.0, 3.0, false], ["puglin_brute", 4.0, 3.0, false], ["gobelin_chef", 0.0, 6.5, true]],
	[["roi_gobelin", 0.0, 4.0, false]],
]
const NOMS_SALLES := ["Le hall des crocs", "La fosse aux puglins", "La garde enragée", "Les cages", "L'antichambre", "Le trône de Kargash"]

var ville: Node
var salle := 0
var temps := DUREE
var actif := false
var monstres: Array = []
var _par_salle: Array = []
var _barrieres: Array = []
var _mat_sol: StandardMaterial3D
var _mat_mur: StandardMaterial3D
var _depart_t := 0.0
var sortie: Node3D = null
var coffre: Node3D = null
var gains := {}
var _animes: Array = []

func centre(i: int) -> Vector3:
	return ORIGINE + Vector3(0, 0, i * PAS)

func point_depart() -> Vector3:
	return centre(0) + Vector3(0, 0.3, -8.5)

func _ready() -> void:
	_materiaux()
	for i in 6:
		_salle(i)
		if i < 5:
			_couloir(i)
	for i in 6:
		_peupler(i)
	_decor()
	for n in get_children():
		if n.has_meta("vacille"):
			n.set_meta("base", n.light_energy)
			_animes.append(n)
		elif n.has_meta("tourne"):
			_animes.append(n)


func _materiaux() -> void:
	_mat_sol = StandardMaterial3D.new()
	_mat_sol.albedo_texture = load("res://assets/fx/dalles.png")
	_mat_sol.normal_enabled = true
	_mat_sol.normal_texture = load("res://assets/fx/dalles_n.png")
	_mat_sol.normal_scale = 1.2
	_mat_sol.roughness = 0.82
	_mat_sol.uv1_triplanar = true
	_mat_sol.uv1_scale = Vector3(0.25, 0.25, 0.25)
	_mat_sol.albedo_color = Color(0.85, 0.82, 0.9)
	_mat_mur = StandardMaterial3D.new()
	_mat_mur.albedo_texture = load("res://assets/fx/mur.png")
	_mat_mur.normal_enabled = true
	_mat_mur.normal_texture = load("res://assets/fx/mur_n.png")
	_mat_mur.roughness = 0.9
	_mat_mur.uv1_triplanar = true
	_mat_mur.uv1_scale = Vector3(0.28, 0.28, 0.28)
	_mat_mur.albedo_color = Color(0.8, 0.78, 0.88)

func _boite(taille: Vector3, pos: Vector3, mat: Material, collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	if collision:
		var c := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		c.add_child(cs)
		c.position = pos
		add_child(c)
	return mi

func _salle(i: int) -> void:
	var c := centre(i)
	var L := DEMI * 2.0 + 1.0
	_boite(Vector3(L, 0.4, L), c + Vector3(0, -0.2, 0), _mat_sol)
	var h := HAUT_MUR
	_boite(Vector3(1, h, L), c + Vector3(- DEMI - 0.5, h / 2.0, 0), _mat_mur)
	_boite(Vector3(1, h, L), c + Vector3(DEMI + 0.5, h / 2.0, 0), _mat_mur)
	for cote in [-1, 1]:
		var ouvert: bool = (cote == -1 and i > 0) or (cote == 1 and i < 5)
		var z: float = c.z + cote * (DEMI + 0.5)
		if ouvert:
			var seg := (L - LARGE_PASSAGE) / 2.0
			var x := LARGE_PASSAGE / 2.0 + seg / 2.0
			_boite(Vector3(seg, h, 1), Vector3(c.x - x, h / 2.0, z), _mat_mur)
			_boite(Vector3(seg, h, 1), Vector3(c.x + x, h / 2.0, z), _mat_mur)

			_boite(Vector3(LARGE_PASSAGE, 1.6, 1.2), Vector3(c.x, h - 0.8, z), _mat_mur, false)
		else:
			_boite(Vector3(L, h, 1), Vector3(c.x, h / 2.0, z), _mat_mur)

	for px in [-7.5, 7.5]:
		for pz in [-7.5, 7.5]:
			var p := c + Vector3(px, 0, pz)
			_boite(Vector3(2.0, 0.6, 2.0), p + Vector3(0, 0.3, 0), _mat_mur)
			var mi := MeshInstance3D.new()
			var cy := CylinderMesh.new()
			cy.top_radius = 0.62
			cy.bottom_radius = 0.7
			cy.height = h - 1.2
			cy.radial_segments = 14
			mi.mesh = cy
			mi.material_override = _mat_mur
			mi.position = p + Vector3(0, 0.6 + (h - 1.2) / 2.0, 0)
			add_child(mi)
			_boite(Vector3(1.8, 0.6, 1.8), p + Vector3(0, h - 0.3, 0), _mat_mur, false)
			var cc := StaticBody3D.new()
			var cs := CollisionShape3D.new()
			var cyl := CylinderShape3D.new()
			cyl.radius = 0.75
			cyl.height = h
			cs.shape = cyl
			cc.add_child(cs)
			cc.position = p + Vector3(0, h / 2.0, 0)
			add_child(cc)

	var rune := MeshInstance3D.new()
	var q := PlaneMesh.new()
	q.size = Vector2(9, 9) if i < 5 else Vector2(13, 13)
	rune.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/fx/magic_02.png")
	m.albedo_color = Color(0.55, 0.2, 1.0, 0.55) if i < 5 else Color(1.0, 0.55, 0.15, 0.7)
	rune.material_override = m
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rune.position = c + Vector3(0, 0.03, 3.0 if i == 5 else 2.0)
	rune.set_meta("tourne", 0.12 if i < 5 else -0.2)
	add_child(rune)

	for cote in [-1, 1]:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.62, 0.3)
		l.light_energy = 5.0
		l.omni_range = 17.0
		l.omni_attenuation = 1.0
		l.position = c + Vector3(cote * (DEMI - 1.2), 3.6, 0)
		l.distance_fade_enabled = true
		l.distance_fade_begin = 40.0
		l.distance_fade_length = 10.0
		l.set_meta("vacille", randf() * 10.0)
		add_child(l)
	var lv := OmniLight3D.new()
	lv.light_color = Color(0.55, 0.25, 1.0) if i < 5 else Color(1.0, 0.45, 0.2)
	lv.light_energy = 2.4 if i < 5 else 3.6
	lv.omni_range = 14.0
	lv.position = c + Vector3(0, 1.2, 2.0)
	lv.distance_fade_enabled = true
	lv.distance_fade_begin = 40.0
	lv.distance_fade_length = 10.0
	add_child(lv)

func _couloir(i: int) -> void:
	var z0 := centre(i).z + DEMI + 1.0
	var z1 := centre(i + 1).z - DEMI - 1.0
	var long := z1 - z0
	var zc := (z0 + z1) / 2.0
	var x := ORIGINE.x
	_boite(Vector3(LARGE_PASSAGE + 2.0, 0.4, long + 2.0), Vector3(x, -0.2, zc), _mat_sol)
	_boite(Vector3(1, HAUT_MUR, long + 2.0), Vector3(x - LARGE_PASSAGE / 2.0 - 0.5, HAUT_MUR / 2.0, zc), _mat_mur)
	_boite(Vector3(1, HAUT_MUR, long + 2.0), Vector3(x + LARGE_PASSAGE / 2.0 + 0.5, HAUT_MUR / 2.0, zc), _mat_mur)
	var l := OmniLight3D.new()
	l.light_color = Color(1.0, 0.6, 0.3)
	l.light_energy = 3.2
	l.omni_range = 11.0
	l.position = Vector3(x, 3.2, zc)
	l.set_meta("vacille", randf() * 10.0)
	add_child(l)
	_torche(Vector3(x - LARGE_PASSAGE / 2.0 + 0.15, 2.4, zc), PI / 2.0)
	_torche(Vector3(x + LARGE_PASSAGE / 2.0 - 0.15, 2.4, zc), -PI / 2.0)

	var zb := centre(i).z + DEMI + 0.5
	var mi := MeshInstance3D.new()
	var q := QuadMesh.new()
	q.size = Vector2(LARGE_PASSAGE, HAUT_MUR - 1.6)
	mi.mesh = q
	var mat := Shaders.barriere(Color(0.9, 0.15, 0.4))
	mi.material_override = mat
	mi.position = Vector3(x, (HAUT_MUR - 1.6) / 2.0, zb)
	mi.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(mi)
	var corps := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = Vector3(LARGE_PASSAGE, HAUT_MUR, 0.6)
	cs.shape = bs
	corps.add_child(cs)
	corps.position = Vector3(x, HAUT_MUR / 2.0, zb)
	add_child(corps)
	_barrieres.append([mi, corps, mat])

func _prop(nom: String, pos: Vector3, angle := 0.0, ech := 1.0) -> Node3D:
	var n: Node3D = load("res://assets/props/%s.gltf" % nom).instantiate()
	n.position = pos
	n.rotation.y = angle
	n.scale = Vector3.ONE * ech
	add_child(n)
	for mi in n.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return n

func _torche(pos: Vector3, angle: float) -> void:
	_prop("Torch_Metal", pos - Vector3(0, 0.5, 0), angle, 1.0)
	var f := GPUParticles3D.new()
	f.amount = 14
	f.lifetime = 0.6
	var pm := ParticleProcessMaterial.new()
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 12.0
	pm.initial_velocity_min = 0.4
	pm.initial_velocity_max = 0.9
	pm.gravity = Vector3(0, 0.6, 0)
	pm.scale_min = 0.6
	pm.scale_max = 1.1
	var g := Gradient.new()
	g.set_color(0, Color(1.0, 0.75, 0.3, 1.0))
	g.add_point(0.5, Color(1.0, 0.35, 0.1, 0.8))
	g.set_color(g.get_point_count() - 1, Color(0.4, 0.05, 0.0, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	f.process_material = pm
	var qm := QuadMesh.new()
	qm.size = Vector2(0.35, 0.45)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/fx/flame_03.png")
	qm.material = m
	f.draw_pass_1 = qm
	f.position = pos + Vector3(0, 0.25, 0)
	add_child(f)


func _decor() -> void:
	for i in 6:
		var c := centre(i)

		for cote in [-1.0, 1.0]:
			for dz in [-4.0, 4.0]:
				_torche(c + Vector3(cote * (DEMI - 0.15), 2.6, dz), -cote * PI / 2.0)

		var zf := c.z + DEMI - 0.1
		if i < 5:
			_prop("Banner_1" if i % 2 == 0 else "Banner_2", Vector3(c.x - 5.0, 0, zf), PI, 1.6)
			_prop("Banner_1" if i % 2 == 0 else "Banner_2", Vector3(c.x + 5.0, 0, zf), PI, 1.6)
	var c0 := centre(0)
	_prop("Barrel", c0 + Vector3(-9.6, 0, -9.4), 0.4)
	_prop("Barrel", c0 + Vector3(-8.5, 0, -9.8), 1.2)
	_prop("Crate_Wooden", c0 + Vector3(9.3, 0, -9.3), 0.2, 1.1)
	_prop("Crate_Wooden", c0 + Vector3(9.4, 1.0, -9.2), 0.9, 0.8)
	_prop("Vase_Rubble_Medium", c0 + Vector3(-9.5, 0, 9.0), 0.0)
	_prop("Chain_Coil", c0 + Vector3(8.8, 0, 9.2), 0.0)
	var c1 := centre(1)
	_prop("Cage_Small", c1 + Vector3(-9.2, 0, -8.8), 0.3, 1.3)
	_prop("Cage_Small", c1 + Vector3(9.0, 0, 8.6), 2.0, 1.3)
	_prop("Vase_Rubble_Medium", c1 + Vector3(9.4, 0, -9.0), 1.0)
	_prop("Barrel", c1 + Vector3(-9.5, 0, 9.2), 0.0)
	var c2 := centre(2)
	_prop("WeaponStand", c2 + Vector3(-10.0, 0, -3.0), PI / 2.0, 1.2)
	_prop("WeaponStand", c2 + Vector3(10.0, 0, 3.0), -PI / 2.0, 1.2)
	_prop("Shield_Wooden", c2 + Vector3(-9.6, 0, 9.0), 0.6)
	_prop("Crate_Wooden", c2 + Vector3(9.2, 0, -9.2), 0.5)
	_prop("Sword_Bronze", c2 + Vector3(9.0, 0.05, 9.0), 1.0)
	var c3 := centre(3)
	for p in [Vector3(-9.0, 0, -9.0), Vector3(-9.0, 0, 9.0), Vector3(9.0, 0, -9.0), Vector3(9.0, 0, 9.0)]:
		_prop("Cage_Small", c3 + p, p.x * 0.1, 1.5)
	_prop("Chain_Coil", c3 + Vector3(0, 0, -9.5), 0.0, 1.2)
	var c4 := centre(4)
	_prop("Bookcase_2", c4 + Vector3(-10.4, 0, -4.0), PI / 2.0, 1.1)
	_prop("Bookcase_2", c4 + Vector3(-10.4, 0, 4.0), PI / 2.0, 1.1)
	_prop("CandleStick_Stand", c4 + Vector3(9.5, 0, -9.0), 0.0, 1.3)
	_prop("CandleStick_Stand", c4 + Vector3(9.5, 0, 9.0), 0.0, 1.3)
	_prop("Book_Stack_1", c4 + Vector3(9.0, 0, 0.0), 0.3)
	_prop("Scroll_1", c4 + Vector3(9.4, 0, 1.2), 1.3)
	var c5 := centre(5)

	for p in [Vector3(-4.5, 0, 9.0), Vector3(4.5, 0, 9.0), Vector3(-9.5, 0, -2.0), Vector3(9.5, 0, -2.0)]:
		_prop("CandleStick_Triple", c5 + p, 0.0, 1.5)
	_prop("Coin_Pile", c5 + Vector3(-2.5, 0, 9.6), 0.0, 1.6)
	_prop("Coin_Pile_2", c5 + Vector3(2.6, 0, 9.5), 1.0, 1.6)
	_prop("Coin_Pile", c5 + Vector3(-9.3, 0, 9.2), 0.5, 1.4)
	_prop("Coin_Pile_2", c5 + Vector3(9.3, 0, 9.2), 2.0, 1.4)
	_prop("Banner_2", c5 + Vector3(-7.0, 0, DEMI - 0.1), PI, 2.0)
	_prop("Banner_2", c5 + Vector3(7.0, 0, DEMI - 0.1), PI, 2.0)
	_prop("Barrel", c5 + Vector3(-9.4, 0, -9.4), 0.0)
	_prop("Crate_Wooden", c5 + Vector3(9.4, 0, -9.4), 0.4)

func _peupler(i: int) -> void:
	var liste := []
	for d in SALLES[i]:
		var m := Monstre.new()
		var p := centre(i) + Vector3(d[1], 0, d[2])
		m.configurer(d[0], p, PI)
		m.elite_fixe = d[3]
		m.sans_chrono = true
		m.reapparait_auto = false
		add_child(m)
		liste.append(m)
		monstres.append(m)
	_par_salle.append(liste)


func demarrer() -> void:
	actif = true
	salle = 0
	temps = DUREE
	_depart_t = Time.get_ticks_msec() / 1000.0

func restants() -> int:
	if salle >= _par_salle.size():
		return 0
	return _par_salle[salle].filter(func (m): return not m.mort).size()

func _process(dt: float) -> void:
	var t0 := Time.get_ticks_msec() / 1000.0
	for n in _animes:
		if n is OmniLight3D:
			var t: float = t0 + float(n.get_meta("vacille"))
			n.light_energy = float(n.get_meta("base")) * (0.88 + 0.08 * sin(t * 9.0) + 0.04 * sin(t * 23.0))
		else:
			n.rotation.y += dt * float(n.get_meta("tourne"))
	if not actif:
		return
	temps -= dt
	if temps <= 0.0:
		temps = 0.0
		actif = false
		termine.emit(false)
		return
	if restants() == 0:
		if salle < 5:
			_ouvrir(salle)
			salle += 1
			if salle == 5:
				Partie.message.emit("Le roi gobelin vous attend…", Color(1.0, 0.75, 0.3))
				Fx.son("portal", 0.0)
			else:
				Partie.message.emit("Salle %d / 6 : %s" % [salle + 1, NOMS_SALLES[salle]], Color(0.8, 0.6, 1.0))
		else:
			actif = false
			_victoire()

func _ouvrir(i: int) -> void:
	var b: Array = _barrieres[i]
	b[1].queue_free()
	Fx.son("portal", -2.0)
	var tw := create_tween()
	tw.tween_method(func (v): b[2].set_shader_parameter("ouvert", v), 0.0, 1.0, 0.8)
	tw.tween_callback(b[0].queue_free)

func duree() -> float:
	return DUREE - temps


func _victoire() -> void:
	var c := centre(5)
	var t := duree()
	var record := Partie.record_donjon <= 0.0 or t < Partie.record_donjon
	if record:
		Partie.record_donjon = t
	Partie.donjons += 1
	var gain := int(round(1500.0 * (1.0 + Partie.bonus("pieces") / 100.0)))
	Partie.pieces += gain
	var m1: String = Partie.MONNAIES.keys().pick_random()
	var autres: Array = Partie.MONNAIES.keys().filter(func (x): return x != m1)
	var m2: String = autres.pick_random()
	Partie.donner_monnaie(m1, 3)
	Partie.donner_monnaie(m2, 2)
	var unique := Partie.butin_unique("croc_roi")
	Partie.butin_donjon()
	gains = {"pieces": gain, "monnaies": [[m1, 3], [m2, 2]], "unique": unique, "temps": t, "record": record}
	coffre = _prop("Chest_Wood", c + Vector3(0, 0, 7.5), PI, 1.6)
	Fx.anneau(coffre.global_position, Color(1.0, 0.75, 0.2), 4.0)
	Fx.son("chest", 0.0)
	Fx.son("victory", -2.0)
	sortie = Node3D.new()
	add_child(sortie)
	sortie.position = c + Vector3(0, 0, -6.5)
	sortie.add_child(Portail.creer(Color(0.2, 0.75, 1.0), Color(0.4, 0.3, 1.0), 2.2))
	Partie.sauver()
	Partie.change.emit()
	termine.emit(true)
