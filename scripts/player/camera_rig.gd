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
	cam.far = 420.0
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

func zoom_by(f: float) -> void:
	dist_goal = clampf(dist_goal * f, min_dist, max_dist)

func _process(delta: float) -> void:
	if target == null:
		return
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
	# empêcher la caméra de passer sous le terrain
	var cp := cam.global_position
	var gh := Terrain.height_at(cp.x, cp.z) + 0.6
	if cp.y < gh and not inside:
		pitch = lerpf(pitch, pitch - 0.02, 0.5)
