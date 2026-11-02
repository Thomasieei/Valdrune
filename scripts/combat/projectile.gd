class_name Projectile
extends Node3D
## Trait de feu : comète à tête chercheuse légère (suit la cible), explose au contact, au sol ou à bout de course.

var damage := 20.0
var splash := 2.0
var speed := 24.0
var source: Node3D
var target: Node3D
var dir := Vector3.FORWARD
var _life := 1.4
var _fx: Node3D

func _ready() -> void:
	_fx = FX.fireball()
	add_child(_fx)

func _process(delta: float) -> void:
	_life -= delta
	if target and Combat.alive(target):
		var aim := target.global_position + Vector3.UP * (1.0 * float(target.def["scale"])) - global_position
		dir = dir.lerp(aim.normalized(), clampf(delta * 8.0, 0, 1)).normalized()
	global_position += dir * speed * delta
	var gy := Terrain.height_at(global_position.x, global_position.z)
	var hit: Node3D = null
	for m in Combat.in_radius(global_position, 1.6):
		if absf(m.global_position.y + 0.9 - global_position.y) < 1.6:
			hit = m
			break
	if hit or global_position.y < gy + 0.1 or _life <= 0.0:
		_explode(hit)

func _explode(direct: Node3D) -> void:
	FX.explosion(global_position, splash)
	Sfx.play("lourd", -3.0)
	for m in Combat.in_radius(global_position, splash):
		var dmg := damage if m == direct else damage * 0.5
		m.cbt.take_damage(dmg, source, "magie")
	queue_free()
