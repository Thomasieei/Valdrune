extends Node3D
## Scène principale du royaume.

var player: Player
var rig: CameraRig
var _inside := false

var _loading: CanvasLayer
var _bar: ProgressBar
var _step_label: Label

func _ready() -> void:
	_show_loading()
	var t0 := Time.get_ticks_msec()
	var steps := [
		["Le ciel et la lumière", func(): Ambiance.setup(self)],
		["Les terres et les rivières", func(): Terrain.build(self)],
		["Les routes et les ponts", func(): Roads.build(self)],
		["Le château", func(): Castle.build(self)],
		["Le bourg", func(): Town.build(self)],
		["Les champs", func(): Fields.build(self)],
		["La ferme, la mine et le portail", func(): Places.build(self)],
		["Les forêts", func(): Vegetation.build(self)],
		["Optimisation du décor", func(): _batch()],
	]
	for i in steps.size():
		_step_label.text = steps[i][0] + "…"
		_bar.value = float(i) / steps.size() * 100.0
		await get_tree().process_frame
		await get_tree().process_frame
		steps[i][1].call()
	print("monde construit en ", Time.get_ticks_msec() - t0, " ms")
	_step_label.text = "Préparation des effets visuels…"
	_bar.value = 95.0
	await _warmup()
	_bar.value = 100.0
	_spawn()
	_set_inside(false)
	await get_tree().process_frame
	_loading.queue_free()

## Préchauffage des shaders : on fait voir TOUT le monde (extérieur, intérieur éclairé, personnages)
## à une caméra cachée derrière l'écran de chargement, pour que les shaders soient compilés
## pendant le chargement et pas en pleine partie (c'était la cause des gros pics de ms).
func _warmup() -> void:
	var saved := {}
	for n in find_children("*", "GeometryInstance3D", true, false):
		saved[n] = [n.visibility_range_begin, n.visibility_range_end]
		n.visibility_range_begin = 0.0
		n.visibility_range_end = 0.0
	var cam := Camera3D.new()
	cam.far = 2000.0
	add_child(cam)
	cam.current = true
	var views := [
		[Vector3(0, 420, 120), Vector3(0, 0, -20)],
		[Vector3(0, Castle.FLOOR + 6.0, -131.0), Vector3(0, Castle.FLOOR + 2.0, -150.0)],
		[Vector3(14, Castle.FLOOR + 4.0, -131.0), Vector3(14, Castle.FLOOR, -150.0)],
		[Vector3(-14, Castle.FLOOR + 4.0, -131.0), Vector3(-14, Castle.FLOOR, -150.0)],
		[Vector3(0, 20, -40), Vector3(0, 12, -100)],
		[Vector3(80, 25, 30), Vector3(110, 3, -10)],
	]
	for l in Castle.interior_lights:
		l.visible = true
	for v in views:
		cam.position = v[0]
		cam.look_at(v[1])
		await get_tree().process_frame
		await get_tree().process_frame
	for n in saved:
		if is_instance_valid(n):
			n.visibility_range_begin = saved[n][0]
			n.visibility_range_end = saved[n][1]
	cam.queue_free()

func _batch() -> void:
	for nm in ["Mobilier", "CourDecor", "BourgDecor", "LieuxDecor"]:
		var n := get_node_or_null(nm) as Node3D
		if n:
			Batcher.merge(n)

func _show_loading() -> void:
	_loading = CanvasLayer.new()
	_loading.layer = 10
	add_child(_loading)
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.16)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	_loading.add_child(bg)
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.custom_minimum_size = Vector2(700, 300)
	box.position = Vector2(-350, -150)
	bg.add_child(box)
	var title := Label.new()
	title.text = "ROYAUME"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 96)
	title.add_theme_color_override("font_color", Color(0.98, 0.82, 0.42))
	title.add_theme_color_override("font_outline_color", Color(0.25, 0.12, 0.05))
	title.add_theme_constant_override("outline_size", 18)
	box.add_child(title)
	var sub := Label.new()
	sub.text = "Les terres du seigneur"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 30)
	sub.add_theme_color_override("font_color", Color(0.85, 0.88, 0.95))
	box.add_child(sub)
	var sp := Control.new()
	sp.custom_minimum_size = Vector2(0, 40)
	box.add_child(sp)
	_bar = ProgressBar.new()
	_bar.custom_minimum_size = Vector2(600, 22)
	_bar.show_percentage = false
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color(0.98, 0.78, 0.35)
	fill.set_corner_radius_all(10)
	var back := StyleBoxFlat.new()
	back.bg_color = Color(1, 1, 1, 0.12)
	back.set_corner_radius_all(10)
	_bar.add_theme_stylebox_override("fill", fill)
	_bar.add_theme_stylebox_override("background", back)
	box.add_child(_bar)
	_step_label = Label.new()
	_step_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_step_label.add_theme_font_size_override("font_size", 24)
	_step_label.add_theme_color_override("font_color", Color(0.75, 0.78, 0.86))
	box.add_child(_step_label)

