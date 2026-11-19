class_name Chateau
extends Node3D

# Château rouge : une seule grande salle, 250 étages, un boss tous les 10 étages.
signal termine(etage: int)

const ORIGINE := Vector3(-600, 0, 0)
const DEMI := 20.0
const ETAGES := 250
const TEMPS_DEPART := 150.0
const BONUS_ETAGE := 25.0
const BONUS_BOSS := 60.0
const POOLS := [["orc", "diablotin", "chaman_demon"], ["chaman_demon", "orc_guerrier", "demon"],
	["demon", "chasseur_dechu", "garde_sang"], ["chasseur_dechu", "garde_sang", "chaman_demon"], ["garde_sang", "chasseur_dechu", "demon"]]
const BOSS := ["b_vulcanor", "b_mortis", "b_sire", "b_ozzug"]

var ville: Node
var etage := 0
var temps := TEMPS_DEPART
var actif := false
var monstres: Array = []
var _vague: Array = []
var _pause := 0.0

static func mult_etage(f: int) -> float:
	return 0.6 * pow(1.07, f - 1)

func _ready() -> void:
	var sol := StandardMaterial3D.new()
	sol.albedo_texture = load("res://assets/fx/dalles.png")
	sol.uv1_triplanar = true
	sol.uv1_scale = Vector3(0.25, 0.25, 0.25)
	sol.albedo_color = Color(0.55, 0.25, 0.28)
	var mur := StandardMaterial3D.new()
	mur.albedo_texture = load("res://assets/fx/mur.png")
	mur.uv1_triplanar = true
	mur.uv1_scale = Vector3(0.28, 0.28, 0.28)
	mur.albedo_color = Color(0.45, 0.2, 0.22)
	var L := DEMI * 2.0 + 2.0
	_boite(Vector3(L, 0.4, L), ORIGINE + Vector3(0, -0.2, 0), sol)
	for c in [Vector3(-DEMI - 0.5, 5, 0), Vector3(DEMI + 0.5, 5, 0)]:
		_boite(Vector3(1, 10, L), ORIGINE + c, mur)
	for c in [Vector3(0, 5, -DEMI - 0.5), Vector3(0, 5, DEMI + 0.5)]:
		_boite(Vector3(L, 10, 1), ORIGINE + c, mur)
	for px in [-12.0, 0.0, 12.0]:
		for pz in [-12.0, 12.0]:
			_boite(Vector3(1.6, 10, 1.6), ORIGINE + Vector3(px, 5, pz), mur)
	var tapis := MeshInstance3D.new()
	var pl := PlaneMesh.new()
	pl.size = Vector2(6, L - 2)
	tapis.mesh = pl
	var tm := StandardMaterial3D.new()
	tm.albedo_color = Color(0.5, 0.05, 0.08)
	tm.roughness = 1.0
	tapis.material_override = tm
	tapis.position = ORIGINE + Vector3(0, 0.02, 0)
	add_child(tapis)
	for k in 8:
		var a := TAU * k / 8.0
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.25, 0.2)
		l.light_energy = 3.5
		l.omni_range = 18.0
		l.position = ORIGINE + Vector3(cos(a) * 15.0, 6.0, sin(a) * 15.0)
		add_child(l)
	var p := GPUParticles3D.new()
	p.amount = 120
	p.lifetime = 5.0
	p.preprocess = 5.0
	p.visibility_aabb = AABB(Vector3(-25, -2, -25), Vector3(50, 14, 50))
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(DEMI, 0.2, DEMI)
	pm.direction = Vector3(0, 1, 0)
	pm.gravity = Vector3(0, 0.5, 0)
	pm.initial_velocity_min = 0.2
	pm.initial_velocity_max = 0.6
	pm.color = Color(1.0, 0.2, 0.15)
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.1, 0.1)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	qm.vertex_color_use_as_albedo = true
	qm.albedo_texture = load("res://assets/fx/etincelle.png")
	q.material = qm
	p.draw_pass_1 = q
	p.position = ORIGINE
	add_child(p)

func _boite(taille: Vector3, pos: Vector3, mat: Material) -> void:
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

func point_depart() -> Vector3:
	return ORIGINE + Vector3(0, 0.3, -DEMI + 3.0)

func demarrer() -> void:
	actif = true
	etage = 0
	temps = TEMPS_DEPART
	_suivant()

func _ajouter_monstre(esp: String, pos: Vector3, mult: float, elite := false) -> Monstre:
	var m := Monstre.new()
	m.configurer(esp, pos, PI)
	m.sans_chrono = true
	m.reapparait_auto = false
	m.elite_fixe = elite
	m.mult = mult
	add_child(m)
	m.chrono = 0.0
	monstres.append(m)
	_vague.append(m)
	ville.monstres.append(m)
	Fx.anneau(pos, Color(1.0, 0.2, 0.2), 2.0)
	return m

func _suivant() -> void:
	etage += 1
	_vague.clear()
	var mult := mult_etage(etage)
	var c := ORIGINE + Vector3(0, 0, 6)
	if etage % 10 == 0:
		var b: String = BOSS[(etage / 10 - 1) % BOSS.size()]
		var boss := _ajouter_monstre(b, c, mult)
		var meca: String = Partie.ESPECES[b].get("meca", "")
		if meca == "totems":
			for k in 3:
				var a := TAU * k / 3.0
				boss.totems.append(_ajouter_monstre("totem", c + Vector3(cos(a), 0, sin(a)) * 9.0, mult))
		elif meca == "furie":
			boss.enrage = true
		ville.hud.annonce("ÉTAGE %d — BOSS" % etage, "%s  ·  %s" % [Partie.ESPECES[b]["nom"], Partie.MECAS.get(meca, "")], Color(1.0, 0.3, 0.3))
	else:
		var pool: Array = POOLS[mini(etage / 50, POOLS.size() - 1)]
		var n := 4 + mini(4, etage / 30)
		for k in n:
			var a := TAU * k / n
			_ajouter_monstre(pool[k % pool.size()], c + Vector3(cos(a) * 8.0, 0, sin(a) * 8.0), mult, randf() < 0.1)
		Partie.message.emit("Étage %d / %d" % [etage, ETAGES], Color(1.0, 0.5, 0.45))

func _process(dt: float) -> void:
	if not actif:
		return
	temps -= dt
	if temps <= 0.0:
		_fin()
		return
	if _pause > 0.0:
		_pause -= dt
		if _pause <= 0.0:
			_suivant()
		return
	if _vague.all(func (m): return not is_instance_valid(m) or m.mort):
		var boss := etage % 10 == 0
		temps += BONUS_BOSS if boss else BONUS_ETAGE
		Partie.etage_franchi(etage, boss)
		if etage >= ETAGES:
			_fin()
			return
		_pause = 2.0

func _fin() -> void:
	if not actif:
		return
	actif = false
	termine.emit(etage - (0 if _vague.all(func (m): return not is_instance_valid(m) or m.mort) else 1))
