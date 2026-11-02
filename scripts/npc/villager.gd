class_name Villager
extends Node3D
## Habitant : occupé à une activité sur place, ou marchant sur un trajet au sol.

var spec := {}
var anim_name := "Idle"
var path: Array = []      # points Vector2 (x, z)
var speed := 1.35
var work_anim := ""        # animation de travail à l'arrivée (champs, bûcheronnage)
var _i := 0
var _ap: AnimationPlayer
var _cur := ""
var _wait := 0.0

func _ready() -> void:
	var m := CharBuilder.build(spec)
	add_child(m)
	_ap = m.get_node("AnimationPlayer")
	if path.size() > 0:
		var p: Vector2 = path[0]
		position = Vector3(p.x, Terrain.height_at(p.x, p.y), p.y)
		_play("Walk")
	else:
		_play(anim_name)
		_ap.seek(randf() * 3.0, true)

func _play(a: String) -> void:
	if not _ap.has_animation(a):
		a = "Idle"
	if a != _cur:
		_cur = a
		_ap.play(a, 0.3)

func _process(delta: float) -> void:
	if path.size() < 2:
		return
	if _wait > 0.0:
		_wait -= delta
		return
	var t: Vector2 = path[_i]
	var here := Vector2(position.x, position.z)
	var to := t - here
	if to.length() < 0.4:
		_i = (_i + 1) % path.size()
		if work_anim != "":
			_play(work_anim)
			_wait = randf_range(6.0, 12.0)
		else:
			_play("Idle")
			_wait = randf_range(1.5, 4.0)
		return
	_play("Walk")
	var d := to.normalized()
	here += d * speed * delta
	position = Vector3(here.x, Terrain.height_at(here.x, here.y), here.y)
	rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), clampf(delta * 6.0, 0, 1))
