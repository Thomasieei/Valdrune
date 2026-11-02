class_name Combat
## Registre des créatures actives, requêtes de ciblage (portée, cône), et accès au joueur.

static var monsters: Array = []
static var player: Node3D
static var companion: Node3D
static var allies: Array = []     # soldats alliés (le compagnon est géré à part)

static func add_ally(n: Node3D) -> void:
	if not allies.has(n):
		allies.append(n)

static func remove_ally(n: Node3D) -> void:
	allies.erase(n)

## Tous les combattants du camp du joueur susceptibles d'être pris pour cible
static func friends() -> Array:
	var out := []
	if player and is_instance_valid(player) and not player.cbt.dead:
		out.append(player)
	if companion and is_instance_valid(companion) and companion.visible and not companion.cbt.dead:
		out.append(companion)
	for a in allies:
		if is_instance_valid(a) and a.visible and not a.cbt.dead:
			out.append(a)
	return out

static func register(m: Node3D) -> void:
	if not monsters.has(m):
		monsters.append(m)

static func unregister(m: Node3D) -> void:
	monsters.erase(m)

static func alive(m) -> bool:
	return is_instance_valid(m) and m.is_inside_tree() and m.visible and not m.cbt.dead

static func in_radius(pos: Vector3, r: float) -> Array:
	var out := []
	for m in monsters:
		if alive(m) and m.global_position.distance_to(pos) <= r:
			out.append(m)
	return out

## Ennemi le plus pertinent : dans le cône devant, sinon le plus proche.
static func best_target(pos: Vector3, forward: Vector3, max_dist: float, cone_deg := 70.0) -> Node3D:
	var best: Node3D = null
	var best_score := INF
	var f := Vector3(forward.x, 0, forward.z).normalized()
	for m in monsters:
		if not alive(m):
			continue
		var d: Vector3 = m.global_position - pos
		d.y = 0
		var dist := d.length()
		if dist > max_dist:
			continue
		var ang := rad_to_deg(f.angle_to(d.normalized())) if dist > 0.1 else 0.0
		var score := dist + (0.0 if ang < cone_deg else 25.0) + ang * 0.05
		if score < best_score:
			best_score = score
			best = m
	return best
