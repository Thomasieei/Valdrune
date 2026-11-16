extends Node3D
const IDS := ["env_room99","env_simple","env_throne","env_dungeon1","env_temple","env_abbuilding","env_brick","env_office"]
func _aabb(n: Node, acc: Array) -> void:
	if n is MeshInstance3D:
		var a: AABB = n.global_transform * n.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	for c in n.get_children(): _aabb(c, acc)
func _ready() -> void:
	DirAccess.make_dir_recursive_absolute("res://out")
	for id in IDS:
		var vp := SubViewport.new(); vp.size = Vector2i(640, 400); vp.own_world_3d = true
		vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; add_child(vp)
		var we := WorldEnvironment.new(); var e := Environment.new()
		e.background_mode = Environment.BG_COLOR; e.background_color = Color(0.2,0.22,0.28)
		e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR; e.ambient_light_color = Color(1,1,1); e.ambient_light_energy = 0.7
		we.environment = e; vp.add_child(we)
		var m: Node3D = load("res://m/%s.glb" % id).instantiate(); vp.add_child(m)
		await get_tree().process_frame
		var acc := [null]; _aabb(m, acc); var a: AABB = acc[0]
		print("ROOM ", id, " ", a)
		var L := OmniLight3D.new(); L.omni_range = a.size.length(); L.light_energy = 1.5
		L.position = a.get_center(); vp.add_child(L)
		var cam := Camera3D.new(); cam.fov = 75; cam.far = a.size.length() * 3; cam.near = a.size.length() * 0.002; vp.add_child(cam); cam.current = true
		var lo := a.position; var hi := a.end; var h := lo.y + a.size.y * 0.4
		var views := [
			[Vector3(lo.x + a.size.x*0.1, h, lo.z + a.size.z*0.1), Vector3(hi.x - a.size.x*0.3, lo.y + a.size.y*0.2, hi.z - a.size.z*0.3)],
			[Vector3(hi.x - a.size.x*0.1, h, hi.z - a.size.z*0.1), Vector3(lo.x + a.size.x*0.3, lo.y + a.size.y*0.2, lo.z + a.size.z*0.3)],
			[a.get_center() + Vector3(0, a.size.y*0.05, 0), a.get_center() + Vector3(a.size.x*0.5, -a.size.y*0.2, 0.01)],
			[a.get_center() + Vector3(-a.size.x*0.9, a.size.y*1.6, a.size.z*0.9), a.get_center()]]
		for k in views.size():
			cam.position = views[k][0]; cam.look_at(views[k][1])
			for f in 6: await RenderingServer.frame_post_draw
			vp.get_texture().get_image().save_png("res://out/%s_%d.png" % [id, k])
		vp.queue_free(); await get_tree().process_frame
	print("ROOMS_DONE"); get_tree().quit()
