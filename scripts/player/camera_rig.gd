class_name CameraRig
extends Node3D
## Caméra 3e personne équilibrée : assez proche pour profiter du perso, assez haute pour voir le pays.
## Bras à ressort contre le sol et les murs (jamais à travers), suivi fluide, recentrage doux.

var target: Node3D
var yaw := 0.0
var pitch := deg_to_rad(-24.0)
var dist := 8.0
var dist_goal := 8.0
var min_dist := 4.5
var max_dist := 13.0
var _last_manual := -10.0
var inside := false      # dans un bâtiment : distance réduite
var arm: SpringArm3D
var cam: Camera3D
var _focus := Vector3.ZERO

func _ready() -> void:
	arm = SpringArm3D.new()
	arm.collision_mask = 1 | 2   # sol + bâtiments (pas les feuillages)
	var sph := SphereShape3D.new()
	sph.radius = 0.35
	arm.shape = sph
	arm.margin = 0.2
	add_child(arm)
	cam = Camera3D.new()
	cam.fov = 62.0
	cam.near = 0.15
	cam.far = 300.0
	arm.add_child(cam)
	cam.current = true
	if target:
		_focus = target.global_position + Vector3.UP * 1.45
		global_position = _focus
		yaw = target.rotation.y + PI

func rotate_by(dx: float, dy: float) -> void:
	yaw -= dx * 0.006
	pitch = clampf(pitch - dy * 0.004, deg_to_rad(-62), deg_to_rad(-6))
	_last_manual = Time.get_ticks_msec() / 1000.0

var _shake := 0.0

func shake(a: float) -> void:
	_shake = maxf(_shake, a)

## Plan de cinéma : une caméra À PART (jamais sous le bras-ressort, donc aucun tremblement)
## vient cadrer la scène en douceur ; à la fin elle rejoint la caméra de jeu puis lui rend la main.
var cine := false
var ccam: Camera3D
var _cine_pos := Vector3.ZERO
var _cine_look := Vector3.ZERO
var _cine_back := 0.0
func cine_on(pos: Vector3, look: Vector3) -> void:
	if ccam == null:
		ccam = Camera3D.new()
		ccam.fov = cam.fov
		ccam.near = cam.near
		ccam.far = cam.far
		get_tree().current_scene.add_child(ccam)
	if not cine and _cine_back <= 0.0:
		ccam.global_transform = cam.global_transform
	cine = true
	_cine_back = 0.0
	_cine_pos = pos
	_cine_look = look
	ccam.current = true
func cine_off() -> void:
	if cine:
		cine = false
		_cine_back = 0.6

## Cadrage « par-dessus l'épaule » du héros vers un interlocuteur, toujours du côté où se trouve déjà
## la caméra de jeu (pas de retournement brusque)
func frame_talk(hero: Node3D, other: Node3D, wide := false) -> void:
	var a := hero.global_position + Vector3.UP * 1.55
	var b := other.global_position + Vector3.UP * 1.55
	var d := b - a
	d.y = 0.0
	if d.length() < 0.2:
		return
	d = d.normalized()
	var right := d.cross(Vector3.UP).normalized()
	if right.dot(cam.global_position - a) < 0.0:
		right = -right
	var back := 3.2 if wide else 1.9
	cine_on(a - d * back + right * (1.3 if wide else 0.85) + Vector3.UP * (0.8 if wide else 0.25), b + Vector3.DOWN * (0.3 if wide else 0.1))

func zoom_by(f: float) -> void:
	dist_goal = clampf(dist_goal * f, min_dist, max_dist)

func _process(delta: float) -> void:
	if target == null:
		return
	if cine:
		var want_t := Transform3D(Basis(), _cine_pos).looking_at(_cine_look, Vector3.UP)
		ccam.global_transform = ccam.global_transform.interpolate_with(want_t, clampf(delta * 4.0, 0.0, 1.0))
	elif _cine_back > 0.0 and ccam:
		_cine_back -= delta
		ccam.global_transform = ccam.global_transform.interpolate_with(cam.global_transform, clampf(delta * 7.0, 0.0, 1.0))
		if _cine_back <= 0.0:
			cam.current = true
	var want := target.global_position + Vector3.UP * 1.45
	_focus = _focus.lerp(want, clampf(delta * 10.0, 0, 1))
	global_position = _focus
	# recentrage doux derrière le perso quand il avance et qu'on ne touche pas la caméra
	var now := Time.get_ticks_msec() / 1000.0
	var v: Vector3 = target.velocity if target is CharacterBody3D else Vector3.ZERO
	var hv := Vector2(v.x, v.z)
	if now - _last_manual > 2.5 and hv.length() > 2.0:
		var behind := atan2(hv.x, hv.y) + PI
		yaw = lerp_angle(yaw, behind, clampf(delta * 0.6, 0, 1))
	var lim := 6.5 if inside else max_dist
	var d := minf(dist_goal, lim)
	dist = lerpf(dist, d, clampf(delta * 4.0, 0, 1))
	rotation = Vector3(pitch, yaw, 0)
	arm.spring_length = dist
	if _shake > 0.0:
		_shake = maxf(0.0, _shake - delta * 1.8)
		cam.h_offset = randf_range(-1, 1) * _shake * 0.35
		cam.v_offset = randf_range(-1, 1) * _shake * 0.35
	else:
		cam.h_offset = 0.0
		cam.v_offset = 0.0
	# empêcher la caméra de passer sous le terrain
	var cp := cam.global_position
	var gh := Terrain.height_at(cp.x, cp.z) + 0.6
	if cp.y < gh and not inside:
		pitch = lerpf(pitch, pitch - 0.02, 0.5)
