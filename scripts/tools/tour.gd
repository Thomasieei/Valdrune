extends Node
## Tournée de contrôle : place le joueur et la caméra à des points clés et enregistre des captures.
var world
var stops := []
func _ready() -> void:
	var args := OS.get_cmdline_user_args()
	var only := args[1] if args.size() > 1 else ""
	stops = [
		# nom, position joueur (x,z), lacet caméra (deg), tangage (deg), distance, intérieur
		["01_arrivee_chateau", Vector2(0, -40), 0.0, -14.0, 9.0, false],
		["02_porte_gardes", Vector2(0, -74), 340.0, -12.0, 8.0, false],
		["03_cour", Vector2(0, -100), 0.0, -16.0, 9.0, false],
		["04_salle_trone", Vector2(0, -134), 0.0, -12.0, 6.0, true],
		["05_conseil", Vector2(-13, -147), 20.0, -22.0, 6.0, true],
		["06_bibliotheque", Vector2(-12, -132), 50.0, -20.0, 6.0, true],
		["07_armurerie", Vector2(13, -147), 340.0, -22.0, 6.0, true],
		["08_tresorerie", Vector2(12, -132), 320.0, -20.0, 6.0, true],
		["09_bourg", Vector2(8, -6), 20.0, -18.0, 9.0, false],
		["10_champs", Vector2(60, -20), 60.0, -16.0, 9.0, false],
		["10b_champs_haut", Vector2(100, -32), 200.0, -32.0, 13.0, false],
		["10c_ferme", Vector2(80, 10), 120.0, -20.0, 11.0, false],
		["11_foret", Vector2(-100, 30), 300.0, -12.0, 8.0, false],
		["12_riviere_pont", Vector2(14, 40), 330.0, -16.0, 9.0, false],
		["13_mine", Vector2(160, -150), 20.0, -14.0, 9.0, false],
		["14_lac", Vector2(130, 140), 50.0, -14.0, 9.0, false],
		["15_portail", Vector2(33, 212), 180.0, -12.0, 9.0, false],
		["16_vue_chateau_loin", Vector2(20, -10), 350.0, -8.0, 12.0, false],
	]
	if only == "audit":
		_audit()
		return
	if only != "":
		var keys: Array = Array(only.split(","))
		stops = stops.filter(func(s): return keys.any(func(k): return k in s[0]))
	_run()

func _run() -> void:
	while world.player == null:
		await get_tree().process_frame
	for f in 3: await get_tree().process_frame
	var p: Player = world.player
	var rig: CameraRig = world.rig
	for s in stops:
		var xz: Vector2 = s[1]
		var y := Layout.height(xz.x, xz.y) + 0.3
		if s[5]:
			y = Castle.FLOOR + 0.2
		p.global_position = Vector3(xz.x, y, xz.y)
		p.velocity = Vector3.ZERO
		world._set_inside(s[5])
		rig.yaw = deg_to_rad(s[2])
		rig.pitch = deg_to_rad(s[3])
		rig.dist_goal = s[4]
		rig.dist = s[4]
		p.rotation.y = rig.yaw + PI
		rig._focus = p.global_position + Vector3.UP * 1.45
		rig._last_manual = Time.get_ticks_msec() / 1000.0 + 100.0
		for f in 8: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % s[0])
		var prims := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME)
		var draws := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
		var objs := RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME)
		print("SHOT ", s[0], " triangles=", prims, " draws=", draws, " objets=", objs)
	get_tree().quit()

