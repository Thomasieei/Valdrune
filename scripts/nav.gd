class_name Nav
extends Node
## Navigation : maillage navigable calculé en tâche de fond à partir des collisions du décor
## (ville, salles de donjon). Les PNJ et monstres suivent des chemins au lieu de foncer
## en ligne droite dans les murs, et tout déplacement « téléporté » est ramené sur un sol valide.

var main
var map: RID
var regions := {}        # nom -> NavigationRegion3D
var ready := {}          # nom -> bool
var bounds := {}         # nom -> AABB (globale)
var seeds_of := {}       # nom -> points de départ (on ne garde que la zone reliée à ces points)

func setup(m) -> void:
	main = m
	map = m.get_world_3d().navigation_map

func _make_mesh() -> NavigationMesh:
	var nm := NavigationMesh.new()
	nm.cell_size = NavigationServer3D.map_get_cell_size(map)
	nm.cell_height = NavigationServer3D.map_get_cell_height(map)
	nm.agent_radius = 0.45
	nm.agent_height = 1.6
	nm.agent_max_climb = 0.5
	nm.agent_max_slope = 46.0
	nm.region_min_size = 6.0
	nm.geometry_parsed_geometry_type = NavigationMesh.PARSED_GEOMETRY_STATIC_COLLIDERS
	nm.geometry_collision_mask = 1
	return nm

## source : nœud racine dont les collisions sont analysées (repère sans échelle) ; zone : AABB globale.
func bake(nm_name: String, source: Node3D, zone: AABB, seeds: Array) -> void:
	ready[nm_name] = false
	seeds_of[nm_name] = seeds
	bounds[nm_name] = zone
	var nm := _make_mesh()
	var inv := source.global_transform.affine_inverse()
	nm.filter_baking_aabb = inv * zone
	var src := NavigationMeshSourceGeometryData3D.new()
	var t0 := Time.get_ticks_msec()
	NavigationServer3D.parse_source_geometry_data(nm, src, source)
	print("NAV_PARSE %s %d ms" % [nm_name, Time.get_ticks_msec() - t0])
	var reg: NavigationRegion3D = regions.get(nm_name)
	if reg == null or not is_instance_valid(reg):
		reg = NavigationRegion3D.new()
		source.add_child(reg)
		regions[nm_name] = reg
	var t1 := Time.get_ticks_msec()
	NavigationServer3D.bake_from_source_geometry_data_async(nm, src, _on_baked.bind(nm_name, nm, t1))

func _on_baked(nm_name: String, nm: NavigationMesh, t1: int) -> void:
	call_deferred("_apply", nm_name, nm, t1)

func _apply(nm_name: String, nm: NavigationMesh, t1: int) -> void:
	var reg: NavigationRegion3D = regions.get(nm_name)
	if reg == null or not is_instance_valid(reg):
		return
	var before := nm.get_polygon_count()
	var seeds: Array = seeds_of.get(nm_name, [])
	if not seeds.is_empty():
		_keep_connected(nm, reg.global_transform.affine_inverse(), seeds)
	reg.navigation_mesh = nm
	ready[nm_name] = true
	print("NAV_READY %s polygones=%d (sur %d, îlots retirés) en %d ms" % [nm_name, nm.get_polygon_count(), before, Time.get_ticks_msec() - t1])

## Retire les îlots isolés (toits, intérieurs fermés de bâtiments) : on ne garde que
## les polygones reliés aux points de départ (rue du point d'apparition, entrée d'une salle).
func _keep_connected(nm: NavigationMesh, inv: Transform3D, seeds: Array) -> void:
	var verts := nm.get_vertices()
	var n := nm.get_polygon_count()
	if n == 0:
		return
	var polys: Array = []
	var edge_map := {}
	var cent: Array = []
	for i in n:
		var p: PackedInt32Array = nm.get_polygon(i)
		polys.append(p)
		var c := Vector3.ZERO
		for k in p.size():
			c += verts[p[k]]
			var a: int = p[k]
			var b: int = p[(k + 1) % p.size()]
			var key := Vector2i(mini(a, b), maxi(a, b))
			if not edge_map.has(key):
				edge_map[key] = []
			(edge_map[key] as Array).append(i)
		cent.append(c / p.size())
	var keep := {}
	var queue: Array = []
	for s in seeds:
		var sp: Vector3 = inv * (s as Vector3)
		var best := -1
		var bd := 1e18
		for i in n:
			var d := (cent[i] as Vector3).distance_squared_to(sp)
			if d < bd:
				bd = d
				best = i
		if best >= 0 and not keep.has(best):
			keep[best] = true
			queue.append(best)
	var qi := 0
	while qi < queue.size():
		var i: int = queue[qi]
		qi += 1
		var p: PackedInt32Array = polys[i]
		for k in p.size():
			var a: int = p[k]
			var b: int = p[(k + 1) % p.size()]
			for j in edge_map[Vector2i(mini(a, b), maxi(a, b))]:
				if not keep.has(j):
					keep[j] = true
					queue.append(j)
	nm.clear_polygons()
	for i in n:
		if keep.has(i):
			nm.add_polygon(polys[i])

func drop(nm_name: String) -> void:
	var reg: NavigationRegion3D = regions.get(nm_name)
	if reg and is_instance_valid(reg):
		reg.queue_free()
	regions.erase(nm_name)
	ready.erase(nm_name)
	bounds.erase(nm_name)

## Un maillage prêt couvre-t-il ce point ?
func covers(p: Vector3) -> bool:
	for k in ready.keys():
		if ready[k] and (bounds[k] as AABB).grow(2.0).has_point(p):
			return true
	return false

func closest(p: Vector3) -> Vector3:
	return NavigationServer3D.map_get_closest_point(map, p)

func path(a: Vector3, b: Vector3) -> PackedVector3Array:
	return NavigationServer3D.map_get_path(map, a, b, true)
