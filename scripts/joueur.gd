class_name Joueur
extends CharacterBody3D




const VITESSE := 7.5
const PORTEE := 2.0
const CADENCE := 0.55
const CHANCE_CRIT := 0.15

var entree := Vector2.ZERO
var cible: Monstre = null
var _corps: Node3D
var _ap: AnimationPlayer
var _coup_t := 0.0
var _coup_n := 0
var _anim_coup := 0.0
var _dernier_coup := 0
var camera_lacet := 0.0
var _main: BoneAttachment3D
var _arme_vue := ""
var invulnerable := 0.0
var _dash := Vector3.ZERO
var _dash_t := 0.0
var recharges := {"esquive": 0.0, "brise": 0.0, "cri": 0.0, "domaine": 0.0}


func _maj_arme() -> void:
	var a := Partie.arme()
	var nom: String = Partie.base(a)["modele"] if not a.is_empty() else ""
	var effet: String = Partie.base(a).get("effet", "") if not a.is_empty() else ""
	if nom + effet == _arme_vue:
		return
	_arme_vue = nom + effet
	for c in _main.get_children():
		c.queue_free()
	if nom == "":
		return
	var w := Modele.arme(nom)
	if effet == "unique":

		for mi in w.find_children("*", "MeshInstance3D", true, false):
			var m := StandardMaterial3D.new()
			m.albedo_color = Color(1.0, 0.76, 0.3)
			m.metallic = 0.9
			m.roughness = 0.25
			m.emission_enabled = true
			m.emission = Color(1.0, 0.6, 0.15)
			m.emission_energy_multiplier = 0.35
			(mi as MeshInstance3D).material_override = m
			(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.7, 0.25, 1.0), 2.2)
	elif effet == "shiny":
		for mi in w.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.85, 0.35, 1.0), 3.0)
		w.add_child(_etincelles(Color(0.9, 0.55, 1.0)))
	if effet != "":
		var lum := OmniLight3D.new()
		lum.light_color = Color(0.75, 0.4, 1.0) if effet == "shiny" else Color(1.0, 0.7, 0.35)
		lum.light_energy = 0.9
		lum.omni_range = 2.5
		lum.position = Vector3(0, 0.6, 0)
		w.add_child(lum)
	var porte := Node3D.new()
	porte.name = "Prise"
	porte.rotation_degrees = Modele.reglage_main["rot"]
	porte.position = Modele.reglage_main["pos"]
	porte.add_child(w)
	_main.add_child(porte)

	var sk: Skeleton3D = _main.get_parent()
	var ech := sk.global_transform.basis.get_scale().x
	porte.scale = Vector3.ONE / maxf(ech, 0.0001)

func _ready() -> void:
	var forme := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	forme.shape = cap
	forme.position.y = 0.9
	add_child(forme)
	floor_snap_length = 0.5
	floor_max_angle = deg_to_rad(50)
	_corps = Modele.creer("hero", 1.85)
	add_child(_corps)
	_ap = Modele.lecteur(_corps)
	Modele.jouer(_ap, "Idle")
	var sk: Skeleton3D = _corps.find_child("Skeleton3D", true, false)
	_main = BoneAttachment3D.new()
	_main.name = "MainDroite"
	for i in sk.get_bone_count():
		var bn := sk.get_bone_name(i)
		if bn.ends_with("RightHand") or bn.contains("RightHand_"):
			_main.bone_name = bn
			break
	sk.add_child(_main)
	Partie.change.connect(_maj_arme)
	_maj_arme()

func viser(m: Monstre) -> void:
	cible = m
	if m:
		Fx.son("select", -6.0)


func cible_devant(monstres: Array, portee := 16.0) -> Monstre:
	var avant := _corps.global_transform.basis.z
	avant.y = 0
	avant = avant.normalized()
	var mieux: Monstre = null
	var score := INF
	for m: Monstre in monstres:
		if m.mort:
			continue
		var v := m.global_position - global_position
		v.y = 0
		var d := v.length()
		if d > portee:
			continue
		var face := avant.dot(v.normalized()) if d > 0.1 else 1.0
		var s := d * (2.2 - face)
		if s < score:
			score = s
			mieux = m
	return mieux