## Vues d'audit (caméra libre) : vues aériennes et au sol du bourg et des lieux habités
func _audit() -> void:
	while world.player == null:
		await get_tree().process_frame
	for f in 3: await get_tree().process_frame
	var cams := [
		["A_bourg_ciel", Vector3(0, 95, 25), Vector3(0, 0, -20)],
		["A_bourg_oblique", Vector3(45, 38, 30), Vector3(0, 0, -20)],
		["S_eglise", Vector3(10, 4, -2), Vector3(-19, 6, 4)],
		["P_portail", Vector3(52, 16, 205), Vector3(35, 4, 235)],
		["K_bandits", Vector3(-42, 14, 120), Vector3(-60, 2, 140)],
		["K_puglins", Vector3(120, 12, 62), Vector3(140, 2, 85)],
		["K_crypte", Vector3(-182, 12, -20), Vector3(-200, 2, 0)],
		["P_portail_face", Vector3(35, 13, 214), Vector3(35, 4, 235)],
		["A_bourg_sud", Vector3(10, 30, 60), Vector3(5, 0, 0)],
		["A_route_sud", Vector3(40, 45, 80), Vector3(15, 0, 40)],
		["A_ferme", Vector3(95, 50, 40), Vector3(100, 0, -10)],
		["A_bucherons", Vector3(-120, 40, 25), Vector3(-120, 0, -10)],
		["A_mine", Vector3(170, 45, -130), Vector3(172, 0, -170)],
		["S_place", Vector3(14, 6, -8), Vector3(0, 3, -22)],
		["S_rue_est", Vector3(30, 5, -14), Vector3(10, 3, -20)],
		["S_rue_ouest", Vector3(-30, 5, -26), Vector3(-10, 3, -18)],
		["S_maisons_sud", Vector3(18, 5, 40), Vector3(10, 3, 20)],
		["S_route_pont", Vector3(30, 5, 75), Vector3(22, 2, 55)],
		["S_vers_chateau", Vector3(4, 6, -40), Vector3(0, 10, -80)],
		["C_entree_cachots", Vector3(-24, 16.5, -94), Vector3(-33, 11, -106)],
		["C_escalier", Vector3(-33, 13.6, -100.5), Vector3(-33, 8.0, -116)],
		["C_interieur", Vector3(-29.0, 10.6, -115.6), Vector3(-35, 8.2, -123)],
		["C_cellules", Vector3(-33, 9.4, -116.2), Vector3(-33, 8.4, -125)],
	]
	for key in ["auberge", "forge"]:
		if Town.specials.has(key):
			var dp: Vector2 = Town.specials[key][0]
			var dd: Vector2 = Town.specials[key][1]
			var sd := Vector2(dd.y, -dd.x)
			var e: Vector2 = dp + dd * 11.0 + sd * 5.0
			cams.append(["S_" + key, Vector3(e.x, 3.2, e.y), Vector3(dp.x + dd.x * 2.5, 1.0, dp.y + dd.y * 2.5)])
	for gid in BanditVillage.VILLAGES:
		var vc: Vector2 = CampParley.zone(gid)["pos"]
		var dv: Vector2 = (Layout.TOWN - vc).normalized()
		var e2: Vector2 = vc + dv * 30.0 + Vector2(dv.y, -dv.x) * 8.0
		cams.append(["S_v_" + gid, Vector3(e2.x, 13.0, e2.y), Vector3(vc.x, 1.0, vc.y)])
	var args := OS.get_cmdline_user_args()
	if args.size() > 2:
		cams = cams.filter(func(c): return c[0].begins_with(args[2]))
	var cam := Camera3D.new()
	cam.far = 1500.0
	world.add_child(cam)
	cam.current = true
	world.player.global_position = Vector3(0, -50, 0)
	for c in cams:
		var pos: Vector3 = c[1]
		var tgt: Vector3 = c[2]
		pos.y += Terrain.height_at(pos.x, pos.z) if c[0].begins_with("S_") else 0.0
		tgt.y += Terrain.height_at(tgt.x, tgt.z)
		cam.global_position = pos
		cam.look_at(tgt, Vector3.UP)
		world.player.global_position = Vector3(tgt.x, Terrain.height_at(tgt.x, tgt.z) - 30.0, tgt.z)
		world.set_cellar(c[0] == "C_interieur" or c[0] == "C_cellules")
		world._cull_npcs()
		for f in 10: await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png("res://shots/%s.png" % c[0])
		print("SHOT ", c[0])
	get_tree().quit()
