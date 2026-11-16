extends Node
## Projectile : avance, gravité si lancé, touche le premier ennemi proche.
var w; var src; var v: Vector3; var act: Array; var kind: String; var col: Color; var t := 0.0
func init(world, a, vel: Vector3, ac: Array, k: String, c: Color) -> void:
	w = world; src = a; v = vel; act = ac; kind = k; col = c
func _physics_process(dt: float) -> void:
	var mi: Node3D = get_parent(); t += dt
	if kind in ["rock", "bomb"]: v.y -= 14.0 * dt
	mi.global_position += v * dt
	var hit = null
	for o in w.actors:
		if o != src and o.team != src.team and o.state != "dead" and (o.global_position + Vector3.UP).distance_to(mi.global_position) < 0.8: hit = o
	if hit or mi.global_position.y < 0.05 or t > 1.6:
		if kind == "bomb":
			w.ring(mi.global_position, 3.0, col); w.shake(0.2)
			for o in w.actors:
				if o.team != src.team and o.state != "dead" and o.global_position.distance_to(mi.global_position) < 3.0: o.hurt(act[1], mi.global_position, act[4])
		elif hit: hit.hurt(act[1], src.global_position, act[4]); w.sfx("hit", mi.global_position)
		w.burst(mi.global_position, col, 14)
		mi.queue_free()