func _physics_process(dt: float) -> void:
	var dir := Vector3.ZERO
	if entree.length() > 0.08:
		var avant := Vector3(- sin(camera_lacet), 0, -cos(camera_lacet))
		var droite := Vector3(cos(camera_lacet), 0, -sin(camera_lacet))
		dir = droite * entree.x + avant * entree.y
		if dir.length() > 1.0:
			dir = dir.normalized()
		if entree.length() > 0.5 and not Partie.auto_attaque:
			cible = null
	if Partie.auto_attaque and entree.length() < 0.2 and (cible == null or not is_instance_valid(cible) or cible.mort):
		cible = cible_devant(get_parent().monstres, 14.0)
	var en_combat := cible != null and is_instance_valid(cible) and not cible.mort
	if cible and (not is_instance_valid(cible) or cible.mort):
		cible = null
	var distance := INF
	if en_combat:
		var v := cible.global_position - global_position
		v.y = 0
		distance = v.length() - cible.haut() * 0.25
		if distance > PORTEE and dir == Vector3.ZERO:
			dir = v.normalized()
	for k in recharges:
		recharges[k] = maxf(0.0, recharges[k] - dt)
	invulnerable = maxf(0.0, invulnerable - dt)
	var vit := VITESSE * Partie.vitesse()
	velocity.x = dir.x * vit
	velocity.z = dir.z * vit
	if _dash_t > 0.0:
		_dash_t -= dt
		velocity.x = _dash.x
		velocity.z = _dash.z
	velocity.y = -2.0 if is_on_floor() else velocity.y - 30.0 * dt
	move_and_slide()

	if dir.length() > 0.1 and is_on_wall():
		_monter_marche(dir)
	_anim_coup -= dt
	if dir.length() > 0.1:
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(dir.x, dir.z), minf(1.0, dt * 14.0))
		if _anim_coup <= 0.0:
			Modele.jouer(_ap, "Run", 1.05 * Partie.vitesse())
	elif en_combat and distance <= PORTEE + 0.3:
		var v2 := cible.global_position - global_position
		_corps.rotation.y = lerp_angle(_corps.rotation.y, atan2(v2.x, v2.z), minf(1.0, dt * 16.0))
		_coup_t -= dt
		if _coup_t <= 0.0:
			_coup_t = CADENCE
			if not (Partie.auto_attaque and cible.en_parade()):
				_frapper()
	elif _anim_coup <= 0.0:
		Modele.jouer(_ap, "SwordIdle" if en_combat else "Idle")

const MARCHE_MAX := 0.45
func _monter_marche(dir: Vector3) -> void:
	var haut := Vector3(0, MARCHE_MAX, 0)
	var avance := dir.normalized() * 0.3
	var t := global_transform
	if test_move(t, haut):
		return
	t = t.translated(haut)
	if test_move(t, avance):
		return
	t = t.translated(avance)

	var col := KinematicCollision3D.new()
	if test_move(t, Vector3(0, -MARCHE_MAX - 0.05, 0), col):
		t.origin.y -= col.get_travel().length()
	global_transform = t

func _frapper() -> void:
	_coup_n = (_coup_n + 1) % 3
	var anim: String = ["Slash1", "Slash2", "Slash3"][_coup_n]
	_dernier_coup = Time.get_ticks_msec()
	_anim_coup = Modele.jouer(_ap, anim, 1.9, 0.06) * 0.9
	Fx.son(["swing1", "swing2", "swing3"][_coup_n], -4.0, randf_range(0.95, 1.08))
	var c := cible
	await get_tree().create_timer(0.16).timeout
	if c == null or not is_instance_valid(c) or c.mort:
		return
	var crit := randf() < Partie.chance_crit()
	var deg := Partie.dps_joueur() * CADENCE * (2.0 if crit else 1.0) * randf_range(0.9, 1.1)
	c.frapper(deg, crit)
	Fx.son(["hit1", "hit2", "hit3"][randi() % 3], -2.0 if crit else -5.0)


