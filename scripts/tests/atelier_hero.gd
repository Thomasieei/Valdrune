extends Node3D
# Atelier autonome utilisant le vrai Joueur et ses vrais clips, sans ville ni IA.
# Test reproductible : 224 images, phases / transitions / vitesse / traces.
const TOTAL := 224
const SORTIE := "/tmp/caps_hero"

var monstres: Array = []
var _hero: Joueur
var _camera: Camera3D
var _info: Label
var _etape := ""
var _derniere_anim := ""
var _transitions := 0
var _vides := 0
var _vitesse_max := 0.0
var _fichier: FileAccess

func action_proche() -> Dictionary:
	return {}

func _ready() -> void:
	Partie.auto_attaque = false
	Partie.opts["monarque"] = false
	Partie.opts["fourreau"] = false
	Partie.opts["arise"] = false
	_construire()
	call_deferred("_filmer")

func _construire() -> void:
	var sol := StaticBody3D.new()
	sol.name = "Plateau"
	var boite := BoxMesh.new()
	boite.size = Vector3(90.0, 0.3, 90.0)
	var geom := MeshInstance3D.new()
	geom.mesh = boite
	var mat := StandardMaterial3D.new()
	mat.albedo_color = Color(0.30, 0.35, 0.42)
	mat.roughness = 0.88
	geom.material_override = mat
	sol.add_child(geom)
	var collision := CollisionShape3D.new()
	var forme := BoxShape3D.new()
	forme.size = boite.size
	collision.shape = forme
	sol.add_child(collision)
	sol.position.y = -0.16
	add_child(sol)

	# Reperes au sol pour juger le glissement des pieds.
	for k in range(-7, 8):
		var ligne := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		mesh.size = Vector3(16.0, 0.012, 0.025)
		ligne.mesh = mesh
		var peau := StandardMaterial3D.new()
		peau.albedo_color = Color(0.48, 0.54, 0.61)
		peau.roughness = 1.0
		ligne.material_override = peau
		ligne.position = Vector3(0.0, 0.008, float(k) * 2.0)
		add_child(ligne)

	var env_node := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.095, 0.12, 0.17)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.85, 0.90, 1.0)
	env.ambient_light_energy = 0.85
	env_node.environment = env
	add_child(env_node)

	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-48.0, -35.0, 0.0)
	sun.light_energy = 1.5
	sun.shadow_enabled = false
	add_child(sun)

	_hero = Joueur.new()
	_hero.name = "VraiHero"
	add_child(_hero)
	_hero.position = Vector3(0.0, 0.03, 0.0)
	_hero.camera_lacet = 0.0
	_hero.invulnerable = 600.0
	_hero._repos_geste_t = 999.0

	_camera = Camera3D.new()
	_camera.name = "CameraProche"
	_camera.fov = 45.0
	_camera.current = true
	add_child(_camera)
	_camera.global_position = _hero.global_position + Vector3(2.4, 2.35, 4.7)
	_camera.look_at(_hero.global_position + Vector3(0.0, 1.06, 0.0))

	var calque := CanvasLayer.new()
	add_child(calque)
	_info = Label.new()
	_info.position = Vector2(25, 20)
	_info.add_theme_font_size_override("font_size", 22)
	_info.add_theme_color_override("font_color", Color(0.95, 0.95, 1.0))
	calque.add_child(_info)

func _process(dt: float) -> void:
	if _hero == null:
		return
	var cible := _hero.global_position + Vector3(2.4, 2.35, 4.7)
	_camera.global_position = _camera.global_position.lerp(cible, 1.0 - exp(-12.0 * dt))
	_camera.look_at(_hero.global_position + Vector3(0.0, 1.06, 0.0))

func _phase(i: int) -> String:
	if i < 16: return "REPOS"
	if i < 38: return "MARCHE"
	if i < 58: return "COURSE"
	if i < 82: return "SPRINT"
	if i < 95: return "ARRET"
	if i < 113: return "VIRAGE DROIT"
	if i < 129: return "VIRAGE GAUCHE"
	if i < 144: return "ARRET"
	if i < 161: return "ATTAQUE 1"
	if i < 178: return "ATTAQUE 2"
	if i < 195: return "ATTAQUE 3"
	if i < 208: return "IMPACT"
	return "REPOS FINAL"

func _entree(phase: String) -> Vector2:
	match phase:
		"MARCHE": return Vector2(0.0, 0.34)
		"COURSE": return Vector2(0.0, 0.82)
		"SPRINT": return Vector2(0.0, 1.0)
		"VIRAGE DROIT": return Vector2(0.85, 0.48)
		"VIRAGE GAUCHE": return Vector2(-0.80, 0.44)
	return Vector2.ZERO

func _filmer() -> void:
	DirAccess.make_dir_recursive_absolute(SORTIE)
	await get_tree().create_timer(0.6).timeout
	print("[HERO] laboratoire seul, fichiers=", TOTAL, " clips=", _hero._ap.get_animation_list())
	var dernier := ""
	for i in range(TOTAL):
		var phase := _phase(i)
		if phase != dernier:
			dernier = phase
			print("[HERO][PHASE] ", i, " ", phase)
		_hero.entree = _entree(phase)
		if i == 144 or i == 161 or i == 178:
			_hero._frapper()
		if i == 195:
			_hero.mouvement_visuel = _hero.Mouvement.IMPACT
			_hero._anim_coup = Modele.jouer(_hero._ap, "Hit", 1.4, 0.12)
		# Sur un runner logiciel lent, ralentit la simulation pour ne pas
		# accelerer artificiellement les mouvements lors du montage 30 i/s.
		if i % 12 == 0:
			Engine.time_scale = clampf(float(Engine.get_frames_per_second()) / 30.0, 0.06, 1.0)
		await get_tree().create_timer(1.0 / 30.0, true, false, true).timeout
		await RenderingServer.frame_post_draw
		var clip: String = _hero._ap.current_animation
		if clip != _derniere_anim:
			_transitions += 1
			print("[HERO][CLIP] ", i, " ", _derniere_anim, " -> ", clip)
			_derniere_anim = clip
		if clip == "":
			_vides += 1
		var vitesse := Vector2(_hero.velocity.x, _hero.velocity.z).length()
		_vitesse_max = maxf(_vitesse_max, vitesse)
		_info.text = "ARISE VILLE | HERO STUDIO\n%s   |   %s   |   %.1f m/s" % [phase, clip, vitesse]
		var image_capture := get_viewport().get_texture().get_image()
		var chemin := "%s/hero_%04d.png" % [SORTIE, i]
		var erreur := image_capture.save_png(chemin)
		if erreur != OK:
			push_error("Capture echouee: " + chemin)
			get_tree().quit(1)
			return
		if i % 30 == 0:
			print("[HERO][FRAME] ", i, "/", TOTAL, " ", clip, " vitesse=", snappedf(vitesse, 0.01), " fps_runner=", Engine.get_frames_per_second())
	_hero.entree = Vector2.ZERO
	Engine.time_scale = 1.0
	print("[HERO][SUMMARY] images=", TOTAL, " changes=", _transitions, " empty_clips=", _vides, " vmax=", snappedf(_vitesse_max, 0.01))
	get_tree().quit(0 if _vides == 0 else 3)
