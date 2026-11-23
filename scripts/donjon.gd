class_name Donjon
extends Node3D





signal termine(victoire: bool)

const ORIGINE := Vector3(600, 0, 0)
const PAS := 36.0
const DEMI := 11.0
const HAUT_MUR := 7.0
const LARGE_PASSAGE := 6.0
const DONJONS := [
	{"nom": "Repaire du roi gobelin", "theme": "pierre", "duree": 270.0, "niveau": 1, "puissance": 120.0, "or": 1500, "boss": "Kargash, le roi gobelin",
		"noms": ["Le hall des crocs", "La fosse aux puglins", "La garde enragée", "Les cages", "L'antichambre", "Le trône de Kargash"]},
	{"nom": "Grotte gelée", "theme": "neige", "duree": 330.0, "niveau": 15, "puissance": 2500.0, "or": 9000, "boss": "Grolm, roi des glaces",
		"noms": ["Le seuil givré", "La galerie de glace", "Le lac gelé", "Les stalactites", "La tempête", "Le trône de Grolm"]},
	{"nom": "Forge de braise", "theme": "braise", "duree": 390.0, "niveau": 30, "puissance": 40000.0, "or": 45000, "boss": "Vorgath, seigneur de braise",
		"noms": ["Les scories", "La coulée", "Le marteau-pilon", "Les fosses ardentes", "Le creuset", "Le cœur de la forge"]},
	{"nom": "Sanctuaire du renard", "theme": "nuit", "duree": 480.0, "niveau": 45, "puissance": 400000.0, "or": 200000, "boss": "Naruto",
		"noms": ["La forêt de nuit", "Le pont suspendu", "Les statues", "La cascade", "Le cercle des clones", "L'arène de Naruto"]},
]
const SALLES_PAR_NIV := [[
	[["gobelin", -4.5, 1.0, false], ["gobelin", 4.5, 1.0, false], ["gobelin", -2.0, 5.5, false], ["gobelin", 2.5, 5.5, false]],
	[["puglin", -5.0, 2.0, false], ["puglin", 5.0, 2.0, false], ["puglin", 0.0, 6.5, false], ["gobelin", 0.0, 1.0, true]],
	[["gobelin_chef", -4.0, 4.0, false], ["gobelin_chef", 4.0, 4.0, false], ["gobelin", -6.5, 0.0, false], ["gobelin", 6.5, 0.0, false]],
	[["puglin", -5.5, 0.5, false], ["puglin", 5.5, 0.5, false], ["puglin", -2.5, 6.0, false], ["puglin", 2.5, 6.0, true]],
	[["puglin_brute", -4.0, 3.0, false], ["puglin_brute", 4.0, 3.0, false], ["gobelin_chef", 0.0, 6.5, true]],
	[["roi_gobelin", 0.0, 4.0, false]],
], [
	[["gobelin_chef", -4.5, 1.0, false], ["gobelin_chef", 4.5, 1.0, false], ["gobelin_chef", 0.0, 5.5, false], ["puglin", 0.0, 2.0, true]],
	[["puglin_brute", -5.0, 2.0, false], ["puglin_brute", 5.0, 2.0, false], ["gobelin_chef", -2.0, 6.5, false], ["gobelin_chef", 2.0, 6.5, false]],
	[["puglin_brute", -4.0, 4.0, false], ["puglin_brute", 4.0, 4.0, false], ["puglin_brute", 0.0, 1.0, true]],
	[["orc", 0.0, 5.0, false], ["gobelin_chef", -6.0, 1.0, false], ["gobelin_chef", 6.0, 1.0, false]],
	[["puglin_brute", -4.0, 2.0, false], ["puglin_brute", 4.0, 2.0, false], ["orc", 0.0, 6.0, true]],
	[["roi_puglin", 0.0, 4.0, false]],
], [
	[["orc", -4.5, 1.0, false], ["orc", 4.5, 1.0, false], ["orc", 0.0, 5.5, false]],
	[["diablotin", -5.0, 2.0, false], ["diablotin", 5.0, 2.0, false], ["orc", 0.0, 6.0, false]],
	[["orc", -4.0, 4.0, false], ["orc", 4.0, 4.0, false], ["diablotin", 0.0, 1.0, true]],
	[["diablotin", -5.5, 1.0, false], ["diablotin", 5.5, 1.0, false], ["diablotin", 0.0, 6.0, false]],
	[["orc_guerrier", 0.0, 5.0, false], ["diablotin", -5.0, 1.0, false], ["diablotin", 5.0, 1.0, false]],
	[["seigneur_braise", 0.0, 4.0, false]],
], [
	[["orc_guerrier", -4.5, 1.5, false], ["orc_guerrier", 4.5, 1.5, false], ["demon", 0.0, 5.5, false]],
	[["demon", -5.0, 2.0, false], ["demon", 5.0, 2.0, false], ["orc_guerrier", 0.0, 6.0, true]],
	[["orc_guerrier", -5.0, 3.0, false], ["orc_guerrier", 5.0, 3.0, false], ["orc_guerrier", 0.0, 6.5, false]],
	[["demon", -5.0, 1.0, false], ["demon", 5.0, 1.0, false], ["demon", 0.0, 6.0, true]],
	[["chevalier", 0.0, 4.5, false]],
	[["naruto", 0.0, 4.0, false]],
]]
const THEMES := {
	"pierre": {"sol": Color(0.85, 0.82, 0.9), "mur": Color(0.8, 0.78, 0.88), "feu": Color(1.0, 0.62, 0.3), "rune": Color(0.55, 0.2, 1.0, 0.55),
		"brume": Color(0.1, 0.05, 0.16), "ambiance": Color(0.22, 0.18, 0.32), "fond": Color(0.01, 0.0, 0.02), "meteo": ""},
	"neige": {"sol": Color(1.15, 1.2, 1.35), "mur": Color(0.75, 0.85, 1.05), "feu": Color(0.55, 0.8, 1.0), "rune": Color(0.3, 0.75, 1.0, 0.6),
		"brume": Color(0.55, 0.65, 0.8), "ambiance": Color(0.45, 0.55, 0.75), "fond": Color(0.6, 0.7, 0.85), "meteo": "neige"},
	"braise": {"sol": Color(0.45, 0.32, 0.3), "mur": Color(0.5, 0.3, 0.25), "feu": Color(1.0, 0.4, 0.12), "rune": Color(1.0, 0.35, 0.05, 0.7),
		"brume": Color(0.35, 0.08, 0.02), "ambiance": Color(0.4, 0.18, 0.1), "fond": Color(0.08, 0.01, 0.0), "meteo": "braises"},
	"nuit": {"sol": Color(0.5, 0.6, 0.55), "mur": Color(0.45, 0.55, 0.5), "feu": Color(0.95, 0.75, 0.35), "rune": Color(1.0, 0.55, 0.1, 0.65),
		"brume": Color(0.06, 0.1, 0.2), "ambiance": Color(0.2, 0.25, 0.4), "fond": Color(0.02, 0.03, 0.08), "meteo": "feuilles"},
}

