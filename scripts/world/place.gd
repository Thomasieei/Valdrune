class_name Place
## Placement sûr des personnages : vérifie qu'un point n'est pas dans un mur, une maison ou un objet du décor,
## sinon cherche la place libre la plus proche (spirale). Évite les PNJ « dans le décor ».

static var moved := 0

static func blocked(p: Vector3, r := 0.42) -> bool:
	var w := (Engine.get_main_loop() as SceneTree).current_scene as Node3D
	var space := w.get_world_3d().direct_space_state
	var q := PhysicsShapeQueryParameters3D.new()
	var sh := CapsuleShape3D.new()
	sh.radius = r
	sh.height = 1.5
	q.shape = sh
	q.transform = Transform3D(Basis(), p + Vector3.UP * 1.05)
	q.collision_mask = 2
	return space.intersect_shape(q, 1).size() > 0

## Point libre le plus proche (sur le sol), ou le point d'origine s'il est déjà libre
static func free_spot(p: Vector3, r := 0.42) -> Vector3:
	if not blocked(p, r):
		return p
	for ring in range(1, 12):
		var rad := ring * 0.6
		for k in 12:
			var a := TAU * k / 12.0 + ring * 0.3
			var q := p + Vector3(cos(a) * rad, 0, sin(a) * rad)
			q.y = Terrain.height_at(q.x, q.z) if p.y < Terrain.height_at(q.x, q.z) + 1.0 else p.y
			if Terrain.height_at(q.x, q.z) < Layout.WATER + 0.2:
				continue
			if not blocked(q, r):
				moved += 1
				return q
	return p

## Le chemin traverse-t-il un obstacle ? (rayon à hauteur de poitrine)
static func segment_clear(a: Vector3, b: Vector3) -> bool:
	var w := (Engine.get_main_loop() as SceneTree).current_scene as Node3D
	var space := w.get_world_3d().direct_space_state
	var q := PhysicsRayQueryParameters3D.create(a + Vector3.UP * 1.0, b + Vector3.UP * 1.0, 2)
	return space.intersect_ray(q).is_empty()

## Remet en place tous les PNJ statiques du monde et nettoie les trajets des passants
static func fix_all(tree: SceneTree) -> void:
	for n in tree.get_nodes_in_group("pnj"):
		if not (n is Node3D) or not n.is_inside_tree():
			continue
		if n is Villager and n.path.size() >= 2:
			var pts: Array = []
			for v in n.path:
				var q := free_spot(Vector3(v.x, Terrain.height_at(v.x, v.y), v.y))
				pts.append(Vector2(q.x, q.z))
			n.path = pts
			continue
		if n is Guard and n.patrol.size() >= 2:
			continue
		if n.has_meta("place_fixe"):
			continue   # assis sur un banc, derrière un comptoir : posé à la main, on n'y touche pas
		var fixed := free_spot(n.global_position)
		if fixed != n.global_position:
			n.global_position = fixed
