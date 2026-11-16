extends Node
## Mode « --icons » (CI) : photographie les armes et les ombres en 3D pour en faire des vignettes de cartes.

const SPECS := [
	# nom, modèle, animation, ombre ?, lueur, angle (deg)
	["w1", "katana", "", false, "", 45.0],
	["w2", "dague", "", false, "", 45.0],
	["w3", "hache", "", false, "", 45.0],
	["w4", "lame", "", false, "ff3b3b", 45.0],
	["w5", "dague", "", false, "4ade80", 45.0],
	["w6", "hache", "", false, "ff3b5c", 45.0],
	["w7", "lame", "", false, "ff2020", 45.0],
	["w8", "lame", "", false, "b46bff", 45.0],
	["sh_goblin", "goblin", "Idle", true, "", 20.0],
	["sh_shaman", "chaman", "Animacion", true, "", 20.0],
	["sh_orc", "orc", "Idle", true, "", 20.0],
	["sh_orc_warrior", "orc_warrior", "Idle", true, "", 20.0],
	["sh_igris", "igris", "Idle", true, "", 20.0],
	["m_goblin", "goblin", "Idle", false, "", 20.0],
	["m_shaman", "chaman", "Animacion", false, "", 20.0],
	["m_orc", "orc", "Idle", false, "", 20.0],
	["m_orc_warrior", "orc_warrior", "Idle", false, "", 20.0],
]

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://shots/icons"))
	for s in SPECS:
		await _bake(s)
	print("ICONS_DONE ", SPECS.size())
	get_tree().quit()

func _bake(s: Array) -> void:
	var vp := SubViewport.new()
	vp.size = Vector2i(256, 256)
	vp.transparent_bg = true
	vp.own_world_3d = true
	vp.msaa_3d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(vp)
	var env := WorldEnvironment.new()
	var e := Environment.new()
	e.background_mode = Environment.BG_CLEAR_COLOR
	e.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	e.ambient_light_color = Color(0.7, 0.72, 0.85)
	e.ambient_light_energy = 0.7
	e.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	env.environment = e
	vp.add_child(env)
	var key := DirectionalLight3D.new()
	key.rotation_degrees = Vector3(-35, -30, 0)
	key.light_energy = 1.4
	vp.add_child(key)
	var rim := DirectionalLight3D.new()
	rim.rotation_degrees = Vector3(-20, 150, 0)
	rim.light_energy = 1.0
	rim.light_color = Color(0.7, 0.6, 1.0) if s[3] else Color(1, 0.9, 0.8)
	vp.add_child(rim)
	var root := Node3D.new()
	vp.add_child(root)
	var m := (load("res://assets/%s.glb" % s[1]) as PackedScene).instantiate() as Node3D
	root.add_child(m)
	var aps := m.find_children("*", "AnimationPlayer", true, false)
	if not aps.is_empty() and str(s[2]) != "":
		var ap := aps[0] as AnimationPlayer
		for a in ap.get_animation_list():
			if a == s[2] or a.ends_with(str(s[2])):
				ap.play(a)
				ap.seek(0.4, true)
				ap.pause()
				break
	# masque les éléments plats (ombres au sol intégrées) et les armes géantes de l'orc
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		var bb := g.get_aabb()
		if bb.size.y < 0.02 * maxf(bb.size.x, bb.size.z):
			g.visible = false
	if s[3]:
		var sm := StandardMaterial3D.new()
		sm.albedo_color = Color(0.06, 0.03, 0.12)
		sm.emission_enabled = true
		sm.emission = Color(0.4, 0.12, 0.9)
		sm.emission_energy_multiplier = 0.7
		sm.rim_enabled = true
		sm.rim = 1.0
		sm.rim_tint = 0.2
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_override = sm
	if str(s[4]) != "":
		var c := Color(str(s[4]))
		var gm := StandardMaterial3D.new()
		gm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		gm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		gm.blend_mode = BaseMaterial3D.BLEND_MODE_ADD
		gm.albedo_color = Color(c.r, c.g, c.b, 0.4)
		for mi in m.find_children("*", "MeshInstance3D", true, false):
			(mi as MeshInstance3D).material_overlay = gm
	await get_tree().process_frame
	await get_tree().process_frame
	var aabb := AABB()
	var first := true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if not g.visible:
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var weapon: bool = str(s[0]).begins_with("w")
	if weapon:
		root.rotation_degrees = Vector3(0, 90, float(s[5]))
	await get_tree().process_frame
	aabb = AABB()
	first = true
	for mi in m.find_children("*", "MeshInstance3D", true, false):
		var g := mi as MeshInstance3D
		if not g.visible:
			continue
		var bb: AABB = g.global_transform * g.get_aabb()
		aabb = bb if first else aabb.merge(bb)
		first = false
	var cam := Camera3D.new()
	vp.add_child(cam)
	cam.fov = 30.0
	var ctr := aabb.get_center()
	var sz := maxf(aabb.size.x, aabb.size.y)
	if not weapon:
		# portrait : buste et tête
		ctr.y = aabb.position.y + aabb.size.y * 0.68
		sz = aabb.size.y * 0.62
	var dist := sz * 0.5 / tan(deg_to_rad(cam.fov * 0.5)) * 1.12
	var dir := Vector3(sin(deg_to_rad(float(s[5]) if not weapon else 0.0)), 0.12, cos(deg_to_rad(float(s[5]) if not weapon else 0.0))).normalized()
	cam.look_at_from_position(ctr + dir * (dist + aabb.size.z * 0.5), ctr, Vector3.UP)
	for k in 4:
		await RenderingServer.frame_post_draw
	var img := vp.get_texture().get_image()
	img.save_png("res://shots/icons/%s.png" % s[0])
	print("ICON ", s[0], " ", aabb.size)
	vp.queue_free()