var niv := 0
var test_rang := -1
var N := 6
var groupe := false
var mult_groupe := 1.0
var allies: Array = []
var cfg: Dictionary
var th: Dictionary
var SALLES: Array
var NOMS_SALLES: Array
var DUREE := 270.0

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

const THEMES_TEST := ["pierre", "neige", "braise", "nuit"]

func _config_test(r: int) -> void:
	var l: Array = Partie.ESPECES_RANG[r]
	var salles := []
	var noms := []
	for k in 9:
		var esp: String = l[k % 2]
		var n := 3 + (k / 3)
		var salle := []
		for j in n:
			var a := TAU * j / n
			salle.append([esp if j % 2 == 0 else l[(k + 1) % 2], cos(a) * 5.0, 3.0 + sin(a) * 3.0, j == 0 and k >= 3])
		salles.append(salle)
		noms.append("Épreuve %d" % (k + 1))
	salles.append([[l[2], 0.0, 4.0, false]])
	noms.append("Épreuve finale")
	SALLES = salles
	cfg = {"nom": "Test de rang %s" % Partie.RANGS[r], "theme": THEMES_TEST[r], "duree": Partie.DUREE_TEST, "noms": noms,
		"boss": Partie.ESPECES[l[2]]["nom"], "or": 0}

func _ready() -> void:
	if test_rang >= 0:
		_config_test(test_rang)
	else:
		cfg = DONJONS[niv]
		SALLES = SALLES_PAR_NIV[niv]
	th = THEMES[cfg["theme"]]
	N = SALLES.size()
	NOMS_SALLES = cfg["noms"]
	DUREE = cfg["duree"]
	temps = DUREE
	_materiaux()
	for i in N:
		_salle(i)
		if i < N - 1:
			_couloir(i)
	for i in N:
		_peupler(i)
	_decor()
	_meteo()
	_pieges_et_secret()
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
	_mat_sol.albedo_color = th["sol"]
	if cfg["theme"] == "neige":
		_mat_sol.roughness = 0.35
		_mat_sol.metallic_specular = 0.8
	_mat_mur = StandardMaterial3D.new()
	_mat_mur.albedo_texture = load("res://assets/fx/mur.png")
	_mat_mur.normal_enabled = true
	_mat_mur.normal_texture = load("res://assets/fx/mur_n.png")
	_mat_mur.roughness = 0.9
	_mat_mur.uv1_triplanar = true
	_mat_mur.uv1_scale = Vector3(0.28, 0.28, 0.28)
	_mat_mur.albedo_color = th["mur"]

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
		var ouvert: bool = (cote == -1 and i > 0) or (cote == 1 and i < N - 1)
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
	q.size = Vector2(9, 9) if i < N - 1 else Vector2(13, 13)
	rune.mesh = q
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.albedo_texture = load("res://assets/fx/magic_02.png")
	m.albedo_color = th["rune"] if i < N - 1 else Color(1.0, 0.55, 0.15, 0.7)
	rune.material_override = m
	rune.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	rune.position = c + Vector3(0, 0.03, 3.0 if i == N - 1 else 2.0)
	rune.set_meta("tourne", 0.12 if i < N - 1 else -0.2)
	add_child(rune)

	for cote in [-1, 1]:
		var l := OmniLight3D.new()
		l.light_color = th["feu"]
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
	lv.light_color = Color(th["rune"].r, th["rune"].g, th["rune"].b) if i < N - 1 else Color(1.0, 0.45, 0.2)
	lv.light_energy = 2.4 if i < N - 1 else 3.6
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
	l.light_color = th["feu"]
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
	for i in N:
		var c := centre(i)

		for cote in [-1.0, 1.0]:
			for dz in [-4.0, 4.0]:
				_torche(c + Vector3(cote * (DEMI - 0.15), 2.6, dz), -cote * PI / 2.0)

		var zf := c.z + DEMI - 0.1
		if i < N - 1:
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
		if groupe:
			m.mult = mult_groupe
		if test_rang >= 0:
			m.mult = Partie.MULT_TEST
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
	return _par_salle[salle].filter(func (m): return is_instance_valid(m) and not m.mort and not m.allie).size()

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
		if salle < N - 1:
			_ouvrir(salle)
			salle += 1
			if salle == N - 1:
				Partie.message.emit("%s vous attend…" % cfg["boss"], Color(1.0, 0.75, 0.3))
				Fx.son("portal", 0.0)
			else:
				Partie.message.emit("Salle %d / 6 : %s" % [salle + 1, NOMS_SALLES[salle]], Color(0.8, 0.6, 1.0))
		else:
			actif = false
			_victoire()

