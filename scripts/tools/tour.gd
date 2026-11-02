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
		print("SHOT ", s[0], " fps=", Engine.get_frames_per_second())
	get_tree().quit()
