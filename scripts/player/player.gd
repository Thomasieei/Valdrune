class_name Player
extends CharacterBody3D
## Le seigneur : déplacement relatif à la caméra, marche/course selon le joystick, animations UAL,
## épée en main, et actions de combat (attaques, esquive, sorts) jouées par-dessus la locomotion.

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
var cbt: Combatant
var combat: PlayerCombat
var rig: Node = null
var last_hurt := -100.0
var _cur := ""
var _action_until := 0.0
var gravity: float = ProjectSettings.get_setting("physics/3d/default_gravity", 9.8)

func _ready() -> void:
	collision_layer = 8
	collision_mask = 1 | 2 | 4 | 16
	floor_max_angle = deg_to_rad(48)
	floor_snap_length = 0.6
	platform_floor_layers = 1 | 2      # ne jamais « chevaucher » une créature comme une plateforme
	var aura := HeroAura.new()
	aura.name = "Aura"
	add_child(aura)
	var cs := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.35
	cap.height = 1.8
	cs.shape = cap
	cs.position.y = 0.9
	add_child(cs)
	model = CharBuilder.build({"hero": true, "outfit": "rodeur_h", "skin_light": true, "tint": Color(0.82, 0.88, 1.0)})
	add_child(model)
	anim = model.get_node("AnimationPlayer")
	# épée dans la main droite
	var skel: Skeleton3D = model.get_node("Armature/Skeleton3D")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	var sword := Kit.dungeon(att, "Sword", Vector3.ZERO, 0.0, 1.15)
	sword.rotation_degrees = Vector3(-90, 0, 0)
	cbt = Combatant.new()
	cbt.team = "joueur"
	cbt.display_name = "Seigneur"
	add_child(cbt)
	cbt.damaged.connect(func(_a, _s): last_hurt = Time.get_ticks_msec() / 1000.0)
	combat = PlayerCombat.new()
	add_child(combat)
	combat.setup(self)
	Combat.player = self
	_play("Idle")

func _play(a: String, blend := 0.2, speed := 1.0) -> void:
	if a == _cur:
		anim.speed_scale = speed
		return
	_cur = a
	anim.play(a, blend)
	anim.speed_scale = speed

## Action de combat : joue une animation pour une durée donnée, la locomotion reprend ensuite.
func action(a: String, duration: float, speed := 1.0) -> void:
	_action_until = Time.get_ticks_msec() / 1000.0 + duration
	_cur = a
	anim.play(a, 0.08)
	anim.seek(0.0, true)
	anim.speed_scale = speed

func end_action() -> void:
	_action_until = 0.0
	_cur = ""

func forward() -> Vector3:
	return Vector3(sin(rotation.y), 0, cos(rotation.y))

func move_dir() -> Vector3:
	var dir := Vector3(input_dir.x, 0, input_dir.y).rotated(Vector3.UP, cam_yaw)
	return dir if dir.length() > 0.1 else Vector3.ZERO

func shake(amount: float) -> void:
	if rig and rig.has_method("shake"):
		rig.shake(amount)

func _over_bridge() -> bool:
	return global_position.y > Terrain.height_at(global_position.x, global_position.z) + 0.6

func _physics_process(delta: float) -> void:
	var t := Time.get_ticks_msec() / 1000.0
	var dir := Vector3(input_dir.x, 0, input_dir.y)
	var mag := minf(dir.length(), 1.0)
	dir = dir.rotated(Vector3.UP, cam_yaw)
	if dir.length() > 0.001:
		dir = dir.normalized()
	var target_speed := 0.0
	if mag > 0.08 and not cbt.dead:
		target_speed = lerpf(WALK, RUN, smoothstep(0.45, 0.9, mag))
		if sprint:
			target_speed = SPRINT
	target_speed *= combat.move_scale() * cbt.speed_mult()
	var hv := Vector3(velocity.x, 0, velocity.z)
	hv = hv.lerp(dir * target_speed, clampf(ACCEL * delta, 0, 1))
	var dv := combat.dodge_velocity()
	if dv != Vector3.INF:
		hv = dv
	# eau profonde : on ne s'y aventure pas (on peut patauger au bord)
	var ahead := global_position + hv.normalized() * 0.8
	if hv.length() > 0.1 and Terrain.height_at(ahead.x, ahead.z) < Layout.WATER - 0.7 and not _over_bridge():
		hv = Vector3.ZERO
	velocity.x = hv.x
	velocity.z = hv.z
	if not is_on_floor():
		velocity.y -= gravity * delta
	else:
		velocity.y = -0.5
	move_and_slide()
	var acting := t < _action_until
	if hv.length() > 0.3 and dv == Vector3.INF and combat.move_scale() > 0.5:
		var target := atan2(hv.x, hv.z)
		rotation.y = lerp_angle(rotation.y, target, clampf(TURN * delta, 0, 1))
	if not acting and not cbt.dead:
		var sp := hv.length()
		if sp < 0.25:
			_play("Sword_Idle" if t - last_hurt < 8.0 or combat.target != null else "Idle")
		elif sp < 3.6:
			_play("Walk", 0.2, sp / 1.6)
		elif sp < 7.0:
			_play("Jog_Fwd", 0.2, sp / 4.6)
		else:
			_play("Sprint", 0.2, sp / 7.2)
	# sécurité : ne jamais tomber sous le sol
	var ground := Terrain.height_at(global_position.x, global_position.z)
	if global_position.y < ground - 2.0:
		global_position.y = ground + 0.5
		velocity = Vector3.ZERO
