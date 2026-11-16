extends Node
## Projectile : avance, gravité si lancé, touche le premier ennemi proche. Figé pendant l'arrêt du temps (sauf ceux du joueur).
var w; var src; var v: Vector3; var act: Array; var kind: String; var col: Color; var t := 0.0
func init(world, a, vel: Vector3, ac: Array, k: String, c: Color) -> void:
	w = world; src = a; v = vel; act = ac; kind = k; col = c
func _physics_process(dt: float) -> void:
	if not is_instance_valid(src): get_parent().queue_free(); return
	if w.tstop and src != w.player: return
	var mi: Node3D = get_parent(); t += dt
	if kind in ["rock", "bomb"]: v.y -= 14.0 * dt
	mi.global_position += v * dt
	var hit = null
	for o in w.actors:
		if src.foe(o) and (o.global_position + Vector3.UP).distance_to(mi.global_position) < 0.8: hit = o
	if hit or mi.global_position.y < 0.05 or t > 1.6:
		if kind == "bomb":
			w.ring(mi.global_position, 3.0, col); w.shake(0.2)
			for o in w.actors:
				if src.foe(o) and o.global_position.distance_to(mi.global_position) < 3.0: o.hurt(act[1] * src.dmg_mul, mi.global_position, act[4], src)
		elif hit: hit.hurt(act[1] * src.dmg_mul, src.global_position, act[4], src); w.sfx("hit", mi.global_position)
		w.burst(mi.global_position, col, 12)
		mi.queue_free()
