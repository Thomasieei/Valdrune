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
var charge := 0.0
var _fx: Node3D

func _ready() -> void:
	_fx = FX.fireball()
	add_child(_fx)
	_fx.scale = Vector3.ONE * (1.0 + 1.3 * charge)
	speed = 24.0 - 6.0 * charge

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
	if charge >= 0.5:
		FX.shockwave(Vector3(global_position.x, Terrain.height_at(global_position.x, global_position.z), global_position.z), splash)
	Sfx.play("lourd", -3.0 + 4.0 * charge)
	var hits := 0
	for m in Combat.in_radius(global_position, splash):
		var dmg := damage if m == direct else damage * 0.5
		m.cbt.take_damage(dmg, source, "feu")
		hits += 1
		# souffle de l'explosion : repousse d'autant plus que le sort était chargé
		var dv: Vector3 = m.global_position - global_position
		dv.y = 0
		if dv.length() > 0.05:
			m.knockback(dv.normalized() * (2.0 + 8.0 * charge))
	if hits > 0:
		FX.hitstop(0.03 + 0.08 * charge)
		if source and source.has_method("shake"):
			source.shake(0.15 + 0.35 * charge)
	queue_free()
