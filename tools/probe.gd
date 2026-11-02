extends SceneTree
func aabb_of(n:Node, xf:Transform3D=Transform3D.IDENTITY) -> AABB:
	var r := AABB(); var first := true
	var stack := [[n, xf]]
	while stack.size():
		var it = stack.pop_back(); var node = it[0]; var t:Transform3D = it[1]
		if node is Node3D: t = t * node.transform
		if node is MeshInstance3D and node.mesh:
			var a:AABB = t * node.mesh.get_aabb()
			if first: r = a; first = false
			else: r = r.merge(a)
		for c in node.get_children(): stack.append([c, t])
	return r
func tree(n:Node, d:int=0):
	if d > 4: return
	var extra := ""
	if n is AnimationPlayer: extra = str(n.get_animation_list().slice(0,5))
	print("  ".repeat(d), n.name, " <", n.get_class(), "> ", extra)
	for c in n.get_children(): tree(c, d+1)
func _init():
	var args = OS.get_cmdline_user_args()
	var mode = args[0]
	for p in args.slice(1):
		var res = load(p)
		if res == null: print("FAIL ", p); continue
		var inst
		if res is Mesh:
			inst = MeshInstance3D.new(); inst.mesh = res
		else:
			inst = res.instantiate()
		if mode == "tree": print("== ", p); tree(inst)
		else:
			var a := aabb_of(inst); print("%s size=(%.2f, %.2f, %.2f) pos=(%.2f, %.2f, %.2f)" % [p.get_file(), a.size.x, a.size.y, a.size.z, a.position.x, a.position.y, a.position.z])
		inst.free()
	quit()