func competence(k: String) -> String:
	var d: Dictionary = Partie.COMPETENCES[k]
	if k == "domaine":
		if Partie.domaine_actif():
			return "Domaine déjà actif"
		if Partie.charge < 100.0:
			return "Domaine chargé à %d %% — tue des monstres" % int(Partie.charge)
		Partie.charge = 0.0
		Partie.domaine_fin = Partie.temps() + Partie.DUREE_DOMAINE
		Fx.son("arise", 0.0, 0.6)
		Fx.son("portal", -2.0, 0.7)
		Fx.anneau(global_position, Color(0.45, 0.1, 0.9), 14.0)
		Fx.texte(global_position + Vector3(0, 3.2, 0), "DOMAINE DU MONARQUE", Color(0.75, 0.45, 1.0), 2.0, 2.0)
		var v := get_tree().get_first_node_in_group("ville")
		if v:
			v.hud.domaine(Partie.DUREE_DOMAINE)
		return ""
	if recharges[k] > 0.0:
		return "Recharge : %.1f s" % recharges[k]
	if Partie.mana < d["mana"]:
		return "Pas assez de mana (%d)" % int(d["mana"])
	var c := cible
	if k == "brise":
		if c == null or not is_instance_valid(c) or c.mort:
			return "Aucune cible"
		var v := c.global_position - global_position
		v.y = 0
		if v.length() - c.haut() * 0.25 > PORTEE + 1.2:
			return "Trop loin"
	Partie.depenser_mana(d["mana"])
	recharges[k] = d["cd"]
	match k:
		"esquive":
			var dir := Vector3.ZERO
			if entree.length() < 0.2:
				dir = -_corps.global_transform.basis.z
			else:
				var b := Basis(Vector3.UP, camera_lacet)
				dir = b * Vector3(entree.x, 0, -entree.y)
			dir.y = 0
			_dash = dir.normalized() * 24.0
			_dash_t = 0.22
			invulnerable = 0.45
			cible = null
			Modele.jouer(_ap, "Roll" if _ap and _ap.has_animation("Roll") else "Run", 1.6, 0.05)
			_anim_coup = 0.3
			Fx.son("swing2", -2.0, 1.3)
			Fx.anneau(global_position, Color(0.5, 1.0, 0.85), 1.4)
		"brise":
			_anim_coup = Modele.jouer(_ap, "Slash3", 1.4, 0.05) * 0.9
			Fx.son("slam", -2.0)
			_brise_differe(c)
		"cri":
			Partie.cri_fin = Partie.temps() + Partie.DUREE_CRI
			Fx.son("arise", -2.0, 0.8)
			Fx.anneau(global_position, Color(0.65, 0.3, 1.0), 7.0)
			Fx.texte(global_position + Vector3(0, 2.8, 0), "CRI DU MONARQUE", Color(0.8, 0.55, 1.0), 1.5, 1.4)
	return ""

var _aura_anos: Array = []

func aura_anos(on: bool) -> void:
	for n in _aura_anos:
		if is_instance_valid(n):
			n.queue_free()
	_aura_anos.clear()
	for mi in _corps.find_children("*", "MeshInstance3D", true, false):
		(mi as MeshInstance3D).material_overlay = Shaders.halo(Color(0.9, 0.05, 0.12), 2.6) if on else null
	if on:
		var l := OmniLight3D.new()
		l.light_color = Color(1.0, 0.1, 0.15)
		l.light_energy = 2.5
		l.omni_range = 6.0
		l.position = Vector3(0, 1.4, 0)
		add_child(l)
		_aura_anos.append(l)
		var p := _etincelles(Color(1.0, 0.15, 0.2))
		p.amount = 40
		p.position = Vector3(0, 1.0, 0)
		add_child(p)
		_aura_anos.append(p)

func _brise_differe(cc: Monstre) -> void:
	await get_tree().create_timer(0.3).timeout
	if is_instance_valid(cc) and not cc.mort:
		cc.briser(Partie.dps_joueur() * CADENCE * 4.0)

func _etincelles(c: Color) -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 18
	p.lifetime = 0.9
	p.local_coords = false
	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	pm.emission_box_extents = Vector3(0.03, 0.45, 0.03)
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 180.0
	pm.initial_velocity_min = 0.1
	pm.initial_velocity_max = 0.5
	pm.gravity = Vector3(0, 0.4, 0)
	pm.scale_min = 0.5
	pm.scale_max = 1.0
	var g := Gradient.new()
	g.set_color(0, Color(c.r, c.g, c.b, 1.0))
	g.set_color(1, Color(c.r, c.g, c.b, 0.0))
	var gt := GradientTexture1D.new()
	gt.gradient = g
	pm.color_ramp = gt
	p.process_material = pm
	var q := QuadMesh.new()
	q.size = Vector2(0.06, 0.06)
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
	m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	m.vertex_color_use_as_albedo = true
	m.albedo_texture = load("res://assets/fx/etincelle.png")
	q.material = m
	p.draw_pass_1 = q
	p.position = Vector3(0, 0.55, 0)
	return p
