extends Node3D
## Vue de dessus du royaume (plan), pour valider l'organisation.
func _ready() -> void:
	var t0 := Time.get_ticks_msec()
	Ambiance.setup(self)
	Terrain.build(self)
	Roads.build(self)
	Castle.build(self)
	Town.build(self)
	Fields.build(self)
	Places.build(self)
	Vegetation.build(self)
	for n in find_children("*", "GeometryInstance3D", true, false):
		n.visibility_range_end = 0.0
	print("terrain ms ", Time.get_ticks_msec() - t0)
	var cam := Camera3D.new()
	cam.projection = Camera3D.PROJECTION_ORTHOGONAL
	cam.size = 640
	cam.position = Vector3(0, 300, 0)
	cam.rotation_degrees = Vector3(-90, 0, 0)
	cam.far = 1000
	add_child(cam)
	cam.current = true
	var env: WorldEnvironment = find_child("*", false, false) as WorldEnvironment
	for c in get_children():
		if c is WorldEnvironment: c.environment.fog_enabled = false
		if c is DirectionalLight3D: c.directional_shadow_max_distance = 600
	var args := OS.get_cmdline_user_args()
	if args.size() > 1:
		var v: Array = str_to_var(args[1])
		cam.projection = Camera3D.PROJECTION_PERSPECTIVE
		cam.fov = 60
		cam.position = Vector3(v[0], v[1], v[2])
		cam.look_at(Vector3(v[3], v[4], v[5]))
	for f in 6: await get_tree().process_frame
	get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % (args[0] if args.size() else "plan"))
	get_tree().quit()
