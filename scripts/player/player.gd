class_name Player
extends CharacterBody3D
## Le seigneur : déplacement relatif à la caméra, marche/course selon le joystick, animations UAL.

const WALK := 2.6
const RUN := 6.2
const SPRINT := 8.0
const ACCEL := 12.0
const TURN := 11.0

var input_dir := Vector2.ZERO      # fourni par les commandes tactiles / clavier
var sprint := false
var cam_yaw := 0.0                  # fourni par la caméra
var model: Node3D
var anim: AnimationPlayer
var _cur := ""
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = 0.6
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = CharBuilder.build({"outfit": "rodeur_h", "skin_light": true, "tint": Color(0.82, 0.88, 1.0)})
	add_child(model)
	anim = model.get_node("AnimationPlayer")
	_play("Idle")

func _play(a: String, blend := 0.2, speed := 1.0) -> void:
	if a == _cur:
		anim.speed_scale = speed
		return
	_cur = a
	anim.play(a, blend)
	anim.speed_scale = speed

func _physics_process(delta: float) -> void:
	var dir := Vector3(input_dir.x, 0, input_dir.y)
	var mag := minf(dir.length(), 1.0)
	dir = dir.rotated(Vector3.UP, cam_yaw)
	if dir.length() > 0.001:
		dir = dir.normalized()
	var target_speed := 0.0
	if mag > 0.08:
		target_speed = lerpf(WALK, RUN, smoothstep(0.45, 0.9, mag))
		if sprint:
			target_speed = SPRINT
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * target_speed, clampf(ACCEL * delta, 0, 1))
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	if hv.length() > 0.3:
		var target := atan2(hv.x, hv.z)
		rotation.y = lerp_angle(rotation.y, target, clampf(TURN * delta, 0, 1))
	var sp := hv.length()
	if sp < 0.25:
		_play("Idle")
	elif sp < 3.6:
		_play("Walk", 0.2, sp / 1.6)
	elif sp < 7.0:
		_play("Jog_Fwd", 0.2, sp / 4.6)
	else:
		_play("Sprint", 0.2, sp / 7.2)
	# sécurité : ne jamais tomber sous le sol
	var ground := Layout.height(global_position.x, global_position.z)
	if global_position.y < ground - 2.0:
		global_position.y = ground + 0.5
		velocity = Vector3.ZERO
