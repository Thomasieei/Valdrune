class_name Farmer
extends Node3D
## Paysan : se rend à une parcelle et y fait le travail correspondant à son état
## (labourer, semer, arroser, récolter), puis change de parcelle.

var spec := {}
var plot_index := 0
var _ap: AnimationPlayer
var _cur := ""
var _target := Vector2.ZERO
var _work_left := 0.0
const SPEED := 1.4

func _ready() -> void:
	var m := CharBuilder.build(spec)
	add_child(m)
	_ap = m.get_node("AnimationPlayer")
	var plot: Dictionary = Fields.plots[plot_index]
	_target = _edge_point(plot)
	position = Vector3(_target.x, Terrain.height_at(_target.x, _target.y), _target.y)
	_work_left = randf_range(14.0, 22.0)

func _edge_point(plot: Dictionary) -> Vector2:
	var c: Vector2 = plot["c"]
	var s: Vector2 = plot["size"]
	return c + Vector2(randf_range(-s.x * 0.4, s.x * 0.4), randf_range(-s.y * 0.35, s.y * 0.35))

func _play(a: String) -> void:
	if not _ap.has_animation(a):
		a = "Idle"
	if a != _cur:
		_cur = a
		_ap.play(a, 0.3)

func _process(delta: float) -> void:
	var here := Vector2(position.x, position.z)
	var to := _target - here
	if to.length() > 0.4:
		_play("Walk")
		var d := to.normalized()
		here += d * SPEED * delta
		position = Vector3(here.x, Terrain.height_at(here.x, here.y), here.y)
		rotation.y = lerp_angle(rotation.y, atan2(d.x, d.y), clampf(delta * 6.0, 0, 1))
		return
	var plot: Dictionary = Fields.plots[plot_index]
	var s: int = plot["state"]
	match s:
		0: _play("Fixing_Kneeling")
		1: _play("b/Farm_PlantSeed")
		2: _play("b/Farm_Watering")
		_: _play("b/Farm_Harvest")
	_work_left -= delta
	if _work_left <= 0.0:
		plot_index = (plot_index + 1 + randi() % 3) % Fields.plots.size()
		_target = _edge_point(Fields.plots[plot_index])
		_work_left = randf_range(14.0, 22.0)
