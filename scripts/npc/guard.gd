class_name Guard
extends Node3D
## Garde royal : tenue de rôdeur aux couleurs du royaume, lance en main.
## Immobile à son poste, ou en patrouille sur un circuit.

var patrol: Array = []
var speed := 1.5
var _i := 0
var _ap: AnimationPlayer
var _cur := ""
var _spear: Node3D

func _ready() -> void:
	add_to_group("pnj")
	var m := CharBuilder.build({"outfit": "rodeur_h", "skin_light": randf() > 0.4, "tint": Color(0.55, 0.62, 0.95)})
	add_child(m)
	_ap = m.get_node("AnimationPlayer")
	var skel: Skeleton3D = m.get_node("Armature/Skeleton3D")
	var att := BoneAttachment3D.new()
	att.bone_name = "hand_r"
	skel.add_child(att)
	_spear = Kit.dungeon(att, "Spear", Vector3.ZERO, 0.0, 1.3)
	if patrol.size() > 0:
		position = patrol[0]
		_play("Walk")
	else:
		_play("Idle")
		_ap.seek(randf() * 2.0, true)

func _play(a: String) -> void:
	if a != _cur:
		_cur = a
		_ap.play(a, 0.25)

var _anim_until := 0.0

func react(a: String, dur: float) -> void:
	if not _ap.has_animation(a):
		return
	_cur = a
	_ap.play(a, 0.2)
	_anim_until = Time.get_ticks_msec() / 1000.0 + dur

func nod() -> void:
	react("b/Yes", 1.6)

func _process(delta: float) -> void:
	if _anim_until > 0.0 and Time.get_ticks_msec() / 1000.0 > _anim_until:
		_anim_until = 0.0
		_cur = ""
		_play("Walk" if patrol.size() >= 2 else "Idle")
	# lance toujours droite, tenue dans la main (suit la main, pas sa rotation)
	if _spear:
		_spear.global_basis = Basis(Vector3.UP, global_rotation.y).scaled(Vector3.ONE * 1.3)
		_spear.position = Vector3.ZERO
	if patrol.size() < 2:
		return
	var target: Vector3 = patrol[_i]
	var to := target - position
	to.y = 0
	if to.length() < 0.3:
		_i = (_i + 1) % patrol.size()
		return
	var dir := to.normalized()
	position += dir * speed * delta
	rotation.y = lerp_angle(rotation.y, atan2(dir.x, dir.z), clampf(delta * 6.0, 0, 1))
