class_name Arene
extends Node3D

signal termine(victoire: bool)

const ORIGINE := Vector3(0, 0, 600)
const RAYON := 14.0
const DUREE := 90.0

var adversaire: Dictionary
var rival: Monstre
var temps := DUREE
var actif := false

func _ready() -> void:
	var sol := StandardMaterial3D.new()
	sol.albedo_texture = load("res://assets/fx/dalles.png")
	sol.uv1_triplanar = true
	sol.uv1_scale = Vector3(0.25, 0.25, 0.25)
	sol.albedo_color = Color(0.75, 0.62, 0.5)
	var mur := StandardMaterial3D.new()
	mur.albedo_texture = load("res://assets/fx/mur.png")
	mur.uv1_triplanar = true
	mur.uv1_scale = Vector3(0.28, 0.28, 0.28)
	mur.albedo_color = Color(0.85, 0.7, 0.55)
	_boite(Vector3(RAYON * 2 + 4, 0.4, RAYON * 2 + 4), ORIGINE + Vector3(0, -0.2, 0), sol)
	for k in 16:
		var a := TAU * k / 16.0
		var p := ORIGINE + Vector3(cos(a), 0, sin(a)) * (RAYON + 1.0)
		var b := _boite(Vector3(6.0, 5.0, 1.0), p + Vector3(0, 2.5, 0), mur)
		b.rotation.y = -a + PI / 2.0
		b.get_meta("corps").rotation.y = b.rotation.y
	var anneau := MeshInstance3D.new()
	var t := TorusMesh.new()
	t.inner_radius = RAYON - 0.3
	t.outer_radius = RAYON
	anneau.mesh = t
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = Color(1.0, 0.6, 0.2)
	anneau.material_override = m
	anneau.scale = Vector3(1, 0.05, 1)
	anneau.position = ORIGINE + Vector3(0, 0.05, 0)
	add_child(anneau)
	for k in 4:
		var l := OmniLight3D.new()
		var a2 := TAU * k / 4.0
		l.light_color = Color(1.0, 0.7, 0.4)
		l.light_energy = 4.0
		l.omni_range = 20.0
		l.position = ORIGINE + Vector3(cos(a2) * 9.0, 6.0, sin(a2) * 9.0)
		add_child(l)
	var e: Dictionary = Partie.ESPECES["rival"]
	rival = Monstre.new()
	rival.configurer("rival", ORIGINE + Vector3(0, 0, 6), PI)
	rival.sans_chrono = true
	rival.reapparait_auto = false
	rival.elite_fixe = true
	rival.pv_perso = Partie.bot_dps(adversaire) * 45.0
	rival.atk_perso = Partie.ATK_RANG[mini(int(adversaire["niveau"]) / 12, 3)] * 1.3
	rival.nom_perso = "%s  (ÉLO %d)" % [adversaire["nom"], int(adversaire.get("elo", 1000))]
	add_child(rival)
	rival.vaincu.connect(func (_m):
		if actif:
			actif = false
			termine.emit(true))

func point_depart() -> Vector3:
	return ORIGINE + Vector3(0, 0.3, -8)

func _boite(taille: Vector3, pos: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var bm := BoxMesh.new()
	bm.size = taille
	mi.mesh = bm
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	var c := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var bs := BoxShape3D.new()
	bs.size = taille
	cs.shape = bs
	c.add_child(cs)
	c.position = pos
	add_child(c)
	mi.set_meta("corps", c)
	return mi

func demarrer() -> void:
	actif = true
	temps = DUREE
	rival.chrono = 0.0

func _process(dt: float) -> void:
	if not actif:
		return
	temps -= dt
	if temps <= 0.0:
		actif = false
		termine.emit(false)

func abandon() -> void:
	if actif:
		actif = false
		termine.emit(false)