var pieges: Array = []
var secret: Node3D = null
var secret_ouvert := false

func _pieges_et_secret() -> void:
	if test_rang >= 0:
		return
	for i in range(1, N - 1):
		var c := centre(i)
		for k in 2 + niv:
			var dalle := MeshInstance3D.new()
			var bm := BoxMesh.new()
			bm.size = Vector3(2.4, 0.06, 2.4)
			dalle.mesh = bm
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(0.35, 0.1, 0.1)
			m.emission_enabled = true
			m.emission = Color(1.0, 0.15, 0.05)
			m.emission_energy_multiplier = 0.0
			dalle.material_override = m
			dalle.position = c + Vector3(randf_range(-7, 7), 0.03, randf_range(-6, 6))
			add_child(dalle)
			pieges.append({"n": dalle, "m": m, "t": randf_range(0.0, 3.0)})
	var s := randi_range(1, N - 2)
	secret = MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = Vector3(0.3, 2.6, 2.4)
	(secret as MeshInstance3D).mesh = b
	var sm := StandardMaterial3D.new()
	sm.albedo_texture = load("res://assets/fx/mur.png")
	sm.albedo_color = Color(0.6, 0.45, 0.8)
	sm.emission_enabled = true
	sm.emission = Color(0.5, 0.2, 0.9)
	sm.emission_energy_multiplier = 0.6
	(secret as MeshInstance3D).material_override = sm
	secret.position = centre(s) + Vector3(DEMI - 0.2, 1.3, randf_range(-4, 4))
	add_child(secret)

