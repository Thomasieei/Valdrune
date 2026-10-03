extends SceneTree
func _aabb(n: Node, xf: Transform3D, acc: Array) -> void:
	var x := xf
	if n is Node3D: x = xf * n.transform
	if n is MeshInstance3D and n.mesh:
		var a: AABB = x * n.mesh.get_aabb()
		acc[0] = a if acc[0] == null else acc[0].merge(a)
	for c in n.get_children(): _aabb(c, x, acc)
func _init():
	var paths := []
	for d in ["forest", "hex", "dungeon", "halloween", "weapons"]:
		for f in DirAccess.get_files_at("res://assets/" + d):
			if f.ends_with(".gltf") or f.ends_with(".glb"): paths.append("res://assets/%s/%s" % [d, f])
	for p in paths:
		var s = load(p)
		if s == null: continue
		var n: Node = s.instantiate(); var acc := [null]; _aabb(n, Transform3D.IDENTITY, acc)
		if acc[0]: print(p.get_file(), "  size=", acc[0].size.snapped(Vector3(0.01,0.01,0.01)), " pos=", acc[0].position.snapped(Vector3(0.01,0.01,0.01)))
		n.free()
	quit()
