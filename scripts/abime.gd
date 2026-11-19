class_name Abime
extends Node3D

# L'Abîme : 1000 étages aux dimensions étranges, chaque étage = 1 à 3 salles (petite, moyenne, grande).
const ORIGINE := Vector3(0, 0, -900)
const ETAGES := 1000
const TAILLES := {"petite": 14.0, "moyenne": 22.0, "grande": 32.0}

var ville: Node
var etage := 0
var monstres: Array = []
var _decor: Node3D
var sortie: Node3D = null
var _depart := ORIGINE

static func mult_etage(f: int) -> float:
	return 0.5 * pow(1.05, f - 1)

func point_depart() -> Vector3:
	return _depart + Vector3(0, 0.4, 0)

func demarrer() -> void:
	_suivant()

func _mat(c: Color, em := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = load("res://assets/fx/dalles.png")
	m.uv1_triplanar = true
	m.uv1_scale = Vector3(0.25, 0.25, 0.25)
	m.albedo_color = c
	if em > 0.0:
		m.emission_enabled = true
		m.emission = c
		m.emission_energy_multiplier = em
	return m

func _boite(parent: Node3D, taille: Vector3, pos: Vector3, mat: Material, collision := true) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var b := BoxMesh.new()
	b.size = taille
	mi.mesh = b
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	if collision:
		var c := StaticBody3D.new()
		var cs := CollisionShape3D.new()
		var bs := BoxShape3D.new()
		bs.size = taille
		cs.shape = bs
		c.add_child(cs)
		c.position = pos
		parent.add_child(c)
	return mi

func _suivant() -> void:
	etage += 1
	if _decor:
		_decor.queue_free()
	for m in monstres:
		if is_instance_valid(m) and not m.allie:
			ville.monstres.erase(m)
			m.queue_free()
	monstres = monstres.filter(func (m): return is_instance_valid(m) and m.allie)
	sortie = null
	_decor = Node3D.new()
	add_child(_decor)
	var bloc := (etage - 1) / 10
	var style := bloc % 4
	var teinte := Color.from_hsv(fmod(bloc * 0.237, 1.0), 0.55, 0.75)
	var sol := _mat(teinte.darkened(0.3))
	var mur := _mat(teinte.darkened(0.55), 0.15)
	var nb := 1 + (etage % 3)
	var z := ORIGINE.z
	var mult := mult_etage(etage)
	var boss_fait := false
	for s in nb:
		var genre: String = ["petite", "moyenne", "grande"][(etage + s) % 3] if s < nb - 1 else "grande"
		var L: float = TAILLES[genre]
		var c := Vector3(ORIGINE.x, 0, z + L / 2.0)
		_boite(_decor, Vector3(L, 0.4, L), c + Vector3(0, -0.2, 0), sol)
		var hm: float = [3.0, 1.0, 6.0, 2.0][style]
		for cote in [-1.0, 1.0]:
			_boite(_decor, Vector3(1, hm, L), c + Vector3(cote * (L / 2.0 + 0.5), hm / 2.0, 0), mur)
		match style:
			1:
				for a in 8:
					var an := TAU * a / 8.0
					_boite(_decor, Vector3(1.4, 7.0, 1.4), c + Vector3(cos(an), 0, sin(an)) * (L * 0.38) + Vector3(0, 3.5, 0), mur)
			2:
				for a in int(L / 4.0):
					_boite(_decor, Vector3(1.0, 6.0, 1.0), c + Vector3(randf_range(-L / 2 + 2, L / 2 - 2), 3.0, randf_range(-L / 2 + 2, L / 2 - 2)), mur)
			3:
				for a in 4:
					var pl := _boite(_decor, Vector3(L * 0.3, 0.5, L * 0.3), c + Vector3(randf_range(-L / 4, L / 4), 1.6 + a * 1.2, randf_range(-L / 4, L / 4)), _mat(teinte.lightened(0.15), 0.4))
					pl.rotation.y = randf() * TAU
		if s == 0:
			_boite(_decor, Vector3(L, 3.0, 1), c + Vector3(0, 1.5, -L / 2.0 - 0.5), mur)
			_depart = c + Vector3(0, 0, -L / 2.0 + 2.5)
		# dimensions étranges : blocs flottants qui tournent au-dessus de la salle
		for k in int(L / 5.0):
			var cube := _boite(_decor, Vector3.ONE * randf_range(0.6, 2.2), c + Vector3(randf_range(-L / 2, L / 2), randf_range(5, 12), randf_range(-L / 2, L / 2)), _mat(teinte.lightened(0.2), 1.2), false)
			cube.rotation = Vector3(randf() * TAU, randf() * TAU, 0)
			cube.set_meta("tourne", randf_range(-1.0, 1.0))
		var l := OmniLight3D.new()
		l.light_color = teinte.lightened(0.3)
		l.light_energy = 4.0
		l.omni_range = L * 1.1
		l.position = c + Vector3(0, 7, 0)
		_decor.add_child(l)
		var n: int = {"petite": 3, "moyenne": 5, "grande": 7}[genre]
		for k in n:
			var pool: Array = Partie.ESPECES_RANG[mini(etage / 60, 3)] + ["chaman_demon", "chasseur_dechu", "garde_sang"].slice(0, mini(etage / 100, 3))
			var esp: String = pool[randi() % mini(pool.size(), 2 + etage / 120)]
			if genre == "grande" and not boss_fait and (etage % 5 == 0 or k == 0 and etage % 10 == 0):
				esp = Chateau.BOSS[(etage / 5) % Chateau.BOSS.size()] if etage >= 20 else pool[2] if pool.size() > 2 else pool[0]
				boss_fait = true
			var m := Monstre.new()
			m.configurer(esp, c + Vector3(randf_range(-L / 2 + 2, L / 2 - 2), 0, randf_range(-L / 2 + 3, L / 2 - 2)), PI)
			m.sans_chrono = true
			m.reapparait_auto = false
			m.elite_fixe = randf() < 0.15
			m.mult = mult
			_decor.add_child(m)
			monstres.append(m)
			ville.monstres.append(m)
		z += L + 1.0
	var fin := _boite(_decor, Vector3(10, 3.0, 1), Vector3(ORIGINE.x, 1.5, z), mur)
	fin.set_meta("fin", true)
	_sortie_z = z - 4.0
	for m in monstres:
		if is_instance_valid(m) and m.allie:
			m.global_position = _depart + Vector3(2.0, 0, 1.0)
	Partie.message.emit("Abîme : étage %d / %d  (%d salle%s) · %s" % [etage, ETAGES, nb, "s" if nb > 1 else "", ["Salles de pierre", "Cercles de colonnes", "Forêt de piliers", "Dalles suspendues"][style]], Color(0.6, 1.0, 0.85))

var _sortie_z := 0.0

func _process(dt: float) -> void:
	if _decor:
		for n in _decor.get_children():
			if n.has_meta("tourne"):
				n.rotation.y += dt * float(n.get_meta("tourne"))
	if sortie == null and monstres.all(func (m): return not is_instance_valid(m) or m.mort or m.allie):
		if etage > Partie.abime_max:
			Partie.abime_max = etage
			Partie.sauver()
		sortie = Node3D.new()
		_decor.add_child(sortie)
		sortie.position = Vector3(ORIGINE.x, 0, _sortie_z)
		sortie.add_child(Portail.creer(Color(0.3, 1.0, 0.7), Color(0.5, 0.2, 1.0), 2.0))
		Fx.son("portal", -2.0)
	if sortie and ville.joueur.global_position.distance_to(sortie.global_position) < 3.5 and etage < ETAGES:
		_suivant()
		ville._teleporter(point_depart(), PI)