func _maj_pieges(dt: float) -> void:
	if ville == null or not actif:
		return
	var j: Node3D = ville.joueur
	for p in pieges:
		p["t"] -= dt
		var t: float = p["t"]
		p["m"].emission_energy_multiplier = 0.0 if t > 1.0 else (3.0 - t * 2.5)
		if t <= 0.0:
			p["t"] = 3.0
			var pos: Vector3 = p["n"].global_position
			Fx.anneau(pos, Color(1.0, 0.25, 0.1), 1.6)
			if absf(j.global_position.x - pos.x) < 1.3 and absf(j.global_position.z - pos.z) < 1.3 and absf(j.global_position.y - pos.y) < 1.5:
				var d: float = Partie.ATK_RANG[niv] * 1.5
				Fx.texte(j.global_position + Vector3(0, 2.3, 0), "-%d  PIÈGE" % int(d), Color(1.0, 0.3, 0.2), 1.1, 1.0)
				ville.hud.flash_degats("PIÈGE")
				if Partie.blesser(d):
					ville.mort_joueur()

func ouvrir_secret() -> void:
	if secret_ouvert or secret == null:
		return
	secret_ouvert = true
	var pos := secret.global_position
	Fx.anneau(pos, Color(0.6, 0.3, 1.0), 3.0)
	Fx.son("slam", 0.0)
	secret.queue_free()
	if randf() < 0.35:
		var l: Array = Partie.ESPECES_RANG[mini(niv + 1, 3)]
		var m := Monstre.new()
		m.configurer(l[randi() % 2], pos + Vector3(-3, -1.3, 0), -PI / 2.0)
		m.sans_chrono = true
		m.reapparait_auto = false
		m.elite_fixe = true
		m.mult = 2.0
		add_child(m)
		m.chrono = 0.0
		monstres.append(m)
		ville.monstres.append(m)
		ville.hud.annonce("SALLE SECRÈTE", "Un gardien rare surgit du mur !", Color(0.8, 0.5, 1.0))
	else:
		var g := int(float(cfg["or"]) * 0.6)
		Partie.pieces += g
		Partie.or_total += g
		Partie.butin_donjon(niv + 1)
		Partie.eclats_forge += 5 + niv * 3
		ville.hud.annonce("SALLE SECRÈTE", "Coffre caché : +%s pièces, +%d éclats de forge" % [Fx.court(g), 5 + niv * 3], Color(0.8, 0.5, 1.0))

func appliquer_ambiance(env: Environment) -> void:
	env.background_color = th["fond"]
	env.ambient_light_color = th["ambiance"]
	env.fog_light_color = th["brume"]
	env.fog_density = 0.008 if cfg["theme"] == "neige" else 0.004
	env.ambient_light_energy = 2.4
	var lune := DirectionalLight3D.new()
	lune.rotation_degrees = Vector3(-55, 30, 0)
	lune.light_color = th["feu"].lerp(Color.WHITE, 0.5)
	lune.light_energy = 0.7
	add_child(lune)