func _spawn() -> void:
	FX.root = self
	Sfx.setup(self)
	player = Player.new()
	player.name = "Joueur"
	var start := Vector2(0, -60)
	var args := OS.get_cmdline_user_args()
	player.position = Vector3(start.x, Layout.height(start.x, start.y) + 0.3, start.y)
	player.rotation.y = PI   # regarde vers le château (nord)
	add_child(player)
	rig = CameraRig.new()
	rig.target = player
	add_child(rig)
	player.rig = rig
	Spawner.build(self)
	var ui := CanvasLayer.new()
	add_child(ui)
	var hud := Hud.new()
	ui.add_child(hud)
	hud.bind(player)
	var tc := TouchControls.new()
	tc.player = player
	tc.rig = rig
	tc.hud = hud
	ui.add_child(tc)
	var zone := find_child("ZoneDonjon", true, false) as Area3D
	if zone:
		zone.body_entered.connect(func(b): if b == player: _set_inside(true))
		zone.body_exited.connect(func(b): if b == player: _set_inside(false))
	if args.size() > 0 and args[0] == "--combat":
		var ct = load("res://scripts/tools/combat_test.gd").new()
		ct.world = self
		add_child(ct)
	if args.size() > 0 and args[0] == "--tour":
		var tour = load("res://scripts/tools/tour.gd").new()
		tour.world = self
		add_child(tour)

## Qualité adaptative : si le téléphone peine (< 28 FPS pendant 3 s), on allège par paliers.
var quality := 0
var _q_acc := 0.0
var _q_low := 0.0
var _npc_acc := 0.0

func _process(delta: float) -> void:
	if player == null:
		return
	_npc_acc += delta
	if _npc_acc > 0.3:
		_npc_acc = 0.0
		_cull_npcs()
	var a := OS.get_cmdline_user_args()
	if "--tour" in a or "--combat" in a:
		return
	_q_acc += delta
	if _q_acc < 1.0:
		return
	_q_acc = 0.0
	var fps := Engine.get_frames_per_second()
	_q_low = _q_low + 1.0 if fps < 28 else 0.0
	if _q_low >= 3.0 and quality < 4:
		_q_low = 0.0
		quality += 1
		_apply_quality()

## Les PNJ loin du joueur (ou de l'autre côté des murs du donjon) ne sont ni affichés ni animés.
func _cull_npcs() -> void:
	var pp := player.global_position
	for n in get_tree().get_nodes_in_group("pnj"):
		var inside_keep: bool = n.global_position.y > Castle.FLOOR - 0.2 and n.global_position.y < Castle.FLOOR + 3.0 and Layout.in_castle(Vector2(n.global_position.x, n.global_position.z)) and n.global_position.z < Castle.K_MAX.y and n.global_position.z > Castle.K_MIN.y and absf(n.global_position.x) < Castle.K_MAX.x
		var show: bool = pp.distance_to(n.global_position) < 65.0 and inside_keep == _inside
		if n.visible != show:
			n.visible = show
			n.process_mode = Node.PROCESS_MODE_INHERIT if show else Node.PROCESS_MODE_DISABLED

func _apply_quality() -> void:
	var sun := find_child("Soleil", false, false) as DirectionalLight3D
	var vp := get_viewport()
	match quality:
		1: vp.scaling_3d_scale = 0.65
		2:
			if sun: sun.shadow_enabled = false
		3:
			for n in find_child("Vegetation", true, false).get_children():
				n.visibility_range_end *= 0.75
		4: vp.scaling_3d_scale = 0.55
	print("qualité réduite → niveau ", quality)

## Intérieur / extérieur : on n'affiche que ce qui peut être vu.
const OUTSIDE_ONLY := ["Vegetation", "Bourg", "BourgDecor", "Champs", "Lieux", "LieuxDecor", "Gisements", "Ponts", "RoutesPavees", "Eau"]
const INSIDE_ONLY := ["DonjonInterieur", "Mobilier"]

func _set_inside(v: bool) -> void:
	_inside = v
	if rig:
		rig.inside = v
	for l in Castle.interior_lights:
		l.visible = v
	for nm in OUTSIDE_ONLY:
		var n := get_node_or_null(nm) as Node3D
		if n: n.visible = not v
	for nm in INSIDE_ONLY:
		var n := get_node_or_null(nm) as Node3D
		if n: n.visible = v
	if player:
		_cull_npcs()
