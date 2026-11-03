extends Node3D
## Banc d'essai du MegaKit : planche de pièces, maison isolée, vues multiples.
## godot --path . res://scenes/tests/mk_test.tscn -- <mode> [args]

func _ready() -> void:
	Ambiance.setup(self)
	for c in get_children():
		if c is WorldEnvironment: c.environment.fog_enabled = false
		if c is DirectionalLight3D: c.directional_shadow_max_distance = 120
	var ground := MeshInstance3D.new()
	var pm := PlaneMesh.new()
	pm.size = Vector2(400, 400)
	ground.mesh = pm
	var gm := StandardMaterial3D.new()
	gm.albedo_color = Color(0.35, 0.45, 0.28)
	ground.material_override = gm
	add_child(ground)
	var args := OS.get_cmdline_user_args()
	var mode: String = args[0] if args.size() > 0 else "sheet"
	var shots: Array = []
	match mode:
		"sheet":
			var names: Array = args[1].split(",")
			var mk := MK.new()
			var cols := int(ceil(sqrt(names.size())))
			var sp := float(args[2]) if args.size() > 2 else 6.0
			for i in names.size():
				var p := Vector3((i % cols) * sp, 0, (i / cols) * sp)
				if names[i].begins_with("res://"):
					Kit.place(self, names[i], p, 0.0, float(args[3]) if args.size() > 3 else 1.0)
				else:
					mk.put(names[i], p)
				var l := Label3D.new()
				l.text = names[i].get_file()
				l.font_size = 40
				l.pixel_size = 0.01
				l.billboard = BaseMaterial3D.BILLBOARD_ENABLED
				l.position = p + Vector3(0, -0.2, 2.2)
				add_child(l)
			mk.commit(self, "Sheet", 0.0, false)
			var c := Vector3((cols - 1) * sp * 0.5, 0, (names.size() / cols) * sp * 0.5)
			shots = [["sheet_front", c + Vector3(0, cols * sp * 0.55, cols * sp * 0.9), c], ["sheet_back", c + Vector3(0, cols * sp * 0.55, -cols * sp * 0.9), c]]
		"house":
			var mk := MK.new()
			var b := Bourg.new()
			b.mk = mk
			var specs: Array = str_to_var(args[1])
			for s in specs:
				b.build_house(s)
			mk.commit(self, "Maisons", 0.0, false)
			print("triangles : ", mk.tris)
			var ks: Array = mk.stats.keys()
			ks.sort_custom(func(a, b): return mk.stats[a] > mk.stats[b])
			for k in ks.slice(0, 14): print("  ", k, " ", mk.stats[k])
			for v in str_to_var(args[2]):
				shots.append(["house_%d" % shots.size(), Vector3(v[0], v[1], v[2]), Vector3(v[3], v[4], v[5])])
	var cam := Camera3D.new()
	cam.fov = 60
	cam.far = 800
	add_child(cam)
	cam.current = true
	for s in shots:
		cam.position = s[1]
		cam.look_at(s[2])
		for f in 4:
			await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://shots/mk_%s.png" % s[0])
	get_tree().quit()