func _meteo() -> void:
	var m: String = th["meteo"]
	if m == "":
		return
	for i in N:
		var p := GPUParticles3D.new()
		p.amount = 260 if m == "neige" else 90
		p.lifetime = 6.0
		p.preprocess = 6.0
		p.visibility_aabb = AABB(Vector3(-14, -8, -14), Vector3(28, 18, 28))
		var pm := ParticleProcessMaterial.new()
		pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
		pm.emission_box_extents = Vector3(DEMI, 0.5, DEMI)
		var col: Color
		match m:
			"neige":
				pm.direction = Vector3(0.2, -1, 0.1)
				pm.gravity = Vector3(0.15, -0.6, 0)
				pm.initial_velocity_min = 0.6
				pm.initial_velocity_max = 1.4
				pm.turbulence_enabled = true
				pm.turbulence_noise_strength = 0.6
				col = Color(1, 1, 1, 0.9)
			"braises":
				pm.direction = Vector3(0, 1, 0)
				pm.gravity = Vector3(0, 0.4, 0)
				pm.initial_velocity_min = 0.3
				pm.initial_velocity_max = 0.9
				col = Color(1.0, 0.45, 0.1, 1.0)
			_:
				pm.direction = Vector3(0.4, -1, 0.3)
				pm.gravity = Vector3(0.3, -0.35, 0.2)
				pm.initial_velocity_min = 0.4
				pm.initial_velocity_max = 1.0
				pm.angular_velocity_min = -90.0
				pm.angular_velocity_max = 90.0
				col = Color(1.0, 0.6, 0.2, 0.9)
		pm.scale_min = 0.6
		pm.scale_max = 1.3
		pm.color = col
		p.process_material = pm
		var q := QuadMesh.new()
		q.size = Vector2(0.09, 0.09) if m == "neige" else Vector2(0.12, 0.12)
		var mat := StandardMaterial3D.new()
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mat.blend_mode = BaseMaterial3D.BLEND_MODE_ADD if m == "braises" else BaseMaterial3D.BLEND_MODE_MIX
		mat.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		mat.vertex_color_use_as_albedo = true
		mat.albedo_texture = load("res://assets/fx/etincelle.png") if m == "braises" else load("res://assets/fx/circle_05.png")
		q.material = mat
		p.draw_pass_1 = q
		p.position = centre(i) + Vector3(0, 0.5 if m == "braises" else HAUT_MUR + 1.0, 0)
		add_child(p)
	if m == "neige":
		for i in N:
			for k in 5:
				var pic := MeshInstance3D.new()
				var cy := CylinderMesh.new()
				cy.top_radius = 0.0
				cy.bottom_radius = randf_range(0.25, 0.5)
				cy.height = randf_range(1.2, 2.6)
				cy.radial_segments = 6
				pic.mesh = cy
				var gm := StandardMaterial3D.new()
				gm.albedo_color = Color(0.7, 0.88, 1.0, 0.75)
				gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
				gm.roughness = 0.1
				gm.metallic_specular = 1.0
				gm.emission_enabled = true
				gm.emission = Color(0.3, 0.55, 0.9)
				gm.emission_energy_multiplier = 0.4
				pic.material_override = gm
				pic.rotation_degrees.x = 180.0
				pic.position = centre(i) + Vector3(randf_range(-DEMI + 1, DEMI - 1), HAUT_MUR - cy.height / 2.0, randf_range(-DEMI + 1, DEMI - 1))
				pic.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
				add_child(pic)
	elif m == "braises":
		for i in N:
			for p2 in [Vector3(-8.5, 0, 0), Vector3(8.5, 0, 0)]:
				var lave := MeshInstance3D.new()
				var pl := PlaneMesh.new()
				pl.size = Vector2(3.0, 5.0)
				lave.mesh = pl
				var lm := StandardMaterial3D.new()
				lm.albedo_color = Color(1.0, 0.35, 0.05)
				lm.emission_enabled = true
				lm.emission = Color(1.0, 0.3, 0.02)
				lm.emission_energy_multiplier = 2.5
				lave.material_override = lm
				lave.position = centre(i) + p2 + Vector3(0, 0.02, 0)
				add_child(lave)
				var ll := OmniLight3D.new()
				ll.light_color = Color(1.0, 0.4, 0.1)
				ll.light_energy = 2.0
				ll.omni_range = 6.0
				ll.position = lave.position + Vector3(0, 0.8, 0)
				add_child(ll)

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
	var c := centre(N - 1)
	var t := duree()
	if test_rang >= 0:
		gains = {"test": true, "temps": t}
		Partie.reussir_test()
		sortie = Node3D.new()
		add_child(sortie)
		sortie.position = c + Vector3(0, 0, -6.5)
		sortie.add_child(Portail.creer(Color(0.2, 0.75, 1.0), Color(0.4, 0.3, 1.0), 2.2))
		Fx.son("victory", -2.0)
		termine.emit(true)
		return
	var ancien := float(Partie.records.get(str(niv), 0.0))
	var record := ancien <= 0.0 or t < ancien
	if record:
		Partie.records[str(niv)] = t
	if niv == 0 and (Partie.record_donjon <= 0.0 or t < Partie.record_donjon):
		Partie.record_donjon = t
	Partie.donjons += 1
	Partie.donjons_finis[str(niv)] = int(Partie.donjons_finis.get(str(niv), 0)) + 1
	Partie.progres("donjons")
	var gain := int(round(float(cfg["or"]) * (1.0 + Partie.bonus("pieces") / 100.0)))
	Partie.pieces += gain
	Partie.or_total += gain
	var m1: String = Partie.MONNAIES.keys().pick_random()
	var autres: Array = Partie.MONNAIES.keys().filter(func (x): return x != m1)
	var m2: String = autres.pick_random()
	Partie.donner_monnaie(m1, 3 + niv * 2)
	Partie.donner_monnaie(m2, 2 + niv * 2)
	var unique := Partie.butin_unique("croc_roi") if niv == 0 else false
	Partie.butin_donjon(niv)
	if randf() < 0.2 + 0.05 * niv:
		Partie.donner_cle()
	gains = {"pieces": gain, "monnaies": [[m1, 3 + niv * 2], [m2, 2 + niv * 2]], "unique": unique, "temps": t, "record": record}
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
