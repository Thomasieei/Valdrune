extends Node
## Sonde de performance : coût de rendu par lieu (draw calls, objets, lumières, PNJ affichés)
var world
func _ready() -> void:
	while world.player == null or world.story == null:
		await get_tree().process_frame
	Frontier.quiet = true
	var spots := [["bourg", Layout.TOWN + Vector2(0, 25), 0.0], ["porte", Vector2(0, -70), 180.0], ["champs", Vector2(90, 0), 90.0],
		["repaire", CampParley.zone("camp_bandits")["pos"] + Vector2(0, 40), 180.0], ["foret", Vector2(-150, 0), 270.0], ["pont", Vector2(24, 50), 0.0]]
	for s in spots:
		var p: Player = world.player
		var q: Vector2 = s[1]
		p.global_position = Vector3(q.x, Terrain.height_at(q.x, q.y) + 0.3, q.y)
		world.rig.yaw = deg_to_rad(s[2])
		for i in 40:
			await get_tree().process_frame
		world._cull_npcs()
		for i in 5:
			await get_tree().process_frame
		var lights := 0
		for l in get_tree().root.find_children("*", "OmniLight3D", true, false):
			if l.is_visible_in_tree() and l.global_position.distance_to(p.global_position) < 60.0:
				lights += 1
		var npcs := get_tree().get_nodes_in_group("pnj").filter(func(n): return n.visible).size()
		print("PERF %-8s draws %5d  objets %5d  prims %8d  lumières<60m %2d  pnj %3d  monstres %2d  soldats %2d  cpu %.1f ms" % [s[0],
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME),
			RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME),
			lights, npcs, Combat.monsters.size(), Soldier.all.size(), Performance.get_monitor(Performance.TIME_PROCESS) * 1000.0])
		get_viewport().get_texture().get_image().save_png("res://shots/perf_%s.png" % s[0])
		if s[0] in ["foret", "bourg"]:
			_frustum(p.global_position)
	get_tree().quit()

## Répartition : instances affichées par groupe racine (distance, portée de visibilité, triangles)
func _breakdown(pp: Vector3) -> void:
	var groups := {}
	for gi in world.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree():
			continue
		var d: float = gi.global_position.distance_to(pp) if not (gi is MultiMeshInstance3D) else 0.0
		var vr: float = gi.visibility_range_end
		if vr > 0.0 and d > vr + 5.0 and not (gi is MultiMeshInstance3D):
			continue
		var top: Node = gi
		while top.get_parent() != world and top.get_parent() != null:
			top = top.get_parent()
		var k := String(top.name).left(24)
		var tris := 0
		if gi is MeshInstance3D and gi.mesh:
			for si in gi.mesh.get_surface_count():
				var arr = gi.mesh.surface_get_arrays(si)
				if arr[Mesh.ARRAY_INDEX] != null:
					tris += arr[Mesh.ARRAY_INDEX].size() / 3
				elif arr[Mesh.ARRAY_VERTEX] != null:
					tris += arr[Mesh.ARRAY_VERTEX].size() / 3
		elif gi is MultiMeshInstance3D and gi.multimesh and gi.multimesh.mesh:
			var arr2 = gi.multimesh.mesh.surface_get_arrays(0)
			var t1: int = (arr2[Mesh.ARRAY_INDEX].size() if arr2[Mesh.ARRAY_INDEX] != null else arr2[Mesh.ARRAY_VERTEX].size()) / 3
			tris += t1 * gi.multimesh.visible_instance_count if gi.multimesh.visible_instance_count >= 0 else t1 * gi.multimesh.instance_count
		var e: Array = groups.get(k, [0, 0, 0])
		e[0] += 1
		e[1] += tris
		if vr == 0.0:
			e[2] += 1
		groups[k] = e
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][1] > groups[b][1])
	for k in keys.slice(0, 14):
		print("   %-24s inst %5d  tris %8d  sans_portee %4d" % [k, groups[k][0], groups[k][1], groups[k][2]])

## Objets réellement dans le champ : par groupe racine (surfaces = appels de rendu)
func _frustum(pp: Vector3) -> void:
	var cam := get_viewport().get_camera_3d()
	var groups := {}
	for gi in world.find_children("*", "GeometryInstance3D", true, false):
		if not gi.is_visible_in_tree():
			continue
		var ab: AABB = gi.get_aabb()
		var c: Vector3 = gi.global_transform * ab.get_center()
		var rad: float = ab.size.length() * 0.5 * gi.global_transform.basis.get_scale().x
		var d: float = c.distance_to(cam.global_position)
		if gi.visibility_range_end > 0.0 and d > gi.visibility_range_end:
			continue
		if gi.visibility_range_begin > 0.0 and d < gi.visibility_range_begin:
			continue
		var inside := true
		for pl in cam.get_frustum():
			if pl.distance_to(c) > rad:
				inside = false
				break
		if not inside:
			continue
		var surf := 1
		if gi is MeshInstance3D and gi.mesh:
			surf = gi.mesh.get_surface_count()
		var top: Node = gi
		while top.get_parent() != world and top.get_parent() != null:
			top = top.get_parent()
		var k := String(top.get_class() if top is CharacterBody3D or top is Node3D and String(top.name).begins_with("@") else top.name).left(22)
		if top is Monster: k = "Monstres"
		elif top is Soldier: k = "Soldats"
		elif top is Villager: k = "Villageois"
		var e: Array = groups.get(k, [0, 0, 0])
		e[0] += surf
		e[1] += 1
		if gi.cast_shadow != GeometryInstance3D.SHADOW_CASTING_SETTING_OFF and d < 50.0:
			e[2] += surf
		groups[k] = e
	var keys := groups.keys()
	keys.sort_custom(func(a, b): return groups[a][0] > groups[b][0])
	for k in keys.slice(0, 16):
		print("   %-22s surfaces %5d  instances %4d  ombres<50m %4d" % [k, groups[k][0], groups[k][1], groups[k][2]])
